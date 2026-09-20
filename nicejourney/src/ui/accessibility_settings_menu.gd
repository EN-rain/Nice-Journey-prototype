class_name AccessibilitySettingsMenu
extends Node

const SETTINGS_MODAL_ID: StringName = &"accessibility_settings"
const RUN_MODE_HOLD: int = 0
const RUN_MODE_TOGGLE: int = 1
const PROTOTYPE_SCALE_OPTIONS: Array[float] = [1.0, 1.125, 1.25]
const BASE_FONT_SIZE: int = 16

@export var pause_menu_path: NodePath
@export var settings_panel_path: NodePath
@export var map_overlay_path: NodePath
@export var tower_access_overlay_path: NodePath
@export var quest_log_overlay_path: NodePath
@export var skills_overlay_path: NodePath
@export var inventory_overlay_path: NodePath
@export var merchant_overlay_path: NodePath
@export var blacksmith_overlay_path: NodePath
@export var storage_overlay_path: NodePath
@export var combat_hud_root_path: NodePath
@export var settings_button_path: NodePath
@export var back_button_path: NodePath
@export var run_mode_path: NodePath
@export var reduced_motion_path: NodePath
@export var shake_intensity_path: NodePath
@export var ui_scale_path: NodePath
@export var text_scale_path: NodePath
@export var control_action_path: NodePath
@export var current_binding_path: NodePath
@export var rebind_button_path: NodePath
@export var reset_controls_button_path: NodePath
@export var binding_status_path: NodePath
@export var status_path: NodePath
@export var input_ownership_path: NodePath
@export var pause_coordinator_path: NodePath
@export var player_path: NodePath

var _pause_menu: Control = null
var _settings_panel: Control = null
var _map_overlay: Control = null
var _tower_access_overlay: Control = null
var _quest_log_overlay: Control = null
var _skills_overlay: Control = null
var _inventory_overlay: Control = null
var _merchant_overlay: Control = null
var _blacksmith_overlay: Control = null
var _storage_overlay: Control = null
var _combat_hud_root: Control = null
var _settings_button: Button = null
var _back_button: Button = null
var _run_mode: OptionButton = null
var _reduced_motion: CheckBox = null
var _shake_intensity: HSlider = null
var _ui_scale: OptionButton = null
var _text_scale: OptionButton = null
var _audio_volume_controls: Dictionary = {}
var _audio_mute_controls: Dictionary = {}
var _reset_audio_button: Button = null
var _control_action: OptionButton = null
var _current_binding: Label = null
var _rebind_button: Button = null
var _reset_controls_button: Button = null
var _binding_status: Label = null
var _status: Label = null
var _input_ownership: InputOwnership = null
var _pause_coordinator: PauseCoordinator = null
var _player: PlayerController = null
var _settings: Node = null
var _awaiting_rebind: bool = false
var _font_size_baselines: Dictionary = {}

func _enter_tree() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
    _pause_menu = get_node_or_null(pause_menu_path) as Control
    _settings_panel = get_node_or_null(settings_panel_path) as Control
    _map_overlay = get_node_or_null(map_overlay_path) as Control
    _tower_access_overlay = get_node_or_null(tower_access_overlay_path) as Control
    _quest_log_overlay = get_node_or_null(quest_log_overlay_path) as Control
    _skills_overlay = get_node_or_null(skills_overlay_path) as Control
    _inventory_overlay = get_node_or_null(inventory_overlay_path) as Control
    _merchant_overlay = get_node_or_null(merchant_overlay_path) as Control
    _blacksmith_overlay = get_node_or_null(blacksmith_overlay_path) as Control
    _storage_overlay = get_node_or_null(storage_overlay_path) as Control
    _combat_hud_root = get_node_or_null(combat_hud_root_path) as Control
    _settings_button = get_node_or_null(settings_button_path) as Button
    _back_button = get_node_or_null(back_button_path) as Button
    _run_mode = get_node_or_null(run_mode_path) as OptionButton
    _reduced_motion = get_node_or_null(reduced_motion_path) as CheckBox
    _shake_intensity = get_node_or_null(shake_intensity_path) as HSlider
    _ui_scale = get_node_or_null(ui_scale_path) as OptionButton
    _text_scale = get_node_or_null(text_scale_path) as OptionButton
    _bind_audio_controls()
    _control_action = get_node_or_null(control_action_path) as OptionButton
    _current_binding = get_node_or_null(current_binding_path) as Label
    _rebind_button = get_node_or_null(rebind_button_path) as Button
    _reset_controls_button = get_node_or_null(reset_controls_button_path) as Button
    _binding_status = get_node_or_null(binding_status_path) as Label
    _status = get_node_or_null(status_path) as Label
    _input_ownership = get_node_or_null(input_ownership_path) as InputOwnership
    _pause_coordinator = get_node_or_null(pause_coordinator_path) as PauseCoordinator
    _player = get_node_or_null(player_path) as PlayerController
    _settings = get_node_or_null("/root/AccessibilitySettings")

    if _settings_panel != null:
        _settings_panel.visible = false
        _settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
    if _run_mode != null:
        _run_mode.clear()
        _run_mode.add_item(tr("Hold"))
        _run_mode.add_item(tr("Toggle"))
        _run_mode.item_selected.connect(_on_run_mode_selected)
    if _reduced_motion != null:
        _reduced_motion.toggled.connect(_on_reduced_motion_toggled)
    if _shake_intensity != null:
        _shake_intensity.value_changed.connect(_on_shake_intensity_changed)
    if _ui_scale != null:
        _populate_scale_options(_ui_scale)
        _ui_scale.item_selected.connect(_on_ui_scale_selected)
    if _text_scale != null:
        _populate_scale_options(_text_scale)
        _text_scale.item_selected.connect(_on_text_scale_selected)
    if _reset_audio_button != null:
        _reset_audio_button.pressed.connect(_on_reset_audio_pressed)
    if _control_action != null:
        _populate_control_actions()
        _control_action.item_selected.connect(_on_control_action_selected)
    if _rebind_button != null:
        _rebind_button.pressed.connect(_on_rebind_pressed)
    if _reset_controls_button != null:
        _reset_controls_button.pressed.connect(_on_reset_controls_pressed)
    if _settings_button != null:
        _settings_button.pressed.connect(open_settings)
    if _back_button != null:
        _back_button.pressed.connect(close_settings)
    if _pause_coordinator != null:
        _pause_coordinator.modal_back_requested.connect(_on_modal_back_requested)

    if _settings == null:
        push_error("AccessibilitySettingsMenu: AccessibilitySettings autoload is required")
        return
    _settings.connect(&"run_mode_changed", _on_global_run_mode_changed)
    _settings.connect(&"reduced_motion_changed", _on_global_reduced_motion_changed)
    _settings.connect(&"shake_intensity_changed", _on_global_shake_intensity_changed)
    _settings.connect(&"ui_scale_changed", _on_global_ui_scale_changed)
    _settings.connect(&"text_scale_changed", _on_global_text_scale_changed)
    _settings.connect(&"audio_bus_settings_changed", _on_global_audio_bus_settings_changed)
    _capture_font_size_baselines(_pause_menu)
    _capture_font_size_baselines(_settings_panel)
    _capture_font_size_baselines(_map_overlay)
    _capture_font_size_baselines(_tower_access_overlay)
    _capture_font_size_baselines(_quest_log_overlay)
    _capture_font_size_baselines(_skills_overlay)
    _capture_font_size_baselines(_inventory_overlay)
    _capture_font_size_baselines(_merchant_overlay)
    _capture_font_size_baselines(_blacksmith_overlay)
    _capture_font_size_baselines(_storage_overlay)
    _capture_font_size_baselines(_combat_hud_root)
    _sync_controls_from_settings()
    _apply_all_settings()

func open_settings() -> void:
    if _settings_panel == null or _pause_menu == null:
        return
    if _pause_coordinator != null and not get_tree().paused:
        return
    if _input_ownership != null:
        _input_ownership.open_modal(SETTINGS_MODAL_ID)
    _pause_menu.visible = false
    _settings_panel.visible = true
    _awaiting_rebind = false
    _sync_controls_from_settings()
    if _run_mode != null:
        _run_mode.grab_focus()

func close_settings() -> void:
    if _settings_panel == null or not _settings_panel.visible:
        return
    _awaiting_rebind = false
    if _input_ownership != null:
        _input_ownership.close_modal(SETTINGS_MODAL_ID)
    _settings_panel.visible = false
    if _pause_menu != null:
        _pause_menu.visible = true
    if _settings_button != null:
        _settings_button.grab_focus()

func is_open() -> bool:
    return _settings_panel != null and _settings_panel.visible

func _input(event: InputEvent) -> void:
    if not is_open():
        return
    if _awaiting_rebind and event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        if not key_event.pressed or key_event.echo:
            return
        if key_event.physical_keycode == KEY_ESCAPE or key_event.keycode == KEY_ESCAPE:
            _awaiting_rebind = false
            if _binding_status != null:
                _binding_status.text = tr("Rebind cancelled.")
            if _rebind_button != null:
                _rebind_button.grab_focus()
            get_viewport().set_input_as_handled()
            return
        _finish_rebind(key_event)
        get_viewport().set_input_as_handled()
        return
    if _awaiting_rebind and event is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = event as InputEventMouseButton
        if not mouse_event.pressed:
            return
        _finish_rebind(mouse_event)
        get_viewport().set_input_as_handled()
        return
    if _pause_coordinator == null and event.is_action_pressed(&"pause"):
        close_settings()
        get_viewport().set_input_as_handled()

func _on_modal_back_requested(modal_id: StringName) -> void:
    if modal_id == SETTINGS_MODAL_ID:
        close_settings()

func _on_run_mode_selected(index: int) -> void:
    if _settings != null:
        _settings.call("set_run_mode", index)

func _on_reduced_motion_toggled(enabled: bool) -> void:
    if _settings != null:
        _settings.call("set_reduced_motion", enabled)

func _on_shake_intensity_changed(value: float) -> void:
    if _settings != null:
        _settings.call("set_shake_intensity", value / 100.0)

func _on_ui_scale_selected(index: int) -> void:
    if _settings != null and index >= 0 and index < PROTOTYPE_SCALE_OPTIONS.size():
        _settings.call("set_ui_scale", PROTOTYPE_SCALE_OPTIONS[index])

func _on_text_scale_selected(index: int) -> void:
    if _settings != null and index >= 0 and index < PROTOTYPE_SCALE_OPTIONS.size():
        _settings.call("set_text_scale", PROTOTYPE_SCALE_OPTIONS[index])

func _on_audio_volume_changed(value: float, bus_name: StringName) -> void:
    if _settings != null:
        _settings.call("set_audio_bus_volume_percent", bus_name, value)

func _on_audio_mute_toggled(muted: bool, bus_name: StringName) -> void:
    if _settings != null:
        _settings.call("set_audio_bus_muted", bus_name, muted)

func _on_reset_audio_pressed() -> void:
    if _settings != null:
        _settings.call("reset_audio_defaults")

func _on_control_action_selected(_index: int) -> void:
    _update_current_binding()

func _on_rebind_pressed() -> void:
    if _settings == null or _control_action == null or _control_action.item_count == 0:
        return
    _awaiting_rebind = true
    if _binding_status != null:
        _binding_status.text = tr("Press a new key or mouse button. Esc cancels.")

func _on_reset_controls_pressed() -> void:
    if _settings == null:
        return
    var save_error: int = int(_settings.call("reset_input_defaults"))
    _update_current_binding()
    if _binding_status != null:
        _binding_status.text = tr("Control defaults restored.") if save_error == OK else tr("Defaults restored for this session; settings file save failed.")

func _on_global_run_mode_changed(_run_mode_value: int) -> void:
    _sync_controls_from_settings()
    _apply_run_mode()

func _on_global_reduced_motion_changed(_enabled: bool) -> void:
    _sync_controls_from_settings()
    _apply_camera_settings()

func _on_global_shake_intensity_changed(_intensity: float) -> void:
    _sync_controls_from_settings()
    _apply_camera_settings()

func _on_global_ui_scale_changed(_scale: float) -> void:
    _sync_controls_from_settings()
    _apply_presentation_scale()

func _on_global_text_scale_changed(_scale: float) -> void:
    _sync_controls_from_settings()
    _apply_presentation_scale()

func _on_global_audio_bus_settings_changed(_bus_name: StringName, _volume_percent: float, _muted: bool) -> void:
    _sync_audio_controls_from_settings()
    _update_status()

func _sync_controls_from_settings() -> void:
    if _settings == null:
        return
    var run_mode_value: int = int(_settings.get("run_mode"))
    var reduced_motion_value: bool = bool(_settings.get("reduced_motion"))
    var shake_intensity_value: float = float(_settings.get("shake_intensity"))
    var ui_scale_value: float = float(_settings.get("ui_scale"))
    var text_scale_value: float = float(_settings.get("text_scale"))
    if _run_mode != null:
        _run_mode.select(run_mode_value)
    if _reduced_motion != null:
        _reduced_motion.set_pressed_no_signal(reduced_motion_value)
    if _shake_intensity != null:
        _shake_intensity.set_value_no_signal(shake_intensity_value * 100.0)
    _select_scale_option(_ui_scale, ui_scale_value)
    _select_scale_option(_text_scale, text_scale_value)
    _sync_audio_controls_from_settings()
    _update_current_binding()
    _update_status()

func _apply_all_settings() -> void:
    _apply_run_mode()
    _apply_camera_settings()
    _apply_presentation_scale()

func _apply_run_mode() -> void:
    if _player != null and _settings != null:
        _player.movement.set_run_toggle_enabled(int(_settings.get("run_mode")) == RUN_MODE_TOGGLE)
    _update_status()

func _apply_camera_settings() -> void:
    if _player != null and _settings != null:
        _player.camera.set_reduced_motion(bool(_settings.get("reduced_motion")))
        _player.camera.set_shake_intensity(float(_settings.get("shake_intensity")))
    _update_status()

func _apply_presentation_scale() -> void:
    if _settings == null:
        return
    var ui_scale_value: float = float(_settings.get("ui_scale"))
    var text_scale_value: float = float(_settings.get("text_scale"))
    _apply_scale_to_root(_pause_menu, ui_scale_value, text_scale_value)
    _apply_scale_to_root(_settings_panel, ui_scale_value, text_scale_value)
    _apply_scale_to_root(_map_overlay, ui_scale_value, text_scale_value)
    _apply_scale_to_root(_tower_access_overlay, ui_scale_value, text_scale_value)
    _apply_scale_to_root(_quest_log_overlay, ui_scale_value, text_scale_value)
    _apply_scale_to_root(_skills_overlay, ui_scale_value, text_scale_value)
    _apply_scale_to_root(_inventory_overlay, ui_scale_value, text_scale_value)
    _apply_scale_to_root(_merchant_overlay, ui_scale_value, text_scale_value)
    _apply_scale_to_root(_blacksmith_overlay, ui_scale_value, text_scale_value)
    _apply_scale_to_root(_storage_overlay, ui_scale_value, text_scale_value)
    _apply_scale_to_root(_combat_hud_root, ui_scale_value, text_scale_value)
    _update_status()

func _update_status() -> void:
    if _status == null or _settings == null:
        return
    var run_text: String = tr("Toggle") if int(_settings.get("run_mode")) == RUN_MODE_TOGGLE else tr("Hold")
    var motion_text: String = tr("On") if bool(_settings.get("reduced_motion")) else tr("Off")
    var save_state: String = tr("Saved outside campaign data") if int(_settings.call("get_last_save_error")) == OK else tr("Settings file write failed")
    _status.text = tr("Run: %s | Motion: %s | Shake: %d%% | UI: %d%% | Text: %d%%\n%s.") % [
        run_text,
        motion_text,
        roundi(float(_settings.get("shake_intensity")) * 100.0),
        roundi(float(_settings.get("ui_scale")) * 100.0),
        roundi(float(_settings.get("text_scale")) * 100.0),
        save_state,
    ]

func _populate_scale_options(option: OptionButton) -> void:
    option.clear()
    for scale: float in PROTOTYPE_SCALE_OPTIONS:
        option.add_item("%d%%" % roundi(scale * 100.0))

func _bind_audio_controls() -> void:
    if _settings_panel == null:
        return
    _bind_audio_control(&"Master", "MasterRow")
    _bind_audio_control(&"Music", "MusicRow")
    _bind_audio_control(&"Gameplay SFX", "GameplaySfxRow")
    _bind_audio_control(&"UI", "UiRow")
    _bind_audio_control(&"Ambience", "AmbienceRow")
    _reset_audio_button = _settings_panel.get_node_or_null("Scroller/Layout/AudioSection/ResetAudioButton") as Button

func _bind_audio_control(bus_name: StringName, row_name: String) -> void:
    var row_path: String = "Scroller/Layout/AudioSection/%s" % row_name
    var volume: HSlider = _settings_panel.get_node_or_null("%s/Volume" % row_path) as HSlider
    var mute: CheckBox = _settings_panel.get_node_or_null("%s/Mute" % row_path) as CheckBox
    if volume != null:
        _audio_volume_controls[bus_name] = volume
        volume.value_changed.connect(_on_audio_volume_changed.bind(bus_name))
        volume.focus_entered.connect(_on_audio_control_focus_entered.bind(volume))
    if mute != null:
        _audio_mute_controls[bus_name] = mute
        mute.toggled.connect(_on_audio_mute_toggled.bind(bus_name))
        mute.focus_entered.connect(_on_audio_control_focus_entered.bind(mute))

func _on_audio_control_focus_entered(control: Control) -> void:
    if _settings_panel == null:
        return
    var scroller: ScrollContainer = _settings_panel.get_node_or_null("Scroller") as ScrollContainer
    if scroller != null:
        scroller.call_deferred(&"ensure_control_visible", control)

func _sync_audio_controls_from_settings() -> void:
    if _settings == null:
        return
    for bus_name: StringName in AudioEventDefinition.REQUIRED_BUSES:
        var volume: HSlider = _audio_volume_controls.get(bus_name) as HSlider
        var mute: CheckBox = _audio_mute_controls.get(bus_name) as CheckBox
        if volume != null:
            volume.set_value_no_signal(float(_settings.call("get_audio_bus_volume_percent", bus_name)))
        if mute != null:
            mute.set_pressed_no_signal(bool(_settings.call("is_audio_bus_muted", bus_name)))

func _select_scale_option(option: OptionButton, value: float) -> void:
    if option == null:
        return
    var best_index: int = 0
    var best_distance: float = INF
    for index: int in range(PROTOTYPE_SCALE_OPTIONS.size()):
        var distance: float = absf(PROTOTYPE_SCALE_OPTIONS[index] - value)
        if distance < best_distance:
            best_distance = distance
            best_index = index
    option.select(best_index)

func _capture_font_size_baselines(root_control: Control) -> void:
    if root_control == null:
        return
    _capture_font_size_baseline(root_control)
    for child: Node in root_control.find_children("*", "Control", true, false):
        _capture_font_size_baseline(child as Control)

func _capture_font_size_baseline(control: Control) -> void:
    if control == null or not control.has_theme_font_size_override(&"font_size"):
        return
    _font_size_baselines[control.get_instance_id()] = control.get_theme_font_size(&"font_size")

func _apply_scale_to_root(root_control: Control, ui_scale_value: float, text_scale_value: float) -> void:
    if root_control == null:
        return
    var scaled_theme: Theme = root_control.theme
    if scaled_theme == null:
        scaled_theme = Theme.new()
        root_control.theme = scaled_theme
    scaled_theme.default_base_scale = ui_scale_value
    scaled_theme.default_font_size = roundi(BASE_FONT_SIZE * text_scale_value)
    _apply_explicit_font_scale(root_control, text_scale_value)
    for child: Node in root_control.find_children("*", "Control", true, false):
        _apply_explicit_font_scale(child as Control, text_scale_value)

func _apply_explicit_font_scale(control: Control, text_scale_value: float) -> void:
    if control == null:
        return
    var instance_id: int = control.get_instance_id()
    if not _font_size_baselines.has(instance_id):
        return
    control.add_theme_font_size_override(&"font_size", roundi(int(_font_size_baselines[instance_id]) * text_scale_value))

func _populate_control_actions() -> void:
    if _control_action == null:
        return
    _control_action.clear()
    var actions: Array[StringName] = []
    for action_variant: Variant in InputDefaultBindings.DEFAULT_BINDINGS.keys():
        actions.append(StringName(action_variant))
    actions.sort()
    for action: StringName in actions:
        _control_action.add_item(_action_display_name(action))
        _control_action.set_item_metadata(_control_action.item_count - 1, action)

func _selected_control_action() -> StringName:
    if _control_action == null or _control_action.item_count == 0:
        return &""
    return StringName(_control_action.get_item_metadata(_control_action.selected))

func _update_current_binding() -> void:
    if _current_binding == null:
        return
    var action: StringName = _selected_control_action()
    var events: Array[InputEvent] = InputMap.action_get_events(action)
    _current_binding.text = tr("Current: —") if events.is_empty() else tr("Current: %s") % _describe_event(events[0])

func _finish_rebind(event: InputEvent) -> void:
    _awaiting_rebind = false
    var action: StringName = _selected_control_action()
    var result: Dictionary = _settings.call("try_rebind_action", action, event)
    if bool(result.get("success", false)):
        var save_error: int = int(result.get("save_error", OK))
        if _binding_status != null:
            if save_error == OK:
                _binding_status.text = tr("Bound %s to %s.") % [_action_display_name(action), _describe_event(event)]
            else:
                _binding_status.text = tr("Bound %s to %s. Settings file save failed.") % [_action_display_name(action), _describe_event(event)]
    else:
        var conflicts: Array[StringName] = result.get("conflicts", Array([], TYPE_STRING_NAME, &"", null))
        if _binding_status != null:
            _binding_status.text = tr("Conflict: already used by %s. Binding unchanged.") % _join_action_names(conflicts)
    _update_current_binding()
    if _rebind_button != null:
        _rebind_button.grab_focus()

func _describe_event(event: InputEvent) -> String:
    if event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        var code: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
        return OS.get_keycode_string(code)
    if event is InputEventMouseButton:
        return tr("Mouse %d") % int((event as InputEventMouseButton).button_index)
    return tr("Unknown")

func _action_display_name(action: StringName) -> String:
    match action:
        &"move_up": return tr("Move Up")
        &"move_down": return tr("Move Down")
        &"move_left": return tr("Move Left")
        &"move_right": return tr("Move Right")
        &"run": return tr("Run")
        &"dodge": return tr("Dodge")
        &"dash": return tr("Dash")
        &"parry": return tr("Parry")
        &"interact": return tr("Interact")
        &"skill_1": return tr("Skill 1")
        &"skill_2": return tr("Skill 2")
        &"consumable_1": return tr("Consumable 1")
        &"consumable_2": return tr("Consumable 2")
        &"consumable_3": return tr("Consumable 3")
        &"consumable_4": return tr("Consumable 4")
        &"inventory": return tr("Inventory")
        &"skills": return tr("Skills")
        &"quest_log": return tr("Quest Log")
        &"map": return tr("Map")
        &"sigil_menu": return tr("Tower Sigil Menu")
        &"pause": return tr("Pause")
        &"basic_attack": return tr("Basic Attack")
        &"block": return tr("Block")
        _:
            return String(action).replace("_", " ").capitalize()

func _join_action_names(actions: Array[StringName]) -> String:
    var names: PackedStringArray = PackedStringArray()
    for action: StringName in actions:
        names.append(_action_display_name(action))
    return ", ".join(names)
