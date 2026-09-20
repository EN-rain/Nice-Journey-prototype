class_name PlayerCombatEffectController
extends Node

signal effect_played(action_id: StringName, effect_id: StringName, action_instance_id: int)

@export_node_path("EffectSpritePresenter") var presenter_path: NodePath = NodePath("../WeaponPivot/ActionEffect")
@export var action_effect_bindings: Array[ActionEffectBinding] = []

@onready var presenter: EffectSpritePresenter = get_node_or_null(presenter_path) as EffectSpritePresenter

var _action_state_machine: ActionStateMachine
var _last_effect_id: StringName = &""

func bind_action_state_machine(machine: ActionStateMachine) -> void:
    if _action_state_machine != null and _action_state_machine.action_commit_point_reached.is_connected(_on_action_commit_point_reached):
        _action_state_machine.action_commit_point_reached.disconnect(_on_action_commit_point_reached)
    _action_state_machine = machine
    _last_effect_id = &""
    if _action_state_machine != null:
        _action_state_machine.action_commit_point_reached.connect(_on_action_commit_point_reached)

func validate_setup() -> PackedStringArray:
    var errors := PackedStringArray()
    if presenter == null:
        errors.append("EffectSpritePresenter is unavailable")
    var seen: Dictionary = {}
    for index: int in range(action_effect_bindings.size()):
        var binding: ActionEffectBinding = action_effect_bindings[index]
        if binding == null:
            errors.append("action_effect_bindings[%d] is null" % index)
            continue
        for error: String in binding.validate_binding():
            errors.append("action_effect_bindings[%d]: %s" % [index, error])
        if seen.has(binding.action_id):
            errors.append("duplicate action effect binding: %s" % String(binding.action_id))
        else:
            seen[binding.action_id] = true
    return errors

func get_last_effect_id() -> StringName:
    return _last_effect_id

func _on_action_commit_point_reached(action: ActionDefinition, action_instance_id: int) -> void:
    if action == null or presenter == null:
        return
    var binding: ActionEffectBinding = _find_binding(action.action_id)
    if binding == null or binding.effect_profile == null:
        return
    if not presenter.configure_profile(binding.effect_profile):
        return
    _last_effect_id = binding.effect_profile.effect_id
    effect_played.emit(action.action_id, _last_effect_id, action_instance_id)

func _find_binding(action_id: StringName) -> ActionEffectBinding:
    for binding: ActionEffectBinding in action_effect_bindings:
        if binding != null and binding.action_id == action_id:
            return binding
    return null
