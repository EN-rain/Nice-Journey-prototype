class_name ConsumablePlaytestTuning
extends Resource

# Temporary healing amounts are Inspector-owned and cannot be mistaken for
# approved final consumable balance or an unauthored item category.
@export var playtest_placeholder: bool = true
@export var health_recovery_by_definition: Dictionary = {}


func validate_tuning(category_catalog: ItemCategoryCatalog = null) -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder or health_recovery_by_definition.is_empty():
        errors.append("provisional nonempty consumable tuning is required")
    if category_catalog == null or not category_catalog.validate_catalog().is_empty():
        errors.append("valid item category catalog required")
        return errors
    for raw_id: Variant in health_recovery_by_definition.keys():
        if not raw_id is String and not raw_id is StringName:
            errors.append("consumable definition IDs must be strings")
            continue
        var definition_id := StringName(String(raw_id))
        if not StableId.is_valid(String(definition_id)) or not category_catalog.is_consumable(definition_id):
            errors.append("heal definition must be an explicitly authored consumable: %s" % String(definition_id))
        var raw_amount: Variant = health_recovery_by_definition[raw_id]
        if typeof(raw_amount) != TYPE_INT or int(raw_amount) <= 0 or int(raw_amount) > 1000000:
            errors.append("healing amount must be a positive integer no greater than 1000000")
    return errors


func heal_amount(definition_id: StringName) -> int:
    var raw: Variant = health_recovery_by_definition.get(
        String(definition_id), health_recovery_by_definition.get(definition_id, null)
    )
    return int(raw) if typeof(raw) == TYPE_INT and int(raw) > 0 else 0
