class_name InputOwnership
extends Node

signal modal_opened(modal_id: StringName)
signal modal_closed(modal_id: StringName)

var _modal_stack: Array[StringName] = []
var _suppressed_until_release: Dictionary = {}

func _enter_tree() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
    if _suppressed_until_release.is_empty():
        return
    var suppressed_actions: Array = _suppressed_until_release.keys()
    for action_variant: Variant in suppressed_actions:
        var action_id: StringName = StringName(action_variant)
        if event.is_action_released(action_id):
            notify_action_released(action_id)

func open_modal(modal_id: StringName) -> void:
    if modal_id == &"":
        push_error("InputOwnership: modal_id must not be empty")
        return
    if _modal_stack.has(modal_id):
        return
    _modal_stack.append(modal_id)
    modal_opened.emit(modal_id)

func close_modal(modal_id: StringName, triggering_action: StringName = &"") -> void:
    var index: int = _modal_stack.rfind(modal_id)
    if index < 0:
        return
    _modal_stack.remove_at(index)
    if triggering_action != &"":
        _suppressed_until_release[triggering_action] = true
    modal_closed.emit(modal_id)

func is_modal_open() -> bool:
    return not _modal_stack.is_empty()

func current_modal() -> StringName:
    if _modal_stack.is_empty():
        return &""
    return _modal_stack[_modal_stack.size() - 1]

func can_route_gameplay_action(action_id: StringName) -> bool:
    if is_modal_open():
        return false
    return not _suppressed_until_release.has(action_id)

func notify_action_released(action_id: StringName) -> void:
    _suppressed_until_release.erase(action_id)

func clear_transient_suppression() -> void:
    _suppressed_until_release.clear()

func reset() -> void:
    _modal_stack.clear()
    _suppressed_until_release.clear()
