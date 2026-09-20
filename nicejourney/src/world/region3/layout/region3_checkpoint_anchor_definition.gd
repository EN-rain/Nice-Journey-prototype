class_name Region3CheckpointAnchorDefinition
extends Resource

@export var checkpoint_id: StringName = &""
@export var zone_id: StringName = &""
@export var tile: Vector2i = Vector2i(-1, -1)


func validate_definition(map_size_tiles: Vector2i, known_zone_ids: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(checkpoint_id)):
        errors.append("checkpoint_id must be a stable ID")
    if not StableId.is_valid(String(zone_id)):
        errors.append("zone_id must be a stable ID")
    elif not known_zone_ids.has(zone_id):
        errors.append("zone_id must reference an authored Region 3 zone")
    if tile.x < 0 or tile.y < 0 or tile.x >= map_size_tiles.x or tile.y >= map_size_tiles.y:
        errors.append("checkpoint tile must be an exact authored tile inside Region 3")
    return errors
