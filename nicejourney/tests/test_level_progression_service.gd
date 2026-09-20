extends SceneTree

const DEFAULT_THRESHOLDS: LevelThresholdTuning = preload("res://src/progression/leveling/level_threshold_default.tres")

var _failures: int = 0
var _atomic_call_count: int = 0
var _captured_prepared: Dictionary = {}


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_plans_both_xp_storage_semantics()
    _test_exact_boundary_for_each_transition()
    _test_cap_overflow_is_policy_driven_without_level_11()
    _test_multi_level_award_aggregates_each_transition_once()
    _test_invalid_or_missing_policy_fails_closed()
    _test_atomic_commit_receipt_boundary()

    if _failures == 0:
        print("LEVEL PROGRESSION SERVICE TEST PASS")
    else:
        push_error("LEVEL PROGRESSION SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_plans_both_xp_storage_semantics() -> void:
    var cumulative_profile := ProfileCreationService.create_profile(1, "Cumulative XP", "melee")
    var cumulative_policy := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL,
        LevelProgressionPolicy.CAP_OVERFLOW_DISCARD
    )
    var stats := {"hp": 100.0, "stamina": 50.0}
    cumulative_profile.automatic_stats = stats.duplicate(true)
    var before_profile := cumulative_profile.to_dictionary()
    var plan := LevelProgressionService.plan_award(
        cumulative_profile,
        stats,
        350,
        &"xp_claim:test:cumulative",
        &"xp_source:test",
        cumulative_policy
    )
    _expect(bool(plan.get("accepted", false)), "complete cumulative-total policy produces a progression plan")
    _expect(int(plan.get("to_level", 0)) == 3 and int(plan.get("levels_gained", 0)) == 2, "350 authored XP crosses the fixed Level 1->2 and Level 2->3 thresholds")
    _expect(int(plan.get("to_xp", -1)) == 350, "cumulative-total policy stores the authored award as cumulative XP")
    _expect(int(plan.get("skill_points_granted", -1)) == 3 and int(plan.get("skill_points_after", -1)) == 3, "multi-level plan sums only the authored skill-point transition grants")
    var growth := plan.get("stat_growth_delta", {}) as Dictionary
    _expect(is_equal_approx(float(growth.get("hp", 0.0)), 15.0) and is_equal_approx(float(growth.get("stamina", 0.0)), 3.0), "multi-level plan sums only authored automatic stat-growth amounts")
    var resulting_stats := plan.get("resulting_stat_values", {}) as Dictionary
    _expect(is_equal_approx(float(resulting_stats.get("hp", 0.0)), 115.0) and is_equal_approx(float(resulting_stats.get("stamina", 0.0)), 53.0), "plan derives resulting stat state from caller-owned current values plus authored growth")
    _expect(cumulative_profile.to_dictionary() == before_profile and stats == {"hp": 100.0, "stamina": 50.0}, "planning mutates neither live profile nor caller stat state")

    var level_progress_profile := ProfileCreationService.create_profile(2, "Level Progress XP", "ranged")
    var level_progress_policy := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_LEVEL_PROGRESS,
        LevelProgressionPolicy.CAP_OVERFLOW_RETAIN
    )
    level_progress_profile.automatic_stats = stats.duplicate(true)
    var level_progress_plan := LevelProgressionService.plan_award(
        level_progress_profile,
        stats,
        350,
        &"xp_claim:test:level_progress",
        &"xp_source:test",
        level_progress_policy
    )
    _expect(bool(level_progress_plan.get("accepted", false)) and int(level_progress_plan.get("to_level", 0)) == 3, "level-progress policy reaches the same level from the same fixed thresholds")
    _expect(int(level_progress_plan.get("to_xp", -1)) == 50, "level-progress policy explicitly stores only progress toward the next threshold")


func _test_exact_boundary_for_each_transition() -> void:
    var policy := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL,
        LevelProgressionPolicy.CAP_OVERFLOW_DISCARD
    )
    var stats := {"hp": 100.0, "stamina": 50.0}
    for from_level: int in range(LevelThresholdTuning.MIN_LEVEL, LevelThresholdTuning.MAX_LEVEL):
        var threshold := DEFAULT_THRESHOLDS.xp_required_to_next(from_level)
        var cumulative_before := DEFAULT_THRESHOLDS.cumulative_xp_required_for_level(from_level)

        var below := ProfileCreationService.create_profile(1, "Boundary Below %d" % from_level, "melee")
        below.level = from_level
        below.xp = cumulative_before
        below.automatic_stats = stats.duplicate(true)
        var below_plan := LevelProgressionService.plan_award(
            below,
            stats,
            threshold - 1,
            StringName("xp_claim:test:boundary_below_%d" % from_level),
            &"xp_source:test:boundary",
            policy
        )
        _expect(bool(below_plan.get("accepted", false)) and int(below_plan.get("to_level", 0)) == from_level, "Level %d remains below the next transition at threshold minus one" % from_level)

        var exact := ProfileCreationService.create_profile(1, "Boundary Exact %d" % from_level, "melee")
        exact.level = from_level
        exact.xp = cumulative_before
        exact.automatic_stats = stats.duplicate(true)
        var exact_plan := LevelProgressionService.plan_award(
            exact,
            stats,
            threshold,
            StringName("xp_claim:test:boundary_exact_%d" % from_level),
            &"xp_source:test:boundary",
            policy
        )
        _expect(bool(exact_plan.get("accepted", false)) and int(exact_plan.get("to_level", 0)) == from_level + 1, "Level %d transitions exactly at its authored threshold" % from_level)
    _expect(DEFAULT_THRESHOLDS.xp_required_to_next(LevelThresholdTuning.MAX_LEVEL) == 0, "Level 10 exposes no Level 11 boundary")


func _test_cap_overflow_is_policy_driven_without_level_11() -> void:
    var profile := ProfileCreationService.create_profile(1, "Cap XP", "mage")
    profile.level = 9
    profile.xp = 3600
    var stats := {"hp": 200.0, "stamina": 80.0}
    profile.automatic_stats = stats.duplicate(true)

    var discard_policy := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL,
        LevelProgressionPolicy.CAP_OVERFLOW_DISCARD
    )
    var discarded := LevelProgressionService.plan_award(
        profile,
        stats,
        1000,
        &"xp_claim:test:cap_discard",
        &"xp_source:test",
        discard_policy
    )
    _expect(bool(discarded.get("accepted", false)) and int(discarded.get("to_level", 0)) == 10, "cap plan reaches Level 10")
    _expect(int(discarded.get("cap_overflow_amount", -1)) == 100 and int(discarded.get("to_xp", -1)) == 4500, "discard policy reports overflow and clamps cumulative stored XP at the fixed Level 10 threshold")

    var retain_policy := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL,
        LevelProgressionPolicy.CAP_OVERFLOW_RETAIN
    )
    var retained := LevelProgressionService.plan_award(
        profile,
        stats,
        1000,
        &"xp_claim:test:cap_retain",
        &"xp_source:test",
        retain_policy
    )
    _expect(bool(retained.get("accepted", false)) and int(retained.get("to_level", 0)) == 10 and int(retained.get("to_xp", -1)) == 4600, "retain policy preserves authored cap overflow while still forbidding Level 11")
    _expect(int(retained.get("levels_gained", -1)) == 1, "cap overflow never fabricates a progression transition beyond Level 10")

    var progress_profile := ProfileCreationService.create_profile(2, "Cap Progress", "mage")
    progress_profile.level = 9
    progress_profile.xp = 0
    progress_profile.automatic_stats = stats.duplicate(true)
    var progress_retain := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_LEVEL_PROGRESS,
        LevelProgressionPolicy.CAP_OVERFLOW_RETAIN
    )
    var retained_progress := LevelProgressionService.plan_award(
        progress_profile,
        stats,
        1000,
        &"xp_claim:test:cap_progress",
        &"xp_source:test",
        progress_retain
    )
    _expect(int(retained_progress.get("to_level", 0)) == 10 and int(retained_progress.get("to_xp", -1)) == 100, "level-progress retain policy stores only explicit post-cap overflow at Level 10")


func _test_multi_level_award_aggregates_each_transition_once() -> void:
    var profile := ProfileCreationService.create_profile(1, "All Transitions", "melee")
    var policy := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL,
        LevelProgressionPolicy.CAP_OVERFLOW_DISCARD
    )
    var stats := {"hp": 100.0, "stamina": 50.0}
    profile.automatic_stats = stats.duplicate(true)
    var plan := LevelProgressionService.plan_award(
        profile,
        stats,
        999999,
        &"xp_claim:test:all_transitions",
        &"xp_source:test",
        policy
    )
    _expect(bool(plan.get("accepted", false)) and int(plan.get("to_level", 0)) == LevelThresholdTuning.MAX_LEVEL, "oversized award stops at the locked Level 10 cap")
    _expect(int(plan.get("levels_gained", -1)) == LevelThresholdTuning.TRANSITION_COUNT, "Level 1 to cap contains exactly nine progression transitions")
    _expect(int(plan.get("skill_points_granted", -1)) == 10, "multi-level award sums each authored skill-point transition exactly once")
    var growth := plan.get("stat_growth_delta", {}) as Dictionary
    _expect(is_equal_approx(float(growth.get("hp", 0.0)), 72.0) and is_equal_approx(float(growth.get("stamina", 0.0)), 15.0), "multi-level award sums every authored stat-growth transition exactly once")
    var transitions := plan.get("transitions", []) as Array
    _expect(transitions.size() == 9 and int((transitions[8] as Dictionary).get("to_level", 0)) == 10, "transition ledger ends at Level 10 with no synthetic Level 11 entry")


func _test_invalid_or_missing_policy_fails_closed() -> void:
    var profile := ProfileCreationService.create_profile(1, "Missing Policy", "melee")
    var stats := {"hp": 100.0, "stamina": 50.0}
    profile.automatic_stats = stats.duplicate(true)
    var missing := LevelProgressionService.plan_award(
        profile,
        stats,
        100,
        &"xp_claim:test:missing_policy",
        &"xp_source:test",
        null
    )
    _expect(not bool(missing.get("accepted", true)) and StringName(missing.get("reason_id", &"")) == LevelProgressionService.REASON_POLICY_MISSING, "missing progression policy is a named fail-closed result")

    var incomplete := LevelProgressionPolicy.new()
    incomplete.threshold_tuning = DEFAULT_THRESHOLDS
    var invalid := LevelProgressionService.plan_award(
        profile,
        stats,
        100,
        &"xp_claim:test:invalid_policy",
        &"xp_source:test",
        incomplete
    )
    _expect(not bool(invalid.get("accepted", true)) and StringName(invalid.get("reason_id", &"")) == LevelProgressionService.REASON_POLICY_INVALID, "incomplete authored policy cannot silently fall back to invented tuning")
    _expect(not (invalid.get("policy_errors", PackedStringArray()) as PackedStringArray).is_empty(), "invalid-policy result exposes exact missing authored policy fields")

    var complete := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL,
        LevelProgressionPolicy.CAP_OVERFLOW_DISCARD
    )
    var missing_stat := LevelProgressionService.plan_award(
        profile,
        {"hp": 100.0},
        100,
        &"xp_claim:test:missing_stat",
        &"xp_source:test",
        complete
    )
    _expect(not bool(missing_stat.get("accepted", true)) and StringName(missing_stat.get("reason_id", &"")) == LevelProgressionService.REASON_STAT_STATE_INVALID, "plan rejects missing caller-owned automatic stat state")

    var mismatched_profile := ProfileCreationService.create_profile(2, "Mismatch", "ranged")
    mismatched_profile.level = 2
    mismatched_profile.xp = 0
    mismatched_profile.automatic_stats = stats.duplicate(true)
    var mismatch := LevelProgressionService.plan_award(
        mismatched_profile,
        stats,
        100,
        &"xp_claim:test:mismatch",
        &"xp_source:test",
        complete
    )
    _expect(not bool(mismatch.get("accepted", true)) and StringName(mismatch.get("reason_id", &"")) == LevelProgressionService.REASON_PROFILE_POLICY_MISMATCH, "stored XP/level state must be consistent with the explicitly authored XP storage semantics")


func _test_atomic_commit_receipt_boundary() -> void:
    var profile := ProfileCreationService.create_profile(1, "Atomic Progression", "melee")
    var policy := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL,
        LevelProgressionPolicy.CAP_OVERFLOW_DISCARD
    )
    var stats := {"hp": 100.0, "stamina": 50.0}
    profile.automatic_stats = stats.duplicate(true)
    var before := profile.to_dictionary()

    var missing_owner := LevelProgressionService.commit_award(
        profile,
        stats,
        350,
        &"xp_claim:test:no_owner",
        &"xp_source:test",
        policy,
        Callable()
    )
    _expect(not bool(missing_owner.get("accepted", true)) and StringName(missing_owner.get("reason_id", &"")) == LevelProgressionService.REASON_ATOMIC_COMMIT_OWNER_MISSING, "commit fails closed when no owner can atomically persist profile and automatic stats")
    _expect(profile.to_dictionary() == before, "missing atomic owner leaves live progression unchanged")

    _atomic_call_count = 0
    var invalid_receipt := LevelProgressionService.commit_award(
        profile,
        stats,
        350,
        &"xp_claim:test:bad_receipt",
        &"xp_source:test",
        policy,
        Callable(self, &"_atomic_missing_stat_confirmation")
    )
    _expect(not bool(invalid_receipt.get("accepted", true)) and StringName(invalid_receipt.get("reason_id", &"")) == LevelProgressionService.REASON_ATOMIC_COMMIT_RECEIPT_INVALID, "commit rejects a receipt that does not confirm atomic automatic-stat persistence")
    _expect(profile.to_dictionary() == before and _atomic_call_count == 1, "invalid durable receipt cannot mutate live level/XP/points/claims")

    _atomic_call_count = 0
    var missing_version := LevelProgressionService.commit_award(
        profile,
        stats,
        350,
        &"xp_claim:test:missing_contract_version",
        &"xp_source:test",
        policy,
        Callable(self, &"_atomic_missing_contract_version")
    )
    _expect(not bool(missing_version.get("accepted", true)) and StringName(missing_version.get("reason_id", &"")) == LevelProgressionService.REASON_ATOMIC_COMMIT_RECEIPT_INVALID, "accepted atomic receipt must echo the progression contract version")
    _expect(profile.to_dictionary() == before and _atomic_call_count == 1, "receipt missing the contract version cannot finalize live progression")

    _atomic_call_count = 0
    _captured_prepared.clear()
    var committed := LevelProgressionService.commit_award(
        profile,
        stats,
        350,
        &"xp_claim:test:atomic_success",
        &"xp_source:test",
        policy,
        Callable(self, &"_atomic_success")
    )
    _expect(bool(committed.get("accepted", false)) and bool(committed.get("durable", false)), "complete atomic receipt permits the staged progression transaction to finalize")
    _expect(profile.level == 3 and profile.xp == 350 and profile.skill_points == 3, "atomic finalization applies the planned level, XP and authored skill-point grants together")
    _expect(AutomaticStatState.equivalent(profile.automatic_stats, {"hp": 115.0, "stamina": 53.0}), "atomic finalization commits authored automatic stat growth into the profile source of truth")
    _expect(profile.claimed_transactions.has("xp_claim:test:atomic_success"), "atomic progression commit records the stable XP source claim with the same durable profile generation")
    _expect(_atomic_call_count == 1 and not _captured_prepared.is_empty(), "atomic owner receives exactly one detached prepared transaction")
    _expect(int(_captured_prepared.get("atomic_commit_contract_version", -1)) == LevelProgressionService.ATOMIC_COMMIT_CONTRACT_VERSION, "prepared transaction declares the exact atomic owner contract version")
    var contract := LevelProgressionService.atomic_owner_contract()
    _expect(int(contract.get("version", -1)) == LevelProgressionService.ATOMIC_COMMIT_CONTRACT_VERSION and StringName(contract.get("prepared_profile_key", &"")) == &"staged_profile" and StringName(contract.get("resulting_stat_values_key", &"")) == &"resulting_stat_values", "public atomic-owner contract identifies the exact staged profile and resulting-stat payload keys")
    var prepared_stats := _captured_prepared.get("resulting_stat_values", {}) as Dictionary
    _expect(is_equal_approx(float(prepared_stats.get("hp", 0.0)), 115.0) and is_equal_approx(float(prepared_stats.get("stamina", 0.0)), 53.0), "atomic owner receives the exact authored resulting stat state alongside staged profile progression")
    var prepared_profile := _captured_prepared.get("staged_profile", {}) as Dictionary
    _expect(int(prepared_profile.get("level", 0)) == 3 and (prepared_profile.get("claimed_transactions", {}) as Dictionary).has("xp_claim:test:atomic_success"), "prepared atomic payload contains level and claim identity before the owner commits it")
    _expect(AutomaticStatState.equivalent(prepared_profile.get("automatic_stats", {}), prepared_stats), "prepared atomic profile embeds the same automatic stats that the live runtime mirror must apply")

    var after_success := profile.to_dictionary()
    var duplicate := LevelProgressionService.commit_award(
        profile,
        prepared_stats,
        1,
        &"xp_claim:test:atomic_success",
        &"xp_source:test",
        policy,
        Callable(self, &"_atomic_success")
    )
    _expect(not bool(duplicate.get("accepted", true)) and StringName(duplicate.get("reason_id", &"")) == LevelProgressionService.REASON_DUPLICATE_CLAIM, "stable XP claim identity prevents repeat award transactions")
    _expect(profile.to_dictionary() == after_success and _atomic_call_count == 1, "duplicate XP claim is rejected before the atomic owner is invoked again")


func _atomic_missing_stat_confirmation(prepared: Dictionary) -> Dictionary:
    _atomic_call_count += 1
    return {
        "accepted": true,
        "durable": true,
        "profile_committed": true,
        "stat_growth_committed": false,
        "claim_id": prepared.get("claim_id", &""),
    }


func _atomic_missing_contract_version(prepared: Dictionary) -> Dictionary:
    _atomic_call_count += 1
    return {
        "accepted": true,
        "durable": true,
        "profile_committed": true,
        "stat_growth_committed": true,
        "claim_id": prepared.get("claim_id", &""),
    }


func _atomic_success(prepared: Dictionary) -> Dictionary:
    _atomic_call_count += 1
    _captured_prepared = prepared.duplicate(true)
    return {
        "accepted": true,
        "durable": true,
        "profile_committed": true,
        "stat_growth_committed": true,
        "claim_id": prepared.get("claim_id", &""),
        "atomic_commit_contract_version": prepared.get("atomic_commit_contract_version", -1),
    }


func _make_policy(xp_storage: StringName, overflow: StringName) -> LevelProgressionPolicy:
    var policy := LevelProgressionPolicy.new()
    policy.threshold_tuning = DEFAULT_THRESHOLDS
    policy.xp_storage_semantics = xp_storage
    policy.cap_overflow_behavior = overflow
    policy.skill_points_granted_by_transition = PackedInt32Array([1, 2, 0, 1, 0, 2, 1, 0, 3])
    policy.stat_growth_by_transition = [
        {"hp": 10.0, "stamina": 2.0},
        {"hp": 5.0, "stamina": 1.0},
        {"hp": 8.0, "stamina": 1.5},
        {"hp": 6.0, "stamina": 1.0},
        {"hp": 7.0, "stamina": 2.0},
        {"hp": 9.0, "stamina": 1.0},
        {"hp": 5.0, "stamina": 1.0},
        {"hp": 10.0, "stamina": 2.5},
        {"hp": 12.0, "stamina": 3.0},
    ]
    return policy


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
