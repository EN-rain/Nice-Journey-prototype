extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Blacksmith Boundary", "melee")
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "blacksmith fixture loads profile inventory")
    _expect(inventory.add_gold(120), "blacksmith fixture owns Gold")
    _expect(inventory.try_add_normal(&"item:upgrade_target", &"itemdef:test_blade", 1, false, {
        "rarity": "rare",
        "upgrade_rank": 0,
        "affixes": ["affix:test"],
        "source_claim_id": "loot:test_blade",
    }).get("accepted", false), "blacksmith fixture owns exact upgrade target")
    _expect(inventory.try_add_normal(&"item:upgrade_material", &"itemdef:test_ore", 4, true).get("accepted", false), "blacksmith fixture owns upgrade material")
    profile.item_state = inventory.to_dictionary()
    var recipe := _recipe()
    var recipes: Array[UpgradeRecipeDefinition] = [recipe]

    var incomplete_recipe := _recipe()
    incomplete_recipe.gold_cost_declared = false
    var incomplete_before := profile.to_dictionary()
    var incomplete_result := ProfileUpgradeTransactionService.upgrade(
        profile,
        ProfileUpgradeTransactionService.LOCATION_INVENTORY,
        &"transaction:blacksmith:incomplete_recipe",
        &"item:upgrade_target",
        incomplete_recipe
    )
    _expect(not bool(incomplete_result.get("accepted", true)) and StringName(incomplete_result.get("reason_id", &"")) == ProfileUpgradeTransactionService.REASON_RECIPE_CONTENT_UNAVAILABLE, "profile Blacksmith rejects structurally plausible but incompletely authored recipe content")
    _expect(profile.to_dictionary() == incomplete_before, "incomplete recipe rejection is non-mutating")

    var view := BlacksmithViewService.build_view(profile, recipes)
    _expect(bool(view.get("accepted", false)) and int(view.get("authored_recipe_count", -1)) == 1, "blacksmith view accepts caller-supplied authored recipe set")
    var options := view.get("upgrade_options", []) as Array
    _expect(options.size() == 1, "blacksmith view exposes only an owned item compatible with supplied recipe")
    var option := options[0] as Dictionary if not options.is_empty() else {}
    _expect(StringName(String(option.get("recipe_id", &""))) == recipe.recipe_id and int(option.get("gold_cost", -1)) == 30, "blacksmith preview preserves exact recipe identity and Gold cost")
    _expect(int((option.get("material_costs", {}) as Dictionary).get("itemdef:test_ore", -1)) == 2, "blacksmith preview preserves exact authored material cost")

    var no_recipe_view := BlacksmithViewService.build_view(profile, [])
    _expect(bool(no_recipe_view.get("accepted", false)) and (no_recipe_view.get("upgrade_options", []) as Array).is_empty(), "empty recipe input remains an honest no-upgrade state instead of fabricating recipes")

    var upgraded := ProfileUpgradeTransactionService.upgrade(
        profile,
        ProfileUpgradeTransactionService.LOCATION_INVENTORY,
        &"transaction:blacksmith:upgrade",
        &"item:upgrade_target",
        recipe
    )
    _expect(bool(upgraded.get("accepted", false)) and not bool(upgraded.get("durable", true)), "profile Blacksmith upgrade commits through authoritative service as live unbanked state")
    inventory = InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "upgraded inventory remains valid")
    _expect(inventory.gold == 90 and inventory.get_total_quantity(&"itemdef:test_ore") == 2, "upgrade consumes exact authored Gold/material costs")
    _expect(inventory.get_upgrade_rank(&"item:upgrade_target") == 1, "upgrade preserves item identity and commits exact next rank")
    var upgraded_item := inventory.get_normal_slot(&"item:upgrade_target")
    _expect(String(upgraded_item.get("rarity", "")) == "rare" and String(upgraded_item.get("source_claim_id", "")) == "loot:test_blade", "upgrade preserves realized item metadata/provenance")

    var equipment := EquipmentState.new()
    _expect(equipment.load_dictionary(profile.equipment_state).is_empty(), "blacksmith fixture loads equipment state")
    var equipped_target := {
        "item_instance_id": &"item:equipped_upgrade_target",
        "definition_id": &"itemdef:test_blade",
        "quantity": 1,
        "stackable": false,
        "rarity": "rare",
        "upgrade_rank": 0,
        "affixes": ["affix:test"],
        "source_claim_id": "loot:equipped_test_blade",
    }
    _expect(equipment.set_item(EquipmentSlotIdentityValidator.SLOT_ARMOR, equipped_target), "blacksmith fixture owns exact equipped upgrade target")
    profile.equipment_state = equipment.to_dictionary()
    var equipped_view := BlacksmithViewService.build_view(profile, recipes)
    _expect(bool(equipped_view.get("accepted", false)), "blacksmith view accepts equipped ownership state")
    var equipped_option := _find_location(equipped_view.get("upgrade_options", []) as Array, ProfileUpgradeTransactionService.LOCATION_EQUIPMENT)
    _expect(not equipped_option.is_empty() and StringName(String(equipped_option.get("item_instance_id", &""))) == &"item:equipped_upgrade_target", "blacksmith view exposes caller-authored upgrade for equipped gear without moving it")

    var equipped_upgrade := ProfileUpgradeTransactionService.upgrade(
        profile,
        ProfileUpgradeTransactionService.LOCATION_EQUIPMENT,
        &"transaction:blacksmith:equipped_upgrade",
        &"item:equipped_upgrade_target",
        recipe
    )
    _expect(bool(equipped_upgrade.get("accepted", false)), "profile Blacksmith upgrade supports equipped location")
    inventory = InventoryState.new()
    equipment = EquipmentState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty() and equipment.load_dictionary(profile.equipment_state).is_empty(), "equipped profile upgrade preserves item/equipment state validity")
    var post_equipped := equipment.get_item(EquipmentSlotIdentityValidator.SLOT_ARMOR)
    _expect(StringName(String(post_equipped.get("item_instance_id", &""))) == &"item:equipped_upgrade_target" and int(post_equipped.get("upgrade_rank", -1)) == 1, "profile equipped upgrade preserves exact slot/identity and advances rank")
    _expect(inventory.gold == 60 and inventory.get_total_quantity(&"itemdef:test_ore") == 0, "profile equipped upgrade consumes exact caller-authored portable costs")
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "Blacksmith profile wrapper preserves whole-profile validity")

    if _failures == 0:
        print("PROFILE UPGRADE UI BOUNDARY TEST PASS")
    else:
        push_error("PROFILE UPGRADE UI BOUNDARY TEST FAILURES: %d" % _failures)
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
    recipe.gold_cost_declared = true
    recipe.prerequisites_declared = true
    recipe.gold_cost = 30
    recipe.material_costs = {"itemdef:test_ore": 2}
    recipe.stat_changes = {"attack_power": 1}
    return recipe


func _find_location(options: Array, location_id: StringName) -> Dictionary:
    for raw_option: Variant in options:
        if raw_option is Dictionary and StringName(String((raw_option as Dictionary).get("location_id", &""))) == location_id:
            return (raw_option as Dictionary).duplicate(true)
    return {}


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
