class_name TowerPrevalidatedFallbackFactory
extends RefCounted

const LAYOUT_REVISION_PREFIX := "fallback:prototype_v01:floor_"

static func build_for_request(raw_request: Variant) -> Dictionary:
    if not TowerFloorGenerationCommitService.validate_request(raw_request).is_empty():
        return {}
    var request := raw_request as Dictionary
    var floor_id := int(request["floor_id"])
    var rooms: Array[Dictionary] = []
    var edges: Array[Dictionary] = []
    var bindings: Dictionary = {}

    var entrance := _room(
        &"room:entrance",
        &"module:entrance_safe_v01",
        Rect2i(2, 20, 6, 6),
        [TowerFloorLayoutManifestValidator.TAG_ENTRANCE, TowerFloorLayoutManifestValidator.TAG_SAFE],
        0,
        0,
        true
    )
    rooms.append(entrance)

    if floor_id == 10:
        _build_floor10(request, rooms, edges, bindings)
    else:
        _build_standard_floor(request, rooms, edges, bindings)

    var manifest := {
        "floor_id": floor_id,
        "generation_seed": int(request["generation_seed"]),
        "generator_version": StringName(String(request["generator_version"])),
        "module_content_version": StringName(String(request["module_content_version"])),
        "encounter_config_id": StringName(String(request["encounter_config_id"])),
        "quest_world_flags_signature": StringName(String(request["quest_world_flags_signature"])),
        "layout_revision_id": StringName("%s%d" % [LAYOUT_REVISION_PREFIX, floor_id]),
        "reserved_quest_ids": (request["required_quest_ids"] as Array).duplicate(true),
        "entrance_room_id": &"room:entrance",
        "exit_room_id": &"room:exit",
        "rooms": rooms,
        "edges": edges,
        "objective_bindings": bindings,
    }
    if not TowerFloorLayoutManifestValidator.validate_manifest(manifest, request).is_empty():
        return {}
    if not TowerPrototypeModuleCatalog.validate_manifest_modules(manifest).is_empty():
        return {}
    if not TowerFloorTraversalManifestValidator.validate_manifest(manifest).is_empty():
        return {}
    return manifest

static func _build_standard_floor(request: Dictionary, rooms: Array[Dictionary], edges: Array[Dictionary], bindings: Dictionary) -> void:
    var floor_id := int(request["floor_id"])
    var required: Array = request["required_quest_ids"] as Array
    var objective_rooms: Array[StringName] = []
    var x := 12
    for index: int in range(required.size()):
        var quest_id := StringName(String(required[index]))
        var definition := QuestCatalog.get_definition(quest_id)
        if definition == null:
            continue
        var room_id := StringName("room:objective_%02d" % index)
        var tags := _tags_for_family(definition.family)
        if floor_id == 5 and index == 0:
            if not tags.has(TowerFloorLayoutManifestValidator.TAG_ELITE):
                tags.append(TowerFloorLayoutManifestValidator.TAG_ELITE)
        var elite_capacity := 3 if floor_id == 5 and index == 0 else 0
        var module_id := StringName("module:%s_objective_v01" % String(definition.family))
        if floor_id == 5 and index == 0:
            module_id = &"module:elite_gate_v01"
        rooms.append(_room(
            room_id,
            module_id,
            Rect2i(x, 18, 10, 10),
            tags,
            1,
            elite_capacity,
            false
        ))
        bindings[String(quest_id)] = room_id
        objective_rooms.append(room_id)
        x += 14

    rooms.append(_room(
        &"room:exit",
        &"module:exit_v01",
        Rect2i(42, 20, 6, 6),
        [TowerFloorLayoutManifestValidator.TAG_EXIT],
        0,
        0,
        true
    ))

    var previous: StringName = &"room:entrance"
    for room_id: StringName in objective_rooms:
        edges.append(_edge(previous, room_id, rooms))
        previous = room_id
    edges.append(_edge(previous, &"room:exit", rooms))

static func _build_floor10(request: Dictionary, rooms: Array[Dictionary], edges: Array[Dictionary], bindings: Dictionary) -> void:
    rooms.append(_room(
        &"room:elite_gate",
        &"module:elite_gate_v01",
        Rect2i(10, 18, 10, 10),
        [TowerFloorLayoutManifestValidator.TAG_COMBAT, TowerFloorLayoutManifestValidator.TAG_ELITE],
        1,
        3,
        false
    ))
    rooms.append(_room(
        &"room:preboss_safe",
        &"module:preboss_safe_v01",
        Rect2i(24, 20, 6, 6),
        [TowerFloorLayoutManifestValidator.TAG_SAFE],
        0,
        0,
        true
    ))
    rooms.append(_room(
        &"room:boss",
        &"module:boss_sanctum_v01",
        Rect2i(34, 14, 14, 14),
        [TowerFloorLayoutManifestValidator.TAG_BOSS, TowerFloorLayoutManifestValidator.TAG_COMBAT, TowerFloorLayoutManifestValidator.TAG_OBJECTIVE],
        1,
        0,
        false
    ))
    rooms.append(_room(
        &"room:exit",
        &"module:exit_v01",
        Rect2i(40, 34, 6, 6),
        [TowerFloorLayoutManifestValidator.TAG_EXIT],
        0,
        0,
        true
    ))
    var required: Array = request["required_quest_ids"] as Array
    for raw_quest_id: Variant in required:
        bindings[String(raw_quest_id)] = &"room:boss"
    edges.append(_edge(&"room:entrance", &"room:elite_gate", rooms))
    edges.append(_edge(&"room:elite_gate", &"room:preboss_safe", rooms))
    edges.append(_edge(&"room:preboss_safe", &"room:boss", rooms))
    edges.append(_edge(&"room:boss", &"room:exit", rooms))

static func _tags_for_family(family: StringName) -> Array[StringName]:
    match family:
        QuestDefinition.FAMILY_ESCORT:
            return [TowerFloorLayoutManifestValidator.TAG_OBJECTIVE, TowerFloorLayoutManifestValidator.TAG_ESCORT_ROUTE]
        QuestDefinition.FAMILY_TOWER_DEFENSE:
            return [TowerFloorLayoutManifestValidator.TAG_OBJECTIVE, TowerFloorLayoutManifestValidator.TAG_DEFENSE_ARENA, TowerFloorLayoutManifestValidator.TAG_COMBAT]
        _:
            return [TowerFloorLayoutManifestValidator.TAG_OBJECTIVE, TowerFloorLayoutManifestValidator.TAG_COMBAT]

static func _room(
    room_instance_id: StringName,
    module_id: StringName,
    rect: Rect2i,
    tags: Array[StringName],
    objective_socket_capacity: int,
    elite_capacity: int,
    safe_arrival: bool
) -> Dictionary:
    return {
        "room_instance_id": room_instance_id,
        "module_id": module_id,
        "rect": rect,
        "transform_id": &"identity",
        "tags": tags.duplicate(),
        "objective_socket_capacity": objective_socket_capacity,
        "elite_capacity": elite_capacity,
        "safe_arrival": safe_arrival,
    }

static func _edge(from_room_id: StringName, to_room_id: StringName, rooms: Array[Dictionary]) -> Dictionary:
    var from_room := _find_room(rooms, from_room_id)
    var to_room := _find_room(rooms, to_room_id)
    if from_room.is_empty() or to_room.is_empty():
        return {"from_room_id": from_room_id, "to_room_id": to_room_id}
    var from_definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(from_room["module_id"])))
    var to_definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(to_room["module_id"])))
    if from_definition == null or to_definition == null:
        return {"from_room_id": from_room_id, "to_room_id": to_room_id}

    var connector_pair := _select_connector_pair(from_room, from_definition, to_room, to_definition)
    if connector_pair.is_empty():
        return {"from_room_id": from_room_id, "to_room_id": to_room_id}
    var from_connector_id := StringName(String(connector_pair["from_connector_id"]))
    var to_connector_id := StringName(String(connector_pair["to_connector_id"]))
    var from_connector := from_definition.connectors[String(from_connector_id)] as Dictionary
    var to_connector := to_definition.connectors[String(to_connector_id)] as Dictionary
    var from_world := (from_room["rect"] as Rect2i).position + (from_connector["tile"] as Vector2i)
    var to_world := (to_room["rect"] as Rect2i).position + (to_connector["tile"] as Vector2i)
    var from_outward := _facing_vector(StringName(String(from_connector["facing"])))
    var to_outward := _facing_vector(StringName(String(to_connector["facing"])))
    var route := _route_between_connectors(from_world, from_outward, to_world, to_outward, rooms, from_room_id, to_room_id)
    return {
        "from_room_id": from_room_id,
        "to_room_id": to_room_id,
        "from_connector_id": from_connector_id,
        "to_connector_id": to_connector_id,
        "route_width_tiles": 2,
        "route_tiles": route,
    }

static func _select_connector_pair(
    from_room: Dictionary,
    from_definition: TowerRoomModuleDefinition,
    to_room: Dictionary,
    to_definition: TowerRoomModuleDefinition
) -> Dictionary:
    var from_rect := from_room["rect"] as Rect2i
    var to_rect := to_room["rect"] as Rect2i
    var from_center := Vector2(from_rect.position) + Vector2(from_rect.size) * 0.5
    var to_center := Vector2(to_rect.position) + Vector2(to_rect.size) * 0.5
    var delta := to_center - from_center
    var from_id: StringName
    var to_id: StringName
    if absf(delta.x) >= absf(delta.y):
        from_id = &"east" if delta.x >= 0.0 else &"west"
        to_id = &"west" if delta.x >= 0.0 else &"east"
    else:
        from_id = &"south" if delta.y >= 0.0 else &"north"
        to_id = &"north" if delta.y >= 0.0 else &"south"
    if not from_definition.connectors.has(String(from_id)) or not to_definition.connectors.has(String(to_id)):
        return {}
    return {"from_connector_id": from_id, "to_connector_id": to_id}

static func _route_between_connectors(
    from_world: Vector2i,
    from_outward: Vector2i,
    to_world: Vector2i,
    to_outward: Vector2i,
    rooms: Array[Dictionary],
    from_room_id: StringName,
    to_room_id: StringName
) -> Array[Vector2i]:
    var start_outer := from_world + from_outward
    var end_outer := to_world + to_outward
    for horizontal_first: bool in [true, false]:
        var middle := _manhattan_path(start_outer, end_outer, horizontal_first)
        var route: Array[Vector2i] = [from_world]
        for tile: Vector2i in middle:
            if route.is_empty() or route[route.size() - 1] != tile:
                route.append(tile)
        if route.is_empty() or route[route.size() - 1] != to_world:
            route.append(to_world)
        if _route_avoids_room_interiors(route, rooms, from_room_id, to_room_id):
            return route
    return []

static func _manhattan_path(start: Vector2i, finish: Vector2i, horizontal_first: bool) -> Array[Vector2i]:
    var result: Array[Vector2i] = [start]
    var cursor := start
    if horizontal_first:
        while cursor.x != finish.x:
            cursor.x += 1 if finish.x > cursor.x else -1
            result.append(cursor)
        while cursor.y != finish.y:
            cursor.y += 1 if finish.y > cursor.y else -1
            result.append(cursor)
    else:
        while cursor.y != finish.y:
            cursor.y += 1 if finish.y > cursor.y else -1
            result.append(cursor)
        while cursor.x != finish.x:
            cursor.x += 1 if finish.x > cursor.x else -1
            result.append(cursor)
    return result

static func _route_avoids_room_interiors(route: Array[Vector2i], rooms: Array[Dictionary], from_room_id: StringName, to_room_id: StringName) -> bool:
    for index: int in range(route.size()):
        var tile := route[index]
        for room: Dictionary in rooms:
            var room_id := StringName(String(room["room_instance_id"]))
            if not (room["rect"] as Rect2i).has_point(tile):
                continue
            if room_id == from_room_id and index == 0:
                continue
            if room_id == to_room_id and index == route.size() - 1:
                continue
            return false
    return true

static func _find_room(rooms: Array[Dictionary], room_id: StringName) -> Dictionary:
    for room: Dictionary in rooms:
        if StringName(String(room.get("room_instance_id", &""))) == room_id:
            return room
    return {}

static func _facing_vector(facing: StringName) -> Vector2i:
    match facing:
        &"north": return Vector2i.UP
        &"south": return Vector2i.DOWN
        &"west": return Vector2i.LEFT
        &"east": return Vector2i.RIGHT
        _: return Vector2i.ZERO
