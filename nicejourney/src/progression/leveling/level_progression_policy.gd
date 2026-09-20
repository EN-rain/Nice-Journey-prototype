class_name LevelProgressionPolicy
extends Resource

const XP_STORAGE_CUMULATIVE_TOTAL: StringName = &"cumulative_total"
const XP_STORAGE_LEVEL_PROGRESS: StringName = &"level_progress"
const CAP_OVERFLOW_DISCARD: StringName = &"discard"
const CAP_OVERFLOW_RETAIN: StringName = &"retain"

const SUPPORTED_XP_STORAGE: Array[StringName] = [
    XP_STORAGE_CUMULATIVE_TOTAL,
    XP_STORAGE_LEVEL_PROGRESS,
]
const SUPPORTED_CAP_OVERFLOW: Array[StringName] = [
    CAP_OVERFLOW_DISCARD,
    CAP_OVERFLOW_RETAIN,
]

@export var threshold_tuning: LevelThresholdTuning = null
@export var xp_storage_semantics: StringName = &""
@export var cap_overflow_behavior: StringName = &""
@export var skill_points_granted_by_transition: PackedInt32Array = PackedInt32Array()
@export var stat_growth_by_transition: Array[Dictionary] = []


func validate_policy() -> PackedStringArray:
    var errors := PackedStringArray()
    if threshold_tuning == null:
        errors.append("threshold_tuning must be authored")
    else:
        for threshold_error: String in threshold_tuning.validate_tuning():
            errors.append("threshold_tuning: %s" % threshold_error)

    if not SUPPORTED_XP_STORAGE.has(xp_storage_semantics):
        errors.append("xp_storage_semantics must be explicitly authored as a supported policy")
    if not SUPPORTED_CAP_OVERFLOW.has(cap_overflow_behavior):
        errors.append("cap_overflow_behavior must be explicitly authored as a supported policy")

    if skill_points_granted_by_transition.size() != LevelThresholdTuning.TRANSITION_COUNT:
        errors.append("skill_points_granted_by_transition must contain exactly nine Level 1-9 transition entries")
    else:
        for index: int in range(skill_points_granted_by_transition.size()):
            if skill_points_granted_by_transition[index] < 0:
                errors.append("skill_points_granted_by_transition[%d] cannot be negative" % index)

    if stat_growth_by_transition.size() != LevelThresholdTuning.TRANSITION_COUNT:
        errors.append("stat_growth_by_transition must contain exactly nine Level 1-9 transition entries")
    else:
        for index: int in range(stat_growth_by_transition.size()):
            _validate_stat_growth_entry(stat_growth_by_transition[index], index, errors)
    return errors


func skill_points_for_transition(from_level: int) -> int:
    if not validate_policy().is_empty() or from_level < LevelThresholdTuning.MIN_LEVEL or from_level >= LevelThresholdTuning.MAX_LEVEL:
        return -1
    return skill_points_granted_by_transition[from_level - LevelThresholdTuning.MIN_LEVEL]


func stat_growth_for_transition(from_level: int) -> Dictionary:
    if not validate_policy().is_empty() or from_level < LevelThresholdTuning.MIN_LEVEL or from_level >= LevelThresholdTuning.MAX_LEVEL:
        return {}
    return stat_growth_by_transition[from_level - LevelThresholdTuning.MIN_LEVEL].duplicate(true)


func required_stat_ids() -> Array[StringName]:
    if not validate_policy().is_empty():
        return []
    var seen: Dictionary = {}
    for entry: Dictionary in stat_growth_by_transition:
        for raw_stat_id: Variant in entry.keys():
            seen[String(raw_stat_id)] = true
    var names: Array = seen.keys()
    names.sort()
    var result: Array[StringName] = []
    for raw_name: Variant in names:
        result.append(StringName(String(raw_name)))
    return result


func _validate_stat_growth_entry(entry: Dictionary, index: int, errors: PackedStringArray) -> void:
    if entry.is_empty():
        errors.append("stat_growth_by_transition[%d] must author at least one automatic stat increase" % index)
        return
    var normalized_ids: Dictionary = {}
    var has_positive_growth := false
    for raw_stat_id: Variant in entry.keys():
        var stat_id := String(raw_stat_id)
        if not StableId.is_valid(stat_id):
            errors.append("stat_growth_by_transition[%d] has invalid stat ID: %s" % [index, stat_id])
            continue
        if normalized_ids.has(stat_id):
            errors.append("stat_growth_by_transition[%d] duplicates stat ID after normalization: %s" % [index, stat_id])
            continue
        normalized_ids[stat_id] = true
        var raw_amount: Variant = entry[raw_stat_id]
        if not _is_finite_number(raw_amount):
            errors.append("stat_growth_by_transition[%d][%s] must be a finite number" % [index, stat_id])
            continue
        var amount := float(raw_amount)
        if amount < 0.0:
            errors.append("stat_growth_by_transition[%d][%s] cannot be negative" % [index, stat_id])
        elif amount > 0.0:
            has_positive_growth = true
    if not has_positive_growth:
        errors.append("stat_growth_by_transition[%d] must contain at least one positive automatic stat increase" % index)


static func _is_finite_number(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return true
    if typeof(value) != TYPE_FLOAT:
        return false
    return is_finite(float(value))
