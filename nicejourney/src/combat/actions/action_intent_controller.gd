class_name ActionIntentController
extends Node

@export var input_ownership_path: NodePath
@export var action_state_machine_path: NodePath

var input_ownership: InputOwnership = null
var action_state_machine: ActionStateMachine = null
var _last_input_rejection: StringName = &""

func _ready() -> void:
    input_ownership = get_node_or_null(input_ownership_path) as InputOwnership
    action_state_machine = get_node_or_null(action_state_machine_path) as ActionStateMachine
    if input_ownership == null or action_state_machine == null:
        push_error("ActionIntentController requires InputOwnership and ActionStateMachine")
        return
    input_ownership.modal_opened.connect(_on_modal_boundary)
    input_ownership.modal_closed.connect(_on_modal_boundary)

func request_action(input_action_id: StringName, action: ActionDefinition, aim_sample: Vector2 = Vector2.ZERO) -> bool:
    if input_action_id == &"" or action == null or input_ownership == null or action_state_machine == null:
        return false
    if not input_ownership.can_route_gameplay_action(input_action_id):
        _last_input_rejection = &"input_owned_or_suppressed"
        return false
    _last_input_rejection = &""
    return action_state_machine.request_action(action, aim_sample)

func get_debug_snapshot(cooldown_action_id: StringName = &"") -> Dictionary:
    if action_state_machine == null:
        return {}
    var observed_cooldown_id: StringName = cooldown_action_id
    if observed_cooldown_id == &"":
        observed_cooldown_id = action_state_machine.get_current_action_id()
    return {
        "action_id": action_state_machine.get_current_action_id(),
        "action_instance_id": action_state_machine.get_current_instance_id(),
        "phase": int(action_state_machine.get_phase()),
        "phase_name": _phase_name(action_state_machine.get_phase()),
        "phase_elapsed_ticks": action_state_machine.get_phase_elapsed_ticks(),
        "phase_duration_ticks": action_state_machine.get_phase_duration_ticks(),
        "buffered_action_id": action_state_machine.get_buffered_action_id(),
        "buffer_ticks_remaining": action_state_machine.get_buffer_ticks_remaining(),
        "cooldown_action_id": observed_cooldown_id,
        "cooldown_ticks": action_state_machine.get_cooldown_ticks(observed_cooldown_id),
        "allowed_cancel_action_ids": action_state_machine.get_allowed_cancel_action_ids(),
        "aim_locked": action_state_machine.has_locked_aim_sample(),
        "locked_aim_sample": action_state_machine.get_locked_aim_sample(),
        "current_aim_sample": action_state_machine.get_current_aim_sample(),
        "current_modal": &"" if input_ownership == null else input_ownership.current_modal(),
        "last_input_rejection": _last_input_rejection,
    }

func _on_modal_boundary(_modal_id: StringName) -> void:
    if action_state_machine != null:
        action_state_machine.clear_buffer()

func _phase_name(phase: ActionStateMachine.Phase) -> StringName:
    match phase:
        ActionStateMachine.Phase.STARTUP:
            return &"STARTUP"
        ActionStateMachine.Phase.COMMIT:
            return &"COMMIT"
        ActionStateMachine.Phase.ACTIVE:
            return &"ACTIVE"
        ActionStateMachine.Phase.RECOVERY:
            return &"RECOVERY"
        _:
            return &"IDLE"
