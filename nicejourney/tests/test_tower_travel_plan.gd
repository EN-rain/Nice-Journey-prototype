extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_destination_failure_precedes_leave_mutation()
    _test_missing_leave_plan_cannot_bypass_active_quest()
    _test_same_floor_active_quest_does_not_require_leave_plan()
    _test_block_and_confirmation_are_non_destructive()
    _test_confirmed_leave_and_generation_stage_atomically()
    _test_suspend_leave_stages_serialized_attempt()
    if _failures == 0:
        print("TOWER TRAVEL PLAN TEST PASS")
    else:
        push_error("TOWER TRAVEL PLAN TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_destination_failure_precedes_leave_mutation() -> void:
    var profile := _profile_with_active_escort()
    var guard := GameplayOperationGuard.new()
    var before := profile.to_dictionary()
    var rule := _rule(&"leave:test_suspend", QuestLeaveRuleDefinition.MODE_SERIALIZE_SUSPEND, &"leave:test_suspend_reason", &"")
    var result := _stage(profile, guard, 2, [{"quest_id": &"side_region3_escort", "rule": rule, "confirmed": false}])
    _expect(not bool(result["accepted"]), "locked destination rejects before leave processing")
    _expect((result["leave_results"] as Array).is_empty(), "failed destination consumes no leave-rule transaction")
    _expect(profile.to_dictionary() == before, "failed destination leaves source quest and profile untouched")
    guard.free()

func _test_missing_leave_plan_cannot_bypass_active_quest() -> void:
    var profile := _profile_with_active_escort()
    var guard := GameplayOperationGuard.new()
    var before := profile.to_dictionary()
    var result := _stage(profile, guard, 1, [])
    _expect(not bool(result["accepted"]) and result["reason_id"] == TowerTravelPlanService.REASON_LEAVE_PLAN_MISSING, "active nonportable quest cannot be bypassed by omitting its leave plan")
    _expect(result.get("leave_quest_id", &"") == &"side_region3_escort", "missing leave-plan rejection identifies the active quest requiring an authored policy")
    _expect(profile.to_dictionary() == before, "missing leave-plan rejection mutates no source quest or floor state")
    guard.free()

func _test_same_floor_active_quest_does_not_require_leave_plan() -> void:
    var profile := ProfileCreationService.create_profile(1, "Same Floor", "melee")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    profile.quest_progress["primary_floor_1"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:primary_floor1_same_floor",
        "objective_state": {},
    }
    var guard := GameplayOperationGuard.new()
    var result := _stage(profile, guard, 1, [])
    _expect(bool(result["accepted"]), "tower-bound active quest does not require a leave plan when travelling into its own floor scope")
    guard.free()

func _test_block_and_confirmation_are_non_destructive() -> void:
    var profile := _profile_with_active_escort()
    var guard := GameplayOperationGuard.new()
    var before := profile.to_dictionary()
    var block_rule := _rule(&"leave:test_block", QuestLeaveRuleDefinition.MODE_BLOCK, &"leave:test_block_reason", &"")
    var blocked := _stage(profile, guard, 1, [{"quest_id": &"side_region3_escort", "rule": block_rule, "confirmed": false}])
    _expect(not bool(blocked["accepted"]) and blocked["reason_id"] == TowerTravelPlanService.REASON_LEAVE_REJECTED, "authored block rule prevents staged travel")
    _expect(blocked.get("leave_reason_id", &"") == QuestLeaveTransactionService.REASON_BLOCKED, "travel plan preserves concrete quest leave rejection")
    _expect(profile.to_dictionary() == before and not profile.tower_floor_states.has("1"), "blocked leave cannot create destination instance or mutate source")

    var abandon_rule := _rule(&"leave:test_abandon", QuestLeaveRuleDefinition.MODE_CONFIRM_TERMINAL, &"leave:test_abandon_reason", QuestProgressState.STATE_ABANDONED)
    var pending := _stage(profile, guard, 1, [{"quest_id": &"side_region3_escort", "rule": abandon_rule, "confirmed": false}])
    _expect(not bool(pending["accepted"]) and pending.get("leave_reason_id", &"") == QuestLeaveTransactionService.REASON_CONFIRMATION_REQUIRED, "unconfirmed destructive leave keeps travel pending")
    _expect(profile.to_dictionary() == before, "confirmation prompt path is non-mutating")
    guard.free()

func _test_confirmed_leave_and_generation_stage_atomically() -> void:
    var profile := _profile_with_active_escort()
    var guard := GameplayOperationGuard.new()
    var before := profile.to_dictionary()
    var abandon_rule := _rule(&"leave:test_abandon_commit", QuestLeaveRuleDefinition.MODE_CONFIRM_TERMINAL, &"leave:test_abandon_commit_reason", QuestProgressState.STATE_ABANDONED)
    var result := _stage(profile, guard, 1, [{"quest_id": &"side_region3_escort", "rule": abandon_rule, "confirmed": true}])
    _expect(bool(result["accepted"]) and bool(result["ready_for_transfer_commit"]), "confirmed leave plus valid destination produces a ready atomic transfer plan")
    _expect(profile.to_dictionary() == before and not profile.tower_floor_states.has("1"), "successful planning still does not mutate source before transfer commit")
    var staged := ProfileSnapshot.from_dictionary(result["staged_profile"] as Dictionary)
    _expect(staged != null, "staged transfer profile remains schema-valid")
    if staged != null:
        _expect(StringName(String((staged.quest_progress["side_region3_escort"] as Dictionary)["state"])) == QuestProgressState.STATE_ABANDONED, "staged profile contains confirmed quest leave consequence")
        _expect(staged.tower_floor_states.has("1"), "new destination floor is committed only to the staged transfer profile")
        _expect(int((staged.tower_floor_states["1"] as Dictionary)["seed"]) == 10101, "staged destination preserves requested generation identity")
    guard.free()

func _test_suspend_leave_stages_serialized_attempt() -> void:
    var profile := _profile_with_active_escort()
    var guard := GameplayOperationGuard.new()
    var suspend_rule := _rule(&"leave:test_suspend_commit", QuestLeaveRuleDefinition.MODE_SERIALIZE_SUSPEND, &"leave:test_suspend_commit_reason", &"")
    var result := _stage(profile, guard, 1, [{"quest_id": &"side_region3_escort", "rule": suspend_rule, "confirmed": false}])
    _expect(bool(result["accepted"]), "explicit serialize-and-suspend rule permits staged travel")
    var staged := ProfileSnapshot.from_dictionary(result["staged_profile"] as Dictionary)
    _expect(staged != null, "suspend travel staged profile validates")
    if staged != null:
        var entry: Dictionary = staged.quest_progress["side_region3_escort"] as Dictionary
        _expect(StringName(String(entry["state"])) == QuestProgressState.STATE_SUSPENDED, "staged quest state becomes Suspended")
        _expect((entry["suspended_objective_state"] as Dictionary) == (entry["objective_state"] as Dictionary), "staged suspend preserves exact serializable objective state")
    guard.free()

func _profile_with_active_escort() -> ProfileSnapshot:
    var profile := ProfileCreationService.create_profile(1, "Travel Plan", "ranged")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    profile.quest_progress["side_region3_escort"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"escort_objective",
        "attempt_id": &"attempt:region3_escort_travel",
        "objective_state": {"actor_id": "npc:escort", "route_progress": 1, "wait_requested": false},
    }
    return profile

func _stage(profile: ProfileSnapshot, guard: GameplayOperationGuard, floor_id: int, leave_plans: Array) -> Dictionary:
    return TowerTravelPlanService.stage(
        profile, guard, floor_id, 10101,
        &"tower_generator:v01", &"tower_modules:v01", &"encounters:v01", &"quest_flags:travel_plan_test",
        StringName("floor_instance:travel_plan_%d" % floor_id), leave_plans, []
    )

func _rule(rule_id: StringName, mode: StringName, reason_id: StringName, terminal_state: StringName) -> QuestLeaveRuleDefinition:
    var rule := QuestLeaveRuleDefinition.new()
    rule.rule_id = rule_id
    rule.mode = mode
    rule.reason_id = reason_id
    rule.reason_text = "Authored travel leave fixture"
    rule.terminal_state = terminal_state
    return rule

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
