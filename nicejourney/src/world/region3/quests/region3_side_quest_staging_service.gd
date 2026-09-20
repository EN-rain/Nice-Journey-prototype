class_name Region3SideQuestStagingService
extends RefCounted

const REASON_INVALID_LAYOUT: StringName = &"invalid_layout"
const REASON_ROUTE_ROOT_MISSING: StringName = &"route_root_missing"
const REASON_STAGING_ROUTE_MISSING: StringName = &"staging_route_missing"
const REASON_AUTHORED_SIDE_QUEST_MISSING: StringName = &"authored_side_quest_missing"

const SLOT_SIDE_A: StringName = &"R3-SIDE-A"
const SLOT_SIDE_B: StringName = &"R3-SIDE-B"
const SLOT_SIDE_C: StringName = &"R3-SIDE-C"

const FAMILY_ESCORT: StringName = &"escort"
const FAMILY_ANNIHILATION: StringName = &"annihilation"
const FAMILY_DEFENSE: StringName = &"tower_defense"

const ZONE_OUTSKIRTS: StringName = &"R3-OUTSKIRTS"
const ZONE_ROADS: StringName = &"R3-ROADS"
const ZONE_RUINS: StringName = &"R3-RUINS"

const SOUTH_OUTSKIRTS_TILE_RECT := Rect2i(48, 112, 64, 32)
const WEST_ROAD_TILE_RECT := Rect2i(16, 64, 32, 64)
const NORTH_RUINS_TILE_RECT := Rect2i(40, 16, 72, 32)

const ROUTE_SOUTH_APPROACH: StringName = &"SouthApproach"
const ROUTE_WEST_APPROACH: StringName = &"WestApproach"
const ROUTE_NORTH_APPROACH: StringName = &"NorthApproach"


static func build_from_layout(
    layout: Region3AuthoredTownLayout,
    anchors: Region3SideQuestPlaytestAnchorLayer = null,
    authored_descriptors: Dictionary = {}
) -> Dictionary:
    if layout == null:
        return _rejected(REASON_INVALID_LAYOUT, PackedStringArray(["layout is required"]))
    var layout_errors := layout.validate_layout()
    if not layout_errors.is_empty():
        return _rejected(REASON_INVALID_LAYOUT, layout_errors)

    var routes := layout.get_node_or_null(layout.routes_path) as Node2D
    if routes == null:
        return _rejected(REASON_ROUTE_ROOT_MISSING, PackedStringArray(["authored route root is required"]))
    if anchors != null and (not anchors.validate_for_layout(layout).is_empty() or authored_descriptors.size() != 3):
        return _rejected(REASON_AUTHORED_SIDE_QUEST_MISSING, PackedStringArray(["authored side quest markers and three validated descriptors are required"]))

    var descriptors: Array[Dictionary] = []
    var extraction_errors := PackedStringArray()
    for spec: Dictionary in _staging_specs():
        var route_name := StringName(String(spec["route_name"]))
        var route := routes.get_node_or_null(String(route_name)) as Line2D
        if route == null or route.points.size() < 2:
            extraction_errors.append("%s requires authored route %s with at least two points" % [String(spec["slot_id"]), String(route_name)])
            continue
        var descriptor := _build_descriptor(layout, route, spec)
        if anchors != null:
            var authored: Dictionary = {}
            for raw_authored: Variant in authored_descriptors.values():
                if raw_authored is Dictionary and StringName(String((raw_authored as Dictionary).get("slot_id", &""))) == StringName(String(spec["slot_id"])):
                    authored = raw_authored as Dictionary
                    break
            if authored.is_empty() or (authored.get("objective_config", {}) as Dictionary).is_empty():
                return _rejected(REASON_AUTHORED_SIDE_QUEST_MISSING, PackedStringArray(["%s has no validated live objective binding" % String(spec["slot_id"])]))
            descriptor["authored_live_runtime"] = authored.duplicate(true)
            descriptor["objective_binding_blockers"] = PackedStringArray()
            descriptor["runtime_authoring_blockers"] = PackedStringArray()
            descriptor["policy_blockers"] = PackedStringArray()
            descriptor["geometry_blockers"] = PackedStringArray() if bool(descriptor["route_enters_reserved_zone"]) else PackedStringArray(["%s must connect its authored quest site to the reserved zone" % String(route_name)])
            descriptor["runtime_staging_ready"] = (descriptor["geometry_blockers"] as PackedStringArray).is_empty() and bool(descriptor["route_touches_town"])
        descriptors.append(descriptor)

    if not extraction_errors.is_empty():
        return _rejected(REASON_STAGING_ROUTE_MISSING, extraction_errors)
    return {
        "accepted": true,
        "reason_id": &"",
        "map_revision_id": layout.map_revision_id,
        "descriptors": descriptors,
        "runtime_staging_ready": _all_runtime_ready(descriptors),
    }


static func descriptor_for_slot(snapshot: Dictionary, slot_id: StringName) -> Dictionary:
    if not bool(snapshot.get("accepted", false)):
        return {}
    for raw_descriptor: Variant in snapshot.get("descriptors", []) as Array:
        if not raw_descriptor is Dictionary:
            continue
        var descriptor := raw_descriptor as Dictionary
        if StringName(String(descriptor.get("slot_id", &""))) == slot_id:
            return descriptor.duplicate(true)
    return {}


static func _build_descriptor(layout: Region3AuthoredTownLayout, route: Line2D, spec: Dictionary) -> Dictionary:
    var points_tiles := PackedVector2Array()
    var enters_reserved_zone := false
    var touches_town := false
    var zone_rect: Rect2i = spec["zone_tile_rect"] as Rect2i
    var zone_rect_float := Rect2(Vector2(zone_rect.position), Vector2(zone_rect.size))
    var town_rect_float := Rect2(Vector2(layout.town_tile_rect.position), Vector2(layout.town_tile_rect.size))
    for point: Vector2 in route.points:
        var local_point := layout.to_local(route.to_global(point))
        var point_tiles := local_point / float(layout.tile_size)
        points_tiles.append(point_tiles)
        enters_reserved_zone = enters_reserved_zone or zone_rect_float.has_point(point_tiles)
        touches_town = touches_town or town_rect_float.has_point(point_tiles)

    var geometry_blockers := (spec["geometry_blockers"] as PackedStringArray).duplicate()
    if not enters_reserved_zone:
        geometry_blockers.append("%s does not enter the reserved %s staging zone" % [String(route.name), String(spec["zone_id"])])

    return {
        "slot_id": spec["slot_id"],
        "objective_family": spec["objective_family"],
        "zone_id": spec["zone_id"],
        "zone_tile_rect": zone_rect,
        "staging_route_name": StringName(route.name),
        "staging_route_points_tiles": points_tiles,
        "staging_route_width_px": route.width,
        "route_enters_reserved_zone": enters_reserved_zone,
        "route_touches_town": touches_town,
        "geometry_blockers": geometry_blockers,
        "objective_binding_blockers": (spec["objective_binding_blockers"] as PackedStringArray).duplicate(),
        "runtime_authoring_blockers": (spec["runtime_authoring_blockers"] as PackedStringArray).duplicate(),
        "policy_blockers": (spec["policy_blockers"] as PackedStringArray).duplicate(),
        "runtime_staging_ready": false,
    }


static func _staging_specs() -> Array[Dictionary]:
    return [
        {
            "slot_id": SLOT_SIDE_A,
            "objective_family": FAMILY_ESCORT,
            "zone_id": ZONE_OUTSKIRTS,
            "zone_tile_rect": SOUTH_OUTSKIRTS_TILE_RECT,
            "route_name": ROUTE_SOUTH_APPROACH,
            "geometry_blockers": PackedStringArray([
                "escort actor start anchor is not authored",
                "escort goal/destination anchor is not authored",
                "escort combat-corridor boundary is not authored",
                "escort route-node stable IDs and direction are not authored",
            ]),
            "objective_binding_blockers": PackedStringArray([
                "actor_id",
                "route_node_ids",
                "goal_id",
                "safe_retry_origin_id",
                "failure_policy_id",
            ]),
            "runtime_authoring_blockers": PackedStringArray([
                "speed_px_per_second",
                "arrival_tolerance_px",
            ]),
            "policy_blockers": PackedStringArray([
                "retry/recovery policy",
            ]),
        },
        {
            "slot_id": SLOT_SIDE_B,
            "objective_family": FAMILY_ANNIHILATION,
            "zone_id": ZONE_ROADS,
            "zone_tile_rect": WEST_ROAD_TILE_RECT,
            "route_name": ROUTE_WEST_APPROACH,
            "geometry_blockers": PackedStringArray([
                "designated hostile-group placement/spawn anchors are not authored",
                "quest return-landmark socket/identity is not authored",
            ]),
            "objective_binding_blockers": PackedStringArray([
                "required_actor_ids",
            ]),
            "runtime_authoring_blockers": PackedStringArray(),
            "policy_blockers": PackedStringArray(),
        },
        {
            "slot_id": SLOT_SIDE_C,
            "objective_family": FAMILY_DEFENSE,
            "zone_id": ZONE_RUINS,
            "zone_tile_rect": NORTH_RUINS_TILE_RECT,
            "route_name": ROUTE_NORTH_APPROACH,
            "geometry_blockers": PackedStringArray([
                "protected-objective socket/anchor is not authored",
                "defense wave spawn/path identities are not authored",
            ]),
            "objective_binding_blockers": PackedStringArray([
                "objective_id",
                "objective_max_hp",
                "required_actor_ids_by_wave",
            ]),
            "runtime_authoring_blockers": PackedStringArray(),
            "policy_blockers": PackedStringArray([
                "leave_rule",
            ]),
        },
    ]


static func _all_runtime_ready(descriptors: Array[Dictionary]) -> bool:
    if descriptors.size() != 3:
        return false
    for descriptor: Dictionary in descriptors:
        if not bool(descriptor.get("runtime_staging_ready", false)):
            return false
    return true


static func _rejected(reason_id: StringName, errors: PackedStringArray) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "errors": errors.duplicate(),
        "descriptors": [],
        "runtime_staging_ready": false,
    }
