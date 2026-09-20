class_name EnemyArchetypeRuntime
extends RefCounted

signal tactic_selected(actor_id: StringName, tactic_id: StringName, reason_id: StringName)
signal non_attack_tactic_requested(actor_id: StringName, tactic_id: StringName)
signal action_phase_changed(actor_id: StringName, action_id: StringName, phase_id: StringName)
signal tactical_state_changed(actor_id: StringName, state_id: StringName)

const PHASE_IDLE: StringName = &"phase:idle"
const PHASE_WINDUP: StringName = &"phase:windup"
const PHASE_ACTIVE: StringName = &"phase:active"
const PHASE_RECOVERY: StringName = &"phase:recovery"

const TACTICAL_OBSERVE: StringName = &"tactical:observe"
const TACTICAL_PURSUE: StringName = &"tactical:pursue"
const TACTICAL_DISENGAGE: StringName = &"tactical:disengage"
const TACTICAL_REPOSITION: StringName = &"tactical:reposition"
const TACTICAL_DEFEND: StringName = &"tactical:defend"
const TACTICAL_PRESSURE: StringName = &"tactical:pressure"
const TACTICAL_ATTACK: StringName = &"tactical:attack"
const TACTICAL_PUNISH: StringName = &"tactical:punish"
const TACTICAL_RECOVER: StringName = &"tactical:recover"
const TACTICAL_OBJECTIVE: StringName = &"tactical:objective"
const TACTICAL_SUPPORT: StringName = &"tactical:support"

const REASON_NOT_CONFIGURED: StringName = &"not_configured"
const REASON_INVALID_SELECTION: StringName = &"invalid_selection"
const REASON_SIGNATURE_PRECONDITION: StringName = &"signature_precondition_unmet"
const REASON_RESERVATION_REJECTED: StringName = &"reservation_rejected"
const REASON_ACTION_ALREADY_ACTIVE: StringName = &"action_already_active"
const REASON_ACTION_INSTANCE_MISMATCH: StringName = &"action_instance_mismatch"
const REASON_INVALID_PHASE: StringName = &"invalid_phase"

var encounter: CombatEncounterRuntime = null
var definition: EnemyArchetypeDefinition = null
var actor_id: StringName = &""
var target_id: StringName = &""
var phase_id: StringName = PHASE_IDLE
var active_action_instance_id: int = 0
var active_reservation_token: int = 0
var active_committed_observation_position: Vector2 = Vector2.ZERO
var has_active_committed_observation_position: bool = false
var cooldown_ready: bool = true
var tactical_state_id: StringName = TACTICAL_OBSERVE


func configure(
    new_encounter: CombatEncounterRuntime,
    new_actor_id: StringName,
    new_target_id: StringName,
    archetype_id: StringName
) -> bool:
    if new_encounter == null or new_encounter.encounter_id == &"":
        return false
    if not StableId.is_valid(String(new_actor_id)) or not StableId.is_valid(String(new_target_id)):
        return false
    if new_actor_id == new_target_id:
        return false
    var candidate_definition: EnemyArchetypeDefinition = EnemyArchetypeCatalog.get_definition(archetype_id)
    if candidate_definition == null or not candidate_definition.validate_definition().is_empty():
        return false
    if new_encounter.get_combatant(new_actor_id) == null or new_encounter.get_combatant(new_target_id) == null:
        return false
    if not new_encounter.full_ai.is_admitted_to_encounter(new_actor_id, new_encounter.encounter_id):
        return false

    encounter = new_encounter
    definition = candidate_definition
    actor_id = new_actor_id
    target_id = new_target_id
    phase_id = PHASE_IDLE
    active_action_instance_id = 0
    active_reservation_token = 0
    active_committed_observation_position = Vector2.ZERO
    has_active_committed_observation_position = false
    cooldown_ready = true
    tactical_state_id = TACTICAL_OBSERVE
    return true


func choose_tactic(selector_context: Variant, signature_facts: Variant = {}) -> Dictionary:
    if not is_configured():
        return _rejected(REASON_NOT_CONFIGURED)
    if not is_tactical_eligible():
        return _rejected(&"tactical_ineligible")
    var selection: Dictionary = EnemyTacticalSelector.select_tactic(definition, selector_context)
    if not bool(selection.get("accepted", false)):
        return selection

    var tactic_id := StringName(String(selection.get("tactic_id", &"")))
    if tactic_id == definition.signature_action_id:
        if not cooldown_ready or phase_id != PHASE_IDLE:
            return _hold_selection(&"reason:no_legal_commit")
        var admission: Dictionary = EnemyArchetypeActionAdmission.validate_signature_commit(definition, _resolved_signature_facts(signature_facts))
        if not bool(admission.get("accepted", false)):
            return _hold_selection(REASON_SIGNATURE_PRECONDITION, StringName(admission.get("reason_id", &"")))

    tactic_selected.emit(actor_id, tactic_id, StringName(selection.get("reason_id", &"")))
    return selection.duplicate(true)


func request_non_attack_tactic(selection: Variant) -> bool:
    if not is_configured() or not is_tactical_eligible() or phase_id != PHASE_IDLE or not selection is Dictionary:
        return false
    var selected: Dictionary = selection as Dictionary
    if not bool(selected.get("accepted", false)):
        return false
    var tactic_id := StringName(String(selected.get("tactic_id", &"")))
    if tactic_id == &"" or tactic_id == definition.signature_action_id or not definition.tactic_ids.has(tactic_id):
        return false
    _set_tactical_state(_tactical_state_for_tactic(tactic_id))
    non_attack_tactic_requested.emit(actor_id, tactic_id)
    return true


func begin_signature_action(selection: Variant, action_instance_id: int, signature_facts: Variant = {}) -> Dictionary:
    if not is_configured():
        return _rejected(REASON_NOT_CONFIGURED)
    if not is_tactical_eligible():
        return _rejected(&"tactical_ineligible")
    if phase_id != PHASE_IDLE or active_reservation_token != 0:
        return _rejected(REASON_ACTION_ALREADY_ACTIVE)
    if action_instance_id <= 0 or not selection is Dictionary:
        return _rejected(REASON_INVALID_SELECTION)
    var selected: Dictionary = selection as Dictionary
    if not bool(selected.get("accepted", false)):
        return _rejected(REASON_INVALID_SELECTION)
    var tactic_id := StringName(String(selected.get("tactic_id", &"")))
    if tactic_id != definition.signature_action_id or not cooldown_ready:
        return _rejected(REASON_INVALID_SELECTION)

    var admission: Dictionary = EnemyArchetypeActionAdmission.validate_signature_commit(definition, _resolved_signature_facts(signature_facts))
    if not bool(admission.get("accepted", false)):
        return {
            "accepted": false,
            "reason_id": REASON_SIGNATURE_PRECONDITION,
            "admission_reason_id": StringName(admission.get("reason_id", &"")),
            "action_id": &"",
        }

    var token: int = encounter.reserve_enemy_attack(actor_id, target_id, action_instance_id)
    if token <= 0:
        return _rejected(REASON_RESERVATION_REJECTED)

    active_action_instance_id = action_instance_id
    active_reservation_token = token
    active_committed_observation_position = Vector2.ZERO
    has_active_committed_observation_position = false
    if signature_facts is Dictionary:
        var observed_position_variant: Variant = (signature_facts as Dictionary).get("observed_target_position", null)
        if observed_position_variant is Vector2 and (observed_position_variant as Vector2).is_finite():
            active_committed_observation_position = observed_position_variant as Vector2
            has_active_committed_observation_position = true
    cooldown_ready = false
    _set_tactical_state(TACTICAL_ATTACK)
    _set_phase(PHASE_WINDUP)
    return {
        "accepted": true,
        "reason_id": &"committed",
        "action_id": definition.signature_action_id,
        "action_instance_id": active_action_instance_id,
        "reservation_token": active_reservation_token,
        "phase_id": phase_id,
    }


func begin_active(action_instance_id: int) -> bool:
    if not _matches_active_action(action_instance_id) or phase_id != PHASE_WINDUP:
        return false
    _set_phase(PHASE_ACTIVE)
    return true


func get_active_delivery_context(action_instance_id: int) -> Dictionary:
    if not is_configured():
        return _delivery_rejected(REASON_NOT_CONFIGURED)
    if action_instance_id <= 0 or active_action_instance_id != action_instance_id:
        return _delivery_rejected(REASON_ACTION_INSTANCE_MISMATCH)
    if phase_id != PHASE_ACTIVE:
        return _delivery_rejected(REASON_INVALID_PHASE)
    if not is_tactical_eligible():
        return _delivery_rejected(&"tactical_ineligible")
    if not encounter.has_enemy_attack_ownership(actor_id, target_id, action_instance_id, active_reservation_token):
        return _delivery_rejected(REASON_RESERVATION_REJECTED)
    var attack_authoring_errors := definition.validate_signature_attack_authoring()
    return {
        "accepted": true,
        "reason_id": &"",
        "encounter_id": encounter.encounter_id,
        "actor_id": actor_id,
        "target_id": target_id,
        "action_id": definition.signature_action_id,
        "action_instance_id": active_action_instance_id,
        "reservation_token": active_reservation_token,
        "phase_id": phase_id,
        "has_committed_observation_position": has_active_committed_observation_position,
        "committed_observation_position": active_committed_observation_position,
        "attack_authoring_ready": attack_authoring_errors.is_empty(),
        "attack_authoring_errors": attack_authoring_errors,
    }


func begin_recovery(action_instance_id: int) -> bool:
    if not _matches_active_action(action_instance_id) or phase_id != PHASE_ACTIVE:
        return false
    _set_tactical_state(TACTICAL_RECOVER)
    _set_phase(PHASE_RECOVERY)
    return true


func finish_recovery(action_instance_id: int) -> bool:
    if not _matches_active_action(action_instance_id) or phase_id != PHASE_RECOVERY:
        return false
    if not encounter.release_enemy_attack(active_reservation_token, AttackReservationLedger.RELEASE_COMPLETION):
        return false
    _clear_active_action()
    return true


func cancel_action(reason_id: StringName = AttackReservationLedger.RELEASE_CANCELLATION) -> bool:
    if not is_configured() or active_reservation_token == 0:
        return false
    if not [
        AttackReservationLedger.RELEASE_CANCELLATION,
        AttackReservationLedger.RELEASE_INTERRUPTION,
        AttackReservationLedger.RELEASE_TARGET_INVALIDATION,
        AttackReservationLedger.RELEASE_ENCOUNTER_EXIT,
    ].has(reason_id):
        return false
    if not encounter.release_enemy_attack(active_reservation_token, reason_id):
        return false
    _clear_active_action()
    return true


func mark_cooldown_ready() -> bool:
    if not is_configured() or phase_id != PHASE_IDLE or active_reservation_token != 0:
        return false
    cooldown_ready = true
    return true


func is_configured() -> bool:
    return encounter != null and definition != null and actor_id != &"" and target_id != &""


func is_tactical_eligible() -> bool:
    if not is_configured() or not encounter.is_enemy_tactical_eligible(actor_id):
        return false
    var target := encounter.get_combatant(target_id)
    return target != null and not target.is_defeated()


func reconcile_external_reservation_release() -> bool:
    if not is_configured():
        return false
    if active_reservation_token == 0:
        return phase_id == PHASE_IDLE and active_action_instance_id == 0
    if encounter.reservations.has_reservation(actor_id, active_action_instance_id):
        return false
    _clear_active_action()
    return true


func get_debug_snapshot() -> Dictionary:
    return {
        "configured": is_configured(),
        "encounter_id": encounter.encounter_id if encounter != null else &"",
        "actor_id": actor_id,
        "target_id": target_id,
        "archetype_id": definition.archetype_id if definition != null else &"",
        "signature_action_id": definition.signature_action_id if definition != null else &"",
        "phase_id": phase_id,
        "active_action_instance_id": active_action_instance_id,
        "active_reservation_token": active_reservation_token,
        "has_committed_observation_position": has_active_committed_observation_position,
        "committed_observation_position": active_committed_observation_position,
        "cooldown_ready": cooldown_ready,
        "tactical_state_id": tactical_state_id,
        "tactical_eligible": is_tactical_eligible(),
    }


func _resolved_signature_facts(raw_facts: Variant) -> Variant:
    if not raw_facts is Dictionary:
        return raw_facts
    var resolved: Dictionary = (raw_facts as Dictionary).duplicate(true)
    if definition != null and definition.defensive_limit_ids.has(&"limit:full_ai_cap_required") and encounter != null:
        resolved["full_ai_slot_available"] = encounter.full_ai.get_admitted_count() < FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS
    return resolved


func _matches_active_action(action_instance_id: int) -> bool:
    return is_configured() \
        and action_instance_id > 0 \
        and active_action_instance_id == action_instance_id \
        and active_reservation_token != 0


func _set_phase(new_phase_id: StringName) -> void:
    phase_id = new_phase_id
    action_phase_changed.emit(actor_id, definition.signature_action_id, phase_id)


func _clear_active_action() -> void:
    active_action_instance_id = 0
    active_reservation_token = 0
    active_committed_observation_position = Vector2.ZERO
    has_active_committed_observation_position = false
    _set_tactical_state(TACTICAL_OBSERVE)
    _set_phase(PHASE_IDLE)


func _set_tactical_state(new_state_id: StringName) -> void:
    if tactical_state_id == new_state_id:
        return
    tactical_state_id = new_state_id
    tactical_state_changed.emit(actor_id, tactical_state_id)


func _tactical_state_for_tactic(tactic_id: StringName) -> StringName:
    match tactic_id:
        &"tactic:hold_observe":
            return TACTICAL_OBSERVE
        &"tactic:approach":
            return TACTICAL_PURSUE
        &"tactic:withdraw":
            return TACTICAL_DISENGAGE
        &"tactic:reposition_last_known":
            return TACTICAL_REPOSITION
        &"tactic:contest_objective":
            return TACTICAL_OBJECTIVE
        _:
            return TACTICAL_OBSERVE


func _hold_selection(reason_id: StringName, admission_reason_id: StringName = &"") -> Dictionary:
    var result := {
        "accepted": true,
        "reason_id": reason_id,
        "tactic_id": &"tactic:hold_observe",
        "score": 25.0,
    }
    if admission_reason_id != &"":
        result["admission_reason_id"] = admission_reason_id
    tactic_selected.emit(actor_id, &"tactic:hold_observe", reason_id)
    return result


func _delivery_rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "encounter_id": encounter.encounter_id if encounter != null else &"",
        "actor_id": actor_id,
        "target_id": target_id,
        "action_id": definition.signature_action_id if definition != null else &"",
        "action_instance_id": active_action_instance_id,
        "reservation_token": active_reservation_token,
        "phase_id": phase_id,
    }


func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "action_id": &"",
    }
