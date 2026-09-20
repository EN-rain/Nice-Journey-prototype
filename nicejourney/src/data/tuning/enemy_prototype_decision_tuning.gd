class_name EnemyPrototypeDecisionTuning
extends Resource

@export_range(1, 120, 1) var evaluation_interval_ticks: int = 6
@export_range(0, 120, 1) var reaction_delay_ticks: int = 12
@export_range(1, 600, 1) var observation_lifetime_ticks: int = 90
@export_range(0.0, 1.0, 0.001) var confidence_decay_per_tick: float = 0.005
@export_range(16.0, 1024.0, 1.0) var close_range_px: float = 96.0
@export_range(16.0, 2048.0, 1.0) var mid_range_px: float = 224.0
@export_range(1, 8, 1) var signature_repeat_limit: int = 2
@export_range(1, 16, 1) var signature_suppression_evaluations: int = 1

func validate_tuning() -> PackedStringArray:
    var errors := PackedStringArray()
    if evaluation_interval_ticks <= 0:
        errors.append("evaluation_interval_ticks must be positive")
    if reaction_delay_ticks < 0:
        errors.append("reaction_delay_ticks cannot be negative")
    if observation_lifetime_ticks <= reaction_delay_ticks:
        errors.append("observation_lifetime_ticks must exceed reaction_delay_ticks")
    if not is_finite(confidence_decay_per_tick) or confidence_decay_per_tick < 0.0:
        errors.append("confidence_decay_per_tick must be finite and nonnegative")
    if not is_finite(close_range_px) or not is_finite(mid_range_px) or close_range_px <= 0.0 or mid_range_px <= close_range_px:
        errors.append("distance bands must be finite, positive and strictly ordered")
    if signature_repeat_limit <= 0 or signature_suppression_evaluations <= 0:
        errors.append("signature repeat suppression tuning must be positive")
    return errors
