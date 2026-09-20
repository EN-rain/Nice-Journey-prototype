class_name Region3RouteNavigator
extends Node

const ROUTE_GRAPH_SCRIPT: Script = preload("res://src/world/region3/layout/region3_route_navigation_graph.gd")

@export_node_path("Node2D") var layout_path: NodePath = NodePath("..")

var _graph: RefCounted
var _configuration_errors := PackedStringArray()


func _ready() -> void:
    rebuild()


func rebuild() -> PackedStringArray:
    _graph = ROUTE_GRAPH_SCRIPT.new()
    var layout := get_node_or_null(layout_path) as Region3AuthoredTownLayout
    _configuration_errors = _graph.configure_from_layout(layout)
    return _configuration_errors.duplicate()


func is_ready_for_navigation() -> bool:
    return _graph != null and _configuration_errors.is_empty()


func configuration_errors() -> PackedStringArray:
    return _configuration_errors.duplicate()


func contains_authored_point(world_position: Vector2) -> bool:
    if not is_ready_for_navigation():
        return false
    return _graph.contains_authored_point(world_position)


func find_path(world_start: Vector2, world_goal: Vector2) -> PackedVector2Array:
    if not is_ready_for_navigation():
        return PackedVector2Array()
    return _graph.find_path(world_start, world_goal)


func plan_rejoin_path(world_start: Vector2, world_goal: Vector2, max_rejoin_distance_px: float) -> Dictionary:
    if not is_ready_for_navigation():
        return {
            "accepted": false,
            "reason_id": &"navigation_unavailable",
            "rejoin_position": world_start,
            "rejoin_distance_px": INF,
            "path": PackedVector2Array(),
        }
    return _graph.plan_rejoin_path(world_start, world_goal, max_rejoin_distance_px)


func point_count() -> int:
    if not is_ready_for_navigation():
        return 0
    return int(_graph.point_count())
