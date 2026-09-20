class_name PlayerCombatantRuntimeBinding
extends RefCounted

signal live_player_defeated(actor_id: StringName)

var player: PlayerController = null
var encounter: CombatEncounterRuntime = null
var state: CombatantRuntimeState = null
var actor_id: StringName = &""

static func create_state(
    source_player: PlayerController,
    class_runtime: ClassCombatRuntime,
    tuning: PlayerCombatRuntimeTuning,
    new_actor_id: StringName = &"player:local"
) -> CombatantRuntimeState:
    if source_player == null or class_runtime == null or tuning == null:
        return null
    if not StableId.is_valid(String(new_actor_id)) or not tuning.validate_tuning().is_empty():
        return null
    if source_player.health == null or source_player.stamina == null:
        return null
    var result := CombatantRuntimeState.new()
    if not result.configure(
        new_actor_id,
        source_player.health.get_max_hp(),
        source_player.stamina.current_stamina,
        tuning.base_physical_defense,
        tuning.base_arcane_defense,
        tuning.poise_threshold,
        tuning.interruptible,
        class_runtime.supports_block(),
        class_runtime.supports_parry()
    ):
        return null
    result.current_hp = source_player.health.current_hp
    var status_restore := result.restore_status_states(class_runtime.get_status_safe_states())
    if not bool(status_restore.get("accepted", false)):
        return null
    return result

func bind(source_player: PlayerController, source_encounter: CombatEncounterRuntime, source_state: CombatantRuntimeState) -> bool:
    unbind()
    if source_player == null or source_encounter == null or source_state == null:
        return false
    if source_encounter.get_combatant(source_state.actor_id) != source_state:
        return false
    if source_player.health == null or source_player.stamina == null:
        return false
    player = source_player
    encounter = source_encounter
    state = source_state
    actor_id = source_state.actor_id
    if not player.health.health_changed.is_connected(_on_health_changed):
        player.health.health_changed.connect(_on_health_changed)
    if not player.stamina.stamina_changed.is_connected(_on_stamina_changed):
        player.stamina.stamina_changed.connect(_on_stamina_changed)
    if not encounter.direct_contact_resolved.is_connected(_on_direct_contact_resolved):
        encounter.direct_contact_resolved.connect(_on_direct_contact_resolved)
    if not encounter.status_damage_resolved.is_connected(_on_status_damage_resolved):
        encounter.status_damage_resolved.connect(_on_status_damage_resolved)
    if not encounter.player_defeated.is_connected(_on_player_defeated):
        encounter.player_defeated.connect(_on_player_defeated)
    _sync_state_from_player()
    return true

func unbind() -> void:
    if player != null and is_instance_valid(player):
        if player.health != null and player.health.health_changed.is_connected(_on_health_changed):
            player.health.health_changed.disconnect(_on_health_changed)
        if player.stamina != null and player.stamina.stamina_changed.is_connected(_on_stamina_changed):
            player.stamina.stamina_changed.disconnect(_on_stamina_changed)
    if encounter != null:
        if encounter.direct_contact_resolved.is_connected(_on_direct_contact_resolved):
            encounter.direct_contact_resolved.disconnect(_on_direct_contact_resolved)
        if encounter.status_damage_resolved.is_connected(_on_status_damage_resolved):
            encounter.status_damage_resolved.disconnect(_on_status_damage_resolved)
        if encounter.player_defeated.is_connected(_on_player_defeated):
            encounter.player_defeated.disconnect(_on_player_defeated)
    player = null
    encounter = null
    state = null
    actor_id = &""

func is_bound() -> bool:
    return player != null and encounter != null and state != null and actor_id != &""


func persist_status_safe_states(class_runtime: ClassCombatRuntime) -> bool:
    if not is_bound() or class_runtime == null:
        return false
    return class_runtime.store_status_safe_states(state.get_status_states())

func _sync_state_from_player() -> void:
    if not is_bound():
        return
    state.max_hp = player.health.get_max_hp()
    state.current_hp = player.health.current_hp
    state.current_stamina = player.stamina.current_stamina

func _on_health_changed(current: int, maximum: int) -> void:
    if state == null:
        return
    state.max_hp = maximum
    state.current_hp = current

func _on_stamina_changed(current: float, _maximum: float) -> void:
    if state == null:
        return
    state.current_stamina = current

func _on_direct_contact_resolved(
    _attacker_id: StringName,
    target_id: StringName,
    _action_instance_id: int,
    _hit_interval_index: int,
    result: Dictionary
) -> void:
    if not is_bound() or target_id != actor_id or not bool(result.get("accepted", false)):
        return
    if player.health.current_hp != state.current_hp:
        player.health.set_current_hp(state.current_hp)
    if not is_equal_approx(player.stamina.current_stamina, state.current_stamina):
        player.stamina.apply_combat_value(state.current_stamina, true)

func _on_status_damage_resolved(damaged_actor_id: StringName, _damage: int, remaining_hp: int) -> void:
    if not is_bound() or damaged_actor_id != actor_id or player.health == null:
        return
    # HealthComponent is the live UI/death owner; its signal mirrors the
    # committed value to all overlapping encounter states, not just this one.
    if player.health.current_hp != remaining_hp:
        player.health.set_current_hp(remaining_hp)


func _on_player_defeated(defeated_actor_id: StringName) -> void:
    if defeated_actor_id == actor_id:
        live_player_defeated.emit(actor_id)
