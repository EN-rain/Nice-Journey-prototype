class_name MerchantMenu
extends CanvasLayer

const MODAL_ID: StringName = &"ui:merchant"
const VIEW_SERVICE: Script = preload("res://src/ui/merchant_view_service.gd")

@onready var overlay: Control = $Overlay
@onready var title_label: Label = $Overlay/Panel/Layout/Title
@onready var summary_label: Label = $Overlay/Panel/Layout/Summary
@onready var stock_list: ItemList = $Overlay/Panel/Layout/Body/StockColumn/Stock
@onready var sell_list: ItemList = $Overlay/Panel/Layout/Body/SellColumn/Sell
@onready var detail_label: Label = $Overlay/Panel/Layout/Detail
@onready var quantity: SpinBox = $Overlay/Panel/Layout/Actions/Quantity
@onready var buy_button: Button = $Overlay/Panel/Layout/Actions/Buy
@onready var sell_button: Button = $Overlay/Panel/Layout/Actions/Sell
@onready var clinic_recovery_button: Button = $Overlay/Panel/Layout/Actions/ClinicRecovery
@onready var status_label: Label = $Overlay/Panel/Layout/Status
@onready var back_button: Button = $Overlay/Panel/Layout/Back

var _profile: ProfileSnapshot = null
var _input_ownership: InputOwnership = null
var _buy_request: Callable = Callable()
var _sell_request: Callable = Callable()
var _clinic_recovery_request: Callable = Callable()
var _vendor_id: StringName = &""
var _snapshot: Dictionary = {}
var _selected_mode: StringName = &""
var _selected_definition_id: StringName = &""
var _selected_item_instance_id: StringName = &""
var _selected_unit_price: int = 0
var _selected_stock: int = 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    overlay.visible = false
    stock_list.item_selected.connect(_on_stock_selected)
    sell_list.item_selected.connect(_on_sell_selected)
    buy_button.pressed.connect(_on_buy_pressed)
    quantity.value_changed.connect(_on_quantity_changed)
    sell_button.pressed.connect(_on_sell_pressed)
    clinic_recovery_button.pressed.connect(_on_clinic_recovery_pressed)
    back_button.pressed.connect(_on_back_pressed)
    quantity.min_value = 1.0
    quantity.max_value = float(NormalStackQuantityValidator.MAX_QUANTITY)
    quantity.step = 1.0
    buy_button.disabled = true
    sell_button.disabled = true


func configure(
    profile: ProfileSnapshot,
    input_ownership: InputOwnership,
    buy_request: Callable,
    sell_request: Callable,
    clinic_recovery_request: Callable = Callable()
) -> bool:
    if profile == null or input_ownership == null or not buy_request.is_valid() or not sell_request.is_valid():
        return false
    _profile = profile
    _input_ownership = input_ownership
    _buy_request = buy_request
    _sell_request = sell_request
    _clinic_recovery_request = clinic_recovery_request
    return true


func set_profile(profile: ProfileSnapshot) -> bool:
    if profile == null:
        return false
    _profile = profile
    if overlay.visible:
        _refresh_snapshot()
    return true


func open_service(vendor_id: StringName) -> bool:
    if _profile == null or _input_ownership == null or not StableId.is_valid(String(vendor_id)):
        return false
    if _input_ownership.is_modal_open() and _input_ownership.current_modal() != MODAL_ID:
        return false
    _vendor_id = vendor_id
    clinic_recovery_button.visible = vendor_id == &"vendor:clinic_apothecary" and _clinic_recovery_request.is_valid()
    if not _refresh_snapshot():
        _vendor_id = &""
        return false
    overlay.visible = true
    _input_ownership.open_modal(MODAL_ID)
    if stock_list.item_count > 0:
        stock_list.grab_focus()
    elif sell_list.item_count > 0:
        sell_list.grab_focus()
    else:
        back_button.grab_focus()
    return true


func close_menu(triggering_action: StringName = &"") -> void:
    if not overlay.visible:
        return
    overlay.visible = false
    _vendor_id = &""
    clinic_recovery_button.visible = false
    _clear_selection()
    if _input_ownership != null:
        _input_ownership.close_modal(MODAL_ID, triggering_action)


func is_open() -> bool:
    return overlay.visible


func current_snapshot() -> Dictionary:
    return _snapshot.duplicate(true)


func active_vendor_id() -> StringName:
    return _vendor_id


func _refresh_snapshot() -> bool:
    var view: Dictionary = VIEW_SERVICE.build_view(_profile, _vendor_id)
    if not bool(view.get("accepted", false)):
        status_label.text = tr("Merchant view unavailable: %s") % String(view.get("reason_id", &"unknown"))
        return false
    _snapshot = view.duplicate(true)
    _render_snapshot()
    return true


func _render_snapshot() -> void:
    title_label.text = tr("Merchant — %s") % String(_vendor_id)
    summary_label.text = tr("Gold: %d | Stock and prices are persisted authored state") % int(_snapshot.get("gold", 0))
    stock_list.clear()
    for raw_entry: Variant in _snapshot.get("stock_entries", []) as Array:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        stock_list.add_item("%s | buy %d | stock %d" % [
            String(entry.get("definition_id", &"")),
            int(entry.get("buy_price", 0)),
            int(entry.get("quantity", 0)),
        ])
        stock_list.set_item_metadata(stock_list.item_count - 1, entry.duplicate(true))
    sell_list.clear()
    for raw_entry: Variant in _snapshot.get("sell_entries", []) as Array:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        sell_list.add_item("%s x%d | sell %d" % [
            String(entry.get("definition_id", &"")),
            int(entry.get("quantity", 0)),
            int(entry.get("sell_price", 0)),
        ])
        sell_list.set_item_metadata(sell_list.item_count - 1, entry.duplicate(true))
    _clear_selection()
    status_label.text = tr("Buy/sell uses the active vendor's persisted stock and authored prices. Accepted changes remain unbanked until the next committed safe snapshot.")


func _on_clinic_recovery_pressed() -> void:
    if _vendor_id != &"vendor:clinic_apothecary" or not _clinic_recovery_request.is_valid():
        return
    var raw_result: Variant = _clinic_recovery_request.call(Region3RecoveryServiceDefinition.ROLE_CLINIC_APOTHECARY)
    if not raw_result is Dictionary:
        status_label.text = tr("Clinic recovery unavailable.")
        return
    var result := raw_result as Dictionary
    if bool(result.get("accepted", false)):
        _refresh_snapshot()
        status_label.text = tr("Clinic recovery saved.")
    else:
        status_label.text = tr("Clinic recovery unavailable: %s") % String(result.get("reason_id", &"unknown"))


func _on_stock_selected(index: int) -> void:
    if index < 0 or index >= stock_list.item_count:
        return
    var entry := stock_list.get_item_metadata(index) as Dictionary
    _selected_mode = &"buy"
    _selected_definition_id = StringName(String(entry.get("definition_id", &"")))
    _selected_item_instance_id = &""
    var available := int(entry.get("quantity", 0))
    _selected_unit_price = int(entry.get("buy_price", 0))
    _selected_stock = available
    var maximum := 1 if not bool(entry.get("stackable", false)) else mini(available, NormalStackQuantityValidator.MAX_QUANTITY)
    quantity.max_value = float(maxi(1, maximum))
    quantity.value = 1.0
    sell_button.disabled = true
    _update_buy_affordability()


func _on_sell_selected(index: int) -> void:
    if index < 0 or index >= sell_list.item_count:
        return
    var entry := sell_list.get_item_metadata(index) as Dictionary
    _selected_mode = &"sell"
    _selected_definition_id = StringName(String(entry.get("definition_id", &"")))
    _selected_item_instance_id = StringName(String(entry.get("item_instance_id", &"")))
    _selected_unit_price = 0
    _selected_stock = 0
    var owned := int(entry.get("quantity", 0))
    quantity.max_value = float(maxi(1, owned))
    quantity.value = 1.0
    buy_button.disabled = true
    sell_button.disabled = owned <= 0
    detail_label.text = tr("Sell %s | unit price %d | owned %d") % [
        String(_selected_definition_id), int(entry.get("sell_price", 0)), owned
    ]


func _on_quantity_changed(_value: float) -> void:
    if _selected_mode == &"buy":
        _update_buy_affordability()


func _update_buy_affordability() -> void:
    if _selected_mode != &"buy":
        return
    var requested := int(quantity.value)
    var cost := requested * _selected_unit_price
    var gold := int(_snapshot.get("gold", 0))
    var in_stock := requested > 0 and requested <= _selected_stock
    var affordable := _selected_unit_price >= 0 and cost <= gold
    buy_button.disabled = not in_stock or not affordable
    detail_label.text = tr("Buy %s | qty %d | total %d Gold | owned %d Gold | stock %d%s") % [
        String(_selected_definition_id), requested, cost, gold, _selected_stock,
        tr(" — insufficient Gold") if not affordable else (tr(" — out of stock") if not in_stock else ""),
    ]


func _on_buy_pressed() -> void:
    if buy_button.disabled or _selected_mode != &"buy" or _selected_definition_id == &"":
        return
    _apply_transaction(_buy_request.call(_selected_definition_id, int(quantity.value)), tr("Purchase completed"))


func _on_sell_pressed() -> void:
    if sell_button.disabled or _selected_mode != &"sell" or _selected_item_instance_id == &"":
        return
    _apply_transaction(_sell_request.call(_selected_item_instance_id, int(quantity.value)), tr("Sale completed"))


func _apply_transaction(raw_result: Variant, success_text: String) -> void:
    if not raw_result is Dictionary:
        status_label.text = tr("Merchant transaction failed: invalid response.")
        return
    var result := raw_result as Dictionary
    if not bool(result.get("accepted", false)):
        status_label.text = tr("Merchant transaction rejected: %s") % String(result.get("reason_id", &"unknown"))
        return
    _refresh_snapshot()
    status_label.text = tr("%s. Change is live but unbanked until the next committed safe snapshot.") % success_text


func _clear_selection() -> void:
    _selected_mode = &""
    _selected_definition_id = &""
    _selected_item_instance_id = &""
    _selected_unit_price = 0
    _selected_stock = 0
    quantity.value = 1.0
    quantity.max_value = float(NormalStackQuantityValidator.MAX_QUANTITY)
    buy_button.disabled = true
    sell_button.disabled = true
    detail_label.text = tr("Select persisted vendor stock to buy or an owned sellable item to sell.")


func _on_back_pressed() -> void:
    close_menu()
