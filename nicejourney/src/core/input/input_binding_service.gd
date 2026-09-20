class_name InputBindingService
extends RefCounted

func detect_conflicts(action: StringName, event: InputEvent) -> Array[StringName]:
    var conflicts: Array[StringName] = []
    if event == null:
        return conflicts
    for candidate: StringName in InputMap.get_actions():
        if candidate == action:
            continue
        for existing: InputEvent in InputMap.action_get_events(candidate):
            if _events_use_same_binding(existing, event):
                conflicts.append(candidate)
                break
    conflicts.sort()
    return conflicts

func try_rebind_action(action: StringName, event: InputEvent) -> Dictionary:
    if not InputMap.has_action(action) or event == null:
        return {"success": false, "conflicts": Array([], TYPE_STRING_NAME, &"", null)}
    var conflicts: Array[StringName] = detect_conflicts(action, event)
    if not conflicts.is_empty():
        return {"success": false, "conflicts": conflicts}
    InputMap.action_erase_events(action)
    InputMap.action_add_event(action, event)
    return {"success": true, "conflicts": conflicts}

func reset_action_to_default(action: StringName) -> bool:
    var default_event: InputEvent = InputDefaultBindings.make_default_event(action)
    if default_event == null:
        return false
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    InputMap.action_erase_events(action)
    InputMap.action_add_event(action, default_event)
    return true

func reset_all_defaults() -> void:
    for action_variant: Variant in InputDefaultBindings.DEFAULT_BINDINGS.keys():
        reset_action_to_default(StringName(action_variant))

func _events_use_same_binding(a: InputEvent, b: InputEvent) -> bool:
    if a is InputEventKey and b is InputEventKey:
        var key_a: InputEventKey = a as InputEventKey
        var key_b: InputEventKey = b as InputEventKey
        var same_key: bool = false
        if key_a.physical_keycode != KEY_NONE and key_b.physical_keycode != KEY_NONE:
            same_key = key_a.physical_keycode == key_b.physical_keycode
        else:
            same_key = key_a.keycode == key_b.keycode
        return (
            same_key
            and key_a.shift_pressed == key_b.shift_pressed
            and key_a.ctrl_pressed == key_b.ctrl_pressed
            and key_a.alt_pressed == key_b.alt_pressed
            and key_a.meta_pressed == key_b.meta_pressed
        )
    if a is InputEventMouseButton and b is InputEventMouseButton:
        var mouse_a: InputEventMouseButton = a as InputEventMouseButton
        var mouse_b: InputEventMouseButton = b as InputEventMouseButton
        return (
            mouse_a.button_index == mouse_b.button_index
            and mouse_a.shift_pressed == mouse_b.shift_pressed
            and mouse_a.ctrl_pressed == mouse_b.ctrl_pressed
            and mouse_a.alt_pressed == mouse_b.alt_pressed
            and mouse_a.meta_pressed == mouse_b.meta_pressed
        )
    return false
