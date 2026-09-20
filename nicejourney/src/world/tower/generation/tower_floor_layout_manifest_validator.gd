class_name TowerFloorLayoutManifestValidator
extends RefCounted

const MAX_FOOTPRINT_TILES: int = 50

const TAG_ENTRANCE: StringName = &"entrance"
const TAG_COMBAT: StringName = &"combat"
const TAG_ESCORT_ROUTE: StringName = &"escort_route"
const TAG_DEFENSE_ARENA: StringName = &"defense_arena"
const TAG_OBJECTIVE: StringName = &"objective"
const TAG_ELITE: StringName = &"elite"
const TAG_SAFE: StringName = &"safe"
const TAG_EXIT: StringName = &"exit"
const TAG_BOSS: StringName = &"boss"


static func validate_manifest(raw_manifest: Variant, raw_request: Variant) -> PackedStringArray:
    var errors := PackedStringArray()
    if not raw_manifest is Dictionary:
        errors.append("manifest must be a dictionary")
        return errors
    if not raw_request is Dictionary:
        errors.append("request must be a dictionary")
        return errors
    var manifest: Dictionary = raw_manifest as Dictionary
    var request: Dictionary = raw_request as Dictionary

    _validate_tuple(manifest, request, errors)
    if not manifest.get("rooms", null) is Array:
        errors.append("rooms must be an array")
        return errors
    if not manifest.get("edges", null) is Array:
        errors.append("edges must be an array")
        return errors
    if not manifest.get("objective_bindings", null) is Dictionary:
        errors.append("objective_bindings must be a dictionary")
        return errors
    if not _is_stable_id_value(manifest.get("entrance_room_id", null)):
        errors.append("entrance_room_id must be a stable ID")
    if not _is_stable_id_value(manifest.get("exit_room_id", null)):
        errors.append("exit_room_id must be a stable ID")
    if not errors.is_empty():
        return errors

    var room_result: Dictionary = _validate_rooms(manifest["rooms"] as Array)
    for error: String in room_result["errors"] as PackedStringArray:
        errors.append(error)
    if not errors.is_empty():
        return errors
    var room_by_id: Dictionary = room_result["room_by_id"] as Dictionary

    var entrance_id := StringName(String(manifest["entrance_room_id"]))
    var exit_id := StringName(String(manifest["exit_room_id"]))
    if not room_by_id.has(entrance_id):
        errors.append("entrance_room_id must reference a room")
    if not room_by_id.has(exit_id):
        errors.append("exit_room_id must reference a room")
    if not errors.is_empty():
        return errors

    var entrance: Dictionary = room_by_id[entrance_id] as Dictionary
    var exit_room: Dictionary = room_by_id[exit_id] as Dictionary
    if not _room_has_tag(entrance, TAG_ENTRANCE):
        errors.append("entrance room must carry the entrance tag")
    if not bool(entrance.get("safe_arrival", false)):
        errors.append("entrance room must provide a safe arrival")
    if not _room_has_tag(exit_room, TAG_EXIT):
        errors.append("exit room must carry the exit tag")

    var graph_result: Dictionary = _build_graph(manifest["edges"] as Array, room_by_id)
    for error: String in graph_result["errors"] as PackedStringArray:
        errors.append(error)
    if not errors.is_empty():
        return errors
    var graph: Dictionary = graph_result["graph"] as Dictionary
    var reachable: Dictionary = _reachable_from(entrance_id, graph)
    if not reachable.has(exit_id):
        errors.append("exit must be structurally reachable from entrance")

    _validate_quest_bindings(manifest, request, room_by_id, reachable, errors)
    _validate_floor_specials(manifest, request, room_by_id, graph, reachable, errors)
    return errors


static func _validate_tuple(manifest: Dictionary, request: Dictionary, errors: PackedStringArray) -> void:
    for key: String in ["floor_id", "generation_seed"]:
        if typeof(manifest.get(key, null)) != TYPE_INT or typeof(request.get(key, null)) != TYPE_INT or int(manifest.get(key, -1)) != int(request.get(key, -2)):
            errors.append("manifest %s must exactly match the generation request" % key)
    for key: String in ["generator_version", "module_content_version", "encounter_config_id", "quest_world_flags_signature"]:
        if not _is_stable_id_value(manifest.get(key, null)) or not _is_stable_id_value(request.get(key, null)):
            errors.append("%s must be a stable ID in manifest and request" % key)
            continue
        if StringName(String(manifest[key])) != StringName(String(request[key])):
            errors.append("manifest %s must exactly match the generation request" % key)
    var request_quests: Array[StringName] = _normalized_id_array(request.get("required_quest_ids", null), "request required_quest_ids", errors)
    var manifest_quests: Array[StringName] = _normalized_id_array(manifest.get("reserved_quest_ids", null), "manifest reserved_quest_ids", errors)
    if request_quests != manifest_quests:
        errors.append("reserved_quest_ids must exactly match required_quest_ids")


static func _validate_rooms(rooms: Array) -> Dictionary:
    var errors := PackedStringArray()
    var room_by_id: Dictionary = {}
    var rects: Array[Rect2i] = []
    var ids: Array[StringName] = []
    for index: int in range(rooms.size()):
        var raw_room: Variant = rooms[index]
        if not raw_room is Dictionary:
            errors.append("room %d must be a dictionary" % index)
            continue
        var room: Dictionary = raw_room as Dictionary
        if not _is_stable_id_value(room.get("room_instance_id", null)):
            errors.append("room %d room_instance_id must be stable" % index)
            continue
        if not _is_stable_id_value(room.get("module_id", null)):
            errors.append("room %d module_id must be stable" % index)
        var room_id := StringName(String(room["room_instance_id"]))
        if room_by_id.has(room_id):
            errors.append("duplicate room_instance_id: %s" % String(room_id))
            continue
        if not room.get("rect", null) is Rect2i:
            errors.append("room %s rect must be Rect2i" % String(room_id))
            continue
        var rect: Rect2i = room["rect"] as Rect2i
        if rect.size.x <= 0 or rect.size.y <= 0:
            errors.append("room %s rect must have positive size" % String(room_id))
        if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > MAX_FOOTPRINT_TILES or rect.end.y > MAX_FOOTPRINT_TILES:
            errors.append("room %s exceeds the 50x50 floor footprint" % String(room_id))
        if not room.get("tags", null) is Array:
            errors.append("room %s tags must be an array" % String(room_id))
        else:
            _normalized_id_array(room["tags"], "room %s tags" % String(room_id), errors)
        if typeof(room.get("objective_socket_capacity", null)) != TYPE_INT or int(room.get("objective_socket_capacity", -1)) < 0:
            errors.append("room %s objective_socket_capacity must be a nonnegative integer" % String(room_id))
        if typeof(room.get("elite_capacity", null)) != TYPE_INT or int(room.get("elite_capacity", -1)) < 0:
            errors.append("room %s elite_capacity must be a nonnegative integer" % String(room_id))
        if typeof(room.get("safe_arrival", null)) != TYPE_BOOL:
            errors.append("room %s safe_arrival must be boolean" % String(room_id))
        for prior_index: int in range(rects.size()):
            if rect.intersects(rects[prior_index]):
                errors.append("room %s overlaps room %s" % [String(room_id), String(ids[prior_index])])
        room_by_id[room_id] = room.duplicate(true)
        rects.append(rect)
        ids.append(room_id)
    return {"errors": errors, "room_by_id": room_by_id}


static func _build_graph(edges: Array, room_by_id: Dictionary) -> Dictionary:
    var errors := PackedStringArray()
    var graph: Dictionary = {}
    for room_id: Variant in room_by_id.keys():
        graph[StringName(room_id)] = []
    var seen_edges: Dictionary = {}
    for index: int in range(edges.size()):
        var raw_edge: Variant = edges[index]
        if not raw_edge is Dictionary:
            errors.append("edge %d must be a dictionary" % index)
            continue
        var edge: Dictionary = raw_edge as Dictionary
        if not _is_stable_id_value(edge.get("from_room_id", null)) or not _is_stable_id_value(edge.get("to_room_id", null)):
            errors.append("edge %d endpoints must be stable IDs" % index)
            continue
        var from_id := StringName(String(edge["from_room_id"]))
        var to_id := StringName(String(edge["to_room_id"]))
        if from_id == to_id:
            errors.append("edge %d cannot self-connect" % index)
            continue
        if not room_by_id.has(from_id) or not room_by_id.has(to_id):
            errors.append("edge %d must reference existing rooms" % index)
            continue
        var pair: Array[String] = [String(from_id), String(to_id)]
        pair.sort()
        var edge_key := "%s|%s" % pair
        if seen_edges.has(edge_key):
            errors.append("duplicate edge: %s" % edge_key)
            continue
        seen_edges[edge_key] = true
        (graph[from_id] as Array).append(to_id)
        (graph[to_id] as Array).append(from_id)
    return {"errors": errors, "graph": graph}


static func _validate_quest_bindings(
    manifest: Dictionary,
    request: Dictionary,
    room_by_id: Dictionary,
    reachable: Dictionary,
    errors: PackedStringArray
) -> void:
    var bindings: Dictionary = manifest["objective_bindings"] as Dictionary
    var required_quests: Array[StringName] = _normalized_id_array(request["required_quest_ids"], "required_quest_ids", errors)
    var seen_rooms: Dictionary = {}
    for quest_id: StringName in required_quests:
        if not bindings.has(String(quest_id)) and not bindings.has(quest_id):
            errors.append("missing objective binding for %s" % String(quest_id))
            continue
        var room_variant: Variant = bindings.get(quest_id, bindings.get(String(quest_id), null))
        if not _is_stable_id_value(room_variant):
            errors.append("objective binding for %s must be a stable room ID" % String(quest_id))
            continue
        var room_id := StringName(String(room_variant))
        if not room_by_id.has(room_id):
            errors.append("objective binding for %s references missing room" % String(quest_id))
            continue
        if not reachable.has(room_id):
            errors.append("objective room for %s is not reachable from entrance" % String(quest_id))
        var room: Dictionary = room_by_id[room_id] as Dictionary
        if int(room.get("objective_socket_capacity", 0)) <= 0:
            errors.append("objective room for %s has no objective socket capacity" % String(quest_id))
        var definition: QuestDefinition = QuestCatalog.get_definition(quest_id)
        if definition == null:
            errors.append("required quest %s is not present in the approved quest catalog" % String(quest_id))
            continue
        match definition.family:
            QuestDefinition.FAMILY_ANNIHILATION:
                if not (_room_has_tag(room, TAG_COMBAT) or _room_has_tag(room, TAG_BOSS)):
                    errors.append("annihilation quest %s requires a combat-compatible objective room" % String(quest_id))
            QuestDefinition.FAMILY_ESCORT:
                if not _room_has_tag(room, TAG_ESCORT_ROUTE):
                    errors.append("escort quest %s requires an escort-route-compatible room" % String(quest_id))
            QuestDefinition.FAMILY_TOWER_DEFENSE:
                if not _room_has_tag(room, TAG_DEFENSE_ARENA):
                    errors.append("tower-defense quest %s requires a defense-arena-compatible room" % String(quest_id))
        seen_rooms[room_id] = int(seen_rooms.get(room_id, 0)) + 1
        if int(seen_rooms[room_id]) > int(room.get("objective_socket_capacity", 0)):
            errors.append("objective bindings exceed socket capacity for room %s" % String(room_id))


static func _validate_floor_specials(
    manifest: Dictionary,
    request: Dictionary,
    room_by_id: Dictionary,
    graph: Dictionary,
    reachable: Dictionary,
    errors: PackedStringArray
) -> void:
    var floor_id: int = int(request["floor_id"])
    var elite_capacity := 0
    var boss_rooms: Array[StringName] = []
    var safe_rooms: Array[StringName] = []
    for room_id_variant: Variant in room_by_id.keys():
        var room_id := StringName(room_id_variant)
        var room: Dictionary = room_by_id[room_id] as Dictionary
        if _room_has_tag(room, TAG_ELITE):
            elite_capacity += int(room.get("elite_capacity", 0))
        if _room_has_tag(room, TAG_BOSS):
            boss_rooms.append(room_id)
        if _room_has_tag(room, TAG_SAFE):
            safe_rooms.append(room_id)
    if floor_id in [5, 10] and elite_capacity < 3:
        errors.append("Floor %d must reserve capacity for all three required elites" % floor_id)
    if floor_id == 10:
        if boss_rooms.size() != 1:
            errors.append("Floor 10 must contain exactly one boss room")
        elif not reachable.has(boss_rooms[0]):
            errors.append("Floor 10 boss room must be reachable from entrance")
        else:
            var boss_id: StringName = boss_rooms[0]
            var has_safe_preboss_neighbor := false
            for neighbor_variant: Variant in graph.get(boss_id, []) as Array:
                var neighbor_id := StringName(neighbor_variant)
                if safe_rooms.has(neighbor_id):
                    has_safe_preboss_neighbor = true
                    break
            if not has_safe_preboss_neighbor:
                errors.append("Floor 10 boss room must connect directly to a safe pre-boss checkpoint room")
    elif not boss_rooms.is_empty():
        errors.append("only Floor 10 may contain the prototype boss room")


static func _reachable_from(start_id: StringName, graph: Dictionary) -> Dictionary:
    var visited: Dictionary = {start_id: true}
    var frontier: Array[StringName] = [start_id]
    while not frontier.is_empty():
        var current: StringName = frontier.pop_front()
        for neighbor_variant: Variant in graph.get(current, []) as Array:
            var neighbor := StringName(neighbor_variant)
            if visited.has(neighbor):
                continue
            visited[neighbor] = true
            frontier.append(neighbor)
    return visited


static func _room_has_tag(room: Dictionary, tag: StringName) -> bool:
    if not room.get("tags", null) is Array:
        return false
    for value: Variant in room["tags"] as Array:
        if StringName(String(value)) == tag:
            return true
    return false


static func _normalized_id_array(value: Variant, label: String, errors: PackedStringArray) -> Array[StringName]:
    var result: Array[StringName] = []
    if not value is Array:
        errors.append("%s must be an array" % label)
        return result
    var seen: Dictionary = {}
    for raw_id: Variant in value as Array:
        if not _is_stable_id_value(raw_id):
            errors.append("%s contains an invalid stable ID" % label)
            continue
        var id := StringName(String(raw_id))
        if seen.has(id):
            errors.append("%s contains duplicate ID %s" % [label, String(id)])
            continue
        seen[id] = true
        result.append(id)
    result.sort()
    return result


static func _is_stable_id_value(value: Variant) -> bool:
    return (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME) and StableId.is_valid(String(value))
