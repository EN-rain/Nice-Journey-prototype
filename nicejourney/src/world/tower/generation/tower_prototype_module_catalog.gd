class_name TowerPrototypeModuleCatalog
extends RefCounted

static func all_definitions() -> Array[TowerRoomModuleDefinition]:
    return [
        _module(&"module:entrance_safe_v01", Vector2i(6, 6), &"safe", 0, 0, false),
        _module(&"module:annihilation_objective_v01", Vector2i(10, 10), &"combat", 1, 0, true),
        _module(&"module:escort_objective_v01", Vector2i(10, 10), &"objective", 1, 0, true),
        _module(&"module:tower_defense_objective_v01", Vector2i(10, 10), &"objective", 1, 0, true),
        _module(&"module:elite_gate_v01", Vector2i(10, 10), &"elite", 1, 3, true),
        _module(&"module:preboss_safe_v01", Vector2i(6, 6), &"safe", 0, 0, false),
        _module(&"module:boss_sanctum_v01", Vector2i(14, 14), &"boss", 1, 0, true),
        _module(&"module:exit_v01", Vector2i(6, 6), &"safe", 0, 0, false),
    ]

static func get_definition(module_id: StringName) -> TowerRoomModuleDefinition:
    for definition: TowerRoomModuleDefinition in all_definitions():
        if definition.module_id == module_id:
            return definition
    return null

static func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    var definitions := all_definitions()
    var seen: Dictionary = {}
    for index: int in range(definitions.size()):
        var definition := definitions[index]
        for definition_error: String in definition.validate_definition():
            errors.append("module[%d] %s: %s" % [index, String(definition.module_id), definition_error])
        if seen.has(definition.module_id):
            errors.append("duplicate module_id %s" % String(definition.module_id))
        seen[definition.module_id] = true
    return errors

static func validate_manifest_modules(raw_manifest: Variant) -> PackedStringArray:
    var errors := validate_catalog()
    if not raw_manifest is Dictionary:
        errors.append("manifest must be a dictionary")
        return errors
    var manifest := raw_manifest as Dictionary
    if not manifest.get("rooms", null) is Array:
        errors.append("manifest rooms must be an array")
        return errors
    for raw_room: Variant in manifest["rooms"] as Array:
        if not raw_room is Dictionary:
            errors.append("manifest room must be a dictionary")
            continue
        var room := raw_room as Dictionary
        var module_id := StringName(String(room.get("module_id", &"")))
        var definition := get_definition(module_id)
        if definition == null:
            errors.append("manifest references unknown module_id %s" % String(module_id))
            continue
        var transform_id := StringName(String(room.get("transform_id", &"identity")))
        if not definition.allowed_transforms.has(transform_id):
            errors.append("room using %s declares unsupported transform %s" % [String(module_id), String(transform_id)])
        var rect_variant: Variant = room.get("rect", null)
        if not rect_variant is Rect2i:
            errors.append("room using %s must declare a Rect2i" % String(module_id))
            continue
        var rect := rect_variant as Rect2i
        if rect.size != definition.footprint_size:
            errors.append("room using %s must preserve authored module footprint %s" % [String(module_id), str(definition.footprint_size)])
        if int(room.get("objective_socket_capacity", -1)) != definition.objective_socket_capacity:
            errors.append("room using %s must preserve authored objective socket capacity" % String(module_id))
        if int(room.get("elite_capacity", -1)) != definition.elite_capacity:
            errors.append("room using %s must preserve authored elite capacity" % String(module_id))
    return errors

static func _module(
    module_id: StringName,
    size: Vector2i,
    visual_room_type: StringName,
    objective_socket_capacity: int,
    elite_capacity: int,
    combat_capable: bool
) -> TowerRoomModuleDefinition:
    var definition := TowerRoomModuleDefinition.new()
    definition.module_id = module_id
    definition.footprint_size = size
    definition.visual_room_type = visual_room_type
    definition.connectors = _four_connectors(size)
    definition.walkable_rects = [Rect2i(Vector2i.ONE, size - Vector2i(2, 2))]
    definition.collision_rects = _border_collision(size)
    definition.actor_clearance_size = Vector2i(2, 2)
    definition.objective_socket_capacity = objective_socket_capacity
    definition.elite_capacity = elite_capacity
    if combat_capable:
        definition.spawn_regions = [Rect2i(Vector2i(2, 2), size - Vector2i(4, 4))]
    else:
        definition.spawn_regions = []
    definition.hazard_exclusion_regions = [Rect2i(Vector2i.ONE, Vector2i(2, 2))]
    definition.arrival_candidates = [Vector2i(size.x / 2, size.y / 2)]
    definition.supported_state_variants = [&"default"]
    return definition

static func _four_connectors(size: Vector2i) -> Dictionary:
    return {
        "north": {"tile": Vector2i(size.x / 2, 0), "facing": &"north", "one_way": false},
        "south": {"tile": Vector2i(size.x / 2, size.y - 1), "facing": &"south", "one_way": false},
        "west": {"tile": Vector2i(0, size.y / 2), "facing": &"west", "one_way": false},
        "east": {"tile": Vector2i(size.x - 1, size.y / 2), "facing": &"east", "one_way": false},
    }

static func _border_collision(size: Vector2i) -> Array[Rect2i]:
    var result: Array[Rect2i] = []
    var mid_x := size.x / 2
    var mid_y := size.y / 2
    _append_positive_rect(result, Rect2i(0, 0, mid_x, 1))
    _append_positive_rect(result, Rect2i(mid_x + 1, 0, size.x - mid_x - 1, 1))
    _append_positive_rect(result, Rect2i(0, size.y - 1, mid_x, 1))
    _append_positive_rect(result, Rect2i(mid_x + 1, size.y - 1, size.x - mid_x - 1, 1))
    _append_positive_rect(result, Rect2i(0, 1, 1, mid_y - 1))
    _append_positive_rect(result, Rect2i(0, mid_y + 1, 1, size.y - mid_y - 2))
    _append_positive_rect(result, Rect2i(size.x - 1, 1, 1, mid_y - 1))
    _append_positive_rect(result, Rect2i(size.x - 1, mid_y + 1, 1, size.y - mid_y - 2))
    return result

static func _append_positive_rect(target: Array[Rect2i], rect: Rect2i) -> void:
    if rect.size.x > 0 and rect.size.y > 0:
        target.append(rect)
