extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    await _test_floor10_preboss_checkpoint_round_trip()
    _test_anchor_schema_and_unresolved_fallback()
    if _failures == 0:
        print("TOWER CHECKPOINT ARRIVAL TEST PASS")
    else:
        push_error("TOWER CHECKPOINT ARRIVAL TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_floor10_preboss_checkpoint_round_trip() -> void:
    var profile := ProfileCreationService.create_profile(1, "Checkpoint Restore", "melee")
    var floor := _floor_state(10, 101010)
    _expect(profile != null and floor != null, "Floor 10 checkpoint fixture creates")
    if profile == null or floor == null:
        return
    _expect(floor.checkpoint_ids.has(&"checkpoint:floor10_preboss"), "Floor 10 generated state automatically owns required pre-boss checkpoint identity")
    var anchor := floor.get_checkpoint_anchor(&"checkpoint:floor10_preboss")
    _expect(not anchor.is_empty() and StringName(String(anchor.get("room_instance_id", &""))) == &"room:preboss_safe", "Floor 10 pre-boss checkpoint binds to the generated safe room")
    var arrival := TowerArrivalResolver.resolve_checkpoint(floor, &"checkpoint:floor10_preboss")
    _expect(bool(arrival.get("accepted", false)) and StringName(String(arrival.get("arrival_kind", &""))) == &"checkpoint", "authored pre-boss checkpoint resolves to a safe tower arrival")
    _expect(StringName(String(arrival.get("room_instance_id", &""))) == &"room:preboss_safe", "resolved checkpoint remains in the safe pre-boss room")

    _expect(TowerFloorStateService.commit_floor_state(profile, floor), "Floor 10 state with anchored checkpoint commits to profile")
    profile.safe_state = SafeCheckpointState.make(
        &"safe:floor10_preboss_restore",
        &"tower:floor_10",
        10,
        &"checkpoint:floor10_preboss",
        {"hp": 100, "stamina": 100.0},
        {"primary_floor_10": {"stage": "floor_objective"}},
        10
    )
    _expect(not profile.safe_state.is_empty() and ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "anchored checkpoint profile remains schema-valid")
    var round_trip := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    _expect(round_trip != null, "anchored checkpoint survives profile serialization")
    var loaded_floor := FloorInstanceState.new()
    if round_trip != null:
        _expect(loaded_floor.load_dictionary(round_trip.tower_floor_states["10"] as Dictionary).is_empty(), "anchored checkpoint survives FloorInstanceState reload")
        var restored_arrival := TowerArrivalResolver.resolve_saved_safe_state(loaded_floor, round_trip.safe_state)
        _expect(bool(restored_arrival.get("accepted", false)) and not bool(restored_arrival.get("fallback_to_entrance", true)), "saved pre-boss checkpoint resolves directly without entrance fallback")
        _expect(StringName(String(restored_arrival.get("arrival_anchor_id", &""))) == &"checkpoint:floor10_preboss", "restored arrival preserves exact checkpoint identity")

        var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
        gameplay.set_profile(round_trip)
        get_root().add_child(gameplay)
        await process_frame
        _expect(gameplay.is_tower_floor_active() and gameplay.tower_floor_session_host.active_floor_id == 10, "GameplayRoot reload restores persistent Floor 10 session")
        _expect(not bool(gameplay.tower_restore_status.get("fallback_to_entrance", true)), "GameplayRoot reload uses the anchored pre-boss checkpoint instead of fallback entrance")
        _expect(StringName(String((gameplay.tower_restore_status.get("arrival", {}) as Dictionary).get("arrival_anchor_id", &""))) == &"checkpoint:floor10_preboss", "GameplayRoot arrival status reports the exact pre-boss checkpoint")
        gameplay.queue_free()
        await process_frame

func _test_anchor_schema_and_unresolved_fallback() -> void:
    var floor := _floor_state(2, 202020)
    _expect(floor != null, "checkpoint schema fixture creates")
    if floor == null:
        return
    var legacy := floor.to_dictionary()
    legacy.erase("checkpoint_anchors")
    _expect(FloorInstanceState.validate_dictionary(legacy).is_empty(), "older floor state without checkpoint_anchors remains backward compatible")
    var legacy_loaded := FloorInstanceState.new()
    _expect(legacy_loaded.load_dictionary(legacy).is_empty() and legacy_loaded.checkpoint_anchors.is_empty(), "legacy floor state loads with an empty anchor registry")

    _expect(floor.add_checkpoint(&"checkpoint:unanchored"), "legacy ID-only checkpoint remains representable")
    var unresolved := TowerArrivalResolver.resolve_checkpoint(floor, &"checkpoint:unanchored")
    _expect(not bool(unresolved.get("accepted", false)) and unresolved.get("reason_id", &"") == TowerArrivalResolver.REASON_CHECKPOINT_UNRESOLVED, "ID-only checkpoint does not fabricate a world position")

    var malformed := floor.to_dictionary()
    malformed["checkpoint_anchors"] = {
        "checkpoint:not_listed": {"room_instance_id": "room:entrance", "local_tile_x": 3, "local_tile_y": 3}
    }
    _expect(not FloorInstanceState.validate_dictionary(malformed).is_empty(), "checkpoint anchor must also be declared in checkpoint_ids")

func _floor_state(floor_id: int, seed: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id, seed, &"tower_generator:v01", &"tower_modules:v01", &"encounters:v01", &"quest_flags:checkpoint_arrival_test"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return null
    return TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:checkpoint_arrival_%d_%d" % [floor_id, seed]), manifest
    )

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
