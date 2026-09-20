class_name QuestLogMenu
extends CanvasLayer

const MODAL_ID: StringName = &"ui:quest_log"
const VIEW_SERVICE_SCRIPT: Script = preload("res://src/ui/quest_log_view_service.gd")

@onready var overlay: Control = $Overlay
@onready var quest_list: ItemList = $Overlay/Panel/Layout/Body/QuestList
@onready var detail_label: Label = $Overlay/Panel/Layout/Body/DetailScroll/Detail
@onready var status_label: Label = $Overlay/Panel/Layout/Status
@onready var pending_row: HBoxContainer = $Overlay/Panel/Layout/PendingRow
@onready var pending_selector: OptionButton = $Overlay/Panel/Layout/PendingRow/PendingSelector
@onready var claim_pending_button: Button = $Overlay/Panel/Layout/PendingRow/ClaimPending
@onready var back_button: Button = $Overlay/Panel/Layout/Back

var _profile: ProfileSnapshot = null
var _input_ownership: InputOwnership = null
var _claim_request: Callable = Callable()
var _claim_status: Callable = Callable()
var _snapshot: Dictionary = {}
var _selected_quest_id: StringName = &""


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    overlay.visible = false
    quest_list.item_selected.connect(_on_item_selected)
    claim_pending_button.pressed.connect(_on_claim_pending_pressed)
    back_button.pressed.connect(_on_back_pressed)


func configure(
    profile: ProfileSnapshot,
    input_ownership: InputOwnership,
    claim_request: Callable = Callable(),
    claim_status: Callable = Callable()
) -> bool:
    if profile == null or input_ownership == null:
        return false
    _profile = profile
    _input_ownership = input_ownership
    _claim_request = claim_request
    _claim_status = claim_status
    return true


func set_profile(profile: ProfileSnapshot) -> bool:
    if profile == null:
        return false
    _profile = profile
    if overlay.visible:
        var snapshot: Dictionary = VIEW_SERVICE_SCRIPT.build_log(_profile)
        if bool(snapshot.get("accepted", false)):
            _snapshot = snapshot.duplicate(true)
            _render_snapshot()
    return true


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed(&"quest_log"):
        return
    if overlay.visible:
        close_menu(&"quest_log")
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
    var snapshot: Dictionary = VIEW_SERVICE_SCRIPT.build_log(_profile)
    if not bool(snapshot.get("accepted", false)):
        return false
    _snapshot = snapshot.duplicate(true)
    overlay.visible = true
    _input_ownership.open_modal(MODAL_ID)
    _render_snapshot()
    if quest_list.item_count > 0:
        quest_list.grab_focus()
    else:
        back_button.grab_focus()
    return true


func close_menu(triggering_action: StringName = &"") -> void:
    if not overlay.visible:
        return
    overlay.visible = false
    if _input_ownership != null:
        _input_ownership.close_modal(MODAL_ID, triggering_action)


func is_open() -> bool:
    return overlay.visible


func current_snapshot() -> Dictionary:
    return _snapshot.duplicate(true)


func selected_quest_id() -> StringName:
    return _selected_quest_id


func _render_snapshot() -> void:
    quest_list.clear()
    var entries := _snapshot.get("entries", []) as Array
    _render_pending_rewards()
    var pending_count := int(_snapshot.get("pending_reward_claim_count", 0))
    if pending_count > 0:
        status_label.text = tr("Reward waiting — inventory full. %d pending normal-reward claim(s). Claim becomes durable only at the next committed safe snapshot.") % pending_count
    else:
        status_label.text = tr("Read-only quest state. Contract metadata is shown only when explicitly authored.")
    for raw_entry: Variant in entries:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        var quest_id := StringName(String(entry.get("quest_id", &"")))
        var kind := String(entry.get("kind", &""))
        var state := String(entry.get("quest_state", &""))
        quest_list.add_item("%s | %s | %s" % [String(quest_id), kind, state])
        quest_list.set_item_metadata(quest_list.item_count - 1, quest_id)
    if quest_list.item_count == 0:
        _selected_quest_id = &""
        var empty_lines := PackedStringArray([tr("No persisted quest entries are currently present in this profile.")])
        empty_lines.append_array(_pending_reward_lines())
        detail_label.text = "\n".join(empty_lines)
        return
    var selected_index := _find_selected_index()
    quest_list.select(selected_index)
    _show_entry(selected_index)


func _find_selected_index() -> int:
    if _selected_quest_id == &"":
        return 0
    for index: int in range(quest_list.item_count):
        if StringName(String(quest_list.get_item_metadata(index))) == _selected_quest_id:
            return index
    return 0


func _show_entry(index: int) -> void:
    var entries := _snapshot.get("entries", []) as Array
    if index < 0 or index >= entries.size() or not entries[index] is Dictionary:
        return
    var entry := entries[index] as Dictionary
    _selected_quest_id = StringName(String(entry.get("quest_id", &"")))
    var lines := PackedStringArray()
    lines.append(tr("Quest: %s") % String(_selected_quest_id))
    lines.append(tr("Kind / family: %s / %s") % [String(entry.get("kind", &"")), String(entry.get("family", &""))])
    lines.append(tr("State: %s") % String(entry.get("quest_state", &"")))
    lines.append(tr("Current required step: %s") % _required_step_text(entry))
    lines.append(tr("Map location: %s") % _location_text(entry))
    lines.append(tr("Acceptance anchor: %s") % _single_id_contract_text(entry, "acceptance_anchor_available", "acceptance_anchor_id"))
    lines.append(tr("Turn-in anchor: %s") % _turn_in_anchor_text(entry))
    lines.append(tr("Prerequisites: %s") % _id_array_contract_text(entry, "prerequisite_authoring_available", "prerequisite_ids"))
    lines.append(tr("Leave rule: %s") % _single_id_contract_text(entry, "leave_policy_available", "leave_rule_id"))
    lines.append(tr("Failure rule: %s") % _single_id_contract_text(entry, "failure_policy_available", "failure_rule_id"))
    lines.append(tr("Retry reset: %s") % _id_array_contract_text(entry, "retry_policy_available", "retry_reset_ids"))
    lines.append(tr("Rewards: %s") % _id_array_contract_text(entry, "reward_authoring_available", "reward_ids"))
    lines.append(tr("Branch effects: %s") % _id_array_contract_text(entry, "branch_effect_authoring_available", "branch_effect_ids"))
    lines.append(tr("Completion conditions: %s") % _id_array_contract_text(entry, "completion_authoring_available", "completion_condition_ids"))
    var leave_reason := StringName(String(entry.get("last_leave_reason_id", &"")))
    if leave_reason != &"":
        lines.append(tr("Recorded leave reason: %s") % String(leave_reason))
    var failure_reason := StringName(String(entry.get("failure_reason_id", &"")))
    if failure_reason != &"":
        lines.append(tr("Recorded failure reason: %s") % String(failure_reason))
    if bool(entry.get("completed_outcome_available", false)):
        lines.append(tr("Completed outcome: %s") % String(entry.get("completed_outcome_state", &"")))
    else:
        lines.append(tr("Completed outcome: not completed"))
    if bool(entry.get("playtest_placeholder", false)):
        lines.append(tr("Content status: playtest placeholder"))
    lines.append_array(_pending_reward_lines())
    detail_label.text = "\n".join(lines)


func _single_id_contract_text(entry: Dictionary, availability_key: String, value_key: String) -> String:
    if not bool(entry.get(availability_key, false)):
        return tr("authoring unavailable")
    var value := StringName(String(entry.get(value_key, &"")))
    return String(value) if value != &"" else tr("authoring unavailable")


func _turn_in_anchor_text(entry: Dictionary) -> String:
    if not bool(entry.get("turn_in_authoring_available", false)):
        return tr("authoring unavailable")
    if not bool(entry.get("turn_in_anchor_available", false)):
        return tr("automatic completion")
    return String(entry.get("turn_in_anchor_id", &""))


func _id_array_contract_text(entry: Dictionary, availability_key: String, value_key: String) -> String:
    if not bool(entry.get(availability_key, false)):
        return tr("authoring unavailable")
    var values := entry.get(value_key, []) as Array
    if values.is_empty():
        return tr("none")
    var rendered := PackedStringArray()
    for raw_value: Variant in values:
        rendered.append(String(raw_value))
    return ", ".join(rendered)


func _required_step_text(entry: Dictionary) -> String:
    var stage_id := StringName(String(entry.get("stage_id", &"")))
    var base := String(stage_id) if stage_id != &"" else tr("No persisted stage")
    match StringName(entry.get("progress_kind", VIEW_SERVICE_SCRIPT.PROGRESS_UNBOUND)):
        VIEW_SERVICE_SCRIPT.PROGRESS_ANNIHILATION:
            return tr("%s — Defeated %d/%d") % [base, int(entry.get("defeated_count", 0)), int(entry.get("required_count", 0))]
        VIEW_SERVICE_SCRIPT.PROGRESS_ESCORT:
            var text := tr("%s — Route %d/%d") % [base, int(entry.get("next_route_index", 0)), int(entry.get("route_count", 0))]
            if bool(entry.get("wait_requested", false)):
                text += tr(" — Wait")
            return text
        VIEW_SERVICE_SCRIPT.PROGRESS_TOWER_DEFENSE:
            return tr("%s — Waves %d/%d — Objective HP %d/%d") % [
                base,
                int(entry.get("completed_wave_count", 0)),
                int(entry.get("wave_count", 0)),
                int(entry.get("objective_current_hp", 0)),
                int(entry.get("objective_max_hp", 0)),
            ]
        VIEW_SERVICE_SCRIPT.PROGRESS_BOSS:
            return tr("%s — Boss defeated: %s") % [base, tr("Yes") if bool(entry.get("boss_defeated", false)) else tr("No")]
        _:
            return base


func _location_text(entry: Dictionary) -> String:
    var scope_id := String(entry.get("scope_id", &""))
    var floor_id := int(entry.get("floor_id", 0))
    return tr("%s — Tower Floor %d") % [scope_id, floor_id] if floor_id > 0 else scope_id


func _pending_reward_lines() -> PackedStringArray:
    var pending := _snapshot.get("pending_reward_claims", []) as Array
    if pending.is_empty():
        return PackedStringArray()
    var lines := PackedStringArray(["", tr("Reward waiting — inventory full:")])
    for raw_claim: Variant in pending:
        if not raw_claim is Dictionary:
            continue
        var claim := raw_claim as Dictionary
        lines.append(tr("Claim %s | source %s") % [String(claim.get("claim_id", &"")), String(claim.get("source_id", &""))])
        for raw_reward: Variant in claim.get("normal_rewards", []) as Array:
            if not raw_reward is Dictionary:
                continue
            var reward := raw_reward as Dictionary
            lines.append(tr("  %s | instance %s | qty %d") % [
                String(reward.get("definition_id", &"")),
                String(reward.get("item_instance_id", &"")),
                int(reward.get("quantity", 0)),
            ])
    lines.append(tr("Claim action: outside Active Combat; unbanked until the next committed safe snapshot."))
    return lines


func _render_pending_rewards() -> void:
    var previously_selected: StringName = &""
    if pending_selector.selected >= 0 and pending_selector.selected < pending_selector.item_count:
        previously_selected = StringName(String(pending_selector.get_item_metadata(pending_selector.selected)))
    pending_selector.clear()
    var pending := _snapshot.get("pending_reward_claims", []) as Array
    pending_row.visible = not pending.is_empty()
    for raw_claim: Variant in pending:
        if not raw_claim is Dictionary:
            continue
        var claim := raw_claim as Dictionary
        var claim_id := StringName(String(claim.get("claim_id", &"")))
        var quantity := int(claim.get("total_quantity", 0))
        pending_selector.add_item(tr("%s — %d item(s)") % [String(claim_id), quantity])
        pending_selector.set_item_metadata(pending_selector.item_count - 1, claim_id)
    if pending_selector.item_count > 0:
        var chosen := 0
        for index: int in range(pending_selector.item_count):
            if StringName(String(pending_selector.get_item_metadata(index))) == previously_selected:
                chosen = index
                break
        pending_selector.select(chosen)
    _refresh_claim_availability()


func _refresh_claim_availability() -> void:
    if not pending_row.visible or pending_selector.item_count == 0:
        claim_pending_button.disabled = true
        return
    if not _claim_request.is_valid() or not _claim_status.is_valid():
        claim_pending_button.disabled = true
        claim_pending_button.text = tr("Claim unavailable")
        return
    var status: Variant = _claim_status.call()
    if not status is Dictionary:
        claim_pending_button.disabled = true
        claim_pending_button.text = tr("Claim unavailable")
        return
    var allowed := bool((status as Dictionary).get("allowed", false))
    claim_pending_button.disabled = not allowed
    claim_pending_button.text = tr("Claim") if allowed else tr("Claim blocked")


func _process(_delta: float) -> void:
    if overlay.visible and pending_row.visible:
        _refresh_claim_availability()


func _on_claim_pending_pressed() -> void:
    if pending_selector.item_count == 0 or not _claim_request.is_valid():
        return
    var index := pending_selector.selected
    if index < 0 or index >= pending_selector.item_count:
        return
    var claim_id := StringName(String(pending_selector.get_item_metadata(index)))
    var raw_result: Variant = _claim_request.call(claim_id)
    if not raw_result is Dictionary:
        status_label.text = tr("Reward claim failed: invalid response.")
        return
    var result := raw_result as Dictionary
    if not bool(result.get("accepted", false)):
        status_label.text = tr("Reward claim blocked: %s") % String(result.get("reason_id", &"unknown"))
        _refresh_claim_availability()
        return
    var snapshot: Dictionary = VIEW_SERVICE_SCRIPT.build_log(_profile)
    if bool(snapshot.get("accepted", false)):
        _snapshot = snapshot.duplicate(true)
        _render_snapshot()
    var autosave_status := result.get("autosave_status", {}) as Dictionary
    var autosave_state := StringName(String(autosave_status.get("state", &"")))
    if autosave_state == SaveRequestCoordinator.STATE_SUCCEEDED:
        status_label.text = tr("Reward claimed and saved.")
    elif autosave_state == SaveRequestCoordinator.STATE_PENDING:
        var reason_text := String(autosave_status.get("reason_text", "")).strip_edges()
        status_label.text = tr("Reward claimed. Save pending%s") % (": %s" % reason_text if not reason_text.is_empty() else ".")
    else:
        status_label.text = tr("Reward claimed. It remains unbanked until the next committed safe snapshot.")


func _on_item_selected(index: int) -> void:
    _show_entry(index)


func _on_back_pressed() -> void:
    close_menu()
