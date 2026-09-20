extends SceneTree

const MERCHANT_SCENE: PackedScene = preload("res://src/ui/merchant_menu.tscn")
const BLACKSMITH_SCENE: PackedScene = preload("res://src/ui/blacksmith_menu.tscn")

var _failures := 0
var _merchant_profile: ProfileSnapshot = null
var _blacksmith_profile: ProfileSnapshot = null
var _merchant_counter := 0
var _blacksmith_counter := 0
var _merchant_vendor_id: StringName = &"vendor:menu_test"


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var ownership := InputOwnership.new()
    get_root().add_child(ownership)
    await _test_merchant_menu(ownership)
    await _test_blacksmith_menu(ownership)
    ownership.queue_free()
    await process_frame
    if _failures == 0:
        print("MERCHANT BLACKSMITH MENU UI TEST PASS")
    else:
        push_error("MERCHANT BLACKSMITH MENU UI TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_merchant_menu(ownership: InputOwnership) -> void:
    _merchant_profile = ProfileCreationService.create_profile(1, "Merchant UI", "ranged")
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(_merchant_profile.item_state).is_empty(), "merchant UI fixture loads inventory")
    _expect(inventory.add_gold(100), "merchant UI fixture owns Gold")
    _expect(inventory.try_add_normal(&"item:merchant_owned", &"itemdef:potion", 2, true).get("accepted", false), "merchant UI fixture owns sellable stack")
    _merchant_profile.item_state = inventory.to_dictionary()
    var vendor := VendorStockState.new()
    _expect(vendor.configure(_merchant_vendor_id, {
        "itemdef:potion": {"buy_price": 10, "sell_price": 4, "quantity": 6, "stackable": true},
    }), "merchant UI fixture authors exact vendor stock")
    var economy := EconomyState.new()
    _expect(economy.set_vendor(vendor), "merchant UI fixture persists vendor stock")
    _merchant_profile.economy_state = economy.to_dictionary()

    var menu := MERCHANT_SCENE.instantiate() as MerchantMenu
    get_root().add_child(menu)
    await process_frame
    _expect(menu.configure(_merchant_profile, ownership, Callable(self, &"_merchant_buy"), Callable(self, &"_merchant_sell")), "Merchant menu configures reusable buy/sell callbacks")
    _expect(menu.open_service(_merchant_vendor_id), "Merchant menu opens exact persisted vendor")
    _expect(ownership.current_modal() == MerchantMenu.MODAL_ID and menu.active_vendor_id() == _merchant_vendor_id, "Merchant menu owns modal input and exact vendor identity")
    var snapshot := menu.current_snapshot()
    _expect((snapshot.get("stock_entries", []) as Array).size() == 1 and int(snapshot.get("gold", -1)) == 100, "Merchant menu renders persisted stock and current Gold")
    var stock := menu.get_node("Overlay/Panel/Layout/Body/StockColumn/Stock") as ItemList
    var sell := menu.get_node("Overlay/Panel/Layout/Body/SellColumn/Sell") as ItemList
    var quantity := menu.get_node("Overlay/Panel/Layout/Actions/Quantity") as SpinBox
    var buy_button := menu.get_node("Overlay/Panel/Layout/Actions/Buy") as Button
    var sell_button := menu.get_node("Overlay/Panel/Layout/Actions/Sell") as Button
    stock.select(0)
    menu.call("_on_stock_selected", 0)
    quantity.value = 2.0
    _expect(not buy_button.disabled and (menu.get_node("Overlay/Panel/Layout/Detail") as Label).text.contains("total 20 Gold"), "Merchant shows exact selected quantity cost before buying")
    buy_button.emit_signal("pressed")
    inventory = InventoryState.new()
    economy = EconomyState.new()
    _expect(inventory.load_dictionary(_merchant_profile.item_state).is_empty() and economy.load_dictionary(_merchant_profile.economy_state).is_empty(), "Merchant buy UI preserves persisted state validity")
    _expect(inventory.gold == 80 and inventory.get_total_quantity(&"itemdef:potion") == 4, "Merchant buy UI commits exact selected quantity at authored price")
    vendor = economy.get_vendor(_merchant_vendor_id)
    _expect(vendor != null and int(vendor.get_entry(&"itemdef:potion").get("quantity", -1)) == 4, "Merchant buy UI persists decremented vendor stock")

    _expect(sell.item_count > 0, "Merchant menu refresh exposes owned sellable stack")
    if sell.item_count > 0:
        sell.select(0)
        menu.call("_on_sell_selected", 0)
        quantity.value = 1.0
        _expect(not sell_button.disabled, "owned vendor-supported stack enables Merchant sell callback")
        sell_button.emit_signal("pressed")
    inventory = InventoryState.new()
    _expect(inventory.load_dictionary(_merchant_profile.item_state).is_empty() and inventory.gold == 84 and inventory.get_total_quantity(&"itemdef:potion") == 3, "Merchant sell UI credits exact authored sell value and removes selected quantity")
    _expect(inventory.spend_gold(84), "affordability fixture removes live Gold")
    _merchant_profile.item_state = inventory.to_dictionary()
    _expect(menu.set_profile(_merchant_profile), "Merchant refresh consumes current Gold")
    menu.call("_on_stock_selected", 0)
    _expect(buy_button.disabled and (menu.get_node("Overlay/Panel/Layout/Detail") as Label).text.contains("insufficient Gold"), "Merchant prevents unaffordable purchase before calling transaction owner")
    menu.close_menu()
    _expect(not ownership.is_modal_open(), "closing Merchant menu releases modal ownership")
    menu.queue_free()
    await process_frame


func _test_blacksmith_menu(ownership: InputOwnership) -> void:
    _blacksmith_profile = ProfileCreationService.create_profile(2, "Blacksmith UI", "melee")
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(_blacksmith_profile.item_state).is_empty(), "blacksmith UI fixture loads inventory")
    _expect(inventory.add_gold(75), "blacksmith UI fixture owns Gold")
    _expect(inventory.try_add_normal(&"item:blacksmith_target", &"itemdef:blacksmith_blade", 1, false, {
        "rarity": "rare",
        "upgrade_rank": 0,
        "affixes": ["affix:blacksmith_test"],
        "source_claim_id": "loot:blacksmith_blade",
    }).get("accepted", false), "blacksmith UI fixture owns authored upgrade target")
    _expect(inventory.try_add_normal(&"item:blacksmith_ore", &"itemdef:blacksmith_ore", 2, true).get("accepted", false), "blacksmith UI fixture owns exact material cost")
    _blacksmith_profile.item_state = inventory.to_dictionary()
    var recipe := _blacksmith_recipe()

    var menu := BLACKSMITH_SCENE.instantiate() as BlacksmithMenu
    get_root().add_child(menu)
    await process_frame
    _expect(menu.configure(_blacksmith_profile, ownership, [recipe], Callable(self, &"_blacksmith_upgrade")), "Blacksmith menu configures only caller-supplied authored recipe")
    _expect(menu.open_service(), "Blacksmith menu opens without inventing additional recipe content")
    _expect(ownership.current_modal() == BlacksmithMenu.MODAL_ID, "Blacksmith menu owns modal input")
    var snapshot := menu.current_snapshot()
    _expect(int(snapshot.get("authored_recipe_count", -1)) == 1 and (snapshot.get("upgrade_options", []) as Array).size() == 1, "Blacksmith menu exposes exact compatible authored upgrade option")
    var options := menu.get_node("Overlay/Panel/Layout/Options") as ItemList
    var upgrade_button := menu.get_node("Overlay/Panel/Layout/Upgrade") as Button
    options.select(0)
    menu.call("_on_option_selected", 0)
    _expect(not upgrade_button.disabled, "compatible and affordable authored option enables Blacksmith upgrade callback")
    var unaffordable := InventoryState.new()
    _expect(unaffordable.load_dictionary(_blacksmith_profile.item_state).is_empty() and unaffordable.spend_gold(75), "Blacksmith affordability fixture temporarily removes live Gold")
    _blacksmith_profile.item_state = unaffordable.to_dictionary()
    _expect(menu.set_profile(_blacksmith_profile), "Blacksmith preview refresh uses live inventory")
    menu.call("_on_option_selected", 0)
    _expect(upgrade_button.disabled and (menu.get_node("Overlay/Panel/Layout/Detail") as Label).text.contains("Missing Gold 25"), "Blacksmith disables unaffordable upgrade and reports exact Gold shortfall")
    _expect(unaffordable.add_gold(75), "Blacksmith restores fixture Gold without applying upgrade")
    _blacksmith_profile.item_state = unaffordable.to_dictionary()
    _expect(menu.set_profile(_blacksmith_profile), "Blacksmith rebuilds affordable option from restored inventory")
    menu.call("_on_option_selected", 0)
    _expect(not upgrade_button.disabled, "Blacksmith re-enables upgrade when the resources return")
    _expect(bool(unaffordable.try_remove_definition_quantity(&"itemdef:blacksmith_ore", 2).get("accepted", false)), "material-shortage fixture removes all upgrade ore")
    _blacksmith_profile.item_state = unaffordable.to_dictionary()
    _expect(menu.set_profile(_blacksmith_profile), "Blacksmith refreshes exact inventory material ownership")
    menu.call("_on_option_selected", 0)
    var shortage_text := (menu.get_node("Overlay/Panel/Layout/Detail") as Label).text
    _expect(upgrade_button.disabled and shortage_text.contains("itemdef:blacksmith_ore:1") and shortage_text.contains("Missing Gold 0"), "Blacksmith reports exact missing material and prevents upgrade even when Gold is sufficient")
    _expect(bool(unaffordable.try_add_normal(&"item:blacksmith_ore", &"itemdef:blacksmith_ore", 2, true).get("accepted", false)), "material-shortage fixture restores authored ore without upgrade")
    _blacksmith_profile.item_state = unaffordable.to_dictionary()
    _expect(menu.set_profile(_blacksmith_profile), "Blacksmith refreshes after material restoration")
    menu.call("_on_option_selected", 0)
    _expect(not upgrade_button.disabled, "Blacksmith enables upgrade only when Gold and materials both suffice")
    upgrade_button.emit_signal("pressed")
    inventory = InventoryState.new()
    _expect(inventory.load_dictionary(_blacksmith_profile.item_state).is_empty(), "Blacksmith UI mutation leaves inventory valid")
    _expect(inventory.gold == 50 and inventory.get_total_quantity(&"itemdef:blacksmith_ore") == 1 and inventory.get_upgrade_rank(&"item:blacksmith_target") == 1, "Blacksmith UI commits exact caller-authored costs and next rank")
    menu.close_menu()
    _expect(not ownership.is_modal_open(), "closing Blacksmith menu releases modal ownership")
    menu.queue_free()
    await process_frame


func _merchant_buy(definition_id: StringName, amount: int) -> Dictionary:
    _merchant_counter += 1
    return ProfileEconomyTransactionService.buy(
        _merchant_profile,
        _merchant_vendor_id,
        StringName("transaction:merchant_ui:buy:%d" % _merchant_counter),
        definition_id,
        StringName("item:merchant_ui_purchase:%d" % _merchant_counter),
        amount
    )


func _merchant_sell(item_instance_id: StringName, amount: int) -> Dictionary:
    _merchant_counter += 1
    return ProfileEconomyTransactionService.sell(
        _merchant_profile,
        _merchant_vendor_id,
        StringName("transaction:merchant_ui:sell:%d" % _merchant_counter),
        item_instance_id,
        amount
    )


func _blacksmith_upgrade(location_id: StringName, item_instance_id: StringName, recipe: UpgradeRecipeDefinition) -> Dictionary:
    _blacksmith_counter += 1
    return ProfileUpgradeTransactionService.upgrade(
        _blacksmith_profile,
        location_id,
        StringName("transaction:blacksmith_ui:upgrade:%d" % _blacksmith_counter),
        item_instance_id,
        recipe
    )


func _blacksmith_recipe() -> UpgradeRecipeDefinition:
    var recipe := UpgradeRecipeDefinition.new()
    recipe.recipe_id = &"upgrade:blacksmith_blade:0_to_1"
    recipe.compatible_definition_ids = [&"itemdef:blacksmith_blade"]
    recipe.compatible_rarities = [&"rare"]
    recipe.source_rank = 0
    recipe.source_rank_declared = true
    recipe.result_rank = 1
    recipe.result_rank_declared = true
    recipe.maximum_rank = 3
    recipe.maximum_rank_declared = true
    recipe.gold_cost_declared = true
    recipe.prerequisites_declared = true
    recipe.gold_cost = 25
    recipe.material_costs = {"itemdef:blacksmith_ore": 1}
    recipe.stat_changes = {"attack_power": 1}
    return recipe


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
