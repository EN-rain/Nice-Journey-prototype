class_name TowerEscortObjectiveAuthoring
extends RefCounted

const CONTENT_STATUS: StringName = &"playtest_placeholder"
const PRODUCTION_V01_CONTENT_STATUS: StringName = &"production_v01"
const FAILURE_POLICY_ACTOR_DEFEAT: StringName = &"failure:escort_actor_defeat_v01"


static func build_production_v01(floor_state: FloorInstanceState, quest_id: StringName) -> Dictionary:
    var definition := QuestCatalog.get_definition(quest_id)
    if (
        definition == null
        or definition.kind != QuestDefinition.KIND_PRIMARY
        or definition.family != QuestDefinition.FAMILY_ESCORT
        or definition.floor_id not in [2, 6, 8]
        or definition.playtest_placeholder
    ):
        return {}
    var authored := build(floor_state, quest_id)
    if authored.is_empty():
        return {}
    authored["content_status"] = PRODUCTION_V01_CONTENT_STATUS
    return authored


static func production_readiness(floor_state: FloorInstanceState, quest_id: StringName) -> Dictionary:
    var definition := QuestCatalog.get_definition(quest_id)
    if definition == null or definition.kind != QuestDefinition.KIND_PRIMARY or definition.family != QuestDefinition.FAMILY_ESCORT:
        return {
            "accepted": false,
            "reason_id": &"primary_escort_definition_required",
            "production_ready": false,
            "content_status": &"",
            "placeholder_config_available": false,
            "known_placeholder_config": {},
            "quest_missing_authoritative_fields": PackedStringArray(),
            "external_runtime_missing_authoritative_fields": PackedStringArray(),
        }

    var authority := PrimaryQuestProductionAuthority.readiness(definition)
    var authored := build_production_v01(floor_state, quest_id)
    return {
        "accepted": bool(authority.get("accepted", false)) and not authored.is_empty(),
        "reason_id": (
            StringName(authority.get("reason_id", &""))
            if not bool(authority.get("accepted", false))
            else (&"" if not authored.is_empty() else &"production_escort_authoring_unavailable")
        ),
        "production_ready": bool(authority.get("production_ready", false)) and not authored.is_empty(),
        "content_status": PRODUCTION_V01_CONTENT_STATUS if not authored.is_empty() else &"unavailable",
        "placeholder_config_available": false,
        "known_placeholder_config": {},
        "production_config_available": not authored.is_empty(),
        "production_config": (
            (authored.get("objective_config", {}) as Dictionary).duplicate(true)
            if not authored.is_empty()
            else {}
        ),
        "quest_missing_authoritative_fields": (
            authority.get("quest_missing_authoritative_fields", PackedStringArray()) as PackedStringArray
        ).duplicate(),
        "external_runtime_missing_authoritative_fields": (
            authority.get("external_runtime_missing_authoritative_fields", PackedStringArray()) as PackedStringArray
        ).duplicate(),
    }


static func build(floor_state: FloorInstanceState, quest_id: StringName) -> Dictionary:
    if floor_state == null or not FloorInstanceState.validate_dictionary(floor_state.to_dictionary()).is_empty():
        return {}
    var definition := QuestCatalog.get_definition(quest_id)
    if definition == null or definition.family != QuestDefinition.FAMILY_ESCORT:
        return {}
    if definition.floor_id != floor_state.floor_id:
        return {}
    var manifest := floor_state.layout_manifest
    if manifest.is_empty():
        return {}
    var bindings_variant: Variant = manifest.get("objective_bindings", null)
    if not bindings_variant is Dictionary:
        return {}
    var bindings := bindings_variant as Dictionary
    if not bindings.has(String(quest_id)):
        return {}
    var entrance_id := StringName(String(manifest.get("entrance_room_id", &"")))
    var goal_room_id := StringName(String(bindings[String(quest_id)]))
    if not StableId.is_valid(String(entrance_id)) or not StableId.is_valid(String(goal_room_id)):
        return {}

    var rooms := _rooms_by_id(manifest.get("rooms", []) as Array)
    if not rooms.has(entrance_id) or not rooms.has(goal_room_id):
        return {}
    var goal_room := rooms[goal_room_id] as Dictionary
    if not (goal_room.get("tags", []) as Array).has(TowerFloorLayoutManifestValidator.TAG_ESCORT_ROUTE):
        return {}

    var path := _room_path(entrance_id, goal_room_id, manifest.get("edges", []) as Array)
    if path.is_empty():
        return {}
    var waypoints := _waypoints_for_path(path, rooms, manifest.get("edges", []) as Array, quest_id)
    if waypoints.is_empty():
        return {}
    var route_node_ids: Array[StringName] = []
    for waypoint: Dictionary in waypoints:
        route_node_ids.append(StringName(String(waypoint.get("route_node_id", &""))))
    var actor_id := StringName("npc:%s_escort_v01" % _component(quest_id))
    var goal_id := StringName("goal:%s_objective_v01" % _component(quest_id))
    var retry_id := StringName("retry:%s_entrance_v01" % _component(quest_id))
    if not StableId.is_valid(String(actor_id)) or not StableId.is_valid(String(goal_id)) or not StableId.is_valid(String(retry_id)):
        return {}

    var config := {
        "actor_id": actor_id,
        "route_node_ids": route_node_ids,
        "goal_id": goal_id,
        "safe_retry_origin_id": retry_id,
        "failure_policy_id": FAILURE_POLICY_ACTOR_DEFEAT,
    }
    var state := EscortObjectiveState.new()
    if not state.configure(actor_id, route_node_ids, goal_id, retry_id, FAILURE_POLICY_ACTOR_DEFEAT):
        return {}
    return {
        "quest_id": quest_id,
        "floor_id": floor_state.floor_id,
        "content_status": CONTENT_STATUS,
        "objective_config": config,
        "waypoints": waypoints,
        "spawn_world_tile": (waypoints[0] as Dictionary).get("world_tile", Vector2i.ZERO),
        "safe_retry_world_tile": (waypoints[0] as Dictionary).get("world_tile", Vector2i.ZERO),
        "goal_world_tile": (waypoints[-1] as Dictionary).get("world_tile", Vector2i.ZERO),
        "room_path": path,
    }


static func _rooms_by_id(raw_rooms: Array) -> Dictionary:
    var result: Dictionary = {}
    for raw_room: Variant in raw_rooms:
        if not raw_room is Dictionary:
            continue
        var room := raw_room as Dictionary
        var room_id := StringName(String(room.get("room_instance_id", &"")))
        if StableId.is_valid(String(room_id)):
            result[room_id] = room
    return result


static func _room_path(start_id: StringName, goal_id: StringName, edges: Array) -> Array[StringName]:
    var graph: Dictionary = {}
    for raw_edge: Variant in edges:
        if not raw_edge is Dictionary:
            continue
        var edge := raw_edge as Dictionary
        var from_id := StringName(String(edge.get("from_room_id", &"")))
        var to_id := StringName(String(edge.get("to_room_id", &"")))
        if not StableId.is_valid(String(from_id)) or not StableId.is_valid(String(to_id)):
            continue
        var from_neighbors: Array = graph.get(from_id, []) as Array
        if not from_neighbors.has(to_id):
            from_neighbors.append(to_id)
        graph[from_id] = from_neighbors
        var to_neighbors: Array = graph.get(to_id, []) as Array
        if not to_neighbors.has(from_id):
            to_neighbors.append(from_id)
        graph[to_id] = to_neighbors
    var queue: Array[StringName] = [start_id]
    var previous: Dictionary = {start_id: &""}
    while not queue.is_empty():
        var current: StringName = queue.pop_front()
        if current == goal_id:
            break
        var neighbors := (graph.get(current, []) as Array).duplicate()
        neighbors.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
        for raw_neighbor: Variant in neighbors:
            var neighbor := StringName(String(raw_neighbor))
            if previous.has(neighbor):
                continue
            previous[neighbor] = current
            queue.append(neighbor)
    if not previous.has(goal_id):
        return []
    var reversed: Array[StringName] = []
    var cursor := goal_id
    while cursor != &"":
        reversed.append(cursor)
        cursor = StringName(String(previous.get(cursor, &"")))
    reversed.reverse()
    return reversed


static func _waypoints_for_path(path: Array[StringName], rooms: Dictionary, edges: Array, quest_id: StringName) -> Array[Dictionary]:
    var tiles: Array[Vector2i] = []
    if path.is_empty():
        return []
    _append_unique_tile(tiles, _room_arrival_tile(rooms[path[0]] as Dictionary))
    for index: int in range(path.size() - 1):
        var edge := _find_edge(path[index], path[index + 1], edges)
        if edge.is_empty():
            return []
        var forward := StringName(String(edge.get("from_room_id", &""))) == path[index]
        var route_tiles := _vector2i_array(edge.get("route_tiles", []) as Array)
        if not forward:
            route_tiles.reverse()
        for tile: Vector2i in route_tiles:
            _append_unique_tile(tiles, tile)
        _append_unique_tile(tiles, _room_arrival_tile(rooms[path[index + 1]] as Dictionary))
    var result: Array[Dictionary] = []
    for index: int in range(tiles.size()):
        result.append({
            "route_node_id": StringName("route:%s:%03d" % [_component(quest_id), index]),
            "world_tile": tiles[index],
        })
    return result


static func _room_arrival_tile(room: Dictionary) -> Vector2i:
    var rect_variant: Variant = room.get("rect", null)
    if not rect_variant is Rect2i:
        return Vector2i(-1, -1)
    var rect := rect_variant as Rect2i
    var module_id := StringName(String(room.get("module_id", &"")))
    var module := TowerPrototypeModuleCatalog.get_definition(module_id)
    if module != null and not module.arrival_candidates.is_empty():
        return rect.position + module.arrival_candidates[0]
    return rect.position + Vector2i(rect.size.x / 2, rect.size.y / 2)


static func _find_edge(left: StringName, right: StringName, edges: Array) -> Dictionary:
    for raw_edge: Variant in edges:
        if not raw_edge is Dictionary:
            continue
        var edge := raw_edge as Dictionary
        var from_id := StringName(String(edge.get("from_room_id", &"")))
        var to_id := StringName(String(edge.get("to_room_id", &"")))
        if (from_id == left and to_id == right) or (from_id == right and to_id == left):
            return edge
    return {}


static func _vector2i_array(raw: Array) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for value: Variant in raw:
        if value is Vector2i:
            result.append(value as Vector2i)
    return result


static func _append_unique_tile(target: Array[Vector2i], tile: Vector2i) -> void:
    if tile.x < 0 or tile.y < 0:
        return
    if target.is_empty() or target[-1] != tile:
        target.append(tile)


static func _component(value: StringName) -> String:
    return String(value).replace(":", "_").replace("/", "_").replace(".", "_").replace("-", "_")
