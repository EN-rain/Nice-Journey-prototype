class_name QuestEscortWaypointDriver
extends RefCounted

var _actor: CharacterBody2D = null
var _route_node_ids: Array[StringName] = []
var _positions := PackedVector2Array()
var _speed_px_per_second: float = 0.0
var _arrival_tolerance_px: float = 0.0
var _next_index: int = 0
var _complete: bool = false


func configure(
    actor: CharacterBody2D,
    waypoints: Array,
    speed_px_per_second: float,
    arrival_tolerance_px: float,
    next_route_index: int = 0
) -> PackedStringArray:
    _reset()
    var errors := PackedStringArray()
    if actor == null:
        errors.append("actor is required")
    if not is_finite(speed_px_per_second) or speed_px_per_second <= 0.0:
        errors.append("speed_px_per_second must be finite and positive")
    if not is_finite(arrival_tolerance_px) or arrival_tolerance_px <= 0.0:
        errors.append("arrival_tolerance_px must be finite and positive")
    if waypoints.is_empty():
        errors.append("at least one authored waypoint is required")
    if next_route_index < 0 or next_route_index > waypoints.size():
        errors.append("next_route_index must point within or immediately after the authored route")
    var seen: Dictionary = {}
    var ids: Array[StringName] = []
    var positions := PackedVector2Array()
    for index: int in range(waypoints.size()):
        var raw: Variant = waypoints[index]
        if not raw is Dictionary:
            errors.append("waypoint %d must be a dictionary" % index)
            continue
        var waypoint := raw as Dictionary
        var node_id := StringName(String(waypoint.get("route_node_id", &"")))
        var position_variant: Variant = waypoint.get("world_position", null)
        if not StableId.is_valid(String(node_id)):
            errors.append("waypoint %d route_node_id must be stable" % index)
        elif seen.has(node_id):
            errors.append("waypoint route_node_ids must be unique")
        else:
            seen[node_id] = true
        if not position_variant is Vector2:
            errors.append("waypoint %d world_position must be Vector2" % index)
            continue
        var position := position_variant as Vector2
        if not is_finite(position.x) or not is_finite(position.y):
            errors.append("waypoint %d world_position must be finite" % index)
            continue
        ids.append(node_id)
        positions.append(position)
    if not errors.is_empty():
        return errors
    _actor = actor
    _route_node_ids = ids
    _positions = positions
    _speed_px_per_second = speed_px_per_second
    _arrival_tolerance_px = arrival_tolerance_px
    _next_index = next_route_index
    _advance_arrived_waypoints()
    return errors


func physics_step(delta: float, wait_requested: bool) -> Dictionary:
    if _actor == null or _positions.is_empty():
        return _result(false, &"not_configured")
    if not is_finite(delta) or delta <= 0.0:
        _actor.velocity = Vector2.ZERO
        return _result(false, &"invalid_delta")
    if _complete:
        _actor.velocity = Vector2.ZERO
        return _result(true, &"complete")
    if wait_requested:
        _actor.velocity = Vector2.ZERO
        return _result(true, &"wait_requested")

    var reached_before := _next_index
    _advance_arrived_waypoints()
    if _complete:
        _actor.velocity = Vector2.ZERO
        return _result(true, &"complete", _reached_ids(reached_before, _next_index))

    var target := _positions[_next_index]
    var offset := target - _actor.global_position
    if offset.length_squared() <= 0.000001:
        _advance_arrived_waypoints()
        _actor.velocity = Vector2.ZERO
        return _result(true, &"complete" if _complete else &"", _reached_ids(reached_before, _next_index))
    var step_speed := minf(_speed_px_per_second, offset.length() / delta)
    var before := _actor.global_position
    _actor.velocity = offset.normalized() * step_speed
    _actor.move_and_slide()
    var moved := before.distance_to(_actor.global_position)
    var collision := _actor.get_slide_collision_count() > 0
    _advance_arrived_waypoints()
    if _complete:
        _actor.velocity = Vector2.ZERO
    var reason := &"physical_collision" if collision else (&"complete" if _complete else &"")
    return _result(true, reason, _reached_ids(reached_before, _next_index), moved, collision)


func is_complete() -> bool:
    return _complete


func next_route_node_id() -> StringName:
    if _complete or _next_index < 0 or _next_index >= _route_node_ids.size():
        return &""
    return _route_node_ids[_next_index]


func next_route_index() -> int:
    return _next_index


func next_world_position() -> Vector2:
    if _complete or _next_index < 0 or _next_index >= _positions.size():
        return _positions[-1] if not _positions.is_empty() else Vector2.ZERO
    return _positions[_next_index]


func _advance_arrived_waypoints() -> void:
    if _actor == null:
        return
    while _next_index < _positions.size() and _actor.global_position.distance_to(_positions[_next_index]) <= _arrival_tolerance_px:
        _next_index += 1
    _complete = _next_index >= _positions.size()


func _reached_ids(start_index: int, end_index: int) -> Array[StringName]:
    var result: Array[StringName] = []
    for index: int in range(start_index, mini(end_index, _route_node_ids.size())):
        result.append(_route_node_ids[index])
    return result


func _result(
    accepted: bool,
    reason_id: StringName,
    reached_route_node_ids: Array[StringName] = [],
    moved_distance_px: float = 0.0,
    had_collision: bool = false
) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "reached_route_node_ids": reached_route_node_ids.duplicate(),
        "next_route_node_id": next_route_node_id(),
        "next_world_position": next_world_position(),
        "complete": _complete,
        "next_index": _next_index,
        "waypoint_count": _positions.size(),
        "moved_distance_px": moved_distance_px,
        "had_collision": had_collision,
    }


func _reset() -> void:
    if _actor != null:
        _actor.velocity = Vector2.ZERO
    _actor = null
    _route_node_ids = []
    _positions = PackedVector2Array()
    _speed_px_per_second = 0.0
    _arrival_tolerance_px = 0.0
    _next_index = 0
    _complete = false
