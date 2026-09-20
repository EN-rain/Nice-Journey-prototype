class_name PrototypeTowerFloorCatalogValidator
extends RefCounted

const FLOOR_COUNT: int = 10

static func validate_entries(raw_entries: Variant) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if not raw_entries is Array:
        errors.append("entries must be an array")
        return errors

    var entries: Array = raw_entries as Array
    if entries.size() != FLOOR_COUNT:
        errors.append("entries must contain exactly 10 tower floors")

    var seen_floor_ids: Dictionary = {}
    for index: int in range(entries.size()):
        var raw_entry: Variant = entries[index]
        if not raw_entry is Dictionary:
            errors.append("entries[%d] must be a dictionary" % index)
            continue

        var entry: Dictionary = raw_entry as Dictionary
        var floor_id: int = _read_floor_id(entry, index, errors)
        if floor_id != 0:
            if seen_floor_ids.has(floor_id):
                errors.append("entries[%d]: duplicate floor_id %d" % [index, floor_id])
            else:
                seen_floor_ids[floor_id] = true

        _validate_optional_name(entry, index, errors)

    for floor_id: int in range(1, FLOOR_COUNT + 1):
        if not seen_floor_ids.has(floor_id):
            errors.append("missing floor_id %d" % floor_id)

    return errors

static func _read_floor_id(entry: Dictionary, index: int, errors: PackedStringArray) -> int:
    if not entry.has("floor_id"):
        errors.append("entries[%d]: missing floor_id" % index)
        return 0
    var value: Variant = entry.get("floor_id")
    if typeof(value) != TYPE_INT:
        errors.append("entries[%d]: floor_id must be an integer" % index)
        return 0
    var floor_id: int = int(value)
    if floor_id < 1 or floor_id > FLOOR_COUNT:
        errors.append("entries[%d]: floor_id must be between 1 and 10" % index)
        return 0
    return floor_id

static func _validate_optional_name(entry: Dictionary, index: int, errors: PackedStringArray) -> void:
    if not entry.has("name"):
        return
    var value: Variant = entry.get("name")
    if not (value is String or value is StringName):
        errors.append("entries[%d]: name must be a string when present" % index)
