extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_threshold_boundaries()
    _test_slow_frame_percentage()
    _test_rolling_window_floor()
    _test_short_sample_fails_closed()
    if _failures == 0:
        print("QA PERF METRICS TEST PASS")
    else:
        push_error("QA PERF METRICS TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_threshold_boundaries() -> void:
    var samples: Array[float] = []
    for _index: int in range(120):
        samples.append(16.0)
    var summary := QaPerfMetrics.summarize(samples)
    var result := QaPerfMetrics.evaluate_thresholds(summary)
    _expect(bool(result.get("thresholds_met", false)), "steady 16 ms fixture passes all DR-08 frame-time thresholds")
    _expect(is_equal_approx(float(summary.get("rolling_one_second_min_fps", 0.0)), 62.0), "rolling one-second evaluator counts completed frames inside the literal 1000 ms window")


func _test_slow_frame_percentage() -> void:
    var samples: Array[float] = []
    for _index: int in range(199):
        samples.append(10.0)
    samples.append(41.0)
    var summary := QaPerfMetrics.summarize(samples)
    _expect(is_equal_approx(float(summary.get("frames_over_40_ms_percent", -1.0)), 0.5), "exactly 0.5 percent slower-than-40-ms frames remains on the allowed boundary")
    _expect(bool(QaPerfMetrics.evaluate_thresholds(summary).get("thresholds_met", false)), "0.5 percent slow-frame boundary is accepted when other thresholds remain valid")


func _test_rolling_window_floor() -> void:
    var samples: Array[float] = []
    for _index: int in range(60):
        samples.append(41.0)
    var summary := QaPerfMetrics.summarize(samples)
    var result := QaPerfMetrics.evaluate_thresholds(summary)
    _expect(float(summary.get("rolling_one_second_min_fps", 99.0)) == 24.0, "41 ms cadence exposes a 24 FPS rolling one-second window")
    _expect(not bool(result.get("thresholds_met", true)), "rolling one-second floor failure rejects the threshold result")


func _test_short_sample_fails_closed() -> void:
    var summary := QaPerfMetrics.summarize([16.0, 16.0, 16.0])
    var result := QaPerfMetrics.evaluate_thresholds(summary)
    _expect(float(summary.get("rolling_one_second_min_fps", 0.0)) < 0.0, "sub-second sample cannot claim a rolling one-second rate")
    _expect(not bool(result.get("thresholds_met", true)), "sub-second sample fails closed")


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
