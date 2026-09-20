class_name AudioMusicStateController
extends RefCounted

const STATE_EXPLORATION: StringName = &"exploration"
const STATE_COMBAT: StringName = &"combat"
const STATE_BOSS: StringName = &"boss"
const STATE_RECOVERY: StringName = &"recovery"
const VALID_STATES: Array[StringName] = [STATE_EXPLORATION, STATE_COMBAT, STATE_BOSS, STATE_RECOVERY]

var _audio_service: Node = null
var _events_by_state: Dictionary = {}
var _fade_seconds: float = 0.0
var _debounce_seconds: float = 0.0
var _current_state: StringName = &""
var _current_token: int = 0
var _previous_token: int = 0
var _transition_elapsed: float = 0.0
var _pending_state: StringName = &""
var _pending_elapsed: float = 0.0


func configure(audio_service: Node, events_by_state: Dictionary, fade_seconds: float, debounce_seconds: float) -> PackedStringArray:
    stop()
    var errors := PackedStringArray()
    if (
        audio_service == null
        or not audio_service.has_method("try_begin_event")
        or not audio_service.has_method("end_event")
        or not audio_service.has_method("set_event_volume_linear")
        or not audio_service.has_method("get_event_definition")
    ):
        errors.append("audio_service with native event playback API is required")
    if not is_finite(fade_seconds) or fade_seconds < 0.0:
        errors.append("fade_seconds must be finite and nonnegative")
    if not is_finite(debounce_seconds) or debounce_seconds < 0.0:
        errors.append("debounce_seconds must be finite and nonnegative")
    var seen_event_ids: Dictionary = {}
    for state_id: StringName in VALID_STATES:
        if not events_by_state.has(state_id) and not events_by_state.has(String(state_id)):
            errors.append("missing music event mapping for %s" % String(state_id))
            continue
        var event_id := StringName(String(events_by_state.get(state_id, events_by_state.get(String(state_id), &""))))
        if not StableId.is_valid(String(event_id)):
            errors.append("music event ID for %s must be stable" % String(state_id))
            continue
        if seen_event_ids.has(event_id):
            errors.append("music states must use unique event IDs")
        else:
            seen_event_ids[event_id] = state_id
        if audio_service != null and audio_service.has_method("get_event_definition"):
            var definition := audio_service.call("get_event_definition", event_id) as AudioEventDefinition
            if definition == null:
                errors.append("music event for %s must be registered" % String(state_id))
                continue
            if definition.bus != &"Music" or definition.positional:
                errors.append("music event for %s must be a registered non-positional Music event" % String(state_id))
            if definition.lifecycle != AudioEventDefinition.Lifecycle.LOOP:
                errors.append("music event for %s must use loop lifecycle" % String(state_id))
            if definition.stream == null:
                errors.append("music event for %s requires an authored AudioStream" % String(state_id))
    if not errors.is_empty():
        _audio_service = null
        _events_by_state.clear()
        _fade_seconds = 0.0
        _debounce_seconds = 0.0
        return errors
    _audio_service = audio_service
    _events_by_state = events_by_state.duplicate(true)
    _fade_seconds = fade_seconds
    _debounce_seconds = debounce_seconds
    return errors


func request_state(state_id: StringName) -> bool:
    if _audio_service == null or not VALID_STATES.has(state_id):
        return false
    if state_id == _current_state:
        _pending_state = &""
        _pending_elapsed = 0.0
        return true
    if state_id == _pending_state:
        return true
    if _current_state == &"" or _debounce_seconds <= 0.0:
        _pending_state = &""
        _pending_elapsed = 0.0
        return _begin_state(state_id)
    _pending_state = state_id
    _pending_elapsed = 0.0
    return true


func advance(delta: float) -> bool:
    if _audio_service == null or not is_finite(delta) or delta < 0.0:
        return false
    if _pending_state != &"":
        _pending_elapsed += delta
        if _pending_elapsed >= _debounce_seconds:
            var state_to_begin := _pending_state
            _pending_state = &""
            _pending_elapsed = 0.0
            if not _begin_state(state_to_begin):
                return false
    _advance_fade(delta)
    return true


func stop() -> void:
    if _audio_service != null:
        if _current_token > 0:
            _audio_service.call("end_event", _current_token)
        if _previous_token > 0 and _previous_token != _current_token:
            _audio_service.call("end_event", _previous_token)
    _current_state = &""
    _current_token = 0
    _previous_token = 0
    _transition_elapsed = 0.0
    _pending_state = &""
    _pending_elapsed = 0.0


func current_state() -> StringName:
    return _current_state

func current_token() -> int:
    return _current_token

func pending_state() -> StringName:
    return _pending_state


func _begin_state(state_id: StringName) -> bool:
    var event_id := StringName(String(_events_by_state.get(state_id, _events_by_state.get(String(state_id), &""))))
    if _previous_token > 0:
        _audio_service.call("end_event", _previous_token)
        _previous_token = 0
    var new_token := int(_audio_service.call("try_begin_event", event_id, &"audio:music_state"))
    if new_token <= 0:
        return false
    _previous_token = _current_token
    _current_token = new_token
    _current_state = state_id
    _transition_elapsed = 0.0
    if _fade_seconds <= 0.0:
        if _previous_token > 0:
            _audio_service.call("end_event", _previous_token)
            _previous_token = 0
        _audio_service.call("set_event_volume_linear", _current_token, 1.0)
    else:
        _audio_service.call("set_event_volume_linear", _current_token, 0.0)
    return true


func _advance_fade(delta: float) -> void:
    if _current_token <= 0 or _fade_seconds <= 0.0:
        return
    _transition_elapsed = minf(_fade_seconds, _transition_elapsed + delta)
    var blend := clampf(_transition_elapsed / _fade_seconds, 0.0, 1.0)
    _audio_service.call("set_event_volume_linear", _current_token, blend)
    if _previous_token > 0:
        _audio_service.call("set_event_volume_linear", _previous_token, 1.0 - blend)
    if blend >= 1.0 and _previous_token > 0:
        _audio_service.call("end_event", _previous_token)
        _previous_token = 0
