extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var service: InputBindingService = InputBindingService.new()
    service.reset_all_defaults()

    var move_up_default: InputEvent = InputDefaultBindings.make_default_event(&"move_up")
    _expect(move_up_default is InputEventKey and (move_up_default as InputEventKey).physical_keycode == KEY_W, "default binding data exposes the approved W key for move_up")

    var conflicting: InputEventKey = InputEventKey.new()
    conflicting.physical_keycode = KEY_S
    conflicting.keycode = KEY_S
    var conflicts: Array[StringName] = service.detect_conflicts(&"move_up", conflicting)
    _expect(conflicts.has(&"move_down"), "rebinding detects another action using the requested physical key even when the live event also carries a logical keycode")

    var rejected: Dictionary = service.try_rebind_action(&"move_up", conflicting)
    _expect(not bool(rejected.get("success", false)), "conflicting rebind is rejected without changing the action")
    _expect(_action_uses_physical_key(&"move_up", KEY_W), "rejected conflict leaves the prior binding intact")

    var replacement: InputEventKey = InputEventKey.new()
    replacement.physical_keycode = KEY_UP
    var accepted: Dictionary = service.try_rebind_action(&"move_up", replacement)
    _expect(bool(accepted.get("success", false)), "unused key can rebind an existing gameplay action")
    _expect(_action_uses_physical_key(&"move_up", KEY_UP), "successful rebind replaces the prior binding")

    _expect(service.reset_action_to_default(&"move_up"), "single action can recover to its specification default")
    _expect(_action_uses_physical_key(&"move_up", KEY_W), "single-action reset restores W")

    var attack_replacement: InputEventMouseButton = InputEventMouseButton.new()
    attack_replacement.button_index = MOUSE_BUTTON_MIDDLE
    _expect(bool(service.try_rebind_action(&"basic_attack", attack_replacement).get("success", false)), "mouse actions are rebindable through the same service")
    service.reset_all_defaults()
    _expect(_action_uses_mouse_button(&"basic_attack", MOUSE_BUTTON_LEFT), "reset-all restores the default basic-attack mouse button")
    _expect(_action_uses_physical_key(&"move_up", KEY_W), "reset-all preserves/restores the default movement surface")

    if _failures == 0:
        print("INPUT BINDINGS TEST PASS")
    else:
        push_error("INPUT BINDINGS TEST FAILURES: %d" % _failures)
    quit(_failures)

func _action_uses_physical_key(action: StringName, keycode: Key) -> bool:
    for event: InputEvent in InputMap.action_get_events(action):
        if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
            return true
    return false

func _action_uses_mouse_button(action: StringName, button: MouseButton) -> bool:
    for event: InputEvent in InputMap.action_get_events(action):
        if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
            return true
    return false

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
