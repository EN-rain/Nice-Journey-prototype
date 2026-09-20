extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const VISUAL_CATALOG: EnemyVisualSceneCatalog = preload("res://src/enemies/presentation/enemy_visual_scene_catalog.tres")
const TUNING: SummonerReinforcementPlaytestTuning = preload("res://src/data/tuning/summoner_reinforcement_playtest_v01.tres")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(ProfileCreationService.create_profile(1, "Summoner Gate", "melee"))
    root.add_child(game)
    await process_frame
    game._set_foundation_world_enabled(false)
    game.player.global_position = Vector2(-1000.0, -1000.0)
    var host := game.tower_encounter_session_host
    var delivery := game.enemy_non_damage_playtest_delivery
    host.set_physics_process(false)
    delivery.set_physics_process(false)
    _expect(delivery.host == host and host.reinforcement_tuning == TUNING,
        "shipped Gameplay wires Inspector-authored reinforcement tuning to the active-window owner")

    var floor := _floor_state(4)
    var profile: ProfileSnapshot = ProfileCreationService.create_profile(1, "Summoner Floor", "melee")
    _expect(profile != null and TowerFloorStateService.commit_floor_state(profile, floor),
        "floor fixture has authoritative persistent state")
    var summon_id := &"enemy:reinforcement_fixture_summoner"
    var encounter_id := &"encounter:summoner_reinforcement_fixture"
    var plan := _plan(4, [_placement(summon_id, encounter_id, Vector2i(2, 2))])
    var allocation := SummonerReinforcementPlan.build(plan, floor, encounter_id, TUNING)
    _expect(bool(allocation.get("accepted", false)), "fixed floor plan reserves authored, reachable summon tiles before combat")
    var slots := (allocation.get("slots_by_summoner", {}) as Dictionary).get(summon_id, []) as Array
    _expect(slots.size() == TUNING.calls_per_summoner and slots[0]["actor_id"] != slots[1]["actor_id"],
        "each permitted call owns one distinct stable reinforcement identity")
    var small_floor := _floor_state(1)
    var over_budget: Array = []
    for index: int in 4:
        over_budget.append(_placement(StringName("enemy:floor_budget_%02d" % index),
            &"encounter:floor_budget_test", Vector2i(2 + index, 2)))
    var rejected_allocation := SummonerReinforcementPlan.build(_plan(1, over_budget),
        small_floor, &"encounter:floor_budget_test", TUNING)
    _expect(not bool(rejected_allocation.get("accepted", false))
        and rejected_allocation.get("reason_id", &"") == &"reinforcement_floor_population_budget",
        "Summoner reserves every floor call up front, rejecting population over-allocation")
    var player_id := &"player:summoner_fixture"
    var started := host.activate_encounter(profile, floor, plan, encounter_id, _actor(player_id),
        {summon_id: _actor(summon_id)}, VISUAL_CATALOG)
    _expect(bool(started.get("accepted", false)), "real session admits Summoner through normal encounter owner")
    if not bool(started.get("accepted", false)):
        game.queue_free()
        await process_frame
        quit(_failures)
        return
    var encounter := host.get_encounter_runtime(encounter_id)
    var summoner := host.get_archetype_runtime(encounter_id, summon_id)
    var driver := host.get_action_phase_driver(encounter_id, summon_id)
    _expect(host.has_reinforcement_budget(encounter_id, summon_id),
        "live Summoner has only its reserved and unused actor slots")

    _expect(_cast(driver, summoner, 71001), "first finite Summoner call completes authentic windup")
    var first := delivery.last_result
    var first_id := StringName(String(first.get("actor_id", &"")))
    _expect(bool(first.get("accepted", false)) and first_id == StringName(String(slots[0]["actor_id"])),
        "authenticated ACTIVE window spawns the first reserved actor")
    _expect(encounter.get_active_enemy_count() == 2 and host.shared_full_ai.get_admitted_count() == 2,
        "live reinforcement uses ordinary combat and globally counted FULL-AI admission")
    _expect(host.get_archetype_runtime(encounter_id, first_id) != null
        and host.get_action_phase_driver(encounter_id, first_id) != null
        and host.get_movement_driver(encounter_id, first_id) != null
        and host.get_attack_delivery_executor(encounter_id, first_id) != null
        and host.get_visuals_by_actor(encounter_id).has(first_id),
        "spawn registers archetype, action, movement, attack and visible presentation")
    var first_runtime := host.get_archetype_runtime(encounter_id, first_id)
    var first_driver := host.get_action_phase_driver(encounter_id, first_id)
    var add_attack := first_driver.begin({"accepted": true,
        "tactic_id": first_runtime.definition.signature_action_id}, 71011, {})
    _expect(bool(add_attack.get("accepted", false))
        and encounter.has_enemy_attack_ownership(first_id, player_id, 71011,
            first_runtime.active_reservation_token),
        "reinforcement can commit a real enemy attack through shared pressure and reservation admission")
    var replay := delivery.resolve_active_window(encounter_id, summoner.get_active_delivery_context(71001))
    _expect(not bool(replay.get("accepted", false)) and host.shared_full_ai.get_admitted_count() == 2,
        "duplicate delivery cannot mint an extra reinforcement")
    var forged_context := summoner.get_active_delivery_context(71001)
    forged_context["reservation_token"] = 0
    var forged := host.spawn_summoner_reinforcement(encounter_id, summon_id, forged_context)
    _expect(not bool(forged.get("accepted", false))
        and forged.get("reason_id", &"") == &"reinforcement_unauthenticated_action"
        and host.shared_full_ai.get_admitted_count() == 2,
        "forged active context lacking a live reservation cannot spend a summon slot")

    var defeated := encounter.resolve_direct_contact(player_id, first_id, 71901, 0,
        _attack(1000.0), false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(defeated.get("target_defeated", false)) and floor.defeated_actor_ids.has(first_id),
        "reinforcement death releases normal AI and records stable floor defeat")
    _expect(not encounter.reservations.has_reservation(first_id, 71011),
        "defeated reinforcement releases its committed attack reservation")
    _expect(host.shared_full_ai.get_admitted_count() == 1 and host.has_reinforcement_budget(encounter_id, summon_id),
        "remaining call survives first reinforcement defeat without refunding used slot")

    _finish_action(driver)
    for index: int in FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS - 1:
        _expect(host.shared_full_ai.try_admit(StringName("enemy:cap_filler_%02d" % index), &"encounter:cap_fixture"),
            "shared cap fixture fills one counted slot")
    _expect(not _cast(driver, summoner, 71002),
        "Summoner cannot commit a call while the global FULL-AI cap is full")
    _expect(host.has_reinforcement_budget(encounter_id, summon_id),
        "capacity denial does not consume finite remaining allocation")
    for index: int in FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS - 1:
        host.shared_full_ai.release(StringName("enemy:cap_filler_%02d" % index))
    var pending := driver.begin({"accepted": true,
        "tactic_id": summoner.definition.signature_action_id}, 71003,
        {"reinforcement_budget_available": true})
    _expect(bool(pending.get("accepted", false)),
        "Summoner can commit while shared capacity is initially available")
    for index: int in FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS - 1:
        host.shared_full_ai.try_admit(StringName("enemy:cap_filler_%02d" % index), &"encounter:cap_fixture")
    for _tick: int in int(driver.timing["windup_ticks"]):
        driver.advance_fixed_tick()
    _expect(not bool(delivery.last_result.get("accepted", false))
        and StringName(String(delivery.last_result.get("reason_id", &""))) == &"reinforcement_full_ai_cap"
        and host.has_reinforcement_budget(encounter_id, summon_id),
        "late FULL-AI saturation refuses actual spawn without burning finite actor slot")
    for index: int in FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS - 1:
        host.shared_full_ai.release(StringName("enemy:cap_filler_%02d" % index))
    _finish_action(driver)
    _expect(_cast(driver, summoner, 71004), "available FULL-AI slot enables the second authored call")
    var second_id := StringName(String(delivery.last_result.get("actor_id", &"")))
    _expect(bool(delivery.last_result.get("accepted", false))
        and second_id == StringName(String(slots[1]["actor_id"]))
        and not host.has_reinforcement_budget(encounter_id, summon_id),
        "second unique actor consumes the final call; no third reinforcement is authorized")
    var spent := floor.quest_state.get(host.REINFORCEMENT_SPENT_KEY, []) as Array
    _expect(spent.has(String(first_id)) and spent.has(String(second_id))
        and (profile.tower_floor_states[str(floor.floor_id)] as Dictionary).get("quest_state", {}).get(
            host.REINFORCEMENT_SPENT_KEY, []).size() == TUNING.calls_per_summoner,
        "successful calls durably charge both actor identities, including the surviving second add")

    _expect(host.end_encounter(encounter_id), "encounter exit tears down Summoner and its adds together")
    _expect(host.shared_full_ai.get_admitted_count() == 0 and not host.shared_active_combat.is_active(),
        "encounter teardown leaves no global FULL-AI or Active Combat ownership")
    await process_frame
    _expect(host.get_visuals_by_actor(encounter_id).is_empty() and host.get_child_count() == 0,
        "encounter teardown removes spawned visuals and runtime lookup")
    var restored_floor := FloorInstanceState.new()
    _expect(restored_floor.load_dictionary(profile.tower_floor_states[str(floor.floor_id)]).is_empty(),
        "ordinary revisit restores the same floor after a surviving reinforcement unload")
    var revisit := host.activate_encounter(profile, restored_floor, plan, encounter_id,
        _actor(player_id), {summon_id: _actor(summon_id)}, VISUAL_CATALOG)
    _expect(bool(revisit.get("accepted", false)) and not host.has_reinforcement_budget(encounter_id, summon_id)
        and host.shared_full_ai.get_admitted_count() == 1,
        "re-entering the surviving Summoner cannot recycle spent calls or respawn unloaded adds")
    host.end_encounter(encounter_id)
    game.queue_free()
    await process_frame
    if _failures == 0:
        print("SUMMONER REINFORCEMENT LIVE TEST PASS")
    else:
        push_error("SUMMONER REINFORCEMENT LIVE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _cast(driver: EnemySignatureActionPhaseDriver, summoner: EnemyArchetypeRuntime, instance_id: int) -> bool:
    var begin := driver.begin({"accepted": true, "tactic_id": summoner.definition.signature_action_id},
        instance_id, {"reinforcement_budget_available": true})
    if not bool(begin.get("accepted", false)):
        return false
    for _tick: int in int(driver.timing["windup_ticks"]):
        if not driver.advance_fixed_tick():
            return false
    return summoner.phase_id == EnemyArchetypeRuntime.PHASE_ACTIVE


func _finish_action(driver: EnemySignatureActionPhaseDriver) -> void:
    for _tick: int in int(driver.timing["active_ticks"]) + int(driver.timing["recovery_ticks"]) + int(driver.timing["cooldown_ticks"]):
        driver.advance_fixed_tick()


func _floor_state(floor_id: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(floor_id, 44091,
        &"tower_generator:v01", &"tower_modules:v01", &"encounters:v01", &"quest_flags:summoner_test")
    return TowerFloorGenerationCommitService.floor_state_from_manifest(
        &"floor_instance:summoner_reinforcement_test", TowerPrevalidatedFallbackFactory.build_for_request(request))


func _plan(floor_id: int, placements: Array) -> Dictionary:
    return {"plan_id": &"encounter_plan:summoner_reinforcement_test", "floor_id": floor_id,
        "complete_floor_plan": false, "placements": placements}


func _placement(actor_id: StringName, encounter_id: StringName, local_tile: Vector2i) -> Dictionary:
    return {"actor_id": actor_id, "archetype_id": &"summoner", "encounter_id": encounter_id,
        "room_instance_id": &"room:objective_00", "local_tile": local_tile, "elite": false}


func _actor(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, 100, 100.0, 0.0, 0.0, 20.0, true, false, false),
        "combatant fixture configures %s" % String(actor_id))
    return state


func _attack(raw_damage: float) -> Dictionary:
    return {"domain": DirectHitResolver.DOMAIN_PHYSICAL, "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": raw_damage, "dodgeable": true, "blockable": true, "parryable": true,
        "guard_pressure": 0.0, "critical_triggered": false, "critical_multiplier": 1.0,
        "weak_point_triggered": false, "weak_point_multiplier": 1.0}


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
