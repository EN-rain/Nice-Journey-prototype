extends Node

const REQUIRED_BUSES: Array[StringName] = AudioEventDefinition.REQUIRED_BUSES
const MAX_IMPORTANT_POSITIONAL_SFX: int = 32

var _events: Dictionary = {}
var _important_positional_slots: Dictionary = {}
var _event_owned_important_slots: Dictionary = {}
var _next_important_positional_token: int = 1
var _active_event_instances: Dictionary = {}
var _active_tokens_by_event: Dictionary = {}
var _next_event_instance_token: int = 1

func _enter_tree() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    ensure_required_buses()

func ensure_required_buses() -> void:
    for bus_name: StringName in REQUIRED_BUSES:
        if AudioServer.get_bus_index(bus_name) >= 0:
            continue
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func register_event(definition: AudioEventDefinition) -> bool:
    if definition == null or not definition.validate_definition().is_empty():
        return false
    if _events.has(definition.event_id):
        return false
    _events[definition.event_id] = definition
    return true

func has_event(event_id: StringName) -> bool:
    return _events.has(event_id)

func get_event_definition(event_id: StringName) -> AudioEventDefinition:
    return _events.get(event_id) as AudioEventDefinition

func clear_registered_events() -> void:
    _events.clear()

func try_begin_event(event_id: StringName, owner_id: StringName = &"", world_position: Vector2 = Vector2.ZERO) -> int:
    var definition: AudioEventDefinition = get_event_definition(event_id)
    if definition == null:
        return 0
    if definition.positional and (not is_finite(world_position.x) or not is_finite(world_position.y)):
        return 0
    var active_tokens: Array = _active_tokens_by_event.get(event_id, [])
    if active_tokens.size() >= definition.overlap_limit:
        return 0
    if definition.lifecycle == AudioEventDefinition.Lifecycle.LOOP and definition.stop_on_owner_exit and owner_id == &"":
        return 0

    var important_slot_token: int = 0
    if definition.positional and definition.priority != AudioEventDefinition.Priority.DECORATIVE:
        important_slot_token = _try_acquire_important_positional_slot(true)
        if important_slot_token == 0:
            return 0

    var instance_token: int = _next_event_instance_token
    _next_event_instance_token += 1
    _active_event_instances[instance_token] = {
        "event_id": event_id,
        "owner_id": owner_id,
        "important_slot_token": important_slot_token,
        "lifecycle": definition.lifecycle,
        "stop_on_owner_exit": definition.stop_on_owner_exit,
        "player": null,
    }
    active_tokens.append(instance_token)
    _active_tokens_by_event[event_id] = active_tokens
    if definition.stream != null:
        var player := _create_player(definition, world_position)
        if player == null:
            end_event(instance_token)
            return 0
        add_child(player)
        (_active_event_instances[instance_token] as Dictionary)["player"] = player
        player.finished.connect(_on_event_player_finished.bind(instance_token))
        player.play()
    return instance_token

func end_event(instance_token: int) -> bool:
    if instance_token <= 0 or not _active_event_instances.has(instance_token):
        return false
    var entry: Dictionary = _active_event_instances[instance_token]
    _active_event_instances.erase(instance_token)
    var player_variant: Variant = entry.get("player", null)
    if player_variant is Node and is_instance_valid(player_variant as Node):
        var player := player_variant as Node
        if player.has_method("stop"):
            player.call("stop")
        # Release the native AudioStreamPlayback immediately instead of keeping
        # it alive until the deferred node deletion is flushed at frame end.
        # This keeps lifecycle teardown deterministic during scene/process exit.
        player.set("stream", null)
        player.queue_free()
    var event_id: StringName = StringName(entry.get("event_id", &""))
    var active_tokens: Array = _active_tokens_by_event.get(event_id, [])
    active_tokens.erase(instance_token)
    if active_tokens.is_empty():
        _active_tokens_by_event.erase(event_id)
    else:
        _active_tokens_by_event[event_id] = active_tokens
    var important_slot_token: int = int(entry.get("important_slot_token", 0))
    if important_slot_token > 0:
        _release_important_positional_slot_internal(important_slot_token)
    return true

func release_owner_events(owner_id: StringName) -> int:
    if owner_id == &"":
        return 0
    var tokens: Array = _active_event_instances.keys()
    tokens.sort()
    var released: int = 0
    for token_variant: Variant in tokens:
        var token: int = int(token_variant)
        var entry: Dictionary = _active_event_instances.get(token, {})
        if StringName(entry.get("owner_id", &"")) != owner_id:
            continue
        if not bool(entry.get("stop_on_owner_exit", false)):
            continue
        if end_event(token):
            released += 1
    return released

func get_active_event_count(event_id: StringName) -> int:
    return (_active_tokens_by_event.get(event_id, []) as Array).size()

func get_active_event_instance_count() -> int:
    return _active_event_instances.size()

func get_event_player(instance_token: int) -> Node:
    if not _active_event_instances.has(instance_token):
        return null
    var player_variant: Variant = (_active_event_instances[instance_token] as Dictionary).get("player", null)
    return player_variant as Node if player_variant is Node and is_instance_valid(player_variant as Node) else null

func set_event_volume_linear(instance_token: int, linear_volume: float) -> bool:
    if instance_token <= 0 or not is_finite(linear_volume) or not _active_event_instances.has(instance_token):
        return false
    var player := get_event_player(instance_token)
    if player == null:
        return false
    var clamped := clampf(linear_volume, 0.0, 1.0)
    player.set("volume_db", -80.0 if clamped <= 0.0 else linear_to_db(clamped))
    return true

func get_event_volume_linear(instance_token: int) -> float:
    var player := get_event_player(instance_token)
    if player == null:
        return 0.0
    return db_to_linear(float(player.get("volume_db")))

func clear_active_event_instances() -> void:
    var tokens: Array = _active_event_instances.keys()
    tokens.sort()
    for token_variant: Variant in tokens:
        end_event(int(token_variant))

func try_acquire_important_positional_slot() -> int:
    return _try_acquire_important_positional_slot(false)

func release_important_positional_slot(token: int) -> bool:
    if token <= 0 or _event_owned_important_slots.has(token):
        return false
    return _release_important_positional_slot_internal(token)

func _try_acquire_important_positional_slot(event_owned: bool) -> int:
    if _important_positional_slots.size() >= MAX_IMPORTANT_POSITIONAL_SFX:
        return 0
    var token: int = _next_important_positional_token
    _next_important_positional_token += 1
    _important_positional_slots[token] = true
    if event_owned:
        _event_owned_important_slots[token] = true
    return token

func _release_important_positional_slot_internal(token: int) -> bool:
    if token <= 0 or not _important_positional_slots.has(token):
        return false
    _event_owned_important_slots.erase(token)
    _important_positional_slots.erase(token)
    return true

func get_important_positional_slot_count() -> int:
    return _important_positional_slots.size()

func set_bus_volume_linear(bus_name: StringName, linear_volume: float) -> bool:
    var bus_index: int = AudioServer.get_bus_index(bus_name)
    if bus_index < 0 or not is_finite(linear_volume):
        return false
    var clamped: float = clampf(linear_volume, 0.0, 1.0)
    AudioServer.set_bus_volume_db(bus_index, -80.0 if clamped <= 0.0 else linear_to_db(clamped))
    return true

func get_bus_volume_linear(bus_name: StringName) -> float:
    var bus_index: int = AudioServer.get_bus_index(bus_name)
    if bus_index < 0:
        return 0.0
    return db_to_linear(AudioServer.get_bus_volume_db(bus_index))

func set_bus_muted(bus_name: StringName, muted: bool) -> bool:
    var bus_index: int = AudioServer.get_bus_index(bus_name)
    if bus_index < 0:
        return false
    AudioServer.set_bus_mute(bus_index, muted)
    return true

func is_bus_muted(bus_name: StringName) -> bool:
    var bus_index: int = AudioServer.get_bus_index(bus_name)
    return false if bus_index < 0 else AudioServer.is_bus_mute(bus_index)

func _create_player(definition: AudioEventDefinition, world_position: Vector2) -> Node:
    if definition == null or definition.stream == null:
        return null
    if definition.positional:
        var player_2d := AudioStreamPlayer2D.new()
        player_2d.stream = definition.stream
        player_2d.bus = String(definition.bus)
        player_2d.position = world_position
        player_2d.process_mode = Node.PROCESS_MODE_ALWAYS
        return player_2d
    var player := AudioStreamPlayer.new()
    player.stream = definition.stream
    player.bus = String(definition.bus)
    player.process_mode = Node.PROCESS_MODE_ALWAYS
    return player

func _on_event_player_finished(instance_token: int) -> void:
    if not _active_event_instances.has(instance_token):
        return
    var entry := _active_event_instances[instance_token] as Dictionary
    if int(entry.get("lifecycle", AudioEventDefinition.Lifecycle.ONE_SHOT)) == AudioEventDefinition.Lifecycle.LOOP:
        var player := get_event_player(instance_token)
        if player != null and player.has_method("play"):
            player.call("play")
            return
    end_event(instance_token)
