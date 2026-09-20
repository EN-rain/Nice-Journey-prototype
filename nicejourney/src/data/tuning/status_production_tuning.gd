class_name StatusProductionTuning
extends Resource

# Unassigned authoring template only. The shipped PLAYTEST resource does not
# instantiate this class and has no authority to mark its numbers final.
@export var approved_final_values: bool = false
@export var approval_reference_id: StringName = &""

@export var burn_source_identity_policy_id: StringName = &""
@export var burn_duration_ticks: int = -1
@export var burn_tick_interval_ticks: int = -1
@export var burn_damage_per_tick: int = -1
@export var burn_first_tick_policy_id: StringName = &""
@export var burn_reapplication_tick_phase_policy_id: StringName = &""
@export var burn_damage_domain_policy_id: StringName = &""
@export var burn_mitigation_policy_id: StringName = &""
@export var burn_cross_source_aggregation_policy_id: StringName = &""
@export var burn_encounter_handoff_policy_id: StringName = &""

@export var slow_source_identity_policy_id: StringName = &""
@export var slow_duration_ticks: int = -1
@export var slow_reduction_fraction: float = -1.0
@export var slow_speed_floor_multiplier: float = -1.0
@export var slow_movement_domains_policy_id: StringName = &""
@export var slow_cross_source_aggregation_policy_id: StringName = &""
@export var slow_encounter_handoff_policy_id: StringName = &""


func authoring_readiness(behavior: StringName) -> Dictionary:
    var missing := PackedStringArray()
    var errors := PackedStringArray()
    if not approved_final_values:
        missing.append("approved_final_values")
    if not StableId.is_valid(String(approval_reference_id)):
        missing.append("approval_reference_id")
    if behavior == PrototypeStatusResolver.BEHAVIOR_BURN:
        _require_policy(burn_source_identity_policy_id, "application_source_id", missing)
        _require_positive(burn_duration_ticks, "duration_ticks", missing)
        _require_positive(burn_tick_interval_ticks, "tick_interval_ticks", missing)
        _require_positive(burn_damage_per_tick, "damage_per_tick", missing)
        _require_policy(burn_first_tick_policy_id, "first_tick_timing", missing)
        _require_policy(burn_reapplication_tick_phase_policy_id, "tick_phase_when_same_source_refreshes", missing)
        _require_policy(burn_damage_domain_policy_id, "damage_domain", missing)
        _require_policy(burn_mitigation_policy_id, "mitigation_or_defense_interaction", missing)
        _require_policy(burn_cross_source_aggregation_policy_id, "cross_status_id_execution_aggregation_policy", missing)
        _require_policy(burn_encounter_handoff_policy_id, "encounter_handoff_policy", missing)
        if burn_duration_ticks > 0 and burn_tick_interval_ticks > burn_duration_ticks:
            errors.append("Burn tick interval must not exceed authored duration")
    elif behavior == PrototypeStatusResolver.BEHAVIOR_SLOW:
        _require_policy(slow_source_identity_policy_id, "application_source_id", missing)
        _require_positive(slow_duration_ticks, "duration_ticks", missing)
        if not is_finite(slow_reduction_fraction) or slow_reduction_fraction <= 0.0 or slow_reduction_fraction >= 1.0:
            missing.append("magnitude_semantics_percent_or_multiplier")
        if not is_finite(slow_speed_floor_multiplier) or slow_speed_floor_multiplier <= 0.0 or slow_speed_floor_multiplier > 1.0:
            missing.append("minimum_or_maximum_speed_clamp_policy")
        _require_policy(slow_movement_domains_policy_id, "affected_movement_domains", missing)
        _require_policy(slow_cross_source_aggregation_policy_id, "cross_status_id_aggregation_policy", missing)
        _require_policy(slow_encounter_handoff_policy_id, "encounter_handoff_policy", missing)
    else:
        errors.append("only Burn and Slow have approved prototype status behaviors")
    return {
        "authoring_ready": missing.is_empty() and errors.is_empty(),
        "missing_fields": missing,
        "validation_errors": errors,
        "behavior": behavior,
    }


static func _require_positive(value: int, field: String, missing: PackedStringArray) -> void:
    if value <= 0:
        missing.append(field)


static func _require_policy(value: StringName, field: String, missing: PackedStringArray) -> void:
    if not StableId.is_valid(String(value)):
        missing.append(field)
