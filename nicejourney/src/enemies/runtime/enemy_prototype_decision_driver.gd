class_name EnemyPrototypeDecisionDriver
extends RefCounted

const OBSERVED_TARGET_STATE: StringName = &"state:target_visible"

var runtime: EnemyArchetypeRuntime = null
var phase_driver: EnemySignatureActionPhaseDriver = null
var tuning: EnemyPrototypeDecisionTuning = null
var memory: AiObservationMemory = AiObservationMemory.new(8)
var admission: AiObservationAdmission = AiObservationAdmission.new(memory)
var _visibility_started_tick: int = -1
var _next_evaluation_tick: int = 0
var _consecutive_signature_commits: int = 0
var _signature_suppression_evaluations_remaining: int = 0

func configure(
    source_runtime: EnemyArchetypeRuntime,
    source_phase_driver: EnemySignatureActionPhaseDriver,
    source_tuning: EnemyPrototypeDecisionTuning
) -> bool:
    if source_runtime == null or source_phase_driver == null or source_tuning == null:
        return false
    if not source_runtime.is_configured() or source_phase_driver.runtime != source_runtime:
        return false
    if not source_tuning.validate_tuning().is_empty():
        return false
    runtime = source_runtime
    phase_driver = source_phase_driver
    tuning = source_tuning
    memory = AiObservationMemory.new(8)
    admission = AiObservationAdmission.new(memory)
    _visibility_started_tick = -1
    _next_evaluation_tick = 0
    _consecutive_signature_commits = 0
    _signature_suppression_evaluations_remaining = 0
    return true

func admit_shared_observation(raw_fact: Variant, now_tick: int) -> bool:
    if runtime == null or tuning == null or now_tick < 0 or not raw_fact is Dictionary:
        return false
    var fact := raw_fact as Dictionary
    if StringName(String(fact.get("source_id", &""))) != runtime.target_id:
        return false
    var observed_state := StringName(String(fact.get("observed_state", &"")))
    var observed_tick := int(fact.get("observed_tick", -1))
    var observed_position_variant: Variant = fact.get("observed_position", null)
    var confidence_variant: Variant = fact.get("confidence", null)
    var lifetime_ticks := int(fact.get("lifetime_ticks", 0))
    if not StableId.is_valid(String(observed_state)) or observed_tick < 0 or not observed_position_variant is Vector2:
        return false
    if not (typeof(confidence_variant) == TYPE_INT or typeof(confidence_variant) == TYPE_FLOAT):
        return false
    var observed_position := observed_position_variant as Vector2
    var confidence := float(confidence_variant)
    if not observed_position.is_finite() or not is_finite(confidence) or confidence < 0.0 or confidence > 1.0 or lifetime_ticks <= 0:
        return false
    if now_tick >= observed_tick + lifetime_ticks:
        return false
    var current := memory.latest_for_source(runtime.target_id, now_tick, 0.0)
    if not current.is_empty() and int(current.get("observed_tick", -1)) >= observed_tick:
        return true
    return admission.admit_shared_fact(
        runtime.target_id,
        observed_position,
        observed_state,
        observed_tick,
        confidence,
        lifetime_ticks,
        now_tick
    )

func observe_and_decide(
    now_tick: int,
    enemy_position: Vector2,
    target_position: Vector2,
    target_visible: bool,
    new_action_instance_id: int,
    internal_facts: Dictionary = {}
) -> Dictionary:
    if runtime == null or phase_driver == null or tuning == null or now_tick < 0:
        return _result(false, &"not_configured")
    if not runtime.is_tactical_eligible():
        _visibility_started_tick = -1
        return _result(false, &"tactical_ineligible")
    if not enemy_position.is_finite() or not target_position.is_finite():
        return _result(false, &"invalid_positions")

    if target_visible:
        if _visibility_started_tick < 0:
            _visibility_started_tick = now_tick
        admission.admit_sight(
            runtime.target_id,
            target_position,
            OBSERVED_TARGET_STATE,
            now_tick,
            1.0,
            tuning.observation_lifetime_ticks,
            now_tick
        )
    else:
        _visibility_started_tick = -1

    memory.purge_expired(now_tick)
    if now_tick < _next_evaluation_tick:
        return _result(true, &"evaluation_throttled")
    _next_evaluation_tick = now_tick + tuning.evaluation_interval_ticks

    var latest := memory.latest_for_source(runtime.target_id, now_tick, tuning.confidence_decay_per_tick)
    var observed_position := target_position if target_visible else Vector2(latest.get("observed_position", enemy_position))
    var confidence := 1.0 if target_visible else float(latest.get("confidence", 0.0))
    var reaction_ready := target_visible \
        and _visibility_started_tick >= 0 \
        and now_tick >= _visibility_started_tick + tuning.reaction_delay_ticks
    if not target_visible and not latest.is_empty():
        reaction_ready = memory.can_react_to(latest, now_tick, tuning.reaction_delay_ticks)

    var repeat_suppressed := _signature_suppression_evaluations_remaining > 0 \
        and runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE \
        and runtime.cooldown_ready
    var context := {
        "target_visible": target_visible,
        "observation_confidence": clampf(confidence, 0.0, 1.0),
        "reaction_delay_satisfied": reaction_ready,
        "distance_band": _distance_band(enemy_position.distance_to(observed_position)),
        "reservation_available": runtime.encounter.attack_pressure.has_capacity(),
        "cooldown_ready": runtime.cooldown_ready,
        "signature_repeat_suppressed": repeat_suppressed,
        "objective_contested": bool(internal_facts.get("objective_contested", false)),
        "observed_player_recovering": target_visible and bool(internal_facts.get("observed_player_recovering", false)),
        "observed_player_committed": target_visible and bool(internal_facts.get("observed_player_committed", false)),
        "observation_age_ticks": int(latest.get("age_ticks", 0)) if not latest.is_empty() else 0,
    }
    var signature_facts := _signature_facts(target_visible, internal_facts, observed_position)
    var selection := runtime.choose_tactic(context, signature_facts)
    if not bool(selection.get("accepted", false)):
        var rejected := _result(false, StringName(selection.get("reason_id", &"selection_rejected")))
        rejected["selection"] = selection.duplicate(true)
        return rejected

    var tactic_id := StringName(String(selection.get("tactic_id", &"")))
    var committed := false
    if tactic_id == runtime.definition.signature_action_id:
        if new_action_instance_id <= 0:
            var invalid := _result(false, &"action_instance_required")
            invalid["selection"] = selection.duplicate(true)
            return invalid
        var begin := phase_driver.begin(selection, new_action_instance_id, signature_facts)
        committed = bool(begin.get("accepted", false))
        if not committed:
            var rejected := _result(false, StringName(begin.get("reason_id", &"begin_rejected")))
            rejected["selection"] = selection.duplicate(true)
            rejected["begin"] = begin.duplicate(true)
            return rejected
        _consecutive_signature_commits += 1
        if _consecutive_signature_commits >= tuning.signature_repeat_limit:
            _signature_suppression_evaluations_remaining = tuning.signature_suppression_evaluations
            _consecutive_signature_commits = 0
    else:
        runtime.request_non_attack_tactic(selection)
        if StringName(String(selection.get("reason_id", &""))) == &"reason:signature_repeat_suppression":
            _signature_suppression_evaluations_remaining = maxi(0, _signature_suppression_evaluations_remaining - 1)

    var result := _result(true, &"")
    result["selection"] = selection.duplicate(true)
    result["signature_facts"] = signature_facts.duplicate(true)
    result["committed"] = committed
    result["action_instance_id"] = new_action_instance_id if committed else 0
    result["target_visible"] = target_visible
    result["reaction_ready"] = reaction_ready
    result["observation_confidence"] = context["observation_confidence"]
    result["observed_position"] = observed_position
    return result

func _signature_facts(target_visible: bool, internal_facts: Dictionary, observed_position: Vector2) -> Dictionary:
    return {
        "line_of_sight_observed": target_visible,
        "observed_target_position": observed_position,
        "flank_observed": target_visible and bool(internal_facts.get("flank_observed", false)),
        "ally_observed": bool(internal_facts.get("ally_observed", false)),
        "reinforcement_budget_available": bool(internal_facts.get("reinforcement_budget_available", false)),
        "full_ai_slot_available": runtime.encounter.full_ai.get_admitted_count() < FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS,
        "visible_targeting_window": target_visible,
        "telegraph_ready": bool(internal_facts.get("telegraph_ready", true)),
    }

func _distance_band(distance_px: float) -> StringName:
    if distance_px <= tuning.close_range_px:
        return EnemyArchetypeDefinition.RANGE_CLOSE
    if distance_px <= tuning.mid_range_px:
        return EnemyArchetypeDefinition.RANGE_MID
    return EnemyArchetypeDefinition.RANGE_LONG

func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "selection": {},
        "signature_facts": {},
        "committed": false,
        "action_instance_id": 0,
        "target_visible": false,
        "reaction_ready": false,
        "observation_confidence": 0.0,
        "observed_position": Vector2.ZERO,
    }
