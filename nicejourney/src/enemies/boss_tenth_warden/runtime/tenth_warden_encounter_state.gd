class_name TenthWardenEncounterState
extends RefCounted

const PHASE_ONE: int = 1
const PHASE_TWO: int = 2
const ACTION_PHASE_TRANSITION: StringName = &"phase_transition"

const MOVE_TWIN_CUT: StringName = &"twin_cut"
const MOVE_WARDEN_LUNGE: StringName = &"warden_lunge"
const MOVE_ARC_VOLLEY: StringName = &"arc_volley"
const MOVE_CRESCENT_SWEEP: StringName = &"crescent_sweep"
const MOVE_PUNISHING_STEP: StringName = &"punishing_step"
const MOVE_IDS: Array[StringName] = [
    MOVE_TWIN_CUT,
    MOVE_WARDEN_LUNGE,
    MOVE_ARC_VOLLEY,
    MOVE_CRESCENT_SWEEP,
    MOVE_PUNISHING_STEP,
]

const OUTCOME_ONGOING: StringName = &"ongoing"
const OUTCOME_VICTORY: StringName = &"victory"
const OUTCOME_FAILED_ATTEMPT: StringName = &"failed_attempt"

signal move_committed(move_id: StringName)
signal recovery_started(move_id: StringName, weak_point_exposed: bool)
signal recovery_finished(move_id: StringName)
signal phase_transition_requested()
signal phase_transition_committed()
signal weak_point_exposure_changed(exposed: bool)

var tuning: TenthWardenEncounterTuning = null
var phase: int = PHASE_ONE
var transition_pending: bool = false
var transition_action_requested: bool = false
var transition_committed: bool = false
var active_move_id: StringName = &""
var recovery_active: bool = false
var weak_point_exposed: bool = false

func configure(new_tuning: TenthWardenEncounterTuning) -> bool:
    if new_tuning == null or not new_tuning.validate_tuning().is_empty():
        return false
    tuning = new_tuning
    return true

func observe_health(current_hp: int, max_hp: int) -> bool:
    if tuning == null or max_hp <= 0 or current_hp < 0 or current_hp > max_hp:
        return false
    if phase == PHASE_ONE and not transition_committed:
        var ratio := float(current_hp) / float(max_hp)
        if ratio <= tuning.phase_transition_health_ratio:
            transition_pending = true
            _refresh_transition_request()
    return true

func can_begin_move(move_id: StringName, positioning_condition_met: bool = true) -> bool:
    if not MOVE_IDS.has(move_id):
        return false
    if transition_action_requested or recovery_active or active_move_id != &"":
        return false
    if move_id == MOVE_PUNISHING_STEP and not positioning_condition_met:
        return false
    return true

func begin_committed_move(move_id: StringName, positioning_condition_met: bool = true) -> bool:
    if not can_begin_move(move_id, positioning_condition_met):
        return false
    active_move_id = move_id
    move_committed.emit(move_id)
    return true

func begin_recovery(is_heavy_committed_action: bool) -> bool:
    if active_move_id == &"" or recovery_active:
        return false
    recovery_active = true
    weak_point_exposed = phase == PHASE_TWO and is_heavy_committed_action
    if weak_point_exposed:
        weak_point_exposure_changed.emit(true)
    recovery_started.emit(active_move_id, weak_point_exposed)
    return true

func finish_recovery() -> bool:
    if not recovery_active:
        return false
    var finished_move_id := active_move_id
    recovery_active = false
    if weak_point_exposed:
        weak_point_exposed = false
        weak_point_exposure_changed.emit(false)
    active_move_id = &""
    recovery_finished.emit(finished_move_id)
    _refresh_transition_request()
    return true

func cancel_committed_move() -> bool:
    if active_move_id == &"":
        return false
    recovery_active = false
    if weak_point_exposed:
        weak_point_exposed = false
        weak_point_exposure_changed.emit(false)
    active_move_id = &""
    _refresh_transition_request()
    return true


func commit_phase_transition() -> bool:
    if phase != PHASE_ONE or transition_committed or not transition_action_requested:
        return false
    phase = PHASE_TWO
    transition_pending = false
    transition_action_requested = false
    transition_committed = true
    if weak_point_exposed:
        weak_point_exposed = false
        weak_point_exposure_changed.emit(false)
    phase_transition_committed.emit()
    return true

func get_locked_move_semantics(move_id: StringName) -> Dictionary:
    match move_id:
        MOVE_TWIN_CUT:
            return {
                "move_id": MOVE_TWIN_CUT,
                "move_family": &"close_two_hit_melee",
                "hit_count": 2,
            }
        MOVE_WARDEN_LUNGE:
            return {
                "move_id": MOVE_WARDEN_LUNGE,
                "move_family": &"straight_advancing_strike",
            }
        MOVE_ARC_VOLLEY:
            return {
                "move_id": MOVE_ARC_VOLLEY,
                "move_family": &"ranged_pressure_sequence",
                "dodgeable": true,
                "blockable": true,
                "parryable": false,
                "projectile": true,
            }
        MOVE_CRESCENT_SWEEP:
            return {
                "move_id": MOVE_CRESCENT_SWEEP,
                "move_family": &"wide_positional_sweep",
                "dodgeable": true,
                "blockable": false,
            }
        MOVE_PUNISHING_STEP:
            return {
                "move_id": MOVE_PUNISHING_STEP,
                "move_family": &"positioning_punish",
                "requires_positioning_condition": true,
            }
        _:
            return {}

func get_debug_snapshot() -> Dictionary:
    return {
        "phase": phase,
        "transition_pending": transition_pending,
        "transition_action_requested": transition_action_requested,
        "transition_committed": transition_committed,
        "active_move_id": active_move_id,
        "recovery_active": recovery_active,
        "weak_point_exposed": weak_point_exposed,
    }

static func evaluate_terminal_outcome(player_defeated: bool, boss_defeated: bool) -> StringName:
    if player_defeated:
        return OUTCOME_FAILED_ATTEMPT
    if boss_defeated:
        return OUTCOME_VICTORY
    return OUTCOME_ONGOING

func _refresh_transition_request() -> void:
    if not transition_pending or phase != PHASE_ONE or transition_committed:
        return
    if active_move_id == &"" and not recovery_active and not transition_action_requested:
        transition_action_requested = true
        phase_transition_requested.emit()
