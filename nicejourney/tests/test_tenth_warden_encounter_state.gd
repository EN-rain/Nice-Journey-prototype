extends SceneTree

const DEFAULT_TUNING: TenthWardenEncounterTuning = preload("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_encounter_default.tres")

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _expect(DEFAULT_TUNING != null, "Tenth Warden default tuning resource loads")
    _expect(DEFAULT_TUNING.validate_tuning().is_empty(), "default phase threshold tuning validates")
    _expect(is_equal_approx(DEFAULT_TUNING.phase_transition_health_ratio, 0.5), "default phase transition threshold is the approved 50 percent")

    var state := TenthWardenEncounterState.new()
    _expect(state.configure(DEFAULT_TUNING), "encounter state accepts inspector-authored tuning")
    _expect(state.phase == TenthWardenEncounterState.PHASE_ONE, "boss begins in phase one")
    _expect(TenthWardenEncounterState.MOVE_IDS.size() == 5, "exactly five learned move families are exposed")

    for move_id: StringName in TenthWardenEncounterState.MOVE_IDS:
        _expect(state.get_locked_move_semantics(move_id).get("move_id", &"") == move_id, "%s has locked semantic identity" % String(move_id))
        _expect(state.can_begin_move(move_id, true), "%s is available from the shared learned move family set" % String(move_id))

    _expect(not state.can_begin_move(TenthWardenEncounterState.MOVE_PUNISHING_STEP, false), "Punishing Step rejects when the authored positioning condition is false")
    _expect(state.can_begin_move(TenthWardenEncounterState.MOVE_PUNISHING_STEP, true), "Punishing Step admits only when the authored positioning condition is true")
    _expect(not state.can_begin_move(&"secret_sixth_move", true), "unapproved sixth move family is rejected")

    var arc := state.get_locked_move_semantics(TenthWardenEncounterState.MOVE_ARC_VOLLEY)
    _expect(bool(arc.get("dodgeable", false)), "Arc Volley is dodgeable")
    _expect(bool(arc.get("blockable", false)), "Arc Volley is blockable")
    _expect(not bool(arc.get("parryable", true)), "Arc Volley is not parryable")
    _expect(bool(arc.get("projectile", false)), "Arc Volley is explicitly projectile pressure")

    var sweep := state.get_locked_move_semantics(TenthWardenEncounterState.MOVE_CRESCENT_SWEEP)
    _expect(bool(sweep.get("dodgeable", false)), "Crescent Sweep is dodgeable")
    _expect(not bool(sweep.get("blockable", true)), "Crescent Sweep is unblockable")
    _expect(not sweep.has("parryable"), "Crescent Sweep does not invent an unspecified parry rule")

    _expect(state.begin_committed_move(TenthWardenEncounterState.MOVE_TWIN_CUT), "phase-one committed move begins")
    _expect(state.observe_health(50, 100), "50 percent health observation is accepted")
    _expect(state.transition_pending, "phase transition becomes pending at threshold")
    _expect(not state.transition_action_requested, "transition waits while the current committed action is unfinished")
    _expect(state.begin_recovery(true), "current committed action enters recovery")
    _expect(not state.weak_point_exposed, "phase-one heavy recovery does not expose the phase-two weak point")
    _expect(state.finish_recovery(), "phase-one recovery finishes")
    _expect(state.transition_action_requested, "phase transition is requested only after current recovery finishes")
    _expect(not state.can_begin_move(TenthWardenEncounterState.MOVE_WARDEN_LUNGE), "normal moves are blocked while irreversible transition action is due")
    _expect(state.phase == TenthWardenEncounterState.PHASE_ONE, "requesting transition does not silently change phase")
    _expect(state.commit_phase_transition(), "non-damaging phase transition commits once")
    _expect(state.phase == TenthWardenEncounterState.PHASE_TWO, "boss enters phase two after explicit transition commit")
    _expect(state.transition_committed, "phase transition records irreversible completion")
    _expect(not state.commit_phase_transition(), "phase transition cannot commit twice")

    for move_id: StringName in TenthWardenEncounterState.MOVE_IDS:
        _expect(state.can_begin_move(move_id, true), "phase two reuses learned move family %s" % String(move_id))

    _expect(state.begin_committed_move(TenthWardenEncounterState.MOVE_WARDEN_LUNGE), "phase-two committed move begins")
    _expect(state.begin_recovery(true), "phase-two heavy committed move enters recovery")
    _expect(state.weak_point_exposed, "phase-two heavy committed recovery exposes the visible weak point")
    _expect(state.finish_recovery(), "phase-two heavy recovery finishes")
    _expect(not state.weak_point_exposed, "weak point closes when authored recovery ends")

    _expect(state.begin_committed_move(TenthWardenEncounterState.MOVE_TWIN_CUT), "phase-two non-heavy test move begins")
    _expect(state.begin_recovery(false), "phase-two non-heavy move enters recovery")
    _expect(not state.weak_point_exposed, "phase-two non-heavy recovery does not expose the weak point")
    _expect(state.finish_recovery(), "phase-two non-heavy recovery finishes")

    var idle_threshold_state := TenthWardenEncounterState.new()
    _expect(idle_threshold_state.configure(DEFAULT_TUNING), "second encounter state configures")
    _expect(idle_threshold_state.observe_health(49, 100), "below-threshold idle health observation is accepted")
    _expect(idle_threshold_state.transition_action_requested, "threshold reached while idle requests transition immediately without starting another attack")
    _expect(idle_threshold_state.phase == TenthWardenEncounterState.PHASE_ONE, "idle threshold request still requires explicit transition commit")

    var invalid_tuning := TenthWardenEncounterTuning.new()
    invalid_tuning.phase_transition_health_ratio = NAN
    _expect(not TenthWardenEncounterState.new().configure(invalid_tuning), "non-finite phase threshold tuning is rejected")
    _expect(not state.observe_health(-1, 100), "negative boss HP facts are rejected")
    _expect(not state.observe_health(101, 100), "boss HP above max is rejected")
    _expect(not state.observe_health(1, 0), "non-positive max HP is rejected")

    _expect(TenthWardenEncounterState.evaluate_terminal_outcome(false, false) == TenthWardenEncounterState.OUTCOME_ONGOING, "fight remains ongoing while both actors are alive")
    _expect(TenthWardenEncounterState.evaluate_terminal_outcome(false, true) == TenthWardenEncounterState.OUTCOME_VICTORY, "boss defeat commits victory only while player remains alive")
    _expect(TenthWardenEncounterState.evaluate_terminal_outcome(true, false) == TenthWardenEncounterState.OUTCOME_FAILED_ATTEMPT, "player defeat is a failed attempt")
    _expect(TenthWardenEncounterState.evaluate_terminal_outcome(true, true) == TenthWardenEncounterState.OUTCOME_FAILED_ATTEMPT, "simultaneous player/boss defeat is a failed attempt")

    var source := FileAccess.get_file_as_string("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_encounter_state.gd")
    _expect(not source.contains("func heal") and not source.contains("current_hp = max_hp") and not source.contains("reset_health"), "phase transition state does not invent healing/reset behavior")
    _expect(not source.contains("spawn_add"), "boss state does not invent mandatory adds")
    _expect(not source.contains("rand"), "boss state does not invent hidden RNG move selection")

    if _failures == 0:
        print("TENTH WARDEN ENCOUNTER STATE TEST PASS")
    else:
        push_error("TENTH WARDEN ENCOUNTER STATE TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
