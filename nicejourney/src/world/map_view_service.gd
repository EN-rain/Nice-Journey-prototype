class_name MapViewService
extends RefCounted

const REASON_INVALID_PROFILE: StringName = &"invalid_profile"
const REASON_UNKNOWN_LAYER: StringName = &"unknown_layer"
const REASON_FLOOR_STATE_INVALID: StringName = &"floor_state_invalid"
const REASON_REGION_MAP_INVALID: StringName = &"region_map_invalid"
const REGION3_LAYOUT_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const REGION3_MAP_SNAPSHOT_SERVICE_SCRIPT: Script = preload("res://src/world/region3/map/region3_map_snapshot_service.gd")
const TOWER_FLOOR_DISCOVERY_SERVICE_SCRIPT: Script = preload("res://src/world/tower/tower_floor_discovery_service.gd")


static func layer_descriptors() -> Array[Dictionary]:
    return [
        {"layer_id": MapLayerIdentityValidator.LAYER_WORLD_MAP, "name": "World"},
        {"layer_id": MapLayerIdentityValidator.LAYER_REGION_MAP, "name": "Region"},
        {"layer_id": MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP, "name": "Tower Floor"},
    ]


static func validate_layer_descriptors() -> PackedStringArray:
    return MapLayerIdentityValidator.validate_entries(layer_descriptors())


static func build_layer(profile: ProfileSnapshot, layer_id: StringName, active_floor_id: int = 0, operation_guard: GameplayOperationGuard = null) -> Dictionary:
    if profile == null:
        return _rejected(REASON_INVALID_PROFILE, layer_id)
    if not MapLayerIdentityValidator.REQUIRED_LAYER_IDS.has(layer_id):
        return _rejected(REASON_UNKNOWN_LAYER, layer_id)

    match layer_id:
        MapLayerIdentityValidator.LAYER_WORLD_MAP:
            return _world_layer()
        MapLayerIdentityValidator.LAYER_REGION_MAP:
            return _region_layer(profile)
        MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP:
            return _tower_layer(profile, active_floor_id, operation_guard)
        _:
            return _rejected(REASON_UNKNOWN_LAYER, layer_id)


static func _world_layer() -> Dictionary:
    var regions: Array[Dictionary] = []
    for region_id: int in range(1, WorldRegionCatalogValidator.REGION_COUNT + 1):
        var state := (
            WorldRegionCatalogValidator.STATE_PROTOTYPE_STARTING_REGION
            if region_id == WorldRegionCatalogValidator.PROTOTYPE_REGION_ID
            else WorldRegionCatalogValidator.STATE_FUTURE_LOCKED
        )
        regions.append({
            "region_id": region_id,
            "state": state,
            "playable": region_id == WorldRegionCatalogValidator.PROTOTYPE_REGION_ID,
        })
    return {
        "accepted": true,
        "reason_id": &"",
        "layer_id": MapLayerIdentityValidator.LAYER_WORLD_MAP,
        "regions": regions,
        "prototype_region_id": WorldRegionCatalogValidator.PROTOTYPE_REGION_ID,
        "region_discovery_state_available": false,
        "travel_action_available": false,
    }


static func _region_layer(profile: ProfileSnapshot) -> Dictionary:
    var layout := REGION3_LAYOUT_SCENE.instantiate() as Region3AuthoredTownLayout
    if layout == null:
        return _rejected(REASON_REGION_MAP_INVALID, MapLayerIdentityValidator.LAYER_REGION_MAP)
    var snapshot: Dictionary = REGION3_MAP_SNAPSHOT_SERVICE_SCRIPT.build_from_layout(layout, profile)
    layout.free()
    if not bool(snapshot.get("accepted", false)):
        return _rejected(REASON_REGION_MAP_INVALID, MapLayerIdentityValidator.LAYER_REGION_MAP)
    return {
        "accepted": true,
        "reason_id": &"",
        "layer_id": MapLayerIdentityValidator.LAYER_REGION_MAP,
        "region_id": WorldRegionCatalogValidator.PROTOTYPE_REGION_ID,
        "region_state": WorldRegionCatalogValidator.STATE_PROTOTYPE_STARTING_REGION,
        "map_revision_id": StringName(snapshot.get("map_revision_id", &"")),
        "map_size_tiles": snapshot.get("map_size_tiles", Vector2i.ZERO),
        "town_tile_rect": snapshot.get("town_tile_rect", Rect2i()),
        "plaza_tile_rect": snapshot.get("plaza_tile_rect", Rect2i()),
        "route_polylines": (snapshot.get("route_polylines", []) as Array).duplicate(true),
        "public_landmarks": (snapshot.get("public_landmarks", []) as Array).duplicate(true),
        "discovered_services": (snapshot.get("discovered_services", []) as Array).duplicate(true),
        "explored_subzones": (snapshot.get("explored_subzones", []) as Array).duplicate(true),
        "quest_markers": (snapshot.get("quest_markers", []) as Array).duplicate(true),
        "checkpoint_markers": (snapshot.get("checkpoint_markers", []) as Array).duplicate(true),
        "risk_markers": (snapshot.get("risk_markers", []) as Array).duplicate(true),
        "structure_count": Region3TownStructureManifestValidator.TOTAL_STRUCTURES,
        "functional_structure_count": Region3TownStructureManifestValidator.FUNCTIONAL_STRUCTURES,
        "decorative_structure_count": Region3TownStructureManifestValidator.DECORATIVE_STRUCTURES,
        "service_discovery_state_available": bool(snapshot.get("service_discovery_state_available", false)),
        "world_layout_definition_available": bool(snapshot.get("world_layout_definition_available", false)),
        "explored_subzone_geometry_available": bool(snapshot.get("explored_subzone_geometry_available", false)),
        "explored_subzone_state_available": bool(snapshot.get("explored_subzone_state_available", false)),
        "explored_subzone_unavailable_reason_id": StringName(snapshot.get("explored_subzone_unavailable_reason_id", &"")),
        "quest_marker_state_available": bool(snapshot.get("quest_marker_state_available", false)),
        "quest_marker_unavailable_reason_id": StringName(snapshot.get("quest_marker_unavailable_reason_id", &"")),
        "quest_anchor_discovery_state_available": bool(snapshot.get("quest_marker_state_available", false)),
        "checkpoint_marker_state_available": bool(snapshot.get("checkpoint_marker_state_available", false)),
        "checkpoint_marker_unavailable_reason_id": StringName(snapshot.get("checkpoint_marker_unavailable_reason_id", &"")),
        "risk_marker_state_available": bool(snapshot.get("risk_marker_state_available", false)),
        "risk_marker_unavailable_reason_id": StringName(snapshot.get("risk_marker_unavailable_reason_id", &"")),
        "travel_action_available": false,
    }


static func _tower_layer(profile: ProfileSnapshot, active_floor_id: int, operation_guard: GameplayOperationGuard) -> Dictionary:
    var floor_id := _current_floor_id(profile, active_floor_id)
    var base := {
        "accepted": true,
        "reason_id": &"",
        "layer_id": MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP,
        "available": false,
        "floor_id": floor_id,
        "instance_id": &"",
        "layout_revision_id": &"",
        "primary_cleared": false,
        "checkpoint_count": 0,
        "visible_checkpoint_count": 0,
        "checkpoint_markers": [],
        "room_discovery_state_available": false,
        "discovered_room_count": 0,
        "visible_connection_count": 0,
        "room_connections": [],
        "visible_risk_marker_count": 0,
        "risk_markers": [],
        "room_geometry_withheld": true,
        "room_entries": [],
        "travel_eligibility_available": false,
        "travel_eligibility_reason_id": &"",
        "travel_player_level": profile.level,
        "eligible_travel_floors": [],
        "travel_action_available": false,
    }
    var travel_snapshot := _travel_eligibility_snapshot(profile, operation_guard)
    base["travel_eligibility_available"] = bool(travel_snapshot.get("available", false))
    base["travel_eligibility_reason_id"] = StringName(travel_snapshot.get("reason_id", &""))
    base["travel_player_level"] = int(travel_snapshot.get("player_level", profile.level))
    base["eligible_travel_floors"] = (travel_snapshot.get("entries", []) as Array).duplicate(true)
    if floor_id <= 0:
        return base

    var raw_floor: Variant = profile.tower_floor_states.get(str(floor_id), null)
    if not raw_floor is Dictionary:
        base["reason_id"] = REASON_FLOOR_STATE_INVALID
        return base
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(raw_floor as Dictionary).is_empty() or floor_state.floor_id != floor_id:
        base["reason_id"] = REASON_FLOOR_STATE_INVALID
        return base

    base["available"] = true
    base["reason_id"] = &""
    base["instance_id"] = floor_state.instance_id
    base["layout_revision_id"] = floor_state.layout_revision_id
    base["primary_cleared"] = floor_state.primary_cleared
    base["checkpoint_count"] = floor_state.checkpoint_ids.size()
    base["room_discovery_state_available"] = true
    var visible_rooms: Array[Dictionary] = TOWER_FLOOR_DISCOVERY_SERVICE_SCRIPT.visible_room_summaries(floor_state)
    base["discovered_room_count"] = visible_rooms.size()
    base["room_entries"] = visible_rooms
    var room_connections: Array[Dictionary] = TOWER_FLOOR_DISCOVERY_SERVICE_SCRIPT.visible_room_connections(floor_state)
    base["visible_connection_count"] = room_connections.size()
    base["room_connections"] = room_connections
    var risk_markers: Array[Dictionary] = TOWER_FLOOR_DISCOVERY_SERVICE_SCRIPT.visible_room_risk_markers(floor_state)
    base["visible_risk_marker_count"] = risk_markers.size()
    base["risk_markers"] = risk_markers
    var checkpoint_markers := _visible_checkpoint_markers(floor_state, visible_rooms)
    base["visible_checkpoint_count"] = checkpoint_markers.size()
    base["checkpoint_markers"] = checkpoint_markers
    return base


static func _travel_eligibility_snapshot(profile: ProfileSnapshot, operation_guard: GameplayOperationGuard) -> Dictionary:
    var menu := TowerAccessMenuService.build_menu(profile, operation_guard)
    if not bool(menu.get("accepted", false)):
        return {
            "available": false,
            "reason_id": StringName(menu.get("reason_id", &"")),
            "player_level": profile.level,
            "entries": [],
        }
    var entries: Array[Dictionary] = []
    for raw_entry: Variant in menu.get("entries", []) as Array:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        var floor_id := int(entry.get("floor_id", 0))
        var active_quest_ids: Array[StringName] = []
        var main_objective_quest_id: StringName = &""
        for raw_quest_id: Variant in entry.get("active_quest_ids", []) as Array:
            var quest_id := StringName(String(raw_quest_id))
            active_quest_ids.append(quest_id)
            if quest_id == StringName("primary_floor_%d" % floor_id):
                main_objective_quest_id = quest_id
        entries.append({
            "floor_id": floor_id,
            "state": StringName(entry.get("state", &"")),
            "recommended_level": int(entry.get("recommended_level", 0)),
            "danger_rank": int(entry.get("danger_rank", 0)),
            "danger_display": String(entry.get("danger_display", "")),
            "requires_danger_confirmation": bool(entry.get("requires_danger_confirmation", false)),
            "active_quest_ids": active_quest_ids,
            "main_objective_quest_id": main_objective_quest_id,
            "special_hazard_state_available": false,
            "known_special_hazards": [],
            "elite_warning": bool(entry.get("elite_warning", false)),
            "elite_target": int(entry.get("elite_target", 0)),
            "boss_warning": bool(entry.get("boss_warning", false)),
        })
    entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        return int(first.get("floor_id", 0)) < int(second.get("floor_id", 0))
    )
    return {
        "available": true,
        "reason_id": &"",
        "player_level": profile.level,
        "entries": entries,
    }


static func _visible_checkpoint_markers(floor_state: FloorInstanceState, visible_rooms: Array[Dictionary]) -> Array[Dictionary]:
    var room_rects: Dictionary = {}
    for room: Dictionary in visible_rooms:
        var room_id := StringName(String(room.get("room_instance_id", &"")))
        var rect_variant: Variant = room.get("rect", null)
        if StableId.is_valid(String(room_id)) and rect_variant is Rect2i:
            room_rects[room_id] = rect_variant as Rect2i

    var checkpoint_ids: Array[StringName] = floor_state.checkpoint_ids.duplicate()
    checkpoint_ids.sort()
    var markers: Array[Dictionary] = []
    for checkpoint_id: StringName in checkpoint_ids:
        var anchor := floor_state.get_checkpoint_anchor(checkpoint_id)
        if anchor.is_empty():
            continue
        var room_id := StringName(String(anchor.get("room_instance_id", &"")))
        if not room_rects.has(room_id):
            continue
        var room_rect := room_rects[room_id] as Rect2i
        var local_tile := Vector2i(int(anchor.get("local_tile_x", -1)), int(anchor.get("local_tile_y", -1)))
        if local_tile.x < 0 or local_tile.y < 0 or local_tile.x >= room_rect.size.x or local_tile.y >= room_rect.size.y:
            continue
        markers.append({
            "checkpoint_id": checkpoint_id,
            "room_instance_id": room_id,
            "world_tile": room_rect.position + local_tile,
        })
    return markers


static func _current_floor_id(profile: ProfileSnapshot, active_floor_id: int) -> int:
    if active_floor_id >= 1 and active_floor_id <= PrototypeTowerFloorCatalog.FLOOR_COUNT:
        return active_floor_id
    var safe_floor_id := int(profile.safe_state.get("floor_id", 0))
    if safe_floor_id >= 1 and safe_floor_id <= PrototypeTowerFloorCatalog.FLOOR_COUNT:
        return safe_floor_id
    return 0


static func _rejected(reason_id: StringName, layer_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "layer_id": layer_id,
        "travel_action_available": false,
    }
