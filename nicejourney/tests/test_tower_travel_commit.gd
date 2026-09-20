extends SceneTree

const VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const SAVE_ROOT := "user://test_tower_travel_commit"

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var service := SaveService.new(SAVE_ROOT)
    for slot: int in range(1, SaveService.SLOT_COUNT + 1):
        service.delete_slot(slot)
    _test_runtime_preparation_and_atomic_commit(service)
    _test_stale_source_rejected(service)
    _test_commit_rechecks_travel_guard(service)
    for slot: int in range(1, SaveService.SLOT_COUNT + 1):
        service.delete_slot(slot)
    if _failures == 0:
        print("TOWER TRAVEL COMMIT TEST PASS")
    else:
        push_error("TOWER TRAVEL COMMIT TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_runtime_preparation_and_atomic_commit(save_service: SaveService) -> void:
    var profile := _travel_profile()
    var guard := GameplayOperationGuard.new()
    var coordinator := SaveRequestCoordinator.new(save_service, guard)
    var plan := _plan(profile, guard, 1, 10101)
    _expect(bool(plan.get("accepted", false)), "tower travel plan stages before commit")
    _expect(profile.to_dictionary() == plan["source_profile"], "plan records exact source profile for stale-plan detection")
    var runtime := TowerTravelCommitService.prepare_runtime(plan, VISUAL_CATALOG)
    _expect(bool(runtime.get("accepted", false)), "staged tower destination composes into a validated runtime before save")
    var root := runtime.get("runtime_root") as Node2D
    _expect(root != null and int(root.get_meta(&"floor_id", -1)) == 1, "prepared runtime identity matches planned floor")
    var committed := TowerTravelCommitService.commit(
        coordinator,
        1,
        profile,
        guard,
        plan,
        runtime,
        {"hp": 100, "stamina": 100.0},
        {"primary_floor_1": {"stage": "floor_objective"}},
        7
    )
    _expect(bool(committed.get("accepted", false)), "validated tower runtime and staged profile commit at one safe save boundary")
    _expect(profile.tower_floor_states.has("1"), "live profile receives newly generated floor only after durable commit succeeds")
    _expect(int(profile.safe_state.get("floor_id", -1)) == 1, "travel commit advances durable safe snapshot to destination floor")
    _expect(StringName(String(profile.safe_state.get("checkpoint_anchor_id", &""))) == StringName(String((runtime["arrival"] as Dictionary)["arrival_anchor_id"])), "safe snapshot binds the validated arrival anchor")
    var loaded := save_service.load_profile(1)
    _expect(loaded != null, "committed tower travel reloads from disk")
    if loaded != null:
        _expect(loaded.tower_floor_states.has("1"), "generated destination survives save/load")
        _expect(SafeCheckpointState.validate_dictionary(loaded.safe_state).is_empty(), "destination safe snapshot remains schema-valid after JSON round trip")
        _expect(int(loaded.safe_state.get("floor_id", -1)) == 1 and int(loaded.safe_state.get("snapshot_sequence", -1)) == 7, "destination safe snapshot preserves floor and sequence across JSON numeric normalization")
        _expect(String(loaded.safe_state.get("checkpoint_anchor_id", "")) == String(profile.safe_state.get("checkpoint_anchor_id", "")), "destination safe snapshot preserves arrival-anchor identity across save/load")
    if root != null:
        root.free()
    guard.free()

func _test_stale_source_rejected(save_service: SaveService) -> void:
    save_service.delete_slot(2)
    var profile := _travel_profile(2)
    var guard := GameplayOperationGuard.new()
    var coordinator := SaveRequestCoordinator.new(save_service, guard)
    var plan := _plan(profile, guard, 1, 20202)
    var runtime := TowerTravelCommitService.prepare_runtime(plan, VISUAL_CATALOG)
    profile.xp += 1
    var before := profile.to_dictionary()
    var result := TowerTravelCommitService.commit(coordinator, 2, profile, guard, plan, runtime, {}, {}, 1)
    _expect(not bool(result.get("accepted", false)) and result.get("reason_id", &"") == TowerTravelCommitService.REASON_STALE_SOURCE, "stale tower plan cannot overwrite progression that changed after planning")
    _expect(profile.to_dictionary() == before, "stale-plan rejection preserves the newer live profile")
    _expect(save_service.load_profile(2) == null, "stale-plan rejection writes no destination save")
    var root := runtime.get("runtime_root") as Node2D
    if root != null:
        root.free()
    guard.free()

func _test_commit_rechecks_travel_guard(save_service: SaveService) -> void:
    save_service.delete_slot(3)
    var profile := _travel_profile(3)
    var guard := GameplayOperationGuard.new()
    var coordinator := SaveRequestCoordinator.new(save_service, guard)
    var plan := _plan(profile, guard, 1, 30303)
    var runtime := TowerTravelCommitService.prepare_runtime(plan, VISUAL_CATALOG)
    var token := guard.acquire_blocker(
        &"encounter:test",
        GameplayOperationGuard.REASON_ACTIVE_COMBAT,
        "Active combat",
        [GameplayOperationGuard.OP_SIGIL_TRAVEL, GameplayOperationGuard.OP_MANUAL_SAVE]
    )
    _expect(token != 0, "travel commit fixture acquires active-combat blocker after menu planning")
    var before := profile.to_dictionary()
    var result := TowerTravelCommitService.commit(coordinator, 3, profile, guard, plan, runtime, {}, {}, 1)
    _expect(not bool(result.get("accepted", false)) and result.get("reason_id", &"") == TowerAccessMenuService.REASON_OPERATION_BLOCKED, "travel commit rechecks active combat instead of trusting a stale menu")
    _expect(profile.to_dictionary() == before and save_service.load_profile(3) == null, "commit-time combat rejection changes neither live profile nor disk")
    guard.release_blocker(token)
    var root := runtime.get("runtime_root") as Node2D
    if root != null:
        root.free()
    guard.free()

func _travel_profile(slot_index: int = 1) -> ProfileSnapshot:
    var profile := ProfileCreationService.create_profile(slot_index, "Travel Commit", "melee")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    return profile

func _plan(profile: ProfileSnapshot, guard: GameplayOperationGuard, floor_id: int, seed: int) -> Dictionary:
    return TowerTravelPlanService.stage(
        profile,
        guard,
        floor_id,
        seed,
        &"tower_generator:v01",
        &"tower_modules:v01",
        &"encounters:v01",
        &"quest_flags:travel_commit_test",
        StringName("floor_instance:travel_commit_%d_%d" % [floor_id, seed]),
        [],
        []
    )

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
