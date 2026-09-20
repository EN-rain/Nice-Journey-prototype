class_name DeathRetryOverlay
extends CanvasLayer

signal retry_requested()

@onready var panel: Control = $Panel
@onready var status_label: Label = $Panel/Menu/Layout/Status
@onready var retry_button: Button = $Panel/Menu/Layout/RetryButton

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    panel.process_mode = Node.PROCESS_MODE_ALWAYS
    retry_button.process_mode = Node.PROCESS_MODE_ALWAYS
    if not retry_button.pressed.is_connected(_on_retry_pressed):
        retry_button.pressed.connect(_on_retry_pressed)
    close_overlay()

func open_overlay(status_text: String = "") -> void:
    visible = true
    panel.visible = true
    status_label.text = status_text
    retry_button.disabled = false
    retry_button.grab_focus()

func close_overlay() -> void:
    visible = false
    panel.visible = false
    status_label.text = ""
    retry_button.disabled = false

func set_retry_pending(pending: bool) -> void:
    retry_button.disabled = pending
    if pending:
        status_label.text = "Restoring latest checkpoint..."

func set_status(text: String) -> void:
    status_label.text = text

func is_open() -> bool:
    return visible and panel.visible

func _on_retry_pressed() -> void:
    if retry_button.disabled:
        return
    retry_requested.emit()
