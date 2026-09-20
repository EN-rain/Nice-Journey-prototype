extends SceneTree

const TUNING: StatusPlaytestTuning = preload("res://src/data/tuning/status_effects_playtest_v01.tres")
const GENERATOR_SCRIPT: Script = preload("res://tools/create_status_playtest_tuning.gd")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _expect(TUNING != null and TUNING.playtest_placeholder and TUNING.validate_tuning().is_empty(), "shipped status tuning is valid and explicitly provisional")
    var generated: StatusPlaytestTuning = GENERATOR_SCRIPT.build_resource()
    _expect(
        generated.validate_tuning().is_empty()
        and generated.playtest_placeholder
        and generated.burn_duration_ticks == TUNING.burn_duration_ticks
        and generated.burn_tick_interval_ticks == TUNING.burn_tick_interval_ticks
        and generated.burn_damage_per_tick == TUNING.burn_damage_per_tick
        and generated.slow_duration_ticks == TUNING.slow_duration_ticks
        and is_equal_approx(generated.slow_reduction_fraction, TUNING.slow_reduction_fraction)
        and is_equal_approx(generated.slow_speed_floor_multiplier, TUNING.slow_speed_floor_multiplier),
        "generator reproduces the shipped Inspector class and all six provisional numeric fields without writing"
    )
    var burn := TUNING.application(PrototypeStatusResolver.BEHAVIOR_BURN)
    var slow := TUNING.application(PrototypeStatusResolver.BEHAVIOR_SLOW)
    _expect(burn.get("status_id", &"") == TUNING.BURN_ID and slow.get("status_id", &"") == TUNING.SLOW_ID, "temporary Burn/Slow use separate stable status identities")
    var applied := PrototypeStatusResolver.apply_status([], burn)
    _expect(bool(applied.get("accepted", false)) and (applied.get("states", []) as Array).size() == 1, "Burn uses the shared status-state normalization")
    var reapply := PrototypeStatusResolver.apply_status(applied.get("states", []), {
        "status_id": TUNING.BURN_ID,
        "behavior": PrototypeStatusResolver.BEHAVIOR_BURN,
        "magnitude": 5.0,
        "duration_ticks": 150,
    })
    var reapply_state := (reapply.get("states", []) as Array)[0] as Dictionary
    _expect(bool(reapply.get("accepted", false)) and (reapply.get("states", []) as Array).size() == 1 and is_equal_approx(float(reapply_state["magnitude"]), 5.0) and int(reapply_state["remaining_ticks"]) == 180, "reapplication retains a single status, stronger magnitude and longer remaining duration")
    _expect(TUNING.burn_damage_for_advance({"status_id": TUNING.BURN_ID, "behavior": &"burn", "remaining_ticks": 180, "magnitude": 5.0}, 30) == 5, "reapplied stronger Burn magnitude changes the next tick without inventing extra status IDs")
    _expect(TUNING.burn_damage_for_advance({"status_id": TUNING.BURN_ID, "behavior": &"burn", "remaining_ticks": 180}, 29) == 0, "Burn does not apply before its first 30-tick deadline")
    _expect(TUNING.burn_damage_for_advance({"status_id": TUNING.BURN_ID, "behavior": &"burn", "remaining_ticks": 180}, 30) == 2, "Burn delivers only one explicitly authored damage tick at the first deadline")
    _expect(TUNING.burn_damage_for_advance({"status_id": TUNING.BURN_ID, "behavior": &"burn", "remaining_ticks": 151}, 61) == 6, "Burn crosses multiple cadence boundaries deterministically")
    _expect(TUNING.burn_damage_for_advance({"status_id": &"status:not_our_burn", "behavior": &"burn", "remaining_ticks": 180}, 30) == 0, "playtest damage owner never claims unrelated Burn statuses")
    _expect(TUNING.burn_damage_for_advance({"status_id": &"status:playtest_burn/", "behavior": &"burn", "remaining_ticks": 180}, 30) == 0, "blank source suffix is not an eligible Burn source")
    _expect(TUNING.burn_damage_for_advance({"status_id": &"status:playtest_burn/bad source", "behavior": &"burn", "remaining_ticks": 180}, 30) == 0, "malformed source suffix cannot acquire Burn damage")
    _expect(TUNING.burn_damage_for_advance({"status_id": TUNING.BURN_ID, "behavior": &"burn", "remaining_ticks": 180.0}, 30) == 0, "malformed fractional remaining duration cannot execute Burn")
    _expect(TUNING.burn_damage_for_advance({"status_id": TUNING.BURN_ID, "behavior": &"burn", "remaining_ticks": 180, "magnitude": 10001.0}, 30) == 10001, "strongest same-source Burn damage is not silently truncated to a base tuning cap")
    _expect(TUNING.burn_damage_for_advance({"status_id": TUNING.BURN_ID, "behavior": &"burn", "remaining_ticks": 180, "magnitude": INF}, 30) == 0, "nonfinite Burn magnitude cannot mutate live HP")
    _expect(TUNING.burn_damage_for_advance({"status_id": TUNING.BURN_ID, "behavior": &"burn", "remaining_ticks": 360, "magnitude": 3.0}, 30) == 3, "longer same-ID authored duration keeps Burn ticking above the default playtest lifetime")
    _expect(TUNING.slow_speed_multiplier([{"behavior": &"slow", "remaining_ticks": "10", "magnitude": 0.9}]) == 1.0, "malformed Slow duration cannot alter movement")
    _expect(is_equal_approx(TUNING.slow_speed_multiplier([{"behavior": &"slow", "remaining_ticks": 10, "magnitude": 0.25}, {"behavior": &"slow", "remaining_ticks": 10, "magnitude": 0.9}]), 0.4), "Slow uses strongest reduction with authored minimum speed")
    _expect(TUNING.slow_speed_multiplier([]) == 1.0 and TUNING.slow_speed_multiplier([{"behavior": &"slow", "remaining_ticks": 0, "magnitude": 0.9}]) == 1.0, "inactive Slow cannot apply a stale movement penalty")
    _expect(TUNING.slow_speed_multiplier([{"behavior": &"slow", "remaining_ticks": 10, "magnitude": "invalid"}]) == 1.0, "malformed Slow magnitude cannot alter movement")
    _expect(TUNING.slow_speed_multiplier([{"behavior": &"slow", "remaining_ticks": 10, "magnitude": 1.25}]) == 1.0, "out-of-range Slow magnitude is rejected instead of silently clamped")
    _expect(not bool(PrototypeStatusProductionAuthority.readiness(PrototypeStatusResolver.BEHAVIOR_BURN).get("production_ready", true)) and not bool(PrototypeStatusProductionAuthority.readiness(PrototypeStatusResolver.BEHAVIOR_SLOW).get("production_ready", true)), "provisional numbers do not impersonate final DR-06 production authority")

    if _failures == 0:
        print("STATUS EFFECTS PLAYTEST TEST PASS")
    else:
        push_error("STATUS EFFECTS PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, description: String) -> void:
    if ok:
        print("PASS: %s" % description)
        return
    _failures += 1
    push_error("FAIL: %s" % description)
