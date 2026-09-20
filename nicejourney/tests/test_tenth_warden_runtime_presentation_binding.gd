extends SceneTree

const SCENE: PackedScene = preload("res://src/enemies/boss_tenth_warden/presentation/tenth_warden_visual.tscn")
const DEFAULT_TUNING: TenthWardenEncounterTuning = preload("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_encounter_default.tres")

var _failures := 0
var _weak_point_events: Array[bool] = []

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var visual := SCENE.instantiate() as TenthWardenVisualController
    root.add_child(visual)
    await process_frame

    var binder := visual.get_node_or_null("StatePresentationBinder") as TenthWardenPresentationStateBinder
    _expect(binder != null, "Tenth Warden visual scene owns the semantic state/presentation binder")
    _expect(binder != null and binder.visual == visual, "binder resolves the inspector-authored visual target")

    var state := TenthWardenEncounterState.new()
    _expect(state.configure(DEFAULT_TUNING), "authoritative boss state configures")
    _expect(binder.bind_state(state), "binder accepts the genuine Tenth Warden encounter state owner")
    binder.weak_point_presentation_requested.connect(_on_weak_point_presentation_requested)

    _expect(state.begin_committed_move(TenthWardenEncounterState.MOVE_TWIN_CUT), "authoritative state commits Twin Cut")
    _expect(visual.animation_player.current_animation == &"twin_cut", "committed move drives semantic AnimationPlayer presentation")
    _expect(state.begin_recovery(false), "Twin Cut enters recovery")
    _expect(state.finish_recovery(), "Twin Cut recovery finishes")
    _expect(visual.animation_player.current_animation == &"idle", "normal recovery completion returns presentation to idle")

    _expect(state.observe_health(50, 100), "phase threshold observation is accepted")
    _expect(state.transition_action_requested, "phase transition action becomes authoritative while idle")
    _expect(state.commit_phase_transition(), "authoritative phase transition commits")
    _expect(visual.animation_player.current_animation == &"phase_two", "phase transition commit drives the configured phase-two presentation")

    _expect(state.begin_committed_move(TenthWardenEncounterState.MOVE_WARDEN_LUNGE), "phase-two heavy move commits")
    _expect(visual.animation_player.current_animation == &"warden_lunge", "phase-two move uses its semantic presentation binding")
    _expect(state.begin_recovery(true), "phase-two heavy recovery begins")
    _expect(_weak_point_events == [true], "heavy phase-two recovery requests visible weak-point presentation exactly once")
    _expect(state.finish_recovery(), "phase-two heavy recovery finishes")
    _expect(_weak_point_events == [true, false], "weak-point presentation closes exactly when authored recovery ends")
    _expect(visual.animation_player.current_animation == &"idle", "post-recovery presentation returns to idle")

    binder.unbind_state()
    _expect(state.begin_committed_move(TenthWardenEncounterState.MOVE_ARC_VOLLEY), "state remains independently usable after presentation unbind")
    _expect(visual.animation_player.current_animation == &"idle", "unbound state no longer mutates presentation")

    var binder_source := FileAccess.get_file_as_string("res://src/enemies/boss_tenth_warden/presentation/tenth_warden_presentation_state_binder.gd")
    _expect(not binder_source.contains("res://assets/art"), "state/presentation binder contains no hardcoded art paths")
    _expect(not binder_source.contains("telegraph_") and not binder_source.contains("position =") and not binder_source.contains("rotation"), "binder does not invent boss telegraph geometry")

    visual.queue_free()
    await process_frame

    if _failures == 0:
        print("TENTH WARDEN RUNTIME PRESENTATION BINDING TEST PASS")
    else:
        push_error("TENTH WARDEN RUNTIME PRESENTATION BINDING TEST FAILURES: %d" % _failures)
    quit(_failures)

func _on_weak_point_presentation_requested(exposed: bool) -> void:
    _weak_point_events.append(exposed)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
