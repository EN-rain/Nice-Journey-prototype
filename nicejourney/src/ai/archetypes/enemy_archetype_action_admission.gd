class_name EnemyArchetypeActionAdmission
extends RefCounted

const REASON_ACCEPTED: StringName = &"accepted"
const REASON_INVALID_DEFINITION: StringName = &"invalid_definition"
const REASON_INVALID_FACTS: StringName = &"invalid_facts"
const REASON_LINE_OF_SIGHT_REQUIRED: StringName = &"line_of_sight_required"
const REASON_FLANK_REQUIRED: StringName = &"flank_required"
const REASON_ALLY_REQUIRED: StringName = &"ally_required"
const REASON_REINFORCEMENT_BUDGET_REQUIRED: StringName = &"reinforcement_budget_required"
const REASON_FULL_AI_SLOT_REQUIRED: StringName = &"full_ai_slot_required"
const REASON_VISIBLE_TARGETING_REQUIRED: StringName = &"visible_targeting_required"
const REASON_TELEGRAPH_REQUIRED: StringName = &"telegraph_required"


static func validate_signature_commit(definition: EnemyArchetypeDefinition, raw_facts: Variant) -> Dictionary:
    if definition == null or not definition.validate_definition().is_empty():
        return _rejected(REASON_INVALID_DEFINITION)
    if not raw_facts is Dictionary:
        return _rejected(REASON_INVALID_FACTS)
    var facts: Dictionary = raw_facts as Dictionary

    var checks: Array[Dictionary] = [
        {
            "limit_ids": [&"limit:requires_observed_line_of_sight"],
            "fact_key": "line_of_sight_observed",
            "reason_id": REASON_LINE_OF_SIGHT_REQUIRED,
        },
        {
            "limit_ids": [&"limit:requires_observed_flank"],
            "fact_key": "flank_observed",
            "reason_id": REASON_FLANK_REQUIRED,
        },
        {
            "limit_ids": [&"limit:requires_observed_ally"],
            "fact_key": "ally_observed",
            "reason_id": REASON_ALLY_REQUIRED,
        },
        {
            "limit_ids": [&"limit:finite_reinforcement_budget"],
            "fact_key": "reinforcement_budget_available",
            "reason_id": REASON_REINFORCEMENT_BUDGET_REQUIRED,
        },
        {
            "limit_ids": [&"limit:full_ai_cap_required"],
            "fact_key": "full_ai_slot_available",
            "reason_id": REASON_FULL_AI_SLOT_REQUIRED,
        },
        {
            "limit_ids": [&"limit:visible_targeting_required"],
            "fact_key": "visible_targeting_window",
            "reason_id": REASON_VISIBLE_TARGETING_REQUIRED,
        },
        {
            "limit_ids": [&"limit:telegraph_required", &"limit:telegraphed_control_zone"],
            "fact_key": "telegraph_ready",
            "reason_id": REASON_TELEGRAPH_REQUIRED,
        },
    ]

    for check: Dictionary in checks:
        if not _definition_has_any_limit(definition, check["limit_ids"] as Array):
            continue
        var key: String = String(check["fact_key"])
        if not facts.has(key) or typeof(facts[key]) != TYPE_BOOL:
            return _rejected(REASON_INVALID_FACTS)
        if not bool(facts[key]):
            return _rejected(StringName(check["reason_id"]))

    return {
        "accepted": true,
        "reason_id": REASON_ACCEPTED,
        "action_id": definition.signature_action_id,
    }


static func _definition_has_any_limit(definition: EnemyArchetypeDefinition, limit_ids: Array) -> bool:
    for limit_variant: Variant in limit_ids:
        var limit_id := StringName(String(limit_variant))
        if definition.defensive_limit_ids.has(limit_id):
            return true
    return false


static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "action_id": &"",
    }
