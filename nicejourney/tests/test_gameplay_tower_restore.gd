extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    await _test_exact_saved_arrival_restore()
    await _test_unresolved_checkpoint_falls_back_to_entrance()
    if _failures == 0:
        print("GAMEPLAY TOWER RESTORE TEST PASS")
    else:
        push_error("GAMEPLAY TOWER RESTORE TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_exact_saved_arrival_restore() -> void:
    var fixture := _profile_with_floor_safe_state(false)
    _expect(bool(fixture.get("accepted", false)), "exact tower restore fixture builds")
    if not bool(fixture.get("accepted", false)):
        return
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(fixture["profile"] as ProfileSnapshot)
    get_root().add_child(gameplay)
    await process_frame
    _expect(gameplay.is_tower_floor_active(), "loading a tower safe snapshot restores the generated tower floor instead of foundation greybox")
    _expect(bool(gameplay.tower_restore_status.get("accepted", false)), "tower restore exposes successful restoration status")
    _expect(not bool(gameplay.tower_restore_status.get("fallback_to_entrance", true)), "matching saved entrance anchor restores without fallback")
    _expect(gameplay.tower_floor_session_host.active_floor_id == 2, "restored tower session keeps saved floor identity")
    gameplay.queue_free()
    await process_frame

func _test_unresolved_checkpoint_falls_back_to_entrance() -> void:
    var fixture := _profile_with_floor_safe_state(true)
    _expect(bool(fixture.get("accepted", false)), "checkpoint-fallback tower restore fixture builds")
    if not bool(fixture.get("accepted", false)):
        return
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(fixture["profile"] as ProfileSnapshot)
    get_root().add_child(gameplay)
    await process_frame
    _expect(gameplay.is_tower_floor_active(), "unresolved saved checkpoint still restores the persistent floor safely")
    _expect(bool(gameplay.tower_restore_status.get("fallback_to_entrance", false)), "unresolved checkpoint explicitly reports entrance fallback")
    _expect(gameplay.tower_restore_status.get("fallback_reason_id", &"") == TowerArrivalResolver.REASON_CHECKPOINT_UNRESOLVED, "checkpoint fallback has a recoverable explicit reason")
    var arrival := gameplay.tower_restore_status.get("arrival", {}) as Dictionary
    _expect(StringName(String(arrival.get("requested_checkpoint_anchor_id", &""))) == &"checkpoint:unresolved_fixture", "restore preserves the unresolved requested checkpoint identity for UI notification")
    gameplay.queue_free()
    await process_frame

func _profile_with_floor_safe_state(use_unresolved_checkpoint: bool) -> Dictionary:
    var profile := ProfileCreationService.create_profile(1, "Restore Fixture", "mage")
    if profile == null:
        return {"accepted": false}
    var request := TowerFloorGenerationCommitService.build_request(
        2,
        99202,
        &"generator:restore_v01",
        &"modules:prototype_v01",
        &"encounters:prototype_v01",
        &"questflags:restore_v01"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return {"accepted": false}
    var state := TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:restore_floor2", manifest)
    if state == null or not TowerFloorStateService.commit_floor_state(profile, state):
        return {"accepted": false}
    var entrance := TowerArrivalResolver.resolve_entrance(state)
    if not bool(entrance.get("accepted", false)):
        return {"accepted": false}
    var checkpoint_anchor := StringName(String(entrance["arrival_anchor_id"]))
    if use_unresolved_checkpoint:
        checkpoint_anchor = &"checkpoint:unresolved_fixture"
        state.add_checkpoint(checkpoint_anchor)
        if not TowerFloorStateService.commit_floor_state(profile, state):
            return {"accepted": false}
    profile.safe_state = SafeCheckpointState.make(
        &"safe:restore_floor2",
        &"tower:floor_2",
        2,
        checkpoint_anchor,
        {"hp": 100, "stamina": 100.0},
        {"primary_floor_2": {"stage": "floor_objective"}},
        7
    )
    if profile.safe_state.is_empty() or not ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty():
        return {"accepted": false}
    return {"accepted": true, "profile": profile}

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
