class_name Region3MapSnapshotService
extends RefCounted

const REASON_INVALID_LAYOUT: StringName = &"invalid_layout"
const REASON_ROUTE_ROOT_MISSING: StringName = &"route_root_missing"
const REASON_TOWER_LANDMARK_MISSING: StringName = &"tower_landmark_missing"


static func build_from_layout(layout: Region3AuthoredTownLayout, profile: ProfileSnapshot = null) -> Dictionary:
    if layout == null:
        return _rejected(REASON_INVALID_LAYOUT, PackedStringArray(["layout is required"]))
    var layout_errors := layout.validate_layout()
    if not layout_errors.is_empty():
        return _rejected(REASON_INVALID_LAYOUT, layout_errors)

    var routes := layout.get_node_or_null(layout.routes_path) as Node2D
    if routes == null:
        return _rejected(REASON_ROUTE_ROOT_MISSING, PackedStringArray(["authored route root is required"]))

    var route_polylines: Array[Dictionary] = []
    var seen_names: Dictionary = {}
    for child: Node in routes.get_children():
        var line := child as Line2D
        if line == null:
            continue
        var route_name := StringName(line.name)
        if seen_names.has(route_name) or line.points.size() < 2:
            return _rejected(REASON_INVALID_LAYOUT, PackedStringArray(["route names must be unique and contain at least two points"]))
        seen_names[route_name] = true
        var points_tiles := PackedVector2Array()
        for point: Vector2 in line.points:
            var point_tiles := point / float(layout.tile_size)
            if not is_finite(point_tiles.x) or not is_finite(point_tiles.y):
                return _rejected(REASON_INVALID_LAYOUT, PackedStringArray(["route coordinates must be finite"]))
            points_tiles.append(point_tiles)
        route_polylines.append({
            "route_name": route_name,
            "points_tiles": points_tiles,
        })
    route_polylines.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        return String(first.get("route_name", &"")) < String(second.get("route_name", &""))
    )

    var public_landmarks: Array[Dictionary] = []
    var discovered_services: Array[Dictionary] = []
    for child: Node in layout.get_children():
        var anchor := child as Region3TownStructureAnchor
        if anchor == null or anchor.category != Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
            continue
        if anchor.role_id == Region3TownStructureManifestValidator.ROLE_CENTRAL_TOWER:
            public_landmarks.append({
                "landmark_id": anchor.structure_id,
                "landmark_kind": Region3TownStructureManifestValidator.ROLE_CENTRAL_TOWER,
                "position_tiles": anchor.position / float(layout.tile_size),
                "discovery_kind": &"public_fixed",
            })
            continue
        if profile != null and Region3ServiceDiscoveryService.is_discovered(profile, anchor.structure_id):
            discovered_services.append({
                "landmark_id": anchor.structure_id,
                "landmark_kind": anchor.role_id,
                "position_tiles": anchor.position / float(layout.tile_size),
                "discovery_kind": &"service_interaction",
            })
    if public_landmarks.size() != 1:
        return _rejected(REASON_TOWER_LANDMARK_MISSING, PackedStringArray(["exactly one public Central Tower landmark is required"]))
    discovered_services.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        return String(first.get("landmark_id", &"")) < String(second.get("landmark_id", &""))
    )
    public_landmarks.append_array(discovered_services)

    var world_layout := layout.world_layout_definition
    var content_readiness: Dictionary = {}
    if world_layout != null:
        content_readiness = world_layout.map_content_readiness()

    var explored_subzones: Array = []
    var explored_state_available := false
    var explored_unavailable_reason := StringName(content_readiness.get(
        "explored_subzone_unavailable_reason_id",
        Region3WorldLayoutDefinition.REASON_EXPLORED_SUBZONE_STATE_OWNER_UNAVAILABLE
    ))
    if profile != null:
        var explored_result := Region3SubzoneDiscoveryService.explored_zone_entries(profile, layout)
        if bool(explored_result.get("accepted", false)):
            explored_state_available = true
            explored_unavailable_reason = &""
            explored_subzones = (explored_result.get("entries", []) as Array).duplicate(true)
        else:
            explored_unavailable_reason = StringName(String(explored_result.get("reason_id", explored_unavailable_reason)))

    var risk_markers: Array[Dictionary] = []
    var risk_state_available := false
    var risk_unavailable_reason := StringName(content_readiness.get(
        "risk_marker_unavailable_reason_id",
        Region3WorldLayoutDefinition.REASON_REGION_DANGER_CONCRETE_LEVEL_UNAUTHORED
    ))
    if bool(content_readiness.get("risk_marker_data_available", false)) and profile != null:
        if explored_state_available:
            risk_state_available = true
            risk_unavailable_reason = &""
            for raw_entry: Variant in explored_subzones:
                var entry := raw_entry as Dictionary
                var zone := world_layout.get_zone(StringName(String(entry.get("zone_id", &""))))
                if zone == null or zone.safe_zone or not zone.travel_destination:
                    continue
                var rank := DangerEvaluator.evaluate_rank(profile.level, zone.recommended_level)
                risk_markers.append({
                    "zone_id": zone.zone_id,
                    "tile_rect": zone.tile_rect,
                    "recommended_level": zone.recommended_level,
                    "player_level": profile.level,
                    "danger_rank": int(rank),
                    "danger_display": DangerEvaluator.display_name(rank),
                    "requires_danger_confirmation": DangerEvaluator.requires_explicit_travel_confirmation(rank),
                })
            risk_markers.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
                return String(first.get("zone_id", &"")) < String(second.get("zone_id", &""))
            )
        else:
            risk_unavailable_reason = explored_unavailable_reason

    return {
        "accepted": true,
        "reason_id": &"",
        "map_revision_id": layout.map_revision_id,
        "map_size_tiles": layout.map_size_tiles,
        "town_tile_rect": layout.town_tile_rect,
        "plaza_tile_rect": layout.plaza_tile_rect,
        "route_polylines": route_polylines,
        "public_landmarks": public_landmarks,
        "discovered_services": discovered_services.duplicate(true),
        "service_discovery_state_available": profile != null,
        "world_layout_definition_available": world_layout != null,
        "explored_subzone_geometry_available": bool(content_readiness.get("explored_subzone_geometry_available", false)),
        "explored_subzones": explored_subzones,
        "explored_subzone_state_available": explored_state_available,
        "explored_subzone_unavailable_reason_id": explored_unavailable_reason,
        "quest_markers": [],
        "quest_marker_state_available": bool(content_readiness.get("quest_marker_state_available", false)),
        "quest_marker_unavailable_reason_id": StringName(content_readiness.get(
            "quest_marker_unavailable_reason_id",
            Region3WorldLayoutDefinition.REASON_QUEST_MARKER_GEOMETRY_UNAUTHORED
        )),
        "checkpoint_markers": [],
        "checkpoint_marker_state_available": bool(content_readiness.get("checkpoint_marker_state_available", false)),
        "checkpoint_marker_unavailable_reason_id": StringName(content_readiness.get(
            "checkpoint_marker_unavailable_reason_id",
            Region3WorldLayoutDefinition.REASON_CHECKPOINT_GEOMETRY_UNAUTHORED
        )),
        "risk_markers": risk_markers,
        "risk_marker_state_available": risk_state_available,
        "risk_marker_unavailable_reason_id": risk_unavailable_reason,
    }


static func _rejected(reason_id: StringName, errors: PackedStringArray) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "errors": errors.duplicate(),
        "route_polylines": [],
        "public_landmarks": [],
        "discovered_services": [],
        "service_discovery_state_available": false,
        "world_layout_definition_available": false,
        "explored_subzone_geometry_available": false,
        "explored_subzones": [],
        "explored_subzone_state_available": false,
        "explored_subzone_unavailable_reason_id": reason_id,
        "quest_markers": [],
        "quest_marker_state_available": false,
        "quest_marker_unavailable_reason_id": reason_id,
        "checkpoint_markers": [],
        "checkpoint_marker_state_available": false,
        "checkpoint_marker_unavailable_reason_id": reason_id,
        "risk_markers": [],
        "risk_marker_state_available": false,
        "risk_marker_unavailable_reason_id": reason_id,
    }
