extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const MAIN_SCENE: PackedScene = preload("res://src/app/main.tscn")
const TEST_SETTINGS_PATH: String = "user://accessibility_settings_test.cfg"

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var settings: Node = root.get_node_or_null("AccessibilitySettings")
    _expect(settings != null, "accessibility settings session service is available")
    if settings == null:
        quit(1)
        return
    _remove_test_settings_file()
    _expect(bool(settings.call("set_storage_path", TEST_SETTINGS_PATH)), "accessibility preferences can use storage separate from campaign saves")
    var binding_service: InputBindingService = InputBindingService.new()
    binding_service.reset_all_defaults()
    settings.call("reset_to_defaults")

    var main: Node = MAIN_SCENE.instantiate()
    main.set("save_root", "user://tests/accessibility_settings_main")
    root.add_child(main)
    await process_frame
    var first_slot: Button = main.get_node("FrontEnd/Panel/Scroller/Layout/Slot1") as Button
    var main_profile_panel: Control = main.get_node("FrontEnd/Panel") as Control
    var main_profile_scroller: ScrollContainer = main.get_node("FrontEnd/Panel/Scroller") as ScrollContainer
    var main_settings_button: Button = main.get_node("FrontEnd/Panel/Scroller/Layout/SettingsButton") as Button
    var main_name_edit: LineEdit = main.get_node("FrontEnd/Panel/Scroller/Layout/CreationPanel/NameEdit") as LineEdit
    var main_class_option: OptionButton = main.get_node("FrontEnd/Panel/Scroller/Layout/CreationPanel/ClassOption") as OptionButton
    var main_create_button: Button = main.get_node("FrontEnd/Panel/Scroller/Layout/CreationPanel/CreateButton") as Button
    var main_settings_menu: AccessibilitySettingsMenu = main.get_node("AccessibilitySettingsMenu") as AccessibilitySettingsMenu
    var main_settings_panel: Control = main.get_node("FrontEnd/SettingsPanel") as Control
    var main_run_mode: OptionButton = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/RunRow/RunMode") as OptionButton
    var main_reduced_motion: CheckBox = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/ReducedMotion") as CheckBox
    var main_shake_slider: HSlider = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/ShakeRow/ShakeIntensity") as HSlider
    var main_ui_scale: OptionButton = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/UIScaleRow/UIScale") as OptionButton
    var main_text_scale: OptionButton = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/TextScaleRow/TextScale") as OptionButton
    var main_control_action: OptionButton = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/BindingRow/ControlAction") as OptionButton
    var main_rebind_button: Button = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/BindingButtons/RebindButton") as Button
    var main_reset_controls: Button = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/BindingButtons/ResetControlsButton") as Button
    var main_binding_status: Label = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/BindingStatus") as Label
    var main_scroller: ScrollContainer = main.get_node("FrontEnd/SettingsPanel/Scroller") as ScrollContainer
    var main_back_button: Button = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/BackButton") as Button
    _expect(first_slot.has_focus(), "main profile screen establishes a visible keyboard focus target")
    var sigil_index: int = _find_control_action_index(main_control_action, &"sigil_menu")
    _expect(sigil_index >= 0 and StringName(main_control_action.get_item_metadata(sigil_index)) == &"sigil_menu", "localized control labels preserve the stable Sigil action metadata ID")
    _expect(sigil_index >= 0 and main_control_action.get_item_text(sigil_index) == "Tower Sigil Menu", "known Sigil action uses its explicit localized display label")
    _expect(String(main_settings_menu.call("_action_display_name", &"future_action")) == "Future Action", "unknown control IDs degrade to a readable display name instead of becoming hidden translation keys")

    main_settings_button.pressed.emit()
    _expect(main_settings_menu.is_open() and main_settings_panel.visible, "settings are reachable before gameplay from the main profile screen")
    _expect(main_run_mode.has_focus(), "main settings establishes keyboard focus on the first setting")
    var settings_rect: Rect2 = main_settings_panel.get_global_rect()
    _expect(settings_rect.position.x >= 0.0 and settings_rect.position.y >= 0.0 and settings_rect.end.x <= 640.0 and settings_rect.end.y <= 360.0, "shared settings panel stays inside the minimum 640x360 UI canvas")

    main_ui_scale.select(main_ui_scale.item_count - 1)
    main_ui_scale.item_selected.emit(main_ui_scale.selected)
    main_text_scale.select(main_text_scale.item_count - 1)
    main_text_scale.item_selected.emit(main_text_scale.selected)
    await process_frame
    _expect(is_equal_approx(float(settings.get("ui_scale")), 1.25) and is_equal_approx(float(settings.get("text_scale")), 1.25), "largest UI/text prototype settings are selectable independently")
    _expect(main_profile_panel.theme != null and main_settings_panel.theme != null and is_equal_approx(main_profile_panel.theme.default_base_scale, 1.25) and main_profile_panel.theme.default_font_size == 20, "pre-game UI uses a separately scalable theme layer at the selected prototype UI/text settings")
    settings.call("set_ui_scale", INF)
    settings.call("set_text_scale", NAN)
    _expect(is_equal_approx(float(settings.get("ui_scale")), 1.25) and is_equal_approx(float(settings.get("text_scale")), 1.25), "non-finite UI/text setter values cannot poison the active presentation scale")
    settings_rect = main_settings_panel.get_global_rect()
    _expect(settings_rect.position.x >= 0.0 and settings_rect.position.y >= 0.0 and settings_rect.end.x <= 640.0 and settings_rect.end.y <= 360.0, "largest UI/text settings keep the shared panel inside the 640x360 canvas")
    _expect(not main_scroller.get_h_scroll_bar().visible, "largest UI/text settings do not require horizontal scrolling or crop left-side labels")
    main_back_button.grab_focus()
    await process_frame
    await process_frame
    _expect(main_back_button.has_focus() and main_back_button.get_global_rect().intersects(main_scroller.get_global_rect()), "settings Back remains keyboard-reachable through the scroll layout at largest UI/text settings")

    _select_control_action(main_control_action, &"move_up")
    main_rebind_button.pressed.emit()
    var conflicting_key: InputEventKey = InputEventKey.new()
    conflicting_key.physical_keycode = KEY_S
    conflicting_key.pressed = true
    main_settings_menu._input(conflicting_key)
    _expect(main_binding_status.text.contains("Conflict") and main_binding_status.text.contains("Move Down"), "player-facing rebind UI reports the conflicting action clearly")
    _expect(_action_uses_physical_key(&"move_up", KEY_W), "conflicting UI rebind leaves the prior control unchanged")

    main_rebind_button.pressed.emit()
    var accepted_key: InputEventKey = InputEventKey.new()
    accepted_key.physical_keycode = KEY_UP
    accepted_key.pressed = true
    main_settings_menu._input(accepted_key)
    _expect(_action_uses_physical_key(&"move_up", KEY_UP), "player-facing rebind UI applies a conflict-free binding")
    _expect(main_rebind_button.has_focus(), "focus returns to the rebind control after capture")

    main_run_mode.select(AccessibilitySettingsMenu.RUN_MODE_TOGGLE)
    main_run_mode.item_selected.emit(AccessibilitySettingsMenu.RUN_MODE_TOGGLE)
    main_reduced_motion.set_pressed_no_signal(true)
    main_reduced_motion.toggled.emit(true)
    main_shake_slider.set_value_no_signal(50.0)
    main_shake_slider.value_changed.emit(50.0)

    settings.set("run_mode", AccessibilitySettingsMenu.RUN_MODE_HOLD)
    settings.set("reduced_motion", false)
    settings.set("shake_intensity", 1.0)
    settings.set("ui_scale", 1.0)
    settings.set("text_scale", 1.0)
    binding_service.reset_all_defaults()
    _expect(int(settings.call("load_from_disk")) == OK, "settings file reload succeeds independently of campaign saves")
    _expect(int(settings.get("run_mode")) == AccessibilitySettingsMenu.RUN_MODE_TOGGLE and bool(settings.get("reduced_motion")) and is_equal_approx(float(settings.get("shake_intensity")), 0.5), "run mode, reduced motion and shake intensity survive settings reload")
    _expect(is_equal_approx(float(settings.get("ui_scale")), 1.25) and is_equal_approx(float(settings.get("text_scale")), 1.25), "UI and text scale survive settings reload")
    _expect(_action_uses_physical_key(&"move_up", KEY_UP), "custom input binding survives settings reload")

    main_reset_controls.pressed.emit()
    _expect(_action_uses_physical_key(&"move_up", KEY_W), "Reset Control Defaults restores the specification binding through the UI")
    var temporary_key: InputEventKey = InputEventKey.new()
    temporary_key.physical_keycode = KEY_UP
    binding_service.try_rebind_action(&"move_up", temporary_key)
    _expect(int(settings.call("load_from_disk")) == OK and _action_uses_physical_key(&"move_up", KEY_W), "reset defaults is persisted and recovered on reload")

    _write_conflicting_settings_file()
    var prior_run_mode: int = int(settings.get("run_mode"))
    var prior_reduced_motion: bool = bool(settings.get("reduced_motion"))
    var prior_shake_intensity: float = float(settings.get("shake_intensity"))
    var prior_ui_scale: float = float(settings.get("ui_scale"))
    var prior_text_scale: float = float(settings.get("text_scale"))
    _expect(int(settings.call("load_from_disk")) == ERR_INVALID_DATA, "conflicting persisted bindings are rejected instead of bypassing the rebind conflict boundary")
    _expect(_action_uses_physical_key(&"move_up", KEY_W) and _action_uses_physical_key(&"move_down", KEY_S), "rejected persisted binding set leaves the prior InputMap intact")
    _expect(int(settings.get("run_mode")) == prior_run_mode and bool(settings.get("reduced_motion")) == prior_reduced_motion and is_equal_approx(float(settings.get("shake_intensity")), prior_shake_intensity), "invalid persisted bindings cannot partially apply unrelated accessibility settings")
    _expect(is_equal_approx(float(settings.get("ui_scale")), prior_ui_scale) and is_equal_approx(float(settings.get("text_scale")), prior_text_scale), "invalid persisted bindings cannot partially apply UI/text scaling")
    _expect(int(settings.call("save_to_disk")) == OK, "valid current settings can recover the settings file after persisted conflict rejection")

    var main_escape: InputEventAction = InputEventAction.new()
    main_escape.action = &"pause"
    main_escape.pressed = true
    main_settings_menu._input(main_escape)
    _expect(not main_settings_menu.is_open() and main_settings_button.has_focus(), "Escape closes pre-game settings and returns focus to its trigger")
    _expect(first_slot.get_global_rect().end.y <= 360.0 and main_settings_button.get_global_rect().end.y <= 360.0, "largest UI/text settings keep profile and settings triggers reachable on the 640x360 pre-game surface")
    first_slot.pressed.emit()
    await process_frame
    _expect(main_name_edit.has_focus(), "opening an empty slot keeps keyboard focus on protagonist name entry at largest scaling")
    main_class_option.grab_focus()
    await process_frame
    _expect(main_class_option.has_focus() and main_class_option.get_global_rect().intersects(main_profile_scroller.get_global_rect()), "class selection remains keyboard-reachable through the profile scroll layout at largest scaling")
    main_create_button.grab_focus()
    await process_frame
    await process_frame
    _expect(main_create_button.has_focus() and main_create_button.get_global_rect().intersects(main_profile_scroller.get_global_rect()) and main_create_button.get_global_rect().intersects(main_profile_panel.get_global_rect()), "largest UI/text settings scroll the empty-slot Create action into the visible pre-game panel")
    _expect(main_create_button.get_global_rect().position.y >= 0.0 and main_create_button.get_global_rect().end.y <= 360.0, "focused Create action remains within the 640x360 canvas at largest scaling")
    main.queue_free()
    await process_frame

    var gameplay: Node2D = GAMEPLAY_SCENE.instantiate() as Node2D
    root.add_child(gameplay)
    await process_frame

    var coordinator: PauseCoordinator = gameplay.get_node("PauseCoordinator") as PauseCoordinator
    var settings_menu: AccessibilitySettingsMenu = gameplay.get_node("AccessibilitySettingsMenu") as AccessibilitySettingsMenu
    var ownership: InputOwnership = gameplay.get_node("InputOwnership") as InputOwnership
    var player: PlayerController = gameplay.get_node("Player") as PlayerController
    var resume_button: Button = gameplay.get_node("PauseLayer/PausePanel/Menu/Layout/ResumeButton") as Button
    var settings_button: Button = gameplay.get_node("PauseLayer/PausePanel/Menu/Layout/SettingsButton") as Button
    var pause_menu: Control = gameplay.get_node("PauseLayer/PausePanel/Menu") as Control
    var settings_panel: Control = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel") as Control
    var map_overlay: Control = gameplay.get_node("MapMenu/Overlay") as Control
    var map_panel: Control = gameplay.get_node("MapMenu/Overlay/Panel") as Control
    var map_back: Button = gameplay.get_node("MapMenu/Overlay/Panel/Layout/Back") as Button
    var tower_overlay: Control = gameplay.get_node("TowerAccessMenu/Overlay") as Control
    var tower_panel: Control = gameplay.get_node("TowerAccessMenu/Overlay/Panel") as Control
    var tower_back: Button = gameplay.get_node("TowerAccessMenu/Overlay/Panel/Layout/Back") as Button
    var merchant_overlay: Control = gameplay.get_node("MerchantMenu/Overlay") as Control
    var blacksmith_overlay: Control = gameplay.get_node("BlacksmithMenu/Overlay") as Control
    var storage_overlay: Control = gameplay.get_node("StorageHouseMenu/Overlay") as Control
    var run_mode: OptionButton = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel/Scroller/Layout/RunRow/RunMode") as OptionButton
    var reduced_motion: CheckBox = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel/Scroller/Layout/ReducedMotion") as CheckBox
    var shake_slider: HSlider = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel/Scroller/Layout/ShakeRow/ShakeIntensity") as HSlider
    var ui_scale: OptionButton = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel/Scroller/Layout/UIScaleRow/UIScale") as OptionButton
    var text_scale: OptionButton = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel/Scroller/Layout/TextScaleRow/TextScale") as OptionButton
    var pause_scroller: ScrollContainer = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel/Scroller") as ScrollContainer
    var pause_back_button: Button = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel/Scroller/Layout/BackButton") as Button
    var status: Label = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel/Scroller/Layout/Status") as Label

    _expect(player.movement.is_run_toggle_enabled(), "persisted run toggle applies when gameplay is created")
    _expect(player.camera.is_reduced_motion_enabled(), "persisted reduced motion applies when gameplay is created")
    _expect(is_equal_approx(player.camera.get_shake_intensity(), 0.5), "persisted shake intensity applies when gameplay is created")

    coordinator.request_pause(&"manual_pause")
    _expect(paused and resume_button.has_focus(), "opening pause establishes keyboard focus on Resume")
    _expect(resume_button.get_global_rect().end.y <= 360.0 and settings_button.get_global_rect().end.y <= 360.0, "largest persisted UI/text settings keep pause Resume and Settings reachable at 640x360")

    settings_button.pressed.emit()
    _expect(settings_menu.is_open() and settings_panel.visible, "pause menu opens a player-usable accessibility settings surface")
    _expect(ownership.current_modal() == AccessibilitySettingsMenu.SETTINGS_MODAL_ID, "settings uses nested modal input ownership")
    _expect(run_mode.has_focus(), "settings establishes keyboard focus on the first setting")

    player.camera.set_zoom_step(1)
    var world_zoom_before_scaling: Vector2 = player.camera.zoom
    ui_scale.select(0)
    ui_scale.item_selected.emit(0)
    text_scale.select(0)
    text_scale.item_selected.emit(0)
    ui_scale.select(ui_scale.item_count - 1)
    ui_scale.item_selected.emit(ui_scale.selected)
    text_scale.select(text_scale.item_count - 1)
    text_scale.item_selected.emit(text_scale.selected)
    await process_frame
    _expect(player.camera.get_zoom_step() == 1 and player.camera.zoom == world_zoom_before_scaling, "UI/text scaling never changes world-camera zoom")
    _expect(pause_menu.theme != null and is_equal_approx(pause_menu.theme.default_base_scale, 1.25) and pause_menu.theme.default_font_size == 20, "pause UI uses the same separately scalable presentation layer")
    _expect(map_overlay.theme != null and is_equal_approx(map_overlay.theme.default_base_scale, 1.25) and map_overlay.theme.default_font_size == 20, "Map UI consumes the persisted UI/text accessibility scale")
    _expect(tower_overlay.theme != null and is_equal_approx(tower_overlay.theme.default_base_scale, 1.25) and tower_overlay.theme.default_font_size == 20, "Tower Access UI consumes the persisted UI/text accessibility scale")
    for service_overlay: Control in [merchant_overlay, blacksmith_overlay, storage_overlay]:
        _expect(service_overlay.theme != null and is_equal_approx(service_overlay.theme.default_base_scale, 1.25) and service_overlay.theme.default_font_size == 20,
            "%s consumes the global UI/text accessibility scale" % service_overlay.get_parent().name)
    _expect(map_panel.get_global_rect().position.y >= 0.0 and map_panel.get_global_rect().end.y <= 360.0 and map_back.get_global_rect().end.y <= 360.0, "largest UI/text settings keep Map panel and Close action inside the 640x360 canvas")
    _expect(tower_panel.get_global_rect().position.y >= 0.0 and tower_panel.get_global_rect().end.y <= 360.0 and tower_back.get_global_rect().end.y <= 360.0, "largest UI/text settings keep Tower Access panel and Close action inside the 640x360 canvas")
    pause_back_button.grab_focus()
    await process_frame
    await process_frame
    _expect(pause_back_button.has_focus() and pause_back_button.get_global_rect().intersects(pause_scroller.get_global_rect()), "pause settings Back remains keyboard-reachable through scrolling at largest UI/text settings")

    run_mode.select(AccessibilitySettingsMenu.RUN_MODE_HOLD)
    run_mode.item_selected.emit(AccessibilitySettingsMenu.RUN_MODE_HOLD)
    _expect(player.movement.resolve_run_active(true, true), "hold-run mode is active only while the run input is held")
    _expect(not player.movement.resolve_run_active(false, false), "hold-run mode releases when the input is released")

    run_mode.select(AccessibilitySettingsMenu.RUN_MODE_TOGGLE)
    run_mode.item_selected.emit(AccessibilitySettingsMenu.RUN_MODE_TOGGLE)
    _expect(player.movement.is_run_toggle_enabled(), "settings can switch run input to toggle mode")
    _expect(player.movement.resolve_run_active(true, true), "first run press enables toggled running")
    _expect(player.movement.resolve_run_active(false, false), "toggle-run remains active after releasing the key")
    _expect(not player.movement.resolve_run_active(true, true), "second run press disables toggled running")

    reduced_motion.set_pressed_no_signal(true)
    reduced_motion.toggled.emit(true)
    player.camera.update_aim(Vector2.RIGHT)
    player.camera.request_shake(6.0, 0.2)
    _expect(player.camera.is_reduced_motion_enabled(), "reduced-motion setting applies immediately to the camera")
    _expect(player.camera.get_requested_look_ahead() == Vector2.ZERO and is_zero_approx(player.camera.get_shake_strength()), "reduced motion suppresses look-ahead and screen shake without changing gameplay state")

    reduced_motion.set_pressed_no_signal(false)
    reduced_motion.toggled.emit(false)
    shake_slider.set_value_no_signal(50.0)
    shake_slider.value_changed.emit(50.0)
    player.camera.request_shake(player.camera.max_shake_distance, 0.2)
    _expect(is_equal_approx(player.camera.get_shake_intensity(), 0.5), "screen-shake intensity is keyboard-adjustable through the settings model")
    _expect(is_equal_approx(player.camera.get_shake_strength(), player.camera.max_shake_distance * 0.5), "shake requests are scaled by the selected accessibility intensity")
    _expect(status.text.contains("Run: Toggle") and status.text.contains("Shake: 50%") and status.text.contains("UI: 125%") and status.text.contains("Text: 125%"), "settings exposes clear current-value status text")

    var pause_press: InputEventAction = InputEventAction.new()
    pause_press.action = &"pause"
    pause_press.pressed = true
    coordinator._input(pause_press)
    _expect(paused, "Escape from nested settings returns to pause instead of resuming gameplay")
    _expect(not settings_menu.is_open() and ownership.current_modal() == &"pause_menu", "Escape closes only the settings modal")
    _expect(settings_button.has_focus(), "closing settings returns keyboard focus to its trigger")

    coordinator.resume()
    _write_nonfinite_scale_settings_file()
    _expect(int(settings.call("load_from_disk")) == OK, "settings loader accepts recoverable non-finite presentation values")
    _expect(is_equal_approx(float(settings.get("ui_scale")), 1.0) and is_equal_approx(float(settings.get("text_scale")), 1.0), "non-finite persisted UI/text values recover to the reversible defaults")
    binding_service.reset_all_defaults()
    settings.call("reset_to_defaults")
    gameplay.queue_free()
    _remove_test_settings_file()

    if _failures == 0:
        print("ACCESSIBILITY SETTINGS TEST PASS")
    else:
        push_error("ACCESSIBILITY SETTINGS TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)

func _select_control_action(option: OptionButton, action: StringName) -> void:
    for index: int in range(option.item_count):
        if StringName(option.get_item_metadata(index)) == action:
            option.select(index)
            option.item_selected.emit(index)
            return

func _find_control_action_index(option: OptionButton, action: StringName) -> int:
    for index: int in range(option.item_count):
        if StringName(option.get_item_metadata(index)) == action:
            return index
    return -1

func _action_uses_physical_key(action: StringName, keycode: Key) -> bool:
    for event: InputEvent in InputMap.action_get_events(action):
        if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
            return true
    return false

func _remove_test_settings_file() -> void:
    if FileAccess.file_exists(TEST_SETTINGS_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))

func _write_conflicting_settings_file() -> void:
    var config: ConfigFile = ConfigFile.new()
    config.set_value("accessibility", "run_mode", AccessibilitySettingsMenu.RUN_MODE_HOLD)
    config.set_value("accessibility", "reduced_motion", false)
    config.set_value("accessibility", "shake_intensity", 1.0)
    config.set_value("input", "move_up", {
        "kind": "key",
        "physical_keycode": int(KEY_S),
        "keycode": int(KEY_S),
        "shift": false,
        "ctrl": false,
        "alt": false,
        "meta": false,
    })
    _expect(config.save(TEST_SETTINGS_PATH) == OK, "test can stage a conflicting persisted binding set")

func _write_nonfinite_scale_settings_file() -> void:
    var config: ConfigFile = ConfigFile.new()
    config.set_value("accessibility", "run_mode", AccessibilitySettingsMenu.RUN_MODE_HOLD)
    config.set_value("accessibility", "reduced_motion", false)
    config.set_value("accessibility", "shake_intensity", 1.0)
    config.set_value("accessibility", "ui_scale", INF)
    config.set_value("accessibility", "text_scale", NAN)
    _expect(config.save(TEST_SETTINGS_PATH) == OK, "test can stage non-finite persisted UI/text values")
