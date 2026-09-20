extends SceneTree

const DEFAULT_THRESHOLDS: LevelThresholdTuning = preload("res://src/progression/leveling/level_threshold_default.tres")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_locked_level_range_and_initial_hypothesis()
    _test_all_transition_and_cumulative_thresholds()
    _test_threshold_bounds_fail_closed()

    if _failures == 0:
        print("LEVEL PROGRESSION THRESHOLD TEST PASS")
    else:
        push_error("LEVEL PROGRESSION THRESHOLD TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_locked_level_range_and_initial_hypothesis() -> void:
    _expect(LevelThresholdTuning.MIN_LEVEL == 1, "progression begins at Level 1")
    _expect(LevelThresholdTuning.MAX_LEVEL == 10, "master-locked progression cap is Level 10")
    _expect(LevelThresholdTuning.TRANSITION_COUNT == 9, "Level 1 through Level 10 contains exactly nine level transitions")
    _expect(DEFAULT_THRESHOLDS.validate_tuning().is_empty(), "initial threshold hypothesis resource is structurally valid")
    _expect(DEFAULT_THRESHOLDS.xp_to_next_by_level == PackedInt32Array([100, 200, 300, 400, 500, 600, 700, 800, 900]), "implementation threshold resource matches the master's initial 100 x L hypothesis for Level 1-9")
    _expect(DEFAULT_THRESHOLDS.total_xp_to_cap() == 4500, "initial threshold hypothesis totals 4,500 XP at Level 10")


func _test_all_transition_and_cumulative_thresholds() -> void:
    var expected_cumulative := PackedInt32Array([0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500])
    for level: int in range(LevelThresholdTuning.MIN_LEVEL, LevelThresholdTuning.MAX_LEVEL + 1):
        _expect(DEFAULT_THRESHOLDS.cumulative_xp_required_for_level(level) == expected_cumulative[level - 1], "cumulative XP threshold is exact for Level %d" % level)

    var entries := DEFAULT_THRESHOLDS.threshold_entries()
    _expect(entries.size() == LevelThresholdTuning.TRANSITION_COUNT, "threshold table exposes exactly nine transitions")
    for index: int in range(entries.size()):
        var entry := entries[index] as Dictionary
        var from_level := index + LevelThresholdTuning.MIN_LEVEL
        _expect(int(entry.get("from_level", 0)) == from_level and int(entry.get("to_level", 0)) == from_level + 1, "threshold entry %d maps only the intended adjacent levels" % index)
        _expect(int(entry.get("xp_required", 0)) == 100 * from_level, "threshold entry %d retains the initial 100 x L hypothesis" % index)
    _expect(int((entries[entries.size() - 1] as Dictionary).get("to_level", 0)) == LevelThresholdTuning.MAX_LEVEL, "threshold table terminates at Level 10 and contains no Level 11 transition")


func _test_threshold_bounds_fail_closed() -> void:
    _expect(DEFAULT_THRESHOLDS.xp_required_to_next(0) == 0, "below-minimum level has no transition threshold")
    _expect(DEFAULT_THRESHOLDS.xp_required_to_next(LevelThresholdTuning.MAX_LEVEL) == 0, "Level 10 has no next-level threshold")
    _expect(DEFAULT_THRESHOLDS.xp_required_to_next(LevelThresholdTuning.MAX_LEVEL + 1) == 0, "Level 11 cannot obtain a transition threshold")
    _expect(DEFAULT_THRESHOLDS.cumulative_xp_required_for_level(0) == -1, "below-minimum cumulative threshold fails closed")
    _expect(DEFAULT_THRESHOLDS.cumulative_xp_required_for_level(LevelThresholdTuning.MAX_LEVEL + 1) == -1, "Level 11 cumulative threshold fails closed")

    var incomplete := LevelThresholdTuning.new()
    incomplete.xp_to_next_by_level = PackedInt32Array()
    _expect(not incomplete.validate_tuning().is_empty(), "missing threshold data is invalid rather than receiving invented production thresholds")
    _expect(incomplete.threshold_entries().is_empty() and incomplete.total_xp_to_cap() == -1, "invalid threshold tuning exposes no usable progression table")


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
