class_name WorldRegionCatalogValidator
extends RefCounted

const REGION_COUNT: int = 12
const PROTOTYPE_REGION_ID: int = 3

const STATE_PROTOTYPE_STARTING_REGION: StringName = &"prototype_starting_region"
const STATE_FUTURE_LOCKED: StringName = &"future_locked"

static func validate_entries(raw_entries: Variant) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if not raw_entries is Array:
        errors.append("entries must be an array")
        return errors

    var entries: Array = raw_entries as Array
    if entries.size() != REGION_COUNT:
        errors.append("entries must contain exactly 12 regions")

    var seen_region_ids: Dictionary = {}
    for index: int in range(entries.size()):
        var raw_entry: Variant = entries[index]
        if not raw_entry is Dictionary:
            errors.append("entries[%d] must be a dictionary" % index)
            continue

        var entry: Dictionary = raw_entry as Dictionary
        var region_id: int = _read_region_id(entry, index, errors)
        if region_id == 0:
            _validate_optional_name(entry, index, errors)
            continue

        if seen_region_ids.has(region_id):
            errors.append("entries[%d]: duplicate region_id %d" % [index, region_id])
        else:
            seen_region_ids[region_id] = true

        var state: StringName = _read_state(entry, index, errors)
        if state != &"":
            var expected_state: StringName = STATE_PROTOTYPE_STARTING_REGION if region_id == PROTOTYPE_REGION_ID else STATE_FUTURE_LOCKED
            if state != expected_state:
                errors.append("entries[%d]: region %d state must be %s" % [index, region_id, String(expected_state)])

        _validate_optional_name(entry, index, errors)

    for region_id: int in range(1, REGION_COUNT + 1):
        if not seen_region_ids.has(region_id):
            errors.append("missing region_id %d" % region_id)

    return errors

static func _read_region_id(entry: Dictionary, index: int, errors: PackedStringArray) -> int:
    if not entry.has("region_id"):
        errors.append("entries[%d]: missing region_id" % index)
        return 0
    var value: Variant = entry.get("region_id")
    if typeof(value) != TYPE_INT:
        errors.append("entries[%d]: region_id must be an integer" % index)
        return 0
    var region_id: int = int(value)
    if region_id < 1 or region_id > REGION_COUNT:
        errors.append("entries[%d]: region_id must be between 1 and 12" % index)
        return 0
    return region_id

static func _read_state(entry: Dictionary, index: int, errors: PackedStringArray) -> StringName:
    if not entry.has("state"):
        errors.append("entries[%d]: missing state" % index)
        return &""
    var value: Variant = entry.get("state")
    if not (value is String or value is StringName):
        errors.append("entries[%d]: state must be a string" % index)
        return &""
    var text: String = String(value)
    if text.is_empty():
        errors.append("entries[%d]: state must not be empty" % index)
        return &""
    return StringName(text)

static func _validate_optional_name(entry: Dictionary, index: int, errors: PackedStringArray) -> void:
    if not entry.has("name"):
        return
    var value: Variant = entry.get("name")
    if not (value is String or value is StringName):
        errors.append("entries[%d]: name must be a string when present" % index)
