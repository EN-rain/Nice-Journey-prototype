class_name AutomaticStatState
extends RefCounted


static func validate_dictionary(raw_state: Variant) -> PackedStringArray:
    var errors := PackedStringArray()
    if not raw_state is Dictionary:
        errors.append("automatic stat state must be a dictionary")
        return errors
    var normalized_ids: Dictionary = {}
    for raw_key: Variant in (raw_state as Dictionary).keys():
        var stat_id := String(raw_key)
        if not StableId.is_valid(stat_id):
            errors.append("invalid automatic stat ID: %s" % stat_id)
            continue
        if normalized_ids.has(stat_id):
            errors.append("duplicate automatic stat ID after normalization: %s" % stat_id)
            continue
        normalized_ids[stat_id] = true
        var raw_value: Variant = (raw_state as Dictionary)[raw_key]
        if not _is_finite_number(raw_value):
            errors.append("automatic stat value must be finite: %s" % stat_id)
            continue
        if float(raw_value) < 0.0:
            errors.append("automatic stat value cannot be negative: %s" % stat_id)
    return errors


static func normalize_dictionary(raw_state: Variant) -> Dictionary:
    if not validate_dictionary(raw_state).is_empty():
        return {}
    var result: Dictionary = {}
    var keys: Array = (raw_state as Dictionary).keys()
    keys.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    for raw_key: Variant in keys:
        result[String(raw_key)] = float((raw_state as Dictionary)[raw_key])
    return result


static func equivalent(left: Variant, right: Variant) -> bool:
    var left_normalized := normalize_dictionary(left)
    var right_normalized := normalize_dictionary(right)
    if not validate_dictionary(left).is_empty() or not validate_dictionary(right).is_empty():
        return false
    if left_normalized.size() != right_normalized.size():
        return false
    for key: Variant in left_normalized.keys():
        if not right_normalized.has(key):
            return false
        if not is_equal_approx(float(left_normalized[key]), float(right_normalized[key])):
            return false
    return true


static func _is_finite_number(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return true
    if typeof(value) != TYPE_FLOAT:
        return false
    return is_finite(float(value))
