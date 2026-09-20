class_name StorageHouseMenu
extends CanvasLayer

const MODAL_ID: StringName = &"ui:storage_house"
const STORAGE_STRUCTURE_ID: StringName = &"r3:functional:06"
const STORAGE_ROLE_ID: StringName = &"storage_house"
const VIEW_SERVICE: Script = preload("res://src/ui/storage_house_view_service.gd")

@onready var overlay: Control = $Overlay
@onready var summary_label: Label = $Overlay/Panel/Scroller/Layout/Summary
@onready var inventory_list: ItemList = $Overlay/Panel/Scroller/Layout/Body/InventoryColumn/InventoryList
@onready var storage_list: ItemList = $Overlay/Panel/Scroller/Layout/Body/StorageColumn/StorageList
@onready var detail_label: Label = $Overlay/Panel/Scroller/Layout/Detail
@onready var deposit_button: Button = $Overlay/Panel/Scroller/Layout/Actions/Deposit
@onready var withdraw_button: Button = $Overlay/Panel/Scroller/Layout/Actions/Withdraw
@onready var status_label: Label = $Overlay/Panel/Scroller/Layout/Status
@onready var back_button: Button = $Overlay/Panel/Scroller/Layout/Back

var _profile: ProfileSnapshot = null
var _input_ownership: InputOwnership = null
var _deposit_request: Callable = Callable()
var _withdraw_request: Callable = Callable()
var _snapshot: Dictionary = {}
var _selected_side: StringName = &""
var _selected_item_instance_id: StringName = &""
var _selected_quantity: int = 0
var _active_structure_id: StringName = &""


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    overlay.visible = false
    inventory_list.item_selected.connect(_on_inventory_selected)
    storage_list.item_selected.connect(_on_storage_selected)
    deposit_button.pressed.connect(_on_deposit_pressed)
    withdraw_button.pressed.connect(_on_withdraw_pressed)
    back_button.pressed.connect(_on_back_pressed)
    _clear_selection()


func configure(
    profile: ProfileSnapshot,
    input_ownership: InputOwnership,
    deposit_request: Callable,
    withdraw_request: Callable
) -> bool:
    if profile == null or input_ownership == null or not deposit_request.is_valid() or not withdraw_request.is_valid():
        return false
    _profile = profile
    _input_ownership = input_ownership
    _deposit_request = deposit_request
    _withdraw_request = withdraw_request
    return true


func set_profile(profile: ProfileSnapshot) -> bool:
    if profile == null:
        return false
    _profile = profile
    if overlay.visible:
        _refresh_snapshot()
    return true


func open_service(structure_id: StringName, role_id: StringName) -> bool:
    if structure_id != STORAGE_STRUCTURE_ID or role_id != STORAGE_ROLE_ID:
        return false
    if _profile == null or _input_ownership == null:
        return false
    if _input_ownership.is_modal_open() and _input_ownership.current_modal() != MODAL_ID:
        return false
    if not _refresh_snapshot():
        return false
    _active_structure_id = structure_id
    overlay.visible = true
    _input_ownership.open_modal(MODAL_ID)
    if inventory_list.item_count > 0:
        inventory_list.grab_focus()
    elif storage_list.item_count > 0:
        storage_list.grab_focus()
    else:
        back_button.grab_focus()
    return true


func close_menu(triggering_action: StringName = &"") -> void:
    if not overlay.visible:
        return
    overlay.visible = false
    _active_structure_id = &""
    _clear_selection()
    if _input_ownership != null:
        _input_ownership.close_modal(MODAL_ID, triggering_action)


func is_open() -> bool:
    return overlay.visible


func current_snapshot() -> Dictionary:
    return _snapshot.duplicate(true)


func active_structure_id() -> StringName:
    return _active_structure_id


func _refresh_snapshot() -> bool:
    if _profile == null:
        return false
    var view: Dictionary = VIEW_SERVICE.build_view(_profile)
    if not bool(view.get("accepted", false)):
        return false
    _snapshot = view.duplicate(true)
    _render_snapshot()
    return true


func _render_snapshot() -> void:
    summary_label.text = tr("Portable inventory: %d/%d | Hub storage: %d/%d") % [
        int(_snapshot.get("inventory_occupied", 0)),
        int(_snapshot.get("inventory_capacity", 16)),
        int(_snapshot.get("storage_occupied", 0)),
        int(_snapshot.get("storage_capacity", StorageState.DEFAULT_CAPACITY)),
    ]

    inventory_list.clear()
    for raw_entry: Variant in _snapshot.get("inventory_entries", []) as Array:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        inventory_list.add_item(_entry_line(entry))
        inventory_list.set_item_metadata(inventory_list.item_count - 1, entry.duplicate(true))

    storage_list.clear()
    for raw_entry: Variant in _snapshot.get("storage_entries", []) as Array:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        storage_list.add_item(_entry_line(entry))
        storage_list.set_item_metadata(storage_list.item_count - 1, entry.duplicate(true))

    _restore_or_clear_selection()
    if _selected_item_instance_id == &"":
        status_label.text = tr("Storage House service only. Select a full stack to deposit or withdraw. Transfers remain unbanked until the next committed safe snapshot.")


func _entry_line(entry: Dictionary) -> String:
    return "%s | x%d" % [String(entry.get("definition_id", &"")), int(entry.get("quantity", 1))]


func _restore_or_clear_selection() -> void:
    if _selected_item_instance_id == &"":
        _clear_selection()
        detail_label.text = tr("Select a portable or stored normal item.")
        return
    var entries := _snapshot.get("inventory_entries", []) as Array if _selected_side == &"inventory" else _snapshot.get("storage_entries", []) as Array
    for raw_entry: Variant in entries:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        if StringName(String(entry.get("item_instance_id", &""))) == _selected_item_instance_id:
            _set_selection(_selected_side, entry)
            return
    _clear_selection()
    detail_label.text = tr("Select a portable or stored normal item.")


func _set_selection(side: StringName, item: Dictionary) -> void:
    _selected_side = side
    _selected_item_instance_id = StringName(String(item.get("item_instance_id", &"")))
    _selected_quantity = int(item.get("quantity", 0))
    deposit_button.disabled = side != &"inventory" or _selected_quantity <= 0
    withdraw_button.disabled = side != &"storage" or _selected_quantity <= 0
    detail_label.text = _item_detail_text(item)


func _clear_selection() -> void:
    _selected_side = &""
    _selected_item_instance_id = &""
    _selected_quantity = 0
    if is_instance_valid(deposit_button):
        deposit_button.disabled = true
    if is_instance_valid(withdraw_button):
        withdraw_button.disabled = true


func _item_detail_text(item: Dictionary) -> String:
    var lines := PackedStringArray()
    lines.append(tr("Definition: %s") % String(item.get("definition_id", &"")))
    lines.append(tr("Instance: %s") % String(item.get("item_instance_id", &"")))
    lines.append(tr("Quantity: %d | Stackable: %s") % [int(item.get("quantity", 1)), tr("Yes") if bool(item.get("stackable", false)) else tr("No")])
    lines.append(tr("Rarity: %s") % (String(item.get("rarity", &"")) if bool(item.get("rarity_available", false)) else tr("unavailable")))
    lines.append(tr("Affixes: %s") % (_join_array(item.get("affixes", []) as Array) if bool(item.get("affixes_available", false)) else tr("unavailable")))
    lines.append(tr("Upgrade rank: %s") % (str(int(item.get("upgrade_rank", 0))) if bool(item.get("upgrade_rank_available", false)) else tr("unavailable")))
    lines.append(tr("Source claim: %s") % (String(item.get("source_claim_id", &"")) if bool(item.get("source_claim_id_available", false)) else tr("unavailable")))
    return "\n".join(lines)


func _join_array(values: Array) -> String:
    if values.is_empty():
        return tr("none")
    var parts := PackedStringArray()
    for value: Variant in values:
        parts.append(String(value))
    return ", ".join(parts)


func _on_inventory_selected(index: int) -> void:
    if index < 0 or index >= inventory_list.item_count:
        return
    var raw: Variant = inventory_list.get_item_metadata(index)
    if raw is Dictionary:
        _set_selection(&"inventory", raw as Dictionary)


func _on_storage_selected(index: int) -> void:
    if index < 0 or index >= storage_list.item_count:
        return
    var raw: Variant = storage_list.get_item_metadata(index)
    if raw is Dictionary:
        _set_selection(&"storage", raw as Dictionary)


func _on_deposit_pressed() -> void:
    if deposit_button.disabled or _selected_side != &"inventory":
        return
    _perform_transfer(_deposit_request, tr("Deposited"))


func _on_withdraw_pressed() -> void:
    if withdraw_button.disabled or _selected_side != &"storage":
        return
    _perform_transfer(_withdraw_request, tr("Withdrew"))


func _perform_transfer(request: Callable, verb: String) -> void:
    if not request.is_valid() or _selected_item_instance_id == &"" or _selected_quantity <= 0:
        return
    var raw_result: Variant = request.call(_selected_item_instance_id, _selected_quantity)
    if not raw_result is Dictionary:
        status_label.text = tr("Storage transfer failed: invalid response.")
        return
    var result := raw_result as Dictionary
    if not bool(result.get("accepted", false)):
        var reason := String(result.get("reason_id", &"unknown"))
        var destination_reason := String(result.get("destination_reason_id", &""))
        status_label.text = tr("Storage transfer rejected: %s%s") % [
            reason,
            (" / " + destination_reason) if not destination_reason.is_empty() else "",
        ]
        return
    _selected_item_instance_id = &""
    _selected_side = &""
    _selected_quantity = 0
    _refresh_snapshot()
    status_label.text = tr("%s full stack. Change is live but unbanked until the next committed safe snapshot.") % verb


func _on_back_pressed() -> void:
    close_menu()
