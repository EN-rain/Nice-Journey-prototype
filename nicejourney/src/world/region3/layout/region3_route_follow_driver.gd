class_name Region3RouteFollowDriver
extends RefCounted

var _actor: CharacterBody2D
var _navigator: Node
var _goal_world_position := Vector2.ZERO
var _speed_px_per_second: float = 0.0
var _arrival_tolerance_px: float = 0.0
var _max_rejoin_distance_px: float = 0.0
var _path := PackedVector2Array()
var _waypoint_index: int = 0
var _complete: bool = false
var _last_reason_id: StringName = &""


func configure(
    actor: CharacterBody2D,
    navigator: Node,
    goal_world_position: Vector2,
    speed_px_per_second: float,
    arrival_tolerance_px: float,
    max_rejoin_distance_px: float
) -> PackedStringArray:
    _reset()
    var errors := PackedStringArray()
    if actor == null:
        errors.append("actor is required")
    if navigator == null or not navigator.has_method("is_ready_for_navigation") or not bool(navigator.call("is_ready_for_navigation")):
        errors.append("ready route navigator is required")
    if not is_finite(speed_px_per_second) or speed_px_per_second <= 0.0:
        errors.append("speed_px_per_second must be finite and positive")
    if not is_finite(arrival_tolerance_px) or arrival_tolerance_px <= 0.0:
        errors.append("arrival_tolerance_px must be finite and positive")
    if not is_finite(max_rejoin_distance_px) or max_rejoin_distance_px <= 0.0:
        errors.append("max_rejoin_distance_px must be finite and positive")
    if not errors.is_empty():
        return errors

    _actor = actor
    _navigator = navigator
    _goal_world_position = goal_world_position
    _speed_px_per_second = speed_px_per_second
    _arrival_tolerance_px = arrival_tolerance_px
    _max_rejoin_distance_px = max_rejoin_distance_px

    if not _replan_from_actor():
        errors.append("actor cannot reach the authored goal through the route navigator")
        _reset()
    return errors


func replan_from_actor() -> bool:
    if _actor == null or _navigator == null:
        _last_reason_id = &"navigation_unavailable"
        return false
    return _replan_from_actor()


func physics_step(delta: float, wait_requested: bool) -> Dictionary:
    if _actor == null or _navigator == null:
        return _step_result(false, &"not_configured", Vector2.ZERO)
    if not is_finite(delta) or delta <= 0.0:
        _actor.velocity = Vector2.ZERO
        return _step_result(false, &"invalid_delta", Vector2.ZERO)
    if _complete:
        _actor.velocity = Vector2.ZERO
        return _step_result(true, &"complete", Vector2.ZERO)
    if wait_requested:
        _actor.velocity = Vector2.ZERO
        return _step_result(true, &"wait_requested", Vector2.ZERO)

    _advance_arrived_waypoints()
    if _complete:
        _actor.velocity = Vector2.ZERO
        return _step_result(true, &"complete", Vector2.ZERO)

    var target := _path[_waypoint_index]
    var offset := target - _actor.global_position
    if offset.length_squared() <= 0.000001:
        _advance_arrived_waypoints()
        _actor.velocity = Vector2.ZERO
        return _step_result(true, &"", target)

    var step_speed := minf(_speed_px_per_second, offset.length() / delta)
    var before_position := _actor.global_position
    _actor.velocity = offset.normalized() * step_speed
    _actor.move_and_slide()
    var moved_distance := before_position.distance_to(_actor.global_position)
    var had_collision := _actor.get_slide_collision_count() > 0
    _advance_arrived_waypoints()
    if _complete:
        _actor.velocity = Vector2.ZERO
        return _step_result(true, &"complete", target, moved_distance, had_collision)
    return _step_result(true, &"physical_collision" if had_collision else &"", target, moved_distance, had_collision)


func is_complete() -> bool:
    return _complete


func current_waypoint() -> Vector2:
    if _complete or _waypoint_index < 0 or _waypoint_index >= _path.size():
        return _goal_world_position
    return _path[_waypoint_index]


func last_reason_id() -> StringName:
    return _last_reason_id


func _replan_from_actor() -> bool:
    var plan_variant: Variant = _navigator.call(
        "plan_rejoin_path",
        _actor.global_position,
        _goal_world_position,
        _max_rejoin_distance_px
    )
    if not plan_variant is Dictionary:
        _last_reason_id = &"navigation_unavailable"
        return false
    var plan := plan_variant as Dictionary
    _last_reason_id = StringName(plan.get("reason_id", &""))
    if not bool(plan.get("accepted", false)):
        return false
    var path_variant: Variant = plan.get("path", PackedVector2Array())
    if not path_variant is PackedVector2Array:
        _last_reason_id = &"navigation_unavailable"
        return false
    _path = path_variant as PackedVector2Array
    if _path.is_empty():
        _last_reason_id = &"route_unavailable"
        return false
    _waypoint_index = 0
    _complete = false
    _advance_arrived_waypoints()
    return true


func _advance_arrived_waypoints() -> void:
    while _waypoint_index < _path.size() and _actor.global_position.distance_to(_path[_waypoint_index]) <= _arrival_tolerance_px:
        _waypoint_index += 1
    if _waypoint_index >= _path.size():
        _complete = _actor.global_position.distance_to(_goal_world_position) <= _arrival_tolerance_px


func _step_result(
    accepted: bool,
    reason_id: StringName,
    target_world_position: Vector2,
    moved_distance_px: float = 0.0,
    had_collision: bool = false
) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "target_world_position": target_world_position,
        "complete": _complete,
        "waypoint_index": _waypoint_index,
        "waypoint_count": _path.size(),
        "moved_distance_px": moved_distance_px,
        "had_collision": had_collision,
    }


func _reset() -> void:
    if _actor != null:
        _actor.velocity = Vector2.ZERO
    _actor = null
    _navigator = null
    _goal_world_position = Vector2.ZERO
    _speed_px_per_second = 0.0
    _arrival_tolerance_px = 0.0
    _max_rejoin_distance_px = 0.0
    _path = PackedVector2Array()
    _waypoint_index = 0
    _complete = false
    _last_reason_id = &""
