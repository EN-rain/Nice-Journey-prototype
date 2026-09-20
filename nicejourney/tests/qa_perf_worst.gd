extends Node

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TOWER_VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const ENEMY_VISUAL_CATALOG: EnemyVisualSceneCatalog = preload("res://src/enemies/presentation/enemy_visual_scene_catalog.tres")
const ENEMY_TUNING: TowerPrototypeEnemyRuntimeTuning = preload("res://src/data/tuning/tower_prototype_enemy_runtime_default.tres")

const SCENARIO_ID: StringName = &"QA-PERF-WORST"
const FIXTURE_FLOOR_ID: int = 9
const FIXTURE_SEED: int = 99009012
const DEFAULT_WARMUP_SECONDS: float = 60.0
const DEFAULT_SAMPLE_SECONDS: float = 600.0
const FULL_AI_TARGET: int = FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS

var _warmup_seconds: float = DEFAULT_WARMUP_SECONDS
var _sample_seconds: float = DEFAULT_SAMPLE_SECONDS
var _gameplay: GameplayRoot = null
var _profile: ProfileSnapshot = null
var _floor_state: FloorInstanceState = null
var _qa_audio_slot_tokens: Array[int] = []


func _ready() -> void:
    _parse_user_args()
    call_deferred(&"_run")


func _run() -> void:
    var setup := await _setup_max_full_ai_segment()
    if not bool(setup.get("accepted", false)):
        _finish_with_error(String(setup.get("reason", "unknown setup failure")))
        return

    var warmup_start := Time.get_ticks_usec()
    while float(Time.get_ticks_usec() - warmup_start) / 1000000.0 < _warmup_seconds:
        await get_tree().process_frame

    var frame_ms: Array[float] = []
    var max_static_memory_bytes := 0
    var max_process_ms := 0.0
    var max_physics_ms := 0.0
    var max_draw_calls := 0
    var max_full_ai := 0
    var max_active_encounters := 0
    var physics_start := Engine.get_physics_frames()
    var sample_start_usec := Time.get_ticks_usec()
    var previous_usec := sample_start_usec
    while float(Time.get_ticks_usec() - sample_start_usec) / 1000000.0 < _sample_seconds:
        await get_tree().process_frame
        var now_usec := Time.get_ticks_usec()
        frame_ms.append(float(now_usec - previous_usec) / 1000.0)
        previous_usec = now_usec
        max_static_memory_bytes = maxi(max_static_memory_bytes, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
        max_process_ms = maxf(max_process_ms, float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
        max_physics_ms = maxf(max_physics_ms, float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
        max_draw_calls = maxi(max_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
        max_full_ai = maxi(max_full_ai, _gameplay.tower_encounter_session_host.shared_full_ai.get_admitted_count())
        max_active_encounters = maxi(max_active_encounters, _gameplay.tower_encounter_session_host.get_active_encounter_count())

    var elapsed_seconds := float(Time.get_ticks_usec() - sample_start_usec) / 1000000.0
    var summary := QaPerfMetrics.summarize(frame_ms)
    var threshold_evaluation := QaPerfMetrics.evaluate_thresholds(summary)
    var physics_frames_elapsed := Engine.get_physics_frames() - physics_start
    var expected_physics_frames := roundi(elapsed_seconds * float(Engine.physics_ticks_per_second))
    var route_coverage := _route_coverage()
    var protocol_duration_met := _warmup_seconds >= DEFAULT_WARMUP_SECONDS and _sample_seconds >= DEFAULT_SAMPLE_SECONDS
    var protocol_route_complete := _route_is_complete(route_coverage)
    var evidence := {
        "scenario_id": SCENARIO_ID,
        "deterministic_fixture": true,
        "fixture_floor_id": FIXTURE_FLOOR_ID,
        "fixture_seed": FIXTURE_SEED,
        "exported_build_required_for_final_acceptance": true,
        "acceptance_claim": false,
        "final_hardware_acceptance": false,
        "protocol_duration_met": protocol_duration_met,
        "protocol_route_complete": protocol_route_complete,
        "warmup_seconds": _warmup_seconds,
        "sample_seconds_requested": _sample_seconds,
        "sample_seconds_measured": snappedf(elapsed_seconds, 0.001),
        "window_size": DisplayServer.window_get_size(),
        "physics_ticks_per_second": Engine.physics_ticks_per_second,
        "physics_frames_elapsed": physics_frames_elapsed,
        "expected_physics_frames_from_wall_clock": expected_physics_frames,
        "physics_tick_deficit_vs_wall_clock": maxi(0, expected_physics_frames - physics_frames_elapsed),
        "max_static_memory_bytes": max_static_memory_bytes,
        "max_process_ms": snappedf(max_process_ms, 0.001),
        "max_physics_process_ms": snappedf(max_physics_ms, 0.001),
        "max_draw_calls_in_frame": max_draw_calls,
        "max_full_ai_observed": max_full_ai,
        "max_active_encounters_observed": max_active_encounters,
        "audio_important_slots_observed": AudioService.get_important_positional_slot_count(),
        "route_coverage": route_coverage,
        "frame_time_summary": summary,
        "threshold_evaluation_reference_machine_only": threshold_evaluation,
        "limitations": [
            "Timing thresholds are informational on this machine and cannot certify DR-08 minimum hardware.",
            "The authored production projectile entity path is not yet available to this harness.",
            "The authored final audio streams/load are not yet available; QA only exercises the existing 32-slot admission budget.",
            "The Tenth Warden has no authored production move-timing driver yet, so this harness does not invent a boss cadence.",
        ],
    }
    print("QA_PERF_WORST: %s" % JSON.stringify(evidence))
    _cleanup()
    get_tree().quit(0)


func _setup_max_full_ai_segment() -> Dictionary:
    DisplayServer.window_set_size(Vector2i(1280, 720))
    _profile = ProfileCreationService.create_profile(1, "QA PERF", "melee")
    if _profile == null:
        return {"accepted": false, "reason": "profile creation failed"}
    var request := TowerFloorGenerationCommitService.build_request(
        FIXTURE_FLOOR_ID,
        FIXTURE_SEED,
        &"tower_generator:v01",
        &"tower_modules:v01",
        &"encounters:v01",
        &"quest_flags:qa_perf_worst"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return {"accepted": false, "reason": "deterministic fallback manifest failed"}
    _floor_state = TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:qa_perf_worst_floor9", manifest)
    if _floor_state == null or not TowerFloorStateService.commit_floor_state(_profile, _floor_state):
        return {"accepted": false, "reason": "floor state commit failed"}

    var build := TowerFloorRuntimeComposer.build(_floor_state.layout_manifest, TOWER_VISUAL_CATALOG)
    var arrival := TowerArrivalResolver.resolve_entrance(_floor_state)
    if not bool(build.get("accepted", false)) or not bool(arrival.get("accepted", false)):
        return {"accepted": false, "reason": "floor runtime or arrival failed"}

    _gameplay = GAMEPLAY_SCENE.instantiate() as GameplayRoot
    if _gameplay == null:
        return {"accepted": false, "reason": "gameplay scene failed to instantiate"}
    _gameplay.set_profile(_profile)
    add_child(_gameplay)
    await get_tree().process_frame
    if not _gameplay.activate_committed_tower_travel({"accepted": true, "runtime_root": build.get("root"), "arrival": arrival}):
        return {"accepted": false, "reason": "tower runtime activation failed"}

    _set_max_ui_scale_in_memory()
    var plan := _build_max_full_ai_plan()
    if plan.is_empty():
        return {"accepted": false, "reason": "max FULL-AI plan failed validation"}
    var enemy_states := TowerPrototypeEnemyRuntimeFactory.build_states(_floor_state, plan, ENEMY_TUNING)
    if enemy_states.size() != FULL_AI_TARGET:
        return {"accepted": false, "reason": "max FULL-AI enemy state build failed"}
    var player_state := CombatantRuntimeState.new()
    if not player_state.configure(&"player:qa_perf_worst", 1000000000, 100.0, 0.0, 0.0, 1000000.0, true, true, true):
        return {"accepted": false, "reason": "QA player combat state failed"}

    for encounter_id: StringName in [&"encounter:qa_perf_overlap_a", &"encounter:qa_perf_overlap_b"]:
        var activation := _gameplay.tower_encounter_session_host.activate_encounter(
            _profile,
            _floor_state,
            plan,
            encounter_id,
            player_state,
            enemy_states,
            ENEMY_VISUAL_CATALOG
        )
        if not bool(activation.get("accepted", false)):
            return {"accepted": false, "reason": "overlapping encounter activation failed: %s" % String(encounter_id)}
    if _gameplay.tower_encounter_session_host.shared_full_ai.get_admitted_count() != FULL_AI_TARGET:
        return {"accepted": false, "reason": "global FULL-AI cap was not reached"}
    _acquire_qa_audio_budget_slots()
    await get_tree().physics_frame
    return {"accepted": true}


func _build_max_full_ai_plan() -> Dictionary:
    var objective_room_id := StringName(String((_floor_state.layout_manifest.get("objective_bindings", {}) as Dictionary).get("primary_floor_9", &"")))
    if objective_room_id == &"":
        return {}
    var room: Dictionary = {}
    for raw_room: Variant in _floor_state.layout_manifest.get("rooms", []) as Array:
        if raw_room is Dictionary and StringName(String((raw_room as Dictionary).get("room_instance_id", &""))) == objective_room_id:
            room = raw_room as Dictionary
            break
    if room.is_empty():
        return {}
    var definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(room.get("module_id", &""))))
    if definition == null or definition.spawn_regions.is_empty():
        return {}

    var spawn_tiles: Array[Vector2i] = []
    for spawn_rect: Rect2i in definition.spawn_regions:
        for y: int in range(spawn_rect.position.y, spawn_rect.end.y):
            for x: int in range(spawn_rect.position.x, spawn_rect.end.x):
                var tile := Vector2i(x, y)
                if _tile_is_clear(definition, tile):
                    spawn_tiles.append(tile)
    if spawn_tiles.size() < FULL_AI_TARGET:
        return {}

    var placements: Array[Dictionary] = []
    for index: int in range(FULL_AI_TARGET):
        var archetype_id := EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS[index % EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS.size()]
        placements.append({
            "actor_id": StringName("enemy:qa_perf_%02d_%s" % [index + 1, String(archetype_id)]),
            "archetype_id": archetype_id,
            "encounter_id": &"encounter:qa_perf_overlap_a" if index < FULL_AI_TARGET / 2 else &"encounter:qa_perf_overlap_b",
            "room_instance_id": objective_room_id,
            "local_tile": spawn_tiles[index],
            "elite": false,
        })
    var plan := {
        "plan_id": &"encounter_plan:qa_perf_worst_v01",
        "floor_id": FIXTURE_FLOOR_ID,
        "complete_floor_plan": false,
        "placements": placements,
    }
    return {} if not TowerEncounterPlanValidator.validate(plan, _floor_state).is_empty() else plan


func _tile_is_clear(definition: TowerRoomModuleDefinition, tile: Vector2i) -> bool:
    for collision: Rect2i in definition.collision_rects:
        if collision.has_point(tile):
            return false
    return true


func _set_max_ui_scale_in_memory() -> void:
    AccessibilitySettings.ui_scale = AccessibilitySettings.UI_SCALE_MAX
    AccessibilitySettings.text_scale = AccessibilitySettings.TEXT_SCALE_MAX
    AccessibilitySettings.ui_scale_changed.emit(AccessibilitySettings.ui_scale)
    AccessibilitySettings.text_scale_changed.emit(AccessibilitySettings.text_scale)


func _acquire_qa_audio_budget_slots() -> void:
    _qa_audio_slot_tokens.clear()
    for _index: int in range(AudioService.MAX_IMPORTANT_POSITIONAL_SFX):
        var token := AudioService.try_acquire_important_positional_slot()
        if token <= 0:
            break
        _qa_audio_slot_tokens.append(token)


func _route_coverage() -> Dictionary:
    var runtime_coverage := _runtime_driver_coverage()
    return {
        "max_12_full_ai": _gameplay != null and _gameplay.tower_encounter_session_host.shared_full_ai.get_admitted_count() == FULL_AI_TARGET,
        "overlapping_encounters": _gameplay != null and _gameplay.tower_encounter_session_host.get_active_encounter_count() >= 2,
        "navigation_ai": int(runtime_coverage.get("decision_movement_driver_count", 0)) == FULL_AI_TARGET,
        "decision_movement_driver_count": int(runtime_coverage.get("decision_movement_driver_count", 0)),
        "enemy_telegraph_vfx": int(runtime_coverage.get("telegraph_presenter_count", 0)) > 0,
        "telegraph_presenter_count": int(runtime_coverage.get("telegraph_presenter_count", 0)),
        "foreground_occlusion": _gameplay != null and _gameplay.get_node_or_null("CenterBlock/Occluder") != null,
        "ui_at_max_scale": is_equal_approx(AccessibilitySettings.ui_scale, AccessibilitySettings.UI_SCALE_MAX) and is_equal_approx(AccessibilitySettings.text_scale, AccessibilitySettings.TEXT_SCALE_MAX),
        "audio_admission_budget": AudioService.get_important_positional_slot_count() == AudioService.MAX_IMPORTANT_POSITIONAL_SFX,
        "representative_audio_stream_mix": false,
        "representative_projectile_entities": false,
        "authored_boss_pattern_timing": false,
    }


func _runtime_driver_coverage() -> Dictionary:
    if _gameplay == null:
        return {"decision_movement_driver_count": 0, "telegraph_presenter_count": 0}
    var host := _gameplay.tower_encounter_session_host
    var driver_count := 0
    var admissions := host.shared_full_ai.get_debug_snapshot().get("admissions", []) as Array
    for admission_variant: Variant in admissions:
        if not admission_variant is Dictionary:
            continue
        var admission := admission_variant as Dictionary
        var encounter_id := StringName(String(admission.get("encounter_id", &"")))
        var actor_id := StringName(String(admission.get("actor_id", &"")))
        var decision_driver := host.get_decision_driver(encounter_id, actor_id)
        var movement_driver := host.get_movement_driver(encounter_id, actor_id)
        if decision_driver != null and movement_driver != null and movement_driver.navigation_agent != null:
            driver_count += 1
    return {
        "decision_movement_driver_count": driver_count,
        "telegraph_presenter_count": _count_effect_presenters(host),
    }


func _count_effect_presenters(root_node: Node) -> int:
    if root_node == null:
        return 0
    var count := 0
    var pending: Array[Node] = [root_node]
    while not pending.is_empty():
        var current: Node = pending.pop_back()
        if current is EffectSpritePresenter:
            count += 1
        for child: Node in current.get_children():
            pending.append(child)
    return count


func _route_is_complete(coverage: Dictionary) -> bool:
    for key: String in [
        "max_12_full_ai",
        "overlapping_encounters",
        "navigation_ai",
        "enemy_telegraph_vfx",
        "foreground_occlusion",
        "ui_at_max_scale",
        "audio_admission_budget",
        "representative_audio_stream_mix",
        "representative_projectile_entities",
        "authored_boss_pattern_timing",
    ]:
        if not bool(coverage.get(key, false)):
            return false
    return true


func _parse_user_args() -> void:
    for arg: String in OS.get_cmdline_user_args():
        if arg.begins_with("--warmup-seconds="):
            _warmup_seconds = maxf(0.0, float(arg.trim_prefix("--warmup-seconds=")))
        elif arg.begins_with("--sample-seconds="):
            _sample_seconds = maxf(1.0, float(arg.trim_prefix("--sample-seconds=")))


func _cleanup() -> void:
    for token: int in _qa_audio_slot_tokens:
        AudioService.release_important_positional_slot(token)
    _qa_audio_slot_tokens.clear()
    if _gameplay != null and is_instance_valid(_gameplay):
        _gameplay.tower_encounter_session_host.end_all_encounters()
        _gameplay.queue_free()


func _finish_with_error(message: String) -> void:
    push_error("QA_PERF_WORST_SETUP_FAILED: %s" % message)
    _cleanup()
    get_tree().quit(2)
