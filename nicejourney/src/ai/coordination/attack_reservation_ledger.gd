class_name AttackReservationLedger
extends RefCounted

const RELEASE_COMPLETION: StringName = &"completion"
const RELEASE_CANCELLATION: StringName = &"cancellation"
const RELEASE_INTERRUPTION: StringName = &"interruption"
const RELEASE_DEATH: StringName = &"death"
const RELEASE_TARGET_INVALIDATION: StringName = &"target_invalidation"
const RELEASE_ENCOUNTER_EXIT: StringName = &"encounter_exit"

var _next_token: int = 1
var _reservations: Dictionary = {}
var _token_by_actor_action: Dictionary = {}

func try_reserve(actor_id: StringName, target_id: StringName, encounter_id: StringName, action_instance_id: int) -> int:
    if not StableId.is_valid(String(actor_id)) \
        or not StableId.is_valid(String(target_id)) \
        or not StableId.is_valid(String(encounter_id)) \
        or action_instance_id <= 0:
        return 0

    var actor_actions: Dictionary = _token_by_actor_action.get(actor_id, {}) as Dictionary
    if actor_actions.has(action_instance_id):
        return 0

    var token: int = _next_token
    _next_token += 1
    _reservations[token] = {
        "actor_id": actor_id,
        "target_id": target_id,
        "encounter_id": encounter_id,
        "action_instance_id": action_instance_id,
    }
    actor_actions[action_instance_id] = token
    _token_by_actor_action[actor_id] = actor_actions
    return token

func release(token: int, reason_id: StringName) -> bool:
    if token <= 0 or not _is_supported_release_reason(reason_id) or not _reservations.has(token):
        return false
    _erase_token(token)
    return true

func release_actor(actor_id: StringName, reason_id: StringName) -> int:
    if not StableId.is_valid(String(actor_id)) or reason_id != RELEASE_DEATH:
        return 0
    return _release_matching(func(entry: Dictionary) -> bool: return StringName(entry.get("actor_id", &"")) == actor_id)

func release_target(target_id: StringName, reason_id: StringName) -> int:
    if not StableId.is_valid(String(target_id)) or reason_id != RELEASE_TARGET_INVALIDATION:
        return 0
    return _release_matching(func(entry: Dictionary) -> bool: return StringName(entry.get("target_id", &"")) == target_id)

func release_encounter(encounter_id: StringName, reason_id: StringName) -> int:
    if not StableId.is_valid(String(encounter_id)) or reason_id != RELEASE_ENCOUNTER_EXIT:
        return 0
    return _release_matching(func(entry: Dictionary) -> bool: return StringName(entry.get("encounter_id", &"")) == encounter_id)

func get_active_count() -> int:
    return _reservations.size()

func has_reservation(actor_id: StringName, action_instance_id: int) -> bool:
    var actor_actions: Dictionary = _token_by_actor_action.get(actor_id, {}) as Dictionary
    return actor_actions.has(action_instance_id)

func matches_reservation(
    token: int,
    actor_id: StringName,
    target_id: StringName,
    encounter_id: StringName,
    action_instance_id: int
) -> bool:
    if token <= 0 or not _reservations.has(token):
        return false
    var entry := _reservations[token] as Dictionary
    return StringName(entry.get("actor_id", &"")) == actor_id \
        and StringName(entry.get("target_id", &"")) == target_id \
        and StringName(entry.get("encounter_id", &"")) == encounter_id \
        and int(entry.get("action_instance_id", 0)) == action_instance_id

func has_token(token: int) -> bool:
    return token > 0 and _reservations.has(token)

func get_debug_snapshot(max_records: int = 32) -> Dictionary:
    var records: Array[Dictionary] = []
    if max_records > 0:
        var tokens: Array = _reservations.keys()
        tokens.sort()
        for token_variant: Variant in tokens:
            var token: int = int(token_variant)
            var entry: Dictionary = _reservations[token] as Dictionary
            records.append({
                "token": token,
                "actor_id": StringName(entry.get("actor_id", &"")),
                "target_id": StringName(entry.get("target_id", &"")),
                "encounter_id": StringName(entry.get("encounter_id", &"")),
                "action_instance_id": int(entry.get("action_instance_id", 0)),
            })
            if records.size() >= max_records:
                break
    return {
        "active_count": _reservations.size(),
        "reservations": records,
    }

func _release_matching(predicate: Callable) -> int:
    var tokens: Array = _reservations.keys()
    tokens.sort()
    var released: int = 0
    for token_variant: Variant in tokens:
        var token: int = int(token_variant)
        var entry: Dictionary = _reservations.get(token, {}) as Dictionary
        if predicate.call(entry):
            _erase_token(token)
            released += 1
    return released

func _erase_token(token: int) -> void:
    var entry: Dictionary = _reservations[token] as Dictionary
    var actor_id: StringName = StringName(entry.get("actor_id", &""))
    var action_instance_id: int = int(entry.get("action_instance_id", 0))
    _reservations.erase(token)
    var actor_actions: Dictionary = _token_by_actor_action.get(actor_id, {}) as Dictionary
    actor_actions.erase(action_instance_id)
    if actor_actions.is_empty():
        _token_by_actor_action.erase(actor_id)
    else:
        _token_by_actor_action[actor_id] = actor_actions

func _is_supported_release_reason(reason_id: StringName) -> bool:
    return reason_id == RELEASE_COMPLETION \
        or reason_id == RELEASE_CANCELLATION \
        or reason_id == RELEASE_INTERRUPTION \
        or reason_id == RELEASE_DEATH \
        or reason_id == RELEASE_TARGET_INVALIDATION \
        or reason_id == RELEASE_ENCOUNTER_EXIT
