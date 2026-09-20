class_name PoiseResolver
extends RefCounted

const OUTCOME_REJECTED: StringName = &"rejected"
const OUTCOME_ACCUMULATED: StringName = &"accumulated"
const OUTCOME_THRESHOLD_REACHED: StringName = &"threshold_reached"
const OUTCOME_RECOVERED: StringName = &"recovered"
const OUTCOME_RECOVERY_BLOCKED: StringName = &"recovery_blocked"

const REASON_INVALID_STATE: StringName = &"invalid_state"
const REASON_INVALID_HIT: StringName = &"invalid_hit"
const REASON_INVALID_RECOVERY: StringName = &"invalid_recovery"
const REASON_NONFINITE_RESULT: StringName = &"nonfinite_result"


static func apply_hit(raw_state: Variant, raw_hit: Variant) -> Dictionary:
	if not _is_valid_state(raw_state):
		return _rejected(REASON_INVALID_STATE)
	if not _is_valid_hit(raw_hit):
		return _rejected(REASON_INVALID_HIT)

	var state: Dictionary = raw_state as Dictionary
	var hit: Dictionary = raw_hit as Dictionary
	var accumulated_before: float = float(state["accumulated_poise"])
	var threshold: float = float(state["threshold"])
	var poise_damage: float = float(hit["poise_damage"])
	var accumulated_after: float = accumulated_before + poise_damage
	if not is_finite(accumulated_after):
		return _rejected(REASON_NONFINITE_RESULT)

	if accumulated_after >= threshold:
		return {
			"accepted": true,
			"reason_id": &"",
			"outcome": OUTCOME_THRESHOLD_REACHED,
			"accumulated_poise": 0.0,
			"threshold": threshold,
			"threshold_reached": true,
			"interruption_recovery_requested": bool(state["interruptible"]),
		}

	return {
		"accepted": true,
		"reason_id": &"",
		"outcome": OUTCOME_ACCUMULATED,
		"accumulated_poise": accumulated_after,
		"threshold": threshold,
		"threshold_reached": false,
		"interruption_recovery_requested": false,
	}


static func recover(raw_state: Variant, raw_recovery: Variant) -> Dictionary:
	if not _is_valid_state(raw_state):
		return _rejected(REASON_INVALID_STATE)
	if not _is_valid_recovery(raw_recovery):
		return _rejected(REASON_INVALID_RECOVERY)

	var state: Dictionary = raw_state as Dictionary
	var recovery: Dictionary = raw_recovery as Dictionary
	var accumulated: float = float(state["accumulated_poise"])
	var threshold: float = float(state["threshold"])
	if not bool(recovery["recovery_allowed"]):
		return {
			"accepted": true,
			"reason_id": &"",
			"outcome": OUTCOME_RECOVERY_BLOCKED,
			"accumulated_poise": accumulated,
			"threshold": threshold,
			"threshold_reached": false,
			"interruption_recovery_requested": false,
		}

	var recovered: float = maxf(0.0, accumulated - float(recovery["recovery_amount"]))
	if not is_finite(recovered):
		return _rejected(REASON_NONFINITE_RESULT)
	return {
		"accepted": true,
		"reason_id": &"",
		"outcome": OUTCOME_RECOVERED,
		"accumulated_poise": recovered,
		"threshold": threshold,
		"threshold_reached": false,
		"interruption_recovery_requested": false,
	}


static func _is_valid_state(raw_state: Variant) -> bool:
	if typeof(raw_state) != TYPE_DICTIONARY:
		return false
	var state: Dictionary = raw_state as Dictionary
	if not _has_nonnegative_finite_number(state, "accumulated_poise"):
		return false
	if not _has_positive_finite_number(state, "threshold"):
		return false
	if not _has_bool(state, "interruptible"):
		return false
	return float(state["accumulated_poise"]) < float(state["threshold"])


static func _is_valid_hit(raw_hit: Variant) -> bool:
	if typeof(raw_hit) != TYPE_DICTIONARY:
		return false
	return _has_nonnegative_finite_number(raw_hit as Dictionary, "poise_damage")


static func _is_valid_recovery(raw_recovery: Variant) -> bool:
	if typeof(raw_recovery) != TYPE_DICTIONARY:
		return false
	var recovery: Dictionary = raw_recovery as Dictionary
	return (
		_has_bool(recovery, "recovery_allowed")
		and _has_nonnegative_finite_number(recovery, "recovery_amount")
	)


static func _has_bool(data: Dictionary, key: String) -> bool:
	return data.has(key) and typeof(data[key]) == TYPE_BOOL


static func _has_nonnegative_finite_number(data: Dictionary, key: String) -> bool:
	if not _has_finite_number(data, key):
		return false
	return float(data[key]) >= 0.0


static func _has_positive_finite_number(data: Dictionary, key: String) -> bool:
	if not _has_finite_number(data, key):
		return false
	return float(data[key]) > 0.0


static func _has_finite_number(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return false
	var value: Variant = data[key]
	var value_type: int = typeof(value)
	if not (value_type == TYPE_INT or value_type == TYPE_FLOAT):
		return false
	return is_finite(float(value))


static func _rejected(reason_id: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason_id": reason_id,
		"outcome": OUTCOME_REJECTED,
		"accumulated_poise": 0.0,
		"threshold": 0.0,
		"threshold_reached": false,
		"interruption_recovery_requested": false,
	}
