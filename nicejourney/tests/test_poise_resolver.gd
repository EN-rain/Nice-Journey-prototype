extends SceneTree

var _failures: int = 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_accumulation_and_threshold_reset()
	_test_interruptibility()
	_test_recovery()
	_test_malformed_inputs()
	_test_determinism_and_nonmutation()

	if _failures == 0:
		print("POISE RESOLVER TEST PASS")
	else:
		push_error("POISE RESOLVER TEST FAILURES: %d" % _failures)
	quit(_failures)


func _test_accumulation_and_threshold_reset() -> void:
	var state: Dictionary = _base_state()
	var hit: Dictionary = {"poise_damage": 4.0}
	var below: Dictionary = PoiseResolver.apply_hit(state, hit)
	_expect(below["accepted"] and below["outcome"] == PoiseResolver.OUTCOME_ACCUMULATED, "poise below threshold accumulates")
	_expect(is_equal_approx(below["accumulated_poise"], 4.0) and not below["threshold_reached"], "sub-threshold hit preserves accumulated poise without a threshold event")
	_expect(not below["interruption_recovery_requested"], "sub-threshold hit does not request interruption/recovery")

	state["accumulated_poise"] = 6.0
	hit["poise_damage"] = 4.0
	var exact: Dictionary = PoiseResolver.apply_hit(state, hit)
	_expect(exact["outcome"] == PoiseResolver.OUTCOME_THRESHOLD_REACHED and exact["threshold_reached"], "exact threshold contact triggers the poise threshold")
	_expect(is_equal_approx(exact["accumulated_poise"], 0.0), "reaching threshold resets accumulated poise")
	_expect(exact["interruption_recovery_requested"], "interruptible state requests authored interruption/recovery when threshold is reached")

	state["accumulated_poise"] = 9.0
	hit["poise_damage"] = 50.0
	var overflow: Dictionary = PoiseResolver.apply_hit(state, hit)
	_expect(overflow["threshold_reached"] and is_equal_approx(overflow["accumulated_poise"], 0.0), "poise overflow resets rather than carrying excess into a hidden second threshold")

	hit["poise_damage"] = 0.0
	state["accumulated_poise"] = 3.0
	var zero: Dictionary = PoiseResolver.apply_hit(state, hit)
	_expect(zero["outcome"] == PoiseResolver.OUTCOME_ACCUMULATED and is_equal_approx(zero["accumulated_poise"], 3.0), "zero authored poise damage is a valid no-op")


func _test_interruptibility() -> void:
	var state: Dictionary = _base_state()
	state["accumulated_poise"] = 8.0
	state["interruptible"] = false
	var result: Dictionary = PoiseResolver.apply_hit(state, {"poise_damage": 2.0})
	_expect(result["threshold_reached"], "uninterruptible state still reaches and consumes its poise threshold")
	_expect(is_equal_approx(result["accumulated_poise"], 0.0), "uninterruptible threshold event still resets accumulated poise")
	_expect(not result["interruption_recovery_requested"], "uninterruptible state does not request authored interruption/recovery")


func _test_recovery() -> void:
	var state: Dictionary = _base_state()
	state["accumulated_poise"] = 7.0

	var blocked: Dictionary = PoiseResolver.recover(state, {
		"recovery_allowed": false,
		"recovery_amount": 3.0,
	})
	_expect(blocked["accepted"] and blocked["outcome"] == PoiseResolver.OUTCOME_RECOVERY_BLOCKED, "caller-resolved recovery delay can block poise recovery")
	_expect(is_equal_approx(blocked["accumulated_poise"], 7.0), "blocked recovery leaves accumulated poise unchanged")

	var recovered: Dictionary = PoiseResolver.recover(state, {
		"recovery_allowed": true,
		"recovery_amount": 3.0,
	})
	_expect(recovered["outcome"] == PoiseResolver.OUTCOME_RECOVERED and is_equal_approx(recovered["accumulated_poise"], 4.0), "allowed authored recovery amount reduces accumulated poise")

	var clamped: Dictionary = PoiseResolver.recover(state, {
		"recovery_allowed": true,
		"recovery_amount": 100.0,
	})
	_expect(is_equal_approx(clamped["accumulated_poise"], 0.0), "poise recovery clamps at zero")
	_expect(not clamped["threshold_reached"] and not clamped["interruption_recovery_requested"], "recovery cannot create a poise threshold event")


func _test_malformed_inputs() -> void:
	var state: Dictionary = _base_state()
	var hit: Dictionary = {"poise_damage": 1.0}
	_expect(not PoiseResolver.apply_hit(null, hit)["accepted"], "non-dictionary poise state is rejected")
	_expect(not PoiseResolver.apply_hit(state, null)["accepted"], "non-dictionary poise hit is rejected")

	var missing_threshold: Dictionary = state.duplicate(true)
	missing_threshold.erase("threshold")
	_expect(not PoiseResolver.apply_hit(missing_threshold, hit)["accepted"], "missing threshold is rejected")

	var bad_interruptible: Dictionary = state.duplicate(true)
	bad_interruptible["interruptible"] = 1
	_expect(not PoiseResolver.apply_hit(bad_interruptible, hit)["accepted"], "non-boolean interruptible state is rejected")

	var at_threshold: Dictionary = state.duplicate(true)
	at_threshold["accumulated_poise"] = at_threshold["threshold"]
	_expect(not PoiseResolver.apply_hit(at_threshold, hit)["accepted"], "externally supplied accumulated poise at threshold is rejected because canonical threshold state resets immediately")

	var over_threshold: Dictionary = state.duplicate(true)
	over_threshold["accumulated_poise"] = 11.0
	_expect(not PoiseResolver.apply_hit(over_threshold, hit)["accepted"], "externally supplied accumulated poise above threshold is rejected")

	var zero_threshold: Dictionary = state.duplicate(true)
	zero_threshold["threshold"] = 0.0
	_expect(not PoiseResolver.apply_hit(zero_threshold, hit)["accepted"], "non-positive poise threshold is rejected")

	var negative_hit: Dictionary = {"poise_damage": -1.0}
	_expect(not PoiseResolver.apply_hit(state, negative_hit)["accepted"], "negative poise damage is rejected")

	for key: String in ["accumulated_poise", "threshold"]:
		for value: float in [NAN, INF, -INF]:
			var invalid_state: Dictionary = state.duplicate(true)
			invalid_state[key] = value
			_expect(not PoiseResolver.apply_hit(invalid_state, hit)["accepted"], "nonfinite poise state numeric %s is rejected" % key)
	for value: float in [NAN, INF, -INF]:
		_expect(not PoiseResolver.apply_hit(state, {"poise_damage": value})["accepted"], "nonfinite poise damage is rejected")

	_expect(not PoiseResolver.recover(state, null)["accepted"], "non-dictionary recovery request is rejected")
	_expect(not PoiseResolver.recover(state, {"recovery_allowed": 1, "recovery_amount": 1.0})["accepted"], "non-boolean recovery permission is rejected")
	_expect(not PoiseResolver.recover(state, {"recovery_allowed": true, "recovery_amount": -1.0})["accepted"], "negative recovery amount is rejected")
	for value: float in [NAN, INF, -INF]:
		_expect(not PoiseResolver.recover(state, {"recovery_allowed": true, "recovery_amount": value})["accepted"], "nonfinite recovery amount is rejected")

	var huge_state: Dictionary = _base_state()
	huge_state["threshold"] = 1.0e308
	huge_state["accumulated_poise"] = 9.0e307
	var huge_hit: Dictionary = {"poise_damage": 9.0e307}
	var overflow_result: Dictionary = PoiseResolver.apply_hit(huge_state, huge_hit)
	_expect(not overflow_result["accepted"] and overflow_result["reason_id"] == PoiseResolver.REASON_NONFINITE_RESULT, "overflowing poise accumulation rejects instead of producing nonfinite state")


func _test_determinism_and_nonmutation() -> void:
	var state: Dictionary = _base_state()
	state["accumulated_poise"] = 2.0
	var hit: Dictionary = {"poise_damage": 3.0}
	var state_before: Dictionary = state.duplicate(true)
	var hit_before: Dictionary = hit.duplicate(true)

	var first: Dictionary = PoiseResolver.apply_hit(state, hit)
	var second: Dictionary = PoiseResolver.apply_hit(state, hit)
	_expect(first == second, "identical poise inputs resolve deterministically")
	_expect(state == state_before and hit == hit_before, "poise resolution does not mutate caller dictionaries")

	first["accumulated_poise"] = 999.0
	var third: Dictionary = PoiseResolver.apply_hit(state, hit)
	_expect(third == second, "mutating a returned poise result cannot affect later resolution")

	var recovery: Dictionary = {"recovery_allowed": true, "recovery_amount": 1.0}
	var recovery_before: Dictionary = recovery.duplicate(true)
	PoiseResolver.recover(state, recovery)
	_expect(recovery == recovery_before and state == state_before, "poise recovery does not mutate caller data")


func _base_state() -> Dictionary:
	return {
		"accumulated_poise": 0.0,
		"threshold": 10.0,
		"interruptible": true,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)
