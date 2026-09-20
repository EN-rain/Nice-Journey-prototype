extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")

var _failures: int = 0
var _back_modal: StringName = &""

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var gameplay: Node2D = GAMEPLAY_SCENE.instantiate() as Node2D
    root.add_child(gameplay)
    var coordinator: PauseCoordinator = gameplay.get_node("PauseCoordinator") as PauseCoordinator
    var player: PlayerController = gameplay.get_node("Player") as PlayerController
    var overlay: Control = gameplay.get_node("PauseLayer/PausePanel") as Control
    var resume_button: Button = gameplay.get_node("PauseLayer/PausePanel/Menu/Layout/ResumeButton") as Button

    _expect(not paused, "gameplay begins unpaused")
    _expect(not overlay.visible, "pause overlay begins hidden")

    coordinator.request_pause(&"manual_pause")
    _expect(paused, "manual pause freezes the scene tree")
    _expect(overlay.visible, "manual pause shows the pause overlay")
    _expect(coordinator.input_ownership.current_modal() == &"pause_menu", "pause menu owns modal input")
    _expect(not player.can_process(), "player processing stops while paused")
    _expect(coordinator.can_process(), "pause coordinator remains operable while paused")

    resume_button.button_down.emit()
    _expect(not paused, "resume unpauses gameplay")
    _expect(not overlay.visible, "resume hides the pause overlay")
    _expect(not coordinator.input_ownership.can_route_gameplay_action(&"basic_attack"), "resume click is swallowed until mouse release")
    var mouse_release: InputEventMouseButton = InputEventMouseButton.new()
    mouse_release.button_index = MOUSE_BUTTON_LEFT
    mouse_release.pressed = false
    coordinator.input_ownership._input(mouse_release)
    _expect(coordinator.input_ownership.can_route_gameplay_action(&"basic_attack"), "basic attack is routable after release")

    coordinator.modal_back_requested.connect(_on_modal_back_requested)
    coordinator.input_ownership.open_modal(&"ui:test_unpaused_modal")
    var pause_press := InputEventAction.new()
    pause_press.action = &"pause"
    pause_press.pressed = true
    coordinator._input(pause_press)
    _expect(not paused, "Escape on an unpaused non-pause modal does not stack the Pause menu")
    _expect(_back_modal == &"ui:test_unpaused_modal", "Escape routes a back request to the current unpaused modal owner")
    _expect(coordinator.input_ownership.current_modal() == &"ui:test_unpaused_modal", "PauseCoordinator does not silently close another modal owner's UI")
    coordinator.input_ownership.close_modal(&"ui:test_unpaused_modal", &"pause")
    var pause_release := InputEventAction.new()
    pause_release.action = &"pause"
    pause_release.pressed = false
    coordinator._input(pause_release)
    _expect(coordinator.input_ownership.can_route_gameplay_action(&"pause"), "Escape suppression clears after the routed modal-back release")

    coordinator.pause_for_focus_loss()
    _expect(paused, "focus loss uses the same pause boundary")
    _expect(coordinator.get_pause_reason() == &"focus_loss", "focus-loss pause reason remains observable")
    coordinator.resume()

    gameplay.queue_free()
    if _failures == 0:
        print("PAUSE COORDINATOR TEST PASS")
    else:
        push_error("PAUSE COORDINATOR TEST FAILURES: %d" % _failures)
    quit(_failures)

func _on_modal_back_requested(modal_id: StringName) -> void:
    _back_modal = modal_id

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
