class_name FacingResolver
extends RefCounted

static func resolve_horizontal_facing(
    current_facing: int,
    aim_direction: Vector2,
    vertical_dead_zone_ratio: float
) -> int:
    if aim_direction.length_squared() <= 0.000001:
        return current_facing
    var normalized_aim: Vector2 = aim_direction.normalized()
    if absf(normalized_aim.x) <= vertical_dead_zone_ratio:
        return current_facing
    return 1 if normalized_aim.x > 0.0 else -1
