class_name StatusEffectsPlaytestTuning
extends Resource

# Executable playtest semantics; not final DR-06 production status authority.
@export var playtest_placeholder: bool = true
@export_range(1, 36000, 1) var burn_duration_ticks: int = 180
@export_range(1, 36000, 1) var burn_tick_interval_ticks: int = 60
@export_range(0.0, 10000.0, 0.1) var burn_damage_per_tick: float = 3.0
@export_range(1, 36000, 1) var slow_duration_ticks: int = 150
@export_range(0.0, 1.0, 0.01) var slow_speed_reduction: float = 0.25
@export_range(0.0, 1.0, 0.01) var minimum_speed_multiplier: float = 0.6


func validate_tuning() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("provisional status values must retain playtest_placeholder")
    if burn_duration_ticks <= 0 or burn_tick_interval_ticks <= 0 or burn_tick_interval_ticks > burn_duration_ticks:
        errors.append("Burn duration and tick interval must be positive and ordered")
    if not is_finite(burn_damage_per_tick) or burn_damage_per_tick < 0.0:
        errors.append("Burn damage must be finite and nonnegative")
    if slow_duration_ticks <= 0 or not is_finite(slow_speed_reduction) or slow_speed_reduction < 0.0 or slow_speed_reduction > 1.0:
        errors.append("Slow duration/reduction must be valid")
    if not is_finite(minimum_speed_multiplier) or minimum_speed_multiplier <= 0.0 or minimum_speed_multiplier > 1.0:
        errors.append("minimum speed multiplier must be within (0,1]")
    return errors


func application(status_id: StringName, behavior: StringName) -> Dictionary:
    if not validate_tuning().is_empty() or not StableId.is_valid(String(status_id)):
        return {}
    if behavior == PrototypeStatusResolver.BEHAVIOR_BURN:
        return {"status_id": status_id, "behavior": behavior, "duration_ticks": burn_duration_ticks, "magnitude": burn_damage_per_tick}
    if behavior == PrototypeStatusResolver.BEHAVIOR_SLOW:
        return {"status_id": status_id, "behavior": behavior, "duration_ticks": slow_duration_ticks, "magnitude": slow_speed_reduction}
    return {}


func advance_playtest(raw_states: Variant, elapsed_ticks: int) -> Dictionary:
    if not validate_tuning().is_empty() or elapsed_ticks < 0:
        return {"accepted": false, "reason_id": &"invalid_playtest_tuning"}
    var normalized := PrototypeStatusResolver.normalize_states(raw_states)
    if not bool(normalized.get("accepted", false)):
        return normalized
    var burn_damage := 0.0
    for raw_state: Variant in normalized["states"] as Array:
        var state := raw_state as Dictionary
        var remaining := int(state["remaining_ticks"])
        var magnitude := float(state["magnitude"])
        if state["behavior"] == PrototypeStatusResolver.BEHAVIOR_BURN:
            var elapsed_before := maxi(0, burn_duration_ticks - remaining)
            var elapsed_after := mini(burn_duration_ticks, elapsed_before + mini(remaining, elapsed_ticks))
            var ticks_due := maxi(0, floori(float(elapsed_after) / float(burn_tick_interval_ticks)) - floori(float(elapsed_before) / float(burn_tick_interval_ticks)))
            burn_damage += float(ticks_due) * magnitude
    var advanced := PrototypeStatusResolver.advance_duration(normalized["states"], elapsed_ticks)
    if not bool(advanced.get("accepted", false)):
        return advanced
    var strongest_slow := 0.0
    for raw_state: Variant in advanced["states"] as Array:
        var state := raw_state as Dictionary
        if state["behavior"] == PrototypeStatusResolver.BEHAVIOR_SLOW:
            strongest_slow = maxf(strongest_slow, float(state["magnitude"]))
    return {
        "accepted": true,
        "reason_id": &"",
        "states": (advanced["states"] as Array).duplicate(true),
        "burn_raw_damage": burn_damage,
        "burn_can_crit": false,
        "burn_can_weak_point": false,
        "slow_speed_multiplier": maxf(minimum_speed_multiplier, 1.0 - strongest_slow),
        "affects_action_clocks": false,
        "playtest_placeholder": true,
    }
