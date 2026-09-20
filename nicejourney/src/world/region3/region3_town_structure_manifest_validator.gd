class_name Region3TownStructureManifestValidator
extends RefCounted

const TOTAL_STRUCTURES: int = 20
const FUNCTIONAL_STRUCTURES: int = 8
const DECORATIVE_STRUCTURES: int = 12

const CATEGORY_FUNCTIONAL: StringName = &"functional"
const CATEGORY_DECORATIVE: StringName = &"decorative"

const ROLE_CENTRAL_TOWER: StringName = &"central_tower"
const ROLE_QUEST_HALL: StringName = &"quest_hall"
const ROLE_BLACKSMITH: StringName = &"blacksmith"
const ROLE_GENERAL_MERCHANT: StringName = &"general_merchant"
const ROLE_INN_REST_HOUSE: StringName = &"inn_rest_house"
const ROLE_STORAGE_HOUSE: StringName = &"storage_house"
const ROLE_TRAINING_HALL: StringName = &"training_hall"
const ROLE_CLINIC_APOTHECARY: StringName = &"clinic_apothecary"

const REQUIRED_FUNCTIONAL_ROLES: Array[StringName] = [
    ROLE_CENTRAL_TOWER,
    ROLE_QUEST_HALL,
    ROLE_BLACKSMITH,
    ROLE_GENERAL_MERCHANT,
    ROLE_INN_REST_HOUSE,
    ROLE_STORAGE_HOUSE,
    ROLE_TRAINING_HALL,
    ROLE_CLINIC_APOTHECARY,
]

static func validate_entries(raw_entries: Variant) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if not raw_entries is Array:
        errors.append("entries must be an array")
        return errors

    var entries: Array = raw_entries as Array
    if entries.size() != TOTAL_STRUCTURES:
        errors.append("entries must contain exactly 20 structures")

    var seen_structure_ids: Dictionary = {}
    var seen_functional_roles: Dictionary = {}
    var functional_count: int = 0
    var decorative_count: int = 0

    for index: int in range(entries.size()):
        var raw_entry: Variant = entries[index]
        if not raw_entry is Dictionary:
            errors.append("entries[%d] must be a dictionary" % index)
            continue

        var entry: Dictionary = raw_entry as Dictionary
        var structure_id: StringName = _read_stable_id(entry, "structure_id", index, errors)
        if structure_id != &"":
            if seen_structure_ids.has(structure_id):
                errors.append("entries[%d]: duplicate structure_id %s" % [index, String(structure_id)])
            else:
                seen_structure_ids[structure_id] = true

        var category: StringName = _read_string_name(entry, "category", index, errors)
        if category == CATEGORY_FUNCTIONAL:
            functional_count += 1
            var role_id: StringName = _read_string_name(entry, "role_id", index, errors)
            if role_id == &"":
                continue
            if not REQUIRED_FUNCTIONAL_ROLES.has(role_id):
                errors.append("entries[%d]: unknown functional role_id %s" % [index, String(role_id)])
                continue
            if seen_functional_roles.has(role_id):
                errors.append("entries[%d]: duplicate functional role_id %s" % [index, String(role_id)])
            else:
                seen_functional_roles[role_id] = true
        elif category == CATEGORY_DECORATIVE:
            decorative_count += 1
        elif category != &"":
            errors.append("entries[%d]: category must be functional or decorative" % index)

    if functional_count != FUNCTIONAL_STRUCTURES:
        errors.append("manifest must contain exactly 8 functional structures")
    if decorative_count != DECORATIVE_STRUCTURES:
        errors.append("manifest must contain exactly 12 decorative structures")

    for role_id: StringName in REQUIRED_FUNCTIONAL_ROLES:
        if not seen_functional_roles.has(role_id):
            errors.append("missing functional role_id %s" % String(role_id))

    return errors

static func _read_stable_id(entry: Dictionary, field: String, index: int, errors: PackedStringArray) -> StringName:
    var value: StringName = _read_string_name(entry, field, index, errors)
    if value != &"" and not StableId.is_valid(String(value)):
        errors.append("entries[%d]: %s must be a stable ID" % [index, field])
        return &""
    return value

static func _read_string_name(entry: Dictionary, field: String, index: int, errors: PackedStringArray) -> StringName:
    if not entry.has(field):
        errors.append("entries[%d]: missing %s" % [index, field])
        return &""
    var value: Variant = entry.get(field)
    if not (value is String or value is StringName):
        errors.append("entries[%d]: %s must be a string" % [index, field])
        return &""
    var text: String = String(value)
    if text.is_empty():
        errors.append("entries[%d]: %s must not be empty" % [index, field])
        return &""
    return StringName(text)
