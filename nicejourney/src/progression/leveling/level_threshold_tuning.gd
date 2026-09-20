class_name LevelThresholdTuning
extends Resource

const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 10
const TRANSITION_COUNT: int = MAX_LEVEL - MIN_LEVEL

@export var xp_to_next_by_level: PackedInt32Array = PackedInt32Array([
    100,
    200,
    300,
    400,
    500,
    600,
    700,
    800,
    900,
])


func validate_tuning() -> PackedStringArray:
    var errors := PackedStringArray()
    if xp_to_next_by_level.size() != TRANSITION_COUNT:
        errors.append("xp_to_next_by_level must contain exactly nine Level 1-9 transition thresholds")
        return errors
    for index: int in range(xp_to_next_by_level.size()):
        if xp_to_next_by_level[index] <= 0:
            errors.append("xp_to_next_by_level[%d] must be positive" % index)
    return errors


func xp_required_to_next(level: int) -> int:
    if level < MIN_LEVEL or level >= MAX_LEVEL or not validate_tuning().is_empty():
        return 0
    return xp_to_next_by_level[level - MIN_LEVEL]


func cumulative_xp_required_for_level(level: int) -> int:
    if level < MIN_LEVEL or level > MAX_LEVEL or not validate_tuning().is_empty():
        return -1
    var total := 0
    for transition_level: int in range(MIN_LEVEL, level):
        total += xp_required_to_next(transition_level)
    return total


func total_xp_to_cap() -> int:
    return cumulative_xp_required_for_level(MAX_LEVEL)


func threshold_entries() -> Array[Dictionary]:
    if not validate_tuning().is_empty():
        return []
    var entries: Array[Dictionary] = []
    for level: int in range(MIN_LEVEL, MAX_LEVEL):
        entries.append({
            "from_level": level,
            "to_level": level + 1,
            "xp_required": xp_required_to_next(level),
            "cumulative_xp_at_from_level": cumulative_xp_required_for_level(level),
            "cumulative_xp_at_to_level": cumulative_xp_required_for_level(level + 1),
        })
    return entries
