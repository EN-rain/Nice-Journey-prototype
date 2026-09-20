extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var valid := _routing()
    _expect(valid.validate_definition().is_empty(), "fully authored routing definition validates")
    _expect(valid.event_definitions().size() == 4, "valid routing exposes exactly four authored event definitions")
    _expect(valid.events_by_state().size() == 4, "valid routing exposes exactly four state mappings")
    _expect(bool(valid.production_readiness().get("available", false)), "routing production readiness requires all four real stream references plus explicit transition timing")

    var undeclared_transition := _routing()
    undeclared_transition.fade_seconds_declared = false
    _expect(not undeclared_transition.validate_definition().is_empty(), "production music routing cannot silently treat the default fade value as authored")

    var unauthored := _routing()
    unauthored.authored = false
    _expect(not unauthored.validate_definition().is_empty(), "routing requires the explicit authored flag")

    var duplicate_ids := _routing()
    duplicate_ids.recovery_event.event_id = duplicate_ids.boss_event.event_id
    _expect(not duplicate_ids.validate_definition().is_empty(), "four music states require unique event IDs")

    var wrong_bus := _routing()
    wrong_bus.combat_event.bus = &"Ambience"
    _expect(not wrong_bus.validate_definition().is_empty(), "every routed event must use the Music bus")

    var positional := _routing()
    positional.boss_event.positional = true
    _expect(not positional.validate_definition().is_empty(), "routed music must be non-positional")

    var one_shot := _routing()
    one_shot.recovery_event.lifecycle = AudioEventDefinition.Lifecycle.ONE_SHOT
    _expect(not one_shot.validate_definition().is_empty(), "routed music requires loop lifecycle")

    var streamless := _routing()
    streamless.exploration_event.stream = null
    _expect(not streamless.validate_definition().is_empty(), "every routed state requires a real AudioStream")
    var streamless_readiness := streamless.production_readiness()
    _expect(not bool(streamless_readiness.get("available", true)) and (streamless_readiness.get("missing_fields", PackedStringArray()) as PackedStringArray).has("exploration_stream"), "production readiness reports the exact missing exploration stream instead of accepting a test placeholder")

    var missing_event := _routing()
    missing_event.combat_event = null
    _expect(not missing_event.validate_definition().is_empty(), "all four routed states require authored events")

    for invalid_fade: float in [-1.0, INF, NAN]:
        var invalid := _routing()
        invalid.fade_seconds = invalid_fade
        _expect(not invalid.validate_definition().is_empty(), "fade_seconds rejects negative or non-finite values")

    for invalid_debounce: float in [-1.0, INF, NAN]:
        var invalid := _routing()
        invalid.debounce_seconds = invalid_debounce
        _expect(not invalid.validate_definition().is_empty(), "debounce_seconds rejects negative or non-finite values")

    if _failures == 0:
        print("AUDIO MUSIC ROUTING DEFINITION TEST PASS")
    else:
        push_error("AUDIO MUSIC ROUTING DEFINITION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _routing() -> AudioMusicRoutingDefinition:
    var routing := AudioMusicRoutingDefinition.new()
    routing.authored = true
    routing.fade_seconds = 0.25
    routing.fade_seconds_declared = true
    routing.debounce_seconds = 0.10
    routing.debounce_seconds_declared = true
    routing.exploration_event = _event(&"audio:test:routing:exploration")
    routing.combat_event = _event(&"audio:test:routing:combat")
    routing.boss_event = _event(&"audio:test:routing:boss")
    routing.recovery_event = _event(&"audio:test:routing:recovery")
    return routing


func _event(event_id: StringName) -> AudioEventDefinition:
    var event := AudioEventDefinition.new()
    event.event_id = event_id
    event.bus = &"Music"
    event.priority = AudioEventDefinition.Priority.GAMEPLAY
    event.positional = false
    event.overlap_limit = 2
    event.lifecycle = AudioEventDefinition.Lifecycle.LOOP
    event.stop_on_owner_exit = true

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_8_BITS
    stream.mix_rate = 8000
    stream.stereo = false
    var samples := PackedByteArray()
    samples.resize(16)
    samples.fill(128)
    stream.data = samples
    event.stream = stream
    return event


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
