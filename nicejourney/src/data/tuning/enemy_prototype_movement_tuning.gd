class_name EnemyPrototypeMovementTuning
extends Resource

# Reversible first-pass movement values for the reusable prototype residents.
# They execute already-selected tactics; they do not change perception, utility,
# action legality, room geometry, or encounter content.
@export_range(1.0, 1000.0, 1.0) var move_speed_px_per_second: float = 72.0
@export_range(1.0, 512.0, 1.0) var withdraw_probe_distance_px: float = 160.0
@export_range(0.5, 64.0, 0.5) var path_desired_distance_px: float = 4.0
@export_range(0.5, 128.0, 0.5) var target_desired_distance_px: float = 8.0

func validate_tuning() -> PackedStringArray:
    var errors := PackedStringArray()
    for value: float in [move_speed_px_per_second, withdraw_probe_distance_px, path_desired_distance_px, target_desired_distance_px]:
        if not is_finite(value) or value <= 0.0:
            errors.append("prototype enemy movement values must be finite and positive")
            break
    return errors
