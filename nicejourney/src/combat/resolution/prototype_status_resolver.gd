class_name PrototypeStatusResolver
extends RefCounted

const BEHAVIOR_BURN: StringName = &"burn"
const BEHAVIOR_SLOW: StringName = &"slow"

const OUTCOME_REJECTED: StringName = &"rejected"
const OUTCOME_APPLIED: StringName = &"applied"
const OUTCOME_REAPPLIED: StringName = &"reapplied"
const OUTCOME_ADVANCED: StringName = &"advanced"

const REASON_INVALID_STATES: StringName = &"invalid_states"
const REASON_INVALID_APPLICATION: StringName = &"invalid_application"
const REASON_DUPLICATE_STATUS_ID: StringName = &"duplicate_status_id"
const REASON_BEHAVIOR_MISMATCH: StringName = &"behavior_mismatch"
const REASON_INVALID_ELAPSED_TICKS: StringName = &"invalid_elapsed_ticks"
const REASON_INVALID_BEHAVIOR: StringName = &"invalid_behavior"
const REASON_PRODUCTION_AUTHORITY_INCOMPLETE: StringName = &"production_authority_incomplete"


static func apply_status(raw_states: Variant, raw_application: Variant) -> Dictionary:
	var states_result: Dictionary = normalize_states(raw_states)
	if not bool(states_result["accepted"]):
		return _rejected(states_result["reason_id"])
	if not _is_valid_application(raw_application):
		return _rejected(REASON_INVALID_APPLICATION)

	var states: Array = states_result["states"] as Array
	var application: Dictionary = raw_application as Dictionary
	var status_id: StringName = StringName(String(application["status_id"]))
	var behavior: StringName = StringName(String(application["behavior"]))
	var magnitude: float = float(application["magnitude"])
	var duration_ticks: int = int(application["duration_ticks"])
	var outcome: StringName = OUTCOME_APPLIED
	var merged: bool = false

	for index: int in states.size():
		var existing: Dictionary = states[index] as Dictionary
		if existing["status_id"] != status_id:
			continue
		if existing["behavior"] != behavior:
			return _rejected(REASON_BEHAVIOR_MISMATCH)
		existing["magnitude"] = maxf(float(existing["magnitude"]), magnitude)
		existing["remaining_ticks"] = maxi(int(existing["remaining_ticks"]), duration_ticks)
		states[index] = existing
		outcome = OUTCOME_REAPPLIED
		merged = true
		break

	if not merged:
		states.append({
			"status_id": status_id,
			"behavior": behavior,
			"magnitude": magnitude,
			"remaining_ticks": duration_ticks,
		})

	_sort_states(states)
	return {
		"accepted": true,
		"reason_id": &"",
		"outcome": outcome,
		"states": states,
	}


static func advance_duration(raw_states: Variant, raw_elapsed_ticks: Variant) -> Dictionary:
	var states_result: Dictionary = normalize_states(raw_states)
	if not bool(states_result["accepted"]):
		return _rejected(states_result["reason_id"])
	if typeof(raw_elapsed_ticks) != TYPE_INT or int(raw_elapsed_ticks) < 0:
		return _rejected(REASON_INVALID_ELAPSED_TICKS)

	var elapsed_ticks: int = int(raw_elapsed_ticks)
	var states: Array = states_result["states"] as Array
	var advanced: Array = []
	for state_variant: Variant in states:
		var state: Dictionary = state_variant as Dictionary
		var remaining: int = int(state["remaining_ticks"]) - elapsed_ticks
		if remaining <= 0:
			continue
		state["remaining_ticks"] = remaining
		advanced.append(state)

	_sort_states(advanced)
	return {
		"accepted": true,
		"reason_id": &"",
		"outcome": OUTCOME_ADVANCED,
		"states": advanced,
	}


static func behavior_contract(raw_behavior: Variant) -> Dictionary:
	if not _is_valid_behavior(raw_behavior):
		return {
			"accepted": false,
			"reason_id": REASON_INVALID_BEHAVIOR,
			"behavior": &"",
			"damage_over_time": false,
			"movement_speed_reduction_only": false,
			"can_crit": false,
			"can_weak_point": false,
			"affects_action_clocks": false,
			"affects_ai_reaction_timing": false,
		}

	var behavior: StringName = StringName(String(raw_behavior))
	return {
		"accepted": true,
		"reason_id": &"",
		"behavior": behavior,
		"damage_over_time": behavior == BEHAVIOR_BURN,
		"movement_speed_reduction_only": behavior == BEHAVIOR_SLOW,
		"can_crit": false,
		"can_weak_point": false,
		"affects_action_clocks": false,
		"affects_ai_reaction_timing": false,
	}


static func validate_production_application(raw_application: Variant) -> Dictionary:
	if not _is_valid_application(raw_application):
		return {
			"accepted": false,
			"reason_id": REASON_INVALID_APPLICATION,
			"behavior": &"",
			"missing_authoritative_fields": PackedStringArray(),
			"known_semantics": {},
		}
	var application := raw_application as Dictionary
	var behavior := StringName(String(application.get("behavior", &"")))
	var authority := PrototypeStatusProductionAuthority.readiness(behavior)
	if not bool(authority.get("accepted", false)):
		return {
			"accepted": false,
			"reason_id": REASON_INVALID_BEHAVIOR,
			"behavior": behavior,
			"missing_authoritative_fields": PackedStringArray(),
			"known_semantics": {},
		}
	if not bool(authority.get("production_ready", false)):
		return {
			"accepted": false,
			"reason_id": REASON_PRODUCTION_AUTHORITY_INCOMPLETE,
			"behavior": behavior,
			"missing_authoritative_fields": (authority.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray).duplicate(),
			"known_semantics": (authority.get("known_semantics", {}) as Dictionary).duplicate(true),
		}
	return {
		"accepted": true,
		"reason_id": &"",
		"behavior": behavior,
		"missing_authoritative_fields": PackedStringArray(),
		"known_semantics": (authority.get("known_semantics", {}) as Dictionary).duplicate(true),
	}


static func apply_production_status(raw_states: Variant, raw_application: Variant) -> Dictionary:
	var readiness := validate_production_application(raw_application)
	if not bool(readiness.get("accepted", false)):
		return {
			"accepted": false,
			"reason_id": StringName(readiness.get("reason_id", REASON_PRODUCTION_AUTHORITY_INCOMPLETE)),
			"outcome": OUTCOME_REJECTED,
			"states": [],
			"behavior": StringName(readiness.get("behavior", &"")),
			"production_missing_fields": (readiness.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray).duplicate(),
			"production_known_semantics": (readiness.get("known_semantics", {}) as Dictionary).duplicate(true),
		}
	var result := apply_status(raw_states, raw_application)
	result["production_missing_fields"] = PackedStringArray()
	result["production_known_semantics"] = (readiness.get("known_semantics", {}) as Dictionary).duplicate(true)
	return result


static func build_production_execution_requests(raw_states: Variant) -> Dictionary:
	var generic := build_execution_requests(raw_states)
	if not bool(generic.get("accepted", false)):
		return generic
	var unresolved: Array[Dictionary] = []
	for raw_request: Variant in generic.get("requests", []) as Array:
		var request := raw_request as Dictionary
		if bool(request.get("production_ready", false)):
			continue
		unresolved.append({
			"status_id": StringName(String(request.get("status_id", &""))),
			"behavior": StringName(String(request.get("behavior", &""))),
			"missing_authoritative_fields": (request.get("production_missing_fields", PackedStringArray()) as PackedStringArray).duplicate(),
			"known_semantics": (request.get("production_known_semantics", {}) as Dictionary).duplicate(true),
		})
	if not unresolved.is_empty():
		return {
			"accepted": false,
			"reason_id": REASON_PRODUCTION_AUTHORITY_INCOMPLETE,
			"requests": [],
			"unresolved_statuses": unresolved,
		}
	var result := generic.duplicate(true)
	result["unresolved_statuses"] = []
	return result


static func build_execution_requests(raw_states: Variant) -> Dictionary:
	var normalized_result := normalize_states(raw_states)
	if not bool(normalized_result.get("accepted", false)):
		return {
			"accepted": false,
			"reason_id": StringName(normalized_result.get("reason_id", REASON_INVALID_STATES)),
			"requests": [],
		}

	var requests: Array = []
	for raw_state: Variant in normalized_result.get("states", []) as Array:
		var state := raw_state as Dictionary
		var contract := behavior_contract(state.get("behavior", &""))
		if not bool(contract.get("accepted", false)):
			return {
				"accepted": false,
				"reason_id": StringName(contract.get("reason_id", REASON_INVALID_BEHAVIOR)),
				"requests": [],
			}
		var production_authority := PrototypeStatusProductionAuthority.readiness(StringName(String(state.get("behavior", &""))))
		requests.append({
			"status_id": StringName(String(state.get("status_id", &""))),
			"behavior": StringName(String(state.get("behavior", &""))),
			"opaque_magnitude": float(state.get("magnitude", 0.0)),
			"remaining_ticks": int(state.get("remaining_ticks", 0)),
			"damage_over_time": bool(contract.get("damage_over_time", false)),
			"movement_speed_reduction_only": bool(contract.get("movement_speed_reduction_only", false)),
			"can_crit": false,
			"can_weak_point": false,
			"affects_action_clocks": false,
			"affects_ai_reaction_timing": false,
			"production_ready": bool(production_authority.get("production_ready", false)),
			"production_missing_fields": (production_authority.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray).duplicate(),
			"production_known_semantics": (production_authority.get("known_semantics", {}) as Dictionary).duplicate(true),
		})
	return {
		"accepted": true,
		"reason_id": &"",
		"requests": requests,
	}


static func merge_peer_live_state_collections(raw_collections: Variant) -> Dictionary:
	if typeof(raw_collections) != TYPE_ARRAY:
		return {"accepted": false, "reason_id": REASON_INVALID_STATES, "states": []}
	var merged_states: Array = []
	for raw_collection: Variant in raw_collections as Array:
		var normalized_result := normalize_states(raw_collection)
		if not bool(normalized_result.get("accepted", false)):
			return {"accepted": false, "reason_id": StringName(normalized_result.get("reason_id", REASON_INVALID_STATES)), "states": []}
		for raw_state: Variant in normalized_result.get("states", []) as Array:
			var state := raw_state as Dictionary
			var merge_result := apply_status(merged_states, {
				"status_id": state.get("status_id", &""),
				"behavior": state.get("behavior", &""),
				"magnitude": state.get("magnitude", 0.0),
				"duration_ticks": state.get("remaining_ticks", 0),
			})
			if not bool(merge_result.get("accepted", false)):
				return {"accepted": false, "reason_id": StringName(merge_result.get("reason_id", REASON_INVALID_STATES)), "states": []}
			merged_states = (merge_result.get("states", []) as Array).duplicate(true)
	return {"accepted": true, "reason_id": &"", "states": merged_states.duplicate(true)}


static func normalize_states(raw_states: Variant) -> Dictionary:
	if typeof(raw_states) != TYPE_ARRAY:
		return {"accepted": false, "reason_id": REASON_INVALID_STATES, "states": []}

	var normalized: Array = []
	var seen_ids: Dictionary = {}
	for raw_state: Variant in raw_states as Array:
		if not _is_valid_state(raw_state):
			return {"accepted": false, "reason_id": REASON_INVALID_STATES, "states": []}
		var state: Dictionary = raw_state as Dictionary
		var status_id: StringName = StringName(String(state["status_id"]))
		if seen_ids.has(status_id):
			return {"accepted": false, "reason_id": REASON_DUPLICATE_STATUS_ID, "states": []}
		seen_ids[status_id] = true
		normalized.append({
			"status_id": status_id,
			"behavior": StringName(String(state["behavior"])),
			"magnitude": float(state["magnitude"]),
			"remaining_ticks": int(state["remaining_ticks"]),
		})

	_sort_states(normalized)
	return {"accepted": true, "reason_id": &"", "states": normalized}


static func _is_valid_state(raw_state: Variant) -> bool:
	if typeof(raw_state) != TYPE_DICTIONARY:
		return false
	var state: Dictionary = raw_state as Dictionary
	return (
		_has_stable_id(state, "status_id")
		and _has_behavior(state, "behavior")
		and _has_nonnegative_finite_number(state, "magnitude")
		and _has_positive_int(state, "remaining_ticks")
	)


static func _is_valid_application(raw_application: Variant) -> bool:
	if typeof(raw_application) != TYPE_DICTIONARY:
		return false
	var application: Dictionary = raw_application as Dictionary
	return (
		_has_stable_id(application, "status_id")
		and _has_behavior(application, "behavior")
		and _has_nonnegative_finite_number(application, "magnitude")
		and _has_positive_int(application, "duration_ticks")
	)


static func _has_stable_id(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return false
	var value: Variant = data[key]
	if not (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME):
		return false
	return StableId.is_valid(String(value))


static func _has_behavior(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return false
	return _is_valid_behavior(data[key])


static func _is_valid_behavior(value: Variant) -> bool:
	if not (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME):
		return false
	return [BEHAVIOR_BURN, BEHAVIOR_SLOW].has(StringName(String(value)))


static func _has_nonnegative_finite_number(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return false
	var value: Variant = data[key]
	var value_type: int = typeof(value)
	if not (value_type == TYPE_INT or value_type == TYPE_FLOAT):
		return false
	return is_finite(float(value)) and float(value) >= 0.0


static func _has_positive_int(data: Dictionary, key: String) -> bool:
	return data.has(key) and typeof(data[key]) == TYPE_INT and int(data[key]) > 0


static func _sort_states(states: Array) -> void:
	states.sort_custom(func(left: Variant, right: Variant) -> bool:
		return String((left as Dictionary)["status_id"]) < String((right as Dictionary)["status_id"])
	)


static func _rejected(reason_id: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason_id": reason_id,
		"outcome": OUTCOME_REJECTED,
		"states": [],
	}
