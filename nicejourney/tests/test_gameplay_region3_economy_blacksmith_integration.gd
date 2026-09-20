extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TEST_SAVE_ROOT: String = "user://tests/gameplay_region3_economy_blacksmith_integration"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service := SaveService.new(TEST_SAVE_ROOT)
    save_service.delete_slot(1)

    var profile := ProfileCreationService.create_profile(1, "Economy Integration", "melee")
    _expect(profile != null, "economy integration fixture creates a profile")
    if profile == null:
        quit(1)
        return

    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "economy integration fixture loads inventory")
    _expect(inventory.add_gold(100), "economy integration fixture owns explicit Gold")
    _expect(inventory.try_add_normal(&"item:economy_blade", &"itemdef:test_blade", 1, false, {
        "rarity": "rare",
        "upgrade_rank": 0,
        "affixes": [&"affix:test"],
        "source_claim_id": &"loot:economy_blade",
    }).get("accepted", false), "economy integration fixture owns an upgrade target")
    _expect(inventory.try_add_normal(&"item:economy_ore", &"itemdef:test_ore", 4, true).get("accepted", false), "economy integration fixture owns upgrade material")
    profile.item_state = inventory.to_dictionary()
    _expect(save_service.save_profile(1, profile) == OK, "economy integration fixture persists pre-gameplay profile")

    var vendor_catalog := VendorStockCatalog.new()
    var vendor_definition := VendorStockDefinition.new()
    vendor_definition.vendor_id = GameplayRoot.REGION3_GENERAL_MERCHANT_VENDOR_ID
    vendor_definition.restock_rule_id = &"restock:test_none"
    vendor_definition.restock_policy = VendorStockDefinition.RESTOCK_POLICY_FIXED_NO_RESTOCK
    vendor_definition.availability_conditions_declared = true
    vendor_definition.stock = {
        "itemdef:test_potion": {
            "buy_price": 10,
            "sell_price": 4,
            "quantity": 5,
            "stackable": true,
        },
    }
    vendor_catalog.definitions = [vendor_definition]
    _expect(bool(vendor_catalog.general_merchant_readiness().get("available", false)), "explicit General Merchant catalog is production-ready for the fixture")

    var recipe := _recipe()
    var recipe_catalog := UpgradeRecipeCatalog.new()
    recipe_catalog.recipes = [recipe]
    _expect(bool(recipe_catalog.readiness().get("available", false)), "explicit Blacksmith recipe catalog is production-ready for the fixture")

    var categories := ItemCategoryCatalog.new()
    categories.definition_categories = {
        "itemdef:test_potion": ItemCategoryCatalog.CATEGORY_CONSUMABLE,
        "itemdef:test_blade": ItemCategoryCatalog.CATEGORY_WEAPON,
        "itemdef:test_ore": ItemCategoryCatalog.CATEGORY_MATERIAL,
    }

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.vendor_stock_catalog = vendor_catalog
    gameplay.blacksmith_recipe_catalog = recipe_catalog
    gameplay.item_category_catalog = categories
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save_service, 1), "economy integration fixture supplies save ownership")
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.ensure_starting_world(), "economy integration fixture enters authored Region 3")

    var merchant := gameplay.region3_town_session_host.active_runtime_root.get_node("GeneralMerchant/ServiceInteraction") as Region3FunctionalServiceInteraction
    _expect(merchant != null, "authored General Merchant owns a physical service interaction")
    if merchant != null:
        merchant.call("_on_body_entered", gameplay.player)
        var merchant_admission := merchant.request_service(&"interaction:test_general_merchant_authored")
        _expect(bool(merchant_admission.get("admitted", false)), "physical General Merchant request passes shared interaction admission")
    _expect(
        bool(gameplay.last_region3_service_request.get("service_opened", false))
        and gameplay.merchant_menu.is_open(),
        "General Merchant opens only after the authored stock catalog initializes its persisted vendor state"
    )

    var economy := EconomyState.new()
    _expect(economy.load_dictionary(profile.economy_state).is_empty(), "authored merchant initialization preserves economy state validity")
    var vendor := economy.get_vendor(GameplayRoot.REGION3_GENERAL_MERCHANT_VENDOR_ID)
    _expect(vendor != null and int(vendor.get_entry(&"itemdef:test_potion").get("quantity", -1)) == 5, "live merchant uses the exact authored initial stock quantity")

    var buy := gameplay.request_region3_merchant_buy(&"itemdef:test_potion", 1)
    _expect(bool(buy.get("accepted", false)), "live merchant purchase uses the authoritative profile transaction service")
    inventory = InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "post-purchase inventory remains valid")
    _expect(inventory.gold == 90 and inventory.get_total_quantity(&"itemdef:test_potion") == 1, "live merchant purchase uses the exact authored price and item definition")
    gameplay.merchant_menu.close_menu()
    if merchant != null:
        merchant.call("_on_body_exited", gameplay.player)

    var blacksmith := gameplay.region3_town_session_host.active_runtime_root.get_node("Blacksmith/ServiceInteraction") as Region3FunctionalServiceInteraction
    _expect(blacksmith != null, "authored Blacksmith owns a physical service interaction")
    if blacksmith != null:
        blacksmith.call("_on_body_entered", gameplay.player)
        var blacksmith_admission := blacksmith.request_service(&"interaction:test_blacksmith_authored")
        _expect(bool(blacksmith_admission.get("admitted", false)), "physical Blacksmith request passes shared interaction admission")
    _expect(
        bool(gameplay.last_region3_service_request.get("service_opened", false))
        and gameplay.blacksmith_menu.is_open(),
        "Blacksmith opens only when a validated authored recipe catalog is assigned"
    )

    var authoritative := recipe_catalog.get_recipe(recipe.recipe_id)
    var upgrade := gameplay.request_region3_blacksmith_upgrade(
        ProfileUpgradeTransactionService.LOCATION_INVENTORY,
        &"item:economy_blade",
        authoritative
    )
    _expect(bool(upgrade.get("accepted", false)), "live Blacksmith commits through the authoritative profile upgrade service")
    inventory = InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "post-upgrade inventory remains valid")
    _expect(inventory.gold == 60, "live Blacksmith deducts the exact authored Gold cost")
    _expect(inventory.get_total_quantity(&"itemdef:test_ore") == 2, "live Blacksmith consumes the exact authored material quantity")
    _expect(inventory.get_upgrade_rank(&"item:economy_blade") == 1, "live Blacksmith preserves item identity and advances exactly one authored rank")
    var upgraded := inventory.get_normal_slot(&"item:economy_blade")
    _expect(
        String(upgraded.get("rarity", "")) == "rare"
        and String(upgraded.get("source_claim_id", "")) == "loot:economy_blade",
        "live Blacksmith preserves realized rarity and provenance metadata"
    )

    gameplay.blacksmith_menu.close_menu()
    if blacksmith != null:
        blacksmith.call("_on_body_exited", gameplay.player)

    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "Merchant/Blacksmith integration preserves whole-profile validity")

    gameplay.queue_free()
    await process_frame
    save_service.delete_slot(1)
    if _failures == 0:
        print("GAMEPLAY REGION 3 ECONOMY BLACKSMITH INTEGRATION TEST PASS")
    else:
        push_error("GAMEPLAY REGION 3 ECONOMY BLACKSMITH INTEGRATION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _recipe() -> UpgradeRecipeDefinition:
    var recipe := UpgradeRecipeDefinition.new()
    recipe.recipe_id = &"upgrade:test_blade:0_to_1"
    recipe.compatible_definition_ids = [&"itemdef:test_blade"]
    recipe.compatible_rarities = [&"rare"]
    recipe.source_rank = 0
    recipe.source_rank_declared = true
    recipe.result_rank = 1
    recipe.result_rank_declared = true
    recipe.maximum_rank = 3
    recipe.maximum_rank_declared = true
    recipe.gold_cost = 30
    recipe.gold_cost_declared = true
    recipe.prerequisites_declared = true
    recipe.material_costs = {"itemdef:test_ore": 2}
    recipe.stat_changes = {"attack_power": 1}
    return recipe


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
