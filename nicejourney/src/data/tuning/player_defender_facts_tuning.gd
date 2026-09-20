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
