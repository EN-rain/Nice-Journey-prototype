class_name AudioMusicRoutingDefinition
extends Resource

@export var authored: bool = false
@export var exploration_event: AudioEventDefinition = null
@export var combat_event: AudioEventDefinition = null
@export var boss_event: AudioEventDefinition = null
@export var recovery_event: AudioEventDefinition = null
@export var fade_seconds: float = 0.0
@export var fade_seconds_declared: bool = false
@export var debounce_seconds: float = 0.0
@export var debounce_seconds_declared: bool = false


func validate_definition() -> PackedStringArray:
    var errors := PackedStringArray()
    if not authored:
        errors.append("music routing is not authored")
        return errors
    if not fade_seconds_declared:
        errors.append("fade_seconds must be explicitly authored")
    if not is_finite(fade_seconds) or fade_seconds < 0.0:
        errors.append("fade_seconds must be finite and nonnegative")
    if not debounce_seconds_declared:
        errors.append("debounce_seconds must be explicitly authored")
    if not is_finite(debounce_seconds) or debounce_seconds < 0.0:
        errors.append("debounce_seconds must be finite and nonnegative")

    var seen: Dictionary = {}
    for entry: Dictionary in _state_entries():
        var state_id := entry["state_id"] as StringName
        var definition := entry["event"] as AudioEventDefinition
        if definition == null:
            errors.append("%s music event must be authored" % String(state_id))
            continue
        var definition_errors := definition.validate_definition()
        for definition_error: String in definition_errors:
            errors.append("%s: %s" % [String(state_id), definition_error])
        if definition.bus != &"Music":
            errors.append("%s event must use the Music bus" % String(state_id))
        if definition.positional:
            errors.append("%s event must be non-positional" % String(state_id))
        if definition.lifecycle != AudioEventDefinition.Lifecycle.LOOP:
            errors.append("%s event must be a persistent loop" % String(state_id))
        if definition.stream == null:
            errors.append("%s event requires an authored AudioStream" % String(state_id))
        if seen.has(definition.event_id):
            errors.append("music states must use unique event IDs")
        seen[definition.event_id] = true
    return errors


func production_readiness() -> Dictionary:
    var missing := PackedStringArray()
    if not authored:
        missing.append("authored")
    if not fade_seconds_declared:
        missing.append("fade_seconds")
    if not debounce_seconds_declared:
        missing.append("debounce_seconds")
    for entry: Dictionary in _state_entries():
        var state_id := entry["state_id"] as StringName
        var definition := entry["event"] as AudioEventDefinition
        if definition == null:
            missing.append("%s_event" % String(state_id))
            missing.append("%s_stream" % String(state_id))
        elif definition.stream == null:
            missing.append("%s_stream" % String(state_id))
    var errors := validate_definition() if authored else PackedStringArray(["music routing is not authored"])
    return {
        "available": missing.is_empty() and errors.is_empty(),
        "reason_id": &"" if missing.is_empty() and errors.is_empty() else &"content_unavailable",
        "missing_fields": missing,
        "validation_errors": errors.duplicate(),
    }


func events_by_state() -> Dictionary:
    if not validate_definition().is_empty():
        return {}
    return {
        AudioMusicStateController.STATE_EXPLORATION: exploration_event.event_id,
        AudioMusicStateController.STATE_COMBAT: combat_event.event_id,
        AudioMusicStateController.STATE_BOSS: boss_event.event_id,
        AudioMusicStateController.STATE_RECOVERY: recovery_event.event_id,
    }


func event_definitions() -> Array[AudioEventDefinition]:
    if not validate_definition().is_empty():
        return []
    return [exploration_event, combat_event, boss_event, recovery_event]


func _state_entries() -> Array[Dictionary]:
    return [
        {"state_id": AudioMusicStateController.STATE_EXPLORATION, "event": exploration_event},
        {"state_id": AudioMusicStateController.STATE_COMBAT, "event": combat_event},
        {"state_id": AudioMusicStateController.STATE_BOSS, "event": boss_event},
        {"state_id": AudioMusicStateController.STATE_RECOVERY, "event": recovery_event},
    ]
