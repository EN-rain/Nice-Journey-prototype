class_name Region3QuestMarkerAnchorDefinition
extends Resource

@export var anchor_id: StringName = &""
@export var zone_id: StringName = &""
@export var structure_id: StringName = &""
@export var exact_tile_authored: bool = false
@export var tile: Vector2i = Vector2i(-1, -1)


func validate_definition(known_zone_ids: Dictionary, known_structure_ids: Dictionary = {}) -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(anchor_id)):
        errors.append("anchor_id must be a stable ID")
    if not StableId.is_valid(String(zone_id)):
        errors.append("zone_id must be a stable ID")
    elif not known_zone_ids.has(zone_id):
        errors.append("zone_id must reference an authored Region 3 zone")
    if structure_id != &"":
        if not StableId.is_valid(String(structure_id)):
            errors.append("structure_id must be empty or a stable ID")
        elif not known_structure_ids.is_empty() and not known_structure_ids.has(structure_id):
            errors.append("structure_id must reference an authored Region 3 structure")
    if exact_tile_authored:
        if tile.x < 0 or tile.y < 0:
            errors.append("authored exact tile must be non-negative")
    elif tile != Vector2i(-1, -1):
        errors.append("tile must remain unset until an exact quest-marker tile is authored")
    return errors
