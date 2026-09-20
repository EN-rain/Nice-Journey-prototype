class_name NormalInventoryCapacityPolicy
extends RefCounted

const NORMAL_SLOT_CAPACITY: int = 16

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_NORMAL_INVENTORY_FULL: StringName = &"normal_inventory_full"

static func evaluate(raw_context: Variant) -> Dictionary:
    if not raw_context is Dictionary:
        return _result(false, REASON_INVALID_CONTEXT)

    var context: Dictionary = raw_context as Dictionary
    if not context.has(&"occupied_normal_slots") or typeof(context[&"occupied_normal_slots"]) != TYPE_INT:
        return _result(false, REASON_INVALID_CONTEXT)
    if not _has_bool(context, &"protected_quest_key") or not _has_bool(context, &"needs_new_normal_slot"):
        return _result(false, REASON_INVALID_CONTEXT)

    var occupied_normal_slots: int = int(context[&"occupied_normal_slots"])
    if occupied_normal_slots < 0 or occupied_normal_slots > NORMAL_SLOT_CAPACITY:
        return _result(false, REASON_INVALID_CONTEXT)

    if bool(context[&"protected_quest_key"]):
        return _result(true, &"")

    if not bool(context[&"needs_new_normal_slot"]):
        return _result(true, &"")

    if occupied_normal_slots >= NORMAL_SLOT_CAPACITY:
        return _result(false, REASON_NORMAL_INVENTORY_FULL)

    return _result(true, &"")

static func _has_bool(data: Dictionary, key: StringName) -> bool:
    return data.has(key) and typeof(data[key]) == TYPE_BOOL

static func _result(allowed: bool, reason_id: StringName) -> Dictionary:
    return {
        "allowed": allowed,
        "reason_id": reason_id,
    }
