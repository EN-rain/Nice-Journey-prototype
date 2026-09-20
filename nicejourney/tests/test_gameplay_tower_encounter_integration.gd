extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TOWER_VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    await _test_live_gameplay_encounter_session()
    if _failures == 0:
        print("GAMEPLAY TOWER ENCOUNTER INTEGRATION TEST PASS")
    else:
        push_error("GAMEPLAY TOWER ENCOUNTER INTEGRATION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_live_gameplay_encounter_session() -> void:
    var profile := ProfileCreationService.create_profile(1, "Live Encounter", "melee")
    var floor := _floor_state(4, 44091)
    _expect(profile != null and TowerFloorStateService.commit_floor_state(profile, floor), "gameplay encounter fixture commits persistent floor state")
    profile.quest_progress["primary_floor_4"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:live_gameplay_floor4",
        "objective_state": {},
    }
    _expect(bool(QuestFamilyObjectiveService.bind(profile, &"primary_floor_4", {
        "required_actor_ids": [&"enemy:live_duelist", &"enemy:live_marksman"],
    }).get("accepted", false)), "live gameplay fixture binds designated annihilation group")

    var build := TowerFloorRuntimeComposer.build(floor.layout_manifest, TOWER_VISUAL_CATALOG)
    var arrival := TowerArrivalResolver.resolve_entrance(floor)
    _expect(bool(build.get("accepted", false)) and bool(arrival.get("accepted", false)), "gameplay encounter floor runtime and arrival validate")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    get_root().add_child(gameplay)
    await process_frame
    var root := build.get("root") as Node2D
    _expect(gameplay.activate_committed_tower_travel({"accepted": true, "runtime_root": root, "arrival": arrival}), "GameplayRoot activates generated Floor 4 before encounter session")

    var plan := {
        "plan_id": &"encounter_plan:live_gameplay_floor4",
        "floor_id": 4,
        "complete_floor_plan": false,
        "placements": [
            _placement(&"enemy:live_duelist", &"duelist", Vector2i(2, 2)),
            _placement(&"enemy:live_marksman", &"marksman", Vector2i(3, 2)),
        ],
    }
    var player_state := _combatant(&"player:live_gameplay", 100)
    var enemy_states := {
        &"enemy:live_duelist": _combatant(&"enemy:live_duelist", 20),
        &"enemy:live_marksman": _combatant(&"enemy:live_marksman", 20),
    }
    var bindings := {
        &"enemy:live_duelist": [{"quest_id": &"primary_floor_4"}],
        &"enemy:live_marksman": [{"quest_id": &"primary_floor_4"}],
    }
    var activated := gameplay.activate_tower_encounter(plan, &"encounter:live_floor4", player_state, enemy_states, bindings)
    _expect(bool(activated.get("accepted", false)), "GameplayRoot activates authoritative encounter/runtime/presentation inside live tower floor")
    _expect(gameplay.tower_encounter_session_host.get_active_encounter_count() == 1, "live GameplayRoot owns one active tower encounter session")
    _expect(not gameplay.operation_guard.is_allowed(GameplayOperationGuard.OP_SIGIL_TRAVEL), "live tower encounter immediately blocks Sigil travel through shared operation guard")
    _expect(gameplay.get_shared_full_ai_ledger().get_admitted_count() == 2, "live GameplayRoot encounter consumes shared FULL-AI capacity")

    var encounter := gameplay.tower_encounter_session_host.get_encounter_runtime(&"encounter:live_floor4")
    _expect(encounter != null, "live GameplayRoot exposes authoritative tower encounter runtime")
    if encounter != null:
        var incoming := encounter.resolve_direct_contact(&"enemy:live_duelist", player_state.actor_id, 49099, 0, _attack(7.0), false, DirectHitResolver.DEFENSE_NONE, true)
        _expect(bool(incoming.get("accepted", false)) and gameplay.player.health.current_hp == 93, "live GameplayRoot binds encounter-owned player HP back to the visible player HealthComponent")
        _expect(bool(encounter.resolve_direct_contact(player_state.actor_id, &"enemy:live_duelist", 49101, 0, _attack(100.0), false, DirectHitResolver.DEFENSE_NONE, false).get("target_defeated", false)), "first live resident defeats through authoritative contact")
        _expect(bool(encounter.resolve_direct_contact(player_state.actor_id, &"enemy:live_marksman", 49102, 0, _attack(100.0), false, DirectHitResolver.DEFENSE_NONE, false).get("target_defeated", false)), "second live resident defeats through authoritative contact")
        _expect(bool(encounter.apply_status_to_target(player_state.actor_id, {
            "status_id": &"burn:gameplay_persist",
            "behavior": PrototypeStatusResolver.BEHAVIOR_BURN,
            "magnitude": 1.0,
            "duration_ticks": 75,
        }).get("accepted", false)), "live encounter can own a supported player status before safe teardown")
    await process_frame
    _expect(gameplay.operation_guard.is_allowed(GameplayOperationGuard.OP_SIGIL_TRAVEL), "shared operation guard releases Sigil travel after the encounter has no active enemies")
    _expect(StringName(String((profile.quest_progress["primary_floor_4"] as Dictionary).get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "live gameplay combat advances bound floor objective")
    var stored_floor := profile.tower_floor_states.get("4", {}) as Dictionary
    _expect((stored_floor.get("defeated_actor_ids", []) as Array).size() == 2, "live gameplay combat persists both defeated residents to floor state")
    var remaining_before_end := -1
    if encounter != null:
        remaining_before_end = _remaining_status_ticks(encounter.get_status_states(player_state.actor_id), &"burn:gameplay_persist")
    _expect(remaining_before_end > 0, "live player status still has a supported remaining duration at normal encounter teardown")
    _expect(gameplay.end_tower_encounter(&"encounter:live_floor4"), "GameplayRoot closes completed tower encounter session explicitly")
    await process_frame
    _expect(gameplay.tower_encounter_session_host.get_active_encounter_count() == 0, "completed live encounter presentation/session cleans up")
    _expect(_remaining_status_ticks(gameplay.combat_runtime.get_status_safe_states(), &"burn:gameplay_persist") == remaining_before_end, "normal GameplayRoot encounter teardown hands the exact remaining player status duration to the coherent safe-state owner")
    gameplay.queue_free()
    await process_frame

func _floor_state(floor_id: int, seed: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id, seed, &"tower_generator:v01", &"tower_modules:v01", &"encounters:v01", &"quest_flags:gameplay_encounter_test"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    var state := TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:gameplay_encounter_%d_%d" % [floor_id, seed]), manifest
    )
    _expect(state != null, "Floor %d gameplay encounter fixture builds" % floor_id)
    return state

func _placement(actor_id: StringName, archetype_id: StringName, local_tile: Vector2i) -> Dictionary:
    return {
        "actor_id": actor_id,
        "archetype_id": archetype_id,
        "encounter_id": &"encounter:live_floor4",
        "room_instance_id": &"room:objective_00",
        "local_tile": local_tile,
        "elite": false,
    }

func _combatant(actor_id: StringName, hp: int) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, hp, 100.0, 0.0, 0.0, 10.0, true, false, false), "combatant fixture configures: %s" % String(actor_id))
    return state

func _remaining_status_ticks(states: Array, status_id: StringName) -> int:
    for raw_state: Variant in states:
        if raw_state is Dictionary and StringName(String((raw_state as Dictionary).get("status_id", &""))) == status_id:
            return int((raw_state as Dictionary).get("remaining_ticks", -1))
    return -1


func _attack(raw_damage: float) -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": raw_damage,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 0.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
