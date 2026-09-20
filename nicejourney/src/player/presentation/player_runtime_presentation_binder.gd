class_name PlayerRuntimePresentationBinder
extends Node

@export_node_path("PlayerBodyAnimator") var animator_path: NodePath = NodePath("../PlayerBodyAnimator")

@onready var animator: PlayerBodyAnimator = get_node_or_null(animator_path) as PlayerBodyAnimator

var bound_runtime: CombatEncounterRuntime = null
var bound_actor_id: StringName = &""


func bind_runtime(runtime: CombatEncounterRuntime, actor_id: StringName) -> bool:
    if runtime == null or animator == null or not StableId.is_valid(String(actor_id)):
        return false
    if runtime.get_combatant(actor_id) == null:
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


func _exit_tree() -> void:
    unbind_runtime()


func _on_direct_contact_resolved(
    _attacker_id: StringName,
    target_id: StringName,
    _action_instance_id: int,
    _hit_interval_index: int,
    result: Dictionary
) -> void:
    if target_id != bound_actor_id or animator == null:
        return
    if bool(result.get("target_defeated", false)):
        animator.play_death_reaction()
        return
    var outcome := StringName(String(result.get("outcome", &"")))
    if outcome == DirectHitResolver.OUTCOME_PARRIED:
        animator.play_parry_feedback()
        return
    if outcome == DirectHitResolver.OUTCOME_BLOCKED:
        animator.play_block_feedback()
        return
    if int(result.get("hp_damage", 0)) > 0:
        animator.play_hit_reaction()
