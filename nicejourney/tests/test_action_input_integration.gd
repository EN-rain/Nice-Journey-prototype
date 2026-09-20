extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var gameplay: Node2D = GAMEPLAY_SCENE.instantiate() as Node2D
    root.add_child(gameplay)
    await process_frame

    var ownership: InputOwnership = gameplay.get_node("InputOwnership") as InputOwnership
    var coordinator: PauseCoordinator = gameplay.get_node("PauseCoordinator") as PauseCoordinator
    var machine: ActionStateMachine = gameplay.get_node("ActionStateMachine") as ActionStateMachine
    var intents: ActionIntentController = gameplay.get_node("ActionIntentController") as ActionIntentController
    machine.set_physics_process(false)

    var primary: ActionDefinition = _make_action(&"fixture:primary", 8, 1, 1, 1, 0, 20)
    var followup: ActionDefinition = _make_action(&"fixture:followup", 1, 1, 1, 1, 0, 20)
    var replacement: ActionDefinition = _make_action(&"fixture:replacement", 1, 1, 1, 1, 0, 20)

    _expect(intents.request_action(&"basic_attack", primary), "live action-intent boundary admits gameplay input when no modal owns it")
    _expect(not intents.request_action(&"skill_1", followup) and machine.get_buffered_action_id() == followup.action_id, "busy live action path buffers one replaceable follow-up")

    ownership.open_modal(&"inventory")
    _expect(machine.get_buffered_action_id() == &"", "opening a modal clears obsolete buffered combat intent")
    _expect(not intents.request_action(&"basic_attack", replacement), "modal ownership rejects new combat intent at the shared boundary")

    machine.request_action(followup)
    _expect(machine.get_buffered_action_id() == followup.action_id, "fixture can seed an obsolete buffered intent while modal ownership is active")
    ownership.close_modal(&"inventory", &"basic_attack")
    _expect(machine.get_buffered_action_id() == &"", "closing a modal also clears obsolete buffered combat intent")
    _expect(not intents.request_action(&"basic_attack", replacement) and machine.get_buffered_action_id() == &"", "closing combat input cannot pass through before its release")
    _expect(not intents.request_action(&"skill_1", followup) and machine.get_buffered_action_id() == followup.action_id, "unrelated gameplay input remains routable after modal close")

    ownership.notify_action_released(&"basic_attack")
    _expect(not intents.request_action(&"basic_attack", replacement) and machine.get_buffered_action_id() == replacement.action_id, "closing input becomes routable after its matching release")
    machine.clear_buffer()
    machine.force_interrupt(&"fixture:reset")

    var debug_action: ActionDefinition = _make_action(&"fixture:debug", 2, 1, 2, 2, 4, 12)
    debug_action.uses_aim = true
    debug_action.aim_lock_point = ActionDefinition.AimLockPoint.COMMIT
    debug_action.cancellable_phase_mask = 2
    debug_action.permitted_cancel_action_ids = [&"fixture:cancel"]
    _expect(intents.request_action(&"basic_attack", debug_action, Vector2.RIGHT), "debug fixture action starts through the live intent boundary")
    _expect(machine.try_update_aim_sample(Vector2.UP), "debug fixture can update aim before its declared lock")
    machine.advance_fixed_tick()
    machine.advance_fixed_tick()
    machine.request_action(followup)
    var debug_state: Dictionary = intents.get_debug_snapshot(debug_action.action_id)
    _expect(int(debug_state.get("action_instance_id", 0)) == machine.get_current_instance_id(), "debug snapshot reports the same live action instance as the state machine")
    _expect(StringName(debug_state.get("phase_name", &"")) == &"COMMIT" and int(debug_state.get("phase_elapsed_ticks", -1)) == 0, "debug snapshot exposes readable phase and fixed-tick age")
    _expect(StringName(debug_state.get("buffered_action_id", &"")) == followup.action_id and int(debug_state.get("buffer_ticks_remaining", 0)) == followup.buffer_lifetime_ticks, "debug snapshot exposes buffered intent and gameplay-time expiry")
    _expect(int(debug_state.get("cooldown_ticks", 0)) == debug_action.cooldown_ticks, "debug snapshot exposes current authored cooldown")
    _expect((debug_state.get("allowed_cancel_action_ids", []) as Array).has(&"fixture:cancel"), "debug snapshot exposes authored cancel availability")
    _expect(bool(debug_state.get("aim_locked", false)) and Vector2(debug_state.get("locked_aim_sample", Vector2.ZERO)) == Vector2.UP, "debug snapshot exposes current aim-lock state and exact sample")

    machine.clear_buffer()
    machine.force_interrupt(&"fixture:pause_reset")
    var pause_action: ActionDefinition = _make_action(&"fixture:pause", 10, 1, 1, 1, 0, 20)
    _expect(intents.request_action(&"basic_attack", pause_action), "pause fixture action starts through the live intent boundary")
    machine.set_physics_process(true)
    coordinator.request_pause(&"manual_pause")
    var ticks_before_pause_frame: int = machine.get_phase_elapsed_ticks()
    await physics_frame
    _expect(not machine.can_process() and machine.get_phase_elapsed_ticks() == ticks_before_pause_frame, "pausing stops scene-driven action ticks")
    coordinator.resume()
    await physics_frame
    _expect(machine.get_phase_elapsed_ticks() > ticks_before_pause_frame, "scene-driven action ticks resume after unpausing")

    gameplay.queue_free()
    if _failures == 0:
        print("ACTION INPUT INTEGRATION TEST PASS")
    else:
        push_error("ACTION INPUT INTEGRATION TEST FAILURES: %d" % _failures)
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

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
