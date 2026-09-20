class_name PrototypeStatusProductionAuthority
extends RefCounted

const _BURN_MISSING = [
    "application_source_id",
    "duration_ticks",
    "magnitude_semantics",
    "tick_interval_ticks",
    "first_tick_timing",
    "damage_per_tick",
    "damage_domain",
    "mitigation_or_defense_interaction",
    "cross_status_id_execution_aggregation_policy",
    "encounter_handoff_policy",
]

const _SLOW_MISSING = [
    "application_source_id",
    "duration_ticks",
    "magnitude_semantics_percent_or_multiplier",
    "affected_movement_domains",
    "cross_status_id_aggregation_policy",
    "minimum_or_maximum_speed_clamp_policy",
    "encounter_handoff_policy",
]


static func readiness(behavior: StringName, authored: StatusProductionTuning = null) -> Dictionary:
    var base := _baseline_readiness(behavior)
    if authored == null or not bool(base.get("accepted", false)):
        return base
    var authoring := authored.authoring_readiness(behavior)
    base["authoring_ready"] = bool(authoring.get("authoring_ready", false))
    base["authoring_missing_fields"] = (authoring.get("missing_fields", PackedStringArray()) as PackedStringArray).duplicate()
    base["authoring_validation_errors"] = (authoring.get("validation_errors", PackedStringArray()) as PackedStringArray).duplicate()
    if bool(base["authoring_ready"]):
        base["missing_authoritative_fields"] = PackedStringArray(["production_execution_owner"])
    # This is an Inspector-authoring route; a production execution owner must
    # consume the exact approved payload before production_ready can be true.
    base["production_ready"] = false
    return base


static func _baseline_readiness(behavior: StringName) -> Dictionary:
    if behavior == PrototypeStatusResolver.BEHAVIOR_BURN:
        return {
            "accepted": true,
            "behavior": behavior,
            "production_ready": false,
            "known_semantics": {
                "damage_over_time": true,
                "duration_unit": &"fixed_ticks",
                "reapplication_magnitude_policy": &"strongest",
                "reapplication_duration_policy": &"greatest_remaining_or_new_duration",
                "same_status_never_sums_magnitude": true,
                "different_status_ids_may_coexist": true,
                "can_crit": false,
                "can_weak_point": false,
                "safe_snapshot_duration_supported": true,
            },
            "missing_authoritative_fields": PackedStringArray(_BURN_MISSING),
        }
    if behavior == PrototypeStatusResolver.BEHAVIOR_SLOW:
        return {
            "accepted": true,
            "behavior": behavior,
            "production_ready": false,
            "known_semantics": {
                "movement_speed_reduction_only": true,
                "duration_unit": &"fixed_ticks",
                "affects_action_clocks": false,
                "affects_ai_reaction_timing": false,
                "reapplication_magnitude_policy": &"strongest",
                "reapplication_duration_policy": &"greatest_remaining_or_new_duration",
                "same_status_never_sums_magnitude": true,
                "different_status_ids_may_coexist": true,
                "safe_snapshot_duration_supported": true,
            },
            "missing_authoritative_fields": PackedStringArray(_SLOW_MISSING),
        }
    return {
        "accepted": false,
        "behavior": behavior,
        "production_ready": false,
        "known_semantics": {},
        "missing_authoritative_fields": PackedStringArray(),
    }
