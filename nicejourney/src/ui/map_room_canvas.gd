class_name MapRoomCanvas
extends Control

@export_range(0.0, 64.0, 1.0) var padding_px: float = 10.0
@export_range(1.0, 8.0, 0.5) var outline_width_px: float = 2.0
@export var room_fill_color: Color = Color(0.18, 0.24, 0.32, 0.9)
@export var room_outline_color: Color = Color(0.78, 0.84, 0.92, 1.0)
@export_range(1.0, 8.0, 0.5) var connection_width_px: float = 2.0
@export var connection_color: Color = Color(0.52, 0.62, 0.72, 0.95)
@export_range(2.0, 16.0, 0.5) var risk_marker_radius_px: float = 5.0
@export_range(1.0, 6.0, 0.5) var risk_marker_width_px: float = 2.0
@export var risk_marker_color: Color = Color(0.92, 0.48, 0.3, 1.0)
@export_range(1.0, 12.0, 0.5) var checkpoint_radius_px: float = 3.0
@export var checkpoint_fill_color: Color = Color(0.92, 0.78, 0.2, 1.0)
@export_range(1.0, 12.0, 0.5) var player_marker_radius_px: float = 3.5
@export_range(1.0, 6.0, 0.5) var player_marker_width_px: float = 1.5
@export var player_marker_color: Color = Color(0.86, 0.9, 1.0, 1.0)

var _room_entries: Array[Dictionary] = []
var _room_connections: Array[Dictionary] = []
var _risk_markers: Array[Dictionary] = []
var _checkpoint_markers: Array[Dictionary] = []
var _player_tile: Vector2 = Vector2.ZERO
var _player_marker_visible: bool = false


func set_room_entries(raw_entries: Variant) -> bool:
    if not raw_entries is Array:
        return false
    var normalized: Array[Dictionary] = []
    var seen: Dictionary = {}
    for raw_entry: Variant in raw_entries as Array:
        if not raw_entry is Dictionary:
            return false
        var entry := raw_entry as Dictionary
        var room_id := StringName(String(entry.get("room_instance_id", &"")))
        var rect_variant: Variant = entry.get("rect", null)
        if not StableId.is_valid(String(room_id)) or not rect_variant is Rect2i:
            return false
        var rect := rect_variant as Rect2i
        if rect.size.x <= 0 or rect.size.y <= 0 or seen.has(room_id):
            return false
        seen[room_id] = true
        normalized.append({
            "room_instance_id": room_id,
            "rect": rect,
        })
    normalized.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        return String(first.get("room_instance_id", &"")) < String(second.get("room_instance_id", &""))
    )
    _room_entries = normalized
    _room_connections.clear()
    _risk_markers.clear()
    _checkpoint_markers.clear()
    _player_tile = Vector2.ZERO
    _player_marker_visible = false
    queue_redraw()
    return true


func set_room_connections(raw_connections: Variant) -> bool:
    if not raw_connections is Array:
        return false
    var normalized: Array[Dictionary] = []
    var seen: Dictionary = {}
    for raw_connection: Variant in raw_connections as Array:
        if not raw_connection is Dictionary:
            return false
        var connection := raw_connection as Dictionary
        var from_id := StringName(String(connection.get("from_room_id", &"")))
        var to_id := StringName(String(connection.get("to_room_id", &"")))
        if not StableId.is_valid(String(from_id)) or not StableId.is_valid(String(to_id)) or from_id == to_id:
            return false
        if not _has_room(from_id) or not _has_room(to_id):
            return false
        var pair: Array[String] = [String(from_id), String(to_id)]
        pair.sort()
        var key := "%s|%s" % pair
        if seen.has(key):
            return false
        seen[key] = true
        normalized.append({
            "from_room_id": StringName(pair[0]),
            "to_room_id": StringName(pair[1]),
        })
    normalized.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        var first_key := "%s|%s" % [String(first.get("from_room_id", &"")), String(first.get("to_room_id", &""))]
        var second_key := "%s|%s" % [String(second.get("from_room_id", &"")), String(second.get("to_room_id", &""))]
        return first_key < second_key
    )
    _room_connections = normalized
    queue_redraw()
    return true


func set_risk_markers(raw_markers: Variant) -> bool:
    if not raw_markers is Array:
        return false
    var normalized: Array[Dictionary] = []
    var seen_rooms: Dictionary = {}
    for raw_marker: Variant in raw_markers as Array:
        if not raw_marker is Dictionary:
            return false
        var marker := raw_marker as Dictionary
        var room_id := StringName(String(marker.get("room_instance_id", &"")))
        var risk_id := StringName(String(marker.get("risk_id", &"")))
        if not StableId.is_valid(String(room_id)) or not StableId.is_valid(String(risk_id)):
            return false
        if seen_rooms.has(room_id) or not _has_room(room_id):
            return false
        seen_rooms[room_id] = true
        normalized.append({
            "room_instance_id": room_id,
            "risk_id": risk_id,
        })
    normalized.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        return String(first.get("room_instance_id", &"")) < String(second.get("room_instance_id", &""))
    )
    _risk_markers = normalized
    queue_redraw()
    return true


func set_checkpoint_markers(raw_markers: Variant) -> bool:
    if not raw_markers is Array:
        return false
    var normalized: Array[Dictionary] = []
    var seen: Dictionary = {}
    for raw_marker: Variant in raw_markers as Array:
        if not raw_marker is Dictionary:
            return false
        var marker := raw_marker as Dictionary
        var checkpoint_id := StringName(String(marker.get("checkpoint_id", &"")))
        var room_id := StringName(String(marker.get("room_instance_id", &"")))
        var world_tile_variant: Variant = marker.get("world_tile", null)
        if not StableId.is_valid(String(checkpoint_id)) or not StableId.is_valid(String(room_id)) or not world_tile_variant is Vector2i:
            return false
        if seen.has(checkpoint_id) or not _room_contains_tile(room_id, world_tile_variant as Vector2i):
            return false
        seen[checkpoint_id] = true
        normalized.append({
            "checkpoint_id": checkpoint_id,
            "room_instance_id": room_id,
            "world_tile": world_tile_variant as Vector2i,
        })
    normalized.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        return String(first.get("checkpoint_id", &"")) < String(second.get("checkpoint_id", &""))
    )
    _checkpoint_markers = normalized
    queue_redraw()
    return true


func set_player_marker(world_tile: Variant) -> bool:
    var candidate := Vector2.ZERO
    if world_tile is Vector2:
        candidate = world_tile as Vector2
    elif world_tile is Vector2i:
        candidate = Vector2(world_tile as Vector2i) + Vector2(0.5, 0.5)
    else:
        return false
    if not is_finite(candidate.x) or not is_finite(candidate.y) or not _visible_room_contains_point(candidate):
        return false
    _player_tile = candidate
    _player_marker_visible = true
    queue_redraw()
    return true


func clear_player_marker() -> void:
    _player_tile = Vector2.ZERO
    _player_marker_visible = false
    queue_redraw()


func player_marker_visible() -> bool:
    return _player_marker_visible


func player_marker_tile() -> Vector2:
    return _player_tile


func clear_rooms() -> void:
    _room_entries.clear()
    _room_connections.clear()
    _risk_markers.clear()
    _checkpoint_markers.clear()
    _player_tile = Vector2.ZERO
    _player_marker_visible = false
    queue_redraw()


func visible_room_count() -> int:
    return _room_entries.size()


func room_entries() -> Array[Dictionary]:
    return _room_entries.duplicate(true)


func room_connections() -> Array[Dictionary]:
    return _room_connections.duplicate(true)


func risk_markers() -> Array[Dictionary]:
    return _risk_markers.duplicate(true)


func checkpoint_markers() -> Array[Dictionary]:
    return _checkpoint_markers.duplicate(true)


func _draw() -> void:
    if _room_entries.is_empty():
        return
    var bounds := _room_bounds()
    if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
        return
    var available := Vector2(maxf(1.0, size.x - padding_px * 2.0), maxf(1.0, size.y - padding_px * 2.0))
    var scale_factor := minf(available.x / bounds.size.x, available.y / bounds.size.y)
    if not is_finite(scale_factor) or scale_factor <= 0.0:
        return
    var drawn_size := bounds.size * scale_factor
    var origin := (size - drawn_size) * 0.5
    for connection: Dictionary in _room_connections:
        var from_center := _room_center(StringName(String(connection.get("from_room_id", &""))))
        var to_center := _room_center(StringName(String(connection.get("to_room_id", &""))))
        var from_point := origin + (from_center - bounds.position) * scale_factor
        var to_point := origin + (to_center - bounds.position) * scale_factor
        draw_line(from_point, to_point, connection_color, connection_width_px)
    for entry: Dictionary in _room_entries:
        var recti := entry["rect"] as Rect2i
        var relative_position := Vector2(recti.position) - bounds.position
        var room_rect := Rect2(
            origin + relative_position * scale_factor,
            Vector2(recti.size) * scale_factor
        )
        draw_rect(room_rect, room_fill_color, true)
        draw_rect(room_rect, room_outline_color, false, outline_width_px)
    for marker: Dictionary in _risk_markers:
        var room_id := StringName(String(marker.get("room_instance_id", &"")))
        var risk_id := StringName(String(marker.get("risk_id", &"")))
        var marker_center := origin + (_room_center(room_id) - bounds.position) * scale_factor
        _draw_risk_marker(marker_center, risk_id)
    for marker: Dictionary in _checkpoint_markers:
        var world_tile := marker["world_tile"] as Vector2i
        var marker_center := origin + (Vector2(world_tile) + Vector2(0.5, 0.5) - bounds.position) * scale_factor
        draw_circle(marker_center, checkpoint_radius_px, checkpoint_fill_color)
    if _player_marker_visible:
        var player_center := origin + (_player_tile - bounds.position) * scale_factor
        draw_circle(player_center, player_marker_radius_px, player_marker_color, false, player_marker_width_px)
        draw_line(player_center + Vector2(-player_marker_radius_px, 0.0), player_center + Vector2(player_marker_radius_px, 0.0), player_marker_color, player_marker_width_px)
        draw_line(player_center + Vector2(0.0, -player_marker_radius_px), player_center + Vector2(0.0, player_marker_radius_px), player_marker_color, player_marker_width_px)


func _draw_risk_marker(center: Vector2, risk_id: StringName) -> void:
    match risk_id:
        &"risk:boss":
            var triangle := PackedVector2Array([
                center + Vector2(0.0, -risk_marker_radius_px),
                center + Vector2(risk_marker_radius_px, risk_marker_radius_px),
                center + Vector2(-risk_marker_radius_px, risk_marker_radius_px),
                center + Vector2(0.0, -risk_marker_radius_px),
            ])
            draw_polyline(triangle, risk_marker_color, risk_marker_width_px)
        &"risk:elite":
            var diamond := PackedVector2Array([
                center + Vector2(0.0, -risk_marker_radius_px),
                center + Vector2(risk_marker_radius_px, 0.0),
                center + Vector2(0.0, risk_marker_radius_px),
                center + Vector2(-risk_marker_radius_px, 0.0),
                center + Vector2(0.0, -risk_marker_radius_px),
            ])
            draw_polyline(diamond, risk_marker_color, risk_marker_width_px)
        _:
            draw_circle(center, risk_marker_radius_px, risk_marker_color, false, risk_marker_width_px)


func _has_room(room_id: StringName) -> bool:
    for room: Dictionary in _room_entries:
        if StringName(String(room.get("room_instance_id", &""))) == room_id:
            return true
    return false


func _room_center(room_id: StringName) -> Vector2:
    for room: Dictionary in _room_entries:
        if StringName(String(room.get("room_instance_id", &""))) != room_id:
            continue
        var rect := room.get("rect", Rect2i()) as Rect2i
        return Vector2(rect.position) + Vector2(rect.size) * 0.5
    return Vector2.ZERO


func _room_contains_tile(room_id: StringName, world_tile: Vector2i) -> bool:
    for room: Dictionary in _room_entries:
        if StringName(String(room.get("room_instance_id", &""))) != room_id:
            continue
        var rect_variant: Variant = room.get("rect", null)
        return rect_variant is Rect2i and (rect_variant as Rect2i).has_point(world_tile)
    return false


func _visible_room_contains_point(world_tile: Vector2) -> bool:
    for room: Dictionary in _room_entries:
        var rect_variant: Variant = room.get("rect", null)
        if not rect_variant is Rect2i:
            continue
        var rect := rect_variant as Rect2i
        if Rect2(Vector2(rect.position), Vector2(rect.size)).has_point(world_tile):
            return true
    return false


func _room_bounds() -> Rect2:
    if _room_entries.is_empty():
        return Rect2()
    var first := _room_entries[0]["rect"] as Rect2i
    var min_point := Vector2(first.position)
    var max_point := Vector2(first.end)
    for index: int in range(1, _room_entries.size()):
        var rect := _room_entries[index]["rect"] as Rect2i
        min_point.x = minf(min_point.x, float(rect.position.x))
        min_point.y = minf(min_point.y, float(rect.position.y))
        max_point.x = maxf(max_point.x, float(rect.end.x))
        max_point.y = maxf(max_point.y, float(rect.end.y))
    return Rect2(min_point, max_point - min_point)
