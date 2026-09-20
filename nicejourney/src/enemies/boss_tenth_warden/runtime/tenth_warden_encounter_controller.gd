class_name TenthWardenEncounterController
extends RefCounted

signal active_delivery_window_opened(context: Dictionary)
signal terminal_outcome_ready(outcome_id: StringName)

const REASON_NOT_CONFIGURED: StringName = &"not_configured"
const REASON_NOT_ACTIVE: StringName = &"not_active"
const REASON_INVALID_CONTACT_FACTS: StringName = &"invalid_contact_facts"
const REASON_CONTACT_NOT_CONFIRMED: StringName = &"contact_not_confirmed"
const REASON_CONTACT_IDENTITY_MISMATCH: StringName = &"contact_identity_mismatch"
const REASON_GEOMETRY_MISMATCH: StringName = &"geometry_mismatch"
const REASON_HIT_INTERVAL_OUT_OF_RANGE: StringName = &"hit_interval_out_of_range"
const REASON_ATTACK_AUTHORING_UNAVAILABLE: StringName = &"attack_authoring_unavailable"

var runtime: TenthWardenCombatRuntime = null
var authoring: TenthWardenProductionAuthoring = null
var action_machine: ActionStateMachine = null
var stamina_pool: ResourcePool = null

var _phase_one_cursor: int = 0
var _phase_two_cursor: int = 0
var _positioning_condition_met: bool = false
var _runtime_begin_accepted: bool = false
var _transition_action_active: bool = false
var _terminal_outcome_emitted: StringName = TenthWardenEncounterState.OUTCOME_ONGOING


func configure(
    source_runtime: TenthWardenCombatRuntime,
    source_authoring: TenthWardenProductionAuthoring
) -> bool:
    if source_runtime == null or not source_runtime.is_configured():
        return false
    if source_authoring == null or not source_authoring.validate_authoring().is_empty():
        return false
    var boss: CombatantRuntimeState = source_runtime.encounter.get_combatant(source_runtime.boss_id)
    if not _boss_matches_authoring(boss, source_authoring):
        return false

    runtime = source_runtime
    authoring = source_authoring
    action_machine = ActionStateMachine.new()
    stamina_pool = ResourcePool.new()
    if not stamina_pool.define_resource(
        TenthWardenProductionAuthoring.STAMINA_RESOURCE_ID,
        authoring.stamina,
        boss.current_stamina
    ):
        _clear()
        return false
    action_machine.set_resource_pool(stamina_pool)
    action_machine.action_started.connect(_on_action_started)
    action_machine.phase_changed.connect(_on_phase_changed)
    action_machine.action_commit_point_reached.connect(_on_action_commit_point_reached)
    action_machine.action_finished.connect(_on_action_finished)
    action_machine.action_interrupted.connect(_on_action_interrupted)

    _phase_one_cursor = 0
    _phase_two_cursor = 0
    _positioning_condition_met = false
    _runtime_begin_accepted = false
    _transition_action_active = false
    _terminal_outcome_emitted = TenthWardenEncounterState.OUTCOME_ONGOING
    return true


func advance_fixed_tick(positioning_condition_met: bool = false) -> bool:
    if not is_configured():
        return false
    _positioning_condition_met = positioning_condition_met
    if _commit_terminal_if_ready():
        return true

    _recover_boss_stamina()
    _sync_stamina_pool_from_boss()
    action_machine.advance_fixed_tick()
    _sync_boss_stamina_from_pool()

    if _commit_terminal_if_ready():
        return true
    if action_machine.is_busy():
        return true
    if runtime.state.active_move_id != &"":
        return false

    if runtime.state.transition_action_requested:
        return _request_phase_transition_action()
    return _request_next_authored_move()


func resolve_authored_contact(
    contact_facts: Variant,
    evade_window_active: bool,
    defense_mode: StringName,
    facing_covered: bool
) -> Dictionary:
    if not is_configured():
        return _rejected(REASON_NOT_CONFIGURED)
    if action_machine.get_phase() != ActionStateMachine.Phase.ACTIVE:
        return _rejected(REASON_NOT_ACTIVE)
    if not contact_facts is Dictionary:
        return _rejected(REASON_INVALID_CONTACT_FACTS)

    var facts := contact_facts as Dictionary
    for key: String in [
        "actor_id",
        "target_id",
        "action_id",
        "action_instance_id",
        "hit_interval_index",
        "geometry_id",
        "contact_confirmed",
        "critical_triggered",
        "weak_point_triggered",
    ]:
        if not facts.has(key):
            return _rejected(REASON_INVALID_CONTACT_FACTS)
    if not facts["contact_confirmed"] is bool         or not facts["critical_triggered"] is bool         or not facts["weak_point_triggered"] is bool:
        return _rejected(REASON_INVALID_CONTACT_FACTS)
    if not bool(facts["contact_confirmed"]):
        return _rejected(REASON_CONTACT_NOT_CONFIRMED)
    if typeof(facts["action_instance_id"]) != TYPE_INT or typeof(facts["hit_interval_index"]) != TYPE_INT:
        return _rejected(REASON_INVALID_CONTACT_FACTS)

    var action_instance_id := int(facts["action_instance_id"])
    var hit_interval_index := int(facts["hit_interval_index"])
    var move_id := action_machine.get_current_action_id()
    if StringName(String(facts["actor_id"])) != runtime.boss_id         or StringName(String(facts["target_id"])) != runtime.player_id         or StringName(String(facts["action_id"])) != move_id         or action_instance_id != action_machine.get_current_instance_id():
        return _rejected(REASON_CONTACT_IDENTITY_MISMATCH)

    var attack: EnemySignatureAttackAuthoring = authoring.attack_for_move(move_id)
    if attack == null or attack.geometry == null or attack.payload == null:
        return _rejected(REASON_ATTACK_AUTHORING_UNAVAILABLE)
    if StringName(String(facts["geometry_id"])) != attack.geometry.geometry_id:
        return _rejected(REASON_GEOMETRY_MISMATCH)
    if hit_interval_index < 0 or hit_interval_index >= attack.geometry.hit_interval_count:
        return _rejected(REASON_HIT_INTERVAL_OUT_OF_RANGE)

    var payload := attack.payload.make_payload(
        bool(facts["critical_triggered"]),
        bool(facts["weak_point_triggered"])
    )
    if payload.is_empty():
        return _rejected(REASON_ATTACK_AUTHORING_UNAVAILABLE)
    return runtime.resolve_boss_contact(
        action_instance_id,
        hit_interval_index,
        payload,
        evade_window_active,
        defense_mode,
        facing_covered
    )


func is_configured() -> bool:
    return runtime != null         and authoring != null         and action_machine != null         and stamina_pool != null         and runtime.is_configured()


func get_debug_snapshot() -> Dictionary:
    return {
        "configured": is_configured(),
        "phase": runtime.state.phase if runtime != null and runtime.state != null else 0,
        "action_phase": action_machine.get_phase() if action_machine != null else ActionStateMachine.Phase.IDLE,
        "action_id": action_machine.get_current_action_id() if action_machine != null else &"",
        "action_instance_id": action_machine.get_current_instance_id() if action_machine != null else 0,
        "phase_one_cursor": _phase_one_cursor,
        "phase_two_cursor": _phase_two_cursor,
        "terminal_outcome_emitted": _terminal_outcome_emitted,
        "boss_runtime": runtime.get_debug_snapshot() if runtime != null else {},
    }


func reset() -> void:
    if runtime != null and runtime.active_reservation_token != 0:
        runtime.cancel_active_move(AttackReservationLedger.RELEASE_ENCOUNTER_EXIT)
    if action_machine != null and action_machine.is_busy():
        action_machine.force_interrupt(&"encounter_reset")
    _clear()


func _request_next_authored_move() -> bool:
    var order: Array[StringName] = authoring.selection_order_for_phase(runtime.state.phase)
    if order.is_empty():
        return false
    var cursor := _phase_one_cursor if runtime.state.phase == TenthWardenEncounterState.PHASE_ONE else _phase_two_cursor
    for offset: int in range(order.size()):
        var index := (cursor + offset) % order.size()
        var move_id: StringName = order[index]
        if move_id == TenthWardenEncounterState.MOVE_PUNISHING_STEP and not _positioning_condition_met:
            continue
        if not runtime.state.can_begin_move(move_id, _positioning_condition_met):
            continue
        if action_machine.get_cooldown_ticks(move_id) > 0:
            continue
        var action: ActionDefinition = authoring.action_for_move(move_id, runtime.state.phase)
        if action == null:
            continue
        if not _can_pay_action_cost(action):
            continue

        _runtime_begin_accepted = false
        _transition_action_active = false
        if not action_machine.request_action(action):
            continue
        if not _runtime_begin_accepted:
            action_machine.force_interrupt(&"boss_runtime_begin_rejected")
            return true

        if runtime.state.phase == TenthWardenEncounterState.PHASE_ONE:
            _phase_one_cursor = (index + 1) % order.size()
        else:
            _phase_two_cursor = (index + 1) % order.size()
        return true
    return true


func _request_phase_transition_action() -> bool:
    if authoring.phase_transition_action == null:
        return false
    if action_machine.get_cooldown_ticks(authoring.phase_transition_action.action_id) > 0:
        return false
    if not _can_pay_action_cost(authoring.phase_transition_action):
        return false
    _runtime_begin_accepted = false
    _transition_action_active = true
    if not action_machine.request_action(authoring.phase_transition_action):
        _transition_action_active = false
        return false
    return true


func _on_action_started(action_id: StringName, action_instance_id: int) -> void:
    if action_id == TenthWardenEncounterState.ACTION_PHASE_TRANSITION:
        _runtime_begin_accepted = true
        return
    _runtime_begin_accepted = runtime.begin_move(
        action_id,
        action_instance_id,
        _positioning_condition_met
    )


func _on_phase_changed(action_id: StringName, action_instance_id: int, phase: int) -> void:
    if action_id == TenthWardenEncounterState.ACTION_PHASE_TRANSITION:
        return
    if phase == ActionStateMachine.Phase.ACTIVE:
        var attack: EnemySignatureAttackAuthoring = authoring.attack_for_move(action_id)
        if attack == null or attack.geometry == null:
            return
        active_delivery_window_opened.emit({
            "actor_id": runtime.boss_id,
            "target_id": runtime.player_id,
            "action_id": action_id,
            "action_instance_id": action_instance_id,
            "geometry_id": attack.geometry.geometry_id,
            "query_shape": attack.geometry.query_shape,
            "max_reach_px": attack.geometry.max_reach_px,
            "collision_mask": attack.geometry.collision_mask,
            "hit_interval_count": attack.geometry.hit_interval_count,
        })
    elif phase == ActionStateMachine.Phase.RECOVERY:
        if runtime.state.recovery_active:
            return
        var heavy := runtime.state.phase == TenthWardenEncounterState.PHASE_TWO             and authoring.is_phase_two_heavy_move(action_id)
        runtime.begin_recovery(heavy)


func _on_action_commit_point_reached(_action: ActionDefinition, _action_instance_id: int) -> void:
    _sync_boss_stamina_from_pool()


func _on_action_finished(action_id: StringName, _action_instance_id: int) -> void:
    if action_id == TenthWardenEncounterState.ACTION_PHASE_TRANSITION:
        _transition_action_active = false
        runtime.commit_phase_transition()
        return
    if runtime.state.active_move_id == action_id:
        if not runtime.state.recovery_active:
            var heavy := runtime.state.phase == TenthWardenEncounterState.PHASE_TWO                 and authoring.is_phase_two_heavy_move(action_id)
            runtime.begin_recovery(heavy)
        runtime.finish_recovery()
    _runtime_begin_accepted = false


func _on_action_interrupted(action_id: StringName, _action_instance_id: int, _reason_id: StringName) -> void:
    if action_id == TenthWardenEncounterState.ACTION_PHASE_TRANSITION:
        _transition_action_active = false
        return
    if runtime != null and runtime.state != null and runtime.state.active_move_id == action_id:
        runtime.cancel_active_move(AttackReservationLedger.RELEASE_INTERRUPTION)
    _runtime_begin_accepted = false


func _commit_terminal_if_ready() -> bool:
    var outcome := runtime.evaluate_live_outcome()
    if outcome == TenthWardenEncounterState.OUTCOME_ONGOING:
        return false
    if action_machine != null and action_machine.is_busy():
        var action_id := action_machine.get_current_action_id()
        if action_id != TenthWardenEncounterState.ACTION_PHASE_TRANSITION and runtime.active_reservation_token != 0:
            runtime.cancel_active_move(AttackReservationLedger.RELEASE_ENCOUNTER_EXIT)
        action_machine.force_interrupt(&"terminal_outcome")
    if _terminal_outcome_emitted == TenthWardenEncounterState.OUTCOME_ONGOING:
        _terminal_outcome_emitted = outcome
        terminal_outcome_ready.emit(outcome)
    return true


func _can_pay_action_cost(action: ActionDefinition) -> bool:
    if action.cost_amount <= 0.0:
        return true
    if action.cost_resource != TenthWardenProductionAuthoring.STAMINA_RESOURCE_ID:
        return false
    _sync_stamina_pool_from_boss()
    return stamina_pool.can_spend(action.cost_resource, action.cost_amount)


func _recover_boss_stamina() -> void:
    if runtime == null or runtime.encounter == null or authoring == null or authoring.stamina_recovery_per_tick <= 0.0:
        return
    var boss := runtime.encounter.get_combatant(runtime.boss_id)
    if boss != null and not boss.is_defeated():
        boss.current_stamina = minf(authoring.stamina, boss.current_stamina + authoring.stamina_recovery_per_tick)


func _sync_stamina_pool_from_boss() -> void:
    if runtime == null or runtime.encounter == null or stamina_pool == null:
        return
    var boss: CombatantRuntimeState = runtime.encounter.get_combatant(runtime.boss_id)
    if boss != null:
        stamina_pool.set_value(TenthWardenProductionAuthoring.STAMINA_RESOURCE_ID, boss.current_stamina)


func _sync_boss_stamina_from_pool() -> void:
    if runtime == null or runtime.encounter == null or stamina_pool == null:
        return
    var boss: CombatantRuntimeState = runtime.encounter.get_combatant(runtime.boss_id)
    if boss != null:
        boss.current_stamina = stamina_pool.get_value(TenthWardenProductionAuthoring.STAMINA_RESOURCE_ID)


func _boss_matches_authoring(
    boss: CombatantRuntimeState,
    source_authoring: TenthWardenProductionAuthoring
) -> bool:
    return boss != null         and boss.actor_id == Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID         and boss.max_hp == source_authoring.max_hp         and is_equal_approx(boss.current_stamina, source_authoring.stamina)         and is_equal_approx(boss.physical_defense, source_authoring.physical_defense)         and is_equal_approx(boss.arcane_defense, source_authoring.arcane_defense)         and is_equal_approx(boss.poise_threshold, source_authoring.poise_threshold)         and boss.interruptible == source_authoring.interruptible         and boss.block_supported == source_authoring.block_supported         and boss.parry_supported == source_authoring.parry_supported


func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "outcome": DirectHitResolver.OUTCOME_REJECTED,
        "hp_damage": 0,
        "target_defeated": false,
    }


func _clear() -> void:
    if action_machine != null and is_instance_valid(action_machine):
        action_machine.free()
    runtime = null
    authoring = null
    action_machine = null
    stamina_pool = null
    _phase_one_cursor = 0
    _phase_two_cursor = 0
    _positioning_condition_met = false
    _runtime_begin_accepted = false
    _transition_action_active = false
    _terminal_outcome_emitted = TenthWardenEncounterState.OUTCOME_ONGOING
