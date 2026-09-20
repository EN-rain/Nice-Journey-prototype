class_name MapLayerIdentityValidator
extends RefCounted

const LAYER_COUNT: int = 3

const LAYER_WORLD_MAP: StringName = &"world_map"
const LAYER_REGION_MAP: StringName = &"region_map"
const LAYER_TOWER_FLOOR_MAP: StringName = &"tower_floor_map"

const REQUIRED_LAYER_IDS: Array[StringName] = [
    LAYER_WORLD_MAP,
    LAYER_REGION_MAP,
    LAYER_TOWER_FLOOR_MAP,
]

static func validate_entries(raw_entries: Variant) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if not raw_entries is Array:
        errors.append("entries must be an array")
        return errors

    var entries: Array = raw_entries as Array
    if entries.size() != LAYER_COUNT:
        errors.append("entries must contain exactly 3 map layers")

    var seen_layer_ids: Dictionary = {}
    for index: int in range(entries.size()):
        var raw_entry: Variant = entries[index]
        if not raw_entry is Dictionary:
            errors.append("entries[%d] must be a dictionary" % index)
            continue

        var entry: Dictionary = raw_entry as Dictionary
        var layer_id: StringName = _read_layer_id(entry, index, errors)
        if layer_id != &"":
            if seen_layer_ids.has(layer_id):
                errors.append("entries[%d]: duplicate layer_id %s" % [index, String(layer_id)])
            else:
                seen_layer_ids[layer_id] = true

        _validate_optional_name(entry, index, errors)

    for layer_id: StringName in REQUIRED_LAYER_IDS:
        if not seen_layer_ids.has(layer_id):
            errors.append("missing layer_id %s" % String(layer_id))

    return errors

static func _read_layer_id(entry: Dictionary, index: int, errors: PackedStringArray) -> StringName:
    if not entry.has("layer_id"):
        errors.append("entries[%d]: missing layer_id" % index)
        return &""
    var value: Variant = entry.get("layer_id")
    if not (value is String or value is StringName):
        errors.append("entries[%d]: layer_id must be a string" % index)
        return &""
    var layer_id: StringName = StringName(String(value))
    if not REQUIRED_LAYER_IDS.has(layer_id):
        errors.append("entries[%d]: unknown layer_id %s" % [index, String(layer_id)])
        return &""
    return layer_id

static func _validate_optional_name(entry: Dictionary, index: int, errors: PackedStringArray) -> void:
    if not entry.has("name"):
        return
    var value: Variant = entry.get("name")
    if not (value is String or value is StringName):
        errors.append("entries[%d]: name must be a string when present" % index)
