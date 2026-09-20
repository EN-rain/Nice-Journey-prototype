extends SceneTree

const MENU_SCENE: PackedScene = preload("res://src/ui/inventory_menu.tscn")

var _failures := 0
var _profile: ProfileSnapshot = null
var _catalog: EquipmentItemCatalog = null
var _category_catalog: ItemCategoryCatalog = null
var _transaction_counter := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _profile = ProfileCreationService.create_profile(1, "Inventory Action UI", "melee")
    _catalog = StarterEquipmentCatalog.build()
    _category_catalog = ItemCategoryCatalog.new()
    _category_catalog.definition_categories = {
        "itemdef:ui_consumable": ItemCategoryCatalog.CATEGORY_CONSUMABLE,
        String(StarterKitCatalog.WEAPON_MELEE_SWORD): ItemCategoryCatalog.CATEGORY_WEAPON,
    }
    _expect(_category_catalog.validate_catalog().is_empty(), "inventory action UI category authority validates")
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(_profile.item_state).is_empty(), "inventory action UI fixture loads")
    _expect(inventory.try_add_normal(&"item:ui_consumable", &"itemdef:ui_consumable", 3, true).get("accepted", false), "inventory action UI fixture owns quick-reference stack")
    _profile.item_state = inventory.to_dictionary()

    var ownership := InputOwnership.new()
    get_root().add_child(ownership)
    var menu := MENU_SCENE.instantiate() as InventoryMenu
    get_root().add_child(menu)
    await process_frame
    _expect(menu.configure(
        _profile,
        ownership,
        Callable(),
        Callable(),
        Callable(),
        Callable(self, &"_request_equip"),
        Callable(self, &"_request_unequip"),
        Callable(self, &"_request_quick_slot"),
        _category_catalog
    ), "Inventory menu accepts equipment and quick-reference callbacks")
    _expect(menu.open_menu(), "Inventory menu opens with mutation callbacks")

    var equipment_list := menu.get_node("Overlay/Panel/Scroller/Layout/Body/Right/Equipment") as ItemList
    var unequip_button := menu.get_node("Overlay/Panel/Scroller/Layout/EquipRow/Unequip") as Button
    var equip_button := menu.get_node("Overlay/Panel/Scroller/Layout/EquipRow/Equip") as Button
    var equip_target := menu.get_node("Overlay/Panel/Scroller/Layout/EquipRow/Target") as OptionButton
    var quick_target := menu.get_node("Overlay/Panel/Scroller/Layout/QuickRow/Target") as OptionButton
    var quick_bind := menu.get_node("Overlay/Panel/Scroller/Layout/QuickRow/Bind") as Button
    var quick_clear := menu.get_node("Overlay/Panel/Scroller/Layout/QuickRow/Clear") as Button

    var weapon_index := _equipment_index(equipment_list, EquipmentSlotIdentityValidator.SLOT_WEAPON)
    _expect(weapon_index >= 0, "Inventory menu exposes fixed weapon slot")
    if weapon_index >= 0:
        equipment_list.select(weapon_index)
        menu.call("_on_equipment_selected", weapon_index)
        _expect(not unequip_button.disabled, "selected equipped weapon enables authoritative unequip callback")
        unequip_button.emit_signal("pressed")

    var equipment := EquipmentState.new()
    inventory = InventoryState.new()
    _expect(equipment.load_dictionary(_profile.equipment_state).is_empty() and inventory.load_dictionary(_profile.item_state).is_empty(), "unequip UI leaves persisted states valid")
    var sword_instance := StringName("%s:item:%s" % [_profile.profile_id, String(StarterKitCatalog.WEAPON_MELEE_SWORD)])
    _expect(equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON).is_empty() and not inventory.get_normal_slot(sword_instance).is_empty(), "unequip UI moves exact weapon instance to inventory")

    var sword_button := _grid_button_for(menu, sword_instance)
    _expect(sword_button != null, "unequipped weapon appears in normal inventory grid")
    if sword_button != null:
        sword_button.emit_signal("pressed")
        _select_option_metadata(equip_target, EquipmentSlotIdentityValidator.SLOT_WEAPON)
        _expect(not equip_button.disabled, "selected nonstackable gear enables equip callback")
        _expect(quick_bind.disabled, "authored weapon cannot be assigned to consumable quick slots")
        equip_button.emit_signal("pressed")
    equipment = EquipmentState.new()
    _expect(equipment.load_dictionary(_profile.equipment_state).is_empty() and StringName(String(equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON).get("item_instance_id", &""))) == sword_instance, "equip UI restores exact weapon instance to fixed slot")

    var consumable_button := _grid_button_for(menu, &"item:ui_consumable")
    _expect(consumable_button != null, "quick-reference source remains visible in inventory")
    if consumable_button != null:
        consumable_button.emit_signal("pressed")
        quick_target.select(1)
        _expect(not quick_bind.disabled, "selected owned normal stack enables quick-reference assignment")
        quick_bind.emit_signal("pressed")
    inventory = InventoryState.new()
    _expect(inventory.load_dictionary(_profile.item_state).is_empty() and inventory.quick_slots[1] == &"item:ui_consumable", "quick-reference UI persists exact selected instance")
    _expect(not quick_clear.disabled, "configured quick-reference callback enables explicit clear")
    quick_clear.emit_signal("pressed")
    inventory = InventoryState.new()
    _expect(inventory.load_dictionary(_profile.item_state).is_empty() and inventory.quick_slots[1] == &"", "quick-reference UI clears selected shortcut without changing ownership")

    menu.close_menu()
    _expect(menu.configure(
        _profile,
        ownership,
        Callable(),
        Callable(),
        Callable(),
        Callable(self, &"_request_equip"),
        Callable(self, &"_request_unequip"),
        Callable(self, &"_request_quick_slot")
    ), "Inventory menu can reconfigure without category authority")
    _expect(menu.open_menu(), "Inventory menu reopens without category authority")
    consumable_button = _grid_button_for(menu, &"item:ui_consumable")
    if consumable_button != null:
        consumable_button.emit_signal("pressed")
        _expect(quick_bind.disabled, "Inventory UI fails closed for new quick binding when category authority is absent")

    _expect(ProfileSnapshot.validate_dictionary(_profile.to_dictionary()).is_empty(), "Inventory equip/quick UI preserves whole-profile validity")
    menu.close_menu()
    menu.queue_free()
    ownership.queue_free()
    await process_frame
    if _failures == 0:
        print("INVENTORY EQUIP QUICK MENU UI TEST PASS")
    else:
        push_error("INVENTORY EQUIP QUICK MENU UI TEST FAILURES: %d" % _failures)
    quit(_failures)


func _request_equip(item_instance_id: StringName, slot_id: StringName) -> Dictionary:
    _transaction_counter += 1
    return ProfileInventoryMutationService.equip(
        _profile,
        _catalog,
        StringName("transaction:inventory_ui:equip:%d" % _transaction_counter),
        item_instance_id,
        slot_id
    )


func _request_unequip(slot_id: StringName) -> Dictionary:
    _transaction_counter += 1
    return ProfileInventoryMutationService.unequip(
        _profile,
        StringName("transaction:inventory_ui:unequip:%d" % _transaction_counter),
        slot_id
    )


func _request_quick_slot(slot_index: int, item_instance_id: StringName) -> Dictionary:
    _transaction_counter += 1
    return ProfileInventoryMutationService.bind_quick_slot(
        _profile,
        StringName("transaction:inventory_ui:quick:%d" % _transaction_counter),
        slot_index,
        item_instance_id,
        _category_catalog
    )


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
