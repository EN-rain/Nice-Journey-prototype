extends SceneTree

const WARMUP_FRAMES: int = 120
const SAMPLE_FRAMES: int = 600

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var gameplay_scene: PackedScene = load("res://src/app/gameplay.tscn") as PackedScene
    if gameplay_scene == null:
        push_error("REFERENCE_PERF_SMOKE: gameplay scene failed to load")
        quit(1)
        return

    var gameplay: Node = gameplay_scene.instantiate()
    root.add_child(gameplay)
    var player: Node = gameplay.get_node("Player")
    var camera: PixelCamera = player.get_node("PixelCamera") as PixelCamera
    var accessibility: Node = root.get_node_or_null("AccessibilitySettings")

    for _index: int in range(WARMUP_FRAMES):
        await process_frame

    var frame_ms: Array[float] = []
    var max_static_memory_bytes: int = 0
    var max_process_ms: float = 0.0
    var max_physics_ms: float = 0.0
    var max_draw_calls: int = 0
    var physics_start: int = Engine.get_physics_frames()

    var previous_usec: int = Time.get_ticks_usec()
    for _index: int in range(SAMPLE_FRAMES):
        await process_frame
        var now_usec: int = Time.get_ticks_usec()
        frame_ms.append(float(now_usec - previous_usec) / 1000.0)
        previous_usec = now_usec

        max_static_memory_bytes = maxi(max_static_memory_bytes, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
        max_process_ms = maxf(max_process_ms, float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
        max_physics_ms = maxf(max_physics_ms, float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
        max_draw_calls = maxi(max_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))

    frame_ms.sort()
    var mean_ms: float = 0.0
    for sample: float in frame_ms:
        mean_ms += sample
    mean_ms /= float(frame_ms.size())

    var over_16_667: int = 0
    var over_40: int = 0
    for sample: float in frame_ms:
        if sample > 16.667:
            over_16_667 += 1
        if sample > 40.0:
            over_40 += 1

    var evidence: Dictionary = {
        "scenario_id": "QA-PERF-REFERENCE-GREYBOX",
        "scope": "current gameplay greybox renderer-active smoke only",
        "acceptance_claim": false,
        "warmup_frames": WARMUP_FRAMES,
        "sample_frames": SAMPLE_FRAMES,
        "physics_ticks_per_second": Engine.physics_ticks_per_second,
        "physics_frames_elapsed": Engine.get_physics_frames() - physics_start,
        "window_size": DisplayServer.window_get_size(),
        "screen_size": DisplayServer.screen_get_size(),
        "vsync_mode": DisplayServer.window_get_vsync_mode(),
        "camera_zoom_step": camera.get_zoom_step() if camera != null else -1,
        "camera_zoom": camera.zoom if camera != null else Vector2.ZERO,
        "accessibility": {
            "run_mode": int(accessibility.get("run_mode")) if accessibility != null else -1,
            "reduced_motion": bool(accessibility.get("reduced_motion")) if accessibility != null else false,
            "shake_intensity": float(accessibility.get("shake_intensity")) if accessibility != null else -1.0,
        },
        "frame_ms_mean": snappedf(mean_ms, 0.001),
        "frame_ms_p50": snappedf(_percentile(frame_ms, 0.50), 0.001),
        "frame_ms_p95": snappedf(_percentile(frame_ms, 0.95), 0.001),
        "frame_ms_p99": snappedf(_percentile(frame_ms, 0.99), 0.001),
        "frame_ms_max": snappedf(frame_ms[frame_ms.size() - 1], 0.001),
        "frames_over_16_667_ms": over_16_667,
        "frames_over_40_ms": over_40,
        "max_process_ms": snappedf(max_process_ms, 0.001),
        "max_physics_process_ms": snappedf(max_physics_ms, 0.001),
        "max_static_memory_bytes": max_static_memory_bytes,
        "max_draw_calls_in_frame": max_draw_calls,
    }
    print("REFERENCE_PERF_SMOKE: %s" % JSON.stringify(evidence))
    gameplay.queue_free()
    await process_frame
    quit(0)

func _percentile(sorted_values: Array[float], fraction: float) -> float:
    if sorted_values.is_empty():
        return 0.0
    var index: int = clampi(ceili(fraction * float(sorted_values.size())) - 1, 0, sorted_values.size() - 1)
    return sorted_values[index]
