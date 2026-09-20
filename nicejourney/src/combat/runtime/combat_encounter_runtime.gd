class_name CombatEncounterRuntime
extends RefCounted

signal direct_contact_resolved(attacker_id: StringName, target_id: StringName, action_instance_id: int, hit_interval_index: int, result: Dictionary)
signal status_state_changed(actor_id: StringName, result: Dictionary)
signal status_damage_resolved(actor_id: StringName, damage: int, current_hp: int)
signal enemy_defeated(actor_id: StringName)
signal player_defeated(actor_id: StringName)

var encounter_id: StringName = &""
var active_combat: ActiveCombatRegistry = ActiveCombatRegistry.new()
var full_ai: FullAiSimulationLedger = FullAiSimulationLedger.new()
var reservations: AttackReservationLedger = AttackReservationLedger.new()
var attack_pressure: AttackPressureLedger = AttackPressureLedger.new()
var contacts: CombatContactLedger = CombatContactLedger.new()
var attack_admission: AttackParticipationAdmission = AttackParticipationAdmission.new()
# Opt-in PLAYTEST execution; ordinary / production-authority status paths remain unchanged.
var status_playtest_tuning: StatusPlaytestTuning = null

var _combatants: Dictionary = {}
var _player_ids: Dictionary = {}
var _enemy_lifecycles: Dictionary = {}
var _pressure_token_by_reservation_token: Dictionary = {}


func configure(
    new_encounter_id: StringName,
    shared_active_combat: ActiveCombatRegistry = null,
    shared_full_ai: FullAiSimulationLedger = null,
    shared_attack_pressure: AttackPressureLedger = null
) -> bool:
    if not StableId.is_valid(String(new_encounter_id)):
        return false
    encounter_id = new_encounter_id
    if shared_active_combat != null:
        active_combat = shared_active_combat
    if shared_full_ai != null:
        full_ai = shared_full_ai
    if shared_attack_pressure != null:
        attack_pressure = shared_attack_pressure
    return true


func register_player(state: CombatantRuntimeState) -> bool:
    if not _register_combatant(state, false):
        return false
    _player_ids[state.actor_id] = true
    return true


func register_enemy(state: CombatantRuntimeState) -> bool:
    if encounter_id == &"" or state == null or not _register_combatant(state, true):
        return false
    var lifecycle: EnemyRootLifecycle = EnemyRootLifecycle.new()
    if not lifecycle.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:activate"):
        _combatants.erase(state.actor_id)
        return false
    if not full_ai.try_admit(state.actor_id, encounter_id):
        _combatants.erase(state.actor_id)
        return false
    _enemy_lifecycles[state.actor_id] = lifecycle
    active_combat.acquire(encounter_id, ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER)
    return true


func get_combatant(actor_id: StringName) -> CombatantRuntimeState:
    return _combatants.get(actor_id) as CombatantRuntimeState


func get_registered_combatant_ids() -> Array[StringName]:
    # Read-only, deterministic IDs for opt-in combat telemetry and QA.
    var ids: Array[StringName] = []
    for raw_id: Variant in _combatants.keys():
        ids.append(StringName(String(raw_id)))
    ids.sort()
    return ids


func is_enemy_tactical_eligible(actor_id: StringName) -> bool:
    var lifecycle := _enemy_lifecycles.get(actor_id) as EnemyRootLifecycle
    return lifecycle != null and lifecycle.is_tactical_eligible()


func get_enemy_lifecycle_state(actor_id: StringName) -> StringName:
    var lifecycle := _enemy_lifecycles.get(actor_id) as EnemyRootLifecycle
    return &"" if lifecycle == null else lifecycle.get_state_name()


func resolve_direct_contact(
    attacker_id: StringName,
    target_id: StringName,
    action_instance_id: int,
    hit_interval_index: int,
    attack_payload: Dictionary,
    evade_window_active: bool,
    defense_mode: StringName,
    facing_covered: bool
) -> Dictionary:
    if not _combatants.has(attacker_id) or not _combatants.has(target_id):
        return _contact_rejected(&"unknown_combatant")
    var attacker: CombatantRuntimeState = _combatants[attacker_id] as CombatantRuntimeState
    var target: CombatantRuntimeState = _combatants[target_id] as CombatantRuntimeState
    if attacker == null or target == null or attacker.is_defeated() or target.is_defeated():
        return _contact_rejected(&"inactive_combatant")

    var result: Dictionary = DirectHitResolver.resolve(
        attack_payload,
        target.make_defender_snapshot(evade_window_active, defense_mode, facing_covered)
    )
    if not bool(result.get("accepted", false)):
        return result
    if not contacts.try_admit_contact(action_instance_id, target_id, hit_interval_index):
        return _contact_rejected(&"duplicate_contact")
    if not target.apply_direct_hit_result(result):
        return _contact_rejected(&"state_apply_failed")
    result["target_id"] = target_id
    result["target_hp_after"] = target.current_hp
    result["target_defeated"] = target.is_defeated()
    direct_contact_resolved.emit(attacker_id, target_id, action_instance_id, hit_interval_index, result.duplicate(true))
    if target.is_defeated():
        if _player_ids.has(target_id):
            _resolve_player_defeat(target_id)
        else:
            _resolve_enemy_defeat(target_id)
    return result


func apply_poise_to_target(target_id: StringName, poise_damage: float) -> Dictionary:
    var target: CombatantRuntimeState = get_combatant(target_id)
    if target == null:
        return {"accepted": false, "reason_id": &"unknown_combatant"}
    return target.apply_poise_damage(poise_damage)


func apply_status_to_target(target_id: StringName, application: Variant) -> Dictionary:
    var target: CombatantRuntimeState = get_combatant(target_id)
    if target == null:
        return {
            "accepted": false,
            "reason_id": &"unknown_combatant",
            "outcome": PrototypeStatusResolver.OUTCOME_REJECTED,
            "states": [],
        }
    var result: Dictionary = target.apply_status(application)
    if bool(result.get("accepted", false)):
        status_state_changed.emit(target_id, result.duplicate(true))
    return result.duplicate(true)


func apply_production_status_to_target(target_id: StringName, application: Variant) -> Dictionary:
    var target: CombatantRuntimeState = get_combatant(target_id)
    if target == null:
        return {
            "accepted": false,
            "reason_id": &"unknown_combatant",
            "outcome": PrototypeStatusResolver.OUTCOME_REJECTED,
            "states": [],
            "production_missing_fields": PackedStringArray(),
            "production_known_semantics": {},
        }
    var result := target.apply_production_status(application)
    if bool(result.get("accepted", false)):
        status_state_changed.emit(target_id, result.duplicate(true))
    return result.duplicate(true)


func advance_status_ticks(raw_elapsed_ticks: Variant = 1) -> Dictionary:
    if typeof(raw_elapsed_ticks) != TYPE_INT or int(raw_elapsed_ticks) < 0:
        return {
            "accepted": false,
            "reason_id": PrototypeStatusResolver.REASON_INVALID_ELAPSED_TICKS,
            "states_by_actor": {},
        }
    var elapsed_ticks := int(raw_elapsed_ticks)
    var actor_ids: Array = _combatants.keys()
    actor_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    var states_by_actor: Dictionary = {}
    var burn_damage_by_actor: Dictionary = {}
    for raw_actor_id: Variant in actor_ids:
        var actor_id := StringName(String(raw_actor_id))
        var state := _combatants.get(raw_actor_id) as CombatantRuntimeState
        if state == null:
            continue
        var before := state.get_status_states()
        var result := state.advance_status_duration(elapsed_ticks)
        if not bool(result.get("accepted", false)):
            return {
                "accepted": false,
                "reason_id": StringName(result.get("reason_id", &"")),
                "states_by_actor": states_by_actor.duplicate(true),
            }
        var after := state.get_status_states()
        states_by_actor[actor_id] = after
        if status_playtest_tuning != null and status_playtest_tuning.validate_tuning().is_empty() and not state.is_defeated():
            var burn_damage := 0
            for raw_status: Variant in before:
                if raw_status is Dictionary:
                    burn_damage += status_playtest_tuning.burn_damage_for_advance(raw_status as Dictionary, elapsed_ticks)
            if burn_damage > 0 and state.apply_direct_hit_result({"accepted": true, "hp_damage": burn_damage}):
                burn_damage_by_actor[actor_id] = burn_damage
                # Player mirrors must receive fatal Burn before the defeat event.
                status_damage_resolved.emit(actor_id, burn_damage, state.current_hp)
                if state.is_defeated():
                    if _player_ids.has(actor_id):
                        _resolve_player_defeat(actor_id)
                    else:
                        _resolve_enemy_defeat(actor_id)
        if after != before:
            status_state_changed.emit(actor_id, result.duplicate(true))
    return {
        "accepted": true,
        "reason_id": &"",
        "states_by_actor": states_by_actor.duplicate(true),
        "playtest_burn_damage_by_actor": burn_damage_by_actor.duplicate(),
    }


func get_status_states(actor_id: StringName) -> Array:
    var state := get_combatant(actor_id)
    return [] if state == null else state.get_status_states()


func get_status_execution_requests(actor_id: StringName) -> Dictionary:
    var state := get_combatant(actor_id)
    if state == null:
        return {"accepted": false, "reason_id": &"unknown_combatant", "requests": []}
    return state.get_status_execution_requests().duplicate(true)


func get_production_status_execution_requests(actor_id: StringName) -> Dictionary:
    var state := get_combatant(actor_id)
    if state == null:
        return {"accepted": false, "reason_id": &"unknown_combatant", "requests": [], "unresolved_statuses": []}
    return state.get_production_status_execution_requests().duplicate(true)


func reserve_enemy_attack(actor_id: StringName, target_id: StringName, action_instance_id: int) -> int:
    var lifecycle: EnemyRootLifecycle = _enemy_lifecycles.get(actor_id) as EnemyRootLifecycle
    var actor := _combatants.get(actor_id) as CombatantRuntimeState
    var target := _combatants.get(target_id) as CombatantRuntimeState
    if lifecycle == null or actor == null or target == null or actor.is_defeated() or target.is_defeated():
        return 0
    var pressure_token := attack_pressure.try_admit(actor_id, target_id, encounter_id, action_instance_id)
    if pressure_token <= 0:
        return 0
    var reservation_token := attack_admission.try_admit(
        lifecycle,
        full_ai,
        reservations,
        actor_id,
        target_id,
        encounter_id,
        action_instance_id
    )
    if reservation_token <= 0:
        attack_pressure.release(pressure_token, AttackReservationLedger.RELEASE_CANCELLATION)
        return 0
    _pressure_token_by_reservation_token[reservation_token] = pressure_token
    return reservation_token


func release_enemy_attack(token: int, reason_id: StringName) -> bool:
    var pressure_token := int(_pressure_token_by_reservation_token.get(token, 0))
    if pressure_token <= 0 or not reservations.release(token, reason_id):
        return false
    _pressure_token_by_reservation_token.erase(token)
    return attack_pressure.release(pressure_token, reason_id)


func has_enemy_attack_ownership(
    actor_id: StringName,
    target_id: StringName,
    action_instance_id: int,
    reservation_token: int
) -> bool:
    if reservation_token <= 0 or action_instance_id <= 0:
        return false
    var pressure_token := int(_pressure_token_by_reservation_token.get(reservation_token, 0))
    if pressure_token <= 0:
        return false
    return reservations.matches_reservation(reservation_token, actor_id, target_id, encounter_id, action_instance_id) \
        and attack_pressure.matches_commitment(pressure_token, actor_id, target_id, encounter_id, action_instance_id)


func end_encounter() -> void:
    reservations.release_encounter(encounter_id, AttackReservationLedger.RELEASE_ENCOUNTER_EXIT)
    attack_pressure.release_encounter(encounter_id, AttackReservationLedger.RELEASE_ENCOUNTER_EXIT)
    _pressure_token_by_reservation_token.clear()
    var enemy_ids: Array = _enemy_lifecycles.keys()
    for enemy_variant: Variant in enemy_ids:
        var enemy_id: StringName = StringName(enemy_variant)
        full_ai.release(enemy_id)
        var lifecycle: EnemyRootLifecycle = _enemy_lifecycles[enemy_id] as EnemyRootLifecycle
        if lifecycle != null and lifecycle.get_state() != EnemyRootLifecycle.State.RESOLVED:
            lifecycle.request_transition(EnemyRootLifecycle.State.RESOLVED, &"encounter:exit")
    active_combat.release_source(encounter_id)


func get_active_enemy_count() -> int:
    var count: int = 0
    for lifecycle_variant: Variant in _enemy_lifecycles.values():
        var lifecycle: EnemyRootLifecycle = lifecycle_variant as EnemyRootLifecycle
        if lifecycle != null and lifecycle.get_state() == EnemyRootLifecycle.State.ACTIVE:
            count += 1
    return count


func get_debug_snapshot() -> Dictionary:
    var actor_ids: Array = _combatants.keys()
    actor_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
    var combatant_snapshots: Array[Dictionary] = []
    for actor_variant: Variant in actor_ids:
        var actor_id: StringName = StringName(actor_variant)
        var state: CombatantRuntimeState = _combatants[actor_id] as CombatantRuntimeState
        if state != null:
            combatant_snapshots.append(state.get_debug_snapshot())
    return {
        "encounter_id": encounter_id,
        "active_enemy_count": get_active_enemy_count(),
        "active_combat": active_combat.get_debug_snapshot(),
        "full_ai": full_ai.get_debug_snapshot(),
        "reservations": reservations.get_debug_snapshot(),
        "attack_pressure": attack_pressure.get_debug_snapshot(),
        "combatants": combatant_snapshots,
    }


func _register_combatant(state: CombatantRuntimeState, is_enemy: bool) -> bool:
    if state == null or state.actor_id == &"" or state.max_hp <= 0 or state.is_defeated():
        return false
    if _combatants.has(state.actor_id):
        return false
    if is_enemy and _enemy_lifecycles.has(state.actor_id):
        return false
    _combatants[state.actor_id] = state
    return true


func _resolve_player_defeat(actor_id: StringName) -> void:
    if not _player_ids.has(actor_id):
        return
    reservations.release_target(actor_id, AttackReservationLedger.RELEASE_TARGET_INVALIDATION)
    attack_pressure.release_target(actor_id, AttackReservationLedger.RELEASE_TARGET_INVALIDATION)
    _prune_pressure_links()
    player_defeated.emit(actor_id)


func _resolve_enemy_defeat(actor_id: StringName) -> void:
    var lifecycle: EnemyRootLifecycle = _enemy_lifecycles.get(actor_id) as EnemyRootLifecycle
    if lifecycle == null or lifecycle.get_state() != EnemyRootLifecycle.State.ACTIVE:
        return
    lifecycle.request_transition(EnemyRootLifecycle.State.DEFEATED, &"combat:defeated")
    enemy_defeated.emit(actor_id)
    full_ai.release(actor_id)
    reservations.release_actor(actor_id, AttackReservationLedger.RELEASE_DEATH)
    reservations.release_target(actor_id, AttackReservationLedger.RELEASE_TARGET_INVALIDATION)
    attack_pressure.release_actor(actor_id, AttackReservationLedger.RELEASE_DEATH)
    attack_pressure.release_target(actor_id, AttackReservationLedger.RELEASE_TARGET_INVALIDATION)
    _prune_pressure_links()
    if get_active_enemy_count() == 0:
        active_combat.release(encounter_id, ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER)


func _prune_pressure_links() -> void:
    for raw_token: Variant in _pressure_token_by_reservation_token.keys():
        var reservation_token := int(raw_token)
        if not reservations.has_token(reservation_token):
            _pressure_token_by_reservation_token.erase(raw_token)


func _contact_rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "outcome": DirectHitResolver.OUTCOME_REJECTED,
        "hp_damage": 0,
        "target_defeated": false,
    }
