class_name Region3WorldZoneDefinition
extends Resource

@export var zone_id: StringName = &""
@export var tile_rect: Rect2i = Rect2i()
@export var safe_zone: bool = false
@export var travel_destination: bool = true
@export var recommended_level_min: int = -1
@export var recommended_level_max: int = -1
# Exact, Inspector-authored PLAYTEST recommendation; -1 leaves the level unauthored.
@export var recommended_level: int = -1


func validate_definition(map_size_tiles: Vector2i) -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(zone_id)):
        errors.append("zone_id must be a stable ID")
    if tile_rect.size.x <= 0 or tile_rect.size.y <= 0:
        errors.append("tile_rect must describe a positive rectangle")
    else:
        var end := tile_rect.position + tile_rect.size
        if tile_rect.position.x < 0 or tile_rect.position.y < 0 or end.x > map_size_tiles.x or end.y > map_size_tiles.y:
            errors.append("tile_rect must remain inside the authored Region 3 map")
    if safe_zone:
        if recommended_level_min != -1 or recommended_level_max != -1 or recommended_level != -1:
            errors.append("safe zones must not publish a hostile Recommended Level")
    elif travel_destination:
        if recommended_level_min < 1 or recommended_level_max < recommended_level_min:
            errors.append("hostile travel zones require a positive authored Recommended Level band")
        if recommended_level != -1 and (recommended_level < recommended_level_min or recommended_level > recommended_level_max):
            errors.append("exact Recommended Level must belong to its authored PLAYTEST band")
    elif recommended_level != -1:
        errors.append("non-travel zones must not publish a hostile Recommended Level")
    return errors


func has_concrete_recommended_level() -> bool:
    return (
        not safe_zone
        and travel_destination
        and recommended_level_min > 0
        and recommended_level >= recommended_level_min
        and recommended_level <= recommended_level_max
    )
