extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_missing_instance_is_non_destructive()
    _test_valid_existing_instance_prepares_entrance()
    _test_invalid_layout_and_stale_guard_reject()
    if _failures == 0:
        print("TOWER TRAVEL PREPARATION TEST PASS")
    else:
        push_error("TOWER TRAVEL PREPARATION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_missing_instance_is_non_destructive() -> void:
    var profile := _base_profile()
    var before := profile.to_dictionary()
    var guard := GameplayOperationGuard.new()
    var result := TowerTravelPreparationService.prepare_existing_destination(profile, guard, 1)
    _expect(not bool(result["accepted"]) and result["reason_id"] == TowerTravelPreparationService.REASON_DESTINATION_INSTANCE_MISSING, "eligible floor without a committed instance requests preparation instead of mutating source state")
    _expect(profile.to_dictionary() == before, "missing destination instance changes no profile/source state")
    guard.free()

func _test_valid_existing_instance_prepares_entrance() -> void:
    var profile := _base_profile()
    var floor_state := _floor_state(1, 10101)
    _expect(floor_state != null, "validated Floor 1 fallback creates a persistent instance")
    if floor_state == null:
        return
    _expect(TowerFloorStateService.commit_floor_state(profile, floor_state), "travel fixture commits Floor 1 state")
    var before := profile.to_dictionary()
    var guard := GameplayOperationGuard.new()
    var result := TowerTravelPreparationService.prepare_existing_destination(profile, guard, 1)
    _expect(bool(result["accepted"]), "existing unlocked destination prepares successfully")
    var arrival: Dictionary = result["arrival"]
    _expect(arrival["arrival_kind"] == &"entrance", "uncleared/revisit preparation resolves a validated entrance target")
    _expect(arrival["room_instance_id"] == &"room:entrance", "arrival resolves the manifest entrance room")
    _expect(arrival["module_id"] == &"module:entrance_safe_v01", "arrival resolves the authored entrance module")
    var tile := arrival["world_tile"] as Vector2i
    _expect(tile.x >= 0 and tile.y >= 0 and tile.x < 50 and tile.y < 50, "arrival remains inside the 50x50 floor footprint")
    _expect(profile.to_dictionary() == before and not bool(result["source_state_mutated"]), "preparation validates destination before mutating source/progression")
    guard.free()

func _test_invalid_layout_and_stale_guard_reject() -> void:
    var profile := _base_profile()
    var floor_state := _floor_state(1, 11111)
    TowerFloorStateService.commit_floor_state(profile, floor_state)
    var tampered: Dictionary = (profile.tower_floor_states["1"] as Dictionary).duplicate(true)
    var manifest: Dictionary = (tampered["layout_manifest"] as Dictionary).duplicate(true)
    manifest["edges"] = []
    tampered["layout_manifest"] = manifest
    profile.tower_floor_states["1"] = tampered
    var guard := GameplayOperationGuard.new()
    var invalid := TowerTravelPreparationService.prepare_existing_destination(profile, guard, 1)
    _expect(not bool(invalid["accepted"]) and invalid["reason_id"] == TowerTravelPreparationService.REASON_DESTINATION_ARRIVAL_INVALID, "invalid remembered destination layout is rejected before travel")
    _expect(invalid.get("arrival_reason_id", &"") == TowerArrivalResolver.REASON_LAYOUT_INVALID, "invalid layout reports recoverable arrival validation reason")

    profile.tower_floor_states["1"] = floor_state.to_dictionary()
    var token := guard.acquire_blocker(&"combat:travel_fixture", GameplayOperationGuard.REASON_ACTIVE_COMBAT, "Active combat", [GameplayOperationGuard.OP_SIGIL_TRAVEL])
    var blocked := TowerTravelPreparationService.prepare_existing_destination(profile, guard, 1)
    _expect(not bool(blocked["accepted"]) and blocked["reason_id"] == TowerAccessMenuService.REASON_OPERATION_BLOCKED, "destination preparation rechecks shared out-of-combat eligibility at commit time")
    guard.release_blocker(token)
    guard.free()

func _base_profile() -> ProfileSnapshot:
    var profile := ProfileCreationService.create_profile(1, "Travel Tester", "ranged")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    return profile

func _floor_state(floor_id: int, seed: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(floor_id, seed, &"tower_generator:v01", &"tower_modules:v01", &"encounters:v01", &"quest_flags:travel_test")
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return null
    return TowerFloorGenerationCommitService.floor_state_from_manifest(StringName("floor_instance:travel_%d" % floor_id), manifest)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
