class_name PlayerDefenderFactsTuning
extends Resource

# Shared player-defense authority used by live enemy/boss contact delivery.
# Values stay fail-closed until explicitly authored; movement/animation timing
# must not be treated as implicit invulnerability or coverage authority.
@export var authored: bool = false
@export var playtest_placeholder: bool = false
@export_range(0.0, 10.0, 0.001) var dodge_invulnerability_start_seconds: float = 0.0
@export_range(0.0, 10.0, 0.001) var dodge_invulnerability_duration_seconds: float = 0.0
@export_range(0.0, 180.0, 0.1) var frontal_coverage_degrees: float = 0.0

@export_category("Final defense approval — leave empty for PLAYTEST")
@export var approved_final_values: bool = false
@export var approval_reference_id: StringName = &""
@export var manual_fairness_evidence_id: StringName = &""


func validate_tuning(movement_tuning: MovementTuning = null) -> PackedStringArray:
    var errors := PackedStringArray()
    if not authored:
        errors.append("player defender-facts tuning is not authored")
        return errors

    for entry: Array in [
        ["dodge_invulnerability_start_seconds", dodge_invulnerability_start_seconds],
        ["dodge_invulnerability_duration_seconds", dodge_invulnerability_duration_seconds],
        ["frontal_coverage_degrees", frontal_coverage_degrees],
    ]:
        if not is_finite(float(entry[1])):
            errors.append("%s must be finite" % String(entry[0]))

    if dodge_invulnerability_start_seconds < 0.0:
        errors.append("dodge_invulnerability_start_seconds cannot be negative")
    if dodge_invulnerability_duration_seconds <= 0.0:
        errors.append("dodge_invulnerability_duration_seconds must be positive")
    if frontal_coverage_degrees <= 0.0 or frontal_coverage_degrees > 180.0:
        errors.append("frontal_coverage_degrees must be greater than 0 and at most 180")

    if movement_tuning != null:
        if not is_finite(movement_tuning.dodge_duration) or movement_tuning.dodge_duration <= 0.0:
            errors.append("movement dodge_duration must be finite and positive")
        elif dodge_invulnerability_start_seconds + dodge_invulnerability_duration_seconds > movement_tuning.dodge_duration + 0.000001:
            errors.append("dodge invulnerability interval must fit inside authored dodge movement duration")

    return errors


func production_readiness(
    movement_tuning: MovementTuning = null,
    starter_tuning: StarterCombatTuning = null
) -> Dictionary:
    # The runtime may execute provisional dodge/block/parry values, but only
    # explicitly approved tuning with observed player-contact evidence may be
    # described as production-ready. Do not infer fairness from a green test.
    var errors := validate_tuning(movement_tuning)
    var missing := PackedStringArray()
    if playtest_placeholder:
        missing.append("playtest_placeholder")
    if not approved_final_values:
        missing.append("approved_final_values")
    if not StableId.is_valid(String(approval_reference_id)):
        missing.append("approval_reference_id")
    if not StableId.is_valid(String(manual_fairness_evidence_id)):
        missing.append("manual_fairness_evidence_id")
    if movement_tuning == null:
        missing.append("movement_tuning_for_dodge_interval")
    if starter_tuning == null:
        missing.append("starter_combat_tuning_for_parry_window_and_recovery")
    else:
        for error: String in starter_tuning.validate_tuning():
            errors.append("starter combat: %s" % error)
    return {
        "production_ready": missing.is_empty() and errors.is_empty(),
        "missing_fields": missing,
        "validation_errors": errors,
    }
