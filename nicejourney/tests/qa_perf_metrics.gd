class_name QaPerfMetrics
extends RefCounted

const P50_MAX_MS: float = 16.67
const P95_MAX_MS: float = 25.0
const P99_MAX_MS: float = 33.33
const SLOW_FRAME_THRESHOLD_MS: float = 40.0
const SLOW_FRAME_MAX_PERCENT: float = 0.5
const MAX_FRAME_MS: float = 100.0
const MIN_ROLLING_ONE_SECOND_FPS: float = 25.0


static func summarize(raw_samples: Array[float]) -> Dictionary:
    if raw_samples.is_empty():
        return {}
    var samples: Array[float] = []
    for sample: float in raw_samples:
        if not is_finite(sample) or sample < 0.0:
            return {}
        samples.append(sample)
    var sorted_samples := samples.duplicate()
    sorted_samples.sort()
    var total_ms := 0.0
    var slow_frames := 0
    for sample: float in samples:
        total_ms += sample
        if sample > SLOW_FRAME_THRESHOLD_MS:
            slow_frames += 1
    return {
        "sample_count": samples.size(),
        "duration_ms": snappedf(total_ms, 0.001),
        "frame_ms_mean": snappedf(total_ms / float(samples.size()), 0.001),
        "frame_ms_p50": snappedf(_percentile(sorted_samples, 0.50), 0.001),
        "frame_ms_p95": snappedf(_percentile(sorted_samples, 0.95), 0.001),
        "frame_ms_p99": snappedf(_percentile(sorted_samples, 0.99), 0.001),
        "frame_ms_max": snappedf(sorted_samples[sorted_samples.size() - 1], 0.001),
        "frames_over_40_ms": slow_frames,
        "frames_over_40_ms_percent": snappedf(float(slow_frames) * 100.0 / float(samples.size()), 0.001),
        "rolling_one_second_min_fps": snappedf(_rolling_one_second_min_fps(samples), 0.001),
    }


static func evaluate_thresholds(summary: Dictionary) -> Dictionary:
    if summary.is_empty():
        return {"measurable": false, "thresholds_met": false, "failures": PackedStringArray(["frame-time summary is unavailable"])}
    var failures := PackedStringArray()
    if float(summary.get("frame_ms_p50", INF)) > P50_MAX_MS:
        failures.append("p50 exceeds 16.67 ms")
    if float(summary.get("frame_ms_p95", INF)) > P95_MAX_MS:
        failures.append("p95 exceeds 25 ms")
    if float(summary.get("frame_ms_p99", INF)) > P99_MAX_MS:
        failures.append("p99 exceeds 33.33 ms")
    if float(summary.get("frames_over_40_ms_percent", INF)) > SLOW_FRAME_MAX_PERCENT:
        failures.append("frames slower than 40 ms exceed 0.5 percent")
    if float(summary.get("frame_ms_max", INF)) > MAX_FRAME_MS:
        failures.append("a steady-state frame exceeds 100 ms")
    var rolling_fps := float(summary.get("rolling_one_second_min_fps", -1.0))
    if rolling_fps < 0.0:
        failures.append("sample is shorter than one second")
    elif rolling_fps < MIN_ROLLING_ONE_SECOND_FPS:
        failures.append("a rolling one-second window averages below 25 FPS")
    return {
        "measurable": true,
        "thresholds_met": failures.is_empty(),
        "failures": failures,
    }


static func _percentile(sorted_samples: Array[float], fraction: float) -> float:
    if sorted_samples.is_empty():
        return 0.0
    var index := clampi(ceili(fraction * float(sorted_samples.size())) - 1, 0, sorted_samples.size() - 1)
    return sorted_samples[index]


static func _rolling_one_second_min_fps(samples: Array[float]) -> float:
    if samples.is_empty():
        return -1.0
    var cumulative := PackedFloat64Array()
    cumulative.resize(samples.size() + 1)
    cumulative[0] = 0.0
    for index: int in range(samples.size()):
        cumulative[index + 1] = cumulative[index] + samples[index]
    if cumulative[cumulative.size() - 1] < 1000.0:
        return -1.0

    var minimum_fps := INF
    var end_index := 0
    for start_index: int in range(samples.size()):
        var start_time := cumulative[start_index]
        if cumulative[cumulative.size() - 1] - start_time < 1000.0:
            break
        end_index = maxi(end_index, start_index)
        while end_index < samples.size() and cumulative[end_index + 1] - start_time <= 1000.0:
            end_index += 1
        minimum_fps = minf(minimum_fps, float(end_index - start_index))
    return -1.0 if minimum_fps == INF else minimum_fps
