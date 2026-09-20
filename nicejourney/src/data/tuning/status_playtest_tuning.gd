class_name StatusPlaytestTuning
extends Resource

const BURN_ID: StringName = &"status:playtest_burn"
const SLOW_ID: StringName = &"status:playtest_slow"

# Deliberately provisional: never claim final production status authority.
@export var playtest_placeholder: bool = true
@export_range(1, 3600, 1) var burn_duration_ticks: int = 180
@export_range(1, 3600, 1) var burn_tick_interval_ticks: int = 30
@export_range(1, 10000, 1) var burn_damage_per_tick: int = 2
@export_range(1, 3600, 1) var slow_duration_ticks: int = 150
@export_range(0.0, 1.0, 0.01) var slow_reduction_fraction: float = 0.25
@export_range(0.01, 1.0, 0.01) var slow_speed_floor_multiplier: float = 0.4


func validate_tuning() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("status tuning must remain flagged provisional")
    if burn_duration_ticks <= 0 or burn_tick_interval_ticks <= 0 or burn_damage_per_tick <= 0 or burn_tick_interval_ticks > burn_duration_ticks:
        errors.append("Burn duration/cadence/damage invalid")
    if slow_duration_ticks <= 0 or not is_finite(slow_reduction_fraction) or slow_reduction_fraction < 0.0 or slow_reduction_fraction >= 1.0:
        errors.append("Slow duration/reduction invalid")
    if not is_finite(slow_speed_floor_multiplier) or slow_speed_floor_multiplier <= 0.0 or slow_speed_floor_multiplier > 1.0:
        errors.append("Slow speed clamp invalid")
    return errors


func application(behavior: StringName, source_id: StringName = &"") -> Dictionary:
    if not validate_tuning().is_empty():
        return {}
    if source_id != &"" and not StableId.is_valid(String(source_id)):
        return {}
    if behavior == PrototypeStatusResolver.BEHAVIOR_BURN:
        var burn_id := BURN_ID if source_id == &"" else StringName("%s/%s" % [String(BURN_ID), String(source_id)])
        return {"status_id": burn_id, "behavior": behavior, "magnitude": float(burn_damage_per_tick), "duration_ticks": burn_duration_ticks}
    if behavior == PrototypeStatusResolver.BEHAVIOR_SLOW:
        var slow_id := SLOW_ID if source_id == &"" else StringName("%s/%s" % [String(SLOW_ID), String(source_id)])
        return {"status_id": slow_id, "behavior": behavior, "magnitude": slow_reduction_fraction, "duration_ticks": slow_duration_ticks}
    return {}


func burn_damage_for_advance(state: Dictionary, elapsed_ticks: int) -> int:
    var status_id := String(state.get("status_id", &""))
    if (not validate_tuning().is_empty() or elapsed_ticks <= 0
        or (status_id != String(BURN_ID) and not status_id.begins_with("%s/" % String(BURN_ID)))
        or StringName(String(state.get("behavior", &""))) != PrototypeStatusResolver.BEHAVIOR_BURN):
        return 0
    var remaining := int(state.get("remaining_ticks", 0))
    if remaining <= 0 or remaining > burn_duration_ticks:
        return 0
    var elapsed_before := burn_duration_ticks - remaining
    var elapsed_after := elapsed_before + mini(elapsed_ticks, remaining)
    var events := floori(float(elapsed_after) / float(burn_tick_interval_ticks)) - floori(float(elapsed_before) / float(burn_tick_interval_ticks))
    var magnitude: Variant = state.get("magnitude", float(burn_damage_per_tick))
    if not (typeof(magnitude) == TYPE_FLOAT or typeof(magnitude) == TYPE_INT) or not is_finite(float(magnitude)) or float(magnitude) < 0.0:
        return 0
    return roundi(float(events) * minf(float(magnitude), 10000.0))


func slow_speed_multiplier(states: Array) -> float:
    if not validate_tuning().is_empty():
        return 1.0
    var strongest := 0.0
    for raw_state: Variant in states:
        if not raw_state is Dictionary:
            continue
        var state := raw_state as Dictionary
        if StringName(String(state.get("behavior", &""))) == PrototypeStatusResolver.BEHAVIOR_SLOW and int(state.get("remaining_ticks", 0)) > 0:
            var magnitude := float(state.get("magnitude", 0.0))
            if is_finite(magnitude):
                strongest = maxf(strongest, clampf(magnitude, 0.0, 1.0))
    return maxf(slow_speed_floor_multiplier, 1.0 - strongest)
