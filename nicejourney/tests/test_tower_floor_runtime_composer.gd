extends SceneTree

const VISUAL_CATALOG_PATH := "res://src/world/tower/presentation/tower_room_visual_catalog.tres"
var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var visual_catalog := load(VISUAL_CATALOG_PATH) as TowerRoomVisualCatalog
    _expect(visual_catalog != null and visual_catalog.validate_catalog().is_empty(), "tower visual catalog is available to runtime composition")
    for floor_id: int in [1, 4, 5, 10]:
        await _exercise_floor(floor_id, visual_catalog)
    _test_invalid_manifest_rejection(visual_catalog)
    if _failures == 0:
        print("TOWER FLOOR RUNTIME COMPOSER TEST PASS")
    else:
        push_error("TOWER FLOOR RUNTIME COMPOSER TEST FAILURES: %d" % _failures)
    quit(_failures)

func _exercise_floor(floor_id: int, visual_catalog: TowerRoomVisualCatalog) -> void:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        90000 + floor_id,
        &"generator:prototype_v01",
        &"modules:prototype_v01",
        &"encounters:prototype_v01",
        &"questflags:test_v01"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    _expect(not manifest.is_empty(), "Floor %d fallback exists for live composition" % floor_id)
    var result := TowerFloorRuntimeComposer.build(manifest, visual_catalog)
    _expect(bool(result.get("accepted", false)), "Floor %d manifest composes into a live node tree" % floor_id)
    if not bool(result.get("accepted", false)):
        return
    var root := result["root"] as Node2D
    get_root().add_child(root)
    await process_frame

    _expect(int(root.get_meta(&"floor_id", -1)) == floor_id, "Floor %d runtime root exposes authoritative floor identity" % floor_id)
    _expect(int(root.get_meta(&"tile_size", 0)) == 32, "Floor %d runtime root uses the approved 32 px tile scale" % floor_id)
    var rooms := root.get_node_or_null("Rooms") as Node2D
    _expect(rooms != null and rooms.get_child_count() == (manifest["rooms"] as Array).size(), "Floor %d instantiates exactly one live room per committed manifest room" % floor_id)
    var bounds := root.get_node_or_null("WorldBounds") as StaticBody2D
    _expect(bounds != null and bounds.get_child_count() == 4, "Floor %d owns four physical 50x50 world-bound walls" % floor_id)
    var graph_links := root.get_node_or_null("GraphLinks") as Node2D
    _expect(graph_links != null and graph_links.get_child_count() == (manifest["edges"] as Array).size(), "Floor %d preserves every committed graph edge as runtime identity" % floor_id)

    if rooms != null:
        for raw_room: Variant in manifest["rooms"] as Array:
            var room := raw_room as Dictionary
            var room_id := StringName(String(room["room_instance_id"]))
            var runtime_room := _find_room(rooms, room_id)
            _expect(runtime_room != null, "Floor %d runtime resolves room %s" % [floor_id, String(room_id)])
            if runtime_room == null:
                continue
            var rect := room["rect"] as Rect2i
            _expect(runtime_room.position == Vector2(rect.position * 32), "room %s uses committed tile placement" % String(room_id))
            var module_id := StringName(String(room["module_id"]))
            var definition := TowerPrototypeModuleCatalog.get_definition(module_id)
            _expect(definition != null, "room %s resolves its authored module contract" % String(room_id))
            if definition == null:
                continue
            var collision := runtime_room.get_node_or_null("Collision") as StaticBody2D
            _expect(collision != null and collision.get_child_count() == definition.collision_rects.size(), "room %s owns all authored module collision rectangles" % String(room_id))
            var connectors := runtime_room.get_node_or_null("Connectors") as Node2D
            _expect(connectors != null and connectors.get_child_count() == definition.connectors.size(), "room %s instantiates every authored connector marker" % String(room_id))
            var room_navigation := runtime_room.get_node_or_null("Navigation") as Node2D
            _expect(room_navigation != null and room_navigation.get_child_count() == definition.walkable_rects.size(), "room %s instantiates navigation regions for every authored walkable rectangle" % String(room_id))
            if room_navigation != null:
                for child: Node in room_navigation.get_children():
                    var region := child as NavigationRegion2D
                    _expect(region != null and region.navigation_polygon != null, "room %s walkable navigation region owns polygon data" % String(room_id))
            var arrivals := runtime_room.get_node_or_null("ArrivalCandidates") as Node2D
            _expect(arrivals != null and arrivals.get_child_count() == definition.arrival_candidates.size(), "room %s instantiates every authored safe-arrival candidate" % String(room_id))
            var visual := runtime_room.get_node_or_null("Visual") as TowerRoomVisual
            var floor_tiles := runtime_room.get_node_or_null("FloorTiles") as TileMapLayer
            _expect(floor_tiles != null and floor_tiles.tile_set == visual_catalog.floor_tileset, "room %s uses the inspector-owned floor TileSet" % String(room_id))
            if floor_tiles != null:
                _expect(floor_tiles.get_used_cells().size() == definition.footprint_size.x * definition.footprint_size.y, "room %s has complete visual floor coverage" % String(room_id))
                _expect(floor_tiles.get_cell_source_id(Vector2i.ZERO) == visual_catalog.floor_tile_source_id, "room %s uses the declared floor atlas source" % String(room_id))
                _expect(floor_tiles.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "room %s floor keeps nearest filtering" % String(room_id))
            _expect(visual != null and visual.profile != null and visual.profile.room_type == definition.visual_room_type, "room %s consumes the inspector-owned semantic tower visual profile" % String(room_id))
            if visual != null:
                var sprite := visual.get_node_or_null("Sprite") as Sprite2D
                _expect(sprite != null and sprite.texture == visual.profile.texture, "room %s live presenter applies its profile texture" % String(room_id))
                _expect(sprite != null and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "room %s preserves nearest-filtered pixel presentation" % String(room_id))
    if graph_links != null:
        for link: Node in graph_links.get_children():
            var route_navigation := link.get_node_or_null("Navigation") as Node2D
            var route_tiles: Array = link.get_meta(&"route_tiles", []) as Array
            _expect(route_navigation != null and route_navigation.get_child_count() == route_tiles.size(), "Floor %d link navigation covers every committed route tile" % floor_id)
            var route_floor := link.get_node_or_null("FloorTiles") as TileMapLayer
            _expect(route_floor != null and route_floor.tile_set == visual_catalog.floor_tileset, "Floor %d link has inspector-owned floor TileSet" % floor_id)
            if route_floor != null:
                _expect(route_floor.get_used_cells().size() >= route_tiles.size(), "Floor %d link has visible coverage of every route center" % floor_id)
                _expect(route_floor.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Floor %d link retains nearest pixel filtering" % floor_id)
                for raw_tile: Variant in route_tiles:
                    _expect(route_floor.get_cell_source_id(raw_tile as Vector2i) == visual_catalog.floor_tile_source_id, "Floor %d committed route tile is actually drawn" % floor_id)
    root.queue_free()
    await process_frame

func _test_invalid_manifest_rejection(visual_catalog: TowerRoomVisualCatalog) -> void:
    var request := TowerFloorGenerationCommitService.build_request(1, 123, &"generator:prototype_v01", &"modules:prototype_v01", &"encounters:prototype_v01", &"questflags:test_v01")
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    manifest["reserved_quest_ids"] = []
    var result := TowerFloorRuntimeComposer.build(manifest, visual_catalog)
    _expect(not bool(result.get("accepted", true)) and result.get("root", null) == null, "runtime composer rejects a manifest that drops the floor's required quest reservation")

func _find_room(rooms: Node2D, room_id: StringName) -> Node2D:
    for child: Node in rooms.get_children():
        if child is Node2D and StringName(String(child.get_meta(&"room_instance_id", &""))) == room_id:
            return child as Node2D
    return null

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
