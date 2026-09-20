class_name EnemyRuntimePresentationBinder
extends Node

@export_node_path("EnemyVisualController") var visual_path: NodePath = NodePath("..")

@onready var visual: EnemyVisualController = get_node_or_null(visual_path) as EnemyVisualController

var bound_runtime: CombatEncounterRuntime = null
var bound_actor_id: StringName = &""
var bound_archetype_runtime: EnemyArchetypeRuntime = null


func bind_runtime(runtime: CombatEncounterRuntime, actor_id: StringName) -> bool:
    _resolve_visual()
    if runtime == null or visual == null or not StableId.is_valid(String(actor_id)):
        return false
    if runtime.get_combatant(actor_id) == null:
        return false
    unbind_runtime()
    bound_runtime = runtime
    bound_actor_id = actor_id
    bound_runtime.direct_contact_resolved.connect(_on_direct_contact_resolved)
    bound_runtime.enemy_defeated.connect(_on_enemy_defeated)
    return true


func bind_archetype_runtime(runtime: EnemyArchetypeRuntime) -> bool:
    _resolve_visual()
    if runtime == null or not runtime.is_configured() or visual == null or visual.profile == null:
        return false
    if visual.profile.archetype_id != runtime.definition.archetype_id:
        return false
    if bound_actor_id != &"" and bound_actor_id != runtime.actor_id:
        return false
    unbind_archetype_runtime()
    bound_archetype_runtime = runtime
    bound_archetype_runtime.action_phase_changed.connect(_on_action_phase_changed)
    bound_archetype_runtime.non_attack_tactic_requested.connect(_on_non_attack_tactic_requested)
    return true


func unbind_archetype_runtime() -> void:
    if bound_archetype_runtime != null:
        if bound_archetype_runtime.action_phase_changed.is_connected(_on_action_phase_changed):
            bound_archetype_runtime.action_phase_changed.disconnect(_on_action_phase_changed)
        if bound_archetype_runtime.non_attack_tactic_requested.is_connected(_on_non_attack_tactic_requested):
            bound_archetype_runtime.non_attack_tactic_requested.disconnect(_on_non_attack_tactic_requested)
    bound_archetype_runtime = null


func unbind_runtime() -> void:
    unbind_archetype_runtime()
    if bound_runtime != null:
        if bound_runtime.direct_contact_resolved.is_connected(_on_direct_contact_resolved):
            bound_runtime.direct_contact_resolved.disconnect(_on_direct_contact_resolved)
        if bound_runtime.enemy_defeated.is_connected(_on_enemy_defeated):
            bound_runtime.enemy_defeated.disconnect(_on_enemy_defeated)
    bound_runtime = null
    bound_actor_id = &""


func _exit_tree() -> void:
    unbind_runtime()


func _resolve_visual() -> void:
    if visual == null:
        visual = get_node_or_null(visual_path) as EnemyVisualController


func _on_direct_contact_resolved(
    _attacker_id: StringName,
    target_id: StringName,
    _action_instance_id: int,
    _hit_interval_index: int,
    result: Dictionary
) -> void:
    if target_id != bound_actor_id or visual == null or visual.profile == null:
        return
    if bool(result.get("target_defeated", false)):
        return
    var outcome := StringName(String(result.get("outcome", &"")))
    if outcome == DirectHitResolver.OUTCOME_BLOCKED and visual.profile.block_animation != &"":
        visual.play_semantic(visual.profile.block_animation)
        return
    if int(result.get("hp_damage", 0)) > 0:
        visual.play_semantic(visual.profile.hit_animation)


func _on_enemy_defeated(actor_id: StringName) -> void:
    if actor_id != bound_actor_id or visual == null or visual.profile == null:
        return
    visual.play_semantic(visual.profile.death_animation)


func _on_action_phase_changed(actor_id: StringName, _action_id: StringName, phase_id: StringName) -> void:
    if bound_archetype_runtime == null or actor_id != bound_archetype_runtime.actor_id or visual == null or visual.profile == null:
        return
    match phase_id:
        EnemyArchetypeRuntime.PHASE_WINDUP:
            visual.play_semantic(visual.profile.windup_animation)
        EnemyArchetypeRuntime.PHASE_ACTIVE:
            visual.play_semantic(visual.profile.release_animation)
        EnemyArchetypeRuntime.PHASE_IDLE:
            visual.play_semantic(visual.profile.idle_animation)
        EnemyArchetypeRuntime.PHASE_RECOVERY:
            pass


func _on_non_attack_tactic_requested(actor_id: StringName, tactic_id: StringName) -> void:
    if bound_archetype_runtime == null or actor_id != bound_archetype_runtime.actor_id or visual == null or visual.profile == null:
        return
    if tactic_id == &"tactic:hold_observe":
        visual.play_semantic(visual.profile.idle_animation)
        return
    visual.play_semantic(visual.profile.move_animation)
