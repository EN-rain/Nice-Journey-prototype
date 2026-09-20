class_name MapRegionCanvas
extends Control

@export_range(0.0, 64.0, 1.0) var padding_px: float = 8.0
@export_range(1.0, 8.0, 0.5) var route_width_px: float = 2.0
@export_range(2.0, 14.0, 0.5) var landmark_radius_px: float = 5.0
@export var map_background_color: Color = Color(0.09, 0.11, 0.12, 0.92)
@export var town_fill_color: Color = Color(0.16, 0.18, 0.2, 0.75)
@export var plaza_fill_color: Color = Color(0.24, 0.23, 0.2, 0.8)
@export var route_color: Color = Color(0.72, 0.68, 0.58, 1.0)
@export var landmark_color: Color = Color(0.88, 0.84, 0.7, 1.0)
@export var explored_subzone_fill_color: Color = Color(0.32, 0.42, 0.34, 0.22)
@export var explored_subzone_outline_color: Color = Color(0.58, 0.72, 0.6, 0.95)
@export var risk_outline_color: Color = Color(0.95, 0.48, 0.25, 1.0)
@export_range(1.0, 6.0, 0.5) var risk_outline_width_px: float = 2.0

var _map_size_tiles: Vector2i = Vector2i.ZERO
var _town_tile_rect: Rect2i = Rect2i()
var _plaza_tile_rect: Rect2i = Rect2i()
var _route_polylines: Array[Dictionary] = []
var _public_landmarks: Array[Dictionary] = []
var _explored_subzones: Array[Dictionary] = []
var _risk_markers: Array[Dictionary] = []


func configure_geometry(
    map_size_tiles: Vector2i,
    town_tile_rect: Rect2i,
    plaza_tile_rect: Rect2i,
    raw_routes: Variant,
    raw_landmarks: Variant,
    raw_explored_subzones: Variant = []
) -> bool:
    if map_size_tiles.x <= 0 or map_size_tiles.y <= 0:
        return false
    if not _rect_inside_map(town_tile_rect, map_size_tiles) or not _rect_inside_map(plaza_tile_rect, map_size_tiles):
        return false
    if not raw_routes is Array or not raw_landmarks is Array or not raw_explored_subzones is Array:
        return false

    var routes: Array[Dictionary] = []
    var seen_routes: Dictionary = {}
    for raw_route: Variant in raw_routes as Array:
        if not raw_route is Dictionary:
            return false
        var route := raw_route as Dictionary
        var route_name := StringName(String(route.get("route_name", &"")))
        var points_variant: Variant = route.get("points_tiles", null)
        if String(route_name).is_empty() or seen_routes.has(route_name) or not points_variant is PackedVector2Array:
            return false
        var points := points_variant as PackedVector2Array
        if points.size() < 2:
            return false
        for point: Vector2 in points:
            if not _point_inside_map(point, map_size_tiles):
                return false
        seen_routes[route_name] = true
        routes.append({
            "route_name": route_name,
            "points_tiles": points.duplicate(),
        })
    routes.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        return String(first.get("route_name", &"")) < String(second.get("route_name", &""))
    )

    var landmarks: Array[Dictionary] = []
    var seen_landmarks: Dictionary = {}
    for raw_landmark: Variant in raw_landmarks as Array:
        if not raw_landmark is Dictionary:
            return false
        var landmark := raw_landmark as Dictionary
        var landmark_id := StringName(String(landmark.get("landmark_id", &"")))
        var landmark_kind := StringName(String(landmark.get("landmark_kind", &"")))
        var position_variant: Variant = landmark.get("position_tiles", null)
        if not StableId.is_valid(String(landmark_id)) or String(landmark_kind).is_empty() or seen_landmarks.has(landmark_id) or not position_variant is Vector2:
            return false
        var position_tiles := position_variant as Vector2
        if not _point_inside_map(position_tiles, map_size_tiles):
            return false
        seen_landmarks[landmark_id] = true
        landmarks.append({
            "landmark_id": landmark_id,
            "landmark_kind": landmark_kind,
            "position_tiles": position_tiles,
        })
    landmarks.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        return String(first.get("landmark_id", &"")) < String(second.get("landmark_id", &""))
    )

    var explored_subzones: Array[Dictionary] = []
    var seen_subzones: Dictionary = {}
    for raw_subzone: Variant in raw_explored_subzones as Array:
        if not raw_subzone is Dictionary:
            return false
        var subzone := raw_subzone as Dictionary
        var zone_id := StringName(String(subzone.get("zone_id", &"")))
        var rect_variant: Variant = subzone.get("tile_rect", null)
        if not StableId.is_valid(String(zone_id)) or seen_subzones.has(zone_id) or not rect_variant is Rect2i:
            return false
        var tile_rect := rect_variant as Rect2i
        if not _rect_inside_map(tile_rect, map_size_tiles):
            return false
        seen_subzones[zone_id] = true
        explored_subzones.append({
            "zone_id": zone_id,
            "tile_rect": tile_rect,
        })
    explored_subzones.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        return String(first.get("zone_id", &"")) < String(second.get("zone_id", &""))
    )

    _map_size_tiles = map_size_tiles
    _town_tile_rect = town_tile_rect
    _plaza_tile_rect = plaza_tile_rect
    _route_polylines = routes
    _public_landmarks = landmarks
    _explored_subzones = explored_subzones
    _risk_markers.clear()
    queue_redraw()
    return true


func clear_geometry() -> void:
    _map_size_tiles = Vector2i.ZERO
    _town_tile_rect = Rect2i()
    _plaza_tile_rect = Rect2i()
    _route_polylines.clear()
    _public_landmarks.clear()
    _explored_subzones.clear()
    _risk_markers.clear()
    queue_redraw()


func route_count() -> int:
    return _route_polylines.size()


func landmark_count() -> int:
    return _public_landmarks.size()


func explored_subzone_count() -> int:
    return _explored_subzones.size()


func route_polylines() -> Array[Dictionary]:
    return _route_polylines.duplicate(true)


func public_landmarks() -> Array[Dictionary]:
    return _public_landmarks.duplicate(true)


func explored_subzones() -> Array[Dictionary]:
    return _explored_subzones.duplicate(true)


func set_risk_markers(raw_markers: Variant) -> bool:
    if not raw_markers is Array:
        return false
    var markers: Array[Dictionary] = []
    var seen: Dictionary = {}
    for raw_marker: Variant in raw_markers as Array:
        if not raw_marker is Dictionary:
            return false
        var marker := raw_marker as Dictionary
        var zone_id := StringName(String(marker.get("zone_id", &"")))
        var tile_rect: Variant = marker.get("tile_rect", null)
        var raw_level: Variant = marker.get("recommended_level", null)
        if not StableId.is_valid(String(zone_id)) or seen.has(zone_id) or not tile_rect is Rect2i or typeof(raw_level) != TYPE_INT or int(raw_level) < 1 or int(raw_level) > 10:
            return false
        var discovered := false
        for subzone: Dictionary in _explored_subzones:
            if StringName(String(subzone.get("zone_id", &""))) == zone_id and subzone.get("tile_rect", null) == tile_rect:
                discovered = true
                break
        if not discovered:
            return false
        seen[zone_id] = true
        markers.append(marker.duplicate(true))
    markers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return String(a.get("zone_id", &"")) < String(b.get("zone_id", &""))
    )
    _risk_markers = markers
    queue_redraw()
    return true


func risk_marker_count() -> int:
    return _risk_markers.size()


func risk_markers() -> Array[Dictionary]:
    return _risk_markers.duplicate(true)


func _draw() -> void:
    if _map_size_tiles.x <= 0 or _map_size_tiles.y <= 0:
        return
    var transform := _map_transform()
    var origin: Vector2 = transform["origin"]
    var scale_factor: float = transform["scale"]
    var map_rect := Rect2(origin, Vector2(_map_size_tiles) * scale_factor)
    draw_rect(map_rect, map_background_color, true)
    for subzone: Dictionary in _explored_subzones:
        var subzone_rect := _scaled_rect(subzone["tile_rect"] as Rect2i, origin, scale_factor)
        draw_rect(subzone_rect, explored_subzone_fill_color, true)
        draw_rect(subzone_rect, explored_subzone_outline_color, false, 1.0, true)
    draw_rect(_scaled_rect(_town_tile_rect, origin, scale_factor), town_fill_color, true)
    draw_rect(_scaled_rect(_plaza_tile_rect, origin, scale_factor), plaza_fill_color, true)
    for subzone: Dictionary in _explored_subzones:
        draw_rect(_scaled_rect(subzone["tile_rect"] as Rect2i, origin, scale_factor), explored_subzone_outline_color, false, 1.0, true)
    for risk: Dictionary in _risk_markers:
        var risk_rect := _scaled_rect(risk["tile_rect"] as Rect2i, origin, scale_factor)
        draw_rect(risk_rect, risk_outline_color, false, risk_outline_width_px, true)
        var center := risk_rect.get_center()
        draw_line(center + Vector2(-landmark_radius_px, -landmark_radius_px), center + Vector2(landmark_radius_px, landmark_radius_px), risk_outline_color, risk_outline_width_px, true)
        draw_line(center + Vector2(-landmark_radius_px, landmark_radius_px), center + Vector2(landmark_radius_px, -landmark_radius_px), risk_outline_color, risk_outline_width_px, true)
    for route: Dictionary in _route_polylines:
        var points := route["points_tiles"] as PackedVector2Array
        var screen_points := PackedVector2Array()
        for point: Vector2 in points:
            screen_points.append(origin + point * scale_factor)
        draw_polyline(screen_points, route_color, route_width_px, true)
    for landmark: Dictionary in _public_landmarks:
        var position_tiles := landmark["position_tiles"] as Vector2
        var center := origin + position_tiles * scale_factor
        var diamond := PackedVector2Array([
            center + Vector2(0.0, -landmark_radius_px),
            center + Vector2(landmark_radius_px, 0.0),
            center + Vector2(0.0, landmark_radius_px),
            center + Vector2(-landmark_radius_px, 0.0),
            center + Vector2(0.0, -landmark_radius_px),
        ])
        draw_polyline(diamond, landmark_color, 2.0, true)
        draw_line(center + Vector2(-landmark_radius_px * 0.6, 0.0), center + Vector2(landmark_radius_px * 0.6, 0.0), landmark_color, 1.0, true)
        draw_line(center + Vector2(0.0, -landmark_radius_px * 0.6), center + Vector2(0.0, landmark_radius_px * 0.6), landmark_color, 1.0, true)


func _map_transform() -> Dictionary:
    var available := Vector2(maxf(1.0, size.x - padding_px * 2.0), maxf(1.0, size.y - padding_px * 2.0))
    var scale_factor := minf(available.x / float(_map_size_tiles.x), available.y / float(_map_size_tiles.y))
    if not is_finite(scale_factor) or scale_factor <= 0.0:
        scale_factor = 1.0
    var drawn_size := Vector2(_map_size_tiles) * scale_factor
    return {
        "origin": (size - drawn_size) * 0.5,
        "scale": scale_factor,
    }


func _scaled_rect(rect: Rect2i, origin: Vector2, scale_factor: float) -> Rect2:
    return Rect2(origin + Vector2(rect.position) * scale_factor, Vector2(rect.size) * scale_factor)


func _rect_inside_map(rect: Rect2i, map_size_tiles: Vector2i) -> bool:
    return (
        rect.size.x > 0
        and rect.size.y > 0
        and rect.position.x >= 0
        and rect.position.y >= 0
        and rect.end.x <= map_size_tiles.x
        and rect.end.y <= map_size_tiles.y
    )


func _point_inside_map(point: Vector2, map_size_tiles: Vector2i) -> bool:
    return (
        is_finite(point.x)
        and is_finite(point.y)
        and point.x >= 0.0
        and point.y >= 0.0
        and point.x <= float(map_size_tiles.x)
        and point.y <= float(map_size_tiles.y)
    )
