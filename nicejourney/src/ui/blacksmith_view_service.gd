class_name BlacksmithViewService
extends RefCounted

const REASON_PROFILE_MISSING: StringName = &"profile_missing"
const REASON_INVENTORY_STATE_INVALID: StringName = &"inventory_state_invalid"
const REASON_STORAGE_STATE_INVALID: StringName = &"storage_state_invalid"
const REASON_EQUIPMENT_STATE_INVALID: StringName = &"equipment_state_invalid"
const REASON_RECIPE_SET_INVALID: StringName = &"recipe_set_invalid"


static func build_view(profile: ProfileSnapshot, recipes: Array[UpgradeRecipeDefinition]) -> Dictionary:
    if profile == null:
        return _reject(REASON_PROFILE_MISSING)
    if not _recipes_valid(recipes):
        return _reject(REASON_RECIPE_SET_INVALID)
    var inventory := InventoryState.new()
    if not profile.item_state.is_empty() and not inventory.load_dictionary(profile.item_state).is_empty():
        return _reject(REASON_INVENTORY_STATE_INVALID)
    var storage := StorageState.new()
    if not profile.storage_state.is_empty() and not storage.load_dictionary(profile.storage_state).is_empty():
        return _reject(REASON_STORAGE_STATE_INVALID)
    var equipment := EquipmentState.new()
    if not profile.equipment_state.is_empty() and not equipment.load_dictionary(profile.equipment_state).is_empty():
        return _reject(REASON_EQUIPMENT_STATE_INVALID)

    var options: Array[Dictionary] = []
    _append_options(options, ProfileUpgradeTransactionService.LOCATION_INVENTORY, inventory.normal_slots, recipes, inventory)
    _append_options(options, ProfileUpgradeTransactionService.LOCATION_STORAGE, storage.normal_slots, recipes, inventory)
    var equipped_items: Array[Dictionary] = []
    for slot_id: StringName in EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS:
        var equipped := equipment.get_item(slot_id)
        if not equipped.is_empty():
            equipped_items.append(equipped)
    _append_options(options, ProfileUpgradeTransactionService.LOCATION_EQUIPMENT, equipped_items, recipes, inventory)
    options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var definition_a := String(a.get("definition_id", &""))
        var definition_b := String(b.get("definition_id", &""))
        if definition_a != definition_b:
            return definition_a.naturalnocasecmp_to(definition_b) < 0
        var location_a := String(a.get("location_id", &""))
        var location_b := String(b.get("location_id", &""))
        if location_a != location_b:
            return location_a < location_b
        return String(a.get("recipe_id", &"")).naturalnocasecmp_to(String(b.get("recipe_id", &""))) < 0
    )
    return {
        "accepted": true,
        "gold": inventory.gold,
        "upgrade_options": options,
        "authored_recipe_count": recipes.size(),
        "recipes_are_caller_supplied": true,
    }


static func _append_options(
    output: Array[Dictionary],
    location_id: StringName,
    slots: Array[Dictionary],
    recipes: Array[UpgradeRecipeDefinition],
    inventory: InventoryState
) -> void:
    for item: Dictionary in slots:
        if item.is_empty() or bool(item.get("stackable", true)):
            continue
        var definition_id := StringName(String(item.get("definition_id", &"")))
        var rarity := StringName(String(item.get("rarity", "common")))
        var rank := int(item.get("upgrade_rank", 0))
        for recipe: UpgradeRecipeDefinition in recipes:
            var preview: Dictionary = recipe.preview(definition_id, rarity, rank)
            if not bool(preview.get("compatible", false)):
                continue
            var missing_materials: Dictionary = {}
            var materials := preview.get("material_costs", {}) as Dictionary
            for raw_id: Variant in materials.keys():
                var material_id := StringName(String(raw_id))
                var required := int(materials[raw_id])
                var missing := maxi(0, required - inventory.get_total_quantity(material_id))
                if missing > 0:
                    missing_materials[String(material_id)] = missing
            var gold_shortfall := maxi(0, int(preview.get("gold_cost", 0)) - inventory.gold)
            output.append({
                "affordable": gold_shortfall == 0 and missing_materials.is_empty(),
                "gold_shortfall": gold_shortfall,
                "missing_materials": missing_materials,
                "location_id": location_id,
                "item_instance_id": StringName(String(item.get("item_instance_id", &""))),
                "definition_id": definition_id,
                "rarity": rarity,
                "recipe_id": recipe.recipe_id,
                "before_rank": int(preview.get("before_rank", rank)),
                "after_rank": int(preview.get("after_rank", rank + 1)),
                "maximum_rank": int(preview.get("maximum_rank", rank + 1)),
                "gold_cost": int(preview.get("gold_cost", 0)),
                "material_costs": (preview.get("material_costs", {}) as Dictionary).duplicate(true),
                "stat_changes": (preview.get("stat_changes", {}) as Dictionary).duplicate(true),
            })


static func _recipes_valid(recipes: Array[UpgradeRecipeDefinition]) -> bool:
    var seen: Dictionary = {}
    for recipe: UpgradeRecipeDefinition in recipes:
        if recipe == null or not recipe.validate_definition().is_empty() or seen.has(recipe.recipe_id):
            return false
        seen[recipe.recipe_id] = true
    return true


static func _reject(reason_id: StringName) -> Dictionary:
    return {"accepted": false, "reason_id": reason_id}
