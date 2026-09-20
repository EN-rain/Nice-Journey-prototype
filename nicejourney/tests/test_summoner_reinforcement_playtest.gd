extends SceneTree

const TUNING: SummonerReinforcementPlaytestTuning = preload("res://src/data/tuning/summoner_reinforcement_playtest_v01.tres")
const NON_DAMAGE: EnemyNonDamagePlaytestTuning = preload("res://src/data/tuning/enemy_non_damage_playtest_v01.tres")
const STATUS: StatusPlaytestTuning = preload("res://src/data/tuning/status_effects_playtest_v01.tres")
const VISUALS: EnemyVisualSceneCatalog = preload("res://src/enemies/presentation/enemy_visual_scene_catalog.tres")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var request := TowerFloorGenerationCommitService.build_request(
        8, 80808, &"tower_generator:v01", &"tower_modules:v01", &"encounters:v01", &"quest_flags:summoner_test")
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    var floor := TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:summoner_test", manifest)
    var profile := ProfileCreationService.create_profile(1, "Summoner Gate", "melee")
    _expect(floor != null and profile != null and TowerFloorStateService.commit_floor_state(profile, floor), "Floor 8 fixture persists before combat")
    var encounter_id := &"encounter:summoner_test"
    var summoner_id := &"enemy:summoner_test"
    var escort_id := &"enemy:duelist_test"
    var plan := {
        "plan_id": &"encounter_plan:summoner_test", "floor_id": 8,
        "complete_floor_plan": false,
        "placements": [
            _placement(summoner_id, &"summoner", encounter_id, Vector2i(2, 2)),
            _placement(escort_id, &"duelist", encounter_id, Vector2i(3, 2)),
        ],
    }
    var shipped_plan := TowerProductionEncounterContentCatalog.build_plan(floor)
    var shipped_summoner_count := 0
    for raw_placement: Variant in shipped_plan.get("placements", []) as Array:
        if StringName(String((raw_placement as Dictionary).get("archetype_id", &""))) == &"summoner":
            shipped_summoner_count += 1
    var shipped_reinforcements := SummonerReinforcementPlan.build(shipped_plan, floor, encounter_id, TUNING)
    _expect(shipped_summoner_count > 0 and bool(shipped_reinforcements.get("accepted", false)),
        "shipped Floor 8 production encounters include Summoner and reserve within actual floor budget")
    for floor_id: int in [9, 10]:
        var next_request := TowerFloorGenerationCommitService.build_request(
            floor_id, 80808 + floor_id, &"tower_generator:v01", &"tower_modules:v01",
            &"encounters:v01", &"quest_flags:summoner_test")
        var next_manifest := TowerPrevalidatedFallbackFactory.build_for_request(next_request)
        var next_floor := TowerFloorGenerationCommitService.floor_state_from_manifest(
            StringName("floor_instance:summoner_test_%d" % floor_id), next_manifest)
        var next_shipped := TowerProductionEncounterContentCatalog.build_plan(next_floor)
        var next_reserved := SummonerReinforcementPlan.build(next_shipped, next_floor, encounter_id, TUNING)
        _expect(bool(next_reserved.get("accepted", false)),
            "shipped Floor %d plan reserves Summoner slots inside existing floor population" % floor_id)
    _expect(NON_DAMAGE.reinforcement_tuning == TUNING and TUNING.validate_tuning().is_empty(), "Inspector playtest resource provides valid bounded reinforcement authoring")
    _expect(TowerEncounterPlanValidator.validate(plan, floor).is_empty(), "real authored Floor 8 room accepts both residents")
    var authored := SummonerReinforcementPlan.build(plan, floor, encounter_id, TUNING)
    var slots := (authored.get("slots_by_summoner", {}) as Dictionary).get(summoner_id, []) as Array
    _expect(bool(authored.get("accepted", false)) and slots.size() == TUNING.calls_per_summoner, "finite slot plan reserves every reinforcement against Floor 8 population budget")
    _expect(slots.size() == 2 and (slots[0] as Dictionary).get("actor_id") != (slots[1] as Dictionary).get("actor_id") and (slots[0] as Dictionary).get("local_tile") != (slots[1] as Dictionary).get("local_tile"), "distinct stable actor IDs have distinct authored safe spawn tiles")
    if slots.size() != TUNING.calls_per_summoner:
        quit(_failures)
        return

    var host := TowerEncounterSessionHost.new()
    host.set_physics_process(false)
    root.add_child(host)
    var player := PlayerController.new()
    player.position = Vector2(-10000, -10000)
    host.set_decision_target(player)
    _expect(host.set_reinforcement_tuning(TUNING), "encounter host accepts validated Inspector-owned reinforcement authoring")
    var owner := EnemyNonDamagePlaytestDelivery.new()
    owner.content = NON_DAMAGE
    owner.status_tuning = STATUS
    owner.set_physics_process(false)
    root.add_child(owner)
    _expect(owner.configure(host, player), "non-damage owner connects live authenticated ACTIVE delivery")
    var enemy_states := TowerPrototypeEnemyRuntimeFactory.build_states(floor, plan, TUNING.enemy_state_tuning)
    var activated := host.activate_encounter(profile, floor, plan, encounter_id,
        _combatant(&"player:summoner_test"), enemy_states, VISUALS)
    _expect(bool(activated.get("accepted", false)), "Summoner and ally enter the real encounter runtime")
    _expect(host.has_reinforcement_budget(encounter_id, summoner_id), "Summoner decision receives a real finite reinforcement budget")
    var encounter := host.get_encounter_runtime(encounter_id)
    var runtime := host.get_archetype_runtime(encounter_id, summoner_id)
    var driver := host.get_action_phase_driver(encounter_id, summoner_id)
    _expect(_commit_to_active(runtime, driver, 81001), "Summoner finishes its authored interruptible windup")
    var first := owner.last_result.duplicate(true)
    var first_id := StringName(String((slots[0] as Dictionary)["actor_id"]))
    _expect(bool(first.get("accepted", false)) and first.get("actor_id") == first_id,
        "authenticated ACTIVE delivery registers first reserved reinforcement")
    _expect(encounter.get_combatant(first_id) != null and host.get_archetype_runtime(encounter_id, first_id) != null
        and host.get_movement_driver(encounter_id, first_id) != null and host.get_visuals_by_actor(encounter_id).has(first_id),
        "reinforcement receives real combatant, tactical phase, movement, and presentation")
    _expect(host.shared_full_ai.get_admitted_count() == 3, "reinforcement consumes exactly one shared FULL-AI slot")
    host.enemy_active_delivery_window_opened.emit(encounter_id, runtime.get_active_delivery_context(81001))
    _expect(not bool(owner.last_result.get("accepted", true)) and host.shared_full_ai.get_admitted_count() == 3,
        "replayed delivery cannot create a second actor or duplicate FULL-AI admission")

    for i: int in 9:
        _expect(host.shared_full_ai.try_admit(StringName("enemy:cap_fixture_%d" % i), &"encounter:cap_fixture"), "shared cap fixture admits actor %d" % i)
    _expect(host.shared_full_ai.get_admitted_count() == 12, "shared AI ledger reaches hard cap")
    _finish_action(driver)
    var blocked := driver.begin({"accepted": true, "tactic_id": runtime.definition.signature_action_id}, 81002,
        {"reinforcement_budget_available": true, "full_ai_slot_available": true})
    _expect(not bool(blocked.get("accepted", false)) and blocked.get("admission_reason_id") == EnemyArchetypeActionAdmission.REASON_FULL_AI_SLOT_REQUIRED,
        "shared cap rejects Summoner before windup; supplied facts cannot override live slot ownership")
    _expect(host.has_reinforcement_budget(encounter_id, summoner_id) and host.shared_full_ai.get_admitted_count() == 12,
        "rejected cap admission preserves the finite second call")
    for i: int in 9:
        host.shared_full_ai.release(StringName("enemy:cap_fixture_%d" % i))
    _finish_action(driver)
    _expect(_commit_to_active(runtime, driver, 81003), "Summoner may retry after FULL-AI capacity returns")
    var second_id := StringName(String((slots[1] as Dictionary)["actor_id"]))
    _expect(bool(owner.last_result.get("accepted", false)) and owner.last_result.get("actor_id") == second_id
        and host.shared_full_ai.get_admitted_count() == 4, "second finite call consumes one new actor and exactly one AI slot")
    _expect(not host.has_reinforcement_budget(encounter_id, summoner_id), "per-Summoner finite budget exhausts after two successful calls")
    _expect(bool(encounter.resolve_direct_contact(&"player:summoner_test", first_id, 81991, 0, _attack(), false,
        DirectHitResolver.DEFENSE_NONE, false).get("target_defeated", false)), "player defeats the first real reinforcement")
    _expect(floor.defeated_actor_ids.has(first_id) and host.shared_full_ai.get_admitted_count() == 3,
        "summoned defeat records the stable floor claim and frees its shared AI slot")
    _expect(host.end_encounter(encounter_id) and host.shared_full_ai.get_admitted_count() == 0,
        "encounter exit releases the Summoner, ally and remaining summoned actor without AI leakage")
    _expect(bool(host.activate_encounter(profile, floor, plan, encounter_id,
        _combatant(&"player:summoner_revisit"), enemy_states, VISUALS).get("accepted", false)),
        "encounter revisit can start with existing residents")
    var next_plan := host._sessions[encounter_id] as Dictionary
    var revisit_slots := (next_plan.get("reinforcements_by_summoner", {}) as Dictionary).get(summoner_id, []) as Array
    _expect(revisit_slots.size() == 2 and floor.defeated_actor_ids.has(first_id),
        "revisit retains authored fixed IDs and excludes the defeated actor from further admission")
    host.end_all_encounters()
    owner.queue_free()
    host.queue_free()
    player.free()
    await process_frame
    if _failures == 0:
        print("SUMMONER REINFORCEMENT PLAYTEST TEST PASS")
    else:
        push_error("SUMMONER REINFORCEMENT PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _commit_to_active(runtime: EnemyArchetypeRuntime, driver: EnemySignatureActionPhaseDriver, action_id: int) -> bool:
    if runtime == null or driver == null or not bool(driver.begin(
        {"accepted": true, "tactic_id": runtime.definition.signature_action_id}, action_id,
        {"reinforcement_budget_available": true, "full_ai_slot_available": true}).get("accepted", false)):
        return false
    for _tick: int in int(driver.timing["windup_ticks"]):
        if not driver.advance_fixed_tick():
            return false
    return runtime.phase_id == EnemyArchetypeRuntime.PHASE_ACTIVE


func _finish_action(driver: EnemySignatureActionPhaseDriver) -> void:
    for _tick: int in int(driver.timing["active_ticks"]) + int(driver.timing["recovery_ticks"]) + int(driver.timing["cooldown_ticks"]):
        driver.advance_fixed_tick()


func _placement(actor_id: StringName, archetype: StringName, encounter_id: StringName, tile: Vector2i) -> Dictionary:
    return {"actor_id": actor_id, "archetype_id": archetype, "encounter_id": encounter_id,
        "room_instance_id": &"room:objective_00", "local_tile": tile, "elite": false}


func _combatant(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, 100, 100.0, 0.0, 0.0, 20.0, true, false, false), "combatant %s valid" % String(actor_id))
    return state


func _attack() -> Dictionary:
    return {"domain": DirectHitResolver.DOMAIN_PHYSICAL, "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": 200.0, "dodgeable": true, "blockable": true, "parryable": true,
        "guard_pressure": 0.0, "critical_triggered": false, "critical_multiplier": 1.0,
        "weak_point_triggered": false, "weak_point_multiplier": 1.0}


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
