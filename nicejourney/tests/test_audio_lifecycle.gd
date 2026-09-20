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

    audio_service.call("clear_active_event_instances")
    audio_service.call("clear_registered_events")
    _expect(int(audio_service.call("get_important_positional_slot_count")) == 0, "audio lifecycle fixture begins with no important positional leases")

    var critical: AudioEventDefinition = _make_event(
        &"audio:test:lifecycle:critical",
        &"Gameplay SFX",
        AudioEventDefinition.Priority.CRITICAL,
        true,
        2,
        AudioEventDefinition.Lifecycle.ONE_SHOT
    )
    _expect(bool(audio_service.call("register_event", critical)), "critical fixture event registers")
    var critical_a: int = int(audio_service.call("try_begin_event", critical.event_id, &"actor:a"))
    var critical_b: int = int(audio_service.call("try_begin_event", critical.event_id, &"actor:b"))
    _expect(critical_a > 0 and critical_b > 0, "event instances admit up to the authored same-event overlap limit")
    _expect(int(audio_service.call("try_begin_event", critical.event_id, &"actor:c")) == 0, "same-event overlap beyond the authored limit is rejected")
    _expect(int(audio_service.call("get_active_event_count", critical.event_id)) == 2, "active same-event instances remain observable as a bounded count")
    _expect(int(audio_service.call("get_important_positional_slot_count")) == 2, "critical positional event instances consume aggregate important-SFX capacity")
    _expect(not bool(audio_service.call("release_important_positional_slot", critical_a)), "public aggregate-slot release cannot free a lifecycle-owned lease by token collision")
    _expect(int(audio_service.call("get_active_event_count", critical.event_id)) == 2 and int(audio_service.call("get_important_positional_slot_count")) == 2, "failed cross-release leaves lifecycle and aggregate accounting correlated")
    _expect(bool(audio_service.call("end_event", critical_a)), "ending an admitted event instance succeeds")
    _expect(not bool(audio_service.call("end_event", critical_a)), "an already-ended event token cannot release capacity twice")
    _expect(int(audio_service.call("get_active_event_count", critical.event_id)) == 1 and int(audio_service.call("get_important_positional_slot_count")) == 1, "ending an event releases both per-event and aggregate capacity")
    var critical_c: int = int(audio_service.call("try_begin_event", critical.event_id, &"actor:c"))
    _expect(critical_c > 0, "released same-event capacity can be admitted again")

    var owner_loop: AudioEventDefinition = _make_event(
        &"audio:test:lifecycle:owner_loop",
        &"Ambience",
        AudioEventDefinition.Priority.DECORATIVE,
        false,
        3,
        AudioEventDefinition.Lifecycle.LOOP
    )
    owner_loop.stop_on_owner_exit = true
    _expect(bool(audio_service.call("register_event", owner_loop)), "owner-bound loop fixture registers")
    _expect(int(audio_service.call("try_begin_event", owner_loop.event_id)) == 0, "owner-exit loop cannot start without an owner identity")
    var loop_a1: int = int(audio_service.call("try_begin_event", owner_loop.event_id, &"actor:loop_a"))
    var loop_a2: int = int(audio_service.call("try_begin_event", owner_loop.event_id, &"actor:loop_a"))
    var loop_b: int = int(audio_service.call("try_begin_event", owner_loop.event_id, &"actor:loop_b"))
    _expect(loop_a1 > 0 and loop_a2 > 0 and loop_b > 0, "owner-bound loop instances admit with explicit owners")
    _expect(int(audio_service.call("release_owner_events", &"actor:loop_a")) == 2, "owner teardown releases all event instances owned by that actor")
    _expect(int(audio_service.call("get_active_event_count", owner_loop.event_id)) == 1, "owner teardown leaves unrelated owners active")
    _expect(int(audio_service.call("release_owner_events", &"actor:missing")) == 0, "unknown owner teardown is a no-op")
    _expect(bool(audio_service.call("end_event", loop_b)), "remaining owner loop can stop explicitly")

    var explicit_loop: AudioEventDefinition = _make_event(
        &"audio:test:lifecycle:explicit_loop",
        &"Ambience",
        AudioEventDefinition.Priority.DECORATIVE,
        false,
        1,
        AudioEventDefinition.Lifecycle.LOOP
    )
    explicit_loop.stop_on_owner_exit = false
    explicit_loop.stop_condition_id = &"audio:stop:test"
    _expect(bool(audio_service.call("register_event", explicit_loop)), "explicit-stop loop fixture registers")
    var explicit_token: int = int(audio_service.call("try_begin_event", explicit_loop.event_id))
    _expect(explicit_token > 0, "loop with an explicit stop condition may start without an owner")
    _expect(bool(audio_service.call("end_event", explicit_token)), "ownerless explicit-stop loop can terminate through the lifecycle token")
    explicit_token = int(audio_service.call("try_begin_event", explicit_loop.event_id, &"actor:explicit_loop"))
    _expect(explicit_token > 0, "explicit-stop loop may also carry an owner without opting into owner-exit stopping")
    _expect(int(audio_service.call("release_owner_events", &"actor:explicit_loop")) == 0, "owner teardown preserves events whose authored lifecycle disables owner-exit stopping")
    _expect(int(audio_service.call("get_active_event_count", explicit_loop.event_id)) == 1, "explicit-stop loop remains active until its explicit lifecycle stop")
    _expect(bool(audio_service.call("end_event", explicit_token)), "explicit-stop loop can terminate through the lifecycle token")

    var aggregate_a: AudioEventDefinition = _make_event(
        &"audio:test:lifecycle:aggregate_a",
        &"Gameplay SFX",
        AudioEventDefinition.Priority.GAMEPLAY,
        true,
        20,
        AudioEventDefinition.Lifecycle.ONE_SHOT
    )
    var aggregate_b: AudioEventDefinition = _make_event(
        &"audio:test:lifecycle:aggregate_b",
        &"Gameplay SFX",
        AudioEventDefinition.Priority.GAMEPLAY,
        true,
        20,
        AudioEventDefinition.Lifecycle.ONE_SHOT
    )
    _expect(bool(audio_service.call("register_event", aggregate_a)) and bool(audio_service.call("register_event", aggregate_b)), "aggregate-budget fixture events register")
    audio_service.call("end_event", critical_b)
    audio_service.call("end_event", critical_c)
    var aggregate_tokens: Array[int] = []
    for _index: int in range(20):
        aggregate_tokens.append(int(audio_service.call("try_begin_event", aggregate_a.event_id, &"actor:aggregate")))
    for _index: int in range(12):
        aggregate_tokens.append(int(audio_service.call("try_begin_event", aggregate_b.event_id, &"actor:aggregate")))
    _expect(_all_tokens_valid(aggregate_tokens), "multiple important positional events jointly admit through aggregate capacity up to 32")
    _expect(int(audio_service.call("get_important_positional_slot_count")) == 32, "aggregate important positional budget counts across event IDs")
    _expect(int(audio_service.call("try_begin_event", aggregate_b.event_id, &"actor:aggregate")) == 0, "aggregate important positional budget rejects the 33rd instance across event IDs")
    var freed_aggregate_token: int = aggregate_tokens.pop_back()
    _expect(bool(audio_service.call("end_event", freed_aggregate_token)), "ending one aggregate-budget fixture releases its lease")
    var replacement_token: int = int(audio_service.call("try_begin_event", aggregate_b.event_id, &"actor:aggregate"))
    _expect(replacement_token > 0, "released aggregate capacity is reusable by another important event instance")
    aggregate_tokens.append(replacement_token)

    var decorative: AudioEventDefinition = _make_event(
        &"audio:test:lifecycle:decorative",
        &"Gameplay SFX",
        AudioEventDefinition.Priority.DECORATIVE,
        true,
        1,
        AudioEventDefinition.Lifecycle.ONE_SHOT
    )
    _expect(bool(audio_service.call("register_event", decorative)), "decorative positional fixture registers")
    var decorative_token: int = int(audio_service.call("try_begin_event", decorative.event_id, &"actor:decorative"))
    _expect(decorative_token > 0, "decorative positional event does not consume the important-SFX aggregate budget")
    _expect(int(audio_service.call("get_important_positional_slot_count")) == 32, "decorative admission leaves important positional capacity accounting unchanged")
    audio_service.call("end_event", decorative_token)

    for token: int in aggregate_tokens:
        audio_service.call("end_event", token)
    audio_service.call("clear_active_event_instances")
    _expect(int(audio_service.call("get_active_event_instance_count")) == 0, "audio lifecycle cleanup leaves no active event instances")
    _expect(int(audio_service.call("get_important_positional_slot_count")) == 0, "audio lifecycle cleanup releases every aggregate important-SFX lease")

    var registry_clear_fixture: AudioEventDefinition = _make_event(
        &"audio:test:lifecycle:registry_clear",
        &"Gameplay SFX",
        AudioEventDefinition.Priority.GAMEPLAY,
        true,
        1,
        AudioEventDefinition.Lifecycle.ONE_SHOT
    )
    _expect(bool(audio_service.call("register_event", registry_clear_fixture)), "registry-clear lifecycle fixture registers")
    var registry_clear_token: int = int(audio_service.call("try_begin_event", registry_clear_fixture.event_id, &"actor:registry_clear"))
    _expect(registry_clear_token > 0 and int(audio_service.call("get_important_positional_slot_count")) == 1, "registry-clear fixture owns a tracked aggregate lease")
    audio_service.call("clear_registered_events")
    _expect(int(audio_service.call("get_active_event_count", registry_clear_fixture.event_id)) == 1, "clearing event definitions does not orphan an already-admitted lifecycle instance")
    _expect(bool(audio_service.call("end_event", registry_clear_token)), "admitted instance can still terminate after its definition registry is cleared")
    _expect(int(audio_service.call("get_active_event_instance_count")) == 0 and int(audio_service.call("get_important_positional_slot_count")) == 0, "registry clear plus lifecycle termination leaves no leaked bookkeeping")

    if _failures == 0:
        print("AUDIO LIFECYCLE TEST PASS")
    else:
        push_error("AUDIO LIFECYCLE TEST FAILURES: %d" % _failures)
    quit(_failures)

func _make_event(
    event_id: StringName,
    bus: StringName,
    priority: AudioEventDefinition.Priority,
    positional: bool,
    overlap_limit: int,
    lifecycle: AudioEventDefinition.Lifecycle
) -> AudioEventDefinition:
    var definition: AudioEventDefinition = AudioEventDefinition.new()
    definition.event_id = event_id
    definition.bus = bus
    definition.priority = priority
    definition.positional = positional
    definition.overlap_limit = overlap_limit
    definition.lifecycle = lifecycle
    definition.stop_on_owner_exit = true
    return definition

func _all_tokens_valid(tokens: Array[int]) -> bool:
    for token: int in tokens:
        if token <= 0:
            return false
    return true

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
