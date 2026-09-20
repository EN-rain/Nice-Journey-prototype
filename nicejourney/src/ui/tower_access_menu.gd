class_name TowerAccessMenu
extends CanvasLayer

signal floor_selected(floor_id: int, danger_confirmed: bool)

const MODAL_ID: StringName = &"ui:tower_access"

@export var floor_button_scene: PackedScene

@onready var overlay: Control = $Overlay
@onready var title_label: Label = $Overlay/Panel/Layout/Title
@onready var status_label: Label = $Overlay/Panel/Layout/Status
@onready var floor_list: VBoxContainer = $Overlay/Panel/Layout/Scroll/FloorList
@onready var confirmation_panel: VBoxContainer = $Overlay/Panel/Layout/Confirmation
@onready var confirmation_label: Label = $Overlay/Panel/Layout/Confirmation/Message
@onready var confirm_button: Button = $Overlay/Panel/Layout/Confirmation/Buttons/Confirm
@onready var cancel_confirmation_button: Button = $Overlay/Panel/Layout/Confirmation/Buttons/Cancel
@onready var back_button: Button = $Overlay/Panel/Layout/Back

var _profile: ProfileSnapshot = null
var _input_ownership: InputOwnership = null
var _operation_guard: GameplayOperationGuard = null
var _entries_by_floor: Dictionary = {}
var _pending_floor_id: int = 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    overlay.visible = false
    confirmation_panel.visible = false
    confirm_button.pressed.connect(_on_confirm_pressed)
    cancel_confirmation_button.pressed.connect(_on_cancel_confirmation_pressed)
    back_button.pressed.connect(_on_back_pressed)

func configure(profile: ProfileSnapshot, input_ownership: InputOwnership, operation_guard: GameplayOperationGuard = null) -> bool:
    if profile == null or input_ownership == null:
        return false
    _profile = profile
    _input_ownership = input_ownership
    _operation_guard = operation_guard
    return true

func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed(&"sigil_menu"):
        return
    if overlay.visible:
        close_menu(&"sigil_menu")
        get_viewport().set_input_as_handled()
        return
    if _input_ownership != null and _input_ownership.is_modal_open():
        return
    if open_menu():
        get_viewport().set_input_as_handled()

func open_menu() -> bool:
    if _profile == null or _input_ownership == null:
        return false
    var menu := TowerAccessMenuService.build_menu(_profile, _operation_guard)
    if not bool(menu.get("accepted", false)):
        return false
    if floor_button_scene == null:
        push_error("Tower floor button scene is not assigned")
        return false
    _entries_by_floor.clear()
    _pending_floor_id = 0
    confirmation_panel.visible = false
    _clear_floor_buttons()
    var entries: Array = menu.get("entries", []) as Array
    for raw_entry: Variant in entries:
        if not raw_entry is Dictionary:
            continue
        var entry := (raw_entry as Dictionary).duplicate(true)
        var floor_id := int(entry.get("floor_id", 0))
        if floor_id <= 0:
            continue
        _entries_by_floor[floor_id] = entry
        var button := floor_button_scene.instantiate() as Button
        if button == null:
            push_error("Tower floor button scene must instantiate a Button")
            return false
        button.name = "Floor%d" % floor_id
        button.text = _entry_label(entry)
        button.pressed.connect(_on_floor_pressed.bind(floor_id))
        floor_list.add_child(button)
    title_label.text = tr("Tower Access")
    status_label.text = tr("Select a cleared or currently unlocked floor.")
    overlay.visible = true
    _input_ownership.open_modal(MODAL_ID)
    if floor_list.get_child_count() > 0:
        (floor_list.get_child(0) as Control).grab_focus()
    else:
        back_button.grab_focus()
    return true

func close_menu(triggering_action: StringName = &"") -> void:
    if not overlay.visible:
        return
    overlay.visible = false
    confirmation_panel.visible = false
    _pending_floor_id = 0
    if _input_ownership != null:
        _input_ownership.close_modal(MODAL_ID, triggering_action)

func refresh() -> bool:
    if not overlay.visible:
        return false
    close_menu()
    return open_menu()

func is_open() -> bool:
    return overlay.visible

func set_status_message(message: String) -> void:
    status_label.text = message

func _on_floor_pressed(floor_id: int) -> void:
    var raw: Variant = _entries_by_floor.get(floor_id, null)
    if not raw is Dictionary:
        return
    var entry := raw as Dictionary
    if bool(entry.get("requires_danger_confirmation", false)):
        _pending_floor_id = floor_id
        confirmation_label.text = _confirmation_text(entry)
        confirmation_panel.visible = true
        confirm_button.grab_focus()
        return
    floor_selected.emit(floor_id, false)

func _on_confirm_pressed() -> void:
    if _pending_floor_id <= 0 or not _entries_by_floor.has(_pending_floor_id):
        return
    var floor_id := _pending_floor_id
    _pending_floor_id = 0
    confirmation_panel.visible = false
    floor_selected.emit(floor_id, true)

func _on_cancel_confirmation_pressed() -> void:
    _pending_floor_id = 0
    confirmation_panel.visible = false
    status_label.text = tr("Travel cancelled. Select another floor or close the menu.")
    back_button.grab_focus()

func _on_back_pressed() -> void:
    close_menu()

func _clear_floor_buttons() -> void:
    for child: Node in floor_list.get_children():
        floor_list.remove_child(child)
        child.queue_free()

func _entry_label(entry: Dictionary) -> String:
    var floor_id := int(entry.get("floor_id", 0))
    var recommended := int(entry.get("recommended_level", 0))
    var state_text := tr("Cleared") if bool(entry.get("cleared", false)) else tr("Unlocked — Incomplete")
    var warning_parts: PackedStringArray = PackedStringArray()
    if bool(entry.get("elite_warning", false)):
        warning_parts.append(tr("Elites ×%d") % int(entry.get("elite_target", 0)))
    if bool(entry.get("boss_warning", false)):
        warning_parts.append(tr("Boss"))
    var warning_text := ""
    if not warning_parts.is_empty():
        warning_text = " | %s" % " + ".join(warning_parts)
    return tr("Floor %d | Recommended Lv.%d | %s | %s%s") % [
        floor_id,
        recommended,
        String(entry.get("danger_display", "")),
        state_text,
        warning_text,
    ]

func _confirmation_text(entry: Dictionary) -> String:
    var warning_parts: PackedStringArray = PackedStringArray()
    if bool(entry.get("elite_warning", false)):
        warning_parts.append(tr("elite encounter warning"))
    if bool(entry.get("boss_warning", false)):
        warning_parts.append(tr("boss encounter warning"))
    var extra := ""
    if not warning_parts.is_empty():
        extra = "\n%s" % ", ".join(warning_parts)
    return tr("Floor %d is %s. Entry remains allowed while under the recommendation. Continue?%s") % [
        int(entry.get("floor_id", 0)),
        String(entry.get("danger_display", "")),
        extra,
    ]
