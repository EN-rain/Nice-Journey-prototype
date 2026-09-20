class_name TowerFloorRuntimeComposer
extends RefCounted

const DEFAULT_TILE_SIZE: int = 32
const WORLD_TILES: int = TowerFloorLayoutManifestValidator.MAX_FOOTPRINT_TILES
const ROOM_DISCOVERY_TRIGGER_SCRIPT: Script = preload("res://src/world/tower/tower_room_discovery_trigger.gd")

const REASON_INVALID_MANIFEST: StringName = &"invalid_manifest"
const REASON_INVALID_PRESENTATION: StringName = &"invalid_presentation"
const REASON_UNKNOWN_MODULE: StringName = &"unknown_module"
const REASON_BUILD_FAILED: StringName = &"build_failed"


static func build(raw_manifest: Variant, visual_catalog: TowerRoomVisualCatalog, tile_size: int = DEFAULT_TILE_SIZE) -> Dictionary:
    if tile_size <= 0 or visual_catalog == null:
        return _rejected(REASON_INVALID_PRESENTATION, PackedStringArray(["visual catalog and positive tile_size are required"]))
    var catalog_errors: PackedStringArray = visual_catalog.validate_catalog()
    if not catalog_errors.is_empty():
        return _rejected(REASON_INVALID_PRESENTATION, catalog_errors)
    if not raw_manifest is Dictionary:
        return _rejected(REASON_INVALID_MANIFEST, PackedStringArray(["manifest must be a dictionary"]))

    var manifest: Dictionary = (raw_manifest as Dictionary).duplicate(true)
    var request: Dictionary = _request_from_manifest(manifest)
    var request_errors: PackedStringArray = TowerFloorGenerationCommitService.validate_request(request)
    if not request_errors.is_empty():
        return _rejected(REASON_INVALID_MANIFEST, request_errors)
    var manifest_errors: PackedStringArray = TowerFloorLayoutManifestValidator.validate_manifest(manifest, request)
    for module_error: String in TowerPrototypeModuleCatalog.validate_manifest_modules(manifest):
        manifest_errors.append(module_error)
    for traversal_error: String in TowerFloorTraversalManifestValidator.validate_manifest(manifest):
        manifest_errors.append(traversal_error)
    if not manifest_errors.is_empty():
        return _rejected(REASON_INVALID_MANIFEST, manifest_errors)

    var root := Node2D.new()
    root.name = "TowerFloor%02d" % int(manifest["floor_id"])
    root.set_meta(&"floor_id", int(manifest["floor_id"]))
    root.set_meta(&"generation_seed", int(manifest["generation_seed"]))
    root.set_meta(&"layout_revision_id", StringName(String(manifest["layout_revision_id"])))
    root.set_meta(&"tile_size", tile_size)

    var rooms := Node2D.new()
    rooms.name = "Rooms"
    root.add_child(rooms)
    var world_collision := StaticBody2D.new()
    world_collision.name = "WorldBounds"
    world_collision.collision_layer = 1
    world_collision.collision_mask = 1
    root.add_child(world_collision)
    _append_world_bounds(world_collision, tile_size)

    for raw_room: Variant in manifest["rooms"] as Array:
        var room: Dictionary = raw_room as Dictionary
        var module_id := StringName(String(room["module_id"]))
        var definition: TowerRoomModuleDefinition = TowerPrototypeModuleCatalog.get_definition(module_id)
        if definition == null:
            root.free()
            return _rejected(REASON_UNKNOWN_MODULE, PackedStringArray(["missing module %s" % String(module_id)]))
        var profile: TowerRoomVisualProfile = visual_catalog.get_profile(definition.visual_room_type)
        if profile == null or not profile.validate_profile().is_empty():
            root.free()
            return _rejected(REASON_INVALID_PRESENTATION, PackedStringArray(["missing valid visual profile for %s" % String(definition.visual_room_type)]))
        var room_node: Node2D = _build_room(room, definition, profile, visual_catalog, tile_size)
        if room_node == null:
            root.free()
            return _rejected(REASON_BUILD_FAILED, PackedStringArray(["failed to compose room %s" % String(room.get("room_instance_id", ""))]))
        rooms.add_child(room_node)

    var links := Node2D.new()
    links.name = "GraphLinks"
    root.add_child(links)
    for raw_edge: Variant in manifest["edges"] as Array:
        var edge := raw_edge as Dictionary
        var marker := Node2D.new()
        marker.name = _node_name("Link_%s_%s" % [String(edge["from_room_id"]), String(edge["to_room_id"])])
        marker.set_meta(&"from_room_id", StringName(String(edge["from_room_id"])))
        marker.set_meta(&"to_room_id", StringName(String(edge["to_room_id"])))
        marker.set_meta(&"from_connector_id", StringName(String(edge["from_connector_id"])))
        marker.set_meta(&"to_connector_id", StringName(String(edge["to_connector_id"])))
        marker.set_meta(&"route_width_tiles", int(edge["route_width_tiles"]))
        marker.set_meta(&"route_tiles", (edge["route_tiles"] as Array).duplicate(true))
        var route_floor := TileMapLayer.new()
        route_floor.name = "FloorTiles"
        route_floor.tile_set = visual_catalog.floor_tileset
        route_floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        route_floor.scale = Vector2.ONE * (float(tile_size) / float(visual_catalog.floor_tileset.tile_size.x))
        route_floor.z_index = -4
        _append_route_floor(route_floor, edge["route_tiles"] as Array, int(edge["route_width_tiles"]), visual_catalog.floor_tile_source_id)
        marker.add_child(route_floor)
        var route_navigation := Node2D.new()
        route_navigation.name = "Navigation"
        marker.add_child(route_navigation)
        _append_route_navigation(route_navigation, edge["route_tiles"] as Array, int(edge["route_width_tiles"]), tile_size)
        links.add_child(marker)

    return {
        "accepted": true,
        "reason_id": &"",
        "errors": PackedStringArray(),
        "root": root,
    }


static func _build_room(room: Dictionary, definition: TowerRoomModuleDefinition, profile: TowerRoomVisualProfile, visual_catalog: TowerRoomVisualCatalog, tile_size: int) -> Node2D:
    var rect: Rect2i = room["rect"] as Rect2i
    var room_node := Node2D.new()
    room_node.name = _node_name(String(room["room_instance_id"]))
    room_node.position = Vector2(rect.position * tile_size)
    room_node.set_meta(&"room_instance_id", StringName(String(room["room_instance_id"])))
    room_node.set_meta(&"module_id", definition.module_id)
    room_node.set_meta(&"visual_room_type", definition.visual_room_type)
    room_node.set_meta(&"tags", (room["tags"] as Array).duplicate(true))

    # Visual-only floor coverage follows the committed module footprint. The
    # authored collision, connectors, routes and navigation remain separate.
    var floor_tiles := TileMapLayer.new()
    floor_tiles.name = "FloorTiles"
    floor_tiles.tile_set = visual_catalog.floor_tileset
    floor_tiles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    floor_tiles.scale = Vector2.ONE * (float(tile_size) / float(visual_catalog.floor_tileset.tile_size.x))
    floor_tiles.z_index = -4
    for floor_y: int in range(definition.footprint_size.y):
        for floor_x: int in range(definition.footprint_size.x):
            floor_tiles.set_cell(Vector2i(floor_x, floor_y), visual_catalog.floor_tile_source_id, Vector2i((floor_x + floor_y) % 4, 0))
    room_node.add_child(floor_tiles)

    var visual := TowerRoomVisual.new()
    visual.name = "Visual"
    visual.profile = profile
    visual.position = Vector2(definition.footprint_size * tile_size) * 0.5
    var sprite := Sprite2D.new()
    sprite.name = "Sprite"
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    visual.add_child(sprite)
    room_node.add_child(visual)

    var collision := StaticBody2D.new()
    collision.name = "Collision"
    collision.collision_layer = 1
    collision.collision_mask = 1
    room_node.add_child(collision)
    for index: int in range(definition.collision_rects.size()):
        _append_rect_shape(collision, definition.collision_rects[index], tile_size, "Wall%02d" % index)

    var connectors := Node2D.new()
    connectors.name = "Connectors"
    room_node.add_child(connectors)
    var connector_ids: Array[String] = []
    for raw_connector_id: Variant in definition.connectors.keys():
        connector_ids.append(String(raw_connector_id))
    connector_ids.sort()
    for connector_text: String in connector_ids:
        var connector: Dictionary = definition.connectors[connector_text] as Dictionary
        var marker := Marker2D.new()
        marker.name = _node_name("Connector_%s" % connector_text)
        marker.position = (Vector2(connector["tile"] as Vector2i) + Vector2(0.5, 0.5)) * float(tile_size)
        marker.set_meta(&"connector_id", StringName(connector_text))
        marker.set_meta(&"facing", StringName(String(connector["facing"])))
        marker.set_meta(&"one_way", bool(connector["one_way"]))
        connectors.add_child(marker)

    var navigation := Node2D.new()
    navigation.name = "Navigation"
    room_node.add_child(navigation)
    for index: int in range(definition.walkable_rects.size()):
        _append_navigation_rect(navigation, definition.walkable_rects[index], tile_size, "Walkable%02d" % index)

    if not definition.walkable_rects.is_empty():
        var discovery_trigger := ROOM_DISCOVERY_TRIGGER_SCRIPT.new() as Area2D
        discovery_trigger.name = "DiscoveryTrigger"
        if not bool(discovery_trigger.call("configure", StringName(String(room["room_instance_id"])))):
            return null
        room_node.add_child(discovery_trigger)
        for index: int in range(definition.walkable_rects.size()):
            _append_rect_shape(discovery_trigger, definition.walkable_rects[index], tile_size, "Trigger%02d" % index)

    if not definition.spawn_regions.is_empty():
        var encounter_trigger := TowerEncounterRoomTrigger.new()
        encounter_trigger.name = "EncounterTrigger"
        if not encounter_trigger.configure(StringName(String(room["room_instance_id"]))):
            return null
        room_node.add_child(encounter_trigger)
        for index: int in range(definition.walkable_rects.size()):
            _append_rect_shape(encounter_trigger, definition.walkable_rects[index], tile_size, "Trigger%02d" % index)

    var arrivals := Node2D.new()
    arrivals.name = "ArrivalCandidates"
    room_node.add_child(arrivals)
    for index: int in range(definition.arrival_candidates.size()):
        var marker := Marker2D.new()
        marker.name = "Arrival%02d" % index
        marker.position = (Vector2(definition.arrival_candidates[index]) + Vector2(0.5, 0.5)) * float(tile_size)
        arrivals.add_child(marker)
    return room_node


static func _append_route_navigation(parent: Node2D, route_tiles: Array, width_tiles: int, tile_size: int) -> void:
    var width_px := float(width_tiles * tile_size)
    for index: int in range(route_tiles.size()):
        var tile := route_tiles[index] as Vector2i
        var center := (Vector2(tile) + Vector2(0.5, 0.5)) * float(tile_size)
        var top_left := center - Vector2(width_px, width_px) * 0.5
        _append_navigation_pixel_rect(parent, Rect2(top_left, Vector2(width_px, width_px)), "Route%03d" % index)


static func _append_route_floor(floor_tiles: TileMapLayer, route_tiles: Array, width_tiles: int, atlas_source_id: int) -> void:
    # Paint only already-committed graph link tiles, respecting their authored
    # width. This is decoration: the authoritative navigation remains above.
    var first_offset: int = -int((width_tiles - 1) / 2)
    for raw_tile: Variant in route_tiles:
        var center: Vector2i = raw_tile as Vector2i
        for offset_y: int in range(first_offset, first_offset + width_tiles):
            for offset_x: int in range(first_offset, first_offset + width_tiles):
                var cell := center + Vector2i(offset_x, offset_y)
                floor_tiles.set_cell(cell, atlas_source_id, Vector2i((cell.x + cell.y) % 4, 0))


static func _append_navigation_rect(parent: Node2D, rect: Rect2i, tile_size: int, region_name: String) -> void:
    var pixel_rect := Rect2(Vector2(rect.position) * float(tile_size), Vector2(rect.size) * float(tile_size))
    _append_navigation_pixel_rect(parent, pixel_rect, region_name)


static func _append_navigation_pixel_rect(parent: Node2D, rect: Rect2, region_name: String) -> void:
    var region := NavigationRegion2D.new()
    region.name = region_name
    var polygon := NavigationPolygon.new()
    polygon.vertices = PackedVector2Array([
        rect.position,
        Vector2(rect.end.x, rect.position.y),
        rect.end,
        Vector2(rect.position.x, rect.end.y),
    ])
    polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
    region.navigation_polygon = polygon
    parent.add_child(region)


static func _append_world_bounds(body: StaticBody2D, tile_size: int) -> void:
    var world_px := WORLD_TILES * tile_size
    _append_pixel_rect_shape(body, Vector2(world_px * 0.5, tile_size * 0.5), Vector2(world_px, tile_size), "Top")
    _append_pixel_rect_shape(body, Vector2(world_px * 0.5, world_px - tile_size * 0.5), Vector2(world_px, tile_size), "Bottom")
    _append_pixel_rect_shape(body, Vector2(tile_size * 0.5, world_px * 0.5), Vector2(tile_size, world_px), "Left")
    _append_pixel_rect_shape(body, Vector2(world_px - tile_size * 0.5, world_px * 0.5), Vector2(tile_size, world_px), "Right")


static func _append_rect_shape(body: CollisionObject2D, rect: Rect2i, tile_size: int, shape_name: String) -> void:
    var center := (Vector2(rect.position) + Vector2(rect.size) * 0.5) * float(tile_size)
    var size := Vector2(rect.size) * float(tile_size)
    _append_pixel_rect_shape(body, center, size, shape_name)


static func _append_pixel_rect_shape(body: CollisionObject2D, center: Vector2, size: Vector2, shape_name: String) -> void:
    var collision_shape := CollisionShape2D.new()
    collision_shape.name = shape_name
    collision_shape.position = center
    var rectangle := RectangleShape2D.new()
    rectangle.size = size
    collision_shape.shape = rectangle
    body.add_child(collision_shape)


static func _request_from_manifest(manifest: Dictionary) -> Dictionary:
    return {
        "floor_id": manifest.get("floor_id", null),
        "generation_seed": manifest.get("generation_seed", null),
        "generator_version": manifest.get("generator_version", null),
        "module_content_version": manifest.get("module_content_version", null),
        "encounter_config_id": manifest.get("encounter_config_id", null),
        "quest_world_flags_signature": manifest.get("quest_world_flags_signature", null),
        "required_quest_ids": (manifest.get("reserved_quest_ids", []) as Array).duplicate(true) if manifest.get("reserved_quest_ids", null) is Array else [],
    }


static func _node_name(value: String) -> String:
    return value.replace(":", "_").replace("/", "_").replace("-", "_").replace(".", "_")


static func _rejected(reason_id: StringName, errors: PackedStringArray) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "errors": errors,
        "root": null,
    }
