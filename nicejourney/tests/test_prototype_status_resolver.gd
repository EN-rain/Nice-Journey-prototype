extends SceneTree

var _failures: int = 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_new_status_and_reapplication_rules()
	_test_different_ids_coexist()
	_test_duration_advance_and_expiry()
	_test_behavior_contracts()
	_test_execution_boundary_keeps_magnitude_opaque()
	_test_peer_live_overlap_merge_contract()
	_test_state_normalization()
	_test_malformed_inputs()
	_test_determinism_and_nonmutation()

	if _failures == 0:
		print("PROTOTYPE STATUS RESOLVER TEST PASS")
	else:
		push_error("PROTOTYPE STATUS RESOLVER TEST FAILURES: %d" % _failures)
	quit(_failures)


func _test_new_status_and_reapplication_rules() -> void:
	var applied: Dictionary = PrototypeStatusResolver.apply_status([], _application(&"burn_weapon", &"burn", 3.0, 120))
	_expect(applied["accepted"] and applied["outcome"] == PrototypeStatusResolver.OUTCOME_APPLIED, "new Burn status is admitted")
	_expect(applied["states"].size() == 1, "new status creates exactly one active state")
	var initial: Dictionary = applied["states"][0]
	_expect(initial["status_id"] == &"burn_weapon" and initial["behavior"] == PrototypeStatusResolver.BEHAVIOR_BURN, "status preserves stable ID and approved Burn behavior")
	_expect(is_equal_approx(initial["magnitude"], 3.0) and initial["remaining_ticks"] == 120, "status preserves authored magnitude and duration")

	var stronger_shorter: Dictionary = PrototypeStatusResolver.apply_status(applied["states"], _application(&"burn_weapon", &"burn", 5.0, 60))
	var merged_stronger: Dictionary = stronger_shorter["states"][0]
	_expect(stronger_shorter["outcome"] == PrototypeStatusResolver.OUTCOME_REAPPLIED, "same status ID is reapplied rather than stacked as another entry")
	_expect(is_equal_approx(merged_stronger["magnitude"], 5.0), "reapplication keeps the stronger magnitude")
	_expect(merged_stronger["remaining_ticks"] == 120, "shorter reapplication cannot shorten current remaining duration")

	var weaker_longer: Dictionary = PrototypeStatusResolver.apply_status(stronger_shorter["states"], _application(&"burn_weapon", &"burn", 2.0, 180))
	var merged_longer: Dictionary = weaker_longer["states"][0]
	_expect(is_equal_approx(merged_longer["magnitude"], 5.0), "weaker reapplication cannot reduce strongest active magnitude")
	_expect(merged_longer["remaining_ticks"] == 180, "reapplication refreshes remaining duration to the greater authored duration")
	_expect(weaker_longer["states"].size() == 1, "same status ID never sums by creating parallel copies")


func _test_different_ids_coexist() -> void:
	var states: Array = []
	states = PrototypeStatusResolver.apply_status(states, _application(&"burn_a", &"burn", 1.0, 30))["states"]
	states = PrototypeStatusResolver.apply_status(states, _application(&"burn_b", &"burn", 2.0, 40))["states"]
	states = PrototypeStatusResolver.apply_status(states, _application(&"slow_a", &"slow", 0.25, 50))["states"]
	_expect(states.size() == 3, "different status IDs may coexist even when two share the same approved behavior")
	_expect(states[0]["status_id"] == &"burn_a" and states[1]["status_id"] == &"burn_b" and states[2]["status_id"] == &"slow_a", "returned status state is deterministically ordered by stable ID")

	var mismatch: Dictionary = PrototypeStatusResolver.apply_status(states, _application(&"slow_a", &"burn", 9.0, 99))
	_expect(not mismatch["accepted"] and mismatch["reason_id"] == PrototypeStatusResolver.REASON_BEHAVIOR_MISMATCH, "one stable status ID cannot silently change from Slow to Burn")


func _test_duration_advance_and_expiry() -> void:
	var states: Array = [
		_state(&"burn_a", &"burn", 2.0, 2),
		_state(&"slow_a", &"slow", 0.3, 5),
	]
	var one_tick: Dictionary = PrototypeStatusResolver.advance_duration(states, 1)
	_expect(one_tick["accepted"] and one_tick["outcome"] == PrototypeStatusResolver.OUTCOME_ADVANCED, "status durations advance through an explicit deterministic tick count")
	_expect(one_tick["states"].size() == 2, "unexpired statuses remain active")
	_expect(one_tick["states"][0]["remaining_ticks"] == 1 and one_tick["states"][1]["remaining_ticks"] == 4, "duration advance decrements remaining ticks exactly")

	var expire_one: Dictionary = PrototypeStatusResolver.advance_duration(one_tick["states"], 1)
	_expect(expire_one["states"].size() == 1 and expire_one["states"][0]["status_id"] == &"slow_a", "status expires when remaining duration reaches zero")
	_expect(expire_one["states"][0]["remaining_ticks"] == 3, "other status durations continue independently")

	var zero_tick: Dictionary = PrototypeStatusResolver.advance_duration(expire_one["states"], 0)
	_expect(zero_tick["states"] == expire_one["states"], "advancing zero ticks is a deterministic no-op")

	var expire_all: Dictionary = PrototypeStatusResolver.advance_duration(expire_one["states"], 99)
	_expect(expire_all["states"].is_empty(), "elapsed duration beyond remaining time removes expired states without negative persisted duration")


func _test_behavior_contracts() -> void:
	var burn: Dictionary = PrototypeStatusResolver.behavior_contract(&"burn")
	_expect(burn["accepted"] and burn["damage_over_time"], "Burn is explicitly a damage-over-time behavior")
	_expect(not burn["can_crit"] and not burn["can_weak_point"], "Burn damage-over-time cannot crit or weak-point")
	_expect(not burn["affects_action_clocks"] and not burn["affects_ai_reaction_timing"], "Burn contract adds no hidden clock or AI timing behavior")

	var slow: Dictionary = PrototypeStatusResolver.behavior_contract(&"slow")
	_expect(slow["accepted"] and slow["movement_speed_reduction_only"], "Slow is explicitly movement-speed reduction only")
	_expect(not slow["damage_over_time"], "Slow does not become a damage-over-time effect")
	_expect(not slow["affects_action_clocks"] and not slow["affects_ai_reaction_timing"], "Slow cannot alter action clocks or AI reaction timing")

	var poison: Dictionary = PrototypeStatusResolver.behavior_contract(&"poison")
	_expect(not poison["accepted"] and poison["reason_id"] == PrototypeStatusResolver.REASON_INVALID_BEHAVIOR, "unapproved prototype status behavior is rejected")


func _test_execution_boundary_keeps_magnitude_opaque() -> void:
	var source_states: Array = [
		_state(&"burn:execution", &"burn", 7.5, 45),
		_state(&"slow:execution", &"slow", 0.37, 60),
	]
	var result := PrototypeStatusResolver.build_execution_requests(source_states)
	_expect(bool(result.get("accepted", false)), "supported active statuses produce parameterized execution requests")
	var requests := result.get("requests", []) as Array
	_expect(requests.size() == 2, "execution boundary emits one detached request per active status ID")
	var burn := requests[0] as Dictionary
	var slow := requests[1] as Dictionary
	_expect(bool(burn.get("damage_over_time", false)) and not bool(burn.get("can_crit", true)) and not bool(burn.get("can_weak_point", true)), "Burn execution request preserves locked damage-over-time and no-crit/no-weak-point rules")
	_expect(bool(slow.get("movement_speed_reduction_only", false)) and not bool(slow.get("affects_action_clocks", true)) and not bool(slow.get("affects_ai_reaction_timing", true)), "Slow execution request is movement-only and cannot alter action or AI clocks")
	_expect(is_equal_approx(float(burn.get("opaque_magnitude", -1.0)), 7.5) and is_equal_approx(float(slow.get("opaque_magnitude", -1.0)), 0.37), "execution boundary transports authored magnitude without interpreting its semantic meaning")
	_expect(not burn.has("damage_per_tick") and not burn.has("tick_interval") and not slow.has("speed_multiplier") and not slow.has("slow_percent"), "execution boundary does not invent Burn cadence/damage or Slow percentage/multiplier")
	_expect(not bool(burn.get("production_ready", true)) and (burn.get("production_missing_fields", PackedStringArray()) as PackedStringArray).has("tick_interval_ticks"), "Burn execution request exposes the missing cadence authority instead of executing opaque magnitude")
	_expect(not bool(slow.get("production_ready", true)) and (slow.get("production_missing_fields", PackedStringArray()) as PackedStringArray).has("magnitude_semantics_percent_or_multiplier"), "Slow execution request exposes unresolved movement-magnitude semantics")
	burn["remaining_ticks"] = 999
	_expect(int((source_states[0] as Dictionary).get("remaining_ticks", 0)) == 45, "execution request data is detached from authored state inputs")


func _test_peer_live_overlap_merge_contract() -> void:
	var merged := PrototypeStatusResolver.merge_peer_live_state_collections([
		[
			_state(&"burn:shared", &"burn", 2.0, 60),
		],
		[
			_state(&"burn:shared", &"burn", 3.0, 45),
			_state(&"slow:other", &"slow", 0.2, 75),
		],
	])
	_expect(bool(merged.get("accepted", false)), "peer live status collections can be normalized into one coherent set")
	var states := merged.get("states", []) as Array
	_expect(states.size() == 2, "overlap merge keeps one state per stable status ID while preserving different IDs")
	var burn := states[0] as Dictionary
	_expect(StringName(burn.get("status_id", &"")) == &"burn:shared" and is_equal_approx(float(burn.get("magnitude", 0.0)), 3.0) and int(burn.get("remaining_ticks", 0)) == 60, "same-ID peer states use strongest magnitude and greatest live remaining duration")
	var mismatch := PrototypeStatusResolver.merge_peer_live_state_collections([
		[_state(&"status:shared", &"burn", 1.0, 10)],
		[_state(&"status:shared", &"slow", 1.0, 10)],
	])
	_expect(not bool(mismatch.get("accepted", true)) and StringName(mismatch.get("reason_id", &"")) == PrototypeStatusResolver.REASON_BEHAVIOR_MISMATCH, "overlap coherence fails closed when one stable status ID changes behavior")


func _test_state_normalization() -> void:
	var raw_states: Array = [
		_state(&"slow_z", &"slow", 0.2, 30),
		_state(&"burn_a", &"burn", 2.0, 20),
	]
	var normalized: Dictionary = PrototypeStatusResolver.normalize_states(raw_states)
	_expect(bool(normalized.get("accepted", false)), "status runtime can validate an authored/restored state collection without applying a new status")
	var states := normalized.get("states", []) as Array
	_expect(states.size() == 2 and StringName((states[0] as Dictionary).get("status_id", &"")) == &"burn_a" and StringName((states[1] as Dictionary).get("status_id", &"")) == &"slow_z", "normalized status state uses deterministic stable-ID ordering")
	(states[0] as Dictionary)["remaining_ticks"] = 999
	_expect(int((raw_states[1] as Dictionary).get("remaining_ticks", 0)) == 20, "normalized status state is detached from caller-owned restore data")


func _test_malformed_inputs() -> void:
	var app: Dictionary = _application(&"burn_a", &"burn", 1.0, 10)
	_expect(not PrototypeStatusResolver.apply_status(null, app)["accepted"], "non-array active state collection is rejected")
	_expect(not PrototypeStatusResolver.apply_status([], null)["accepted"], "non-dictionary status application is rejected")

	var invalid_id: Dictionary = app.duplicate(true)
	invalid_id["status_id"] = " bad id "
	_expect(not PrototypeStatusResolver.apply_status([], invalid_id)["accepted"], "malformed stable status ID is rejected")

	var invalid_behavior: Dictionary = app.duplicate(true)
	invalid_behavior["behavior"] = &"poison"
	_expect(not PrototypeStatusResolver.apply_status([], invalid_behavior)["accepted"], "behavior outside Burn/Slow is rejected")

	var negative_magnitude: Dictionary = app.duplicate(true)
	negative_magnitude["magnitude"] = -0.01
	_expect(not PrototypeStatusResolver.apply_status([], negative_magnitude)["accepted"], "negative status magnitude is rejected")
	for value: float in [NAN, INF, -INF]:
		var nonfinite: Dictionary = app.duplicate(true)
		nonfinite["magnitude"] = value
		_expect(not PrototypeStatusResolver.apply_status([], nonfinite)["accepted"], "nonfinite status magnitude is rejected")

	var zero_duration: Dictionary = app.duplicate(true)
	zero_duration["duration_ticks"] = 0
	_expect(not PrototypeStatusResolver.apply_status([], zero_duration)["accepted"], "active status application requires positive authored duration")
	var float_duration: Dictionary = app.duplicate(true)
	float_duration["duration_ticks"] = 10.0
	_expect(not PrototypeStatusResolver.apply_status([], float_duration)["accepted"], "status duration ticks must be an integer")

	var malformed_state: Array = [_state(&"burn_a", &"burn", 1.0, 10)]
	malformed_state[0]["remaining_ticks"] = 0
	_expect(not PrototypeStatusResolver.apply_status(malformed_state, app)["accepted"], "active state with non-positive remaining duration is rejected")

	var duplicate_states: Array = [
		_state(&"burn_a", &"burn", 1.0, 10),
		_state(&"burn_a", &"burn", 2.0, 20),
	]
	var duplicate_result: Dictionary = PrototypeStatusResolver.apply_status(duplicate_states, app)
	_expect(not duplicate_result["accepted"] and duplicate_result["reason_id"] == PrototypeStatusResolver.REASON_DUPLICATE_STATUS_ID, "duplicate active status IDs are rejected instead of silently pre-stacking")

	_expect(not PrototypeStatusResolver.advance_duration([], -1)["accepted"], "negative elapsed ticks are rejected")
	_expect(not PrototypeStatusResolver.advance_duration([], 1.0)["accepted"], "elapsed ticks must be an integer")


func _test_determinism_and_nonmutation() -> void:
	var states: Array = [
		_state(&"slow_z", &"slow", 0.2, 30),
		_state(&"burn_a", &"burn", 2.0, 20),
	]
	var application: Dictionary = _application(&"burn_a", &"burn", 3.0, 40)
	var states_before: Array = states.duplicate(true)
	var application_before: Dictionary = application.duplicate(true)

	var first: Dictionary = PrototypeStatusResolver.apply_status(states, application)
	var second: Dictionary = PrototypeStatusResolver.apply_status(states, application)
	_expect(first == second, "identical status inputs resolve deterministically")
	_expect(states == states_before and application == application_before, "status application does not mutate caller state or application")

	first["states"][0]["magnitude"] = 999.0
	var third: Dictionary = PrototypeStatusResolver.apply_status(states, application)
	_expect(third == second, "mutating returned status state cannot affect later resolution or caller data")

	var advanced: Dictionary = PrototypeStatusResolver.advance_duration(states, 1)
	advanced["states"][0]["remaining_ticks"] = 999
	_expect(states == states_before, "duration advancement returns detached status state")


func _application(status_id: StringName, behavior: StringName, magnitude: float, duration_ticks: int) -> Dictionary:
	return {
		"status_id": status_id,
		"behavior": behavior,
		"magnitude": magnitude,
		"duration_ticks": duration_ticks,
	}


func _state(status_id: StringName, behavior: StringName, magnitude: float, remaining_ticks: int) -> Dictionary:
	return {
		"status_id": status_id,
		"behavior": behavior,
		"magnitude": magnitude,
		"remaining_ticks": remaining_ticks,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)
