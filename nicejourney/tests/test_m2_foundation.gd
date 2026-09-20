extends SceneTree

var _failures: int = 0
var _commit_count: int = 0
var _last_commit_instance: int = 0
var _aim_lock_count: int = 0
var _last_aim_lock_action_id: StringName = &""
var _last_aim_lock_tracking: bool = false
var _phase_seen_at_action_started: int = -1
var _interrupt_count: int = 0
var _last_interrupt_reason: StringName = &""
var _interrupted_finished_count: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var machine: ActionStateMachine = ActionStateMachine.new()
    machine.action_commit_point_reached.connect(_on_commit)
    machine.aim_lock_reached.connect(_on_aim_lock)
    machine.action_started.connect(_on_action_started.bind(machine))

    var primary: ActionDefinition = _make_action(&"test:primary", 2, 1, 2, 2, 5, 20)
    var followup: ActionDefinition = _make_action(&"test:followup", 1, 1, 1, 1, 0, 20)

    _expect(primary.validate_definition().is_empty(), "typed action data validates")
    _expect(machine.request_action(primary), "idle action request starts immediately")
    _expect(machine.get_phase() == ActionStateMachine.Phase.STARTUP, "action begins in startup")
    _expect(_phase_seen_at_action_started == ActionStateMachine.Phase.STARTUP, "action_started observers see the action in Startup, not stale Idle state")
    _expect(machine.get_phase_elapsed_ticks() == 0 and machine.get_phase_duration_ticks() == 2, "action timing is observable for the current phase")

    machine.advance_fixed_tick()
    _expect(machine.get_phase() == ActionStateMachine.Phase.STARTUP, "startup lasts its authored fixed ticks")
    machine.advance_fixed_tick()
    _expect(machine.get_phase() == ActionStateMachine.Phase.COMMIT, "startup transitions to commit at the fixed boundary")
    _expect(_commit_count == 1, "commit point emits exactly once")
    _expect(machine.get_cooldown_ticks(primary.action_id) == 5, "cooldown starts at commitment")
    _expect(_last_commit_instance > 0, "action instance IDs are explicit")

    var immediate_followup: bool = machine.request_action(followup)
    _expect(not immediate_followup, "busy action cannot be silently cancelled by another request")
    _expect(machine.get_buffered_action_id() == followup.action_id and machine.get_buffer_ticks_remaining() == followup.buffer_lifetime_ticks, "buffered intent ID and expiry are observable")

    for tick: int in range(4):
        machine.advance_fixed_tick()
    _expect(machine.is_busy(), "buffered follow-up waits until recovery completes")
    machine.advance_fixed_tick()
    _expect(not machine.is_busy(), "primary action finishes after recovery")
    machine.advance_fixed_tick()
    _expect(machine.get_current_action_id() == followup.action_id, "one buffered action starts after the prior action completes")

    var startup_cancel_machine: ActionStateMachine = ActionStateMachine.new()
    var startup_cancellable: ActionDefinition = _make_action(&"test:startup_cancellable", 3, 1, 1, 1, 0, 10)
    var authored_dodge: ActionDefinition = _make_action(&"test:authored_dodge", 1, 1, 1, 1, 0, 10)
    startup_cancellable.cancellable_phase_mask = 1
    startup_cancellable.permitted_cancel_action_ids = [&"test:authored_dodge"]
    _expect(startup_cancel_machine.request_action(startup_cancellable), "startup-cancellable action begins normally")
    _expect(startup_cancel_machine.get_allowed_cancel_action_ids() == [&"test:authored_dodge"], "current authored cancel options are observable")
    _expect(startup_cancel_machine.request_action(authored_dodge), "explicitly authored startup cancel transitions immediately")
    _expect(startup_cancel_machine.get_current_action_id() == authored_dodge.action_id, "authored cancel replaces the prior action only in its declared window")

    var committed_cancel_machine: ActionStateMachine = ActionStateMachine.new()
    var committed_source: ActionDefinition = _make_action(&"test:committed_source", 1, 1, 1, 2, 0, 10)
    committed_source.cancellable_phase_mask = 1 | 8
    committed_source.permitted_cancel_action_ids = [&"test:authored_dodge"]
    committed_cancel_machine.request_action(committed_source)
    committed_cancel_machine.advance_fixed_tick()
    _expect(committed_cancel_machine.get_phase() == ActionStateMachine.Phase.COMMIT, "cancel test reaches committed phase")
    _expect(not committed_cancel_machine.request_action(authored_dodge), "commit phase does not cancel when only startup/recovery were authored")
    _expect(committed_cancel_machine.get_current_action_id() == committed_source.action_id, "disallowed cancel remains buffered without replacing committed action")
    committed_cancel_machine.clear_buffer()
    committed_cancel_machine.advance_fixed_tick()
    committed_cancel_machine.advance_fixed_tick()
    _expect(committed_cancel_machine.get_phase() == ActionStateMachine.Phase.RECOVERY, "cancel test reaches authored recovery window")
    _expect(committed_cancel_machine.request_action(authored_dodge), "authored recovery cancel transitions immediately")
    _expect(committed_cancel_machine.get_current_action_id() == authored_dodge.action_id, "recovery cancel starts the declared follow-up action")

    var expiring_machine: ActionStateMachine = ActionStateMachine.new()
    var long_action: ActionDefinition = _make_action(&"test:long", 4, 1, 1, 3, 0, 3)
    var short_buffer: ActionDefinition = _make_action(&"test:expired", 1, 1, 1, 1, 0, 2)
    expiring_machine.request_action(long_action)
    expiring_machine.request_action(short_buffer)
    for tick: int in range(10):
        expiring_machine.advance_fixed_tick()
    _expect(expiring_machine.get_current_action_id() != short_buffer.action_id, "expired buffered intent is not executed later")

    var invalid: ActionDefinition = ActionDefinition.new()
    invalid.action_id = &""
    invalid.commit_ticks = 0
    _expect(not invalid.validate_definition().is_empty(), "invalid action data fails before gameplay admission")

    var invalid_aim: ActionDefinition = _make_action(&"test:invalid_aim", 1, 1, 1, 1, 0, 8)
    invalid_aim.allow_aim_tracking_after_lock = true
    _expect(not invalid_aim.validate_definition().is_empty(), "aim tracking cannot be authored on an action that does not use aim")

    var aimed_machine: ActionStateMachine = ActionStateMachine.new()
    aimed_machine.aim_lock_reached.connect(_on_aim_lock)
    var aimed_action: ActionDefinition = _make_action(&"test:aimed", 2, 1, 1, 1, 0, 8)
    aimed_action.uses_aim = true
    aimed_action.aim_lock_point = ActionDefinition.AimLockPoint.COMMIT
    aimed_action.allow_aim_tracking_after_lock = false
    _aim_lock_count = 0
    _last_aim_lock_action_id = &""
    _last_aim_lock_tracking = true
    _expect(aimed_machine.request_action(aimed_action, Vector2.RIGHT), "aimed action starts without inventing class-specific combat behavior")
    _expect(aimed_machine.current_action_uses_aim() and not aimed_machine.current_action_allows_aim_tracking_after_lock(), "aim usage and post-lock tracking policy are observable")
    _expect(_aim_lock_count == 0, "commit-locked aim is not sampled during startup")
    _expect(aimed_machine.try_update_aim_sample(Vector2.UP), "aim can update before the declared lock boundary")
    aimed_machine.advance_fixed_tick()
    _expect(_aim_lock_count == 0, "aim remains unlocked before the declared commit boundary")
    aimed_machine.advance_fixed_tick()
    _expect(_aim_lock_count == 1 and _last_aim_lock_action_id == aimed_action.action_id, "declared aim-lock point emits exactly at commitment")
    _expect(aimed_machine.has_locked_aim_sample() and aimed_machine.get_locked_aim_sample() == Vector2.UP, "aim lock retains the exact sample owned by this action instance")
    _expect(not _last_aim_lock_tracking, "aim-lock signal reports that tracking after lock is not authored")
    _expect(not aimed_machine.try_update_aim_sample(Vector2.LEFT) and aimed_machine.get_current_aim_sample() == Vector2.UP, "unauthorized post-lock retargeting is rejected")
    aimed_machine.advance_fixed_tick()
    aimed_machine.advance_fixed_tick()
    _expect(_aim_lock_count == 1, "aim-lock event emits only once per action instance")

    var startup_aim_machine: ActionStateMachine = ActionStateMachine.new()
    startup_aim_machine.aim_lock_reached.connect(_on_aim_lock)
    var tracking_action: ActionDefinition = _make_action(&"test:tracking_aim", 1, 1, 1, 1, 0, 8)
    tracking_action.uses_aim = true
    tracking_action.aim_lock_point = ActionDefinition.AimLockPoint.STARTUP
    tracking_action.allow_aim_tracking_after_lock = true
    _aim_lock_count = 0
    _last_aim_lock_tracking = false
    _expect(startup_aim_machine.request_action(tracking_action, Vector2(0.25, 0.75)), "startup aim-lock action is admitted")
    _expect(_aim_lock_count == 1 and _last_aim_lock_tracking, "startup aim lock emits immediately and preserves authored tracking permission")
    _expect(startup_aim_machine.get_locked_aim_sample() == Vector2(0.25, 0.75), "startup aim lock snapshots the request sample immediately")
    _expect(startup_aim_machine.try_update_aim_sample(Vector2.LEFT), "authored post-lock tracking accepts a new current aim sample")
    _expect(startup_aim_machine.get_current_aim_sample() == Vector2.LEFT and startup_aim_machine.get_locked_aim_sample() == Vector2(0.25, 0.75), "post-lock tracking does not overwrite the immutable lock sample")

    var consecutive_aim_machine: ActionStateMachine = ActionStateMachine.new()
    var consecutive_action: ActionDefinition = _make_action(&"test:consecutive_aim", 1, 1, 1, 0, 0, 8)
    consecutive_action.uses_aim = true
    consecutive_action.aim_lock_point = ActionDefinition.AimLockPoint.STARTUP
    _expect(consecutive_aim_machine.request_action(consecutive_action, Vector2.RIGHT), "first consecutive aimed action starts")
    var first_aim_instance: int = consecutive_aim_machine.get_current_instance_id()
    _expect(consecutive_aim_machine.get_locked_aim_sample() == Vector2.RIGHT, "first action instance owns its aim sample")
    consecutive_aim_machine.advance_fixed_tick()
    consecutive_aim_machine.advance_fixed_tick()
    consecutive_aim_machine.advance_fixed_tick()
    _expect(not consecutive_aim_machine.is_busy(), "first consecutive aimed action completes")
    _expect(consecutive_aim_machine.request_action(consecutive_action, Vector2.LEFT), "second consecutive aimed action starts")
    _expect(consecutive_aim_machine.get_current_instance_id() != first_aim_instance and consecutive_aim_machine.get_locked_aim_sample() == Vector2.LEFT, "consecutive action instances cannot share a stale aim sample")

    var buffered_aim_machine: ActionStateMachine = ActionStateMachine.new()
    var blocking_action: ActionDefinition = _make_action(&"test:blocking", 1, 1, 1, 0, 0, 8)
    var buffered_aim_action: ActionDefinition = _make_action(&"test:buffered_aim", 1, 1, 1, 0, 0, 8)
    buffered_aim_action.uses_aim = true
    buffered_aim_action.aim_lock_point = ActionDefinition.AimLockPoint.STARTUP
    buffered_aim_machine.request_action(blocking_action)
    _expect(not buffered_aim_machine.request_action(buffered_aim_action, Vector2.DOWN), "busy machine buffers the aimed follow-up intent")
    buffered_aim_machine.advance_fixed_tick()
    buffered_aim_machine.advance_fixed_tick()
    buffered_aim_machine.advance_fixed_tick()
    buffered_aim_machine.advance_fixed_tick()
    _expect(buffered_aim_machine.get_current_action_id() == buffered_aim_action.action_id and buffered_aim_machine.get_locked_aim_sample() == Vector2.DOWN, "buffered action retains its own request aim sample when its instance starts")

    var interrupt_machine: ActionStateMachine = ActionStateMachine.new()
    var interrupt_action: ActionDefinition = _make_action(&"test:interruptible", 4, 1, 1, 1, 0, 8)
    interrupt_machine.action_interrupted.connect(_on_interrupted)
    interrupt_machine.action_finished.connect(_on_interrupted_machine_finished)
    _interrupt_count = 0
    _last_interrupt_reason = &""
    _interrupted_finished_count = 0
    _expect(interrupt_machine.request_action(interrupt_action), "generic forced-interruption fixture action starts")
    var interrupted_instance_id: int = interrupt_machine.get_current_instance_id()
    _expect(interrupt_machine.force_interrupt(&"test:forced_interrupt"), "generic forced interruption terminates the current action")
    _expect(_interrupt_count == 1 and _last_interrupt_reason == &"test:forced_interrupt", "forced interruption emits exactly one terminal reason")
    _expect(not interrupt_machine.is_busy() and interrupt_machine.get_current_instance_id() == 0, "forced interruption leaves the machine idle")
    _expect(not interrupt_machine.force_interrupt(&"test:duplicate") and _interrupt_count == 1, "an already-terminated action cannot emit a duplicate interruption")
    interrupt_machine.advance_fixed_tick()
    _expect(_interrupted_finished_count == 0, "forced interruption does not later emit normal completion")
    _expect(interrupted_instance_id > 0, "forced interruption reports an explicit action instance")

    var zero_recovery_machine: ActionStateMachine = ActionStateMachine.new()
    var zero_recovery_action: ActionDefinition = _make_action(&"test:zero_recovery", 1, 1, 1, 0, 0, 8)
    _expect(zero_recovery_machine.request_action(zero_recovery_action), "zero-recovery action is admitted")
    zero_recovery_machine.advance_fixed_tick()
    zero_recovery_machine.advance_fixed_tick()
    zero_recovery_machine.advance_fixed_tick()
    _expect(not zero_recovery_machine.is_busy(), "authored zero recovery completes at the active boundary without adding a hidden tick")

    var resource_pool: ResourcePool = ResourcePool.new()
    _expect(resource_pool.define_resource(&"stamina", 100.0), "generic action resources are explicitly defined")
    var resource_machine: ActionStateMachine = ActionStateMachine.new()
    resource_machine.set_resource_pool(resource_pool)
    var costed_action: ActionDefinition = _make_action(&"test:costed", 2, 1, 1, 1, 4, 10)
    costed_action.cost_resource = &"stamina"
    costed_action.cost_amount = 25.0
    _expect(resource_machine.request_action(costed_action), "resource-backed action is admitted when startup eligibility passes")
    _expect(is_equal_approx(resource_pool.get_value(&"stamina"), 100.0), "startup eligibility does not spend the resource early")
    resource_machine.advance_fixed_tick()
    _expect(is_equal_approx(resource_pool.get_value(&"stamina"), 100.0), "resource remains unspent before commitment")
    resource_machine.advance_fixed_tick()
    _expect(is_equal_approx(resource_pool.get_value(&"stamina"), 75.0), "resource spends exactly at the commit boundary")
    resource_machine.advance_fixed_tick()
    resource_machine.advance_fixed_tick()
    _expect(is_equal_approx(resource_pool.get_value(&"stamina"), 75.0), "later action phases do not double-spend")

    var revalidation_pool: ResourcePool = ResourcePool.new()
    revalidation_pool.define_resource(&"stamina", 30.0)
    var revalidation_machine: ActionStateMachine = ActionStateMachine.new()
    revalidation_machine.set_resource_pool(revalidation_pool)
    var revalidation_action: ActionDefinition = _make_action(&"test:revalidate", 2, 1, 1, 1, 6, 10)
    revalidation_action.cost_resource = &"stamina"
    revalidation_action.cost_amount = 25.0
    _expect(revalidation_machine.request_action(revalidation_action), "resource eligibility can be reserved at startup without spending")
    revalidation_pool.set_value(&"stamina", 10.0)
    revalidation_machine.advance_fixed_tick()
    revalidation_machine.advance_fixed_tick()
    _expect(not revalidation_machine.is_busy(), "failed commit revalidation cancels before active frames")
    _expect(is_equal_approx(revalidation_pool.get_value(&"stamina"), 10.0), "failed commit revalidation does not overdraft or partially spend")
    _expect(revalidation_machine.get_cooldown_ticks(revalidation_action.action_id) == 0, "failed commit does not start cooldown")

    var insufficient_pool: ResourcePool = ResourcePool.new()
    insufficient_pool.define_resource(&"stamina", 10.0)
    var insufficient_machine: ActionStateMachine = ActionStateMachine.new()
    insufficient_machine.set_resource_pool(insufficient_pool)
    _expect(not insufficient_machine.request_action(costed_action), "insufficient startup resource rejects before action admission")

    machine.free()
    startup_cancel_machine.free()
    committed_cancel_machine.free()
    expiring_machine.free()
    resource_machine.free()
    revalidation_machine.free()
    insufficient_machine.free()
    aimed_machine.free()
    startup_aim_machine.free()
    consecutive_aim_machine.free()
    buffered_aim_machine.free()
    interrupt_machine.free()
    zero_recovery_machine.free()

    if _failures == 0:
        print("M2 FOUNDATION TEST PASS")
    else:
        push_error("M2 FOUNDATION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _make_action(
    action_id: StringName,
    startup: int,
    commit: int,
    active: int,
    recovery: int,
    cooldown: int,
    buffer_lifetime: int
) -> ActionDefinition:
    var action: ActionDefinition = ActionDefinition.new()
    action.action_id = action_id
    action.startup_ticks = startup
    action.commit_ticks = commit
    action.active_ticks = active
    action.recovery_ticks = recovery
    action.cooldown_ticks = cooldown
    action.buffer_lifetime_ticks = buffer_lifetime
    return action

func _on_commit(_action: ActionDefinition, action_instance_id: int) -> void:
    _commit_count += 1
    _last_commit_instance = action_instance_id

func _on_aim_lock(action: ActionDefinition, _action_instance_id: int, allow_tracking_after_lock: bool) -> void:
    _aim_lock_count += 1
    _last_aim_lock_action_id = action.action_id
    _last_aim_lock_tracking = allow_tracking_after_lock

func _on_action_started(_action_id: StringName, _action_instance_id: int, machine: ActionStateMachine) -> void:
    _phase_seen_at_action_started = int(machine.get_phase())

func _on_interrupted(_action_id: StringName, _action_instance_id: int, reason_id: StringName) -> void:
    _interrupt_count += 1
    _last_interrupt_reason = reason_id

func _on_interrupted_machine_finished(_action_id: StringName, _action_instance_id: int) -> void:
    _interrupted_finished_count += 1

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
