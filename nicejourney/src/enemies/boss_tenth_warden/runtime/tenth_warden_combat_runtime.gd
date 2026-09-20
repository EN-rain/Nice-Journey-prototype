class_name TenthWardenCombatRuntime
extends RefCounted

const REASON_NOT_CONFIGURED: StringName = &"not_configured"
const REASON_NO_ACTIVE_MOVE: StringName = &"no_active_move"
const REASON_ACTION_INSTANCE_MISMATCH: StringName = &"action_instance_mismatch"
const REASON_INVALID_MOVE_PAYLOAD: StringName = &"invalid_move_payload"
const REASON_RECOVERY_ACTIVE: StringName = &"recovery_active"

var encounter: CombatEncounterRuntime = null
var state: TenthWardenEncounterState = null
var player_id: StringName = &""
var boss_id: StringName = &""
var active_action_instance_id: int = 0
var active_reservation_token: int = 0

func configure(
    new_encounter: CombatEncounterRuntime,
    new_player_id: StringName,
    new_boss_id: StringName,
    tuning: TenthWardenEncounterTuning
) -> bool:
    if new_encounter == null or new_encounter.encounter_id == &"":
        return false
    if not StableId.is_valid(String(new_player_id)) or not StableId.is_valid(String(new_boss_id)):
        return false
    if new_player_id == new_boss_id:
        return false
    var player: CombatantRuntimeState = new_encounter.get_combatant(new_player_id)
    var boss: CombatantRuntimeState = new_encounter.get_combatant(new_boss_id)
    if player == null or boss == null or player.is_defeated() or boss.is_defeated():
        return false
    if not new_encounter.full_ai.is_admitted_to_encounter(new_boss_id, new_encounter.encounter_id):
        return false

    var candidate_state := TenthWardenEncounterState.new()
    if not candidate_state.configure(tuning):
        return false
    if not candidate_state.observe_health(boss.current_hp, boss.max_hp):
        return false

    encounter = new_encounter
    state = candidate_state
    player_id = new_player_id
    boss_id = new_boss_id
    active_action_instance_id = 0
    active_reservation_token = 0
    return true

func begin_move(move_id: StringName, action_instance_id: int, positioning_condition_met: bool = true) -> bool:
    if not is_configured() or action_instance_id <= 0 or active_reservation_token != 0:
        return false
    if not state.can_begin_move(move_id, positioning_condition_met):
        return false
    var token: int = encounter.reserve_enemy_attack(boss_id, player_id, action_instance_id)
    if token <= 0:
        return false
    if not state.begin_committed_move(move_id, positioning_condition_met):
        encounter.release_enemy_attack(token, AttackReservationLedger.RELEASE_CANCELLATION)
        return false
    active_action_instance_id = action_instance_id
    active_reservation_token = token
    return true

func resolve_boss_contact(
    action_instance_id: int,
    hit_interval_index: int,
    attack_payload: Dictionary,
    evade_window_active: bool,
    defense_mode: StringName,
    facing_covered: bool
) -> Dictionary:
    if not is_configured():
        return _rejected(REASON_NOT_CONFIGURED)
    if state.active_move_id == &"" or active_reservation_token == 0:
        return _rejected(REASON_NO_ACTIVE_MOVE)
    if state.recovery_active:
        return _rejected(REASON_RECOVERY_ACTIVE)
    if action_instance_id != active_action_instance_id:
        return _rejected(REASON_ACTION_INSTANCE_MISMATCH)
    if not encounter.has_enemy_attack_ownership(boss_id, player_id, action_instance_id, active_reservation_token):
        return _rejected(REASON_NO_ACTIVE_MOVE)
    if not _payload_matches_locked_move(state.active_move_id, hit_interval_index, attack_payload):
        return _rejected(REASON_INVALID_MOVE_PAYLOAD)
    var result := encounter.resolve_direct_contact(
        boss_id,
        player_id,
        action_instance_id,
        hit_interval_index,
        attack_payload,
        evade_window_active,
        defense_mode,
        facing_covered
    )
    if bool(result.get("accepted", false)) and bool(result.get("attacker_interrupt_requested", false)):
        state.begin_recovery(false)
    return result

func resolve_player_contact(
    action_instance_id: int,
    hit_interval_index: int,
    attack_payload: Dictionary,
    evade_window_active: bool = false,
    defense_mode: StringName = DirectHitResolver.DEFENSE_NONE,
    facing_covered: bool = false
) -> Dictionary:
    if not is_configured():
        return _rejected(REASON_NOT_CONFIGURED)
    var locked_payload := attack_payload.duplicate(true)
    if not state.weak_point_exposed:
        locked_payload["weak_point_triggered"] = false
    var result: Dictionary = encounter.resolve_direct_contact(
        player_id,
        boss_id,
        action_instance_id,
        hit_interval_index,
        locked_payload,
        evade_window_active,
        defense_mode,
        facing_covered
    )
    if bool(result.get("accepted", false)):
        var boss: CombatantRuntimeState = encounter.get_combatant(boss_id)
        if boss != null and not boss.is_defeated():
            state.observe_health(boss.current_hp, boss.max_hp)
    return result

func begin_recovery(is_heavy_committed_action: bool) -> bool:
    return is_configured() and active_reservation_token != 0 and state.begin_recovery(is_heavy_committed_action)

func finish_recovery() -> bool:
    if not is_configured() or active_reservation_token == 0:
        return false
    if not state.finish_recovery():
        return false
    var released: bool = encounter.release_enemy_attack(active_reservation_token, AttackReservationLedger.RELEASE_COMPLETION)
    active_reservation_token = 0
    active_action_instance_id = 0
    return released

func cancel_active_move(reason_id: StringName = AttackReservationLedger.RELEASE_CANCELLATION) -> bool:
    if not is_configured() or active_reservation_token == 0:
        return false
    if not encounter.release_enemy_attack(active_reservation_token, reason_id):
        return false
    active_reservation_token = 0
    active_action_instance_id = 0
    if state.active_move_id != &"":
        state.cancel_committed_move()
    return true

func commit_phase_transition() -> bool:
    return is_configured() and state.commit_phase_transition()

func evaluate_live_outcome() -> StringName:
    if not is_configured():
        return TenthWardenEncounterState.OUTCOME_ONGOING
    var player: CombatantRuntimeState = encounter.get_combatant(player_id)
    var boss: CombatantRuntimeState = encounter.get_combatant(boss_id)
    if player == null or boss == null:
        return TenthWardenEncounterState.OUTCOME_ONGOING
    return TenthWardenEncounterState.evaluate_terminal_outcome(player.is_defeated(), boss.is_defeated())

func end_encounter() -> void:
    if encounter != null:
        encounter.end_encounter()
    active_reservation_token = 0
    active_action_instance_id = 0
    encounter = null
    state = null
    player_id = &""
    boss_id = &""

func is_configured() -> bool:
    return encounter != null and state != null and player_id != &"" and boss_id != &""

func get_debug_snapshot() -> Dictionary:
    return {
        "configured": is_configured(),
        "encounter_id": encounter.encounter_id if encounter != null else &"",
        "player_id": player_id,
        "boss_id": boss_id,
        "active_action_instance_id": active_action_instance_id,
        "active_reservation_token": active_reservation_token,
        "boss_state": state.get_debug_snapshot() if state != null else {},
        "outcome": evaluate_live_outcome(),
    }

func _payload_matches_locked_move(move_id: StringName, hit_interval_index: int, attack_payload: Dictionary) -> bool:
    if hit_interval_index < 0 or attack_payload == null:
        return false
    match move_id:
        TenthWardenEncounterState.MOVE_TWIN_CUT:
            return hit_interval_index < 2 and _delivery_is(attack_payload, DirectHitResolver.DELIVERY_CONTACT)
        TenthWardenEncounterState.MOVE_WARDEN_LUNGE:
            return _delivery_is(attack_payload, DirectHitResolver.DELIVERY_CONTACT)
        TenthWardenEncounterState.MOVE_ARC_VOLLEY:
            return _delivery_is(attack_payload, DirectHitResolver.DELIVERY_PROJECTILE) \
                and attack_payload.get("dodgeable") is bool and bool(attack_payload["dodgeable"]) \
                and attack_payload.get("blockable") is bool and bool(attack_payload["blockable"]) \
                and attack_payload.get("parryable") is bool and not bool(attack_payload["parryable"])
        TenthWardenEncounterState.MOVE_CRESCENT_SWEEP:
            return _delivery_is(attack_payload, DirectHitResolver.DELIVERY_CONTACT) \
                and attack_payload.get("dodgeable") is bool and bool(attack_payload["dodgeable"]) \
                and attack_payload.get("blockable") is bool and not bool(attack_payload["blockable"])
        TenthWardenEncounterState.MOVE_PUNISHING_STEP:
            return _delivery_is(attack_payload, DirectHitResolver.DELIVERY_CONTACT)
        _:
            return false

func _delivery_is(attack_payload: Dictionary, expected: StringName) -> bool:
    return attack_payload.has("delivery") and StringName(String(attack_payload["delivery"])) == expected

func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "outcome": DirectHitResolver.OUTCOME_REJECTED,
        "hp_damage": 0,
        "target_defeated": false,
    }
