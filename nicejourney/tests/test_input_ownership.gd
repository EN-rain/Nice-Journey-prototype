extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var ownership: InputOwnership = InputOwnership.new()
    _expect(ownership.can_route_gameplay_action(&"attack"), "gameplay owns input by default")

    ownership.open_modal(&"inventory")
    _expect(ownership.is_modal_open(), "modal ownership is active after opening UI")
    _expect(not ownership.can_route_gameplay_action(&"attack"), "modal UI blocks combat input")

    ownership.open_modal(&"confirm")
    _expect(ownership.current_modal() == &"confirm", "nested modal stack exposes the top owner")
    ownership.close_modal(&"confirm", &"attack")
    _expect(ownership.current_modal() == &"inventory", "closing top modal restores previous modal owner")
    _expect(not ownership.can_route_gameplay_action(&"attack"), "underlying modal still owns input")

    ownership.close_modal(&"inventory", &"attack")
    _expect(not ownership.is_modal_open(), "final modal closes cleanly")
    _expect(not ownership.can_route_gameplay_action(&"attack"), "closing action is swallowed until release")
    _expect(ownership.can_route_gameplay_action(&"dodge"), "unrelated gameplay actions are not globally suppressed after close")

    ownership.notify_action_released(&"attack")
    _expect(ownership.can_route_gameplay_action(&"attack"), "closing action becomes routable after release")

    ownership.open_modal(&"inventory")
    ownership.close_modal(&"inventory", &"interact")
    _expect(not ownership.can_route_gameplay_action(&"interact"), "modal closing action is suppressed before its release")
    var interact_release: InputEventKey = InputEventKey.new()
    interact_release.physical_keycode = KEY_E
    interact_release.pressed = false
    ownership._input(interact_release)
    _expect(ownership.can_route_gameplay_action(&"interact"), "InputOwnership observes release before GUI consumption and clears suppression")

    ownership.free()

    var gameplay: Node2D = GAMEPLAY_SCENE.instantiate() as Node2D
    root.add_child(gameplay)
    var shared_ownership: InputOwnership = gameplay.get_node("InputOwnership") as InputOwnership
    var coordinator: PauseCoordinator = gameplay.get_node("PauseCoordinator") as PauseCoordinator
    var player: PlayerController = gameplay.get_node("Player") as PlayerController
    player.set_physics_process(false)
    player.set_process(false)

    _expect(coordinator.input_ownership == shared_ownership, "pause and gameplay use the same input ownership boundary")

    Input.action_press(&"move_right")
    player.movement.tick(player, player.stamina, 1.0 / 60.0)
    var position_after_open_input: Vector2 = player.position
    _expect(position_after_open_input.x > 160.0, "gameplay movement receives input when no modal owns it")

    shared_ownership.open_modal(&"inventory")
    var position_while_modal: Vector2 = player.position
    player.movement.tick(player, player.stamina, 1.0 / 60.0)
    _expect(player.position == position_while_modal, "non-pausing modal ownership blocks movement polling")

    player.apply_aim_direction(Vector2.RIGHT)
    var facing_before_modal_aim: int = player.get_body_facing()
    var aim_before_modal_aim: Vector2 = player.get_aim_direction()
    _expect(not player.apply_pointer_aim_direction(Vector2.LEFT), "modal ownership rejects pointer-driven combat aim")
    _expect(player.get_body_facing() == facing_before_modal_aim and player.get_aim_direction() == aim_before_modal_aim, "modal pointer input cannot change body facing or weapon aim")

    var camera: PixelCamera = player.get_node("PixelCamera") as PixelCamera
    camera.set_zoom_step(0)
    var wheel_up: InputEventMouseButton = InputEventMouseButton.new()
    wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
    wheel_up.pressed = true
    camera._unhandled_input(wheel_up)
    _expect(camera.get_zoom_step() == 0, "modal ownership blocks camera wheel zoom")

    shared_ownership.close_modal(&"inventory")
    _expect(player.apply_pointer_aim_direction(Vector2.LEFT), "pointer aim resumes after modal ownership closes")
    camera._unhandled_input(wheel_up)
    _expect(camera.get_zoom_step() == 1, "camera wheel zoom resumes after modal ownership closes")
    Input.action_release(&"move_right")
    gameplay.queue_free()

    if _failures == 0:
        print("INPUT OWNERSHIP TEST PASS")
    else:
        push_error("INPUT OWNERSHIP TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
