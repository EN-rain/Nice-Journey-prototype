extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var service: Node = root.get_node_or_null("AudioService")
    _expect(service != null, "AudioService exists for gameplay music routing")
    if service == null:
        quit(1)
        return
    service.call("clear_active_event_instances")
    service.call("clear_registered_events")

    var routing := _routing_definition()
    _expect(routing.validate_definition().is_empty(), "fully authored four-state music routing validates")
    var incomplete := AudioMusicRoutingDefinition.new()
    _expect(not incomplete.validate_definition().is_empty(), "unconfigured production routing fails closed")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.music_routing_definition = routing
    root.add_child(gameplay)
    await process_frame
    var snapshot := gameplay.get_music_routing_snapshot()
    _expect(bool(snapshot.get("ready", false)), "GameplayRoot configures valid authored music routing")
    _expect(StringName(snapshot.get("current_state", &"")) == AudioMusicStateController.STATE_EXPLORATION, "gameplay starts in authored exploration state")
    _expect(int(service.call("get_active_event_instance_count")) == 1, "exploration owns exactly one persistent music instance")

    _expect(gameplay.shared_active_combat.acquire(&"test:music_combat", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER), "test enters shared Active Combat")
    await process_frame
    _expect(StringName(gameplay.get_music_routing_snapshot().get("current_state", &"")) == AudioMusicStateController.STATE_COMBAT, "Active Combat routes to combat music")

    _expect(gameplay.set_music_override_state(AudioMusicStateController.STATE_BOSS), "explicit boss override is admitted")
    await process_frame
    _expect(StringName(gameplay.get_music_routing_snapshot().get("current_state", &"")) == AudioMusicStateController.STATE_BOSS, "boss override takes precedence over ordinary combat")

    _expect(gameplay.set_music_override_state(AudioMusicStateController.STATE_RECOVERY), "explicit recovery override is admitted")
    await process_frame
    _expect(StringName(gameplay.get_music_routing_snapshot().get("current_state", &"")) == AudioMusicStateController.STATE_RECOVERY, "recovery state requires explicit caller ownership rather than an invented hold timer")

    _expect(gameplay.clear_music_override_state(), "clearing explicit music override succeeds")
    await process_frame
    _expect(StringName(gameplay.get_music_routing_snapshot().get("current_state", &"")) == AudioMusicStateController.STATE_COMBAT, "clearing recovery returns to still-active shared combat state")
    _expect(gameplay.shared_active_combat.release(&"test:music_combat", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER), "test exits shared Active Combat")
    await process_frame
    _expect(StringName(gameplay.get_music_routing_snapshot().get("current_state", &"")) == AudioMusicStateController.STATE_EXPLORATION, "normal routing returns to exploration after combat ends")

    gameplay.queue_free()
    await process_frame
    _expect(int(service.call("get_active_event_instance_count")) == 0, "GameplayRoot teardown releases persistent music ownership")
    service.call("clear_registered_events")
    await create_timer(0.25).timeout
    await process_frame

    if _failures == 0:
        print("GAMEPLAY MUSIC ROUTING TEST PASS")
    else:
        push_error("GAMEPLAY MUSIC ROUTING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _routing_definition() -> AudioMusicRoutingDefinition:
    var routing := AudioMusicRoutingDefinition.new()
    routing.authored = true
    routing.fade_seconds = 0.0
    routing.fade_seconds_declared = true
    routing.debounce_seconds = 0.0
    routing.debounce_seconds_declared = true
    routing.exploration_event = _event(&"audio:test:route_exploration")
    routing.combat_event = _event(&"audio:test:route_combat")
    routing.boss_event = _event(&"audio:test:route_boss")
    routing.recovery_event = _event(&"audio:test:route_recovery")
    return routing


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
