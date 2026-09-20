extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/app/main.tscn")
const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TEST_SETTINGS_PATH: String = "user://audio_settings_test.cfg"
const TEST_SAVE_ROOT: String = "user://tests/audio_settings_campaign"

var _failures: int = 0
var _native_bus_state: Dictionary = {}

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var settings: Node = root.get_node_or_null("AccessibilitySettings")
    var audio_service: Node = root.get_node_or_null("AudioService")
    _expect(settings != null and audio_service != null, "settings and native audio services are available")
    if settings == null or audio_service == null:
        quit(1)
        return

    _capture_native_bus_state()
    _remove_test_settings_file()
    _expect(bool(settings.call("set_storage_path", TEST_SETTINGS_PATH)), "audio preferences use the existing settings file boundary outside campaign slots")
    var binding_service: InputBindingService = InputBindingService.new()
    binding_service.reset_all_defaults()
    settings.call("reset_to_defaults")
    settings.call("reset_audio_defaults")

    var save_service: SaveService = SaveService.new(TEST_SAVE_ROOT)
    save_service.delete_slot(1)
    var campaign: ProfileSnapshot = ProfileSnapshot.new()
    campaign.profile_id = "profile:audio_settings"
    campaign.protagonist_name = "Audio Keeper"
    campaign.class_id = "melee"
    campaign.level = 7
    campaign.xp = 321
    _expect(save_service.save_profile(1, campaign) == OK, "campaign fixture is committed before audio preferences change")

    settings.call("set_run_mode", AccessibilitySettingsMenu.RUN_MODE_TOGGLE)
    settings.call("set_reduced_motion", true)
    settings.call("set_shake_intensity", 0.5)
    settings.call("set_ui_scale", 1.25)
    settings.call("set_text_scale", 1.25)
    var up_key: InputEventKey = InputEventKey.new()
    up_key.physical_keycode = KEY_UP
    _expect(bool((settings.call("try_rebind_action", &"move_up", up_key) as Dictionary).get("success", false)), "fixture input preference is distinct before audio reset testing")

    var volumes: Dictionary = {
        &"Master": 85.0,
        &"Music": 70.0,
        &"Gameplay SFX": 55.0,
        &"UI": 40.0,
        &"Ambience": 25.0,
    }
    var mutes: Dictionary = {
        &"Master": false,
        &"Music": true,
        &"Gameplay SFX": false,
        &"UI": true,
        &"Ambience": false,
    }
    for bus_name: StringName in AudioEventDefinition.REQUIRED_BUSES:
        _expect(bool(settings.call("set_audio_bus_volume_percent", bus_name, float(volumes[bus_name]))), "%s volume preference is accepted" % String(bus_name))
        _expect(bool(settings.call("set_audio_bus_muted", bus_name, bool(mutes[bus_name]))), "%s mute preference is accepted" % String(bus_name))
        _expect(_bus_matches(audio_service, bus_name, float(volumes[bus_name]), bool(mutes[bus_name])), "%s preference applies immediately through AudioService" % String(bus_name))
    _expect(not bool(settings.call("set_audio_bus_volume_percent", &"Master", NAN)), "non-finite runtime audio volume is rejected without poisoning native audio")
    _expect(not bool(settings.call("set_audio_bus_volume_percent", &"Not A Bus", 50.0)), "unknown audio bus IDs are rejected")

    var persisted: ConfigFile = ConfigFile.new()
    _expect(persisted.load(TEST_SETTINGS_PATH) == OK, "audio settings persist to the shared settings file")
    for bus_name: StringName in AudioEventDefinition.REQUIRED_BUSES:
        var key: String = _audio_key(bus_name)
        _expect(is_equal_approx(float(persisted.get_value("audio", "%s_volume_percent" % key, -1.0)), float(volumes[bus_name])), "%s volume persists independently" % String(bus_name))
        _expect(bool(persisted.get_value("audio", "%s_muted" % key, not bool(mutes[bus_name]))) == bool(mutes[bus_name]), "%s mute persists independently" % String(bus_name))
    _expect(_campaign_is_unchanged(save_service), "writing audio preferences does not alter campaign-slot state")

    var main: Node = MAIN_SCENE.instantiate()
    main.set("save_root", "user://tests/audio_settings_main")
    root.add_child(main)
    await process_frame
    var main_settings_button: Button = main.get_node("FrontEnd/Panel/Scroller/Layout/SettingsButton") as Button
    var main_settings_panel: Control = main.get_node("FrontEnd/SettingsPanel") as Control
    var main_scroller: ScrollContainer = main.get_node("FrontEnd/SettingsPanel/Scroller") as ScrollContainer
    var main_master_volume: HSlider = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/AudioSection/MasterRow/Volume") as HSlider
    var main_master_mute: CheckBox = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/AudioSection/MasterRow/Mute") as CheckBox
    var main_ambience_mute: CheckBox = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/AudioSection/AmbienceRow/Mute") as CheckBox
    var main_reset_audio: Button = main.get_node("FrontEnd/SettingsPanel/Scroller/Layout/AudioSection/ResetAudioButton") as Button
    main_settings_button.pressed.emit()
    _expect(main_settings_panel.visible and is_equal_approx(main_master_volume.value, 85.0) and not main_master_mute.button_pressed, "pre-game shared settings surface reflects persisted native bus values")

    main_master_volume.set_value_no_signal(65.0)
    main_master_volume.value_changed.emit(65.0)
    main_master_mute.set_pressed_no_signal(true)
    main_master_mute.toggled.emit(true)
    _expect(_bus_matches(audio_service, &"Master", 65.0, true), "pre-game audio controls apply volume and mute immediately")

    var prior_run_mode: int = int(settings.get("run_mode"))
    var prior_reduced_motion: bool = bool(settings.get("reduced_motion"))
    var prior_shake: float = float(settings.get("shake_intensity"))
    var prior_ui_scale: float = float(settings.get("ui_scale"))
    var prior_text_scale: float = float(settings.get("text_scale"))
    main_reset_audio.pressed.emit()
    _expect(_all_audio_defaults(settings, audio_service), "Reset Audio Defaults restores all five buses to 100% and unmuted")
    _expect(int(settings.get("run_mode")) == prior_run_mode and bool(settings.get("reduced_motion")) == prior_reduced_motion and is_equal_approx(float(settings.get("shake_intensity")), prior_shake), "audio-only reset preserves Run, reduced-motion and camera-shake preferences")
    _expect(is_equal_approx(float(settings.get("ui_scale")), prior_ui_scale) and is_equal_approx(float(settings.get("text_scale")), prior_text_scale), "audio-only reset preserves UI and text scale preferences")
    _expect(_action_uses_physical_key(&"move_up", KEY_UP), "audio-only reset preserves custom input bindings")
    _expect(_campaign_is_unchanged(save_service), "audio-only reset leaves campaign state untouched")

    for bus_name: StringName in AudioEventDefinition.REQUIRED_BUSES:
        settings.call("set_audio_bus_volume_percent", bus_name, float(volumes[bus_name]))
        settings.call("set_audio_bus_muted", bus_name, bool(mutes[bus_name]))
        audio_service.call("set_bus_volume_linear", bus_name, 1.0)
        audio_service.call("set_bus_muted", bus_name, false)
    _expect(int(settings.call("load_from_disk")) == OK, "persisted audio preferences reload through the existing settings boundary")
    for bus_name: StringName in AudioEventDefinition.REQUIRED_BUSES:
        _expect(_bus_matches(audio_service, bus_name, float(volumes[bus_name]), bool(mutes[bus_name])), "%s persisted preference is re-applied on reload" % String(bus_name))

    _write_malformed_audio_settings()
    _expect(int(settings.call("load_from_disk")) == OK, "malformed audio values use deterministic recovery instead of rejecting the whole settings file")
    _expect(is_equal_approx(float(settings.call("get_audio_bus_volume_percent", &"Master")), 100.0), "non-finite Master volume recovers to 100%")
    _expect(is_equal_approx(float(settings.call("get_audio_bus_volume_percent", &"Music")), 100.0), "malformed Music volume recovers to 100%")
    _expect(is_equal_approx(float(settings.call("get_audio_bus_volume_percent", &"Gameplay SFX")), 0.0), "negative Gameplay SFX volume clamps to 0%")
    _expect(is_equal_approx(float(settings.call("get_audio_bus_volume_percent", &"UI")), 100.0), "oversized UI volume clamps to 100%")
    _expect(is_equal_approx(float(settings.call("get_audio_bus_volume_percent", &"Ambience")), 100.0), "non-finite Ambience volume recovers to 100%")
    _expect(not bool(settings.call("is_audio_bus_muted", &"Master")) and bool(settings.call("is_audio_bus_muted", &"Music")), "malformed mute data recovers to false while valid boolean mute data survives")
    _expect(_all_native_bus_values_finite(), "recovered persisted audio values cannot poison AudioServer with non-finite state")

    var master_before_invalid_binding: float = float(settings.call("get_audio_bus_volume_percent", &"Master"))
    _write_conflicting_binding_with_audio_change()
    _expect(int(settings.call("load_from_disk")) == ERR_INVALID_DATA, "invalid persisted bindings still reject the settings transaction atomically")
    _expect(is_equal_approx(float(settings.call("get_audio_bus_volume_percent", &"Master")), master_before_invalid_binding) and _bus_matches(audio_service, &"Master", master_before_invalid_binding, false), "invalid binding data cannot partially apply staged audio changes")
    _expect(int(settings.call("save_to_disk")) == OK, "valid in-memory preferences can recover the settings file after atomic rejection")

    main_ambience_mute.grab_focus()
    await process_frame
    await process_frame
    _expect(main_ambience_mute.has_focus() and _control_visible_in_scroller(main_ambience_mute, main_scroller), "last audio row remains keyboard-reachable through focus-follow scrolling at 125% UI/text scale")
    main_reset_audio.grab_focus()
    await process_frame
    await process_frame
    _expect(main_reset_audio.has_focus() and main_reset_audio.get_global_rect().intersects(main_scroller.get_global_rect()), "audio reset remains keyboard-reachable pre-game at the maximum implementation/test scale")

    for bus_name: StringName in AudioEventDefinition.REQUIRED_BUSES:
        settings.call("set_audio_bus_volume_percent", bus_name, float(volumes[bus_name]))
        settings.call("set_audio_bus_muted", bus_name, bool(mutes[bus_name]))
    main.queue_free()
    await process_frame

    var gameplay: Node2D = GAMEPLAY_SCENE.instantiate() as Node2D
    root.add_child(gameplay)
    await process_frame
    var coordinator: PauseCoordinator = gameplay.get_node("PauseCoordinator") as PauseCoordinator
    var pause_settings_button: Button = gameplay.get_node("PauseLayer/PausePanel/Menu/Layout/SettingsButton") as Button
    var pause_scroller: ScrollContainer = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel/Scroller") as ScrollContainer
    var pause_music_volume: HSlider = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel/Scroller/Layout/AudioSection/MusicRow/Volume") as HSlider
    var pause_ambience_mute: CheckBox = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel/Scroller/Layout/AudioSection/AmbienceRow/Mute") as CheckBox
    var pause_reset_audio: Button = gameplay.get_node("PauseLayer/PausePanel/SettingsPanel/Scroller/Layout/AudioSection/ResetAudioButton") as Button
    coordinator.request_pause(&"audio_settings_test")
    pause_settings_button.pressed.emit()
    _expect(is_equal_approx(pause_music_volume.value, 70.0), "pause settings surface shares the same persisted native audio preferences")
    pause_music_volume.set_value_no_signal(35.0)
    pause_music_volume.value_changed.emit(35.0)
    _expect(_bus_matches(audio_service, &"Music", 35.0, true), "pause audio controls apply immediately through the same AudioService boundary")
    pause_ambience_mute.grab_focus()
    await process_frame
    await process_frame
    _expect(pause_ambience_mute.has_focus() and _control_visible_in_scroller(pause_ambience_mute, pause_scroller), "pause audio controls remain keyboard-reachable at maximum UI/text scale")
    pause_reset_audio.grab_focus()
    await process_frame
    await process_frame
    _expect(pause_reset_audio.has_focus() and pause_reset_audio.get_global_rect().intersects(pause_scroller.get_global_rect()), "pause audio reset remains keyboard-reachable through the shared focus-follow scroller")

    coordinator.resume()
    gameplay.queue_free()
    save_service.delete_slot(1)
    binding_service.reset_all_defaults()
    settings.call("reset_to_defaults")
    settings.call("reset_audio_defaults")
    _restore_native_bus_state()
    _remove_test_settings_file()

    if _failures == 0:
        print("AUDIO SETTINGS TEST PASS")
    else:
        push_error("AUDIO SETTINGS TEST FAILURES: %d" % _failures)
    quit(_failures)

func _bus_matches(audio_service: Node, bus_name: StringName, volume_percent: float, muted: bool) -> bool:
    var expected_linear: float = volume_percent / 100.0
    var actual_linear: float = float(audio_service.call("get_bus_volume_linear", bus_name))
    return absf(actual_linear - expected_linear) < 0.01 and bool(audio_service.call("is_bus_muted", bus_name)) == muted

func _all_audio_defaults(settings: Node, audio_service: Node) -> bool:
    for bus_name: StringName in AudioEventDefinition.REQUIRED_BUSES:
        if not is_equal_approx(float(settings.call("get_audio_bus_volume_percent", bus_name)), 100.0):
            return false
        if bool(settings.call("is_audio_bus_muted", bus_name)) or not _bus_matches(audio_service, bus_name, 100.0, false):
            return false
    return true

func _campaign_is_unchanged(save_service: SaveService) -> bool:
    var loaded: ProfileSnapshot = save_service.load_profile(1)
    return loaded != null and loaded.profile_id == "profile:audio_settings" and loaded.protagonist_name == "Audio Keeper" and loaded.level == 7 and loaded.xp == 321

func _write_malformed_audio_settings() -> void:
    var config: ConfigFile = ConfigFile.new()
    _expect(config.load(TEST_SETTINGS_PATH) == OK, "test can load persisted settings before staging malformed audio data")
    config.set_value("audio", "master_volume_percent", INF)
    config.set_value("audio", "master_muted", "yes")
    config.set_value("audio", "music_volume_percent", "broken")
    config.set_value("audio", "music_muted", true)
    config.set_value("audio", "gameplay_sfx_volume_percent", -25.0)
    config.set_value("audio", "ui_volume_percent", 150.0)
    config.set_value("audio", "ambience_volume_percent", NAN)
    _expect(config.save(TEST_SETTINGS_PATH) == OK, "test can stage malformed/non-finite persisted audio values")

func _write_conflicting_binding_with_audio_change() -> void:
    var config: ConfigFile = ConfigFile.new()
    _expect(config.load(TEST_SETTINGS_PATH) == OK, "test can load settings before staging an atomic binding failure")
    config.set_value("audio", "master_volume_percent", 25.0)
    config.set_value("input", "move_up", {
        "kind": "key",
        "physical_keycode": int(KEY_S),
        "keycode": int(KEY_S),
        "shift": false,
        "ctrl": false,
        "alt": false,
        "meta": false,
    })
    _expect(config.save(TEST_SETTINGS_PATH) == OK, "test can stage conflicting input with a different audio value")

func _all_native_bus_values_finite() -> bool:
    for bus_name: StringName in AudioEventDefinition.REQUIRED_BUSES:
        var index: int = AudioServer.get_bus_index(bus_name)
        if index < 0 or not is_finite(AudioServer.get_bus_volume_db(index)):
            return false
    return true

func _capture_native_bus_state() -> void:
    for bus_name: StringName in AudioEventDefinition.REQUIRED_BUSES:
        var index: int = AudioServer.get_bus_index(bus_name)
        _native_bus_state[bus_name] = {
            "db": AudioServer.get_bus_volume_db(index),
            "muted": AudioServer.is_bus_mute(index),
        }

func _restore_native_bus_state() -> void:
    for bus_name: StringName in AudioEventDefinition.REQUIRED_BUSES:
        var state: Dictionary = _native_bus_state.get(bus_name, {})
        var index: int = AudioServer.get_bus_index(bus_name)
        if index >= 0 and not state.is_empty():
            AudioServer.set_bus_volume_db(index, float(state.get("db", 0.0)))
            AudioServer.set_bus_mute(index, bool(state.get("muted", false)))

func _audio_key(bus_name: StringName) -> String:
    return String(bus_name).to_lower().replace(" ", "_")

func _action_uses_physical_key(action: StringName, keycode: Key) -> bool:
    for event: InputEvent in InputMap.action_get_events(action):
        if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
            return true
    return false

func _control_visible_in_scroller(control: Control, scroller: ScrollContainer) -> bool:
    var control_rect: Rect2 = control.get_global_rect()
    var scroller_rect: Rect2 = scroller.get_global_rect()
    return control_rect.position.x >= scroller_rect.position.x and control_rect.end.x <= scroller_rect.end.x and control_rect.position.y >= scroller_rect.position.y and control_rect.end.y <= scroller_rect.end.y

func _remove_test_settings_file() -> void:
    if FileAccess.file_exists(TEST_SETTINGS_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
