class_name ItemCategoryCatalog
extends Resource

const CATEGORY_WEAPON: StringName = &"weapon"
const CATEGORY_ARMOR: StringName = &"armor"
const CATEGORY_CONSUMABLE: StringName = &"consumable"
const CATEGORY_MATERIAL: StringName = &"material"
const CATEGORY_QUEST_KEY: StringName = &"quest_key"

const ALLOWED_CATEGORIES: Array[StringName] = [
    CATEGORY_WEAPON,
    CATEGORY_ARMOR,
    CATEGORY_CONSUMABLE,
    CATEGORY_MATERIAL,
    CATEGORY_QUEST_KEY,
]

@export var definition_categories: Dictionary = {}


func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    for raw_definition_id: Variant in definition_categories.keys():
        if not (raw_definition_id is String or raw_definition_id is StringName):
            errors.append("item category definition IDs must be strings")
            continue
        var definition_id := String(raw_definition_id)
        if not StableId.is_valid(definition_id):
            errors.append("item category definition ID must be stable: %s" % definition_id)
            continue
        var raw_category: Variant = definition_categories[raw_definition_id]
        if not (raw_category is String or raw_category is StringName):
            errors.append("item category for %s must be a string" % definition_id)
            continue
        var category := StringName(String(raw_category))
        if not ALLOWED_CATEGORIES.has(category):
            errors.append("unsupported item category for %s: %s" % [definition_id, String(category)])
    return errors


func category_for(definition_id: StringName) -> StringName:
    if not StableId.is_valid(String(definition_id)) or not validate_catalog().is_empty():
        return &""
    if definition_categories.has(definition_id):
        return StringName(String(definition_categories[definition_id]))
    var key := String(definition_id)
    if definition_categories.has(key):
        return StringName(String(definition_categories[key]))
    return &""


func is_consumable(definition_id: StringName) -> bool:
    return category_for(definition_id) == CATEGORY_CONSUMABLE


func missing_definition_ids(required_definition_ids: Array[StringName]) -> Array[StringName]:
    var missing: Array[StringName] = []
    if not validate_catalog().is_empty():
        return required_definition_ids.duplicate()
    var seen: Dictionary = {}
    for definition_id: StringName in required_definition_ids:
        if seen.has(definition_id):
            continue
        seen[definition_id] = true
        if category_for(definition_id) == &"":
            missing.append(definition_id)
    return missing


func validate_required_definitions(required_definition_ids: Array[StringName]) -> PackedStringArray:
    var errors := validate_catalog()
    if not errors.is_empty():
        return errors
    for definition_id: StringName in missing_definition_ids(required_definition_ids):
        errors.append("item category is unauthored for %s" % String(definition_id))
    return errors


func validate_vendor_stock_definition(definition: VendorStockDefinition) -> PackedStringArray:
    var errors := validate_catalog()
    if definition == null:
        errors.append("vendor stock definition is required")
        return errors
    for raw_definition_id: Variant in definition.stock.keys():
        var definition_id := StringName(String(raw_definition_id))
        var category := category_for(definition_id)
        if category == &"":
            errors.append("item category is unauthored for vendor stock %s" % String(definition_id))
        elif category == CATEGORY_QUEST_KEY:
            errors.append("protected quest/key items cannot be normal vendor stock: %s" % String(definition_id))
    return errors


func validate_upgrade_recipe_definition(recipe: UpgradeRecipeDefinition) -> PackedStringArray:
    var errors := validate_catalog()
    if recipe == null:
        errors.append("upgrade recipe is required")
        return errors
    for definition_id: StringName in recipe.compatible_definition_ids:
        var category := category_for(definition_id)
        if category == &"":
            errors.append("item category is unauthored for upgrade target %s" % String(definition_id))
        elif category not in [CATEGORY_WEAPON, CATEGORY_ARMOR]:
            errors.append("upgrade targets must be authored as weapon or armor: %s" % String(definition_id))
    for raw_material_id: Variant in recipe.material_costs.keys():
        var material_id := StringName(String(raw_material_id))
        var category := category_for(material_id)
        if category == &"":
            errors.append("item category is unauthored for upgrade material %s" % String(material_id))
        elif category != CATEGORY_MATERIAL:
            errors.append("upgrade material must be explicitly authored as material: %s" % String(material_id))
    return errors


func validate_quick_slot_candidates(definition_ids: Array[StringName]) -> PackedStringArray:
    var errors := validate_catalog()
    if not errors.is_empty():
        return errors
    var seen: Dictionary = {}
    for definition_id: StringName in definition_ids:
        if seen.has(definition_id):
            continue
        seen[definition_id] = true
        var category := category_for(definition_id)
        if category == &"":
            errors.append("item category is unauthored for quick-slot candidate %s" % String(definition_id))
        elif category != CATEGORY_CONSUMABLE:
            errors.append("quick-slot candidate must be explicitly authored as consumable: %s" % String(definition_id))
    return errors


func production_readiness(required_definition_ids: Array[StringName]) -> Dictionary:
    var validation_errors := validate_catalog()
    var missing_ids: Array[StringName] = []
    var seen: Dictionary = {}
    for definition_id: StringName in required_definition_ids:
        if seen.has(definition_id):
            continue
        seen[definition_id] = true
        if not StableId.is_valid(String(definition_id)):
            validation_errors.append("required production definition ID must be stable: %s" % String(definition_id))
            continue
        if category_for(definition_id) == &"":
            missing_ids.append(definition_id)
    missing_ids.sort()

    return {
        "available": validation_errors.is_empty() and missing_ids.is_empty(),
        "reason_id": &"" if validation_errors.is_empty() and missing_ids.is_empty() else &"content_unavailable",
        "required_definition_ids": required_definition_ids.duplicate(),
        "missing_definition_ids": missing_ids.duplicate(),
        "validation_errors": validation_errors.duplicate(),
    }
