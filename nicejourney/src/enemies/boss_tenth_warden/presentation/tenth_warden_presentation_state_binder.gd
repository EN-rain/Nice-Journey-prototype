class_name TenthWardenPresentationStateBinder
extends Node

signal weak_point_presentation_requested(exposed: bool)

@export_node_path("TenthWardenVisualController") var visual_path: NodePath = NodePath("..")

@onready var visual: TenthWardenVisualController = get_node_or_null(visual_path) as TenthWardenVisualController

var bound_state: TenthWardenEncounterState = null
var bound_combat_runtime: CombatEncounterRuntime = null
var bound_actor_id: StringName = &""

func bind_state(state: TenthWardenEncounterState) -> bool:
    if state == null or visual == null:
        return false
    unbind_state()
    bound_state = state
    bound_state.move_committed.connect(_on_move_committed)
    bound_state.recovery_finished.connect(_on_recovery_finished)
    bound_state.phase_transition_committed.connect(_on_phase_transition_committed)
    bound_state.weak_point_exposure_changed.connect(_on_weak_point_exposure_changed)
    return true

func bind_combat_runtime(runtime: CombatEncounterRuntime, actor_id: StringName) -> bool:
    if runtime == null or visual == null or not StableId.is_valid(String(actor_id)):
        return false
    if runtime.get_combatant(actor_id) == null:
        return false
    unbind_combat_runtime()
    bound_combat_runtime = runtime
    bound_actor_id = actor_id
    bound_combat_runtime.direct_contact_resolved.connect(_on_direct_contact_resolved)
    bound_combat_runtime.enemy_defeated.connect(_on_enemy_defeated)
    return true

func unbind_state() -> void:
    if bound_state == null:
        return
    if bound_state.move_committed.is_connected(_on_move_committed):
        bound_state.move_committed.disconnect(_on_move_committed)
    if bound_state.recovery_finished.is_connected(_on_recovery_finished):
        bound_state.recovery_finished.disconnect(_on_recovery_finished)
    if bound_state.phase_transition_committed.is_connected(_on_phase_transition_committed):
        bound_state.phase_transition_committed.disconnect(_on_phase_transition_committed)
    if bound_state.weak_point_exposure_changed.is_connected(_on_weak_point_exposure_changed):
        bound_state.weak_point_exposure_changed.disconnect(_on_weak_point_exposure_changed)
    bound_state = null

func unbind_combat_runtime() -> void:
    if bound_combat_runtime != null:
        if bound_combat_runtime.direct_contact_resolved.is_connected(_on_direct_contact_resolved):
            bound_combat_runtime.direct_contact_resolved.disconnect(_on_direct_contact_resolved)
        if bound_combat_runtime.enemy_defeated.is_connected(_on_enemy_defeated):
            bound_combat_runtime.enemy_defeated.disconnect(_on_enemy_defeated)
    bound_combat_runtime = null
    bound_actor_id = &""

func _exit_tree() -> void:
    unbind_state()
    unbind_combat_runtime()

func _on_move_committed(move_id: StringName) -> void:
    visual.play_move(move_id)

func _on_recovery_finished(_move_id: StringName) -> void:
    if bound_state == null or bound_state.transition_pending:
        return
    visual.play_semantic(visual.profile.idle_animation)

func _on_phase_transition_committed() -> void:
    if visual.profile != null:
        visual.play_semantic(visual.profile.phase_two_animation)

func _on_weak_point_exposure_changed(exposed: bool) -> void:
    if visual != null:
        visual.set_weak_point_exposed(exposed)
    weak_point_presentation_requested.emit(exposed)

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
    if int(result.get("hp_damage", 0)) > 0:
        visual.play_semantic(visual.profile.hit_animation)

func _on_enemy_defeated(actor_id: StringName) -> void:
    if actor_id != bound_actor_id or visual == null or visual.profile == null:
        return
    visual.play_semantic(visual.profile.death_animation)
    unbind_state()
