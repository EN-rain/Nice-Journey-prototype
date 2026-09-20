class_name AttackPressureLedger
extends RefCounted

const DEFAULT_MAX_COMMITTED_ATTACKS_INITIAL_TUNING: int = 3

var max_committed_attacks: int = DEFAULT_MAX_COMMITTED_ATTACKS_INITIAL_TUNING
var _next_token: int = 1
var _entries: Dictionary = {}
var _token_by_actor_action: Dictionary = {}

func _init(authored_max_committed_attacks: int = DEFAULT_MAX_COMMITTED_ATTACKS_INITIAL_TUNING) -> void:
    max_committed_attacks = maxi(authored_max_committed_attacks, 1)

func try_admit(actor_id: StringName, target_id: StringName, encounter_id: StringName, action_instance_id: int) -> int:
    if not StableId.is_valid(String(actor_id)) \
        or not StableId.is_valid(String(target_id)) \
        or not StableId.is_valid(String(encounter_id)) \
        or action_instance_id <= 0:
        return 0
    var actor_actions := _token_by_actor_action.get(actor_id, {}) as Dictionary
    if actor_actions.has(action_instance_id) or _entries.size() >= max_committed_attacks:
        return 0
    var token := _next_token
    _next_token += 1
    _entries[token] = {
        "actor_id": actor_id,
        "target_id": target_id,
        "encounter_id": encounter_id,
        "action_instance_id": action_instance_id,
    }
    actor_actions[action_instance_id] = token
    _token_by_actor_action[actor_id] = actor_actions
    return token

func release(token: int, reason_id: StringName) -> bool:
    if token <= 0 or not _entries.has(token) or not _supported_reason(reason_id):
        return false
    _erase(token)
    return true

func release_actor(actor_id: StringName, reason_id: StringName) -> int:
    if reason_id != AttackReservationLedger.RELEASE_DEATH:
        return 0
    return _release_matching(func(entry: Dictionary) -> bool: return StringName(entry.get("actor_id", &"")) == actor_id)

func release_target(target_id: StringName, reason_id: StringName) -> int:
    if reason_id != AttackReservationLedger.RELEASE_TARGET_INVALIDATION:
        return 0
    return _release_matching(func(entry: Dictionary) -> bool: return StringName(entry.get("target_id", &"")) == target_id)

func release_encounter(encounter_id: StringName, reason_id: StringName) -> int:
    if reason_id != AttackReservationLedger.RELEASE_ENCOUNTER_EXIT:
        return 0
    return _release_matching(func(entry: Dictionary) -> bool: return StringName(entry.get("encounter_id", &"")) == encounter_id)

func get_active_count() -> int:
    return _entries.size()

func has_capacity() -> bool:
    return _entries.size() < max_committed_attacks

func matches_commitment(
    token: int,
    actor_id: StringName,
    target_id: StringName,
    encounter_id: StringName,
    action_instance_id: int
) -> bool:
    if token <= 0 or not _entries.has(token):
        return false
    var entry := _entries[token] as Dictionary
    return StringName(entry.get("actor_id", &"")) == actor_id \
        and StringName(entry.get("target_id", &"")) == target_id \
        and StringName(entry.get("encounter_id", &"")) == encounter_id \
        and int(entry.get("action_instance_id", 0)) == action_instance_id

func get_debug_snapshot() -> Dictionary:
    var tokens: Array = _entries.keys()
    tokens.sort()
    var entries: Array[Dictionary] = []
    for raw_token: Variant in tokens:
        var token := int(raw_token)
        var entry := _entries[token] as Dictionary
        entries.append({
            "token": token,
            "actor_id": StringName(String(entry.get("actor_id", &""))),
            "target_id": StringName(String(entry.get("target_id", &""))),
            "encounter_id": StringName(String(entry.get("encounter_id", &""))),
            "action_instance_id": int(entry.get("action_instance_id", 0)),
        })
    return {
        "max_committed_attacks": max_committed_attacks,
        "active_count": _entries.size(),
        "has_capacity": has_capacity(),
        "entries": entries,
    }

func _release_matching(predicate: Callable) -> int:
    var tokens: Array = _entries.keys()
    tokens.sort()
    var released := 0
    for raw_token: Variant in tokens:
        var token := int(raw_token)
        if predicate.call(_entries[token] as Dictionary):
            _erase(token)
            released += 1
    return released

func _erase(token: int) -> void:
    var entry := _entries[token] as Dictionary
    var actor_id := StringName(String(entry.get("actor_id", &"")))
    var action_instance_id := int(entry.get("action_instance_id", 0))
    _entries.erase(token)
    var actor_actions := _token_by_actor_action.get(actor_id, {}) as Dictionary
    actor_actions.erase(action_instance_id)
    if actor_actions.is_empty():
        _token_by_actor_action.erase(actor_id)
    else:
        _token_by_actor_action[actor_id] = actor_actions

func _supported_reason(reason_id: StringName) -> bool:
    return [
        AttackReservationLedger.RELEASE_COMPLETION,
        AttackReservationLedger.RELEASE_CANCELLATION,
        AttackReservationLedger.RELEASE_INTERRUPTION,
        AttackReservationLedger.RELEASE_DEATH,
        AttackReservationLedger.RELEASE_TARGET_INVALIDATION,
        AttackReservationLedger.RELEASE_ENCOUNTER_EXIT,
    ].has(reason_id)
