extends SceneTree

const TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const ROUTE_GRAPH_SCRIPT: Script = preload("res://src/world/region3/layout/region3_route_navigation_graph.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var town := TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    root.add_child(town)
    await process_frame

    _expect(town != null, "Region 3 route-navigation fixture instantiates")
    if town == null:
        quit(1)
        return

    var navigator := town.get_node_or_null("RouteNavigator")
    _expect(navigator != null, "authored Region 3 scene owns a runtime route-navigation service")
    if navigator != null:
        _expect(navigator.is_ready_for_navigation(), "scene-owned route-navigation service compiles the authored routes on ready")
        _expect(navigator.configuration_errors().is_empty(), "scene-owned route-navigation service reports no configuration errors")
        _expect(navigator.point_count() > 0, "scene-owned route-navigation service exposes compiled navigation points")

    var before := _route_snapshot(town)
    var graph: RefCounted = ROUTE_GRAPH_SCRIPT.new()
    var errors: PackedStringArray = graph.configure_from_layout(town)
    _expect(errors.is_empty(), "authored Region 3 routes compile into one connected navigation graph")
    _expect(graph.point_count() > 0, "route navigation graph contains authored navigation points")
    _expect(_route_snapshot(town) == before, "route graph compilation does not mutate inspector-authored Line2D geometry")

    var tower_approach := Vector2.ZERO
    var has_tower_approach := false
    var service_approaches: Array[Vector2] = []
    for child: Node in town.get_children():
        var anchor := child as Region3TownStructureAnchor
        if anchor == null or anchor.category != Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
            continue
        var approach := anchor.approach_world_position(float(town.tile_size))
        _expect(graph.contains_authored_point(approach), "%s functional approach is an explicit route-navigation point" % String(anchor.structure_id))
        service_approaches.append(approach)
        if anchor.structure_id == &"r3:functional:01":
            tower_approach = approach
            has_tower_approach = true

    _expect(has_tower_approach, "Central Tower approach exists as the Region 3 route-navigation goal")
    if has_tower_approach:
        for approach: Vector2 in service_approaches:
            var path: PackedVector2Array = graph.find_path(approach, tower_approach)
            if navigator != null:
                _expect(not navigator.find_path(approach, tower_approach).is_empty(), "scene-owned navigator exposes the same functional route reachability")
            _expect(not path.is_empty(), "every functional approach has an authored route path to the Central Tower approach")
            if not path.is_empty():
                _expect(path[0].distance_to(approach) <= town.route_connection_tolerance_px, "service path starts at the requested authored approach")
                _expect(path[path.size() - 1].distance_to(tower_approach) <= town.route_connection_tolerance_px, "service path ends at the Central Tower approach")

        var point_count_before_rejoin: int = int(graph.point_count())
        var separated_start := Vector2(2940, 3400)
        var rejoin_plan: Dictionary = graph.plan_rejoin_path(separated_start, tower_approach, 64.0)
        _expect(bool(rejoin_plan.get("accepted", false)), "explicit rejoin planning accepts a caller-bounded separation near an authored route")
        _expect(StringName(rejoin_plan.get("reason_id", &"")) == &"rejoin_required", "separated route planning explicitly reports that physical rejoin is required")
        _expect(is_equal_approx(float(rejoin_plan.get("rejoin_distance_px", -1.0)), 28.0), "rejoin planning reports the physical distance to the authored route without moving the actor")
        _expect((rejoin_plan.get("rejoin_position", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(2912, 3400)), "rejoin planning returns the nearest authored route position")
        var rejoin_path := rejoin_plan.get("path", PackedVector2Array()) as PackedVector2Array
        _expect(not rejoin_path.is_empty() and rejoin_path[0].is_equal_approx(Vector2(2912, 3400)), "rejoin path starts at the explicit rejoin point rather than fabricating actor movement")
        _expect(graph.point_count() == point_count_before_rejoin, "temporary rejoin planning leaves the persistent authored route graph unchanged")
        var far_plan: Dictionary = graph.plan_rejoin_path(Vector2(4000, 4000), tower_approach, 32.0)
        _expect(not bool(far_plan.get("accepted", true)) and StringName(far_plan.get("reason_id", &"")) == &"start_too_far_from_route", "rejoin planning rejects separation beyond the caller-authorized distance")
        var invalid_distance_plan: Dictionary = graph.plan_rejoin_path(separated_start, tower_approach, 0.0)
        _expect(not bool(invalid_distance_plan.get("accepted", true)) and StringName(invalid_distance_plan.get("reason_id", &"")) == &"invalid_rejoin_distance", "rejoin planning rejects a missing/non-positive caller distance policy")
        var invalid_goal_plan: Dictionary = graph.plan_rejoin_path(separated_start, Vector2(-1234, -1234), 64.0)
        _expect(not bool(invalid_goal_plan.get("accepted", true)) and StringName(invalid_goal_plan.get("reason_id", &"")) == &"goal_not_authored", "rejoin planning refuses an unauthored goal")
        if navigator != null:
            var scene_rejoin_plan: Dictionary = navigator.plan_rejoin_path(separated_start, tower_approach, 64.0)
            _expect(bool(scene_rejoin_plan.get("accepted", false)), "scene-owned navigator exposes explicit non-teleporting rejoin plans")

        var routes := town.get_node_or_null(town.routes_path) as Node2D
        _expect(routes != null, "route-navigation graph resolves the inspector-authored Routes node")
        if routes != null:
            for route_name: String in ["NorthApproach", "SouthApproach", "WestApproach", "EastApproach"]:
                var line := routes.get_node_or_null(route_name) as Line2D
                _expect(line != null and not line.points.is_empty(), "%s exists for route-navigation planning" % route_name)
                if line == null or line.points.is_empty():
                    continue
                var outer_start := line.to_global(line.points[0])
                _expect(graph.contains_authored_point(outer_start), "%s outer endpoint is an authored navigation point" % route_name)
                _expect(not graph.find_path(outer_start, tower_approach).is_empty(), "%s has a connected authored path to the Central Tower approach" % route_name)

            var quest := routes.get_node_or_null("QuestConnector") as Line2D
            _expect(quest != null, "QuestConnector fixture exists for disconnected-navigation rejection")
            if quest != null:
                var original_points := quest.points.duplicate()
                quest.points = PackedVector2Array([Vector2(64, 64), Vector2(96, 64)])
                var disconnected_graph: RefCounted = ROUTE_GRAPH_SCRIPT.new()
                _expect(_contains(disconnected_graph.configure_from_layout(town), "fully connected"), "route-navigation graph rejects disconnected authored geometry")
                quest.points = original_points

    _expect(graph.find_path(Vector2(-9999, -9999), tower_approach).is_empty(), "route navigation refuses an unauthored off-network start instead of silently snapping across the map")

    town.queue_free()
    await process_frame

    if _failures == 0:
        print("REGION 3 ROUTE NAVIGATION GRAPH TEST PASS")
    else:
        push_error("REGION 3 ROUTE NAVIGATION GRAPH TEST FAILURES: %d" % _failures)
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
