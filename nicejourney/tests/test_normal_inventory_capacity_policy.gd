extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var empty_context: Dictionary = _context(0, false, true)
    var empty_before: Dictionary = empty_context.duplicate(true)
    _expect(_allowed(NormalInventoryCapacityPolicy.evaluate(empty_context)), "normal item needing a new slot is allowed in an empty normal inventory")
    _expect(empty_context == empty_before, "capacity evaluation does not mutate caller context")

    _expect(_allowed(NormalInventoryCapacityPolicy.evaluate(_context(15, false, true))), "normal item needing a new slot is allowed at 15 of 16 occupied normal slots")
    _expect(_reason(NormalInventoryCapacityPolicy.evaluate(_context(16, false, true))) == NormalInventoryCapacityPolicy.REASON_NORMAL_INVENTORY_FULL, "normal item needing a new slot is rejected at 16 of 16 occupied normal slots")

    _expect(_allowed(NormalInventoryCapacityPolicy.evaluate(_context(16, false, false))), "caller-resolved no-new-slot normal ownership is not blocked by full-slot capacity")
    _expect(_allowed(NormalInventoryCapacityPolicy.evaluate(_context(16, true, true))), "protected quest/key ownership bypasses the normal 16-slot capacity even if caller marks new-slot need")
    _expect(_allowed(NormalInventoryCapacityPolicy.evaluate(_context(16, true, false))), "protected quest/key ownership bypasses normal capacity regardless of normal-slot merge facts")

    _expect(_reason(NormalInventoryCapacityPolicy.evaluate("bad")) == NormalInventoryCapacityPolicy.REASON_INVALID_CONTEXT, "non-dictionary capacity context is rejected")
    _expect(_reason(NormalInventoryCapacityPolicy.evaluate(_context(-1, false, true))) == NormalInventoryCapacityPolicy.REASON_INVALID_CONTEXT, "negative occupied normal-slot count is rejected")
    _expect(_reason(NormalInventoryCapacityPolicy.evaluate(_context(17, false, true))) == NormalInventoryCapacityPolicy.REASON_INVALID_CONTEXT, "occupied normal-slot count above 16 is rejected")

    var missing_count: Dictionary = _context(0, false, true)
    missing_count.erase(&"occupied_normal_slots")
    _expect(_reason(NormalInventoryCapacityPolicy.evaluate(missing_count)) == NormalInventoryCapacityPolicy.REASON_INVALID_CONTEXT, "missing occupied-slot count is rejected")

    var wrong_count_type: Dictionary = _context(0, false, true)
    wrong_count_type[&"occupied_normal_slots"] = 0.0
    _expect(_reason(NormalInventoryCapacityPolicy.evaluate(wrong_count_type)) == NormalInventoryCapacityPolicy.REASON_INVALID_CONTEXT, "non-integer occupied-slot count is rejected")

    var wrong_protected_type: Dictionary = _context(0, false, true)
    wrong_protected_type[&"protected_quest_key"] = 1
    _expect(_reason(NormalInventoryCapacityPolicy.evaluate(wrong_protected_type)) == NormalInventoryCapacityPolicy.REASON_INVALID_CONTEXT, "wrong-type protected-item fact is rejected")

    var missing_new_slot: Dictionary = _context(0, false, true)
    missing_new_slot.erase(&"needs_new_normal_slot")
    _expect(_reason(NormalInventoryCapacityPolicy.evaluate(missing_new_slot)) == NormalInventoryCapacityPolicy.REASON_INVALID_CONTEXT, "missing caller-resolved new-slot fact is rejected")

    var wrong_new_slot_type: Dictionary = _context(0, false, true)
    wrong_new_slot_type[&"needs_new_normal_slot"] = &"yes"
    _expect(_reason(NormalInventoryCapacityPolicy.evaluate(wrong_new_slot_type)) == NormalInventoryCapacityPolicy.REASON_INVALID_CONTEXT, "wrong-type new-slot fact is rejected")

    var deterministic_context: Dictionary = _context(16, false, true)
    var deterministic_first: Dictionary = NormalInventoryCapacityPolicy.evaluate(deterministic_context)
    var deterministic_second: Dictionary = NormalInventoryCapacityPolicy.evaluate(deterministic_context)
    _expect(deterministic_first == deterministic_second, "identical capacity evaluations are deterministic")

    if _failures == 0:
        print("NORMAL INVENTORY CAPACITY POLICY TEST PASS")
    else:
        push_error("NORMAL INVENTORY CAPACITY POLICY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _context(occupied_normal_slots: int, protected_quest_key: bool, needs_new_normal_slot: bool) -> Dictionary:
    return {
        &"occupied_normal_slots": occupied_normal_slots,
        &"protected_quest_key": protected_quest_key,
        &"needs_new_normal_slot": needs_new_normal_slot,
    }

func _allowed(result: Dictionary) -> bool:
    return bool(result.get("allowed", false)) and StringName(result.get("reason_id", &"")) == &""

func _reason(result: Dictionary) -> StringName:
    return StringName(result.get("reason_id", &""))

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
