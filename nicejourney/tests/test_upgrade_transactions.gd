extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_recipe_validation_and_preview()
    _test_inventory_upgrade_commit_and_rejections()
    _test_storage_upgrade_commit()
    _test_equipped_upgrade_commit()
    if _failures == 0:
        print("UPGRADE TRANSACTIONS TEST PASS")
    else:
        push_error("UPGRADE TRANSACTIONS TEST FAILURES: %d" % _failures)
    quit(_failures)

func _recipe() -> UpgradeRecipeDefinition:
    var recipe := UpgradeRecipeDefinition.new()
    recipe.recipe_id = &"upgrade:starter_sword:0_to_1"
    recipe.compatible_definition_ids = [&"itemdef:starter_sword"]
    recipe.compatible_rarities = [&"rare"]
    recipe.source_rank = 0
    recipe.source_rank_declared = true
    recipe.result_rank = 1
    recipe.result_rank_declared = true
    recipe.maximum_rank = 3
    recipe.maximum_rank_declared = true
    recipe.gold_cost_declared = true
    recipe.prerequisites_declared = true
    recipe.gold_cost = 75
    recipe.material_costs = {"itemdef:upgrade_ore": 3}
    recipe.stat_changes = {"attack_power": 2}
    return recipe

func _gear_metadata(rank: int = 0) -> Dictionary:
    return {
        "rarity": "rare",
        "affixes": ["affix:sharp"],
        "upgrade_rank": rank,
        "source_claim_id": "loot:starter_sword",
    }

func _test_recipe_validation_and_preview() -> void:
    var recipe := _recipe()
    _expect(recipe.validate_definition().is_empty(), "valid deterministic upgrade recipe passes validation")
    _expect(recipe.validate_authored_definition().is_empty(), "fully declared upgrade recipe passes strict production authoring validation")
    var preview := recipe.preview(&"itemdef:starter_sword", &"rare", 0)
    _expect(bool(preview["compatible"]), "upgrade preview reports compatible gear")
    _expect(int(preview["before_rank"]) == 0 and int(preview["after_rank"]) == 1, "upgrade preview exposes exact before/after rank")
    _expect(int(preview["gold_cost"]) == 75 and int((preview["material_costs"] as Dictionary)["itemdef:upgrade_ore"]) == 3, "upgrade preview exposes exact Gold/material cost")
    _expect(int((preview["stat_changes"] as Dictionary)["attack_power"]) == 2, "upgrade preview exposes deterministic stat change")

    var invalid := _recipe()
    invalid.result_rank = 2
    _expect(not invalid.validate_definition().is_empty(), "recipe cannot skip an upgrade rank")

func _test_inventory_upgrade_commit_and_rejections() -> void:
    var inventory := InventoryState.new()
    var ledger := ClaimLedger.new()
    var recipe := _recipe()
    _expect(inventory.add_gold(200), "upgrade fixture receives Gold")
    _expect(inventory.try_add_normal(&"item:sword_a", &"itemdef:starter_sword", 1, false, _gear_metadata())["accepted"], "upgrade fixture owns realized gear")
    _expect(inventory.try_add_normal(&"item:ore_a", &"itemdef:upgrade_ore", 5, true)["accepted"], "upgrade fixture owns upgrade materials")

    var result := UpgradeTransactionService.upgrade_inventory_item(inventory, ledger, &"upgrade_tx:inventory:1", &"item:sword_a", recipe)
    _expect(bool(result["accepted"]), "inventory-resident gear upgrade commits atomically")
    _expect(inventory.gold == 125, "upgrade deducts exact Gold cost once")
    _expect(inventory.get_total_quantity(&"itemdef:upgrade_ore") == 2, "upgrade consumes exact material count once")
    _expect(inventory.get_upgrade_rank(&"item:sword_a") == 1, "upgrade mutates existing item rank without replacing identity")
    var upgraded := inventory.get_normal_slot(&"item:sword_a")
    _expect(String(upgraded.get("rarity", "")) == "rare" and (upgraded.get("affixes", []) as Array) == ["affix:sharp"], "upgrade preserves realized rarity/affixes")
    _expect(String(upgraded.get("source_claim_id", "")) == "loot:starter_sword", "upgrade preserves item provenance/source claim")
    _expect(ledger.is_claimed(&"upgrade_tx:inventory:1"), "upgrade transaction identity is committed for repeat-click resistance")

    var after_first := inventory.to_dictionary()
    var duplicate := UpgradeTransactionService.upgrade_inventory_item(inventory, ledger, &"upgrade_tx:inventory:1", &"item:sword_a", recipe)
    _expect(not bool(duplicate["accepted"]) and duplicate["reason_id"] == UpgradeTransactionService.REASON_DUPLICATE_TRANSACTION, "duplicate upgrade transaction is rejected")
    _expect(inventory.to_dictionary() == after_first, "duplicate upgrade cannot consume Gold/materials again")

    var wrong_rank := UpgradeTransactionService.upgrade_inventory_item(inventory, ledger, &"upgrade_tx:inventory:wrong_rank", &"item:sword_a", recipe)
    _expect(not bool(wrong_rank["accepted"]) and wrong_rank["reason_id"] == UpgradeTransactionService.REASON_RECIPE_INCOMPATIBLE, "recipe source-rank mismatch is rejected before costs")

    var poor := InventoryState.new()
    var poor_ledger := ClaimLedger.new()
    _expect(poor.add_gold(74), "insufficient-Gold fixture is below recipe cost")
    _expect(poor.try_add_normal(&"item:sword_poor", &"itemdef:starter_sword", 1, false, _gear_metadata())["accepted"], "insufficient-Gold fixture owns compatible gear")
    _expect(poor.try_add_normal(&"item:ore_poor", &"itemdef:upgrade_ore", 3, true)["accepted"], "insufficient-Gold fixture owns materials")
    var poor_before := poor.to_dictionary()
    var poor_result := UpgradeTransactionService.upgrade_inventory_item(poor, poor_ledger, &"upgrade_tx:poor", &"item:sword_poor", recipe)
    _expect(not bool(poor_result["accepted"]) and poor_result["reason_id"] == UpgradeTransactionService.REASON_INSUFFICIENT_GOLD, "insufficient Gold rejects upgrade")
    _expect(poor.to_dictionary() == poor_before and not poor_ledger.is_claimed(&"upgrade_tx:poor"), "rejected Gold check is atomic and does not consume transaction identity")

    var no_materials := InventoryState.new()
    var no_material_ledger := ClaimLedger.new()
    _expect(no_materials.add_gold(200), "material-rejection fixture owns enough Gold")
    _expect(no_materials.try_add_normal(&"item:sword_nomats", &"itemdef:starter_sword", 1, false, _gear_metadata())["accepted"], "material-rejection fixture owns compatible gear")
    _expect(no_materials.try_add_normal(&"item:ore_nomats", &"itemdef:upgrade_ore", 2, true)["accepted"], "material-rejection fixture is below material requirement")
    var no_materials_before := no_materials.to_dictionary()
    var no_materials_result := UpgradeTransactionService.upgrade_inventory_item(no_materials, no_material_ledger, &"upgrade_tx:no_materials", &"item:sword_nomats", recipe)
    _expect(not bool(no_materials_result["accepted"]) and no_materials_result["reason_id"] == UpgradeTransactionService.REASON_INSUFFICIENT_MATERIALS, "insufficient materials reject upgrade")
    _expect(no_materials.to_dictionary() == no_materials_before, "material rejection changes neither Gold nor item ownership")

func _test_storage_upgrade_commit() -> void:
    var inventory := InventoryState.new()
    var storage := StorageState.new()
    var ledger := ClaimLedger.new()
    var recipe := _recipe()
    _expect(inventory.add_gold(200), "stored-upgrade fixture receives Gold")
    _expect(inventory.try_add_normal(&"item:ore_storage", &"itemdef:upgrade_ore", 4, true)["accepted"], "stored-upgrade fixture owns materials in portable inventory")
    _expect(storage.try_add_normal(&"item:sword_stored", &"itemdef:starter_sword", 1, false, _gear_metadata())["accepted"], "stored-upgrade fixture owns realized gear in hub storage")

    var result := UpgradeTransactionService.upgrade_storage_item(inventory, storage, ledger, &"upgrade_tx:storage:1", &"item:sword_stored", recipe)
    _expect(bool(result["accepted"]), "storage-resident gear upgrades without moving item location")
    _expect(storage.get_upgrade_rank(&"item:sword_stored") == 1, "stored item preserves identity/location and receives new rank")
    _expect(inventory.gold == 125 and inventory.get_total_quantity(&"itemdef:upgrade_ore") == 1, "stored upgrade consumes portable Gold/material costs exactly once")
    var stored := storage.get_normal_slot(&"item:sword_stored")
    _expect(String(stored.get("rarity", "")) == "rare" and String(stored.get("source_claim_id", "")) == "loot:starter_sword", "stored upgrade preserves realized metadata/provenance")


func _test_equipped_upgrade_commit() -> void:
    var inventory := InventoryState.new()
    var equipment := EquipmentState.new()
    var ledger := ClaimLedger.new()
    var recipe := _recipe()
    _expect(inventory.add_gold(200), "equipped-upgrade fixture receives Gold")
    _expect(inventory.try_add_normal(&"item:ore_equipped", &"itemdef:upgrade_ore", 4, true)["accepted"], "equipped-upgrade fixture owns materials in portable inventory")
    var equipped_item := {
        "item_instance_id": &"item:sword_equipped",
        "definition_id": &"itemdef:starter_sword",
        "quantity": 1,
        "stackable": false,
        "rarity": "rare",
        "affixes": ["affix:sharp"],
        "upgrade_rank": 0,
        "source_claim_id": "loot:starter_sword",
    }
    _expect(equipment.set_item(EquipmentSlotIdentityValidator.SLOT_WEAPON, equipped_item), "equipped-upgrade fixture owns realized gear in weapon slot")

    var result := UpgradeTransactionService.upgrade_equipped_item(
        inventory,
        equipment,
        ledger,
        &"upgrade_tx:equipped:1",
        &"item:sword_equipped",
        recipe
    )
    _expect(bool(result["accepted"]), "equipped gear upgrade commits atomically")
    _expect(StringName(result.get("slot_id", &"")) == EquipmentSlotIdentityValidator.SLOT_WEAPON, "equipped upgrade reports exact preserved equipment slot")
    var upgraded := equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON)
    _expect(StringName(String(upgraded.get("item_instance_id", &""))) == &"item:sword_equipped" and int(upgraded.get("upgrade_rank", -1)) == 1, "equipped upgrade preserves exact identity/location and advances one rank")
    _expect(inventory.gold == 125 and inventory.get_total_quantity(&"itemdef:upgrade_ore") == 1, "equipped upgrade consumes portable Gold/material costs exactly once")
    _expect(String(upgraded.get("rarity", "")) == "rare" and String(upgraded.get("source_claim_id", "")) == "loot:starter_sword", "equipped upgrade preserves realized metadata/provenance")

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
