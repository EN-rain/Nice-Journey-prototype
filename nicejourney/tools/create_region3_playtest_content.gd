extends SceneTree

const OUTPUT: String = "res://src/data/tuning/region3_services_playtest_v01.tres"


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var bundle := Region3PlaytestContent.new()
    bundle.resource_name = "PLAYTEST Region 3 services v01 — provisional costs and inventory"
    bundle.playtest_placeholder = true

    var merchant := VendorStockDefinition.new()
    merchant.vendor_id = VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID
    merchant.restock_rule_id = &"restock:region3_playtest_fixed"
    merchant.restock_policy = VendorStockDefinition.RESTOCK_POLICY_FIXED_NO_RESTOCK
    merchant.availability_conditions_declared = true
    merchant.stock = {
        "itemdef:region3_playtest_tonic": _stock(12, 4, 12, true),
        "itemdef:region3_playtest_ore": _stock(8, 2, 12, true),
        String(StarterKitCatalog.WEAPON_MELEE_SWORD): _stock(38, 12, 2, false),
        String(StarterKitCatalog.WEAPON_RANGED_BOW): _stock(38, 12, 2, false),
        String(StarterKitCatalog.WEAPON_MAGE_STAFF): _stock(38, 12, 2, false),
    }
    var clinic := VendorStockDefinition.new()
    clinic.vendor_id = &"vendor:clinic_apothecary"
    clinic.restock_rule_id = &"restock:region3_playtest_clinic_fixed"
    clinic.restock_policy = VendorStockDefinition.RESTOCK_POLICY_FIXED_NO_RESTOCK
    clinic.availability_conditions_declared = true
    clinic.stock = {"itemdef:region3_playtest_tonic": _stock(12, 4, 8, true)}

    var stock := VendorStockCatalog.new()
    stock.definitions = [merchant, clinic]
    bundle.merchant_stock = stock
    var cats := ItemCategoryCatalog.new()
    cats.definition_categories = {
        "itemdef:region3_playtest_tonic": ItemCategoryCatalog.CATEGORY_CONSUMABLE,
        "itemdef:region3_playtest_ore": ItemCategoryCatalog.CATEGORY_MATERIAL,
        String(StarterKitCatalog.WEAPON_MELEE_SWORD): ItemCategoryCatalog.CATEGORY_WEAPON,
        String(StarterKitCatalog.WEAPON_RANGED_BOW): ItemCategoryCatalog.CATEGORY_WEAPON,
        String(StarterKitCatalog.WEAPON_MAGE_STAFF): ItemCategoryCatalog.CATEGORY_WEAPON,
    }
    bundle.item_categories = cats
    var recipes := UpgradeRecipeCatalog.new()
    for weapon_id: StringName in [StarterKitCatalog.WEAPON_MELEE_SWORD, StarterKitCatalog.WEAPON_RANGED_BOW, StarterKitCatalog.WEAPON_MAGE_STAFF]:
        var recipe := UpgradeRecipeDefinition.new()
        recipe.recipe_id = StringName("upgrade:playtest:%s:0_to_1" % String(weapon_id))
        recipe.compatible_definition_ids = [weapon_id]
        recipe.compatible_rarities = [&"common"]
        recipe.source_rank = 0
        recipe.source_rank_declared = true
        recipe.result_rank = 1
        recipe.result_rank_declared = true
        recipe.maximum_rank = 1
        recipe.maximum_rank_declared = true
        recipe.gold_cost = 22
        recipe.gold_cost_declared = true
        recipe.material_costs = {"itemdef:region3_playtest_ore": 2}
        recipe.stat_changes = {"attack_power": 1}
        recipe.prerequisites_declared = true
        recipes.recipes.append(recipe)
    bundle.blacksmith_recipes = recipes

    bundle.inn_recovery = {
        "service_id": &"service:region3_inn_rest",
        "structure_id": &"r3:functional:05",
        "role_id": Region3RecoveryServiceDefinition.ROLE_INN_REST_HOUSE,
        "available": true,
        "combat_restricted": true,
        "price_gold": 8,
        "recovery_amounts": {
            "resource:region3_playtest_hp": 35,
            "resource:region3_playtest_stamina": 20.0,
        },
        "stock_reference_id": null,
        "save_event_id": &"save_event:region3_inn_rest",
    }
    bundle.clinic_recovery = {
        "service_id": &"service:region3_clinic",
        "structure_id": &"r3:functional:08",
        "role_id": Region3RecoveryServiceDefinition.ROLE_CLINIC_APOTHECARY,
        "available": true,
        "combat_restricted": true,
        "price_gold": 15,
        "recovery_amounts": {
            "resource:region3_playtest_hp": 60,
            "resource:region3_playtest_stamina": 30.0,
        },
        "stock_reference_id": &"vendor:clinic_apothecary",
        "save_event_id": null,
    }
    bundle.recovery_mapping = {
        "resource:region3_playtest_hp": GameplayRoot.RECOVERY_TARGET_HEALTH,
        "resource:region3_playtest_stamina": GameplayRoot.RECOVERY_TARGET_STAMINA,
    }
    var errors := bundle.validate_content()
    if not errors.is_empty():
        push_error("Invalid Region 3 playtest bundle: %s" % str(errors))
        quit(1)
        return
    var code := ResourceSaver.save(bundle, OUTPUT)
    print("REGION 3 PLAYTEST BUNDLE: %d" % code)
    quit(0 if code == OK else 1)


func _stock(buy_price: int, sell_price: int, quantity: int, stackable: bool) -> Dictionary:
    return {"buy_price": buy_price, "sell_price": sell_price, "quantity": quantity, "stackable": stackable}
