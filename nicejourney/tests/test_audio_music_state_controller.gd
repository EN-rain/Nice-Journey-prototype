extends SceneTree

class RecordingAudioService:
    extends Node

    var definitions: Dictionary = {}
    var active_tokens: Dictionary = {}
    var next_token := 1
    var peak_active_count := 0

    func register_definition(definition: AudioEventDefinition) -> void:
        definitions[definition.event_id] = definition

    func try_begin_event(event_id: StringName, _owner_id: StringName = &"", _world_position: Vector2 = Vector2.ZERO) -> int:
        if not definitions.has(event_id):
            return 0
        var token := next_token
        next_token += 1
        active_tokens[token] = event_id
        peak_active_count = maxi(peak_active_count, active_tokens.size())
        return token

    func end_event(token: int) -> bool:
        if not active_tokens.has(token):
            return false
        active_tokens.erase(token)
        return true

    func set_event_volume_linear(token: int, _linear_volume: float) -> bool:
        return active_tokens.has(token)

    func get_event_definition(event_id: StringName) -> AudioEventDefinition:
        return definitions.get(event_id) as AudioEventDefinition


var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_rapid_transition_bound()
    _test_invalid_reconfigure_fails_closed()
    _test_controller_rejects_non_loop_mapping()

    if _failures == 0:
        print("AUDIO MUSIC STATE CONTROLLER TEST PASS")
    else:
        push_error("AUDIO MUSIC STATE CONTROLLER TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_rapid_transition_bound() -> void:
    var service := RecordingAudioService.new()
    var mappings := _register_valid_definitions(service)
    var controller := AudioMusicStateController.new()
    _expect(controller.configure(service, mappings, 1.0, 0.0).is_empty(), "controller accepts four distinct stream-backed loop states")
    _expect(controller.request_state(AudioMusicStateController.STATE_EXPLORATION), "exploration starts")
    _expect(controller.request_state(AudioMusicStateController.STATE_COMBAT), "combat crossfade starts")
    _expect(controller.request_state(AudioMusicStateController.STATE_BOSS), "boss can replace an in-progress crossfade")
    _expect(service.peak_active_count <= 2, "rapid transitions never create more than two persistent music instances")
    _expect(service.active_tokens.size() == 2, "replacement crossfade retains only current and immediately previous music")
    controller.stop()
    _expect(service.active_tokens.is_empty(), "stop releases every controller-owned persistent music token")
    controller.stop()
    _expect(service.active_tokens.is_empty(), "stop is idempotent and cannot duplicate or leak music")
    controller = null
    service.definitions.clear()
    service.free()


func _test_invalid_reconfigure_fails_closed() -> void:
    var service := RecordingAudioService.new()
    var mappings := _register_valid_definitions(service)
    var controller := AudioMusicStateController.new()
    _expect(controller.configure(service, mappings, 0.5, 0.0).is_empty(), "valid configuration is admitted before reconfigure test")
    _expect(controller.request_state(AudioMusicStateController.STATE_EXPLORATION), "valid configuration can start music before reconfigure test")

    var duplicate_mappings: Dictionary = mappings.duplicate(true)
    duplicate_mappings[AudioMusicStateController.STATE_RECOVERY] = mappings[AudioMusicStateController.STATE_BOSS]
    _expect(not controller.configure(service, duplicate_mappings, 0.5, 0.0).is_empty(), "controller rejects duplicate state event IDs")
    _expect(service.active_tokens.is_empty(), "failed reconfigure stops the prior persistent music instance")
    _expect(not controller.request_state(AudioMusicStateController.STATE_EXPLORATION), "failed reconfigure clears stale controller configuration")
    controller = null
    service.definitions.clear()
    service.free()


func _test_controller_rejects_non_loop_mapping() -> void:
    var service := RecordingAudioService.new()
    var mappings := _register_valid_definitions(service)
    var recovery_id: StringName = mappings[AudioMusicStateController.STATE_RECOVERY]
    var recovery := service.get_event_definition(recovery_id)
    recovery.lifecycle = AudioEventDefinition.Lifecycle.ONE_SHOT

    var controller := AudioMusicStateController.new()
    _expect(not controller.configure(service, mappings, 0.0, 0.0).is_empty(), "controller independently rejects non-loop music mappings")
    controller = null
    recovery = null
    service.definitions.clear()
    service.free()


func _register_valid_definitions(service: RecordingAudioService) -> Dictionary:
    var mappings := {
        AudioMusicStateController.STATE_EXPLORATION: &"audio:test:controller:exploration",
        AudioMusicStateController.STATE_COMBAT: &"audio:test:controller:combat",
        AudioMusicStateController.STATE_BOSS: &"audio:test:controller:boss",
        AudioMusicStateController.STATE_RECOVERY: &"audio:test:controller:recovery",
    }
    for state_id: StringName in AudioMusicStateController.VALID_STATES:
        var event_id: StringName = mappings[state_id]
        service.register_definition(_event(event_id))
    return mappings


func _event(event_id: StringName) -> AudioEventDefinition:
    var event := AudioEventDefinition.new()
    event.event_id = event_id
    event.bus = &"Music"
    event.positional = false
    event.priority = AudioEventDefinition.Priority.GAMEPLAY
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
