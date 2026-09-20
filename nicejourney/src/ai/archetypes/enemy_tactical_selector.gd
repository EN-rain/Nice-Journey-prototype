class_name EnemyTacticalSelector
extends RefCounted


static func select_tactic(definition: EnemyArchetypeDefinition, raw_context: Variant) -> Dictionary:
    if definition == null or not definition.validate_definition().is_empty():
        return _rejected(&"invalid_definition")
    if not raw_context is Dictionary:
        return _rejected(&"invalid_context")
    var context: Dictionary = raw_context as Dictionary
    var context_error: StringName = _validate_context(context)
    if context_error != &"":
        return _rejected(context_error)

    var target_visible: bool = bool(context["target_visible"])
    var confidence: float = float(context["observation_confidence"])
    var reaction_ready: bool = bool(context["reaction_delay_satisfied"])
    var distance_band: StringName = StringName(String(context["distance_band"]))
    var reservation_available: bool = bool(context["reservation_available"])
    var cooldown_ready: bool = bool(context["cooldown_ready"])
    var objective_contested: bool = bool(context["objective_contested"])
    var player_recovering: bool = bool(context["observed_player_recovering"])
    var player_committed: bool = bool(context["observed_player_committed"])
    var signature_repeat_suppressed: bool = bool(context.get("signature_repeat_suppressed", false))

    if not reaction_ready:
        return _accepted(definition, &"tactic:hold_observe", 20.0, &"reason:reaction_delay")

    if not target_visible:
        if confidence > 0.0 and definition.tactic_ids.has(&"tactic:reposition_last_known"):
            return _accepted(definition, &"tactic:reposition_last_known", 55.0 * confidence, &"reason:last_known_observation")
        return _accepted(definition, &"tactic:hold_observe", 10.0, &"reason:no_current_observation")

    if objective_contested and definition.tactic_ids.has(&"tactic:contest_objective"):
        return _accepted(definition, &"tactic:contest_objective", 75.0, &"reason:objective_contested")

    var range_tactic: StringName = _range_adjustment_tactic(definition.preferred_range, distance_band)
    if range_tactic != &"" and definition.tactic_ids.has(range_tactic):
        return _accepted(definition, range_tactic, 70.0, &"reason:preferred_range")

    if reservation_available and cooldown_ready and signature_repeat_suppressed:
        return _accepted(definition, &"tactic:hold_observe", 30.0, &"reason:signature_repeat_suppression")

    if reservation_available and cooldown_ready and (player_recovering or player_committed):
        return _accepted(definition, definition.signature_action_id, 95.0, &"reason:observed_commit_window")

    if reservation_available and cooldown_ready:
        return _accepted(definition, definition.signature_action_id, 60.0, &"reason:baseline_pressure")

    return _accepted(definition, &"tactic:hold_observe", 25.0, &"reason:no_legal_commit")


static func _range_adjustment_tactic(preferred_range: StringName, distance_band: StringName) -> StringName:
    if preferred_range == EnemyArchetypeDefinition.RANGE_CLOSE:
        if distance_band == EnemyArchetypeDefinition.RANGE_MID or distance_band == EnemyArchetypeDefinition.RANGE_LONG:
            return &"tactic:approach"
        return &""
    if preferred_range == EnemyArchetypeDefinition.RANGE_LONG:
        if distance_band == EnemyArchetypeDefinition.RANGE_CLOSE or distance_band == EnemyArchetypeDefinition.RANGE_MID:
            return &"tactic:withdraw"
        return &""
    if preferred_range == EnemyArchetypeDefinition.RANGE_MID:
        if distance_band == EnemyArchetypeDefinition.RANGE_CLOSE:
            return &"tactic:withdraw"
        if distance_band == EnemyArchetypeDefinition.RANGE_LONG:
            return &"tactic:approach"
    return &""


static func _validate_context(context: Dictionary) -> StringName:
    for bool_key: String in [
        "target_visible",
        "reaction_delay_satisfied",
        "reservation_available",
        "cooldown_ready",
        "objective_contested",
        "observed_player_recovering",
        "observed_player_committed",
    ]:
        if not context.has(bool_key) or typeof(context[bool_key]) != TYPE_BOOL:
            return &"invalid_context"
    if not context.has("distance_band"):
        return &"invalid_context"
    var distance_variant: Variant = context["distance_band"]
    if not (typeof(distance_variant) == TYPE_STRING or typeof(distance_variant) == TYPE_STRING_NAME):
        return &"invalid_context"
    var distance_band: StringName = StringName(String(distance_variant))
    if not [EnemyArchetypeDefinition.RANGE_CLOSE, EnemyArchetypeDefinition.RANGE_MID, EnemyArchetypeDefinition.RANGE_LONG].has(distance_band):
        return &"invalid_context"
    if not context.has("observation_confidence"):
        return &"invalid_context"
    var confidence_variant: Variant = context["observation_confidence"]
    if not (typeof(confidence_variant) == TYPE_INT or typeof(confidence_variant) == TYPE_FLOAT):
        return &"invalid_context"
    var confidence: float = float(confidence_variant)
    if not is_finite(confidence) or confidence < 0.0 or confidence > 1.0:
        return &"invalid_context"
    if context.has("signature_repeat_suppressed") and typeof(context["signature_repeat_suppressed"]) != TYPE_BOOL:
        return &"invalid_context"
    if not context.has("observation_age_ticks"):
        return &"invalid_context"
    var age_variant: Variant = context["observation_age_ticks"]
    if typeof(age_variant) != TYPE_INT or int(age_variant) < 0:
        return &"invalid_context"
    return &""


static func _accepted(definition: EnemyArchetypeDefinition, tactic_id: StringName, score: float, reason_id: StringName) -> Dictionary:
    if not definition.tactic_ids.has(tactic_id):
        return _rejected(&"tactic_not_authored")
    return {
        "accepted": true,
        "reason_id": reason_id,
        "tactic_id": tactic_id,
        "score": score,
    }


static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "tactic_id": &"",
        "score": 0.0,
    }
