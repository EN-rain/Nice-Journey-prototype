class_name Region3PlaytestContent
extends Resource

# Explicitly provisional content; not final economy, recovery, or balance authority.
@export var playtest_placeholder: bool = true
@export var merchant_stock: VendorStockCatalog = null
@export var blacksmith_recipes: UpgradeRecipeCatalog = null
@export var item_categories: ItemCategoryCatalog = null
@export var inn_recovery: Dictionary = {}
@export var clinic_recovery: Dictionary = {}
@export var recovery_mapping: Dictionary = {}


func validate_content() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("Region 3 playtest content must retain its provisional flag")
    if item_categories == null or not item_categories.validate_catalog().is_empty():
        errors.append("item categories must be valid")
    if merchant_stock == null or not bool(merchant_stock.general_merchant_readiness(item_categories, true).get("available", false)):
        errors.append("General Merchant stock/categories must be complete")
    if merchant_stock == null or not bool(merchant_stock.vendor_readiness(&"vendor:clinic_apothecary", item_categories, true).get("available", false)):
        errors.append("Clinic stock/categories must be complete")
    if blacksmith_recipes == null or not bool(blacksmith_recipes.readiness(item_categories, true).get("available", false)):
        errors.append("Blacksmith recipes/categories must be complete")

    # The shipped provisional bundle promises a usable 0→1 upgrade for each
    # approved starter weapon; a generally valid recipe catalog alone does not.
    if blacksmith_recipes != null and blacksmith_recipes.readiness(item_categories, true).get("available", false):
        for starter_id: StringName in [
            StarterKitCatalog.WEAPON_MELEE_SWORD,
            StarterKitCatalog.WEAPON_RANGED_BOW,
            StarterKitCatalog.WEAPON_MAGE_STAFF,
        ]:
            if blacksmith_recipes.compatible_recipes(starter_id, &"common", 0).is_empty():
                errors.append("no starter weapon upgrade for %s" % String(starter_id))

        # This PLAYTEST bundle currently authors upgrade materials only in
        # General Merchant stock. Validate that each recipe has an actual
        # available source without claiming the finite campaign is balanced.
        if merchant_stock != null:
            var general_vendor := merchant_stock.get_definition(VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID)
            if general_vendor != null:
                for recipe: UpgradeRecipeDefinition in blacksmith_recipes.recipes:
                    if recipe == null:
                        continue
                    for raw_material_id: Variant in recipe.material_costs.keys():
                        var material_id := String(raw_material_id)
                        var stock_entry: Variant = general_vendor.stock.get(material_id, null)
                        if not stock_entry is Dictionary:
                            errors.append("no General Merchant source for upgrade material %s" % material_id)
                        elif int((stock_entry as Dictionary).get("quantity", 0)) < int(recipe.material_costs[raw_material_id]):
                            errors.append("insufficient authored upgrade material stock for %s" % material_id)

    var clinic_vendor_id := StringName(String(clinic_recovery.get("stock_reference_id", &"")))
    if clinic_vendor_id != &"vendor:clinic_apothecary":
        errors.append("Clinic recovery must reference its authored Clinic stock")
    if merchant_stock != null and item_categories != null:
        var clinic_vendor := merchant_stock.get_definition(clinic_vendor_id)
        if clinic_vendor == null:
            errors.append("Clinic recovery stock reference must resolve to an authored vendor")
        else:
            for raw_id: Variant in clinic_vendor.stock.keys():
                var definition_id := StringName(String(raw_id))
                if item_categories.category_for(definition_id) != ItemCategoryCatalog.CATEGORY_CONSUMABLE:
                    errors.append("Clinic stock must contain only authored consumables: %s" % String(definition_id))

    # Check the whole Inspector mapping before applying any part of the bundle.
    # GameplayRoot uses the same target identities when committing recovery.
    var mapped: Dictionary = {}
    var claimed_targets: Dictionary = {}
    for raw_id: Variant in recovery_mapping.keys():
        var source_id := StringName(String(raw_id))
        var target_id := StringName(String(recovery_mapping[raw_id]))
        if not (raw_id is String or raw_id is StringName) or not StableId.is_valid(String(source_id)):
            errors.append("recovery mapping source must be a stable ID")
            continue
        if target_id not in GameplayRoot.SUPPORTED_RECOVERY_TARGETS:
            errors.append("unsupported live recovery target for %s" % String(source_id))
            continue
        if mapped.has(source_id):
            errors.append("duplicate live recovery source %s" % String(source_id))
            continue
        if claimed_targets.has(target_id):
            errors.append("multiple recovery sources target %s" % String(target_id))
            continue
        mapped[source_id] = target_id
        claimed_targets[target_id] = true

    for role_id: StringName in [Region3RecoveryServiceDefinition.ROLE_INN_REST_HOUSE, Region3RecoveryServiceDefinition.ROLE_CLINIC_APOTHECARY]:
        var entry := inn_recovery if role_id == Region3RecoveryServiceDefinition.ROLE_INN_REST_HOUSE else clinic_recovery
        if not bool(Region3RecoveryServiceDefinition.production_readiness(entry).get("available", false)):
            errors.append("recovery %s is invalid" % String(role_id))
        var amounts: Variant = entry.get("recovery_amounts", null)
        if not amounts is Dictionary:
            continue
        for raw_id: Variant in (amounts as Dictionary).keys():
            var source_id := StringName(String(raw_id))
            if not mapped.has(source_id):
                errors.append("no live recovery mapping for %s" % String(source_id))
            elif mapped[source_id] == GameplayRoot.RECOVERY_TARGET_HEALTH:
                var amount: Variant = (amounts as Dictionary)[raw_id]
                if (typeof(amount) == TYPE_FLOAT or typeof(amount) == TYPE_INT) and is_finite(float(amount)) and not is_equal_approx(float(amount), round(float(amount))):
                    errors.append("health recovery must be integral for %s" % String(source_id))
    return errors
