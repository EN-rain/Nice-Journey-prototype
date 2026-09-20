class_name EnemyRootLifecycle
extends RefCounted

enum State {
	DORMANT,
	ACTIVE,
	DEFEATED,
	RETURNING,
	RESOLVED,
}

var _state: State = State.DORMANT
var _transition_generation: int = 0
var _last_transition_reason_id: StringName = &""

func get_state() -> State:
	return _state

func get_state_name() -> StringName:
	return _state_name(_state)

func get_transition_generation() -> int:
	return _transition_generation

func get_last_transition_reason_id() -> StringName:
	return _last_transition_reason_id

func is_tactical_eligible() -> bool:
	return _state == State.ACTIVE

func can_hold_group_reservation() -> bool:
	return _state == State.ACTIVE

func request_transition(next_state: State, reason_id: StringName) -> bool:
	if not StableId.is_valid(String(reason_id)):
		return false
	if next_state == _state or not _is_valid_transition(_state, next_state):
		return false
	_state = next_state
	_transition_generation += 1
	_last_transition_reason_id = reason_id
	return true

func get_debug_snapshot() -> Dictionary:
	return {
		"state": int(_state),
		"state_name": _state_name(_state),
		"transition_generation": _transition_generation,
		"last_transition_reason_id": _last_transition_reason_id,
		"tactical_eligible": is_tactical_eligible(),
		"group_reservation_eligible": can_hold_group_reservation(),
	}

func _is_valid_transition(from_state: State, to_state: State) -> bool:
	match from_state:
		State.DORMANT:
			return to_state == State.ACTIVE or to_state == State.RESOLVED
		State.ACTIVE:
			return to_state == State.DORMANT or to_state == State.DEFEATED or to_state == State.RESOLVED
		State.DEFEATED:
			return to_state == State.RETURNING or to_state == State.RESOLVED
		State.RETURNING:
			return to_state == State.DORMANT or to_state == State.ACTIVE or to_state == State.RESOLVED
		State.RESOLVED:
			return false
		_:
			return false

func _state_name(state: State) -> StringName:
	match state:
		State.DORMANT:
			return &"DORMANT"
		State.ACTIVE:
			return &"ACTIVE"
		State.DEFEATED:
			return &"DEFEATED"
		State.RETURNING:
			return &"RETURNING"
		State.RESOLVED:
			return &"RESOLVED"
		_:
			return &"UNKNOWN"
