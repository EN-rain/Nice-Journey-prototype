class_name TowerFloorTraversalManifestValidator
extends RefCounted

const MIN_ROUTE_WIDTH_TILES: int = 1
const MAX_ROUTE_WIDTH_TILES: int = 4

static func validate_manifest(raw_manifest: Variant) -> PackedStringArray:
    var errors := PackedStringArray()
    if not raw_manifest is Dictionary:
        errors.append("manifest must be a dictionary")
        return errors
    var manifest := raw_manifest as Dictionary
    for module_error: String in TowerPrototypeModuleCatalog.validate_manifest_modules(manifest):
        errors.append(module_error)
    if not errors.is_empty():
        return errors
    if not manifest.get("rooms", null) is Array or not manifest.get("edges", null) is Array:
        errors.append("manifest rooms/edges are required")
        return errors

    var room_by_id: Dictionary = {}
    for raw_room: Variant in manifest["rooms"] as Array:
        if not raw_room is Dictionary:
            continue
        var room := raw_room as Dictionary
        room_by_id[StringName(String(room.get("room_instance_id", &"")))] = room

    for index: int in range((manifest["edges"] as Array).size()):
        var raw_edge: Variant = (manifest["edges"] as Array)[index]
        if not raw_edge is Dictionary:
            errors.append("edge %d must be a dictionary" % index)
            continue
        var edge := raw_edge as Dictionary
        var from_id := StringName(String(edge.get("from_room_id", &"")))
        var to_id := StringName(String(edge.get("to_room_id", &"")))
        if not room_by_id.has(from_id) or not room_by_id.has(to_id):
            errors.append("edge %d must reference known rooms" % index)
            continue
        var from_room := room_by_id[from_id] as Dictionary
        var to_room := room_by_id[to_id] as Dictionary
        var from_definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(from_room["module_id"])))
        var to_definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(to_room["module_id"])))
        if from_definition == null or to_definition == null:
            errors.append("edge %d endpoint modules must resolve")
            continue

        var from_connector_id := StringName(String(edge.get("from_connector_id", &"")))
        var to_connector_id := StringName(String(edge.get("to_connector_id", &"")))
        if not from_definition.connectors.has(String(from_connector_id)):
            errors.append("edge %d from_connector_id must exist on the from module" % index)
            continue
        if not to_definition.connectors.has(String(to_connector_id)):
            errors.append("edge %d to_connector_id must exist on the to module" % index)
            continue
        var width_value: Variant = edge.get("route_width_tiles", null)
        if typeof(width_value) != TYPE_INT or int(width_value) < MIN_ROUTE_WIDTH_TILES or int(width_value) > MAX_ROUTE_WIDTH_TILES:
            errors.append("edge %d route_width_tiles must be an integer from 1 through 4" % index)
        else:
            var required_clearance := maxi(
                maxi(from_definition.actor_clearance_size.x, from_definition.actor_clearance_size.y),
                maxi(to_definition.actor_clearance_size.x, to_definition.actor_clearance_size.y)
            )
            if int(width_value) < required_clearance:
                errors.append("edge %d route width is smaller than endpoint actor clearance" % index)

        var route_value: Variant = edge.get("route_tiles", null)
        if not route_value is Array:
            errors.append("edge %d route_tiles must be an array" % index)
            continue
        var route: Array = route_value as Array
        if route.size() < 2:
            errors.append("edge %d route_tiles must contain at least two tiles" % index)
            continue
        var valid_route := true
        for route_index: int in range(route.size()):
            if not route[route_index] is Vector2i:
                errors.append("edge %d route_tiles[%d] must be Vector2i" % [index, route_index])
                valid_route = false
                continue
            var tile := route[route_index] as Vector2i
            if not _in_floor(tile):
                errors.append("edge %d route leaves the 50x50 footprint" % index)
                valid_route = false
            if route_index > 0 and route[route_index - 1] is Vector2i:
                var previous := route[route_index - 1] as Vector2i
                if absi(tile.x - previous.x) + absi(tile.y - previous.y) != 1:
                    errors.append("edge %d route_tiles must be Manhattan-contiguous" % index)
                    valid_route = false
        if not valid_route:
            continue

        var from_connector := from_definition.connectors[String(from_connector_id)] as Dictionary
        var to_connector := to_definition.connectors[String(to_connector_id)] as Dictionary
        var from_world := (from_room["rect"] as Rect2i).position + (from_connector["tile"] as Vector2i)
        var to_world := (to_room["rect"] as Rect2i).position + (to_connector["tile"] as Vector2i)
        if route[0] != from_world:
            errors.append("edge %d route must begin on the declared from connector" % index)
        if route[route.size() - 1] != to_world:
            errors.append("edge %d route must end on the declared to connector" % index)
        if route.size() >= 2:
            var from_outward := _facing_vector(StringName(String(from_connector["facing"])))
            if (route[1] as Vector2i) != from_world + from_outward:
                errors.append("edge %d route must leave the from connector in its authored facing" % index)
            var to_outward := _facing_vector(StringName(String(to_connector["facing"])))
            if (route[route.size() - 2] as Vector2i) != to_world + to_outward:
                errors.append("edge %d route must approach the to connector from outside its authored facing" % index)

        for route_index: int in range(route.size()):
            var tile := route[route_index] as Vector2i
            for raw_room_variant: Variant in manifest["rooms"] as Array:
                var candidate_room := raw_room_variant as Dictionary
                var candidate_id := StringName(String(candidate_room["room_instance_id"]))
                var candidate_rect := candidate_room["rect"] as Rect2i
                if not candidate_rect.has_point(tile):
                    continue
                var endpoint_allowed := (
                    (candidate_id == from_id and route_index == 0)
                    or (candidate_id == to_id and route_index == route.size() - 1)
                )
                if not endpoint_allowed:
                    errors.append("edge %d route crosses room %s outside its declared connector" % [index, String(candidate_id)])
                    break
    return errors

static func _facing_vector(facing: StringName) -> Vector2i:
    match facing:
        &"north": return Vector2i.UP
        &"south": return Vector2i.DOWN
        &"west": return Vector2i.LEFT
        &"east": return Vector2i.RIGHT
        _: return Vector2i.ZERO

static func _in_floor(tile: Vector2i) -> bool:
    return (
        tile.x >= 0
        and tile.y >= 0
        and tile.x < TowerFloorLayoutManifestValidator.MAX_FOOTPRINT_TILES
        and tile.y < TowerFloorLayoutManifestValidator.MAX_FOOTPRINT_TILES
    )
