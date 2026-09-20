class_name Region3AuthoredTownLayout
extends Node2D

const MAP_REVISION_ID: StringName = &"region3_town_layout_v01"

@export var map_revision_id: StringName = MAP_REVISION_ID
@export_range(1, 128, 1) var tile_size: int = 32
@export var map_size_tiles: Vector2i = Vector2i(160, 160)
@export var town_tile_rect: Rect2i = Rect2i(48, 48, 64, 64)
@export var plaza_tile_rect: Rect2i = Rect2i(69, 81, 23, 13)
@export var structure_count_expected: int = 20
@export var functional_count_expected: int = 8
@export var decorative_count_expected: int = 12
@export_node_path("Node2D") var routes_path: NodePath = NodePath("Routes")
@export var circulation_route_name: StringName = &"CirculationLoop"
@export_range(0.01, 8.0, 0.01) var route_connection_tolerance_px: float = 0.5
@export var environment_support_profile: Region3EnvironmentSupportVisualProfile
@export var world_layout_definition: Region3WorldLayoutDefinition

func validate_layout() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(map_revision_id)):
        errors.append("map_revision_id must be a stable ID")
    if tile_size <= 0:
        errors.append("tile_size must be positive")
    if map_size_tiles != Vector2i(160, 160):
        errors.append("Region 3 authored layout must reserve the 160x160 prototype traversal space")
    if town_tile_rect != Rect2i(48, 48, 64, 64):
        errors.append("Region 3 town reservation must remain x48-111/y48-111")
    if structure_count_expected != 20 or functional_count_expected != 8 or decorative_count_expected != 12:
        errors.append("structure count contract must remain 20 total / 8 functional / 12 decorative")
    if environment_support_profile == null:
        errors.append("environment_support_profile is required")
    else:
        for profile_error: String in environment_support_profile.validate_profile():
            errors.append("environment_support_profile: %s" % profile_error)

    var entries: Array[Dictionary] = []
    var structure_ids: Dictionary = {}
    var functional_count := 0
    var decorative_count := 0
    for child: Node in get_children():
        var anchor := child as Region3TownStructureAnchor
        if anchor == null:
            continue
        for anchor_error: String in anchor.validate_anchor():
            errors.append("%s: %s" % [String(anchor.structure_id), anchor_error])
        if not anchor.position.is_equal_approx(anchor.expected_world_position(float(tile_size))):
            errors.append("%s world position must match its authored lot center" % String(anchor.structure_id))
        var entry: Dictionary = {
            "structure_id": anchor.structure_id,
            "category": anchor.category,
        }
        structure_ids[anchor.structure_id] = true
        if anchor.category == Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
            functional_count += 1
            entry["role_id"] = anchor.role_id
        else:
            decorative_count += 1
        entries.append(entry)

    if entries.size() != structure_count_expected:
        errors.append("authored town scene must contain exactly 20 structure anchors")
    if functional_count != functional_count_expected:
        errors.append("authored town scene must contain exactly 8 functional anchors")
    if decorative_count != decorative_count_expected:
        errors.append("authored town scene must contain exactly 12 decorative anchors")
    for manifest_error: String in Region3TownStructureManifestValidator.validate_entries(entries):
        errors.append("manifest: %s" % manifest_error)

    if world_layout_definition == null:
        errors.append("world_layout_definition is required")
    else:
        if world_layout_definition.map_revision_id != map_revision_id:
            errors.append("world_layout_definition map_revision_id must match the authored town revision")
        if world_layout_definition.map_size_tiles != map_size_tiles:
            errors.append("world_layout_definition map_size_tiles must match the authored Region 3 map")
        var town_zone := world_layout_definition.get_zone(&"R3-TOWN")
        if town_zone == null or town_zone.tile_rect != town_tile_rect:
            errors.append("world_layout_definition R3-TOWN geometry must match the authored town reservation")
        for world_error: String in world_layout_definition.validate_definition(structure_ids):
            errors.append("world_layout_definition: %s" % world_error)

    for route_error: String in validate_route_connectivity():
        errors.append("routes: %s" % route_error)
    return errors

func validate_route_connectivity() -> PackedStringArray:
    var errors := PackedStringArray()
    if not is_finite(route_connection_tolerance_px) or route_connection_tolerance_px <= 0.0:
        errors.append("route_connection_tolerance_px must be finite and positive")
        return errors
    var routes := get_node_or_null(routes_path) as Node2D
    if routes == null:
        errors.append("routes node is required")
        return errors

    var route_lines: Array[Line2D] = []
    var circulation_index := -1
    for child: Node in routes.get_children():
        var line := child as Line2D
        if line == null:
            continue
        if line.points.size() < 2:
            errors.append("%s must contain at least two route points" % line.name)
            continue
        if StringName(line.name) == circulation_route_name:
            circulation_index = route_lines.size()
        route_lines.append(line)
    if route_lines.is_empty():
        errors.append("at least one authored route line is required")
        return errors
    if circulation_index < 0:
        errors.append("circulation route %s is required" % String(circulation_route_name))
        return errors

    for child: Node in get_children():
        var anchor := child as Region3TownStructureAnchor
        if anchor == null or anchor.category != Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
            continue
        var approach_world := anchor.approach_world_position(float(tile_size))
        var touches_route := false
        for line: Line2D in route_lines:
            if _point_touches_polyline(approach_world, line.points):
                touches_route = true
                break
        if not touches_route:
            errors.append("%s approach tile must touch the authored route network" % String(anchor.structure_id))

    var connected: Dictionary = {circulation_index: true}
    var frontier: Array[int] = [circulation_index]
    while not frontier.is_empty():
        var current_index: int = frontier.pop_front()
        for candidate_index: int in range(route_lines.size()):
            if connected.has(candidate_index) or candidate_index == current_index:
                continue
            if _polylines_touch(route_lines[current_index].points, route_lines[candidate_index].points):
                connected[candidate_index] = true
                frontier.append(candidate_index)
    if connected.size() != route_lines.size():
        for index: int in range(route_lines.size()):
            if not connected.has(index):
                errors.append("route %s must connect to the circulation graph" % route_lines[index].name)
    return errors

func _polylines_touch(first: PackedVector2Array, second: PackedVector2Array) -> bool:
    for point: Vector2 in first:
        if _point_touches_polyline(point, second):
            return true
    for point: Vector2 in second:
        if _point_touches_polyline(point, first):
            return true
    return false

func _point_touches_polyline(point: Vector2, polyline: PackedVector2Array) -> bool:
    for index: int in range(polyline.size() - 1):
        if _distance_to_segment(point, polyline[index], polyline[index + 1]) <= route_connection_tolerance_px:
            return true
    return false

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
    var segment := finish - start
    var length_squared := segment.length_squared()
    if length_squared <= 0.000001:
        return point.distance_to(start)
    var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
    return point.distance_to(start + segment * ratio)
