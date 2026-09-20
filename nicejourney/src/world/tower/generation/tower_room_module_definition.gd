class_name TowerRoomModuleDefinition
extends Resource

const FACINGS: Array[StringName] = [&"north", &"south", &"east", &"west"]

@export var module_id: StringName = &""
@export var footprint_size: Vector2i = Vector2i.ZERO
@export var visual_room_type: StringName = &""
@export var allowed_transforms: Array[StringName] = [&"identity"]
@export var connectors: Dictionary = {}
@export var walkable_rects: Array[Rect2i] = []
@export var collision_rects: Array[Rect2i] = []
@export var actor_clearance_size: Vector2i = Vector2i.ONE
@export_range(0, 16, 1) var objective_socket_capacity: int = 0
@export_range(0, 16, 1) var elite_capacity: int = 0
@export var spawn_regions: Array[Rect2i] = []
@export var hazard_exclusion_regions: Array[Rect2i] = []
@export var arrival_candidates: Array[Vector2i] = []
@export var supported_state_variants: Array[StringName] = [&"default"]

func validate_definition() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(module_id)):
        errors.append("module_id must be a stable ID")
    if footprint_size.x <= 0 or footprint_size.y <= 0 or footprint_size.x > TowerFloorLayoutManifestValidator.MAX_FOOTPRINT_TILES or footprint_size.y > TowerFloorLayoutManifestValidator.MAX_FOOTPRINT_TILES:
        errors.append("footprint_size must be positive and no larger than 50x50")
        return errors
    if not TowerRoomVisualProfile.ROOM_TYPES.has(visual_room_type):
        errors.append("visual_room_type must map to one of the eight tower presentation categories")
    if allowed_transforms.is_empty():
        errors.append("allowed_transforms must not be empty")
    else:
        var seen_transforms: Dictionary = {}
        for transform_id: StringName in allowed_transforms:
            if not StableId.is_valid(String(transform_id)):
                errors.append("allowed_transforms require stable IDs")
            if seen_transforms.has(transform_id):
                errors.append("allowed_transforms must be unique")
            seen_transforms[transform_id] = true
        if not seen_transforms.has(&"identity"):
            errors.append("allowed_transforms must include identity")
    if actor_clearance_size.x <= 0 or actor_clearance_size.y <= 0 or actor_clearance_size.x > footprint_size.x or actor_clearance_size.y > footprint_size.y:
        errors.append("actor_clearance_size must fit inside the module footprint")
    if connectors.is_empty():
        errors.append("connectors must declare at least one authored connector")
    else:
        for raw_id: Variant in connectors.keys():
            var connector_id := String(raw_id)
            if not StableId.is_valid(connector_id):
                errors.append("connector IDs must be stable")
                continue
            var raw_connector: Variant = connectors[raw_id]
            if not raw_connector is Dictionary:
                errors.append("connector %s must be a dictionary" % connector_id)
                continue
            var connector := raw_connector as Dictionary
            if not connector.get("tile", null) is Vector2i or not _point_in_footprint(connector["tile"] as Vector2i):
                errors.append("connector %s tile must lie inside the footprint" % connector_id)
            else:
                var connector_tile := connector["tile"] as Vector2i
                for collision_rect: Rect2i in collision_rects:
                    if collision_rect.has_point(connector_tile):
                        errors.append("connector %s cannot be blocked by authored collision" % connector_id)
            var facing := StringName(String(connector.get("facing", &"")))
            if not FACINGS.has(facing):
                errors.append("connector %s facing must be north/south/east/west" % connector_id)
            if typeof(connector.get("one_way", null)) != TYPE_BOOL:
                errors.append("connector %s one_way must be boolean" % connector_id)
    if walkable_rects.is_empty():
        errors.append("walkable_rects must not be empty")
    _validate_rects(walkable_rects, "walkable_rects", errors)
    _validate_rects(collision_rects, "collision_rects", errors)
    _validate_rects(spawn_regions, "spawn_regions", errors)
    _validate_rects(hazard_exclusion_regions, "hazard_exclusion_regions", errors)
    if arrival_candidates.is_empty():
        errors.append("arrival_candidates must not be empty")
    else:
        for candidate: Vector2i in arrival_candidates:
            if not _point_in_footprint(candidate):
                errors.append("arrival_candidates must lie inside the footprint")
                continue
            var on_walkable := false
            for walkable_rect: Rect2i in walkable_rects:
                if walkable_rect.has_point(candidate):
                    on_walkable = true
                    break
            if not on_walkable:
                errors.append("arrival_candidates must lie on authored walkable space")
    if supported_state_variants.is_empty():
        errors.append("supported_state_variants must not be empty")
    else:
        var seen: Dictionary = {}
        for variant_id: StringName in supported_state_variants:
            if not StableId.is_valid(String(variant_id)):
                errors.append("supported_state_variants require stable IDs")
            if seen.has(variant_id):
                errors.append("supported_state_variants must be unique")
            seen[variant_id] = true
        if not seen.has(&"default"):
            errors.append("supported_state_variants must include default")
    return errors

func _validate_rects(rects: Array[Rect2i], label: String, errors: PackedStringArray) -> void:
    for rect: Rect2i in rects:
        if rect.size.x <= 0 or rect.size.y <= 0:
            errors.append("%s entries must have positive size" % label)
            continue
        if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > footprint_size.x or rect.end.y > footprint_size.y:
            errors.append("%s entries must remain inside the footprint" % label)

func _point_in_footprint(point: Vector2i) -> bool:
    return point.x >= 0 and point.y >= 0 and point.x < footprint_size.x and point.y < footprint_size.y
