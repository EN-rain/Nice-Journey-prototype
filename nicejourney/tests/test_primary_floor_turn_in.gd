extends SceneTree

const TEST_ROOT := "user://tests/primary_floor_turn_in"
var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var save_service := SaveService.new(TEST_ROOT)
    save_service.delete_slot(1)
    for floor_id: int in range(2, 10):
        _test_floor_commit(save_service, floor_id)
        save_service.delete_slot(1)
    _test_invalid_floor_rejected(save_service)
    _test_mismatched_safe_snapshot_rejected(save_service)
    save_service.delete_slot(1)
    if _failures == 0:
        print("PRIMARY FLOOR TURN-IN TEST PASS")
    else:
        push_error("PRIMARY FLOOR TURN-IN TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_floor_commit(save_service: SaveService, floor_id: int) -> void:
    var profile := _profile_for_floor(floor_id)
    _expect(profile != null, "Floor %d fixture profile exists" % floor_id)
    if profile == null:
        return
    var safe_state := _safe_state(floor_id)
    _expect(not safe_state.is_empty(), "Floor %d safe snapshot validates" % floor_id)
    var before_claims := profile.claimed_transactions.size()
    var result := PrimaryFloorTurnInService.commit_turn_in(save_service, 1, profile, floor_id, safe_state)
    _expect(bool(result.get("accepted", false)), "Floor %d primary turn-in commits" % floor_id)
    _expect(bool(profile.permanent_flags.get("tower_floor_%d_cleared" % floor_id, false)), "Floor %d clear flag commits" % floor_id)
    _expect(bool(profile.permanent_flags.get("tower_floor_%d_unlocked" % (floor_id + 1), false)), "Floor %d turn-in unlocks exactly the next prototype floor" % floor_id)
    _expect(StringName(String((profile.quest_progress["primary_floor_%d" % floor_id] as Dictionary).get("state", &""))) == QuestProgressState.STATE_COMPLETED, "Floor %d primary quest reaches Completed" % floor_id)
    _expect(bool((profile.tower_floor_states[str(floor_id)] as Dictionary).get("primary_cleared", false)), "Floor %d persistent floor instance records primary clear" % floor_id)
    _expect(profile.claimed_transactions.size() == before_claims + 1, "Floor %d completion claim commits exactly once" % floor_id)
    _expect(profile.safe_state == safe_state, "Floor %d completion advances the durable safe snapshot atomically" % floor_id)

    var duplicate := PrimaryFloorTurnInService.commit_turn_in(save_service, 1, profile, floor_id, safe_state)
    _expect(not bool(duplicate.get("accepted", true)), "Floor %d duplicate turn-in is rejected" % floor_id)
    _expect(profile.claimed_transactions.size() == before_claims + 1, "Floor %d duplicate turn-in cannot duplicate claim value" % floor_id)

    var loaded := save_service.load_profile(1)
    _expect(loaded != null, "Floor %d committed profile reloads" % floor_id)
    if loaded != null:
        _expect(bool(loaded.permanent_flags.get("tower_floor_%d_cleared" % floor_id, false)), "Floor %d clear survives reload" % floor_id)
        _expect(bool(loaded.permanent_flags.get("tower_floor_%d_unlocked" % (floor_id + 1), false)), "Floor %d next-floor unlock survives reload" % floor_id)
        _expect(bool((loaded.tower_floor_states[str(floor_id)] as Dictionary).get("primary_cleared", false)), "Floor %d floor-state clear survives reload" % floor_id)

func _test_invalid_floor_rejected(save_service: SaveService) -> void:
    var profile := _profile_for_floor(9)
    var safe_state := _safe_state(9)
    var result := PrimaryFloorTurnInService.commit_turn_in(save_service, 1, profile, 10, safe_state)
    _expect(not bool(result.get("accepted", true)) and StringName(result.get("reason_id", &"")) == &"invalid_context", "generic turn-in service cannot fabricate Floor 10/Floor 11 progression")

func _test_mismatched_safe_snapshot_rejected(save_service: SaveService) -> void:
    var profile := _profile_for_floor(4)
    var before := profile.to_dictionary()
    var result := PrimaryFloorTurnInService.commit_turn_in(save_service, 1, profile, 4, _safe_state(3))
    _expect(not bool(result.get("accepted", true)) and StringName(result.get("reason_id", &"")) == &"matching_floor_safe_snapshot_required", "turn-in requires a safe snapshot for the same floor")
    _expect(profile.to_dictionary() == before, "mismatched safe snapshot rejection mutates no profile state")

func _profile_for_floor(floor_id: int) -> ProfileSnapshot:
    var profile := ProfileCreationService.create_profile(1, "Turn In Tester", "melee")
    if profile == null:
        return null
    var quest_id := "primary_floor_%d" % floor_id
    profile.quest_progress[quest_id] = {
        "state": QuestProgressState.STATE_OBJECTIVES_COMPLETE,
        "stage_id": &"floor_objective",
        "attempt_id": StringName("attempt:floor_%d" % floor_id),
        "objective_state": {"fixture_complete": true},
    }
    var floor := FloorInstanceState.new()
    floor.floor_id = floor_id
    floor.instance_id = StringName("floor_instance:floor_%d" % floor_id)
    floor.seed = 10000 + floor_id
    floor.layout_revision_id = StringName("layout:floor_%d_fixture" % floor_id)
    profile.tower_floor_states[str(floor_id)] = floor.to_dictionary()
    profile.permanent_flags["tower_floor_%d_unlocked" % floor_id] = true
    if not ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty():
        return null
    return profile

func _safe_state(floor_id: int) -> Dictionary:
    return SafeCheckpointState.make(
        StringName("safe:floor_%d_turn_in" % floor_id),
        StringName("tower:floor_%d" % floor_id),
        floor_id,
        StringName("checkpoint:floor_%d_exit" % floor_id),
        {"hp": 100, "stamina": 100.0, "mana": 0.0},
        {"primary_floor": floor_id},
        floor_id
    )

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
