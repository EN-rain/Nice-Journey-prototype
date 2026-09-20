class_name CombatOutcomeEffectController
extends Node

signal effect_played(outcome_id: StringName, effect_id: StringName)

@export_node_path("EffectSpritePresenter") var presenter_path: NodePath
@export var outcome_effect_bindings: Array[CombatOutcomeEffectBinding] = []

@onready var presenter: EffectSpritePresenter = get_node_or_null(presenter_path) as EffectSpritePresenter

var bound_runtime: CombatEncounterRuntime = null
var bound_actor_id: StringName = &""
var _last_effect_id: StringName = &""


func validate_setup() -> PackedStringArray:
    var errors := PackedStringArray()
    if presenter == null:
        errors.append("EffectSpritePresenter is unavailable")
    var seen: Dictionary = {}
    for index: int in range(outcome_effect_bindings.size()):
        var binding: CombatOutcomeEffectBinding = outcome_effect_bindings[index]
        if binding == null:
            errors.append("outcome_effect_bindings[%d] is null" % index)
            continue
        for error: String in binding.validate_binding():
            errors.append("outcome_effect_bindings[%d]: %s" % [index, error])
        if seen.has(binding.outcome_id):
            errors.append("duplicate outcome effect binding: %s" % String(binding.outcome_id))
        else:
            seen[binding.outcome_id] = true
    return errors


func bind_runtime(runtime: CombatEncounterRuntime, actor_id: StringName) -> bool:
    if runtime == null or not StableId.is_valid(String(actor_id)) or runtime.get_combatant(actor_id) == null:
        return false
    if not validate_setup().is_empty():
        return false
    unbind_runtime()
    bound_runtime = runtime
    bound_actor_id = actor_id
    bound_runtime.direct_contact_resolved.connect(_on_direct_contact_resolved)
    return true


func unbind_runtime() -> void:
    if bound_runtime != null and bound_runtime.direct_contact_resolved.is_connected(_on_direct_contact_resolved):
        bound_runtime.direct_contact_resolved.disconnect(_on_direct_contact_resolved)
    bound_runtime = null
    bound_actor_id = &""


func get_last_effect_id() -> StringName:
    return _last_effect_id


func _exit_tree() -> void:
    unbind_runtime()


func _on_direct_contact_resolved(
    _attacker_id: StringName,
    target_id: StringName,
    _action_instance_id: int,
    _hit_interval_index: int,
    result: Dictionary
) -> void:
    if target_id != bound_actor_id or presenter == null:
        return
    var outcome_id := StringName(String(result.get("outcome", &"")))
    var binding := _find_binding(outcome_id)
    if binding == null or binding.effect_profile == null:
        return
    if not presenter.configure_profile(binding.effect_profile):
        return
    _last_effect_id = binding.effect_profile.effect_id
    effect_played.emit(outcome_id, _last_effect_id)


func _find_binding(outcome_id: StringName) -> CombatOutcomeEffectBinding:
    for binding: CombatOutcomeEffectBinding in outcome_effect_bindings:
        if binding != null and binding.outcome_id == outcome_id:
            return binding
    return null
