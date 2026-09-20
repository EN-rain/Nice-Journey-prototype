extends Node

signal run_mode_changed(run_mode: int)
signal reduced_motion_changed(enabled: bool)
signal shake_intensity_changed(intensity: float)
signal ui_scale_changed(scale: float)
signal text_scale_changed(scale: float)
signal audio_bus_settings_changed(bus_name: StringName, volume_percent: float, muted: bool)

const RUN_MODE_HOLD: int = 0
const RUN_MODE_TOGGLE: int = 1
const DEFAULT_SETTINGS_PATH: String = "user://settings.cfg"
const UI_SCALE_MIN: float = 1.0
const UI_SCALE_MAX: float = 1.25
const TEXT_SCALE_MIN: float = 1.0
const TEXT_SCALE_MAX: float = 1.25
const DEFAULT_AUDIO_VOLUME_PERCENT: float = 100.0
const AUDIO_BUSES: Array[StringName] = AudioEventDefinition.REQUIRED_BUSES

var run_mode: int = RUN_MODE_HOLD
var reduced_motion: bool = false
var shake_intensity: float = 1.0
var ui_scale: float = 1.0
var text_scale: float = 1.0
var settings_path: String = DEFAULT_SETTINGS_PATH
var _last_save_error: int = OK
var _binding_service: InputBindingService = InputBindingService.new()
var _audio_volume_percent: Dictionary = {}
var _audio_muted: Dictionary = {}

func _ready() -> void:
    _set_audio_defaults_in_memory()
    _apply_all_audio_bus_settings()
    load_from_disk()

func set_run_mode(next_mode: int) -> bool:
    if next_mode != RUN_MODE_HOLD and next_mode != RUN_MODE_TOGGLE:
        return false
    if run_mode == next_mode:
        return true
    run_mode = next_mode
    save_to_disk()
    run_mode_changed.emit(run_mode)
    return true

func set_reduced_motion(enabled: bool) -> void:
    if reduced_motion == enabled:
        return
    reduced_motion = enabled
    save_to_disk()
    reduced_motion_changed.emit(reduced_motion)

func set_shake_intensity(intensity: float) -> void:
    var clamped: float = clampf(intensity, 0.0, 1.0)
    if is_equal_approx(shake_intensity, clamped):
        return
    shake_intensity = clamped
    save_to_disk()
    shake_intensity_changed.emit(shake_intensity)

func set_ui_scale(scale: float) -> void:
    if not is_finite(scale):
        return
    var clamped: float = clampf(scale, UI_SCALE_MIN, UI_SCALE_MAX)
    if is_equal_approx(ui_scale, clamped):
        return
    ui_scale = clamped
    save_to_disk()
    ui_scale_changed.emit(ui_scale)

func set_text_scale(scale: float) -> void:
    if not is_finite(scale):
        return
    var clamped: float = clampf(scale, TEXT_SCALE_MIN, TEXT_SCALE_MAX)
    if is_equal_approx(text_scale, clamped):
        return
    text_scale = clamped
    save_to_disk()
    text_scale_changed.emit(text_scale)

func reset_to_defaults() -> void:
    set_run_mode(RUN_MODE_HOLD)
    set_reduced_motion(false)
    set_shake_intensity(1.0)
    set_ui_scale(1.0)
    set_text_scale(1.0)
    save_to_disk()

func get_audio_bus_volume_percent(bus_name: StringName) -> float:
    return float(_audio_volume_percent.get(bus_name, DEFAULT_AUDIO_VOLUME_PERCENT))

func is_audio_bus_muted(bus_name: StringName) -> bool:
    return bool(_audio_muted.get(bus_name, false))

func set_audio_bus_volume_percent(bus_name: StringName, volume_percent: float) -> bool:
    if not AUDIO_BUSES.has(bus_name) or not is_finite(volume_percent):
        return false
    var clamped: float = clampf(volume_percent, 0.0, 100.0)
    if is_equal_approx(get_audio_bus_volume_percent(bus_name), clamped):
        return true
    _audio_volume_percent[bus_name] = clamped
    _apply_audio_bus_settings(bus_name)
    save_to_disk()
    audio_bus_settings_changed.emit(bus_name, clamped, is_audio_bus_muted(bus_name))
    return true

func set_audio_bus_muted(bus_name: StringName, muted: bool) -> bool:
    if not AUDIO_BUSES.has(bus_name):
        return false
    if is_audio_bus_muted(bus_name) == muted:
        return true
    _audio_muted[bus_name] = muted
    _apply_audio_bus_settings(bus_name)
    save_to_disk()
    audio_bus_settings_changed.emit(bus_name, get_audio_bus_volume_percent(bus_name), muted)
    return true

func reset_audio_defaults() -> int:
    _set_audio_defaults_in_memory()
    _apply_all_audio_bus_settings()
    for bus_name: StringName in AUDIO_BUSES:
        audio_bus_settings_changed.emit(bus_name, DEFAULT_AUDIO_VOLUME_PERCENT, false)
    return save_to_disk()

func set_storage_path(path: String) -> bool:
    if path.strip_edges().is_empty():
        return false
    settings_path = path
    return true

func get_last_save_error() -> int:
    return _last_save_error

func try_rebind_action(action: StringName, event: InputEvent) -> Dictionary:
    var result: Dictionary = _binding_service.try_rebind_action(action, event)
    if bool(result.get("success", false)):
        result["save_error"] = save_to_disk()
    return result

func reset_input_defaults() -> int:
    _binding_service.reset_all_defaults()
    return save_to_disk()

func save_to_disk() -> int:
    var config: ConfigFile = ConfigFile.new()
    config.set_value("accessibility", "run_mode", run_mode)
    config.set_value("accessibility", "reduced_motion", reduced_motion)
    config.set_value("accessibility", "shake_intensity", shake_intensity)
    config.set_value("accessibility", "ui_scale", ui_scale)
    config.set_value("accessibility", "text_scale", text_scale)
    for bus_name: StringName in AUDIO_BUSES:
        var audio_key: String = _audio_storage_key(bus_name)
        config.set_value("audio", "%s_volume_percent" % audio_key, get_audio_bus_volume_percent(bus_name))
        config.set_value("audio", "%s_muted" % audio_key, is_audio_bus_muted(bus_name))
    for action_variant: Variant in InputDefaultBindings.DEFAULT_BINDINGS.keys():
        var action: StringName = StringName(action_variant)
        var events: Array[InputEvent] = InputMap.action_get_events(action)
        if events.is_empty():
            continue
        var serialized: Dictionary = _serialize_event(events[0])
        if not serialized.is_empty():
            config.set_value("input", String(action), serialized)
    _last_save_error = config.save(settings_path)
    return _last_save_error

func load_from_disk() -> int:
    var config: ConfigFile = ConfigFile.new()
    var load_error: int = config.load(settings_path)
    if load_error != OK:
        return load_error

    var loaded_run_mode: int = int(config.get_value("accessibility", "run_mode", RUN_MODE_HOLD))
    var next_run_mode: int = loaded_run_mode if loaded_run_mode == RUN_MODE_TOGGLE else RUN_MODE_HOLD
    var next_reduced_motion: bool = bool(config.get_value("accessibility", "reduced_motion", false))
    var next_shake_intensity: float = clampf(float(config.get_value("accessibility", "shake_intensity", 1.0)), 0.0, 1.0)
    var loaded_ui_scale: float = float(config.get_value("accessibility", "ui_scale", 1.0))
    var loaded_text_scale: float = float(config.get_value("accessibility", "text_scale", 1.0))
    var next_ui_scale: float = clampf(loaded_ui_scale, UI_SCALE_MIN, UI_SCALE_MAX) if is_finite(loaded_ui_scale) else 1.0
    var next_text_scale: float = clampf(loaded_text_scale, TEXT_SCALE_MIN, TEXT_SCALE_MAX) if is_finite(loaded_text_scale) else 1.0
    var next_audio_volume_percent: Dictionary = {}
    var next_audio_muted: Dictionary = {}
    for bus_name: StringName in AUDIO_BUSES:
        var audio_key: String = _audio_storage_key(bus_name)
        next_audio_volume_percent[bus_name] = _recover_audio_volume_percent(config.get_value("audio", "%s_volume_percent" % audio_key, DEFAULT_AUDIO_VOLUME_PERCENT))
        next_audio_muted[bus_name] = _recover_audio_mute(config.get_value("audio", "%s_muted" % audio_key, false))

    var binding_load_error: int = _load_bindings_atomically(config)
    if binding_load_error != OK:
        return binding_load_error

    run_mode = next_run_mode
    reduced_motion = next_reduced_motion
    shake_intensity = next_shake_intensity
    ui_scale = next_ui_scale
    text_scale = next_text_scale
    _audio_volume_percent = next_audio_volume_percent
    _audio_muted = next_audio_muted
    _apply_all_audio_bus_settings()

    run_mode_changed.emit(run_mode)
    reduced_motion_changed.emit(reduced_motion)
    shake_intensity_changed.emit(shake_intensity)
    ui_scale_changed.emit(ui_scale)
    text_scale_changed.emit(text_scale)
    for bus_name: StringName in AUDIO_BUSES:
        audio_bus_settings_changed.emit(bus_name, get_audio_bus_volume_percent(bus_name), is_audio_bus_muted(bus_name))
    return OK

func _set_audio_defaults_in_memory() -> void:
    _audio_volume_percent.clear()
    _audio_muted.clear()
    for bus_name: StringName in AUDIO_BUSES:
        _audio_volume_percent[bus_name] = DEFAULT_AUDIO_VOLUME_PERCENT
        _audio_muted[bus_name] = false

func _apply_all_audio_bus_settings() -> void:
    for bus_name: StringName in AUDIO_BUSES:
        _apply_audio_bus_settings(bus_name)

func _apply_audio_bus_settings(bus_name: StringName) -> void:
    var audio_service: Node = get_node_or_null("/root/AudioService")
    if audio_service == null:
        return
    audio_service.call("set_bus_volume_linear", bus_name, get_audio_bus_volume_percent(bus_name) / 100.0)
    audio_service.call("set_bus_muted", bus_name, is_audio_bus_muted(bus_name))

func _audio_storage_key(bus_name: StringName) -> String:
    return String(bus_name).to_lower().replace(" ", "_")

func _recover_audio_volume_percent(value: Variant) -> float:
    if not (value is int or value is float):
        return DEFAULT_AUDIO_VOLUME_PERCENT
    var numeric: float = float(value)
    if not is_finite(numeric):
        return DEFAULT_AUDIO_VOLUME_PERCENT
    return clampf(numeric, 0.0, 100.0)

func _recover_audio_mute(value: Variant) -> bool:
    return bool(value) if value is bool else false

func _load_bindings_atomically(config: ConfigFile) -> int:
    var managed_actions: Array[StringName] = []
    var original_events: Dictionary = {}
    var loaded_events: Dictionary = {}

    for action_variant: Variant in InputDefaultBindings.DEFAULT_BINDINGS.keys():
        var action: StringName = StringName(action_variant)
        managed_actions.append(action)
        original_events[action] = InputMap.action_get_events(action).duplicate()
        if not config.has_section_key("input", String(action)):
            continue
        var value: Variant = config.get_value("input", String(action))
        if not value is Dictionary:
            return ERR_INVALID_DATA
        var event: InputEvent = _deserialize_event(value as Dictionary)
        if event == null:
            return ERR_INVALID_DATA
        loaded_events[action] = event

    for action: StringName in managed_actions:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        InputMap.action_erase_events(action)

    for action: StringName in managed_actions:
        var staged_events: Array = [loaded_events[action]] if loaded_events.has(action) else original_events[action]
        for event_variant: Variant in staged_events:
            if not event_variant is InputEvent:
                continue
            var event: InputEvent = event_variant as InputEvent
            if not _binding_service.detect_conflicts(action, event).is_empty():
                _restore_bindings(managed_actions, original_events)
                return ERR_INVALID_DATA
            InputMap.action_add_event(action, event)
    return OK

func _restore_bindings(actions: Array[StringName], original_events: Dictionary) -> void:
    for action: StringName in actions:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        InputMap.action_erase_events(action)
        var events: Array = original_events.get(action, [])
        for event_variant: Variant in events:
            if event_variant is InputEvent:
                InputMap.action_add_event(action, event_variant as InputEvent)

func _serialize_event(event: InputEvent) -> Dictionary:
    if event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        return {
            "kind": "key",
            "physical_keycode": int(key_event.physical_keycode),
            "keycode": int(key_event.keycode),
            "shift": key_event.shift_pressed,
            "ctrl": key_event.ctrl_pressed,
            "alt": key_event.alt_pressed,
            "meta": key_event.meta_pressed,
        }
    if event is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = event as InputEventMouseButton
        return {
            "kind": "mouse",
            "button_index": int(mouse_event.button_index),
            "shift": mouse_event.shift_pressed,
            "ctrl": mouse_event.ctrl_pressed,
            "alt": mouse_event.alt_pressed,
            "meta": mouse_event.meta_pressed,
        }
    return {}

func _deserialize_event(data: Dictionary) -> InputEvent:
    var kind: String = String(data.get("kind", ""))
    if kind == "key":
        var key_event: InputEventKey = InputEventKey.new()
        key_event.physical_keycode = int(data.get("physical_keycode", 0)) as Key
        key_event.keycode = int(data.get("keycode", 0)) as Key
        key_event.shift_pressed = bool(data.get("shift", false))
        key_event.ctrl_pressed = bool(data.get("ctrl", false))
        key_event.alt_pressed = bool(data.get("alt", false))
        key_event.meta_pressed = bool(data.get("meta", false))
        if key_event.physical_keycode == KEY_NONE and key_event.keycode == KEY_NONE:
            return null
        return key_event
    if kind == "mouse":
        var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
        mouse_event.button_index = int(data.get("button_index", 0)) as MouseButton
        mouse_event.shift_pressed = bool(data.get("shift", false))
        mouse_event.ctrl_pressed = bool(data.get("ctrl", false))
        mouse_event.alt_pressed = bool(data.get("alt", false))
        mouse_event.meta_pressed = bool(data.get("meta", false))
        if mouse_event.button_index == MOUSE_BUTTON_NONE:
            return null
        return mouse_event
    return null
