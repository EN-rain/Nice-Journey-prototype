extends SceneTree

const DEFAULT_THRESHOLDS: LevelThresholdTuning = preload("res://src/progression/leveling/level_threshold_default.tres")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_missing_policy_is_explicit()
    _test_policy_axes_are_explicit()
    _test_complete_authored_policy_validates()
    _test_invalid_authored_values_fail_closed()

    if _failures == 0:
        print("LEVEL PROGRESSION POLICY TEST PASS")
    else:
        push_error("LEVEL PROGRESSION POLICY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_missing_policy_is_explicit() -> void:
    var policy := LevelProgressionPolicy.new()
    policy.threshold_tuning = DEFAULT_THRESHOLDS
    var errors := policy.validate_policy()
    _expect(_contains(errors, "xp_storage_semantics"), "policy rejects missing XP storage semantics instead of choosing one")
    _expect(_contains(errors, "cap_overflow_behavior"), "policy rejects missing Level 10 overflow behavior instead of choosing one")
    _expect(_contains(errors, "skill_points_granted_by_transition"), "policy rejects a missing authored skill-point schedule")
    _expect(_contains(errors, "stat_growth_by_transition"), "policy rejects a missing authored automatic stat-growth table")


func _test_policy_axes_are_explicit() -> void:
    _expect(LevelProgressionPolicy.SUPPORTED_XP_STORAGE.size() == 2 and LevelProgressionPolicy.SUPPORTED_XP_STORAGE.has(LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL) and LevelProgressionPolicy.SUPPORTED_XP_STORAGE.has(LevelProgressionPolicy.XP_STORAGE_LEVEL_PROGRESS), "XP storage remains an explicit two-choice policy axis")
    _expect(LevelProgressionPolicy.SUPPORTED_CAP_OVERFLOW.size() == 2 and LevelProgressionPolicy.SUPPORTED_CAP_OVERFLOW.has(LevelProgressionPolicy.CAP_OVERFLOW_DISCARD) and LevelProgressionPolicy.SUPPORTED_CAP_OVERFLOW.has(LevelProgressionPolicy.CAP_OVERFLOW_RETAIN), "Level 10 overflow remains an explicit discard-or-retain policy axis")

    var unsupported_storage := _make_policy(&"implicit_default", LevelProgressionPolicy.CAP_OVERFLOW_DISCARD)
    _expect(_contains(unsupported_storage.validate_policy(), "xp_storage_semantics"), "unsupported XP storage semantics fail closed")
    var unsupported_overflow := _make_policy(LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL, &"prestige")
    _expect(_contains(unsupported_overflow.validate_policy(), "cap_overflow_behavior"), "unsupported cap overflow behavior fails closed instead of creating prestige progression")


func _test_complete_authored_policy_validates() -> void:
    var policy := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL,
        LevelProgressionPolicy.CAP_OVERFLOW_DISCARD
    )
    _expect(policy.validate_policy().is_empty(), "complete test-authored progression policy validates without production tuning defaults")
    _expect(policy.skill_points_for_transition(1) == 1 and policy.skill_points_for_transition(2) == 2, "policy exposes authored per-transition skill-point grants")
    _expect(is_equal_approx(float(policy.stat_growth_for_transition(1).get("hp", 0.0)), 10.0), "policy exposes authored automatic stat growth without hardcoded amounts")
    var stat_ids := policy.required_stat_ids()
    _expect(stat_ids.size() == 2 and stat_ids.has(&"hp") and stat_ids.has(&"stamina"), "policy derives required automatic-stat ownership from authored growth data")

    var detached := policy.stat_growth_for_transition(1)
    detached["hp"] = 99999.0
    _expect(is_equal_approx(float(policy.stat_growth_for_transition(1).get("hp", 0.0)), 10.0), "returned stat-growth entries cannot mutate policy ownership")


func _test_invalid_authored_values_fail_closed() -> void:
    var bad_points := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_LEVEL_PROGRESS,
        LevelProgressionPolicy.CAP_OVERFLOW_RETAIN
    )
    bad_points.skill_points_granted_by_transition = PackedInt32Array([1, 2])
    _expect(_contains(bad_points.validate_policy(), "exactly nine"), "skill-point schedule rejects missing level transitions")

    var negative_points := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_LEVEL_PROGRESS,
        LevelProgressionPolicy.CAP_OVERFLOW_RETAIN
    )
    negative_points.skill_points_granted_by_transition = PackedInt32Array([1, 2, 0, 1, -1, 0, 1, 0, 2])
    _expect(_contains(negative_points.validate_policy(), "cannot be negative"), "skill-point schedule rejects negative authored grants")

    var empty_growth := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL,
        LevelProgressionPolicy.CAP_OVERFLOW_DISCARD
    )
    empty_growth.stat_growth_by_transition[3] = {}
    _expect(_contains(empty_growth.validate_policy(), "at least one automatic stat increase"), "automatic stat-growth table rejects an unauthored transition")

    var negative_growth := _make_policy(
        LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL,
        LevelProgressionPolicy.CAP_OVERFLOW_DISCARD
    )
    negative_growth.stat_growth_by_transition[4] = {"hp": -1.0}
    _expect(_contains(negative_growth.validate_policy(), "cannot be negative"), "automatic stat-growth table rejects negative growth")


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


func _contains(errors: PackedStringArray, fragment: String) -> bool:
    for error: String in errors:
        if error.contains(fragment):
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
