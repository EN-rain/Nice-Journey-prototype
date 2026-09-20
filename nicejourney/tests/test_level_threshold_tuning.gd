extends SceneTree

const LEVEL_THRESHOLD_SCRIPT: Script = preload("res://src/progression/leveling/level_threshold_tuning.gd")
const DEFAULT_TUNING: Resource = preload("res://src/progression/leveling/level_threshold_default.tres")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var tuning: Resource = DEFAULT_TUNING
    _expect(tuning != null, "default Level 1-10 threshold resource loads")
    _expect((tuning.call("validate_tuning") as PackedStringArray).is_empty(), "default level threshold table validates")
    _expect(int(LEVEL_THRESHOLD_SCRIPT.MIN_LEVEL) == ProfileSnapshot.MIN_LEVEL and int(LEVEL_THRESHOLD_SCRIPT.MAX_LEVEL) == ProfileSnapshot.MAX_LEVEL, "threshold owner matches the persistent Level 1-10 cap")

    var expected_thresholds := PackedInt32Array([100, 200, 300, 400, 500, 600, 700, 800, 900])
    for level: int in range(1, 10):
        _expect(int(tuning.call("xp_required_to_next", level)) == expected_thresholds[level - 1], "Level %d->%d uses the master initial XP threshold" % [level, level + 1])

    var expected_cumulative := PackedInt32Array([0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500])
    for level: int in range(1, 11):
        _expect(int(tuning.call("cumulative_xp_required_for_level", level)) == expected_cumulative[level - 1], "cumulative initial XP threshold reaches Level %d exactly" % level)
    _expect(int(tuning.call("total_xp_to_cap")) == 4500, "initial threshold table totals 4,500 XP through Level 10")
    _expect(int(tuning.call("xp_required_to_next", 10)) == 0, "Level 10 exposes no Level 11 threshold")
    _expect(int(tuning.call("xp_required_to_next", 0)) == 0 and int(tuning.call("cumulative_xp_required_for_level", 11)) == -1, "out-of-range threshold queries fail closed")

    var entries: Array = tuning.call("threshold_entries") as Array
    _expect(entries.size() == 9, "threshold table exposes exactly nine Level 1-9 transitions")
    if entries.size() == 9:
        var first := entries[0] as Dictionary
        var last := entries[8] as Dictionary
        _expect(int(first.get("from_level", 0)) == 1 and int(first.get("to_level", 0)) == 2 and int(first.get("xp_required", 0)) == 100, "first threshold entry preserves Level 1->2 identity")
        _expect(int(last.get("from_level", 0)) == 9 and int(last.get("to_level", 0)) == 10 and int(last.get("xp_required", 0)) == 900 and int(last.get("cumulative_xp_at_to_level", 0)) == 4500, "last threshold entry terminates exactly at the Level 10 cap")
        first["xp_required"] = 999999
        var fresh: Array = tuning.call("threshold_entries") as Array
        _expect(int((fresh[0] as Dictionary).get("xp_required", 0)) == 100, "threshold entry snapshots are detached from tuning ownership")

    var reversible: Resource = LEVEL_THRESHOLD_SCRIPT.new()
    reversible.set("xp_to_next_by_level", PackedInt32Array([50, 100, 150, 200, 250, 300, 350, 400, 450]))
    _expect((reversible.call("validate_tuning") as PackedStringArray).is_empty(), "alternate positive threshold data remains valid tuning")
    _expect(int(reversible.call("xp_required_to_next", 3)) == 150 and int(reversible.call("total_xp_to_cap")) == 2250, "threshold arithmetic consumes resource data instead of hardcoding the initial curve")

    var wrong_count: Resource = LEVEL_THRESHOLD_SCRIPT.new()
    wrong_count.set("xp_to_next_by_level", PackedInt32Array([100, 200]))
    _expect(not (wrong_count.call("validate_tuning") as PackedStringArray).is_empty(), "threshold table rejects missing Level transitions")
    _expect(int(wrong_count.call("xp_required_to_next", 1)) == 0, "invalid threshold tables cannot supply progression values")

    var nonpositive: Resource = LEVEL_THRESHOLD_SCRIPT.new()
    nonpositive.set("xp_to_next_by_level", PackedInt32Array([100, 200, 300, 400, 0, 600, 700, 800, 900]))
    _expect(not (nonpositive.call("validate_tuning") as PackedStringArray).is_empty(), "threshold table rejects nonpositive XP requirements")

    if _failures == 0:
        print("LEVEL THRESHOLD TUNING TEST PASS")
    else:
        push_error("LEVEL THRESHOLD TUNING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
