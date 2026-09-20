extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TEST_SAVE_ROOT: String = "user://tests/gameplay_region3_merchant_inventory_flow"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service := SaveService.new(TEST_SAVE_ROOT)
    save_service.delete_slot(1)

    var profile := ProfileCreationService.create_profile(1, "Merchant Inventory", "melee")
    _expect(profile != null, "Merchant/Inventory fixture creates a profile")
    if profile == null:
        quit(1)
        return

    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "Merchant/Inventory fixture loads starter inventory")
    _expect(inventory.add_gold(100), "Merchant/Inventory fixture owns authored Gold")
    _expect(
        bool(inventory.try_add_normal(&"item:gameplay_consumable", &"itemdef:potion", 2, true).get("accepted", false)),
        "Merchant/Inventory fixture owns a persisted sellable/quick-reference stack"
    )
    profile.item_state = inventory.to_dictionary()

    var vendor := VendorStockState.new()
    _expect(vendor.configure(GameplayRoot.REGION3_GENERAL_MERCHANT_VENDOR_ID, {
        "itemdef:potion": {"buy_price": 10, "sell_price": 4, "quantity": 6, "stackable": true},
    }), "Merchant/Inventory fixture authors exact General Merchant stock")
    var economy := EconomyState.new()
    _expect(economy.set_vendor(vendor), "Merchant/Inventory fixture persists the General Merchant vendor")
    profile.economy_state = economy.to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "Merchant/Inventory fixture profile validates before gameplay")
    _expect(save_service.save_profile(1, profile) == OK, "Merchant/Inventory fixture persists pre-gameplay state")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.region3_playtest_content = null # Intentional missing-category fixture with independently persisted Merchant stock.
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save_service, 1), "Merchant/Inventory fixture supplies save context")
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.ensure_starting_world(), "Merchant/Inventory fixture enters authored Region 3")

    await _exercise_inventory(gameplay, profile)
    await _exercise_merchant(gameplay, profile)

    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "GameplayRoot Merchant/Inventory callbacks preserve whole-profile validity")
    gameplay.queue_free()
    await process_frame
    save_service.delete_slot(1)
    if _failures == 0:
        print("GAMEPLAY REGION 3 MERCHANT INVENTORY FLOW TEST PASS")
    else:
        push_error("GAMEPLAY REGION 3 MERCHANT INVENTORY FLOW TEST FAILURES: %d" % _failures)
    quit(_failures)


func _exercise_inventory(gameplay: GameplayRoot, profile: ProfileSnapshot) -> void:
    var menu := gameplay.inventory_menu as InventoryMenu
    _expect(menu != null and menu.open_menu(), "GameplayRoot Inventory opens with worker-2 mutation callbacks wired")
    if menu == null or not menu.is_open():
        return

    var equipment_list := menu.get_node("Overlay/Panel/Scroller/Layout/Body/Right/Equipment") as ItemList
    var unequip_button := menu.get_node("Overlay/Panel/Scroller/Layout/EquipRow/Unequip") as Button
    var equip_button := menu.get_node("Overlay/Panel/Scroller/Layout/EquipRow/Equip") as Button
    var equip_target := menu.get_node("Overlay/Panel/Scroller/Layout/EquipRow/Target") as OptionButton
    var quick_target := menu.get_node("Overlay/Panel/Scroller/Layout/QuickRow/Target") as OptionButton
    var quick_bind := menu.get_node("Overlay/Panel/Scroller/Layout/QuickRow/Bind") as Button
    var quick_clear := menu.get_node("Overlay/Panel/Scroller/Layout/QuickRow/Clear") as Button

    var weapon_index := _equipment_index(equipment_list, EquipmentSlotIdentityValidator.SLOT_WEAPON)
    _expect(weapon_index >= 0, "GameplayRoot Inventory exposes the equipped starter weapon slot")
    if weapon_index >= 0:
        equipment_list.select(weapon_index)
        menu.call("_on_equipment_selected", weapon_index)
        _expect(not unequip_button.disabled, "GameplayRoot Inventory enables authoritative unequip callback")
        unequip_button.pressed.emit()

    var equipment := EquipmentState.new()
    var inventory := InventoryState.new()
    _expect(
        equipment.load_dictionary(profile.equipment_state).is_empty()
        and inventory.load_dictionary(profile.item_state).is_empty(),
        "GameplayRoot unequip callback leaves inventory/equipment state valid"
    )
    var sword_instance := StringName("%s:item:%s" % [profile.profile_id, String(StarterKitCatalog.WEAPON_MELEE_SWORD)])
    _expect(
        equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON).is_empty()
        and not inventory.get_normal_slot(sword_instance).is_empty(),
        "GameplayRoot unequip moves the exact starter weapon instance into normal inventory"
    )

    var sword_button := _grid_button_for(menu, sword_instance)
    _expect(sword_button != null, "unequipped weapon is rendered as an Inventory grid item")
    if sword_button != null:
        sword_button.pressed.emit()
        _select_option_metadata(equip_target, EquipmentSlotIdentityValidator.SLOT_WEAPON)
        _expect(not equip_button.disabled, "GameplayRoot Inventory enables authoritative equip callback")
        equip_button.pressed.emit()
    equipment = EquipmentState.new()
    _expect(
        equipment.load_dictionary(profile.equipment_state).is_empty()
        and StringName(String(equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON).get("item_instance_id", &""))) == sword_instance,
        "GameplayRoot equip restores the exact weapon instance to its fixed slot"
    )

    var consumable_button := _grid_button_for(menu, &"item:gameplay_consumable")
    _expect(consumable_button != null, "GameplayRoot Inventory retains the owned quick-reference source")
    if consumable_button != null:
        consumable_button.pressed.emit()
        quick_target.select(1)
        _expect(quick_bind.disabled, "GameplayRoot Inventory keeps new quick-slot assignment disabled without authored consumable-category authority")
        var blocked_bind := gameplay.request_inventory_quick_slot(1, &"item:gameplay_consumable")
        _expect(
            not bool(blocked_bind.get("accepted", true))
            and StringName(blocked_bind.get("reason_id", &"")) == ProfileInventoryMutationService.REASON_CATEGORY_AUTHORITY_MISSING,
            "GameplayRoot direct quick-slot request fails closed when consumable category is unauthored"
        )
    inventory = InventoryState.new()
    _expect(
        inventory.load_dictionary(profile.item_state).is_empty()
        and inventory.quick_slots[1] == &"",
        "rejected quick-slot assignment leaves ownership and references unchanged"
    )
    _expect(not quick_clear.disabled, "GameplayRoot Inventory exposes explicit quick-reference clear")
    quick_clear.pressed.emit()
    inventory = InventoryState.new()
    _expect(
        inventory.load_dictionary(profile.item_state).is_empty() and inventory.quick_slots[1] == &"",
        "GameplayRoot quick callback clears the reference without changing item ownership"
    )
    menu.close_menu()
    await process_frame


func _exercise_merchant(gameplay: GameplayRoot, profile: ProfileSnapshot) -> void:
    var host := gameplay.region3_town_session_host
    var merchant_interaction := host.active_runtime_root.get_node("GeneralMerchant/ServiceInteraction") as Region3FunctionalServiceInteraction
    _expect(merchant_interaction != null, "authored General Merchant exposes the generic service interaction")
    if merchant_interaction == null:
        return
    merchant_interaction.call("_on_body_entered", gameplay.player)
    var request := merchant_interaction.request_service(&"interaction:test_gameplay_general_merchant")
    _expect(bool(request.get("admitted", false)), "General Merchant request passes authored service admission")
    _expect(
        bool(gameplay.last_region3_service_request.get("service_opened", false))
        and gameplay.merchant_menu.is_open()
        and gameplay.merchant_menu.active_vendor_id() == GameplayRoot.REGION3_GENERAL_MERCHANT_VENDOR_ID,
        "GameplayRoot opens MerchantMenu only for the exact persisted General Merchant vendor"
    )
    _expect(
        Region3ServiceDiscoveryService.is_discovered(profile, &"r3:functional:04"),
        "admitted General Merchant request also records its live service discovery"
    )

    var menu := gameplay.merchant_menu
    var stock := menu.get_node("Overlay/Panel/Layout/Body/StockColumn/Stock") as ItemList
    var sell := menu.get_node("Overlay/Panel/Layout/Body/SellColumn/Sell") as ItemList
    var quantity := menu.get_node("Overlay/Panel/Layout/Actions/Quantity") as SpinBox
    var buy_button := menu.get_node("Overlay/Panel/Layout/Actions/Buy") as Button
    var sell_button := menu.get_node("Overlay/Panel/Layout/Actions/Sell") as Button
    _expect(stock.item_count == 1, "MerchantMenu renders only the persisted General Merchant stock")
    if stock.item_count > 0:
        stock.select(0)
        menu.call("_on_stock_selected", 0)
        quantity.value = 2.0
        _expect(not buy_button.disabled, "persisted in-stock Merchant selection enables buy")
        buy_button.pressed.emit()

    var inventory := InventoryState.new()
    var economy := EconomyState.new()
    _expect(
        inventory.load_dictionary(profile.item_state).is_empty()
        and economy.load_dictionary(profile.economy_state).is_empty(),
        "GameplayRoot Merchant buy leaves persisted inventory/economy state valid"
    )
    var vendor := economy.get_vendor(GameplayRoot.REGION3_GENERAL_MERCHANT_VENDOR_ID)
    _expect(
        inventory.gold == 80
        and inventory.get_total_quantity(&"itemdef:potion") == 4
        and vendor != null
        and int(vendor.get_entry(&"itemdef:potion").get("quantity", -1)) == 4,
        "GameplayRoot Merchant buy uses exact persisted price, stock, and quantity"
    )

    _expect(sell.item_count > 0, "MerchantMenu refresh exposes owned vendor-supported items for sale")
    if sell.item_count > 0:
        sell.select(0)
        menu.call("_on_sell_selected", 0)
        quantity.value = 1.0
        _expect(not sell_button.disabled, "owned vendor-supported item enables sell")
        sell_button.pressed.emit()
    inventory = InventoryState.new()
    economy = EconomyState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty() and economy.load_dictionary(profile.economy_state).is_empty(), "GameplayRoot Merchant sell leaves persisted state valid")
    vendor = economy.get_vendor(GameplayRoot.REGION3_GENERAL_MERCHANT_VENDOR_ID)
    _expect(
        inventory.gold == 84
        and inventory.get_total_quantity(&"itemdef:potion") == 3
        and vendor != null
        and int(vendor.get_entry(&"itemdef:potion").get("quantity", -1)) == 5,
        "GameplayRoot Merchant sell credits exact authored sell value and restores vendor stock"
    )
    menu.close_menu()
    merchant_interaction.call("_on_body_exited", gameplay.player)
    await process_frame


func _equipment_index(list: ItemList, slot_id: StringName) -> int:
    for index: int in range(list.item_count):
        var raw: Variant = list.get_item_metadata(index)
        if raw is Dictionary and StringName(String((raw as Dictionary).get("slot_id", &""))) == slot_id:
            return index
    return -1


func _grid_button_for(menu: InventoryMenu, item_instance_id: StringName) -> Button:
    var grid := menu.get_node("Overlay/Panel/Scroller/Layout/Body/Left/Grid") as GridContainer
    for child: Node in grid.get_children():
        if not child is Button:
            continue
        var raw: Variant = (child as Button).get_meta("item", {})
        if raw is Dictionary and StringName(String((raw as Dictionary).get("item_instance_id", &""))) == item_instance_id:
            return child as Button
    return null


func _select_option_metadata(option: OptionButton, value: Variant) -> void:
    for index: int in range(option.item_count):
        if option.get_item_metadata(index) == value:
            option.select(index)
            return


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
