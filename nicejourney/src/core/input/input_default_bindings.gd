class_name InputDefaultBindings
extends RefCounted

const DEFAULT_BINDINGS: Dictionary = {
    &"move_up": ["key", KEY_W],
    &"move_down": ["key", KEY_S],
    &"move_left": ["key", KEY_A],
    &"move_right": ["key", KEY_D],
    &"run": ["key", KEY_SHIFT],
    &"dodge": ["key", KEY_SPACE],
    &"dash": ["key", KEY_CTRL],
    &"parry": ["key", KEY_F],
    &"interact": ["key", KEY_E],
    &"skill_1": ["key", KEY_Q],
    &"skill_2": ["key", KEY_R],
    &"consumable_1": ["key", KEY_1],
    &"consumable_2": ["key", KEY_2],
    &"consumable_3": ["key", KEY_3],
    &"consumable_4": ["key", KEY_4],
    &"inventory": ["key", KEY_I],
    &"skills": ["key", KEY_K],
    &"quest_log": ["key", KEY_J],
    &"map": ["key", KEY_M],
    &"sigil_menu": ["key", KEY_T],
    &"pause": ["key", KEY_ESCAPE],
    &"basic_attack": ["mouse", MOUSE_BUTTON_LEFT],
    &"block": ["mouse", MOUSE_BUTTON_RIGHT],
}

static func has_default(action: StringName) -> bool:
    return DEFAULT_BINDINGS.has(action)

static func make_default_event(action: StringName) -> InputEvent:
    if not has_default(action):
        return null
    var binding: Array = DEFAULT_BINDINGS[action]
    var kind: String = String(binding[0])
    if kind == "key":
        var key_event: InputEventKey = InputEventKey.new()
        key_event.physical_keycode = int(binding[1]) as Key
        return key_event
    if kind == "mouse":
        var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
        mouse_event.button_index = int(binding[1]) as MouseButton
        return mouse_event
    return null
