class_name InventoryMenu
extends CanvasLayer

const MODAL_ID: StringName = &"ui:inventory"
const VIEW_SERVICE_SCRIPT: Script = preload("res://src/ui/inventory_view_service.gd")

@export var slot_button_scene: PackedScene

@onready var overlay: Control = $Overlay
@onready var search_field: LineEdit = $Overlay/Panel/Scroller/Layout/SearchRow/Search
@onready var sort_mode: OptionButton = $Overlay/Panel/Scroller/Layout/SearchRow/Sort
@onready var summary_label: Label = $Overlay/Panel/Scroller/Layout/Summary
@onready var grid: GridContainer = $Overlay/Panel/Scroller/Layout/Body/Left/Grid
@onready var equipment_list: ItemList = $Overlay/Panel/Scroller/Layout/Body/Right/Equipment
@onready var protected_label: Label = $Overlay/Panel/Scroller/Layout/Body/Right/Protected
@onready var quick_label: Label = $Overlay/Panel/Scroller/Layout/Body/Right/Quick
@onready var detail_label: Label = $Overlay/Panel/Scroller/Layout/Detail
@onready var action_row: HBoxContainer = $Overlay/Panel/Scroller/Layout/ActionRow
@onready var drop_button: Button = $Overlay/Panel/Scroller/Layout/ActionRow/Drop
@onready var destroy_button: Button = $Overlay/Panel/Scroller/Layout/ActionRow/Destroy
@onready var equip_target: OptionButton = $Overlay/Panel/Scroller/Layout/EquipRow/Target
@onready var equip_button: Button = $Overlay/Panel/Scroller/Layout/EquipRow/Equip
@onready var unequip_button: Button = $Overlay/Panel/Scroller/Layout/EquipRow/Unequip
@onready var quick_target: OptionButton = $Overlay/Panel/Scroller/Layout/QuickRow/Target
@onready var quick_bind_button: Button = $Overlay/Panel/Scroller/Layout/QuickRow/Bind
@onready var quick_clear_button: Button = $Overlay/Panel/Scroller/Layout/QuickRow/Clear
@onready var destroy_confirm_row: HBoxContainer = $Overlay/Panel/Scroller/Layout/DestroyConfirmRow
@onready var destroy_confirm_label: Label = $Overlay/Panel/Scroller/Layout/DestroyConfirmRow/Consequence
@onready var destroy_confirm_button: Button = $Overlay/Panel/Scroller/Layout/DestroyConfirmRow/Confirm
@onready var destroy_cancel_button: Button = $Overlay/Panel/Scroller/Layout/DestroyConfirmRow/Cancel
@onready var status_label: Label = $Overlay/Panel/Scroller/Layout/Status
@onready var back_button: Button = $Overlay/Panel/Scroller/Layout/Back

var _profile: ProfileSnapshot = null
var _input_ownership: InputOwnership = null
var _destroy_request: Callable = Callable()
var _drop_request: Callable = Callable()
var _drop_status_request: Callable = Callable()
var _equip_request: Callable = Callable()
var _unequip_request: Callable = Callable()
var _quick_slot_request: Callable = Callable()
var _item_category_catalog: ItemCategoryCatalog = null
var _snapshot: Dictionary = {}
var _grid_buttons: Array[Button] = []
var _selected_item_instance_id: StringName = &""
var _selected_normal_quantity: int = 0
var _selected_is_normal: bool = false
var _selected_normal_stackable: bool = false
var _selected_equipment_slot_id: StringName = &""


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    overlay.visible = false
    sort_mode.clear()
    sort_mode.add_item(tr("Sort: Definition"))
    sort_mode.set_item_metadata(0, VIEW_SERVICE_SCRIPT.SORT_DEFINITION)
    sort_mode.add_item(tr("Sort: Quantity"))
    sort_mode.set_item_metadata(1, VIEW_SERVICE_SCRIPT.SORT_QUANTITY_DESC)
    search_field.text_changed.connect(_on_search_changed)
    sort_mode.item_selected.connect(_on_sort_selected)
    equipment_list.item_selected.connect(_on_equipment_selected)
    drop_button.pressed.connect(_on_drop_pressed)
    destroy_button.pressed.connect(_on_destroy_pressed)
    destroy_confirm_button.pressed.connect(_on_destroy_confirmed)
    destroy_cancel_button.pressed.connect(_on_destroy_cancelled)
    equip_button.pressed.connect(_on_equip_pressed)
    unequip_button.pressed.connect(_on_unequip_pressed)
    quick_bind_button.pressed.connect(_on_quick_bind_pressed)
    quick_clear_button.pressed.connect(_on_quick_clear_pressed)
    back_button.pressed.connect(_on_back_pressed)
    drop_button.disabled = true
    destroy_button.disabled = true
    equip_button.disabled = true
    unequip_button.disabled = true
    quick_bind_button.disabled = true
    quick_clear_button.disabled = true
    destroy_confirm_row.visible = false
    _configure_equip_targets()
    _configure_quick_targets()
    _build_grid_buttons()


func configure(
    profile: ProfileSnapshot,
    input_ownership: InputOwnership,
    destroy_request: Callable = Callable(),
    drop_request: Callable = Callable(),
    drop_status_request: Callable = Callable(),
    equip_request: Callable = Callable(),
    unequip_request: Callable = Callable(),
    quick_slot_request: Callable = Callable(),
    item_category_catalog: ItemCategoryCatalog = null
) -> bool:
    if profile == null or input_ownership == null:
        return false
    _profile = profile
    _input_ownership = input_ownership
    _destroy_request = destroy_request
    _drop_request = drop_request
    _drop_status_request = drop_status_request
    _equip_request = equip_request
    _unequip_request = unequip_request
    _quick_slot_request = quick_slot_request
    _item_category_catalog = item_category_catalog
    if is_instance_valid(quick_clear_button):
        quick_clear_button.disabled = not _quick_slot_request.is_valid()
    return true


func set_profile(profile: ProfileSnapshot) -> bool:
    if profile == null:
        return false
    _profile = profile
    if overlay.visible:
        _refresh_snapshot()
    return true


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed(&"inventory"):
        return
    if overlay.visible:
        close_menu(&"inventory")
        get_viewport().set_input_as_handled()
        return
    if _input_ownership != null and _input_ownership.is_modal_open():
        return
    if open_menu():
        get_viewport().set_input_as_handled()


func open_menu() -> bool:
    if _profile == null or _input_ownership == null:
        return false
    if _input_ownership.is_modal_open() and _input_ownership.current_modal() != MODAL_ID:
        return false
    if not _refresh_snapshot():
        return false
    overlay.visible = true
    _input_ownership.open_modal(MODAL_ID)
    search_field.grab_focus()
    return true


func close_menu(triggering_action: StringName = &"") -> void:
    if not overlay.visible:
        return
    overlay.visible = false
    destroy_confirm_row.visible = false
    if _input_ownership != null:
        _input_ownership.close_modal(MODAL_ID, triggering_action)


func is_open() -> bool:
    return overlay.visible


func current_snapshot() -> Dictionary:
    return _snapshot.duplicate(true)


func _refresh_snapshot() -> bool:
    if _profile == null:
        return false
    var selected_sort: StringName = VIEW_SERVICE_SCRIPT.SORT_DEFINITION
    if sort_mode.item_count > 0:
        selected_sort = StringName(String(sort_mode.get_item_metadata(sort_mode.selected)))
    var snapshot: Dictionary = VIEW_SERVICE_SCRIPT.build_view(_profile, search_field.text, selected_sort, _item_category_catalog)
    if not bool(snapshot.get("accepted", false)):
        return false
    _snapshot = snapshot.duplicate(true)
    _render_snapshot()
    return true


func _build_grid_buttons() -> void:
    for child: Node in grid.get_children():
        grid.remove_child(child)
        child.queue_free()
    _grid_buttons.clear()
    if slot_button_scene == null:
        push_error("Inventory slot button scene is not assigned")
        return
    for index: int in range(NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY):
        var button := slot_button_scene.instantiate() as Button
        if button == null:
            push_error("Inventory slot button scene must instantiate a Button")
            return
        button.pressed.connect(_on_grid_slot_pressed.bind(index))
        grid.add_child(button)
        _grid_buttons.append(button)


func _render_snapshot() -> void:
    var capacity := int(_snapshot.get("capacity", NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY))
    var occupied := int(_snapshot.get("occupied_normal_slots", 0))
    var matching := int(_snapshot.get("matching_item_count", 0))
    summary_label.text = tr("Gold: %d | Normal inventory: %d/%d | Matching: %d") % [int(_snapshot.get("gold", 0)), occupied, capacity, matching]
    status_label.text = tr("Search/sort are presentation-only. Selected normal stacks may be destroyed with confirmation; world Drop and equipment changes use authoritative callbacks when available. New quick-slot assignment requires an authored consumable category; legacy references remain visible but are not treated as category-authorized. Accepted mutations remain unbanked until the next committed safe snapshot.")

    var slots := _snapshot.get("grid_slots", []) as Array
    for index: int in range(_grid_buttons.size()):
        var button: Button = _grid_buttons[index]
        var entry: Dictionary = slots[index] as Dictionary if index < slots.size() and slots[index] is Dictionary else {}
        if bool(entry.get("occupied", false)):
            var definition_id := String(entry.get("definition_id", &""))
            var quantity := int(entry.get("quantity", 1))
            button.text = "%s\nx%d" % [definition_id, quantity]
            button.tooltip_text = _item_detail_text(entry)
            button.disabled = false
            button.set_meta("item", entry.duplicate(true))
        else:
            button.text = tr("Empty")
            button.tooltip_text = tr("Empty normal inventory slot")
            button.disabled = true
            button.set_meta("item", {})

    equipment_list.clear()
    for raw_entry: Variant in _snapshot.get("equipment_slots", []) as Array:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        var slot_id := StringName(String(entry.get("slot_id", &"")))
        var occupied_slot := bool(entry.get("occupied", false))
        var item := entry.get("item", {}) as Dictionary
        var line := "%s: %s" % [String(slot_id), String(item.get("definition_id", &"")) if occupied_slot else tr("Empty")]
        equipment_list.add_item(line)
        equipment_list.set_item_metadata(equipment_list.item_count - 1, entry.duplicate(true))

    protected_label.text = _protected_text(_snapshot.get("protected_items", []) as Array)
    quick_label.text = _quick_text(_snapshot.get("quick_slots", []) as Array)
    _restore_or_clear_detail()


func _restore_or_clear_detail() -> void:
    if _selected_item_instance_id == &"":
        _clear_destroy_target()
        detail_label.text = tr("Select a normal or equipped item for exact persisted metadata.")
        return
    for raw_slot: Variant in _snapshot.get("grid_slots", []) as Array:
        if raw_slot is Dictionary:
            var slot := raw_slot as Dictionary
            if StringName(String(slot.get("item_instance_id", &""))) == _selected_item_instance_id:
                detail_label.text = _item_detail_text(slot)
                _set_destroy_target(slot)
                return
    for raw_entry: Variant in _snapshot.get("equipment_slots", []) as Array:
        if not raw_entry is Dictionary:
            continue
        var item := (raw_entry as Dictionary).get("item", {}) as Dictionary
        if StringName(String(item.get("item_instance_id", &""))) == _selected_item_instance_id:
            detail_label.text = _item_detail_text(item)
            _clear_destroy_target(false)
            return
    _selected_item_instance_id = &""
    _clear_destroy_target()
    detail_label.text = tr("Select a normal or equipped item for exact persisted metadata.")


func _item_detail_text(item: Dictionary) -> String:
    if item.is_empty():
        return tr("No item metadata available.")
    var lines := PackedStringArray()
    lines.append(tr("Definition: %s") % String(item.get("definition_id", &"")))
    lines.append(tr("Instance: %s") % String(item.get("item_instance_id", &"")))
    lines.append(tr("Quantity: %d | Stackable: %s") % [int(item.get("quantity", 1)), tr("Yes") if bool(item.get("stackable", false)) else tr("No")])
    lines.append(tr("Rarity: %s") % (String(item.get("rarity", &"")) if bool(item.get("rarity_available", false)) else tr("unavailable")))
    lines.append(tr("Affixes: %s") % (_join_array(item.get("affixes", []) as Array) if bool(item.get("affixes_available", false)) else tr("unavailable")))
    lines.append(tr("Upgrade rank: %s") % (str(int(item.get("upgrade_rank", 0))) if bool(item.get("upgrade_rank_available", false)) else tr("unavailable")))
    lines.append(tr("Source claim: %s") % (String(item.get("source_claim_id", &"")) if bool(item.get("source_claim_id_available", false)) else tr("unavailable")))
    if bool(item.get("item_category_authored", false)):
        lines.append(tr("Item category: %s") % String(item.get("item_category", &"")))
    else:
        lines.append(tr("Item category: unauthored"))
    return "\n".join(lines)


func _protected_text(entries: Array) -> String:
    if entries.is_empty():
        return tr("Protected quest/key items: none")
    var lines := PackedStringArray([tr("Protected quest/key items:")])
    for raw_entry: Variant in entries:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        var suffix := tr(" — Tower Sigil") if bool(entry.get("tower_sigil", false)) else ""
        lines.append("• %s%s" % [String(entry.get("item_id", &"")), suffix])
    return "\n".join(lines)


func _quick_text(entries: Array) -> String:
    var lines := PackedStringArray([tr("Consumable quick references:")])
    for raw_entry: Variant in entries:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        var reference := String(entry.get("item_instance_id", &""))
        var display := reference if not reference.is_empty() else tr("Empty")
        if bool(entry.get("legacy_unvalidated_reference", false)):
            display += tr(" — legacy/unvalidated category")
        elif not reference.is_empty() and not bool(entry.get("consumable_category_validated", false)):
            display += tr(" — non-consumable category")
        lines.append("%d: %s" % [int(entry.get("slot_index", 0)) + 1, display])
    return "\n".join(lines)


func _join_array(values: Array) -> String:
    if values.is_empty():
        return tr("none")
    var text := PackedStringArray()
    for value: Variant in values:
        text.append(String(value))
    return ", ".join(text)


func _on_grid_slot_pressed(index: int) -> void:
    if index < 0 or index >= _grid_buttons.size():
        return
    var item := _grid_buttons[index].get_meta("item", {}) as Dictionary
    if item.is_empty():
        return
    _selected_item_instance_id = StringName(String(item.get("item_instance_id", &"")))
    _selected_equipment_slot_id = &""
    detail_label.text = _item_detail_text(item)
    _set_destroy_target(item)


func _on_equipment_selected(index: int) -> void:
    if index < 0 or index >= equipment_list.item_count:
        return
    var entry := equipment_list.get_item_metadata(index) as Dictionary
    var item := entry.get("item", {}) as Dictionary
    if item.is_empty():
        _selected_item_instance_id = &""
        _selected_equipment_slot_id = &""
        _clear_destroy_target()
        detail_label.text = tr("Selected equipment slot is empty.")
        return
    _selected_item_instance_id = StringName(String(item.get("item_instance_id", &"")))
    _selected_equipment_slot_id = StringName(String(entry.get("slot_id", &"")))
    _clear_destroy_target(false)
    unequip_button.disabled = _selected_equipment_slot_id == &"" or not _unequip_request.is_valid()
    detail_label.text = _item_detail_text(item)


func _on_search_changed(_text: String) -> void:
    if overlay.visible:
        _refresh_snapshot()


func _on_sort_selected(_index: int) -> void:
    if overlay.visible:
        _refresh_snapshot()


func _set_destroy_target(item: Dictionary) -> void:
    _selected_is_normal = not item.is_empty()
    _selected_normal_quantity = int(item.get("quantity", 0)) if _selected_is_normal else 0
    _selected_normal_stackable = bool(item.get("stackable", false)) if _selected_is_normal else false
    destroy_confirm_row.visible = false
    destroy_button.disabled = not _selected_is_normal or _selected_normal_quantity <= 0 or not _destroy_request.is_valid()
    drop_button.disabled = not _selected_is_normal or _selected_normal_quantity <= 0 or not _drop_context_allowed()
    equip_button.disabled = not _selected_is_normal or _selected_normal_stackable or _selected_normal_quantity != 1 or not _equip_request.is_valid()
    unequip_button.disabled = true
    quick_bind_button.disabled = (
        not _selected_is_normal
        or _selected_normal_quantity <= 0
        or not _quick_slot_request.is_valid()
        or not bool(item.get("quick_slot_eligible", false))
    )


func _clear_destroy_target(clear_selection: bool = true) -> void:
    _selected_is_normal = false
    _selected_normal_quantity = 0
    _selected_normal_stackable = false
    drop_button.disabled = true
    destroy_button.disabled = true
    equip_button.disabled = true
    quick_bind_button.disabled = true
    if clear_selection:
        _selected_equipment_slot_id = &""
        unequip_button.disabled = true
    destroy_confirm_row.visible = false
    if clear_selection:
        _selected_item_instance_id = &""


func _configure_equip_targets() -> void:
    equip_target.clear()
    for slot_id: StringName in EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS:
        equip_target.add_item(String(slot_id))
        equip_target.set_item_metadata(equip_target.item_count - 1, slot_id)


func _configure_quick_targets() -> void:
    quick_target.clear()
    for index: int in range(InventoryState.QUICK_SLOT_COUNT):
        quick_target.add_item(tr("Quick %d") % (index + 1))
        quick_target.set_item_metadata(quick_target.item_count - 1, index)


func _selected_equip_slot() -> StringName:
    if equip_target.item_count == 0 or equip_target.selected < 0:
        return &""
    return StringName(String(equip_target.get_item_metadata(equip_target.selected)))


func _selected_quick_slot() -> int:
    if quick_target.item_count == 0 or quick_target.selected < 0:
        return -1
    return int(quick_target.get_item_metadata(quick_target.selected))


func _on_equip_pressed() -> void:
    if equip_button.disabled or not _equip_request.is_valid() or _selected_item_instance_id == &"":
        return
    var slot_id := _selected_equip_slot()
    if slot_id == &"":
        return
    _apply_mutation_result(_equip_request.call(_selected_item_instance_id, slot_id), tr("Item equipped"))


func _on_unequip_pressed() -> void:
    if unequip_button.disabled or not _unequip_request.is_valid() or _selected_equipment_slot_id == &"":
        return
    _apply_mutation_result(_unequip_request.call(_selected_equipment_slot_id), tr("Item unequipped"))


func _on_quick_bind_pressed() -> void:
    if quick_bind_button.disabled or not _quick_slot_request.is_valid() or _selected_item_instance_id == &"":
        return
    var slot_index := _selected_quick_slot()
    if slot_index < 0:
        return
    _apply_mutation_result(_quick_slot_request.call(slot_index, _selected_item_instance_id), tr("Quick reference assigned"), false)


func _on_quick_clear_pressed() -> void:
    if quick_clear_button.disabled or not _quick_slot_request.is_valid():
        return
    var slot_index := _selected_quick_slot()
    if slot_index < 0:
        return
    _apply_mutation_result(_quick_slot_request.call(slot_index, &""), tr("Quick reference cleared"), false)


func _apply_mutation_result(raw_result: Variant, success_text: String, clear_selection: bool = true) -> void:
    if not raw_result is Dictionary:
        status_label.text = tr("Inventory mutation failed: invalid response.")
        return
    var result := raw_result as Dictionary
    if not bool(result.get("accepted", false)):
        status_label.text = tr("Inventory mutation rejected: %s") % String(result.get("reason_id", &"unknown"))
        return
    if clear_selection:
        _selected_item_instance_id = &""
        _selected_equipment_slot_id = &""
        _clear_destroy_target()
    _refresh_snapshot()
    status_label.text = tr("%s. Change is live but unbanked until the next committed safe snapshot.") % success_text


func _drop_context_allowed() -> bool:
    if not _drop_request.is_valid() or not _drop_status_request.is_valid():
        return false
    var raw_status: Variant = _drop_status_request.call()
    return raw_status is Dictionary and bool((raw_status as Dictionary).get("allowed", false))


func _on_drop_pressed() -> void:
    if drop_button.disabled or not _selected_is_normal or _selected_item_instance_id == &"":
        return
    var item_id := _selected_item_instance_id
    var raw_result: Variant = _drop_request.call(item_id)
    if not raw_result is Dictionary:
        status_label.text = tr("Drop failed: invalid response.")
        return
    var result := raw_result as Dictionary
    if not bool(result.get("accepted", false)):
        status_label.text = tr("Drop rejected: %s") % String(result.get("reason_id", &"unknown"))
        return
    _selected_item_instance_id = &""
    _clear_destroy_target()
    _refresh_snapshot()
    var world_kind := StringName(String(result.get("world_kind", &"")))
    var destination_text := tr("Region 3") if world_kind == &"region3" else tr("this Tower floor")
    if bool(result.get("runtime_pickup_ready", false)):
        status_label.text = tr("Stack dropped into %s. The local pickup is live; the change remains unbanked until the next committed safe snapshot.") % destination_text
    else:
        status_label.text = tr("Stack moved into persistent %s drop state, but a live pickup could not be confirmed. The persisted drop remains restorable; the change is unbanked until the next committed safe snapshot.") % destination_text


func _on_destroy_pressed() -> void:
    if destroy_button.disabled or not _selected_is_normal or _selected_item_instance_id == &"" or _selected_normal_quantity <= 0:
        return
    destroy_confirm_label.text = tr("Destroy %s x%d? This removes the selected normal stack from the current live attempt.") % [
        String(_selected_item_instance_id),
        _selected_normal_quantity,
    ]
    destroy_confirm_row.visible = true
    destroy_confirm_button.grab_focus()


func _on_destroy_confirmed() -> void:
    if not destroy_confirm_row.visible or not _destroy_request.is_valid() or _selected_item_instance_id == &"" or _selected_normal_quantity <= 0:
        return
    var item_id := _selected_item_instance_id
    var quantity := _selected_normal_quantity
    var raw_result: Variant = _destroy_request.call(item_id, quantity, true)
    if not raw_result is Dictionary:
        status_label.text = tr("Destroy failed: invalid response.")
        destroy_confirm_row.visible = false
        return
    var result := raw_result as Dictionary
    if not bool(result.get("accepted", false)):
        status_label.text = tr("Destroy rejected: %s") % String(result.get("reason_id", &"unknown"))
        destroy_confirm_row.visible = false
        return
    _selected_item_instance_id = &""
    _clear_destroy_target()
    _refresh_snapshot()
    status_label.text = tr("Item destroyed. This change remains unbanked until the next committed safe snapshot.")


func _on_destroy_cancelled() -> void:
    destroy_confirm_row.visible = false
    status_label.text = tr("Destroy cancelled; no ownership changed.")
    if not destroy_button.disabled:
        destroy_button.grab_focus()


func _on_back_pressed() -> void:
    close_menu()
