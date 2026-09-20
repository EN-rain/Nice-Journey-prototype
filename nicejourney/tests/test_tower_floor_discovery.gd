extends SceneTree

const TOWER_VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const DISCOVERY_TRIGGER_SCRIPT: Script = preload("res://src/world/tower/tower_room_discovery_trigger.gd")
const DISCOVERY_SERVICE_SCRIPT: Script = preload("res://src/world/tower/tower_floor_discovery_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Discovery", "melee")
    var request := TowerFloorGenerationCommitService.build_request(
        1,
        10191,
        &"tower_generator:v01",
        &"tower_modules:v01",
        &"encounters:v01",
        &"quest_flags:discovery_fixture"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    _expect(not manifest.is_empty(), "tower discovery fixture builds a validated authored floor manifest")
    var floor := TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:discovery_floor1", manifest)
    _expect(floor != null and TowerFloorStateService.commit_floor_state(profile, floor), "tower discovery fixture commits persistent floor state")
    if floor == null:
        quit(1)
        return

    _expect(floor.discovered_room_ids.is_empty(), "new generated floor begins with no fabricated discovered rooms")
    var entrance_id := StringName(String(manifest.get("entrance_room_id", &"")))
    var first: Dictionary = DISCOVERY_SERVICE_SCRIPT.mark_room_discovered(profile, 1, entrance_id)
    _expect(bool(first.get("accepted", false)) and bool(first.get("changed", false)), "entering an authored room records discovery")
    _expect((first.get("discovered_room_ids", []) as Array) == [String(entrance_id)], "discovery result reports only the entered room")

    var duplicate: Dictionary = DISCOVERY_SERVICE_SCRIPT.mark_room_discovered(profile, 1, entrance_id)
    _expect(bool(duplicate.get("accepted", false)) and not bool(duplicate.get("changed", true)), "duplicate room entry is idempotent")
    _expect(StringName(duplicate.get("reason_id", &"")) == DISCOVERY_SERVICE_SCRIPT.REASON_ALREADY_DISCOVERED, "duplicate discovery reports its explicit reason")

    var unknown: Dictionary = DISCOVERY_SERVICE_SCRIPT.mark_room_discovered(profile, 1, &"room:not_in_manifest")
    _expect(not bool(unknown.get("accepted", true)) and StringName(unknown.get("reason_id", &"")) == DISCOVERY_SERVICE_SCRIPT.REASON_ROOM_NOT_IN_MANIFEST, "discovery cannot reveal a room absent from the committed manifest")

    var restored := FloorInstanceState.new()
    _expect(restored.load_dictionary(profile.tower_floor_states["1"] as Dictionary).is_empty(), "discovered room state reloads through floor persistence")
    _expect(restored.discovered_room_ids == [entrance_id], "floor persistence retains the exact discovered-room set")
    var summaries: Array[Dictionary] = DISCOVERY_SERVICE_SCRIPT.visible_room_summaries(restored)
    _expect(summaries.size() == 1 and StringName(summaries[0].get("room_instance_id", &"")) == entrance_id, "map-visible room summaries contain only discovered rooms")
    if not summaries.is_empty():
        _expect(summaries[0].has("rect"), "discovered room summary exposes authored navigation geometry")
        _expect(not summaries[0].has("module_id") and not summaries[0].has("tags"), "discovered room summary does not leak module or semantic room tags")
    _expect((DISCOVERY_SERVICE_SCRIPT.visible_room_connections(restored) as Array).is_empty(), "one discovered room cannot reveal an edge to an undiscovered neighbor")

    var neighbor_id: StringName = &""
    for raw_edge: Variant in manifest.get("edges", []) as Array:
        if not raw_edge is Dictionary:
            continue
        var edge := raw_edge as Dictionary
        var from_id := StringName(String(edge.get("from_room_id", &"")))
        var to_id := StringName(String(edge.get("to_room_id", &"")))
        if from_id == entrance_id:
            neighbor_id = to_id
            break
        if to_id == entrance_id:
            neighbor_id = from_id
            break
    _expect(neighbor_id != &"", "discovery fixture has an authored room connection from the entrance")
    if neighbor_id != &"":
        var neighbor_discovery: Dictionary = DISCOVERY_SERVICE_SCRIPT.mark_room_discovered(profile, 1, neighbor_id)
        _expect(bool(neighbor_discovery.get("accepted", false)) and bool(neighbor_discovery.get("changed", false)), "physical discovery of the connected neighbor records independently")
        var connected_state := FloorInstanceState.new()
        _expect(connected_state.load_dictionary(profile.tower_floor_states["1"] as Dictionary).is_empty(), "connected discovery reloads from persistent floor state")
        var visible_connections: Array = DISCOVERY_SERVICE_SCRIPT.visible_room_connections(connected_state)
        _expect(visible_connections.size() == 1, "a room edge becomes map-visible only after both endpoint rooms are discovered")
        if visible_connections.size() == 1:
            var connection := visible_connections[0] as Dictionary
            var endpoint_ids: Array[StringName] = [StringName(connection.get("from_room_id", &"")), StringName(connection.get("to_room_id", &""))]
            endpoint_ids.sort()
            var expected_ids: Array[StringName] = [entrance_id, neighbor_id]
            expected_ids.sort()
            _expect(endpoint_ids == expected_ids, "visible connection preserves the exact authored discovered room pair")

    var legacy := restored.to_dictionary()
    legacy.erase("discovered_room_ids")
    _expect(FloorInstanceState.validate_dictionary(legacy).is_empty(), "older floor state without discovered_room_ids remains backward compatible")
    var legacy_loaded := FloorInstanceState.new()
    _expect(legacy_loaded.load_dictionary(legacy).is_empty() and legacy_loaded.discovered_room_ids.is_empty(), "legacy floor state loads with an empty discovery set")

    var build := TowerFloorRuntimeComposer.build(manifest, TOWER_VISUAL_CATALOG)
    _expect(bool(build.get("accepted", false)), "runtime composer builds the discovery fixture")
    var root_node := build.get("root") as Node2D
    if root_node != null:
        root.add_child(root_node)
        await process_frame
        var rooms_root := root_node.get_node_or_null("Rooms")
        _expect(rooms_root != null, "composed floor owns its Rooms root")
        if rooms_root != null:
            var trigger_count := 0
            for room_node: Node in rooms_root.get_children():
                var trigger := room_node.get_node_or_null("DiscoveryTrigger") as Area2D
                _expect(trigger != null, "%s receives an all-room discovery trigger" % String(room_node.name))
                if trigger == null:
                    continue
                trigger_count += 1
                _expect(StringName(String(trigger.get("room_instance_id"))) == StringName(String(room_node.get_meta(&"room_instance_id", &""))), "%s discovery trigger preserves exact room identity" % String(room_node.name))
                _expect(trigger.get_child_count() > 0, "%s discovery trigger derives collision shapes from authored walkable geometry" % String(room_node.name))
            _expect(trigger_count == (manifest.get("rooms", []) as Array).size(), "every committed room receives one discovery trigger")
        root_node.queue_free()
        await process_frame

    if _failures == 0:
        print("TOWER FLOOR DISCOVERY TEST PASS")
    else:
        push_error("TOWER FLOOR DISCOVERY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
