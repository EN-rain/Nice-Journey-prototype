extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_safe_checkpoint_map_floor_coherence()
    _test_profile_tower_safe_state_dependency()

    if _failures == 0:
        print("PROFILE SAFE STATE COHERENCE TEST PASS")
    else:
        push_error("PROFILE SAFE STATE COHERENCE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_safe_checkpoint_map_floor_coherence() -> void:
    var region := _safe_state(&"safe:region", &"region:3", 0)
    _expect(SafeCheckpointState.validate_dictionary(region).is_empty(), "floor-0 Region safe state remains valid without inventing Region map rules")

    var future_region := _safe_state(&"safe:future_region", &"region:future_alpha", 0)
    _expect(SafeCheckpointState.validate_dictionary(future_region).is_empty(), "floor-0 future Region map IDs remain forward-compatible")

    var tower := _safe_state(&"safe:tower4", &"tower:floor_4", 4)
    _expect(SafeCheckpointState.validate_dictionary(tower).is_empty(), "Tower safe state accepts the canonical map ID matching floor_id")

    var mismatched := _safe_state(&"safe:tower_mismatch", &"tower:floor_3", 4)
    _expect(_contains(SafeCheckpointState.validate_dictionary(mismatched), "map_id must match floor_id"), "Tower safe state rejects a canonical Tower map belonging to another floor")

    var non_tower := _safe_state(&"safe:tower_region_map", &"region:3", 4)
    _expect(_contains(SafeCheckpointState.validate_dictionary(non_tower), "map_id must match floor_id"), "positive Tower floor_id cannot persist with a Region map ID")


func _test_profile_tower_safe_state_dependency() -> void:
    var profile := ProfileCreationService.create_profile(1, "Safe Coherence", "melee")
    var floor := _floor_state(4)
    _expect(floor != null, "Tower floor dependency fixture builds")
    if floor == null:
        return

    profile.tower_floor_states["4"] = floor.to_dictionary()
    profile.safe_state = _safe_state(&"safe:tower4_profile", &"tower:floor_4", 4)
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "profile accepts Tower safe state with its matching persisted floor state")

    var missing := profile.to_dictionary().duplicate(true)
    missing["tower_floor_states"] = {}
    var missing_errors := ProfileSnapshot.validate_dictionary(missing)
    _expect(_contains(missing_errors, "references missing tower_floor_states[4]"), "profile rejects Tower safe state whose referenced floor state is absent")

    var wrong_key := profile.to_dictionary().duplicate(true)
    var states := wrong_key["tower_floor_states"] as Dictionary
    states["3"] = states["4"]
    states.erase("4")
    var wrong_key_errors := ProfileSnapshot.validate_dictionary(wrong_key)
    _expect(_contains(wrong_key_errors, "key must match entry floor_id") and _contains(wrong_key_errors, "references missing tower_floor_states[4]"), "profile rejects a Tower floor state stored under a key that disagrees with its floor_id and safe-state reference")

    var region_profile := ProfileCreationService.create_profile(2, "Region Safe", "ranged")
    region_profile.safe_state = _safe_state(&"safe:region_profile", &"region:3", 0)
    _expect(ProfileSnapshot.validate_dictionary(region_profile.to_dictionary()).is_empty(), "Region safe state does not require a Tower floor-state dependency")


func _safe_state(snapshot_id: StringName, map_id: StringName, floor_id: int) -> Dictionary:
    return {
        "snapshot_id": String(snapshot_id),
        "map_id": String(map_id),
        "floor_id": floor_id,
        "checkpoint_anchor_id": "checkpoint:test",
        "player_state": {},
        "quest_attempt_state": {},
        "snapshot_sequence": 1,
    }


func _floor_state(floor_id: int) -> FloorInstanceState:
    var floor := FloorInstanceState.new()
    floor.floor_id = floor_id
    floor.instance_id = StringName("floor_instance:safe_coherence_%d" % floor_id)
    floor.seed = 1000 + floor_id
    floor.layout_revision_id = StringName("layout:safe_coherence_%d" % floor_id)
    return floor if FloorInstanceState.validate_dictionary(floor.to_dictionary()).is_empty() else null


func _contains(errors: PackedStringArray, fragment: String) -> bool:
    for error: String in errors:
        if error.contains(fragment):
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
