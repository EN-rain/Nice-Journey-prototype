class_name Region3RouteNavigationGraph
extends RefCounted

var _graph := AStar2D.new()
var _point_ids: Array[int] = []
var _segments: Array[Dictionary] = []
var _next_point_id: int = 1
var _connection_tolerance_px: float = 0.5


func configure_from_layout(layout: Region3AuthoredTownLayout) -> PackedStringArray:
    _reset()
    var errors := PackedStringArray()
    if layout == null:
        errors.append("layout is required")
        return errors
    if not is_finite(layout.route_connection_tolerance_px) or layout.route_connection_tolerance_px <= 0.0:
        errors.append("route_connection_tolerance_px must be finite and positive")
        return errors
    _connection_tolerance_px = layout.route_connection_tolerance_px

    var routes := layout.get_node_or_null(layout.routes_path) as Node2D
    if routes == null:
        errors.append("routes node is required")
        return errors

    var lines: Array[Line2D] = []
    var authored_points: Array[Vector2] = []
    for child: Node in routes.get_children():
        var line := child as Line2D
        if line == null:
            continue
        if line.points.size() < 2:
            errors.append("%s must contain at least two route points" % line.name)
            continue
        lines.append(line)
        for point: Vector2 in line.points:
            authored_points.append(line.to_global(point))

    if lines.is_empty():
        errors.append("at least one authored route line is required")
        return errors

    for child: Node in layout.get_children():
        var anchor := child as Region3TownStructureAnchor
        if anchor == null or anchor.category != Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
            continue
        authored_points.append(anchor.approach_world_position(float(layout.tile_size)))

    for line: Line2D in lines:
        for segment_index: int in range(line.points.size() - 1):
            var start := line.to_global(line.points[segment_index])
            var finish := line.to_global(line.points[segment_index + 1])
            _append_segment(start, finish, authored_points)

    if _point_ids.is_empty():
        errors.append("authored route graph produced no navigation points")
        return errors

    var origin_id := _point_ids[0]
    for point_id: int in _point_ids:
        if _graph.get_id_path(origin_id, point_id).is_empty():
            errors.append("authored route graph must be fully connected")
            break
    return errors


func point_count() -> int:
    return _point_ids.size()


func contains_authored_point(world_position: Vector2) -> bool:
    return _find_point_id(world_position) >= 0


func find_path(world_start: Vector2, world_goal: Vector2) -> PackedVector2Array:
    var start_id := _find_point_id(world_start)
    var goal_id := _find_point_id(world_goal)
    if start_id < 0 or goal_id < 0:
        return PackedVector2Array()
    return _graph.get_point_path(start_id, goal_id)


func plan_rejoin_path(world_start: Vector2, world_goal: Vector2, max_rejoin_distance_px: float) -> Dictionary:
    if not is_finite(max_rejoin_distance_px) or max_rejoin_distance_px <= 0.0:
        return _rejoin_result(false, &"invalid_rejoin_distance", world_start, INF, PackedVector2Array())
    var goal_id := _find_point_id(world_goal)
    if goal_id < 0:
        return _rejoin_result(false, &"goal_not_authored", world_start, INF, PackedVector2Array())

    var exact_start_id := _find_point_id(world_start)
    if exact_start_id >= 0:
        return _rejoin_result(true, &"", world_start, 0.0, _graph.get_point_path(exact_start_id, goal_id))

    var nearest := _nearest_segment_projection(world_start)
    if nearest.is_empty():
        return _rejoin_result(false, &"route_unavailable", world_start, INF, PackedVector2Array())
    var rejoin_position: Vector2 = nearest["position"]
    var rejoin_distance := world_start.distance_to(rejoin_position)
    if rejoin_distance > max_rejoin_distance_px:
        return _rejoin_result(false, &"start_too_far_from_route", rejoin_position, rejoin_distance, PackedVector2Array())

    var projection_id := _find_point_id(rejoin_position)
    if projection_id >= 0:
        return _rejoin_result(true, &"rejoin_required", rejoin_position, rejoin_distance, _graph.get_point_path(projection_id, goal_id))

    var temporary_id := _next_point_id
    _graph.add_point(temporary_id, rejoin_position)
    _graph.connect_points(temporary_id, int(nearest["from_id"]), true)
    _graph.connect_points(temporary_id, int(nearest["to_id"]), true)
    var path := _graph.get_point_path(temporary_id, goal_id)
    _graph.remove_point(temporary_id)
    return _rejoin_result(not path.is_empty(), &"rejoin_required" if not path.is_empty() else &"route_unavailable", rejoin_position, rejoin_distance, path)


func _append_segment(start: Vector2, finish: Vector2, authored_points: Array[Vector2]) -> void:
    if start.distance_squared_to(finish) <= 0.000001:
        return
    var candidates: Array[Vector2] = [start, finish]
    for point: Vector2 in authored_points:
        if _distance_to_segment(point, start, finish) <= _connection_tolerance_px:
            candidates.append(point)

    var segment := finish - start
    var length_squared := segment.length_squared()
    candidates.sort_custom(func(first: Vector2, second: Vector2) -> bool:
        var first_ratio := (first - start).dot(segment) / length_squared
        var second_ratio := (second - start).dot(segment) / length_squared
        return first_ratio < second_ratio
    )

    var ordered: Array[Vector2] = []
    for point: Vector2 in candidates:
        if ordered.is_empty() or ordered[ordered.size() - 1].distance_to(point) > _connection_tolerance_px:
            ordered.append(point)

    for index: int in range(ordered.size() - 1):
        var from_id := _find_or_add_point(ordered[index])
        var to_id := _find_or_add_point(ordered[index + 1])
        if from_id == to_id:
            continue
        if not _graph.are_points_connected(from_id, to_id):
            _graph.connect_points(from_id, to_id, true)
        _segments.append({
            "from_id": from_id,
            "to_id": to_id,
            "start": ordered[index],
            "finish": ordered[index + 1],
        })


func _find_or_add_point(world_position: Vector2) -> int:
    var existing := _find_point_id(world_position)
    if existing >= 0:
        return existing
    var point_id := _next_point_id
    _next_point_id += 1
    _graph.add_point(point_id, world_position)
    _point_ids.append(point_id)
    return point_id


func _find_point_id(world_position: Vector2) -> int:
    for point_id: int in _point_ids:
        if _graph.get_point_position(point_id).distance_to(world_position) <= _connection_tolerance_px:
            return point_id
    return -1


func _nearest_segment_projection(world_position: Vector2) -> Dictionary:
    var best: Dictionary = {}
    var best_distance := INF
    for segment_data: Dictionary in _segments:
        var start: Vector2 = segment_data["start"]
        var finish: Vector2 = segment_data["finish"]
        var projection := _project_to_segment(world_position, start, finish)
        var distance := world_position.distance_to(projection)
        if distance < best_distance:
            best_distance = distance
            best = {
                "position": projection,
                "from_id": int(segment_data["from_id"]),
                "to_id": int(segment_data["to_id"]),
            }
    return best


func _project_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> Vector2:
    var segment := finish - start
    var length_squared := segment.length_squared()
    if length_squared <= 0.000001:
        return start
    var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
    return start + segment * ratio


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
    return point.distance_to(_project_to_segment(point, start, finish))


func _rejoin_result(accepted: bool, reason_id: StringName, rejoin_position: Vector2, rejoin_distance: float, path: PackedVector2Array) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "rejoin_position": rejoin_position,
        "rejoin_distance_px": rejoin_distance,
        "path": path,
    }


func _reset() -> void:
    _graph.clear()
    _point_ids.clear()
    _segments.clear()
    _next_point_id = 1
    _connection_tolerance_px = 0.5
