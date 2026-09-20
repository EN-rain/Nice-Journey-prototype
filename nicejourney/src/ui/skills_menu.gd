class_name SkillsMenu
extends CanvasLayer

const MODAL_ID: StringName = &"ui:skills"
const VIEW_SERVICE_SCRIPT: Script = preload("res://src/ui/skill_tree_view_service.gd")
const UI_ICON_CATALOG: Resource = preload("res://src/ui/presentation/ui_icon_catalog.tres")

@onready var overlay: Control = $Overlay
@onready var summary_label: Label = $Overlay/Panel/Layout/Summary
@onready var skill_list: ItemList = $Overlay/Panel/Layout/Body/SkillList
@onready var detail_label: Label = $Overlay/Panel/Layout/Body/DetailScroll/Detail
@onready var status_label: Label = $Overlay/Panel/Layout/Status
@onready var purchase_rank_button: Button = $Overlay/Panel/Layout/Actions/PurchaseRank
@onready var equip_slot_1_button: Button = $Overlay/Panel/Layout/Actions/EquipSlot1
@onready var equip_slot_2_button: Button = $Overlay/Panel/Layout/Actions/EquipSlot2
@onready var rank_confirmation_row: HBoxContainer = $Overlay/Panel/Layout/RankConfirmation
@onready var rank_confirmation_label: Label = $Overlay/Panel/Layout/RankConfirmation/Consequence
@onready var rank_confirm_button: Button = $Overlay/Panel/Layout/RankConfirmation/Confirm
@onready var rank_cancel_button: Button = $Overlay/Panel/Layout/RankConfirmation/Cancel
@onready var back_button: Button = $Overlay/Panel/Layout/Back

var _profile: ProfileSnapshot = null
var _input_ownership: InputOwnership = null
var _snapshot: Dictionary = {}
var _selected_skill_id: StringName = &""
var _rank_purchase_request: Callable = Callable()
var _loadout_swap_request: Callable = Callable()
var _interaction_state_provider: Callable = Callable()
var _transaction_id_provider: Callable = Callable()
var _pending_rank_purchase_skill_id: StringName = &""


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    overlay.visible = false
    skill_list.item_selected.connect(_on_item_selected)
    purchase_rank_button.pressed.connect(_on_purchase_rank_pressed)
    equip_slot_1_button.pressed.connect(func() -> void: _on_equip_slot_pressed(0))
    equip_slot_2_button.pressed.connect(func() -> void: _on_equip_slot_pressed(1))
    rank_confirm_button.pressed.connect(_on_rank_purchase_confirmed)
    rank_cancel_button.pressed.connect(_cancel_rank_purchase_confirmation)
    back_button.pressed.connect(_on_back_pressed)
    rank_confirmation_row.visible = false


func configure(profile: ProfileSnapshot, input_ownership: InputOwnership) -> bool:
    if profile == null or input_ownership == null:
        return false
    _profile = profile
    _input_ownership = input_ownership
    return true


func configure_progression_actions(
    rank_purchase_request: Callable,
    loadout_swap_request: Callable,
    interaction_state_provider: Callable,
    transaction_id_provider: Callable
) -> bool:
    if not rank_purchase_request.is_valid() or not loadout_swap_request.is_valid() or not interaction_state_provider.is_valid() or not transaction_id_provider.is_valid():
        return false
    _rank_purchase_request = rank_purchase_request
    _loadout_swap_request = loadout_swap_request
    _interaction_state_provider = interaction_state_provider
    _transaction_id_provider = transaction_id_provider
    if overlay.visible:
        _refresh_snapshot()
    return true


func clear_progression_actions() -> void:
    _rank_purchase_request = Callable()
    _loadout_swap_request = Callable()
    _interaction_state_provider = Callable()
    _transaction_id_provider = Callable()
    if overlay.visible:
        _refresh_snapshot()


func set_profile(profile: ProfileSnapshot) -> bool:
    if profile == null:
        return false
    _profile = profile
    if overlay.visible:
        _refresh_snapshot()
    return true


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed(&"skills"):
        return
    if overlay.visible:
        close_menu(&"skills")
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
    if skill_list.item_count > 0:
        skill_list.grab_focus()
    else:
        back_button.grab_focus()
    return true


func close_menu(triggering_action: StringName = &"") -> void:
    if not overlay.visible:
        return
    overlay.visible = false
    _cancel_rank_purchase_confirmation()
    clear_progression_actions()
    if _input_ownership != null:
        _input_ownership.close_modal(MODAL_ID, triggering_action)


func is_open() -> bool:
    return overlay.visible


func current_snapshot() -> Dictionary:
    return _snapshot.duplicate(true)


func selected_skill_id() -> StringName:
    return _selected_skill_id


func _refresh_snapshot() -> bool:
    if _profile == null:
        return false
    var snapshot: Dictionary = VIEW_SERVICE_SCRIPT.build_view(_profile, _build_action_capabilities())
    if not bool(snapshot.get("accepted", false)):
        return false
    _snapshot = snapshot.duplicate(true)
    _render_snapshot()
    return true


func _build_action_capabilities() -> Dictionary:
    var result: Dictionary = {
        "rank_purchase_commit_available": _rank_purchase_request.is_valid() and _transaction_id_provider.is_valid(),
        "loadout_swap_commit_available": _loadout_swap_request.is_valid() and _transaction_id_provider.is_valid(),
    }
    if not _interaction_state_provider.is_valid():
        return result
    var raw_state: Variant = _interaction_state_provider.call()
    if not raw_state is Dictionary:
        return result
    var state := raw_state as Dictionary
    if state.has("safe_interaction") and state.get("safe_interaction") is bool:
        result["safe_interaction"] = bool(state.get("safe_interaction"))
    if state.has("active_combat") and state.get("active_combat") is bool:
        result["active_combat"] = bool(state.get("active_combat"))
    return result


func _render_snapshot() -> void:
    skill_list.clear()
    summary_label.text = tr("Class: %s | Skill Points: %d | Active: %s | Passive: %s") % [
        String(_snapshot.get("class_id", &"")),
        int(_snapshot.get("skill_points", 0)),
        _slot_text(_snapshot.get("active_slots", []) as Array),
        _slot_text(_snapshot.get("passive_slots", []) as Array),
    ]
    if bool(_snapshot.get("rank_purchase_action_available", false)) or bool(_snapshot.get("loadout_swap_action_available", false)):
        status_label.text = tr("Durable skill actions are connected. Loadout swaps require a safe town/rest interaction outside Active Combat.")
    else:
        status_label.text = tr("Read-only tree/loadout preview. Rank spending and loadout swaps stay disabled until their durable-save and safe town/rest interaction owners are wired.")
    for raw_entry: Variant in _snapshot.get("entries", []) as Array:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        var skill_id := StringName(String(entry.get("skill_id", &"")))
        var label := "%s | %s | R%d/%d" % [
            String(entry.get("display_name", String(skill_id))),
            String(entry.get("kind", &"")),
            int(entry.get("rank", 0)),
            int(entry.get("max_rank", 0)),
        ]
        skill_list.add_item(label)
        var index := skill_list.item_count - 1
        skill_list.set_item_metadata(index, skill_id)
        var icon_id := StringName(entry.get("icon_id", &""))
        if icon_id != &"":
            var icon_profile: Variant = UI_ICON_CATALOG.call("get_profile", icon_id)
            if icon_profile != null:
                var texture_variant: Variant = icon_profile.get("texture")
                if texture_variant is Texture2D:
                    skill_list.set_item_icon(index, texture_variant as Texture2D)
    if skill_list.item_count == 0:
        _selected_skill_id = &""
        detail_label.text = tr("No valid class skill definitions are available.")
        _update_action_buttons({})
        return
    var selected_index := _find_selected_index()
    skill_list.select(selected_index)
    _show_entry(selected_index)


func _find_selected_index() -> int:
    if _selected_skill_id == &"":
        return 0
    for index: int in range(skill_list.item_count):
        if StringName(String(skill_list.get_item_metadata(index))) == _selected_skill_id:
            return index
    return 0


func _show_entry(index: int) -> void:
    var entries := _snapshot.get("entries", []) as Array
    if index < 0 or index >= entries.size() or not entries[index] is Dictionary:
        return
    var entry := entries[index] as Dictionary
    _selected_skill_id = StringName(String(entry.get("skill_id", &"")))
    var lines := PackedStringArray()
    lines.append(tr("%s (%s)") % [String(entry.get("display_name", String(_selected_skill_id))), String(_selected_skill_id)])
    lines.append(tr("Kind: %s | Rank: %d/%d | Learned: %s") % [
        String(entry.get("kind", &"")),
        int(entry.get("rank", 0)),
        int(entry.get("max_rank", 0)),
        tr("Yes") if bool(entry.get("learned", false)) else tr("No"),
    ])
    var slot_index := int(entry.get("equipped_slot_index", -1))
    lines.append(tr("Equipped: %s") % (tr("Slot %d") % (slot_index + 1) if slot_index >= 0 else tr("No")))
    lines.append(tr("Mechanic: %s") % String(entry.get("mechanic_id", &"")))
    lines.append(tr("Rank cost: %d skill point") % int(entry.get("rank_cost_skill_points", 1)))
    lines.append(tr("Irreversible rank purchase action: %s") % (tr("available with durable commit") if bool(entry.get("rank_purchase_available", false)) else tr("unavailable")))
    var cost_resource := StringName(entry.get("cost_resource", &""))
    if cost_resource == &"":
        lines.append(tr("Action resource: none declared"))
    else:
        lines.append(tr("Action resource: %s | Amount: not authored here") % String(cost_resource))
    var prerequisite := StringName(entry.get("prerequisite_event_id", &""))
    if prerequisite == &"":
        lines.append(tr("Prerequisite event: none"))
    else:
        lines.append(tr("Prerequisite event: %s | Satisfaction state: unavailable") % String(prerequisite))
    lines.append(tr("Incompatibility metadata: unavailable"))
    lines.append(tr("Loadout swap: %s") % (tr("available at this safe interaction") if bool(_snapshot.get("loadout_swap_action_available", false)) else tr("unavailable until safe town/rest interaction ownership is wired")))
    var temp := _snapshot.get("temporary_override", {}) as Dictionary
    if not temp.is_empty():
        lines.append("")
        lines.append(tr("Temporary override: slot %d = %s; displaced %s") % [
            int(temp.get("slot_index", -1)) + 1,
            String(temp.get("temporary_skill_id", &"")),
            String(temp.get("displaced_skill_id", &"")),
        ])
    detail_label.text = "\n".join(lines)
    _update_action_buttons(entry)


func _update_action_buttons(entry: Dictionary) -> void:
    purchase_rank_button.disabled = not bool(entry.get("rank_purchase_available", false))
    var learned := bool(entry.get("learned", false))
    var loadout_available := bool(_snapshot.get("loadout_swap_action_available", false)) and learned
    var current_slot := int(entry.get("equipped_slot_index", -1))
    var kind := StringName(entry.get("kind", &""))
    var temporary := _snapshot.get("temporary_override", {}) as Dictionary
    for slot_index: int in range(2):
        var button := equip_slot_1_button if slot_index == 0 else equip_slot_2_button
        var temporary_locked := kind == SkillDefinition.KIND_ACTIVE and not temporary.is_empty() and int(temporary.get("slot_index", -1)) == slot_index
        button.disabled = not loadout_available or current_slot == slot_index or temporary_locked


func _slot_text(slots: Array) -> String:
    var values := PackedStringArray()
    for raw_skill_id: Variant in slots:
        var skill_id := String(raw_skill_id)
        values.append(skill_id if not skill_id.is_empty() else tr("Empty"))
    return " / ".join(values)


func _on_item_selected(index: int) -> void:
    _cancel_rank_purchase_confirmation()
    _show_entry(index)


func _on_purchase_rank_pressed() -> void:
    if purchase_rank_button.disabled or not _rank_purchase_request.is_valid() or _selected_skill_id == &"":
        return
    _pending_rank_purchase_skill_id = _selected_skill_id
    var entry := _selected_entry()
    var display_name := String(entry.get("display_name", String(_selected_skill_id)))
    rank_confirmation_label.text = tr("Spend 1 skill point to increase %s? Rank spending is permanent; the prototype has no respec/refund.") % display_name
    rank_confirmation_row.visible = true
    purchase_rank_button.disabled = true
    equip_slot_1_button.disabled = true
    equip_slot_2_button.disabled = true
    rank_confirm_button.grab_focus()


func _on_rank_purchase_confirmed() -> void:
    if _pending_rank_purchase_skill_id == &"" or not _rank_purchase_request.is_valid():
        _cancel_rank_purchase_confirmation()
        return
    var skill_id := _pending_rank_purchase_skill_id
    var transaction_id := _next_transaction_id(&"rank_purchase", skill_id, -1)
    if transaction_id == &"":
        _cancel_rank_purchase_confirmation()
        status_label.text = tr("Rank purchase rejected: invalid transaction identity.")
        return
    _pending_rank_purchase_skill_id = &""
    rank_confirmation_row.visible = false
    _perform_progression_request(_rank_purchase_request.call(skill_id, transaction_id), tr("Rank purchase"))


func _cancel_rank_purchase_confirmation() -> void:
    _pending_rank_purchase_skill_id = &""
    if is_instance_valid(rank_confirmation_row):
        rank_confirmation_row.visible = false
    if overlay != null and overlay.visible and not _snapshot.is_empty():
        var index := _find_selected_index()
        if index >= 0 and index < skill_list.item_count:
            _show_entry(index)


func _on_equip_slot_pressed(slot_index: int) -> void:
    if slot_index < 0 or slot_index >= 2 or _selected_skill_id == &"" or not _loadout_swap_request.is_valid():
        return
    var button := equip_slot_1_button if slot_index == 0 else equip_slot_2_button
    if button.disabled:
        return
    var entry := _selected_entry()
    if entry.is_empty():
        return
    var kind := StringName(entry.get("kind", &""))
    var capabilities := _build_action_capabilities()
    if not capabilities.has("safe_interaction") or not capabilities.has("active_combat"):
        status_label.text = tr("Loadout swap rejected: safe interaction state unavailable.")
        return
    var transaction_id := _next_transaction_id(&"loadout_swap", _selected_skill_id, slot_index)
    if transaction_id == &"":
        status_label.text = tr("Loadout swap rejected: invalid transaction identity.")
        return
    _perform_progression_request(
        _loadout_swap_request.call(
            kind,
            slot_index,
            _selected_skill_id,
            transaction_id,
            bool(capabilities.get("safe_interaction", false)),
            bool(capabilities.get("active_combat", true))
        ),
        tr("Loadout swap")
    )


func _next_transaction_id(operation_id: StringName, skill_id: StringName, slot_index: int) -> StringName:
    if not _transaction_id_provider.is_valid():
        return &""
    var raw_id: Variant = _transaction_id_provider.call(operation_id, skill_id, slot_index)
    var transaction_id := StringName(String(raw_id))
    return transaction_id if StableId.is_valid(String(transaction_id)) else &""


func _perform_progression_request(raw_result: Variant, label: String) -> void:
    if not raw_result is Dictionary:
        status_label.text = tr("%s failed: invalid response.") % label
        return
    var result := raw_result as Dictionary
    if not bool(result.get("accepted", false)) or not bool(result.get("durable", false)):
        status_label.text = tr("%s rejected: %s") % [label, String(result.get("reason_id", &"non_durable_result"))]
        return
    if not _refresh_snapshot():
        status_label.text = tr("%s committed, but the refreshed skill state is invalid.") % label
        return
    status_label.text = tr("%s committed and saved.") % label


func _selected_entry() -> Dictionary:
    for raw_entry: Variant in _snapshot.get("entries", []) as Array:
        if raw_entry is Dictionary and StringName(String((raw_entry as Dictionary).get("skill_id", &""))) == _selected_skill_id:
            return (raw_entry as Dictionary).duplicate(true)
    return {}


func _on_back_pressed() -> void:
    close_menu()
