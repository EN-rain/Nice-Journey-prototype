extends SceneTree

const MUSIC_CONTROLLER_SCRIPT: Script = preload("res://src/audio/audio_music_state_controller.gd")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var service: Node = root.get_node_or_null("AudioService")
    _expect(service != null, "AudioService is available for native playback")
    if service == null:
        quit(1)
        return
    service.call("clear_active_event_instances")
    service.call("clear_registered_events")
    _test_native_players(service)
    _test_music_state_controller(service)
    service.call("clear_active_event_instances")
    service.call("clear_registered_events")
    # AudioStreamPlayer destruction is deferred, and the native audio thread
    # may retire its AudioStreamPlayback on the next mix cycle rather than the
    # same process frame. Give teardown one bounded audio-mix window before
    # quitting the headless SceneTree so ObjectDB does not race that cleanup.
    await create_timer(0.25).timeout
    await process_frame
    if _failures == 0:
        print("AUDIO NATIVE PLAYBACK TEST PASS")
    else:
        push_error("AUDIO NATIVE PLAYBACK TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_native_players(service: Node) -> void:
    var ui := _event(&"audio:test:native_ui", &"UI", false, AudioEventDefinition.Lifecycle.ONE_SHOT)
    var world := _event(&"audio:test:native_world", &"Gameplay SFX", true, AudioEventDefinition.Lifecycle.ONE_SHOT)
    _expect(bool(service.call("register_event", ui)) and bool(service.call("register_event", world)), "stream-backed native playback events register")
    var ui_token := int(service.call("try_begin_event", ui.event_id, &"owner:ui"))
    var world_token := int(service.call("try_begin_event", world.event_id, &"owner:world", Vector2(42, 84)))
    var ui_player := service.call("get_event_player", ui_token) as Node
    var world_player := service.call("get_event_player", world_token) as Node
    _expect(ui_player is AudioStreamPlayer and String(ui_player.get("bus")) == "UI", "non-positional stream creates a native AudioStreamPlayer on its authored bus")
    _expect(world_player is AudioStreamPlayer2D and (world_player as AudioStreamPlayer2D).position == Vector2(42, 84), "positional stream creates AudioStreamPlayer2D at caller world position")
    _expect(bool(service.call("set_event_volume_linear", ui_token, 0.25)), "active native event exposes bounded per-instance volume control")
    _expect(absf(float(service.call("get_event_volume_linear", ui_token)) - 0.25) < 0.02, "per-instance native volume round-trips")
    _expect(int(service.call("try_begin_event", world.event_id, &"owner:bad", Vector2(INF, 0))) == 0, "non-finite positional playback rejects before lifecycle mutation")
    _expect(bool(service.call("end_event", ui_token)) and bool(service.call("end_event", world_token)), "native playback nodes terminate through existing lifecycle ownership")
    _expect(ui_player.get("stream") == null and world_player.get("stream") == null, "ending native playback releases stream ownership before deferred player deletion")


func _test_music_state_controller(service: Node) -> void:
    service.call("clear_registered_events")
    for state_id: StringName in MUSIC_CONTROLLER_SCRIPT.VALID_STATES:
        var event := _event(StringName("audio:music:%s" % String(state_id)), &"Music", false, AudioEventDefinition.Lifecycle.LOOP)
        _expect(bool(service.call("register_event", event)), "music state %s event registers" % String(state_id))
    var mappings := {
        &"exploration": &"audio:music:exploration",
        &"combat": &"audio:music:combat",
        &"boss": &"audio:music:boss",
        &"recovery": &"audio:music:recovery",
    }
    var controller: RefCounted = MUSIC_CONTROLLER_SCRIPT.new()
    var streamless := AudioEventDefinition.new()
    streamless.event_id = &"audio:test:music:streamless"
    streamless.bus = &"Music"
    streamless.positional = false
    streamless.lifecycle = AudioEventDefinition.Lifecycle.LOOP
    streamless.stop_on_owner_exit = true
    _expect(bool(service.call("register_event", streamless)), "streamless music metadata may remain registered for non-playback catalog use")
    var streamless_mappings: Dictionary = mappings.duplicate(true)
    streamless_mappings[&"boss"] = streamless.event_id
    _expect(not (controller.call("configure", service, streamless_mappings, 0.2, 0.1) as PackedStringArray).is_empty(), "music controller rejects a state mapping that has no authored AudioStream")
    _expect((controller.call("configure", service, mappings, 0.2, 0.1) as PackedStringArray).is_empty(), "music controller validates four native prototype states")
    _expect(bool(controller.call("request_state", &"exploration")), "initial exploration music state starts immediately")
    var first_token := int(controller.call("current_token"))
    _expect(first_token > 0 and int(service.call("get_active_event_instance_count")) == 1, "initial music state owns exactly one persistent lifecycle instance")
    _expect(bool(controller.call("request_state", &"combat")) and StringName(controller.call("pending_state")) == &"combat", "combat transition is debounced instead of spawning immediately")
    _expect(bool(controller.call("request_state", &"exploration")) and StringName(controller.call("pending_state")) == &"", "returning to the current state cancels a pending transition")
    controller.call("advance", 0.1)
    _expect(int(controller.call("current_token")) == first_token and int(service.call("get_active_event_instance_count")) == 1, "cancelled debounce cannot spawn duplicate current-state music")
    _expect(bool(controller.call("request_state", &"combat")) and StringName(controller.call("pending_state")) == &"combat", "combat transition is debounced instead of spawning immediately")
    _expect(bool(controller.call("request_state", &"boss")) and StringName(controller.call("pending_state")) == &"boss", "newer boss request replaces pending combat state during debounce")
    controller.call("advance", 0.05)
    _expect(int(controller.call("current_token")) == first_token, "debounce keeps current music stable before threshold")
    controller.call("advance", 0.05)
    var boss_token := int(controller.call("current_token"))
    _expect(StringName(controller.call("current_state")) == &"boss" and boss_token != first_token, "debounce commits only the latest requested boss state")
    _expect(int(service.call("get_active_event_instance_count")) == 2, "bounded crossfade temporarily owns old and new music only")
    controller.call("advance", 0.2)
    _expect(int(service.call("get_active_event_instance_count")) == 1, "completed crossfade releases prior persistent music instance")
    _expect(bool(controller.call("request_state", &"boss")) and int(service.call("get_active_event_instance_count")) == 1, "requesting current state cannot duplicate persistent music")
    controller.call("stop")
    _expect(int(service.call("get_active_event_instance_count")) == 0, "music controller stop releases owned persistent music")


func _event(event_id: StringName, bus: StringName, positional: bool, lifecycle: AudioEventDefinition.Lifecycle) -> AudioEventDefinition:
    var event := AudioEventDefinition.new()
    event.event_id = event_id
    event.bus = bus
    event.positional = positional
    event.priority = AudioEventDefinition.Priority.GAMEPLAY
    event.overlap_limit = 2
    event.lifecycle = lifecycle
    event.stop_on_owner_exit = true
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_8_BITS
    stream.mix_rate = 8000
    stream.stereo = false
    # Keep the synthetic clip long enough that LOOP fixtures do not complete
    # and restart dozens of native AudioStreamPlayback objects inside a single
    # headless test frame. The test exercises lifecycle control explicitly.
    var samples := PackedByteArray()
    samples.resize(8000)
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
