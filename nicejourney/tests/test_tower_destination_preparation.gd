extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_first_entry_generation_is_staged()
    _test_deterministic_reproduction()
    _test_existing_instance_is_reused()
    _test_eligibility_and_input_rejections()
    if _failures == 0:
        print("TOWER DESTINATION PREPARATION TEST PASS")
    else:
        push_error("TOWER DESTINATION PREPARATION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_first_entry_generation_is_staged() -> void:
    var profile := _profile(2)
    var guard := GameplayOperationGuard.new()
    var before := profile.to_dictionary()
    var result := _prepare(profile, guard, 2, 22002, &"floor_instance:first_floor2")
    _expect(bool(result["accepted"]), "first unlocked floor entry prepares a validated destination instance")
    _expect(bool(result["newly_generated"]), "missing floor instance uses generation/fallback preparation")
    _expect(bool((result["generation_result"] as Dictionary).get("accepted", false)), "prepared floor owns a complete accepted generation result")
    _expect((result["generation_result"] as Dictionary).get("used_fallback", false), "prevalidated fallback is used when no procedural candidates are supplied")
    _expect(int((result["floor_instance"] as Dictionary).get("floor_id", 0)) == 2, "prepared instance targets the selected floor")
    _expect((result["arrival"] as Dictionary).get("arrival_kind", &"") == &"entrance", "first entry resolves the validated entrance arrival")
    _expect(profile.to_dictionary() == before and not profile.tower_floor_states.has("2"), "destination preparation does not commit/mutate source profile before transfer")
    guard.free()

func _test_deterministic_reproduction() -> void:
    var profile := _profile(4)
    var guard := GameplayOperationGuard.new()
    var first := _prepare(profile, guard, 4, 44004, &"floor_instance:repro_a")
    var second := _prepare(profile, guard, 4, 44004, &"floor_instance:repro_b")
    _expect(bool(first["accepted"]) and bool(second["accepted"]), "same complete generation tuple prepares twice")
    var first_manifest: Dictionary = (first["generation_result"] as Dictionary)["manifest"]
    var second_manifest: Dictionary = (second["generation_result"] as Dictionary)["manifest"]
    _expect(first_manifest == second_manifest, "same generation tuple reproduces the identical structural manifest")
    _expect((first["floor_instance"] as Dictionary)["instance_id"] != (second["floor_instance"] as Dictionary)["instance_id"], "caller-owned instance identity stays separate from deterministic layout identity")
    guard.free()

func _test_existing_instance_is_reused() -> void:
    var profile := _profile(1)
    var guard := GameplayOperationGuard.new()
    var generated := _prepare(profile, guard, 1, 10101, &"floor_instance:existing")
    var state := FloorInstanceState.new()
    _expect(state.load_dictionary(generated["floor_instance"] as Dictionary).is_empty(), "generated destination fixture restores into floor state")
    _expect(TowerFloorStateService.commit_floor_state(profile, state), "fixture commits prepared floor after simulated successful transfer")
    var before := profile.to_dictionary()
    var reused := _prepare(profile, guard, 1, 99999, &"floor_instance:ignored")
    _expect(bool(reused["accepted"]) and not bool(reused["newly_generated"]), "ordinary revisit reuses persistent floor instead of generating a fresh seed")
    _expect(int((reused["floor_instance"] as Dictionary)["seed"]) == 10101, "revisit preserves original committed seed")
    _expect((reused["generation_result"] as Dictionary).is_empty(), "revisit does not consume generation randomness")
    _expect(profile.to_dictionary() == before, "revisit preparation remains non-mutating")
    guard.free()

func _test_eligibility_and_input_rejections() -> void:
    var profile := _profile(1)
    var guard := GameplayOperationGuard.new()
    _expect(not bool(_prepare(profile, guard, 2, 20202, &"floor_instance:locked")["accepted"]), "locked floor cannot be generated through travel preparation")
    var invalid := TowerDestinationPreparationService.prepare(profile, guard, 1, -1, &"gen:v1", &"modules:v1", &"encounters:v1", &"flags:v1", &"floor_instance:bad")
    _expect(not bool(invalid["accepted"]) and invalid["reason_id"] == TowerDestinationPreparationService.REASON_INVALID_GENERATION_INPUT, "invalid generation seed is rejected")
    var token := guard.acquire_blocker(&"combat:destination", GameplayOperationGuard.REASON_ACTIVE_COMBAT, "Active combat", [GameplayOperationGuard.OP_SIGIL_TRAVEL])
    var blocked := _prepare(profile, guard, 1, 10101, &"floor_instance:blocked")
    _expect(not bool(blocked["accepted"]) and blocked["reason_id"] == TowerAccessMenuService.REASON_OPERATION_BLOCKED, "destination preparation rechecks active-combat travel guard")
    guard.release_blocker(token)
    guard.free()

func _profile(unlocked_floor: int) -> ProfileSnapshot:
    var profile := ProfileCreationService.create_profile(1, "Destination Tester", "mage")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_%d_unlocked" % unlocked_floor] = true
    return profile

func _prepare(profile: ProfileSnapshot, guard: GameplayOperationGuard, floor_id: int, seed: int, instance_id: StringName) -> Dictionary:
    return TowerDestinationPreparationService.prepare(
        profile, guard, floor_id, seed,
        &"tower_generator:v01", &"tower_modules:v01", &"encounters:v01", &"quest_flags:destination_test",
        instance_id, []
    )

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
