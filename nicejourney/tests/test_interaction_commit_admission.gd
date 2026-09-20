extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var admission: InteractionCommitAdmission = InteractionCommitAdmission.new()
    var valid_context: Dictionary = _valid_context()
    var before_validation: Dictionary = valid_context.duplicate(true)

    var first: Dictionary = admission.try_admit(&"interaction:chest:1", valid_context)
    _expect(bool(first.get("admitted", false)), "all commit-time preconditions admit the interaction once")
    _expect(StringName(first.get("reason_id", &"")) == &"", "successful admission has no rejection reason")
    _expect(valid_context == before_validation, "admission does not mutate caller-supplied commit context")

    var duplicate: Dictionary = admission.try_admit(&"interaction:chest:1", valid_context)
    _expect(not bool(duplicate.get("admitted", true)), "duplicate logical commit is rejected")
    _expect(StringName(duplicate.get("reason_id", &"")) == InteractionCommitAdmission.REASON_DUPLICATE_COMMIT, "duplicate rejection reports the duplicate reason")

    _expect(_reason(admission.try_admit(&"", valid_context)) == InteractionCommitAdmission.REASON_INVALID_COMMIT_ID, "empty commit identity is rejected")
    _expect(_reason(admission.try_admit("bad commit id", valid_context)) == InteractionCommitAdmission.REASON_INVALID_COMMIT_ID, "malformed stable commit identity is rejected")
    _expect(_reason(admission.try_admit(7, valid_context)) == InteractionCommitAdmission.REASON_INVALID_COMMIT_ID, "wrong-type commit identity is rejected")
    _expect(_reason(admission.try_admit(&"interaction:bad-context", "bad")) == InteractionCommitAdmission.REASON_INVALID_CONTEXT, "non-dictionary commit context is rejected")

    var missing_field: Dictionary = _valid_context()
    missing_field.erase(&"hold_complete")
    _expect(_reason(admission.try_admit(&"interaction:missing-field", missing_field)) == InteractionCommitAdmission.REASON_INVALID_CONTEXT, "missing commit precondition is rejected as malformed context")

    var wrong_type: Dictionary = _valid_context()
    wrong_type[&"in_range"] = 1
    _expect(_reason(admission.try_admit(&"interaction:wrong-type", wrong_type)) == InteractionCommitAdmission.REASON_INVALID_CONTEXT, "wrong-type commit precondition is rejected as malformed context")

    _expect(_failed_precondition_reason(admission, &"interaction:range", &"in_range") == InteractionCommitAdmission.REASON_OUT_OF_RANGE, "out-of-range commit is rejected")
    _expect(_failed_precondition_reason(admission, &"interaction:target", &"target_state_valid") == InteractionCommitAdmission.REASON_TARGET_INVALID, "invalid target state is rejected")
    _expect(_failed_precondition_reason(admission, &"interaction:item", &"required_item_satisfied") == InteractionCommitAdmission.REASON_REQUIRED_ITEM_MISSING, "missing required item state is rejected")
    _expect(_failed_precondition_reason(admission, &"interaction:quest", &"required_quest_flag_satisfied") == InteractionCommitAdmission.REASON_REQUIRED_QUEST_FLAG_MISSING, "missing required quest flag state is rejected")
    _expect(_failed_precondition_reason(admission, &"interaction:menu", &"menu_ownership_allows") == InteractionCommitAdmission.REASON_MENU_OWNERSHIP_BLOCKED, "menu ownership rejection is preserved")
    _expect(_failed_precondition_reason(admission, &"interaction:combat", &"combat_ownership_allows") == InteractionCommitAdmission.REASON_COMBAT_OWNERSHIP_BLOCKED, "combat ownership rejection is preserved")
    _expect(_failed_precondition_reason(admission, &"interaction:hold", &"hold_complete") == InteractionCommitAdmission.REASON_HOLD_INCOMPLETE, "incomplete required hold is rejected")

    var retry_context: Dictionary = _valid_context()
    retry_context[&"target_state_valid"] = false
    var failed_retry: Dictionary = admission.try_admit(&"interaction:retry", retry_context)
    _expect(_reason(failed_retry) == InteractionCommitAdmission.REASON_TARGET_INVALID, "failed admission reports the current commit-time blocker")
    retry_context[&"target_state_valid"] = true
    _expect(bool(admission.try_admit(&"interaction:retry", retry_context).get("admitted", false)), "failed admission does not consume the commit identity and may succeed after revalidation")

    var deterministic_context: Dictionary = _valid_context()
    deterministic_context[&"required_item_satisfied"] = false
    var deterministic_first: Dictionary = admission.try_admit(&"interaction:deterministic", deterministic_context)
    var deterministic_second: Dictionary = admission.try_admit(&"interaction:deterministic", deterministic_context)
    _expect(deterministic_first == deterministic_second, "identical rejected commit attempts return deterministic results")

    _expect(bool(admission.try_admit(&"interaction:independent:a", _valid_context()).get("admitted", false)), "one admitted commit identity succeeds independently")
    _expect(bool(admission.try_admit(&"interaction:independent:b", _valid_context()).get("admitted", false)), "a second independent commit identity is not blocked by the first")

    if _failures == 0:
        print("INTERACTION COMMIT ADMISSION TEST PASS")
    else:
        push_error("INTERACTION COMMIT ADMISSION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _valid_context() -> Dictionary:
    return {
        &"in_range": true,
        &"target_state_valid": true,
        &"required_item_satisfied": true,
        &"required_quest_flag_satisfied": true,
        &"menu_ownership_allows": true,
        &"combat_ownership_allows": true,
        &"hold_complete": true,
    }

func _failed_precondition_reason(admission: InteractionCommitAdmission, commit_id: StringName, field: StringName) -> StringName:
    var context: Dictionary = _valid_context()
    context[field] = false
    return _reason(admission.try_admit(commit_id, context))

func _reason(result: Dictionary) -> StringName:
    return StringName(result.get("reason_id", &""))

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
