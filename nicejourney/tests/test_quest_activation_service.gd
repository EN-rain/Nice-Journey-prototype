extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_availability_and_acceptance()
    _test_objective_binding_is_atomic()
    _test_retry_attempt_identity()
    _test_terminal_and_prerequisite_guards()
    _test_authored_contract_policy_boundary()
    _test_authored_activation_transaction_is_atomic()
    if _failures == 0:
        print("QUEST ACTIVATION SERVICE TEST PASS")
    else:
        push_error("QUEST ACTIVATION SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_availability_and_acceptance() -> void:
    var profile := ProfileCreationService.create_profile(1, "Quest Activation", "melee")
    var before := profile.to_dictionary()
    var blocked := QuestActivationService.mark_available(profile, &"primary_floor_4", false)
    _expect(not bool(blocked["accepted"]) and blocked["reason_id"] == QuestActivationService.REASON_PREREQUISITES_NOT_SATISFIED, "unmet prerequisites cannot expose quest availability")
    _expect(profile.to_dictionary() == before, "rejected availability transition is non-mutating")

    var available := QuestActivationService.mark_available(profile, &"primary_floor_4", true)
    _expect(bool(available["accepted"]) and _state(profile, &"primary_floor_4") == QuestProgressState.STATE_AVAILABLE, "caller-authorized prerequisites expose the declared quest as Available")
    var accepted := QuestActivationService.accept(profile, &"primary_floor_4", &"attempt:primary_floor_4:1", true)
    _expect(bool(accepted["accepted"]) and _state(profile, &"primary_floor_4") == QuestProgressState.STATE_ACTIVE, "Available quest accepts into Active with one explicit attempt identity")
    var entry := profile.quest_progress["primary_floor_4"] as Dictionary
    _expect(StringName(String(entry["stage_id"])) == QuestCatalog.get_definition(&"primary_floor_4").stage_ids[0], "acceptance starts at the definition's first declared stage")
    _expect((entry.get("attempt_history", []) as Array) == ["attempt:primary_floor_4:1"], "accepted attempt identity is retained in deterministic history")
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "accepted quest state remains persistence-valid")


func _test_objective_binding_is_atomic() -> void:
    var profile := ProfileCreationService.create_profile(1, "Objective Binding", "ranged")
    QuestActivationService.mark_available(profile, &"primary_floor_4", true)
    var invalid_before := profile.to_dictionary()
    var invalid := QuestActivationService.accept(profile, &"primary_floor_4", &"attempt:primary_floor_4:bad", true, {"required_actor_ids": []})
    _expect(not bool(invalid["accepted"]) and invalid["reason_id"] == QuestActivationService.REASON_OBJECTIVE_BIND_FAILED, "invalid authored objective config rejects the whole acceptance transaction")
    _expect(profile.to_dictionary() == invalid_before, "failed objective bind does not partially activate the quest")

    var accepted := QuestActivationService.accept(profile, &"primary_floor_4", &"attempt:primary_floor_4:good", true, {"required_actor_ids": [&"enemy:required_a", &"enemy:required_b"]})
    _expect(bool(accepted["accepted"]), "valid authored objective config binds during acceptance")
    var objective := (profile.quest_progress["primary_floor_4"] as Dictionary).get("objective_state", {}) as Dictionary
    _expect((objective.get("required_actor_ids", []) as Array).size() == 2, "acceptance commits the exact authored objective state")


func _test_retry_attempt_identity() -> void:
    var profile := ProfileCreationService.create_profile(1, "Retry Activation", "mage")
    QuestActivationService.mark_available(profile, &"primary_floor_6", true)
    var config := {
        "actor_id": &"npc:floor6_retry_fixture",
        "route_node_ids": [&"route:floor6:a", &"route:floor6:b"],
        "goal_id": &"goal:floor6_fixture",
        "safe_retry_origin_id": &"retry:floor6_fixture",
        "failure_policy_id": &"failure:floor6_fixture",
    }
    _expect(bool(QuestActivationService.accept(profile, &"primary_floor_6", &"attempt:floor6:1", true, config)["accepted"]), "escort quest accepts with authored objective state")
    _expect(bool(QuestFamilyObjectiveService.apply_event(profile, &"primary_floor_6", QuestFamilyObjectiveService.EVENT_FAILED, {"reason_id": &"failure:actor_death"})["accepted"]), "fixture records an authoritative escort failure")
    _expect(_state(profile, &"primary_floor_6") == QuestProgressState.STATE_FAILED, "failed escort enters Failed state")

    var blocked := QuestActivationService.mark_retry_ready(profile, &"primary_floor_6", false)
    _expect(not bool(blocked["accepted"]), "retry-ready transition requires caller-authorized recovery conditions")
    _expect(bool(QuestActivationService.mark_retry_ready(profile, &"primary_floor_6", true)["accepted"]), "satisfied recovery conditions enter Retry-ready")
    var reused := QuestActivationService.retry(profile, &"primary_floor_6", &"attempt:floor6:1", true, config)
    _expect(not bool(reused["accepted"]) and reused["reason_id"] == QuestActivationService.REASON_ATTEMPT_ID_REUSED, "retry cannot reuse a prior attempt identity")
    var retried := QuestActivationService.retry(profile, &"primary_floor_6", &"attempt:floor6:2", true, config)
    _expect(bool(retried["accepted"]) and _state(profile, &"primary_floor_6") == QuestProgressState.STATE_ACTIVE, "retry creates a new Active attempt")
    var history := (profile.quest_progress["primary_floor_6"] as Dictionary).get("attempt_history", []) as Array
    _expect(history == ["attempt:floor6:1", "attempt:floor6:2"], "retry retains ordered unique attempt history")


func _test_terminal_and_prerequisite_guards() -> void:
    var profile := ProfileCreationService.create_profile(1, "Terminal Guard", "melee")
    profile.quest_progress["primary_floor_5"] = {
        "state": QuestProgressState.STATE_COMPLETED,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:floor5:done",
        "attempt_history": ["attempt:floor5:done"],
        "objective_state": {},
    }
    var before := profile.to_dictionary()
    var terminal := QuestActivationService.mark_available(profile, &"primary_floor_5", true)
    _expect(not bool(terminal["accepted"]) and terminal["reason_id"] == QuestActivationService.REASON_QUEST_ALREADY_TERMINAL, "completed quest cannot become Available again")
    _expect(profile.to_dictionary() == before, "terminal-state rejection is non-mutating")

    var absent_accept := QuestActivationService.accept(profile, &"side_region3_annihilation", &"attempt:side:1", true)
    _expect(not bool(absent_accept["accepted"]) and absent_accept["reason_id"] == QuestActivationService.REASON_QUEST_NOT_AVAILABLE, "acceptance cannot bypass the explicit Available transition")


func _test_authored_contract_policy_boundary() -> void:
    var definition := QuestDefinition.new()
    definition.quest_id = &"primary_floor_2"
    definition.kind = QuestDefinition.KIND_PRIMARY
    definition.family = QuestDefinition.FAMILY_ESCORT
    definition.floor_id = 2
    definition.scope_id = &"tower:floor_2"
    definition.stage_ids = [&"floor_objective"]
    definition.prerequisites_declared = true
    definition.prerequisite_ids = [&"fact:floor_1_completed"]
    definition.required_objectives_declared = true
    definition.required_objective_ids = [&"objective:floor_2_escort"]
    definition.optional_objectives_declared = true
    definition.instance_bindings_declared = true
    definition.instance_binding_ids = [&"binding:floor_2_escort"]
    definition.acceptance_anchor_declared = true
    definition.acceptance_anchor_id = &"r3:functional:02"
    definition.turn_in_anchor_declared = true
    definition.turn_in_anchor_id = &"r3:functional:02"
    definition.leave_rule_declared = true
    definition.leave_rule_id = &"leave:test"
    definition.failure_rule_declared = true
    definition.failure_rule_id = &"failure:test"
    definition.retry_reset_declared = true
    definition.retry_reset_ids = [&"reset:test"]
    definition.rewards_declared = true
    definition.reward_ids = [&"reward:test"]
    definition.branch_effects_declared = true
    definition.branch_effect_ids = [&"branch:test"]
    definition.completion_conditions_declared = true
    definition.completion_condition_ids = [&"condition:test"]

    var missing := QuestActivationService.evaluate_authored_acceptance(definition, &"r3:functional:02", [])
    _expect(not bool(missing.get("accepted", true)) and StringName(missing.get("reason_id", &"")) == QuestActivationService.REASON_PREREQUISITES_NOT_SATISFIED, "authored policy names unmet prerequisite facts without inferring them")
    _expect((missing.get("missing_prerequisite_ids", []) as Array) == [&"fact:floor_1_completed"], "authored policy reports the exact missing prerequisite identity")
    var wrong_anchor := QuestActivationService.evaluate_authored_acceptance(definition, &"r3:functional:01", [&"fact:floor_1_completed"])
    _expect(not bool(wrong_anchor.get("accepted", true)) and StringName(wrong_anchor.get("reason_id", &"")) == QuestActivationService.REASON_ACCEPTANCE_ANCHOR_MISMATCH, "authored policy requires the exact declared acceptance anchor")
    var admitted := QuestActivationService.evaluate_authored_acceptance(definition, &"r3:functional:02", [&"fact:floor_1_completed"])
    _expect(bool(admitted.get("accepted", false)), "complete production contract plus explicit prerequisite facts admits acceptance")

    var placeholder := definition.duplicate(true) as QuestDefinition
    placeholder.playtest_placeholder = true
    var placeholder_result := QuestActivationService.evaluate_authored_acceptance(placeholder, &"r3:functional:02", [&"fact:floor_1_completed"])
    _expect(not bool(placeholder_result.get("accepted", true)) and StringName(placeholder_result.get("reason_id", &"")) == QuestActivationService.REASON_AUTHORED_CONTRACT_UNAVAILABLE, "production activation rejects a structurally complete playtest placeholder")

    var malformed := definition.duplicate(true) as QuestDefinition
    malformed.scope_id = &""
    var malformed_result := QuestActivationService.evaluate_authored_acceptance(malformed, &"r3:functional:02", [&"fact:floor_1_completed"])
    _expect(not bool(malformed_result.get("accepted", true)) and StringName(malformed_result.get("reason_id", &"")) == QuestActivationService.REASON_AUTHORED_CONTRACT_UNAVAILABLE, "authored acceptance also rejects structurally invalid definitions")

    var profile := ProfileCreationService.create_profile(1, "Authored Policy", "melee")
    var before := profile.to_dictionary()
    var blocked_production := QuestActivationService.activate_authored(
        profile,
        &"primary_floor_2",
        &"attempt:primary_floor_2:blocked",
        &"r3:functional:02",
        []
    )
    _expect(
        not bool(blocked_production.get("accepted", true))
        and StringName(blocked_production.get("reason_id", &"")) == QuestActivationService.REASON_PREREQUISITES_NOT_SATISFIED,
        "real Floor 2 production contract rejects acceptance until its floor-unlock fact is supplied"
    )
    _expect(profile.to_dictionary() == before, "missing Floor 2 unlock fact cannot mutate quest progress")
    var production := QuestActivationService.activate_authored(
        profile,
        &"primary_floor_2",
        &"attempt:primary_floor_2:authored",
        &"r3:functional:02",
        [PrimaryQuestProductionV01.unlocked_fact_id(2)]
    )
    _expect(
        bool(production.get("accepted", false))
        and _state(profile, &"primary_floor_2") == QuestProgressState.STATE_ACTIVE,
        "real Floor 2 production-v01 contract admits explicit Quest Hall acceptance with its floor-unlock fact"
    )


func _test_authored_activation_transaction_is_atomic() -> void:
    var profile := ProfileCreationService.create_profile(1, "Authored Atomicity", "ranged")
    var before := profile.to_dictionary()
    var bind_rejected := QuestActivationService._activate_after_authored_policy(
        profile,
        &"primary_floor_4",
        &"attempt:primary_floor_4:atomic_bind",
        {"required_actor_ids": []}
    )
    _expect(not bool(bind_rejected.get("accepted", true)) and StringName(bind_rejected.get("reason_id", &"")) == QuestActivationService.REASON_OBJECTIVE_BIND_FAILED, "authored activation reports a rejected objective bind")
    _expect(profile.to_dictionary() == before, "rejected authored activation does not leak its staged Available transition")

    var invalid_attempt := QuestActivationService._activate_after_authored_policy(
        profile,
        &"primary_floor_4",
        &"bad attempt id"
    )
    _expect(not bool(invalid_attempt.get("accepted", true)) and StringName(invalid_attempt.get("reason_id", &"")) == QuestActivationService.REASON_INVALID_CONTEXT, "authored activation reports invalid attempt identity")
    _expect(profile.to_dictionary() == before, "invalid attempt rejection remains fully non-mutating")


func _state(profile: ProfileSnapshot, quest_id: StringName) -> StringName:
    var raw := profile.quest_progress.get(String(quest_id), {}) as Dictionary
    return StringName(String(raw.get("state", &"")))


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
