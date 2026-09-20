class_name PauseCoordinator
extends Node

signal pause_changed(is_paused: bool, reason_id: StringName)
signal modal_back_requested(modal_id: StringName)

@export var overlay_path: NodePath
@export var resume_button_path: NodePath
@export var input_ownership_path: NodePath

var input_ownership: InputOwnership = null
var _reason_id: StringName = &""
var _overlay: Control = null
var _resume_button: Button = null

func _enter_tree() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
    input_ownership = get_node_or_null(input_ownership_path) as InputOwnership
    if input_ownership == null:
        input_ownership = InputOwnership.new()
        input_ownership.process_mode = Node.PROCESS_MODE_ALWAYS
        add_child(input_ownership)
    _overlay = get_node_or_null(overlay_path) as Control
    _resume_button = get_node_or_null(resume_button_path) as Button
    if _overlay != null:
        _overlay.visible = false
        _overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    if _resume_button != null:
        _resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
        _resume_button.button_down.connect(_on_resume_pressed)

func _input(event: InputEvent) -> void:
    if input_ownership == null:
        return
    if event.is_action_released(&"pause"):
        input_ownership.notify_action_released(&"pause")
    if event is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
            input_ownership.notify_action_released(&"basic_attack")

    if event.is_action_pressed(&"pause"):
        var current_modal: StringName = input_ownership.current_modal()
        if current_modal != &"" and current_modal != &"pause_menu":
            modal_back_requested.emit(current_modal)
            get_viewport().set_input_as_handled()
            return
        if get_tree().paused:
            resume(&"pause")
        else:
            request_pause(&"manual_pause")
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree():
        request_pause(&"focus_loss")

func request_pause(reason_id: StringName) -> void:
    if get_tree().paused:
        return
    _reason_id = reason_id
    input_ownership.open_modal(&"pause_menu")
    if _overlay != null:
        _overlay.visible = true
    get_tree().paused = true
    if _resume_button != null:
        _resume_button.grab_focus()
    pause_changed.emit(true, _reason_id)

func resume(triggering_action: StringName = &"") -> void:
    if not get_tree().paused:
        return
    input_ownership.close_modal(&"pause_menu", triggering_action)
    if _overlay != null:
        _overlay.visible = false
    get_tree().paused = false
    var previous_reason: StringName = _reason_id
    _reason_id = &""
    pause_changed.emit(false, previous_reason)

func pause_for_focus_loss() -> void:
    request_pause(&"focus_loss")

func get_pause_reason() -> StringName:
    return _reason_id

func _on_resume_pressed() -> void:
    resume(&"basic_attack")
