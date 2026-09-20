extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_general_merchant_content_fails_closed_when_unauthored()
    _test_vendor_definition_and_one_time_initialization()
    _test_vendor_production_restock_and_category_authority()
    _test_upgrade_recipe_catalog_requires_explicit_authoring()
    _test_item_category_required_definition_boundary()
    _test_profile_vendor_initialization_boundary()

    if _failures == 0:
        print("ECONOMY CONTENT CATALOG TEST PASS")
    else:
        push_error("ECONOMY CONTENT CATALOG TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_general_merchant_content_fails_closed_when_unauthored() -> void:
    var catalog: VendorStockCatalog = VendorStockCatalog.new()
    var readiness: Dictionary = catalog.general_merchant_readiness()
    _expect(not bool(readiness.get("available", true)), "General Merchant production content is unavailable when no authored stock definition exists")
    _expect(StringName(readiness.get("reason_id", &"")) == VendorStockCatalog.REASON_CONTENT_UNAVAILABLE, "missing merchant content reports an explicit unavailable reason")
    var missing: PackedStringArray = readiness.get("missing_fields", PackedStringArray()) as PackedStringArray
    _expect(missing.has("stock_manifest") and missing.has("buy_prices") and missing.has("sell_prices") and missing.has("quantities") and missing.has("restock_rule_id"), "merchant readiness precisely reports missing stock, price, quantity and restock authoring")
    _expect(catalog.instantiate_vendor(VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID) == null, "catalog does not fabricate a production merchant state")


func _test_vendor_definition_and_one_time_initialization() -> void:
    var definition: VendorStockDefinition = VendorStockDefinition.new()
    definition.vendor_id = VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID
    definition.restock_rule_id = &"restock:test_none"
    definition.restock_policy = VendorStockDefinition.RESTOCK_POLICY_FIXED_NO_RESTOCK
    definition.availability_conditions_declared = true
    definition.stock = {
        "itemdef:test_consumable": {
            "buy_price": 10,
            "sell_price": 4,
            "quantity": 5,
            "stackable": true,
        },
    }
    _expect(definition.validate_definition().is_empty(), "explicit vendor fixture validates through stock and restock authoring boundary")

    var catalog: VendorStockCatalog = VendorStockCatalog.new()
    catalog.definitions = [definition]
    _expect(catalog.validate_catalog(true).is_empty(), "vendor catalog accepts one fully authored General Merchant fixture")
    var state: VendorStockState = catalog.instantiate_vendor(VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID)
    _expect(state != null and int(state.get_entry(&"itemdef:test_consumable").get("quantity", -1)) == 5, "catalog instantiates exact authored stock without changing values")

    var economy: EconomyState = EconomyState.new()
    _expect(economy.initialize_vendor_once(definition), "economy initializes exact authored vendor once")
    var persisted: VendorStockState = economy.get_vendor(VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID)
    _expect(persisted != null and persisted.adjust_quantity(&"itemdef:test_consumable", -2), "fixture mutates persisted vendor quantity")
    _expect(economy.set_vendor(persisted), "mutated vendor state persists")
    _expect(not economy.initialize_vendor_once(definition), "reinitialization is rejected instead of reload-restocking")
    persisted = economy.get_vendor(VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID)
    _expect(persisted != null and int(persisted.get_entry(&"itemdef:test_consumable").get("quantity", -1)) == 3, "rejected reinitialization preserves consumed stock")


func _test_vendor_production_restock_and_category_authority() -> void:
    var definition := VendorStockDefinition.new()
    definition.vendor_id = VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID
    definition.restock_rule_id = &"restock:region3_fixed"
    definition.stock = {
        "itemdef:test_consumable": {
            "buy_price": 10,
            "sell_price": 4,
            "quantity": 5,
            "stackable": true,
        },
    }
    _expect(not definition.validate_authored_definition().is_empty(), "production vendor content fails closed until restock policy and availability conditions are explicitly declared")
    definition.restock_policy = VendorStockDefinition.RESTOCK_POLICY_FIXED_NO_RESTOCK
    definition.availability_conditions_declared = true
    _expect(definition.validate_authored_definition().is_empty(), "fixed authored stock can explicitly declare no automatic restock and no availability conditions")

    var event_driven := definition.duplicate(true) as VendorStockDefinition
    event_driven.restock_policy = VendorStockDefinition.RESTOCK_POLICY_EVENT_DRIVEN
    _expect(not event_driven.validate_authored_definition().is_empty(), "event-driven restock cannot exist without an explicit event identity")
    event_driven.restock_event_id = &"event:region3_vendor_restock"
    _expect(event_driven.validate_authored_definition().is_empty(), "event-driven restock validates only after a stable event identity is authored")

    var catalog := VendorStockCatalog.new()
    catalog.definitions = [definition]
    _expect(not bool(catalog.general_merchant_readiness(null, true).get("available", true)), "production merchant readiness requires item-category authority")
    var categories := ItemCategoryCatalog.new()
    categories.definition_categories = {"itemdef:test_consumable": ItemCategoryCatalog.CATEGORY_CONSUMABLE}
    _expect(bool(catalog.general_merchant_readiness(categories, true).get("available", false)), "merchant becomes production-ready only when every stocked definition has category authority")


func _test_upgrade_recipe_catalog_requires_explicit_authoring() -> void:
    var recipe: UpgradeRecipeDefinition = UpgradeRecipeDefinition.new()
    recipe.recipe_id = &"upgrade:test:0_to_1"
    recipe.compatible_definition_ids = [&"itemdef:test_blade"]
    recipe.compatible_rarities = [&"rare"]
    recipe.source_rank = 0
    recipe.result_rank = 1
    recipe.maximum_rank = 3
    recipe.gold_cost = 10
    recipe.material_costs = {"itemdef:test_ore": 1}
    recipe.stat_changes = {"attack_power": 1}

    _expect(recipe.validate_definition().is_empty(), "structural recipe fixture is otherwise valid")
    _expect(not recipe.validate_authored_definition().is_empty(), "production recipe remains unavailable until rank and Gold fields are explicitly declared")

    var catalog: UpgradeRecipeCatalog = UpgradeRecipeCatalog.new()
    catalog.recipes = [recipe]
    _expect(not bool(catalog.readiness().get("available", true)), "recipe catalog fails closed on partially authored recipe")

    recipe.source_rank_declared = true
    recipe.result_rank_declared = true
    recipe.maximum_rank_declared = true
    recipe.gold_cost_declared = true
    recipe.prerequisites_declared = true
    _expect(recipe.validate_authored_definition().is_empty(), "fully declared recipe passes authored validation")
    _expect(catalog.validate_catalog(true).is_empty(), "recipe catalog accepts exact authored fixture")
    _expect(catalog.validated_recipes().size() == 1, "validated recipe catalog returns only its explicit recipe set")
    var categories := ItemCategoryCatalog.new()
    categories.definition_categories = {
        "itemdef:test_blade": ItemCategoryCatalog.CATEGORY_WEAPON,
        "itemdef:test_ore": ItemCategoryCatalog.CATEGORY_MATERIAL,
    }
    _expect(bool(catalog.readiness(categories, true).get("available", false)), "production Blacksmith readiness requires exact gear/material category authority")
    categories.definition_categories["itemdef:test_ore"] = ItemCategoryCatalog.CATEGORY_CONSUMABLE
    _expect(not bool(catalog.readiness(categories, true).get("available", true)), "Blacksmith rejects an upgrade cost whose item is not explicitly authored as material")


func _test_item_category_required_definition_boundary() -> void:
    var categories: ItemCategoryCatalog = ItemCategoryCatalog.new()
    categories.definition_categories = {
        "itemdef:test_consumable": ItemCategoryCatalog.CATEGORY_CONSUMABLE,
    }
    var required: Array[StringName] = [&"itemdef:test_consumable", &"itemdef:test_material"]
    var missing: Array[StringName] = categories.missing_definition_ids(required)
    _expect(missing == [&"itemdef:test_material"], "category catalog reports exact required definition lacking authority")
    _expect(not categories.validate_required_definitions(required).is_empty(), "required category validation fails closed while any definition is unauthored")


func _test_profile_vendor_initialization_boundary() -> void:
    var profile: ProfileSnapshot = ProfileCreationService.create_profile(3, "Merchant Init", "mage")
    _expect(profile != null, "profile vendor initialization fixture creates")
    if profile == null:
        return

    var missing_catalog := VendorStockCatalog.new()
    var missing_before: Dictionary = profile.to_dictionary()
    var missing: Dictionary = ProfileEconomyTransactionService.initialize_vendor_from_catalog(
        profile,
        missing_catalog,
        VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID
    )
    _expect(
        not bool(missing.get("accepted", true))
        and StringName(missing.get("reason_id", &"")) == ProfileEconomyTransactionService.REASON_CONTENT_UNAVAILABLE,
        "profile vendor initialization fails closed when exact production content is absent"
    )
    _expect(profile.to_dictionary() == missing_before, "missing vendor initialization is non-mutating")

    var definition := VendorStockDefinition.new()
    definition.vendor_id = VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID
    definition.restock_rule_id = &"restock:test_none"
    definition.restock_policy = VendorStockDefinition.RESTOCK_POLICY_FIXED_NO_RESTOCK
    definition.availability_conditions_declared = true
    definition.stock = {
        "itemdef:test_consumable": {
            "buy_price": 10,
            "sell_price": 4,
            "quantity": 5,
            "stackable": true,
        },
    }
    var catalog := VendorStockCatalog.new()
    catalog.definitions = [definition]

    var initialized: Dictionary = ProfileEconomyTransactionService.initialize_vendor_from_catalog(
        profile,
        catalog,
        VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID
    )
    _expect(bool(initialized.get("accepted", false)), "profile initializes exact authored vendor through item-layer API")
    var economy := EconomyState.new()
    _expect(economy.load_dictionary(profile.economy_state).is_empty(), "profile initialization commits a valid economy state")
    var vendor: VendorStockState = economy.get_vendor(VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID)
    _expect(vendor != null and int(vendor.get_entry(&"itemdef:test_consumable").get("quantity", -1)) == 5, "profile initialization preserves exact authored stock")

    var before_repeat: Dictionary = profile.to_dictionary()
    var repeated: Dictionary = ProfileEconomyTransactionService.initialize_vendor_from_catalog(
        profile,
        catalog,
        VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID
    )
    _expect(
        not bool(repeated.get("accepted", true))
        and StringName(repeated.get("reason_id", &"")) == ProfileEconomyTransactionService.REASON_VENDOR_ALREADY_INITIALIZED,
        "profile vendor initialization cannot reload-restock an existing vendor"
    )
    _expect(profile.to_dictionary() == before_repeat, "repeat vendor initialization is non-mutating")


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
