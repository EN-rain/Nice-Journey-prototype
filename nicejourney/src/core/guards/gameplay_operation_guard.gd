class_name GameplayOperationGuard
extends Node

const OP_MANUAL_SAVE: StringName = &"manual_save"
const OP_SIGIL_TRAVEL: StringName = &"sigil_travel"
const OP_SERVICE: StringName = &"service"

const REASON_ACTIVE_COMBAT: StringName = &"active_combat"
const REASON_UNSUPPORTED_TRANSIENT_STATE: StringName = &"unsupported_transient_state"
const REASON_GENERATOR_CONSTRUCTION: StringName = &"generator_construction"
const REASON_BOSS_PHASE_TRANSITION: StringName = &"boss_phase_transition"

signal blocker_added(token: int, reason_id: StringName)
signal blocker_removed(token: int, reason_id: StringName)

var _next_token: int = 1
var _blockers: Dictionary = {}

func acquire_blocker(source_id: StringName, reason_id: StringName, reason_text: String, operations: Array[StringName]) -> int:
    if source_id == &"" or reason_id == &"" or operations.is_empty():
        return 0
    var token: int = _next_token
    _next_token += 1
    _blockers[token] = {
        "source_id": source_id,
        "reason_id": reason_id,
        "reason_text": reason_text,
        "operations": operations.duplicate(),
    }
    blocker_added.emit(token, reason_id)
    return token

func release_blocker(token: int) -> bool:
    if not _blockers.has(token):
        return false
    var entry: Dictionary = _blockers[token]
    var reason_id: StringName = StringName(entry.get("reason_id", &""))
    _blockers.erase(token)
    blocker_removed.emit(token, reason_id)
    return true

func is_allowed(operation: StringName) -> bool:
    return get_blocking_reasons(operation).is_empty()

func get_blocking_reasons(operation: StringName) -> Array[Dictionary]:
    var reasons: Array[Dictionary] = []
    for token_variant: Variant in _blockers.keys():
        var token: int = int(token_variant)
        var entry: Dictionary = _blockers[token]
        var operations: Array = entry.get("operations", [])
        if operation not in operations:
            continue
        reasons.append({
            "token": token,
            "source_id": StringName(entry.get("source_id", &"")),
            "reason_id": StringName(entry.get("reason_id", &"")),
            "reason_text": String(entry.get("reason_text", "")),
        })
    reasons.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["token"]) < int(b["token"]))
    return reasons

func release_source(source_id: StringName) -> int:
    var released: int = 0
    var tokens: Array = _blockers.keys()
    for token_variant: Variant in tokens:
        var token: int = int(token_variant)
        var entry: Dictionary = _blockers[token]
        if StringName(entry.get("source_id", &"")) != source_id:
            continue
        if release_blocker(token):
            released += 1
    return released

func clear_all() -> void:
    _blockers.clear()
