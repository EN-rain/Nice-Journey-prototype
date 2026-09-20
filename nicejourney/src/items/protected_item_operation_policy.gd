class_name ProtectedItemOperationPolicy
extends RefCounted

const OP_DROP: StringName = &"drop"
const OP_DESTROY: StringName = &"destroy"
const OP_SELL: StringName = &"sell"
const OP_QUEST_REMOVE: StringName = &"quest_remove"

const REASON_INVALID_OPERATION: StringName = &"invalid_operation"
const REASON_INVALID_PROTECTION_STATE: StringName = &"invalid_protection_state"
const REASON_PROTECTED_QUEST_KEY: StringName = &"protected_quest_key"
const REASON_PERMANENT_TOWER_SIGIL: StringName = &"permanent_tower_sigil"

const _SUPPORTED_OPERATIONS: Array[StringName] = [
	OP_DROP,
	OP_DESTROY,
	OP_SELL,
	OP_QUEST_REMOVE,
]

static func evaluate(raw_operation: Variant, raw_protection_state: Variant) -> Dictionary:
	if not (raw_operation is String or raw_operation is StringName):
		return _result(false, REASON_INVALID_OPERATION)
	var operation: StringName = StringName(String(raw_operation))
	if not _SUPPORTED_OPERATIONS.has(operation):
		return _result(false, REASON_INVALID_OPERATION)

	if not raw_protection_state is Dictionary:
		return _result(false, REASON_INVALID_PROTECTION_STATE)
	var protection_state: Dictionary = raw_protection_state as Dictionary
	if not _has_bool(protection_state, &"protected_quest_key") or not _has_bool(protection_state, &"tower_sigil"):
		return _result(false, REASON_INVALID_PROTECTION_STATE)

	var is_tower_sigil: bool = bool(protection_state[&"tower_sigil"])
	if is_tower_sigil:
		return _result(false, REASON_PERMANENT_TOWER_SIGIL)

	var is_protected_quest_key: bool = bool(protection_state[&"protected_quest_key"])
	if is_protected_quest_key and operation != OP_QUEST_REMOVE:
		return _result(false, REASON_PROTECTED_QUEST_KEY)

	return _result(true, &"")

static func _has_bool(data: Dictionary, key: StringName) -> bool:
	return data.has(key) and typeof(data[key]) == TYPE_BOOL

static func _result(allowed: bool, reason_id: StringName) -> Dictionary:
	return {
		"allowed": allowed,
		"reason_id": reason_id,
	}
