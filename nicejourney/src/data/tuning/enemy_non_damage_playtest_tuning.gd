class_name EnemyNonDamagePlaytestTuning
extends Resource

# Reversible playtest values. Reinforcement ownership is separately bounded.
@export var playtest_placeholder: bool = true
@export_range(1.0, 1024.0, 0.1) var ward_range_px: float = 144.0
@export_range(0.0, 1000.0, 0.1) var ward_defense_bonus: float = 4.0
@export_range(1, 1800, 1) var ward_duration_ticks: int = 90
@export_range(1.0, 1024.0, 0.1) var control_cast_range_px: float = 180.0
@export_range(1.0, 1024.0, 0.1) var control_field_radius_px: float = 65.0
@export_range(1, 1800, 1) var control_field_duration_ticks: int = 120
@export_range(1, 300, 1) var control_slow_refresh_ticks: int = 6
@export_range(1, 300, 1) var control_slow_apply_interval_ticks: int = 5
@export var ward_marker_scene: PackedScene
@export var control_field_marker_scene: PackedScene
@export var reinforcement_tuning: SummonerReinforcementPlaytestTuning


func validate_tuning(status_tuning: StatusPlaytestTuning = null) -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("non-damage temporary tuning must be marked PLAYTEST")
    if not is_finite(ward_range_px) or ward_range_px <= 0.0 or not is_finite(ward_defense_bonus) or ward_defense_bonus <= 0.0 or ward_duration_ticks <= 0:
        errors.append("ward range/bonus/duration must be positive")
    if (
        not is_finite(control_cast_range_px) or control_cast_range_px <= 0.0
        or not is_finite(control_field_radius_px) or control_field_radius_px <= 0.0
        or control_field_duration_ticks <= 0 or control_slow_refresh_ticks <= 0
        or control_slow_apply_interval_ticks <= 0
        or control_slow_apply_interval_ticks > control_slow_refresh_ticks
    ):
        errors.append("control field range/radius/cadence/duration invalid")
    if ward_marker_scene == null or control_field_marker_scene == null:
        errors.append("both Godot-native placeholder scenes must be assigned")
    if status_tuning == null or not status_tuning.validate_tuning().is_empty():
        errors.append("the existing Burn/Slow tuning must be valid")
    if reinforcement_tuning == null or not reinforcement_tuning.validate_tuning().is_empty():
        errors.append("finite Summoner reinforcement tuning must be assigned and valid")
    return errors
