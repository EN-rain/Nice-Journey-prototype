extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var source := FileAccess.get_file_as_string("res://tests/qa_perf_worst.gd")
    var harness_source := FileAccess.get_file_as_string("res://tools/qa_perf_worst.ps1")
    _expect(source.contains("DEFAULT_WARMUP_SECONDS: float = 60.0"), "QA-PERF-WORST default warm-up matches the approved 60-second protocol")
    _expect(source.contains("DEFAULT_SAMPLE_SECONDS: float = 600.0"), "QA-PERF-WORST default sample duration matches the approved ten-minute minimum")
    _expect(source.contains("FULL_AI_TARGET: int = FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS"), "QA-PERF-WORST derives the 12 FULL-AI load from the authoritative hard cap")
    _expect(source.contains("DisplayServer.window_set_size(Vector2i(1280, 720))"), "QA-PERF-WORST fixes the approved output resolution")
    _expect(source.contains("\"acceptance_claim\": false"), "developer/reference runs cannot claim final hardware acceptance")
    _expect(source.contains("\"representative_projectile_entities\": false"), "missing production projectile load is explicit instead of fabricated")
    _expect(source.contains("\"representative_audio_stream_mix\": false"), "missing authored audio-stream mix is explicit instead of fabricated")
    _expect(source.contains("\"authored_boss_pattern_timing\": false"), "missing authored boss cadence is explicit instead of invented")
    _expect(source.contains("protocol_route_complete"), "route completeness is reported separately from timing results")
    _expect(harness_source.contains("certification_blocked = $true"), "developer/reference harness cannot self-promote into final DR-08 certification")
    _expect(harness_source.contains("separately identified minimum-class"), "DR-08 certification remains explicitly dependent on a separate minimum-hardware run")
    if _failures == 0:
        print("QA PERF WORST CONTRACT TEST PASS")
    else:
        push_error("QA PERF WORST CONTRACT TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
