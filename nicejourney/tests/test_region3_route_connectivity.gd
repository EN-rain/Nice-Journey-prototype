extends SceneTree

const TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var town := TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    root.add_child(town)
    await process_frame

    _expect(town != null, "Region 3 route-connectivity fixture instantiates")
    if town != null:
        var route_errors := town.validate_route_connectivity()
        _expect(route_errors.is_empty(), "all authored town routes form one connected circulation graph")

        var routes := town.get_node_or_null(town.routes_path) as Node2D
        _expect(routes != null, "route-connectivity validator resolves inspector-authored Routes node")
        if routes != null:
            var route_names: Array[String] = []
            for child: Node in routes.get_children():
                if child is Line2D:
                    route_names.append(String(child.name))
            _expect(route_names.size() == 13, "current route graph contains circulation, four approaches, plaza spine and seven service connectors")

            for child: Node in town.get_children():
                var anchor := child as Region3TownStructureAnchor
                if anchor == null or anchor.category != Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
                    continue
                var approach_world := anchor.approach_world_position(float(town.tile_size))
                var touches := false
                for route_child: Node in routes.get_children():
                    var line := route_child as Line2D
                    if line != null and _point_touches_polyline(approach_world, line.points, town.route_connection_tolerance_px):
                        touches = true
                        break
                _expect(touches, "%s approach tile touches the authored circulation graph" % String(anchor.structure_id))

            var quest := routes.get_node_or_null("QuestConnector") as Line2D
            _expect(quest != null, "QuestConnector fixture exists")
            if quest != null:
                var original_points := quest.points.duplicate()
                quest.points = PackedVector2Array([Vector2(64, 64), Vector2(96, 64)])
                var disconnected := town.validate_route_connectivity()
                _expect(_contains(disconnected, "approach tile must touch"), "validator rejects a functional building whose connector is moved off its approach tile")
                _expect(_contains(disconnected, "QuestConnector must connect to the circulation graph"), "validator rejects a disconnected authored route")
                quest.points = original_points
                _expect(town.validate_route_connectivity().is_empty(), "restoring inspector-authored connector points restores a valid graph")

        var original_tolerance := town.route_connection_tolerance_px
        town.route_connection_tolerance_px = 0.0
        _expect(_contains(town.validate_route_connectivity(), "route_connection_tolerance_px"), "non-positive connection tolerance is rejected")
        town.route_connection_tolerance_px = original_tolerance

        var before := _route_snapshot(town)
        town.validate_route_connectivity()
        _expect(_route_snapshot(town) == before, "route validation does not mutate authored Line2D points")

    if town != null:
        town.queue_free()
    await process_frame

    if _failures == 0:
        print("REGION 3 ROUTE CONNECTIVITY TEST PASS")
    else:
        push_error("REGION 3 ROUTE CONNECTIVITY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _route_snapshot(town: Region3AuthoredTownLayout) -> Dictionary:
    var snapshot: Dictionary = {}
    var routes := town.get_node_or_null(town.routes_path) as Node2D
    if routes == null:
        return snapshot
    for child: Node in routes.get_children():
        var line := child as Line2D
        if line != null:
            snapshot[String(line.name)] = line.points.duplicate()
    return snapshot


func _point_touches_polyline(point: Vector2, polyline: PackedVector2Array, tolerance: float) -> bool:
    for index: int in range(polyline.size() - 1):
        if _distance_to_segment(point, polyline[index], polyline[index + 1]) <= tolerance:
            return true
    return false


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
    var segment := finish - start
    var length_squared := segment.length_squared()
    if length_squared <= 0.000001:
        return point.distance_to(start)
    var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
    return point.distance_to(start + segment * ratio)


func _contains(errors: PackedStringArray, fragment: String) -> bool:
    for error: String in errors:
        if error.contains(fragment):
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
