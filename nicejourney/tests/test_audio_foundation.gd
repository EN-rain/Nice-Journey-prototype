extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var audio_service: Node = root.get_node_or_null("AudioService")
    _expect(audio_service != null, "audio service autoload is available")
    if audio_service == null:
        quit(1)
        return

    audio_service.call("ensure_required_buses")
    for bus_name: StringName in AudioEventDefinition.REQUIRED_BUSES:
        _expect(AudioServer.get_bus_index(bus_name) >= 0, "required audio bus exists: %s" % String(bus_name))

    _expect(int(audio_service.get("MAX_IMPORTANT_POSITIONAL_SFX")) == 32, "aggregate important positional SFX cap matches §37.1")

    var admission_tokens: Array[int] = []
    for index: int in range(32):
        var token: int = int(audio_service.call("try_acquire_important_positional_slot"))
        _expect(token > 0, "important positional SFX slot %d is admitted within the aggregate cap" % (index + 1))
        admission_tokens.append(token)
    _expect(int(audio_service.call("get_important_positional_slot_count")) == 32, "aggregate important positional admission tracks all 32 active slots")
    _expect(int(audio_service.call("try_acquire_important_positional_slot")) == 0, "33rd important positional SFX slot is rejected")
    var released_token: int = admission_tokens.pop_back()
    _expect(bool(audio_service.call("release_important_positional_slot", released_token)), "releasing an admitted positional slot succeeds")
    var reacquired_token: int = int(audio_service.call("try_acquire_important_positional_slot"))
    _expect(reacquired_token > 0, "a released important positional slot can be reacquired")
    admission_tokens.append(reacquired_token)
    for token: int in admission_tokens:
        _expect(bool(audio_service.call("release_important_positional_slot", token)), "admitted positional slot releases cleanly")
    _expect(int(audio_service.call("get_important_positional_slot_count")) == 0, "aggregate positional admission returns to zero after releases")

    var critical_event: AudioEventDefinition = AudioEventDefinition.new()
    critical_event.event_id = &"audio:test:danger_windup"
    critical_event.bus = &"Gameplay SFX"
    critical_event.priority = AudioEventDefinition.Priority.CRITICAL
    critical_event.positional = true
    critical_event.overlap_limit = 2
    critical_event.lifecycle = AudioEventDefinition.Lifecycle.ONE_SHOT
    critical_event.duration_hint_seconds = 0.25
    critical_event.variation_allowed = true
    _expect(critical_event.validate_definition().is_empty(), "named critical gameplay event metadata validates without an asset")

    audio_service.call("clear_registered_events")
    _expect(bool(audio_service.call("register_event", critical_event)), "valid named audio event registers once")
    _expect(not bool(audio_service.call("register_event", critical_event)), "duplicate named audio event is rejected")
    _expect(bool(audio_service.call("has_event", critical_event.event_id)), "registered event is addressable by stable event ID")

    var invalid_ui_event: AudioEventDefinition = AudioEventDefinition.new()
    invalid_ui_event.event_id = &"audio:test:ui"
    invalid_ui_event.bus = &"UI"
    invalid_ui_event.positional = true
    _expect(not invalid_ui_event.validate_definition().is_empty(), "UI events reject positional playback metadata")

    var invalid_loop: AudioEventDefinition = AudioEventDefinition.new()
    invalid_loop.event_id = &"audio:test:loop"
    invalid_loop.bus = &"Ambience"
    invalid_loop.positional = false
    invalid_loop.lifecycle = AudioEventDefinition.Lifecycle.LOOP
    invalid_loop.stop_on_owner_exit = false
    _expect(not invalid_loop.validate_definition().is_empty(), "loop metadata requires an explicit stop path")

    var ui_bus_index: int = AudioServer.get_bus_index(&"UI")
    var prior_ui_db: float = AudioServer.get_bus_volume_db(ui_bus_index)
    var prior_ui_mute: bool = AudioServer.is_bus_mute(ui_bus_index)
    _expect(not bool(audio_service.call("set_bus_volume_linear", &"UI", NAN)) and is_equal_approx(AudioServer.get_bus_volume_db(ui_bus_index), prior_ui_db), "native audio boundary rejects non-finite volume without mutating the bus")
    _expect(not bool(audio_service.call("set_bus_volume_linear", &"UI", INF)) and is_equal_approx(AudioServer.get_bus_volume_db(ui_bus_index), prior_ui_db), "native audio boundary rejects infinite volume without mutating the bus")
    _expect(bool(audio_service.call("set_bus_volume_linear", &"UI", 0.5)), "audio service exposes bus volume control")
    _expect(absf(float(audio_service.call("get_bus_volume_linear", &"UI")) - 0.5) < 0.01, "bus volume round-trips through the native AudioServer")
    _expect(bool(audio_service.call("set_bus_muted", &"UI", true)) and bool(audio_service.call("is_bus_muted", &"UI")), "audio service exposes bus mute control")
    AudioServer.set_bus_volume_db(ui_bus_index, prior_ui_db)
    AudioServer.set_bus_mute(ui_bus_index, prior_ui_mute)

    if _failures == 0:
        print("AUDIO FOUNDATION TEST PASS")
    else:
        push_error("AUDIO FOUNDATION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
