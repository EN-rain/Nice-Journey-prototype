extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_block_rule()
    _test_confirm_terminal_rule()
    _test_suspend_rule()
    _test_invalid_contexts()
    if _failures == 0:
        print("QUEST LEAVE TRANSACTIONS TEST PASS")
    else:
        push_error("QUEST LEAVE TRANSACTIONS TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_block_rule() -> void:
    var profile := _active_profile(&"primary_floor_2")
    var rule := _rule(&"leave:block_escort", QuestLeaveRuleDefinition.MODE_BLOCK, &"leave:escort_cannot_depart", &"")
    _expect(rule.validate_definition().is_empty(), "block leave rule validates")
    var before := profile.to_dictionary()
    var preview := QuestLeaveTransactionService.preview(profile, &"primary_floor_2", rule)
    _expect(bool(preview["accepted"]) and not bool(preview["confirmation_required"]), "block leave rule can be previewed with an explicit reason")
    var result := QuestLeaveTransactionService.apply(profile, &"primary_floor_2", rule)
    _expect(not bool(result["accepted"]) and result["reason_id"] == QuestLeaveTransactionService.REASON_BLOCKED, "block leave rule prevents departure")
    _expect(profile.to_dictionary() == before, "blocked leave mutates no quest state")

func _test_confirm_terminal_rule() -> void:
    var profile := _active_profile(&"side_region3_escort")
    var rule := _rule(&"leave:confirm_abandon", QuestLeaveRuleDefinition.MODE_CONFIRM_TERMINAL, &"leave:escort_abandon_warning", QuestProgressState.STATE_ABANDONED)
    _expect(rule.validate_definition().is_empty(), "confirmed-abandon leave rule validates")
    var before := profile.to_dictionary()
    var pending := QuestLeaveTransactionService.apply(profile, &"side_region3_escort", rule, false)
    _expect(not bool(pending["accepted"]) and pending["reason_id"] == QuestLeaveTransactionService.REASON_CONFIRMATION_REQUIRED, "destructive leave requires confirmation")
    _expect(profile.to_dictionary() == before, "unconfirmed destructive leave mutates no quest state")
    var committed := QuestLeaveTransactionService.apply(profile, &"side_region3_escort", rule, true)
    _expect(bool(committed["accepted"]) and committed["after_state"] == QuestProgressState.STATE_ABANDONED, "confirmed leave commits the authored terminal state")
    _expect(_state(profile, &"side_region3_escort") == QuestProgressState.STATE_ABANDONED, "quest profile records confirmed abandon")
    _expect(String((profile.quest_progress["side_region3_escort"] as Dictionary).get("leave_rule_id", "")) == "leave:confirm_abandon", "committed leave records its authored rule identity")

    var failed_profile := _active_profile(&"side_region3_defense")
    var fail_rule := _rule(&"leave:confirm_fail", QuestLeaveRuleDefinition.MODE_CONFIRM_TERMINAL, &"leave:defense_fail_warning", QuestProgressState.STATE_FAILED)
    var failed := QuestLeaveTransactionService.apply(failed_profile, &"side_region3_defense", fail_rule, true)
    _expect(bool(failed["accepted"]) and _state(failed_profile, &"side_region3_defense") == QuestProgressState.STATE_FAILED, "same generic contract supports an explicitly authored fail-on-leave rule")

func _test_suspend_rule() -> void:
    var profile := _active_profile(&"side_tower_floor4_escort")
    (profile.quest_progress["side_tower_floor4_escort"] as Dictionary)["objective_state"] = {
        "actor_id": "npc:escort_fixture",
        "route_progress": 2,
        "wait_requested": true,
    }
    var rule := _rule(&"leave:suspend_escort", QuestLeaveRuleDefinition.MODE_SERIALIZE_SUSPEND, &"leave:escort_suspended", &"")
    _expect(rule.validate_definition().is_empty(), "serialize-and-suspend leave rule validates")
    var result := QuestLeaveTransactionService.apply(profile, &"side_tower_floor4_escort", rule)
    _expect(bool(result["accepted"]) and result["after_state"] == QuestProgressState.STATE_SUSPENDED, "serializable leave state transitions to Suspended")
    var entry: Dictionary = profile.quest_progress["side_tower_floor4_escort"] as Dictionary
    _expect((entry["suspended_objective_state"] as Dictionary) == (entry["objective_state"] as Dictionary), "suspend path preserves exact attempt/objective state for authored resume")

func _test_invalid_contexts() -> void:
    var profile := _active_profile(&"primary_floor_4")
    var invalid_rule := QuestLeaveRuleDefinition.new()
    _expect(QuestLeaveTransactionService.apply(profile, &"primary_floor_4", invalid_rule)["reason_id"] == QuestLeaveTransactionService.REASON_RULE_INVALID, "invalid leave rule is rejected before mutation")
    var good_rule := _rule(&"leave:block_primary", QuestLeaveRuleDefinition.MODE_BLOCK, &"leave:blocked", &"")
    (profile.quest_progress["primary_floor_4"] as Dictionary)["state"] = QuestProgressState.STATE_COMPLETED
    _expect(QuestLeaveTransactionService.apply(profile, &"primary_floor_4", good_rule)["reason_id"] == QuestLeaveTransactionService.REASON_QUEST_NOT_ACTIVE, "completed quest cannot receive an active-attempt leave transition")

func _rule(rule_id: StringName, mode: StringName, reason_id: StringName, terminal_state: StringName) -> QuestLeaveRuleDefinition:
    var rule := QuestLeaveRuleDefinition.new()
    rule.rule_id = rule_id
    rule.mode = mode
    rule.reason_id = reason_id
    rule.reason_text = "Authored leave consequence fixture"
    rule.terminal_state = terminal_state
    return rule

func _active_profile(quest_id: StringName) -> ProfileSnapshot:
    var profile := ProfileCreationService.create_profile(1, "Leave Tester", "melee")
    var definition := QuestCatalog.get_definition(quest_id)
    profile.quest_progress[String(quest_id)] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": definition.stage_ids[-1],
        "attempt_id": StringName("attempt:%s" % String(quest_id)),
        "objective_state": {},
    }
    return profile

func _state(profile: ProfileSnapshot, quest_id: StringName) -> StringName:
    return StringName(String((profile.quest_progress[String(quest_id)] as Dictionary).get("state", &"")))

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
