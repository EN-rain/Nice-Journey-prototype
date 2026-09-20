class_name EscortObjectiveState
extends RefCounted

var actor_id: StringName = &""
var route_node_ids: Array[StringName] = []
var goal_id: StringName = &""
var safe_retry_origin_id: StringName = &""
var failure_policy_id: StringName = &""
var next_route_index: int = 0
var wait_requested: bool = false
var goal_reached: bool = false
var failed: bool = false
var failure_reason_id: StringName = &""

func configure(
    new_actor_id: StringName,
    new_route_node_ids: Array[StringName],
    new_goal_id: StringName,
    new_safe_retry_origin_id: StringName,
    new_failure_policy_id: StringName
) -> bool:
    if not StableId.is_valid(String(new_actor_id)) or not StableId.is_valid(String(new_goal_id)):
        return false
    if not StableId.is_valid(String(new_safe_retry_origin_id)) or not StableId.is_valid(String(new_failure_policy_id)):
        return false
    if new_route_node_ids.is_empty():
        return false
    var seen: Dictionary = {}
    for node_id: StringName in new_route_node_ids:
        if not StableId.is_valid(String(node_id)) or seen.has(node_id):
            return false
        seen[node_id] = true
    actor_id = new_actor_id
    route_node_ids = new_route_node_ids.duplicate()
    goal_id = new_goal_id
    safe_retry_origin_id = new_safe_retry_origin_id
    failure_policy_id = new_failure_policy_id
    next_route_index = 0
    wait_requested = false
    goal_reached = false
    failed = false
    failure_reason_id = &""
    return true

func set_wait_requested(value: bool) -> bool:
    if failed or goal_reached:
        return false
    wait_requested = value
    return true

func record_route_node_reached(node_id: StringName) -> Dictionary:
    if failed or goal_reached:
        return _result(false, &"objective_terminal")
    if next_route_index >= route_node_ids.size():
        return _result(false, &"route_already_complete")
    var expected := route_node_ids[next_route_index]
    if node_id == expected:
        next_route_index += 1
        return _result(true, &"")
    if next_route_index > 0 and route_node_ids[next_route_index - 1] == node_id:
        return _result(true, &"duplicate_ignored")
    return _result(false, &"route_node_out_of_order")

func record_goal_reached(reached_goal_id: StringName) -> Dictionary:
    if failed:
        return _result(false, &"objective_failed")
    if reached_goal_id != goal_id:
        return _result(false, &"wrong_goal")
    if next_route_index != route_node_ids.size():
        return _result(false, &"route_incomplete")
    if goal_reached:
        return _result(true, &"duplicate_ignored")
    goal_reached = true
    wait_requested = false
    return _result(true, &"")

func record_failure(reason_id: StringName) -> Dictionary:
    if not StableId.is_valid(String(reason_id)):
        return _result(false, &"invalid_failure_reason")
    if goal_reached:
        return _result(false, &"objective_complete")
    if failed:
        return _result(true, &"duplicate_ignored")
    failed = true
    failure_reason_id = reason_id
    wait_requested = false
    return _result(true, &"")

func is_complete() -> bool:
    return goal_reached and not failed

func to_dictionary() -> Dictionary:
    return {
        "actor_id": String(actor_id),
        "route_node_ids": _strings(route_node_ids),
        "goal_id": String(goal_id),
        "safe_retry_origin_id": String(safe_retry_origin_id),
        "failure_policy_id": String(failure_policy_id),
        "next_route_index": next_route_index,
        "wait_requested": wait_requested,
        "goal_reached": goal_reached,
        "failed": failed,
        "failure_reason_id": String(failure_reason_id),
    }

func load_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := validate_dictionary(data)
    if not errors.is_empty():
        return errors
    actor_id = StringName(String(data["actor_id"]))
    route_node_ids = _names(data["route_node_ids"] as Array)
    goal_id = StringName(String(data["goal_id"]))
    safe_retry_origin_id = StringName(String(data["safe_retry_origin_id"]))
    failure_policy_id = StringName(String(data["failure_policy_id"]))
    next_route_index = int(data["next_route_index"])
    wait_requested = bool(data["wait_requested"])
    goal_reached = bool(data["goal_reached"])
    failed = bool(data["failed"])
    failure_reason_id = StringName(String(data.get("failure_reason_id", "")))
    return errors

static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    for key: String in ["actor_id", "goal_id", "safe_retry_origin_id", "failure_policy_id"]:
        if not StableId.is_valid(String(data.get(key, ""))):
            errors.append("%s must be a stable ID" % key)
    var route := AnnihilationObjectiveState._validated_ids(data.get("route_node_ids", null), "route_node_ids", errors)
    if route.is_empty():
        errors.append("route_node_ids must not be empty")
    var route_index_variant: Variant = data.get("next_route_index", null)
    if not _is_integral(route_index_variant) or int(route_index_variant) < 0 or int(route_index_variant) > route.size():
        errors.append("next_route_index must point within or immediately after the route")
    for key: String in ["wait_requested", "goal_reached", "failed"]:
        if typeof(data.get(key, null)) != TYPE_BOOL:
            errors.append("%s must be boolean" % key)
    var reason := String(data.get("failure_reason_id", ""))
    if not reason.is_empty() and not StableId.is_valid(reason):
        errors.append("failure_reason_id must be empty or stable")
    if bool(data.get("goal_reached", false)) and bool(data.get("failed", false)):
        errors.append("escort cannot be both complete and failed")
    if bool(data.get("goal_reached", false)) and int(data.get("next_route_index", -1)) != route.size():
        errors.append("goal_reached requires the full authored route")
    if bool(data.get("failed", false)) and reason.is_empty():
        errors.append("failed escort requires a failure_reason_id")
    return errors

static func _is_integral(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return true
    if typeof(value) != TYPE_FLOAT:
        return false
    var number := float(value)
    return is_finite(number) and is_equal_approx(number, round(number))


func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "next_route_index": next_route_index,
        "route_count": route_node_ids.size(),
        "wait_requested": wait_requested,
        "goal_reached": goal_reached,
        "failed": failed,
        "complete": is_complete(),
    }

static func _strings(values: Array[StringName]) -> Array[String]:
    var result: Array[String] = []
    for value: StringName in values:
        result.append(String(value))
    return result

static func _names(values: Array) -> Array[StringName]:
    var result: Array[StringName] = []
    for value: Variant in values:
        result.append(StringName(String(value)))
    return result
