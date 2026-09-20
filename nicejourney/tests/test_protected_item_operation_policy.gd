extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var normal_state: Dictionary = _state(false, false)
    var normal_before: Dictionary = normal_state.duplicate(true)
    for operation: StringName in _operations():
        var normal_result: Dictionary = ProtectedItemOperationPolicy.evaluate(operation, normal_state)
        _expect(bool(normal_result.get("allowed", false)), "normal item is not blocked by protection policy for %s" % String(operation))
        _expect(StringName(normal_result.get("reason_id", &"")) == &"", "allowed normal operation has no protection rejection reason")
    _expect(normal_state == normal_before, "protection evaluation does not mutate caller state")

    var protected_state: Dictionary = _state(true, false)
    _expect(_reason(ProtectedItemOperationPolicy.evaluate(ProtectedItemOperationPolicy.OP_DROP, protected_state)) == ProtectedItemOperationPolicy.REASON_PROTECTED_QUEST_KEY, "protected quest/key item cannot be dropped")
    _expect(_reason(ProtectedItemOperationPolicy.evaluate(ProtectedItemOperationPolicy.OP_DESTROY, protected_state)) == ProtectedItemOperationPolicy.REASON_PROTECTED_QUEST_KEY, "protected quest/key item cannot be destroyed")
    _expect(_reason(ProtectedItemOperationPolicy.evaluate(ProtectedItemOperationPolicy.OP_SELL, protected_state)) == ProtectedItemOperationPolicy.REASON_PROTECTED_QUEST_KEY, "protected quest/key item cannot be sold")
    _expect(bool(ProtectedItemOperationPolicy.evaluate(ProtectedItemOperationPolicy.OP_QUEST_REMOVE, protected_state).get("allowed", false)), "ordinary protected quest/key item may be removed by quest logic")

    var sigil_state: Dictionary = _state(true, true)
    for operation: StringName in _operations():
        var sigil_result: Dictionary = ProtectedItemOperationPolicy.evaluate(operation, sigil_state)
        _expect(not bool(sigil_result.get("allowed", true)), "Tower Sigil is permanent for %s" % String(operation))
        _expect(_reason(sigil_result) == ProtectedItemOperationPolicy.REASON_PERMANENT_TOWER_SIGIL, "Tower Sigil rejection reports permanent entitlement reason")

    var inconsistent_sigil_state: Dictionary = _state(false, true)
    _expect(_reason(ProtectedItemOperationPolicy.evaluate(ProtectedItemOperationPolicy.OP_QUEST_REMOVE, inconsistent_sigil_state)) == ProtectedItemOperationPolicy.REASON_PERMANENT_TOWER_SIGIL, "Tower Sigil permanence does not depend on a caller also setting the generic protected flag")

    _expect(_reason(ProtectedItemOperationPolicy.evaluate(&"discard", normal_state)) == ProtectedItemOperationPolicy.REASON_INVALID_OPERATION, "unknown removal operation is rejected")
    _expect(_reason(ProtectedItemOperationPolicy.evaluate(1, normal_state)) == ProtectedItemOperationPolicy.REASON_INVALID_OPERATION, "wrong-type operation is rejected")
    _expect(_reason(ProtectedItemOperationPolicy.evaluate(ProtectedItemOperationPolicy.OP_DROP, "bad")) == ProtectedItemOperationPolicy.REASON_INVALID_PROTECTION_STATE, "non-dictionary protection state is rejected")

    var missing_flag: Dictionary = {&"protected_quest_key": true}
    _expect(_reason(ProtectedItemOperationPolicy.evaluate(ProtectedItemOperationPolicy.OP_DROP, missing_flag)) == ProtectedItemOperationPolicy.REASON_INVALID_PROTECTION_STATE, "missing Tower Sigil fact is rejected")

    var wrong_flag_type: Dictionary = _state(false, false)
    wrong_flag_type[&"protected_quest_key"] = 1
    _expect(_reason(ProtectedItemOperationPolicy.evaluate(ProtectedItemOperationPolicy.OP_DROP, wrong_flag_type)) == ProtectedItemOperationPolicy.REASON_INVALID_PROTECTION_STATE, "wrong-type protection fact is rejected")

    var deterministic_state: Dictionary = _state(true, false)
    var deterministic_first: Dictionary = ProtectedItemOperationPolicy.evaluate(ProtectedItemOperationPolicy.OP_SELL, deterministic_state)
    var deterministic_second: Dictionary = ProtectedItemOperationPolicy.evaluate(ProtectedItemOperationPolicy.OP_SELL, deterministic_state)
    _expect(deterministic_first == deterministic_second, "identical protection evaluations are deterministic")

    _expect(bool(ProtectedItemOperationPolicy.evaluate("drop", normal_state).get("allowed", false)), "String operation values are accepted alongside StringName")

    if _failures == 0:
        print("PROTECTED ITEM OPERATION POLICY TEST PASS")
    else:
        push_error("PROTECTED ITEM OPERATION POLICY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _operations() -> Array[StringName]:
    return [
        ProtectedItemOperationPolicy.OP_DROP,
        ProtectedItemOperationPolicy.OP_DESTROY,
        ProtectedItemOperationPolicy.OP_SELL,
        ProtectedItemOperationPolicy.OP_QUEST_REMOVE,
    ]

func _state(protected_quest_key: bool, tower_sigil: bool) -> Dictionary:
    return {
        &"protected_quest_key": protected_quest_key,
        &"tower_sigil": tower_sigil,
    }

func _reason(result: Dictionary) -> StringName:
    return StringName(result.get("reason_id", &""))

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
