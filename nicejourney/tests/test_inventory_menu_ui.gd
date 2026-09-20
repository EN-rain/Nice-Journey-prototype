extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const INVENTORY_MENU_SCRIPT: Script = preload("res://src/ui/inventory_menu.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Inventory UI", "melee")
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "inventory UI fixture loads starter inventory")
    _expect(bool(inventory.try_add_normal(&"item:potion_stack", &"potion_basic", 5, true).get("accepted", false)), "inventory UI fixture owns a normal item")
    _expect(inventory.bind_quick_slot(0, &"item:potion_stack"), "inventory UI fixture binds quick reference")
    _expect(inventory.grant_protected(InventoryState.TOWER_SIGIL_ID, true), "inventory UI fixture owns protected Tower Sigil")
    _expect(inventory.add_gold(12), "inventory UI fixture owns Gold")
    profile.item_state = inventory.to_dictionary()
    var before := profile.to_dictionary()

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame

    var menu: Node = gameplay.get_node("InventoryMenu")
    var overlay := gameplay.get_node("InventoryMenu/Overlay") as Control
    var panel := gameplay.get_node("InventoryMenu/Overlay/Panel") as Control
    var search := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/SearchRow/Search") as LineEdit
    var sort := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/SearchRow/Sort") as OptionButton
    var summary := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/Summary") as Label
    var grid := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/Body/Left/Grid") as GridContainer
    var equipment := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/Body/Right/Equipment") as ItemList
    var protected := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/Body/Right/Protected") as Label
    var quick := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/Body/Right/Quick") as Label
    var detail := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/Detail") as Label
    var destroy_button := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/ActionRow/Destroy") as Button
    var destroy_confirm_row := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/DestroyConfirmRow") as HBoxContainer
    var destroy_consequence := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/DestroyConfirmRow/Consequence") as Label
    var destroy_confirm := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/DestroyConfirmRow/Confirm") as Button
    var destroy_cancel := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/DestroyConfirmRow/Cancel") as Button
    var status := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/Status") as Label
    var ownership := gameplay.input_ownership
    var coordinator := gameplay.pause_coordinator

    _expect(bool(menu.call("open_menu")), "I Inventory modal opens from persisted inventory/equipment state")
    _expect(overlay.visible and ownership.current_modal() == INVENTORY_MENU_SCRIPT.MODAL_ID, "Inventory menu exclusively owns modal input while open")
    _expect(search.has_focus(), "Inventory menu establishes keyboard focus on search")
    _expect(grid.get_child_count() == 16, "Inventory menu renders exactly the locked 16 normal slots")
    var slot_template := (menu as InventoryMenu).slot_button_scene.instantiate() as Button
    _expect(slot_template != null and slot_template.custom_minimum_size == Vector2(46, 32) and grid.get_child(0) is Button and (grid.get_child(0) as Button).custom_minimum_size == slot_template.custom_minimum_size, "Inventory slot sizing comes from an Inspector-assigned PackedScene, not hardcoded button construction")
    slot_template.free()
    _expect(equipment.item_count == 5, "Inventory menu renders exactly five fixed equipment slots")
    _expect(summary.text.contains("Gold: 12") and summary.text.contains("1/16"), "Inventory summary exposes exact Gold and normal-capacity occupancy")
    _expect(_item_list_contains(equipment, "starter_sword") and _item_list_contains(equipment, "starter_shield"), "Inventory equipment list matches the persisted DR-04 Melee starter kit")
    _expect(protected.text.contains("tower_sigil") and protected.text.contains("Tower Sigil"), "Inventory menu keeps protected Tower Sigil separate from normal capacity")
    _expect(quick.text.contains("item:potion_stack"), "Inventory menu exposes the exact bound consumable quick reference")
    _expect(status.text.contains("presentation-only") and status.text.contains("destroyed with confirmation") and status.text.contains("unbanked"), "Inventory menu states presentation-only search/sort plus confirmed unbanked destroy semantics")
    _expect(not gameplay.map_menu.open_menu(), "another modal cannot stack over the open Inventory menu")

    search.text = "potion"
    menu.call("_on_search_changed", search.text)
    var search_snapshot: Dictionary = menu.call("current_snapshot") as Dictionary
    _expect(int(search_snapshot.get("matching_item_count", -1)) == 1, "Inventory UI search filters the presentation deterministically")
    _expect(profile.to_dictionary() == before, "Inventory UI search mutates no profile ownership")

    sort.select(1)
    menu.call("_on_sort_selected", 1)
    var sorted_snapshot: Dictionary = menu.call("current_snapshot") as Dictionary
    _expect(StringName(sorted_snapshot.get("sort_mode", &"")) == &"quantity_desc", "Inventory UI switches to presentation-only quantity sort")
    _expect(profile.to_dictionary() == before, "Inventory UI sorting mutates no profile ownership")

    search.text = ""
    menu.call("_on_search_changed", "")
    var first_button := grid.get_child(0) as Button
    _expect(not first_button.disabled, "Inventory UI exposes occupied normal slots as selectable controls")
    first_button.emit_signal("pressed")
    _expect(detail.text.contains("potion_basic") and detail.text.contains("Quantity: 5"), "Inventory item detail exposes exact persisted ID and quantity")
    _expect(detail.text.contains("Rarity: unavailable") and detail.text.contains("Upgrade rank: unavailable"), "Inventory item detail does not fabricate absent metadata")
    _expect(not destroy_button.disabled, "selecting a normal inventory stack enables destructive input")
    equipment.select(0)
    menu.call("_on_equipment_selected", 0)
    _expect(destroy_button.disabled, "selecting equipped ownership disables destructive input")
    first_button.emit_signal("pressed")
    _expect(not destroy_button.disabled, "returning to normal ownership re-enables Destroy")

    var settings: Node = root.get_node_or_null("AccessibilitySettings")
    if settings != null:
        settings.call("set_ui_scale", 1.25)
        settings.call("set_text_scale", 1.25)
        await process_frame
        _expect(overlay.theme != null and is_equal_approx(overlay.theme.default_base_scale, 1.25) and overlay.theme.default_font_size == 20, "Inventory menu consumes global UI/text accessibility scale")
        var panel_rect := panel.get_global_rect()
        _expect(panel_rect.position.x >= 0.0 and panel_rect.position.y >= 0.0 and panel_rect.end.x <= 640.0 and panel_rect.end.y <= 360.0, "largest supported UI/text scale keeps the Inventory panel inside the minimum 640x360 canvas")
        settings.call("set_ui_scale", 1.0)
        settings.call("set_text_scale", 1.0)

    menu.call("_unhandled_input", _inventory_event(true))
    _expect(not bool(menu.call("is_open")) and not ownership.is_modal_open(), "pressing I again closes only the Inventory modal")
    _expect(not ownership.can_route_gameplay_action(&"inventory"), "Inventory close suppresses the triggering I action until release")
    ownership._input(_inventory_event(false))
    _expect(ownership.can_route_gameplay_action(&"inventory"), "Inventory I suppression clears on release")

    _expect(bool(menu.call("open_menu")), "Inventory menu can reopen after I release")
    coordinator._input(_pause_event(true))
    _expect(not paused, "Escape backs out of Inventory without stacking Pause")
    _expect(not bool(menu.call("is_open")) and not ownership.is_modal_open(), "GameplayRoot closes Inventory through shared PauseCoordinator modal-back routing")
    _expect(not ownership.can_route_gameplay_action(&"pause"), "Inventory modal-back suppresses the triggering Escape until release")
    coordinator._input(_pause_event(false))
    _expect(ownership.can_route_gameplay_action(&"pause"), "Inventory Escape suppression clears on release")

    _expect(bool(menu.call("open_menu")), "Inventory menu opens for detached snapshot proof")
    var detached: Dictionary = menu.call("current_snapshot") as Dictionary
    ((detached.get("equipment_slots", []) as Array)[0] as Dictionary)["slot_id"] = &"mutated_slot"
    var fresh: Dictionary = menu.call("current_snapshot") as Dictionary
    _expect(StringName(((fresh.get("equipment_slots", []) as Array)[0] as Dictionary).get("slot_id", &"")) != &"mutated_slot", "Inventory UI returns detached read-only snapshots")

    first_button = grid.get_child(0) as Button
    first_button.emit_signal("pressed")
    destroy_button.pressed.emit()
    _expect(destroy_confirm_row.visible and destroy_consequence.text.contains("item:potion_stack") and destroy_consequence.text.contains("x5"), "Destroy requires an explicit consequence confirmation for the selected full stack")
    _expect(profile.to_dictionary() == before, "opening destroy confirmation mutates no item ownership")
    destroy_cancel.pressed.emit()
    _expect(not destroy_confirm_row.visible and profile.to_dictionary() == before and status.text.contains("cancelled"), "cancelling Destroy preserves ownership exactly")

    destroy_button.pressed.emit()
    destroy_confirm.pressed.emit()
    _expect(not destroy_confirm_row.visible and status.text.contains("Item destroyed") and status.text.contains("unbanked"), "confirmed Destroy reports live unbanked mutation semantics")
    var destroyed_inventory := InventoryState.new()
    _expect(destroyed_inventory.load_dictionary(profile.item_state).is_empty(), "confirmed Destroy leaves a valid inventory state")
    _expect(destroyed_inventory.get_normal_slot(&"item:potion_stack").is_empty(), "confirmed Destroy removes the exact selected normal stack")
    _expect(destroyed_inventory.quick_slots[0] == &"", "confirmed full-stack Destroy clears the stale quick-slot reference")
    var destroyed_snapshot: Dictionary = menu.call("current_snapshot") as Dictionary
    _expect(int(destroyed_snapshot.get("occupied_normal_slots", -1)) == 0, "Inventory view refreshes immediately after confirmed Destroy")
    menu.call("close_menu")

    _expect(profile.to_dictionary() != before, "confirmed Inventory destruction mutates only after explicit confirmation")

    gameplay.queue_free()
    await process_frame
    if _failures == 0:
        print("INVENTORY MENU UI TEST PASS")
    else:
        push_error("INVENTORY MENU UI TEST FAILURES: %d" % _failures)
    quit(_failures)


func _item_list_contains(list: ItemList, text: String) -> bool:
    for index: int in range(list.item_count):
        if list.get_item_text(index).contains(text):
            return true
    return false


func _inventory_event(pressed: bool) -> InputEventAction:
    var event := InputEventAction.new()
    event.action = &"inventory"
    event.pressed = pressed
    return event


func _pause_event(pressed: bool) -> InputEventAction:
    var event := InputEventAction.new()
    event.action = &"pause"
    event.pressed = pressed
    return event


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
