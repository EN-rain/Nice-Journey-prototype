class_name UpgradeRecipeCatalog
extends Resource

const REASON_CONTENT_UNAVAILABLE: StringName = &"content_unavailable"

@export var recipes: Array[UpgradeRecipeDefinition] = []


func validate_catalog(require_authored_fields: bool = false) -> PackedStringArray:
    var errors := PackedStringArray()
    var seen: Dictionary = {}
    for index: int in range(recipes.size()):
        var recipe: UpgradeRecipeDefinition = recipes[index]
        if recipe == null:
            errors.append("recipe %d must be an UpgradeRecipeDefinition" % index)
            continue
        var recipe_errors: PackedStringArray = (
            recipe.validate_authored_definition()
            if require_authored_fields
            else recipe.validate_definition()
        )
        for recipe_error: String in recipe_errors:
            errors.append("recipe %d: %s" % [index, recipe_error])
        if StableId.is_valid(String(recipe.recipe_id)):
            if seen.has(recipe.recipe_id):
                errors.append("recipe_id must be unique: %s" % String(recipe.recipe_id))
            seen[recipe.recipe_id] = true
    if require_authored_fields and recipes.is_empty():
        errors.append("at least one authored upgrade recipe is required")
    return errors


func readiness(
    category_catalog: ItemCategoryCatalog = null,
    require_category_authority: bool = false
) -> Dictionary:
    if recipes.is_empty():
        var missing_fields := PackedStringArray([
            "recipe_id",
            "compatible_definition_ids",
            "compatible_rarities",
            "source_rank",
            "result_rank",
            "maximum_rank",
            "gold_cost",
            "material_costs",
            "stat_changes",
            "prerequisites",
        ])
        if require_category_authority:
            missing_fields.append("item_category_catalog")
        return {
            "available": false,
            "reason_id": REASON_CONTENT_UNAVAILABLE,
            "missing_fields": missing_fields,
        }
    var errors: PackedStringArray = validate_catalog(true)
    if require_category_authority:
        if category_catalog == null:
            errors.append("item category catalog is required for production Blacksmith content")
        else:
            for recipe: UpgradeRecipeDefinition in recipes:
                if recipe == null:
                    continue
                for category_error: String in category_catalog.validate_upgrade_recipe_definition(recipe):
                    errors.append(category_error)
    if not errors.is_empty():
        var missing := PackedStringArray()
        for recipe: UpgradeRecipeDefinition in recipes:
            if recipe == null:
                continue
            for field: String in recipe.unauthored_fields():
                if not missing.has(field):
                    missing.append(field)
        if require_category_authority and category_catalog == null and not missing.has("item_category_catalog"):
            missing.append("item_category_catalog")
        return {
            "available": false,
            "reason_id": REASON_CONTENT_UNAVAILABLE,
            "missing_fields": missing,
            "validation_errors": errors,
        }
    return {
        "available": true,
        "reason_id": &"",
        "missing_fields": PackedStringArray(),
    }


func has_authored_recipes() -> bool:
    return not recipes.is_empty() and validate_catalog(true).is_empty()


func validated_recipes() -> Array[UpgradeRecipeDefinition]:
    var result: Array[UpgradeRecipeDefinition] = []
    if not has_authored_recipes():
        return result
    for recipe: UpgradeRecipeDefinition in recipes:
        var copy: UpgradeRecipeDefinition = recipe.duplicate(true) as UpgradeRecipeDefinition
        if copy != null:
            result.append(copy)
    return result


func get_recipe(recipe_id: StringName) -> UpgradeRecipeDefinition:
    if not StableId.is_valid(String(recipe_id)) or not has_authored_recipes():
        return null
    for recipe: UpgradeRecipeDefinition in recipes:
        if recipe != null and recipe.recipe_id == recipe_id:
            return recipe.duplicate(true) as UpgradeRecipeDefinition
    return null


func compatible_recipes(definition_id: StringName, rarity: StringName, rank: int) -> Array[UpgradeRecipeDefinition]:
    var result: Array[UpgradeRecipeDefinition] = []
    if (
        not StableId.is_valid(String(definition_id))
        or rank < 0
        or not InventoryState.RARITY_AFFIX_TARGETS.has(String(rarity))
        or not has_authored_recipes()
    ):
        return result
    for recipe: UpgradeRecipeDefinition in recipes:
        if recipe != null and recipe.is_compatible(definition_id, rarity, rank):
            var copy: UpgradeRecipeDefinition = recipe.duplicate(true) as UpgradeRecipeDefinition
            if copy != null:
                result.append(copy)
    return result
