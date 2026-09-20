class_name EnemySignatureActionPhaseDriver
extends RefCounted

signal active_delivery_window_opened(context: Dictionary)

const REASON_NOT_CONFIGURED: StringName = &"not_configured"
const REASON_BEGIN_REJECTED: StringName = &"begin_rejected"
const REASON_RUNTIME_DESYNC: StringName = &"runtime_desync"

var runtime: EnemyArchetypeRuntime = null
var timing: Dictionary = {}
var phase_ticks_remaining: int = 0
var cooldown_ticks_remaining: int = 0
var action_instance_id: int = 0

func configure(source_runtime: EnemyArchetypeRuntime, authored_timing: Dictionary) -> bool:
    if source_runtime == null or not source_runtime.is_configured() or not _timing_valid(authored_timing):
        return false
    runtime = source_runtime
    timing = authored_timing.duplicate(true)
    phase_ticks_remaining = 0
    cooldown_ticks_remaining = 0
    action_instance_id = 0
    return true

func begin(selection: Dictionary, new_action_instance_id: int, signature_facts: Dictionary = {}) -> Dictionary:
    if runtime == null:
        return _rejected(REASON_NOT_CONFIGURED)
    var result := runtime.begin_signature_action(selection, new_action_instance_id, signature_facts)
    if not bool(result.get("accepted", false)):
        var rejected := _rejected(REASON_BEGIN_REJECTED)
        rejected["runtime_reason_id"] = StringName(result.get("reason_id", &""))
        rejected["admission_reason_id"] = StringName(result.get("admission_reason_id", &""))
        return rejected
    action_instance_id = new_action_instance_id
    phase_ticks_remaining = int(timing["windup_ticks"])
    cooldown_ticks_remaining = 0
    return {
        "accepted": true,
        "reason_id": &"",
        "action_instance_id": action_instance_id,
        "phase_id": runtime.phase_id,
        "phase_ticks_remaining": phase_ticks_remaining,
    }

func cancel(reason_id: StringName = AttackReservationLedger.RELEASE_CANCELLATION) -> bool:
    if runtime == null or action_instance_id <= 0:
        return false
    if not runtime.cancel_action(reason_id):
        return false
    action_instance_id = 0
    phase_ticks_remaining = 0
    cooldown_ticks_remaining = int(timing.get("cooldown_ticks", 0))
    _reopen_if_cooldown_complete()
    return true

func advance_fixed_tick() -> bool:
    if runtime == null:
        return false
    if not runtime.is_tactical_eligible():
        runtime.reconcile_external_reservation_release()
        action_instance_id = 0
        phase_ticks_remaining = 0
        cooldown_ticks_remaining = 0
        return true
    if runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE:
        if action_instance_id > 0 or phase_ticks_remaining > 0:
            return false
        if cooldown_ticks_remaining > 0:
            cooldown_ticks_remaining -= 1
            _reopen_if_cooldown_complete()
        return true

    if action_instance_id <= 0 or phase_ticks_remaining <= 0:
        return false
    phase_ticks_remaining -= 1
    if phase_ticks_remaining > 0:
        return true

    match runtime.phase_id:
        EnemyArchetypeRuntime.PHASE_WINDUP:
            if not runtime.begin_active(action_instance_id):
                return false
            phase_ticks_remaining = int(timing["active_ticks"])
            var delivery_context := runtime.get_active_delivery_context(action_instance_id)
            if not bool(delivery_context.get("accepted", false)):
                return false
            active_delivery_window_opened.emit(delivery_context.duplicate(true))
        EnemyArchetypeRuntime.PHASE_ACTIVE:
            if not runtime.begin_recovery(action_instance_id):
                return false
            phase_ticks_remaining = int(timing["recovery_ticks"])
            if phase_ticks_remaining == 0:
                return _finish_recovery()
        EnemyArchetypeRuntime.PHASE_RECOVERY:
            return _finish_recovery()
        _:
            return false
    return true

func get_debug_snapshot() -> Dictionary:
    return {
        "configured": runtime != null,
        "actor_id": runtime.actor_id if runtime != null else &"",
        "phase_id": runtime.phase_id if runtime != null else EnemyArchetypeRuntime.PHASE_IDLE,
        "phase_ticks_remaining": phase_ticks_remaining,
        "cooldown_ticks_remaining": cooldown_ticks_remaining,
        "action_instance_id": action_instance_id,
        "cooldown_ready": runtime.cooldown_ready if runtime != null else false,
    }

func _finish_recovery() -> bool:
    if runtime == null or action_instance_id <= 0:
        return false
    if not runtime.finish_recovery(action_instance_id):
        return false
    action_instance_id = 0
    phase_ticks_remaining = 0
    cooldown_ticks_remaining = int(timing.get("cooldown_ticks", 0))
    _reopen_if_cooldown_complete()
    return true

func _reopen_if_cooldown_complete() -> void:
    if runtime != null and cooldown_ticks_remaining == 0 and not runtime.cooldown_ready and runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE:
        runtime.mark_cooldown_ready()

func _timing_valid(value: Dictionary) -> bool:
    for key: String in ["windup_ticks", "active_ticks", "recovery_ticks", "cooldown_ticks"]:
        if typeof(value.get(key, null)) != TYPE_INT or int(value[key]) < 0:
            return false
    return int(value["windup_ticks"]) > 0 and int(value["active_ticks"]) > 0

func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "runtime_reason_id": &"",
        "admission_reason_id": &"",
        "action_instance_id": 0,
        "phase_id": EnemyArchetypeRuntime.PHASE_IDLE,
        "phase_ticks_remaining": 0,
    }
