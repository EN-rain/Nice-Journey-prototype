class_name ActionStateMachine
extends Node

enum Phase {
    IDLE,
    STARTUP,
    COMMIT,
    ACTIVE,
    RECOVERY,
}

signal action_started(action_id: StringName, action_instance_id: int)
signal action_buffered(action_id: StringName, expires_in_ticks: int)
signal action_rejected(action_id: StringName, reason: String)
signal action_cancelled(action_id: StringName, action_instance_id: int, reason: String)
signal action_interrupted(action_id: StringName, action_instance_id: int, reason_id: StringName)
signal phase_changed(action_id: StringName, action_instance_id: int, phase: int)
signal aim_lock_reached(action: ActionDefinition, action_instance_id: int, allow_tracking_after_lock: bool)
signal action_commit_point_reached(action: ActionDefinition, action_instance_id: int)
signal action_finished(action_id: StringName, action_instance_id: int)

var _phase: Phase = Phase.IDLE
var _phase_elapsed_ticks: int = 0
var _current_action: ActionDefinition = null
var _current_instance_id: int = 0
var _next_instance_id: int = 1
var _buffered_action: ActionDefinition = null
var _buffer_ticks_remaining: int = 0
var _buffered_aim_sample: Vector2 = Vector2.ZERO
var _cooldowns: Dictionary = {}
var _resource_pool: ResourcePool = null
var _aim_lock_emitted: bool = false
var _current_aim_sample: Vector2 = Vector2.ZERO
var _locked_aim_sample: Vector2 = Vector2.ZERO
var _has_locked_aim_sample: bool = false

func _physics_process(_delta: float) -> void:
    advance_fixed_tick()

func set_resource_pool(resource_pool: ResourcePool) -> void:
    _resource_pool = resource_pool

func request_action(action: ActionDefinition, aim_sample: Vector2 = Vector2.ZERO) -> bool:
    var errors: PackedStringArray = action.validate_definition()
    if not errors.is_empty():
        action_rejected.emit(action.action_id, ", ".join(errors))
        return false

    if not _has_startup_resources(action):
        action_rejected.emit(action.action_id, "insufficient_resource")
        return false

    if _phase == Phase.IDLE:
        if get_cooldown_ticks(action.action_id) > 0:
            action_rejected.emit(action.action_id, "cooldown")
            return false
        _start_action(action, aim_sample)
        return true

    if _current_action != null and _current_action.permits_cancel_from_phase(int(_phase), action.action_id):
        if get_cooldown_ticks(action.action_id) > 0:
            action_rejected.emit(action.action_id, "cooldown")
            return false
        clear_buffer()
        _cancel_current_action("authored_cancel:%s" % String(action.action_id))
        _start_action(action, aim_sample)
        return true

    _buffered_action = action
    _buffer_ticks_remaining = action.buffer_lifetime_ticks
    _buffered_aim_sample = aim_sample
    action_buffered.emit(action.action_id, _buffer_ticks_remaining)
    return false

func clear_buffer() -> void:
    _buffered_action = null
    _buffer_ticks_remaining = 0
    _buffered_aim_sample = Vector2.ZERO

func try_update_aim_sample(aim_sample: Vector2) -> bool:
    if _current_action == null or not _current_action.uses_aim:
        return false
    if _has_locked_aim_sample and not _current_action.allow_aim_tracking_after_lock:
        return false
    _current_aim_sample = aim_sample
    return true

func has_locked_aim_sample() -> bool:
    return _has_locked_aim_sample

func get_locked_aim_sample() -> Vector2:
    return _locked_aim_sample

func get_current_aim_sample() -> Vector2:
    return _current_aim_sample

func force_interrupt(reason_id: StringName) -> bool:
    if _current_action == null or String(reason_id).strip_edges().is_empty():
        return false
    var interrupted_action_id: StringName = _current_action.action_id
    var interrupted_instance_id: int = _current_instance_id
    _current_action = null
    _current_instance_id = 0
    _phase = Phase.IDLE
    _phase_elapsed_ticks = 0
    _aim_lock_emitted = false
    _current_aim_sample = Vector2.ZERO
    _locked_aim_sample = Vector2.ZERO
    _has_locked_aim_sample = false
    action_interrupted.emit(interrupted_action_id, interrupted_instance_id, reason_id)
    return true

func advance_fixed_tick() -> void:
    _tick_cooldowns()
    _tick_buffer()

    if _phase == Phase.IDLE:
        _try_start_buffered_action()
        return

    _phase_elapsed_ticks += 1
    if _phase_elapsed_ticks < _phase_duration(_phase):
        return

    match _phase:
        Phase.STARTUP:
            _try_enter_commit()
        Phase.COMMIT:
            _enter_phase(Phase.ACTIVE)
        Phase.ACTIVE:
            _enter_phase(Phase.RECOVERY)
            _skip_zero_duration_recovery_if_needed()
        Phase.RECOVERY:
            _finish_current_action()

func is_busy() -> bool:
    return _phase != Phase.IDLE

func get_phase() -> Phase:
    return _phase

func get_current_action_id() -> StringName:
    return &"" if _current_action == null else _current_action.action_id

func get_current_instance_id() -> int:
    return _current_instance_id

func get_phase_elapsed_ticks() -> int:
    return _phase_elapsed_ticks

func get_phase_duration_ticks() -> int:
    if _phase == Phase.IDLE:
        return 0
    return _phase_duration(_phase)

func get_buffered_action_id() -> StringName:
    return &"" if _buffered_action == null else _buffered_action.action_id

func get_buffer_ticks_remaining() -> int:
    return _buffer_ticks_remaining

func get_allowed_cancel_action_ids() -> Array[StringName]:
    var allowed: Array[StringName] = []
    if _current_action == null:
        return allowed
    for incoming_action_id: StringName in _current_action.permitted_cancel_action_ids:
        if _current_action.permits_cancel_from_phase(int(_phase), incoming_action_id):
            allowed.append(incoming_action_id)
    return allowed

func current_action_uses_aim() -> bool:
    return _current_action != null and _current_action.uses_aim

func current_action_allows_aim_tracking_after_lock() -> bool:
    return _current_action != null and _current_action.uses_aim and _current_action.allow_aim_tracking_after_lock

func get_cooldown_ticks(action_id: StringName) -> int:
    return int(_cooldowns.get(action_id, 0))

func capture_cooldown_state() -> Dictionary:
    var result: Dictionary = {}
    var action_ids: Array = _cooldowns.keys()
    action_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    for raw_id: Variant in action_ids:
        var action_id := StringName(String(raw_id))
        var remaining := int(_cooldowns.get(raw_id, 0))
        if StableId.is_valid(String(action_id)) and remaining > 0:
            result[String(action_id)] = remaining
    return result

func restore_cooldown_state(raw_state: Variant) -> bool:
    if not raw_state is Dictionary:
        return false
    var candidate: Dictionary = {}
    for raw_id: Variant in (raw_state as Dictionary).keys():
        var action_id := StringName(String(raw_id))
        var raw_ticks: Variant = (raw_state as Dictionary)[raw_id]
        if not StableId.is_valid(String(action_id)) or not _is_integral_nonnegative(raw_ticks):
            return false
        if int(raw_ticks) > 0:
            candidate[action_id] = int(raw_ticks)
    _cooldowns = candidate
    return true

func _is_integral_nonnegative(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return int(value) >= 0
    if typeof(value) != TYPE_FLOAT:
        return false
    var number := float(value)
    return is_finite(number) and number >= 0.0 and is_equal_approx(number, round(number))

func _start_action(action: ActionDefinition, aim_sample: Vector2) -> void:
    _current_action = action
    _current_instance_id = _next_instance_id
    _next_instance_id += 1
    _aim_lock_emitted = false
    _current_aim_sample = aim_sample
    _locked_aim_sample = Vector2.ZERO
    _has_locked_aim_sample = false
    _phase = Phase.STARTUP
    _phase_elapsed_ticks = 0
    action_started.emit(action.action_id, _current_instance_id)
    phase_changed.emit(action.action_id, _current_instance_id, int(_phase))
    _maybe_emit_aim_lock()
    _skip_zero_duration_startup_if_needed()

func _enter_phase(next_phase: Phase) -> void:
    _phase = next_phase
    _phase_elapsed_ticks = 0
    if _current_action != null:
        phase_changed.emit(_current_action.action_id, _current_instance_id, int(_phase))
        _maybe_emit_aim_lock()


func _skip_zero_duration_startup_if_needed() -> void:
    if _current_action != null and _phase == Phase.STARTUP and _current_action.startup_ticks == 0:
        _try_enter_commit()

func _skip_zero_duration_recovery_if_needed() -> void:
    if _current_action != null and _phase == Phase.RECOVERY and _current_action.recovery_ticks == 0:
        _finish_current_action()

func _try_enter_commit() -> void:
    if _current_action == null:
        return
    if not _spend_commit_resource(_current_action):
        _cancel_current_action("insufficient_resource_at_commit")
        return
    _enter_phase(Phase.COMMIT)
    if _current_action.cooldown_ticks > 0:
        _cooldowns[_current_action.action_id] = _current_action.cooldown_ticks
    action_commit_point_reached.emit(_current_action, _current_instance_id)

func _has_startup_resources(action: ActionDefinition) -> bool:
    if action.cost_amount <= 0.0:
        return true
    if _resource_pool == null or not _resource_pool.has_resource(action.cost_resource):
        return false
    return _resource_pool.can_spend(action.cost_resource, action.cost_amount)

func _spend_commit_resource(action: ActionDefinition) -> bool:
    if action.cost_amount <= 0.0:
        return true
    if _resource_pool == null:
        return false
    return _resource_pool.try_spend(action.cost_resource, action.cost_amount)

func _cancel_current_action(reason: String) -> void:
    if _current_action == null:
        return
    var cancelled_action_id: StringName = _current_action.action_id
    var cancelled_instance_id: int = _current_instance_id
    _current_action = null
    _current_instance_id = 0
    _phase = Phase.IDLE
    _phase_elapsed_ticks = 0
    _aim_lock_emitted = false
    _current_aim_sample = Vector2.ZERO
    _locked_aim_sample = Vector2.ZERO
    _has_locked_aim_sample = false
    action_cancelled.emit(cancelled_action_id, cancelled_instance_id, reason)

func _finish_current_action() -> void:
    if _current_action == null:
        _phase = Phase.IDLE
        return
    var finished_action_id: StringName = _current_action.action_id
    var finished_instance_id: int = _current_instance_id
    _current_action = null
    _current_instance_id = 0
    _phase = Phase.IDLE
    _phase_elapsed_ticks = 0
    _aim_lock_emitted = false
    _current_aim_sample = Vector2.ZERO
    _locked_aim_sample = Vector2.ZERO
    _has_locked_aim_sample = false
    action_finished.emit(finished_action_id, finished_instance_id)

func _try_start_buffered_action() -> void:
    if _buffered_action == null:
        return
    if _buffer_ticks_remaining <= 0:
        clear_buffer()
        return
    if get_cooldown_ticks(_buffered_action.action_id) > 0:
        return
    if not _has_startup_resources(_buffered_action):
        var rejected_id: StringName = _buffered_action.action_id
        clear_buffer()
        action_rejected.emit(rejected_id, "insufficient_resource")
        return
    var pending: ActionDefinition = _buffered_action
    var pending_aim_sample: Vector2 = _buffered_aim_sample
    clear_buffer()
    _start_action(pending, pending_aim_sample)

func _tick_buffer() -> void:
    if _buffered_action == null:
        return
    _buffer_ticks_remaining -= 1
    if _buffer_ticks_remaining <= 0:
        clear_buffer()

func _tick_cooldowns() -> void:
    var action_ids: Array = _cooldowns.keys()
    for action_id_variant: Variant in action_ids:
        var action_id: StringName = StringName(action_id_variant)
        var remaining: int = int(_cooldowns.get(action_id, 0)) - 1
        if remaining <= 0:
            _cooldowns.erase(action_id)
        else:
            _cooldowns[action_id] = remaining

func _phase_duration(phase: Phase) -> int:
    if _current_action == null:
        return 0
    match phase:
        Phase.STARTUP:
            return maxi(1, _current_action.startup_ticks)
        Phase.COMMIT:
            return maxi(1, _current_action.commit_ticks)
        Phase.ACTIVE:
            return maxi(1, _current_action.active_ticks)
        Phase.RECOVERY:
            return maxi(1, _current_action.recovery_ticks)
        _:
            return 0

func _maybe_emit_aim_lock() -> void:
    if _aim_lock_emitted or _current_action == null or not _current_action.uses_aim:
        return
    var matches_lock_point: bool = false
    match _current_action.aim_lock_point:
        ActionDefinition.AimLockPoint.STARTUP:
            matches_lock_point = _phase == Phase.STARTUP
        ActionDefinition.AimLockPoint.COMMIT:
            matches_lock_point = _phase == Phase.COMMIT
        ActionDefinition.AimLockPoint.ACTIVE:
            matches_lock_point = _phase == Phase.ACTIVE
    if not matches_lock_point:
        return
    _locked_aim_sample = _current_aim_sample
    _has_locked_aim_sample = true
    _aim_lock_emitted = true
    aim_lock_reached.emit(
        _current_action,
        _current_instance_id,
        _current_action.allow_aim_tracking_after_lock
    )
