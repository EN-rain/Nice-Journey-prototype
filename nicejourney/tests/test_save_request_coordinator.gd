extends SceneTree

class FailingSaveService:
    extends SaveService

    func save_profile(_slot_index: int, _profile: ProfileSnapshot) -> int:
        return ERR_CANT_CREATE

class SnapshotProviderNode:
    extends Node

    var profile: ProfileSnapshot = null

    func capture() -> ProfileSnapshot:
        return profile

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var service: SaveService = SaveService.new("user://tests/save_request_coordinator")
    for slot_index: int in range(1, SaveService.SLOT_COUNT + 1):
        service.delete_slot(slot_index)

    var guard: GameplayOperationGuard = GameplayOperationGuard.new()
    var coordinator: SaveRequestCoordinator = SaveRequestCoordinator.new(service, guard)
    var blocker_token: int = guard.acquire_blocker(
        &"encounter:test",
        GameplayOperationGuard.REASON_ACTIVE_COMBAT,
        "Active combat is unresolved.",
        [GameplayOperationGuard.OP_MANUAL_SAVE]
    )
    var generation_token: int = guard.acquire_blocker(
        &"generator:test",
        GameplayOperationGuard.REASON_GENERATOR_CONSTRUCTION,
        "Generation is still being finalized.",
        [GameplayOperationGuard.OP_MANUAL_SAVE]
    )

    var live_state: Dictionary = {"slot_1_xp": 10, "slot_2_xp": 20}
    var provider_calls: Dictionary = {"slot_1": 0, "slot_2": 0, "manual": 0}
    var slot_1_provider: Callable = func() -> ProfileSnapshot:
        provider_calls["slot_1"] = int(provider_calls["slot_1"]) + 1
        return _make_profile("profile:slot_1", "Autosave", int(live_state["slot_1_xp"]))
    var slot_2_provider: Callable = func() -> ProfileSnapshot:
        provider_calls["slot_2"] = int(provider_calls["slot_2"]) + 1
        return _make_profile("profile:slot_2", "Checkpoint", int(live_state["slot_2_xp"]))
    var manual_provider: Callable = func() -> ProfileSnapshot:
        provider_calls["manual"] = int(provider_calls["manual"]) + 1
        return _make_profile("profile:slot_1", "Manual", 30)

    var autosave_status: Dictionary = coordinator.request_save(1, SaveRequestCoordinator.REQUEST_AUTOSAVE, slot_1_provider)
    var checkpoint_status: Dictionary = coordinator.request_save(2, SaveRequestCoordinator.REQUEST_CHECKPOINT, slot_2_provider)
    _expect(StringName(autosave_status["state"]) == SaveRequestCoordinator.STATE_PENDING, "unsafe autosave reports pending")
    _expect(StringName(checkpoint_status["state"]) == SaveRequestCoordinator.STATE_PENDING, "unsafe checkpoint reports pending")
    _expect(StringName(autosave_status["reason_id"]) == GameplayOperationGuard.REASON_ACTIVE_COMBAT, "pending autosave surfaces the guard reason ID")
    _expect(String(autosave_status["reason_text"]) == "Active combat is unresolved.", "pending autosave surfaces the guard reason text")
    _expect(int(provider_calls["slot_1"]) == 0 and int(provider_calls["slot_2"]) == 0, "queued requests do not capture a request-time snapshot")
    _expect(service.load_profile(1) == null and service.load_profile(2) == null, "queued requests do not write before a safe boundary")

    var manual_status: Dictionary = coordinator.request_save(1, SaveRequestCoordinator.REQUEST_MANUAL, manual_provider)
    _expect(StringName(manual_status["state"]) == SaveRequestCoordinator.STATE_FAILED, "unsafe manual save reports a restriction instead of pending durability")
    _expect(StringName(manual_status["reason_id"]) == GameplayOperationGuard.REASON_ACTIVE_COMBAT, "manual restriction surfaces the guard reason")
    _expect(int(provider_calls["manual"]) == 0 and service.load_profile(1) == null, "restricted manual save neither captures nor writes")
    _expect(StringName(coordinator.get_status(1)["state"]) == SaveRequestCoordinator.STATE_PENDING, "manual rejection cannot hide an existing queued autosave")

    var invalid_kind_status: Dictionary = coordinator.request_save(1, &"unsupported", slot_1_provider)
    _expect(StringName(invalid_kind_status["state"]) == SaveRequestCoordinator.STATE_FAILED, "invalid request kind fails independently")
    _expect(StringName(coordinator.get_status(1)["state"]) == SaveRequestCoordinator.STATE_PENDING, "invalid request kind cannot hide an existing queued autosave")
    var invalid_provider_status: Dictionary = coordinator.request_save(1, SaveRequestCoordinator.REQUEST_AUTOSAVE, Callable())
    _expect(StringName(invalid_provider_status["state"]) == SaveRequestCoordinator.STATE_FAILED, "invalid snapshot provider fails independently")
    _expect(StringName(coordinator.get_status(1)["state"]) == SaveRequestCoordinator.STATE_PENDING, "invalid provider cannot hide an existing queued autosave")

    live_state["slot_1_xp"] = 111
    live_state["slot_2_xp"] = 222
    _expect(guard.release_blocker(blocker_token), "first blocker releases without declaring the slot safe")
    _expect(StringName(coordinator.get_status(1)["reason_id"]) == GameplayOperationGuard.REASON_GENERATOR_CONSTRUCTION, "pending status advances to the next ordered guard reason")
    _expect(int(provider_calls["slot_1"]) == 0 and int(provider_calls["slot_2"]) == 0, "partial blocker release does not capture queued state")
    _expect(guard.release_blocker(generation_token), "final blocker releases the save guard")
    _expect(int(provider_calls["slot_1"]) == 0 and int(provider_calls["slot_2"]) == 0, "final blocker release still does not capture before boundary finalization")
    _expect(StringName(coordinator.get_status(1)["state"]) == SaveRequestCoordinator.STATE_PENDING, "released guard leaves queued autosave visibly pending until the safe-boundary pump")
    live_state["slot_1_xp"] = 112
    live_state["slot_2_xp"] = 223
    coordinator.process_pending()
    _expect(int(provider_calls["slot_1"]) == 1 and int(provider_calls["slot_2"]) == 1, "safe boundary captures each queued slot exactly once")
    _expect(StringName(coordinator.get_status(1)["state"]) == SaveRequestCoordinator.STATE_SUCCEEDED, "autosave status becomes succeeded after commit")
    _expect(StringName(coordinator.get_status(2)["state"]) == SaveRequestCoordinator.STATE_SUCCEEDED, "checkpoint status becomes succeeded after commit")

    var slot_1_saved: ProfileSnapshot = service.load_profile(1)
    var slot_2_saved: ProfileSnapshot = service.load_profile(2)
    _expect(slot_1_saved != null and slot_1_saved.xp == 112, "slot 1 commits fresh post-finalization safe-boundary state")
    _expect(slot_2_saved != null and slot_2_saved.xp == 223, "slot 2 commits its own fresh post-finalization safe-boundary state")
    _expect(slot_1_saved != null and slot_2_saved != null and slot_1_saved.profile_id != slot_2_saved.profile_id, "queued slot commits remain isolated")

    service.delete_slot(1)
    var coalesce_guard: GameplayOperationGuard = GameplayOperationGuard.new()
    var coalesce_coordinator: SaveRequestCoordinator = SaveRequestCoordinator.new(service, coalesce_guard)
    var coalesce_token: int = coalesce_guard.acquire_blocker(
        &"encounter:coalesce",
        GameplayOperationGuard.REASON_ACTIVE_COMBAT,
        "Active combat is unresolved.",
        [GameplayOperationGuard.OP_MANUAL_SAVE]
    )
    var coalesce_calls: Dictionary = {"first": 0, "latest": 0}
    var first_pending: Dictionary = coalesce_coordinator.request_save(
        1,
        SaveRequestCoordinator.REQUEST_AUTOSAVE,
        func() -> ProfileSnapshot:
            coalesce_calls["first"] = int(coalesce_calls["first"]) + 1
            return _make_profile("profile:slot_1", "First", 300)
    )
    var latest_pending: Dictionary = coalesce_coordinator.request_save(
        1,
        SaveRequestCoordinator.REQUEST_CHECKPOINT,
        func() -> ProfileSnapshot:
            coalesce_calls["latest"] = int(coalesce_calls["latest"]) + 1
            return _make_profile("profile:slot_1", "Latest", 301)
    )
    _expect(StringName(first_pending["state"]) == SaveRequestCoordinator.STATE_PENDING and StringName(latest_pending["state"]) == SaveRequestCoordinator.STATE_PENDING, "same-slot save requests remain bounded to pending state")
    _expect(int(coalesce_coordinator.get_status(1)["request_id"]) == int(latest_pending["request_id"]), "same-slot pending request coalesces to the latest request")
    _expect(StringName(coalesce_coordinator.get_status(1)["request_kind"]) == SaveRequestCoordinator.REQUEST_CHECKPOINT, "same-slot coalescing keeps the latest request kind")
    coalesce_guard.release_blocker(coalesce_token)
    coalesce_coordinator.process_pending()
    _expect(int(coalesce_calls["first"]) == 0 and int(coalesce_calls["latest"]) == 1, "same-slot coalescing invokes only the latest provider")
    var coalesced_saved: ProfileSnapshot = service.load_profile(1)
    _expect(coalesced_saved != null and coalesced_saved.xp == 301, "same-slot coalescing commits only the latest snapshot")

    service.delete_slot(1)
    service.delete_slot(2)
    var invalidated_guard: GameplayOperationGuard = GameplayOperationGuard.new()
    var invalidated_coordinator: SaveRequestCoordinator = SaveRequestCoordinator.new(service, invalidated_guard)
    var invalidated_token: int = invalidated_guard.acquire_blocker(
        &"encounter:invalidated_provider",
        GameplayOperationGuard.REASON_ACTIVE_COMBAT,
        "Active combat is unresolved.",
        [GameplayOperationGuard.OP_MANUAL_SAVE]
    )
    var provider_node: SnapshotProviderNode = SnapshotProviderNode.new()
    provider_node.profile = _make_profile("profile:slot_1", "Freed Provider", 500)
    var queued_callable: Callable = Callable(provider_node, &"capture")
    invalidated_coordinator.request_save(1, SaveRequestCoordinator.REQUEST_AUTOSAVE, queued_callable)
    invalidated_coordinator.request_save(
        2,
        SaveRequestCoordinator.REQUEST_CHECKPOINT,
        func() -> ProfileSnapshot: return _make_profile("profile:slot_2", "Independent", 501)
    )
    provider_node.free()
    invalidated_guard.release_blocker(invalidated_token)
    invalidated_coordinator.process_pending()
    var invalidated_status: Dictionary = invalidated_coordinator.get_status(1)
    var isolated_status: Dictionary = invalidated_coordinator.get_status(2)
    _expect(StringName(invalidated_status["state"]) == SaveRequestCoordinator.STATE_FAILED, "freed queued provider fails cleanly at the safe-boundary pump")
    _expect(StringName(invalidated_status["reason_id"]) == SaveRequestCoordinator.REASON_SNAPSHOT_CAPTURE_FAILED, "freed queued provider reports snapshot capture failure")
    _expect(StringName(isolated_status["state"]) == SaveRequestCoordinator.STATE_SUCCEEDED, "one slot provider failure does not block another slot commit")
    _expect(service.load_profile(1) == null and service.load_profile(2) != null and service.load_profile(2).xp == 501, "provider failure remains isolated to its slot")
    var invalidated_request_id: int = int(invalidated_status["request_id"])
    invalidated_coordinator.process_pending()
    _expect(int(invalidated_coordinator.get_status(1)["request_id"]) == invalidated_request_id and StringName(invalidated_coordinator.get_status(1)["state"]) == SaveRequestCoordinator.STATE_FAILED, "failed queued provider is removed and is not retried")

    service.delete_slot(3)
    var safe_guard: GameplayOperationGuard = GameplayOperationGuard.new()
    var safe_coordinator: SaveRequestCoordinator = SaveRequestCoordinator.new(service, safe_guard)
    var safe_manual_status: Dictionary = safe_coordinator.request_save(
        3,
        SaveRequestCoordinator.REQUEST_MANUAL,
        func() -> ProfileSnapshot: return _make_profile("profile:slot_3", "Durable", 700)
    )
    _expect(StringName(safe_manual_status["state"]) == SaveRequestCoordinator.STATE_SUCCEEDED, "safe manual save commits immediately")
    _expect(service.load_profile(3) != null and service.load_profile(3).xp == 700, "safe manual save is durable through SaveService")
    var wrong_type_status: Dictionary = safe_coordinator.request_save(
        3,
        SaveRequestCoordinator.REQUEST_MANUAL,
        func() -> Variant: return {"xp": 999}
    )
    _expect(StringName(wrong_type_status["state"]) == SaveRequestCoordinator.STATE_FAILED and StringName(wrong_type_status["reason_id"]) == SaveRequestCoordinator.REASON_SNAPSHOT_CAPTURE_FAILED, "non-ProfileSnapshot provider result fails before save commit")
    _expect(service.load_profile(3) != null and service.load_profile(3).xp == 700, "non-ProfileSnapshot provider preserves the prior valid save")
    var invalid_profile: ProfileSnapshot = _make_profile("bad id", "Invalid", 999)
    var invalid_profile_status: Dictionary = safe_coordinator.request_save(
        3,
        SaveRequestCoordinator.REQUEST_MANUAL,
        func() -> ProfileSnapshot: return invalid_profile
    )
    _expect(StringName(invalid_profile_status["state"]) == SaveRequestCoordinator.STATE_FAILED and int(invalid_profile_status["error_code"]) == ERR_INVALID_DATA, "invalid ProfileSnapshot surfaces SaveService validation failure")
    _expect(service.load_profile(3) != null and service.load_profile(3).xp == 700, "invalid ProfileSnapshot preserves the prior valid save")

    var failing_guard: GameplayOperationGuard = GameplayOperationGuard.new()
    var failing_coordinator: SaveRequestCoordinator = SaveRequestCoordinator.new(FailingSaveService.new(), failing_guard)
    var failed_status: Dictionary = failing_coordinator.request_save(
        1,
        SaveRequestCoordinator.REQUEST_MANUAL,
        func() -> ProfileSnapshot: return _make_profile("profile:slot_1", "Failure", 5)
    )
    _expect(StringName(failed_status["state"]) == SaveRequestCoordinator.STATE_FAILED, "SaveService commit failure reports failed")
    _expect(StringName(failed_status["reason_id"]) == SaveRequestCoordinator.REASON_SAVE_COMMIT_FAILED, "commit failure exposes a stable error reason")
    _expect(int(failed_status["error_code"]) == ERR_CANT_CREATE, "commit failure preserves the SaveService error code")

    for slot_index: int in range(1, SaveService.SLOT_COUNT + 1):
        service.delete_slot(slot_index)
    guard.free()
    coalesce_guard.free()
    invalidated_guard.free()
    safe_guard.free()
    failing_guard.free()
    if _failures == 0:
        print("SAVE REQUEST COORDINATOR TEST PASS")
    else:
        push_error("SAVE REQUEST COORDINATOR TEST FAILURES: %d" % _failures)
    quit(_failures)

func _make_profile(profile_id: String, protagonist_name: String, xp: int) -> ProfileSnapshot:
    var profile: ProfileSnapshot = ProfileSnapshot.new()
    profile.profile_id = profile_id
    profile.protagonist_name = protagonist_name
    profile.class_id = "melee"
    profile.level = 1
    profile.xp = xp
    profile.skill_points = 0
    return profile

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
