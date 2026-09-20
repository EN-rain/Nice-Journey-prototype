extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service := SaveService.new("user://tests/manual_save_request_service")
    for slot_index: int in range(1, SaveService.SLOT_COUNT + 1):
        save_service.delete_slot(slot_index)

    _test_safe_region_manual_save(save_service)
    _test_guard_rejection_does_not_capture(save_service)
    _test_invalid_safe_state_fails_closed(save_service)
    _test_tower_floor_state_is_required(save_service)

    for slot_index: int in range(1, SaveService.SLOT_COUNT + 1):
        save_service.delete_slot(slot_index)
    if _failures == 0:
        print("MANUAL SAVE REQUEST SERVICE TEST PASS")
    else:
        push_error("MANUAL SAVE REQUEST SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_safe_region_manual_save(save_service: SaveService) -> void:
    var guard := GameplayOperationGuard.new()
    var coordinator := SaveRequestCoordinator.new(save_service, guard)
    var profile := _profile(&"profile:manual_region")
    profile.xp = 42
    profile.safe_state = _safe_state(&"safe:old", &"region:3", 0, &"checkpoint:old", 1)
    var new_safe := _safe_state(&"safe:manual", &"region:3", 0, &"checkpoint:region3_town", 2)
    var provider_calls := {"count": 0}

    var status := ManualSaveRequestService.request(
        coordinator,
        1,
        profile,
        func() -> Dictionary:
            provider_calls["count"] = int(provider_calls["count"]) + 1
            return new_safe
    )
    _expect(StringName(status.get("state", &"")) == SaveRequestCoordinator.STATE_SUCCEEDED, "safe manual save commits through SaveRequestCoordinator")
    _expect(int(provider_calls["count"]) == 1, "safe-state provider is captured exactly once at admitted commit time")
    _expect(profile.safe_state == new_safe, "durable manual save advances the live profile safe-state marker")
    var loaded := save_service.load_profile(1)
    _expect(
        loaded != null
        and loaded.xp == 42
        and StringName(String(loaded.safe_state.get("snapshot_id", ""))) == &"safe:manual"
        and StringName(String(loaded.safe_state.get("map_id", ""))) == &"region:3"
        and int(loaded.safe_state.get("floor_id", -1)) == 0
        and StringName(String(loaded.safe_state.get("checkpoint_anchor_id", ""))) == &"checkpoint:region3_town"
        and int(loaded.safe_state.get("snapshot_sequence", -1)) == 2,
        "manual save persists current profile state and the same coherent safe snapshot identity"
    )
    guard.free()


func _test_guard_rejection_does_not_capture(save_service: SaveService) -> void:
    save_service.delete_slot(2)
    var guard := GameplayOperationGuard.new()
    var coordinator := SaveRequestCoordinator.new(save_service, guard)
    var profile := _profile(&"profile:manual_blocked")
    var old_safe := _safe_state(&"safe:block_old", &"region:3", 0, &"checkpoint:region3_town", 1)
    profile.safe_state = old_safe.duplicate(true)
    var provider_calls := {"count": 0}
    var blocker := guard.acquire_blocker(
        &"combat:test_manual_save",
        GameplayOperationGuard.REASON_ACTIVE_COMBAT,
        "Active combat is unresolved.",
        [GameplayOperationGuard.OP_MANUAL_SAVE]
    )

    var status := ManualSaveRequestService.request(
        coordinator,
        2,
        profile,
        func() -> Dictionary:
            provider_calls["count"] = int(provider_calls["count"]) + 1
            return _safe_state(&"safe:should_not_capture", &"region:3", 0, &"checkpoint:region3_town", 2)
    )
    _expect(StringName(status.get("state", &"")) == SaveRequestCoordinator.STATE_FAILED and StringName(status.get("reason_id", &"")) == GameplayOperationGuard.REASON_ACTIVE_COMBAT, "unsafe manual save preserves the coordinator's explicit guard reason")
    _expect(int(provider_calls["count"]) == 0, "guard-rejected manual save does not capture a speculative safe snapshot")
    _expect(profile.safe_state == old_safe and save_service.load_profile(2) == null, "guard rejection mutates neither live nor durable safe state")
    guard.release_blocker(blocker)
    guard.free()


func _test_invalid_safe_state_fails_closed(save_service: SaveService) -> void:
    save_service.delete_slot(3)
    var guard := GameplayOperationGuard.new()
    var coordinator := SaveRequestCoordinator.new(save_service, guard)
    var profile := _profile(&"profile:manual_invalid")
    var before := _safe_state(&"safe:before_invalid", &"region:3", 0, &"checkpoint:region3_town", 1)
    profile.safe_state = before.duplicate(true)

    var status := ManualSaveRequestService.request(
        coordinator,
        3,
        profile,
        func() -> Dictionary:
            return {"floor_id": 0}
    )
    _expect(StringName(status.get("state", &"")) == SaveRequestCoordinator.STATE_FAILED and StringName(status.get("reason_id", &"")) == SaveRequestCoordinator.REASON_SNAPSHOT_CAPTURE_FAILED, "incomplete safe-state data fails before durable commit")
    _expect(profile.safe_state == before and save_service.load_profile(3) == null, "invalid safe-state capture preserves prior live state and writes nothing")
    guard.free()


func _test_tower_floor_state_is_required(save_service: SaveService) -> void:
    save_service.delete_slot(3)
    var guard := GameplayOperationGuard.new()
    var coordinator := SaveRequestCoordinator.new(save_service, guard)
    var profile := _profile(&"profile:manual_tower")
    var floor_safe := _safe_state(&"safe:tower_floor_4", &"tower:floor_4", 4, &"checkpoint:floor_4", 1)

    var missing_floor := ManualSaveRequestService.request(coordinator, 3, profile, func() -> Dictionary: return floor_safe)
    _expect(StringName(missing_floor.get("state", &"")) == SaveRequestCoordinator.STATE_FAILED and StringName(missing_floor.get("reason_id", &"")) == SaveRequestCoordinator.REASON_SNAPSHOT_CAPTURE_FAILED, "Tower manual save rejects when the matching persisted floor state is absent")

    var floor := FloorInstanceState.new()
    floor.floor_id = 4
    floor.instance_id = &"floor_instance:manual:4"
    floor.seed = 404
    floor.layout_revision_id = &"tower_layout:manual:4"
    floor.layout_manifest = {}
    profile.tower_floor_states["4"] = floor.to_dictionary()
    var accepted := ManualSaveRequestService.request(coordinator, 3, profile, func() -> Dictionary: return floor_safe)
    _expect(StringName(accepted.get("state", &"")) == SaveRequestCoordinator.STATE_SUCCEEDED, "Tower manual save accepts after matching floor persistence is valid")
    var loaded := save_service.load_profile(3)
    _expect(loaded != null and int(loaded.safe_state.get("floor_id", 0)) == 4 and loaded.tower_floor_states.has("4"), "Tower manual save commits safe state with its matching floor instance state")
    guard.free()


func _profile(profile_id: StringName) -> ProfileSnapshot:
    var profile := ProfileSnapshot.new()
    profile.profile_id = String(profile_id)
    profile.protagonist_name = "Manual Save"
    profile.class_id = "melee"
    profile.level = 1
    profile.xp = 0
    profile.skill_points = 0
    return profile


func _safe_state(snapshot_id: StringName, map_id: StringName, floor_id: int, checkpoint_id: StringName, sequence: int) -> Dictionary:
    return SafeCheckpointState.make(
        snapshot_id,
        map_id,
        floor_id,
        checkpoint_id,
        {"position_x": 0.0, "position_y": 0.0},
        {"quest_progress": {}},
        sequence
    )


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
