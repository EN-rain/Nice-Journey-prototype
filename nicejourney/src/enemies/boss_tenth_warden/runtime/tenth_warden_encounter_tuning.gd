class_name TenthWardenEncounterTuning
extends Resource

@export_range(0.01, 0.99, 0.01) var phase_transition_health_ratio: float = 0.50

func validate_tuning() -> PackedStringArray:
    var errors := PackedStringArray()
    if not is_finite(phase_transition_health_ratio):
        errors.append("phase_transition_health_ratio must be finite")
    elif phase_transition_health_ratio <= 0.0 or phase_transition_health_ratio >= 1.0:
        errors.append("phase_transition_health_ratio must be between 0 and 1")
    return errors
