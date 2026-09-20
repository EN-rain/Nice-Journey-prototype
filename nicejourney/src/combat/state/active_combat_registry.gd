class_name ActiveCombatRegistry
extends RefCounted

const REASON_ENGAGED_HOSTILE_ENCOUNTER: StringName = &"engaged_hostile_encounter"
const REASON_UNRESOLVED_ATTACK_THREAT: StringName = &"unresolved_attack_threat"
const REASON_CONTESTED_ENCOUNTER_OBJECTIVE: StringName = &"contested_encounter_objective"
const REASON_BOSS_PHASE_OR_COMMITTED_ATTACK: StringName = &"boss_phase_or_committed_attack"

var _reasons_by_source: Dictionary = {}

func acquire(source_id: StringName, reason_id: StringName) -> bool:
    if not StableId.is_valid(String(source_id)) or not _is_supported_reason(reason_id):
        return false
    var source_reasons: Dictionary = _reasons_by_source.get(source_id, {}) as Dictionary
    if source_reasons.has(reason_id):
        return false
    source_reasons[reason_id] = true
    _reasons_by_source[source_id] = source_reasons
    return true

func release(source_id: StringName, reason_id: StringName) -> bool:
    if not _reasons_by_source.has(source_id):
        return false
    var source_reasons: Dictionary = _reasons_by_source[source_id] as Dictionary
    if not source_reasons.has(reason_id):
        return false
    source_reasons.erase(reason_id)
    if source_reasons.is_empty():
        _reasons_by_source.erase(source_id)
    return true

func release_source(source_id: StringName) -> int:
    if not _reasons_by_source.has(source_id):
        return 0
    var released: int = (_reasons_by_source[source_id] as Dictionary).size()
    _reasons_by_source.erase(source_id)
    return released

func is_active() -> bool:
    return not _reasons_by_source.is_empty()

func get_active_reason_count() -> int:
    var count: int = 0
    for reasons_variant: Variant in _reasons_by_source.values():
        count += (reasons_variant as Dictionary).size()
    return count

func get_debug_snapshot() -> Dictionary:
    var source_ids: Array = _reasons_by_source.keys()
    source_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    var reasons: Array[Dictionary] = []
    for source_variant: Variant in source_ids:
        var source_id: StringName = StringName(source_variant)
        var source_reasons: Dictionary = _reasons_by_source[source_id] as Dictionary
        var reason_ids: Array = source_reasons.keys()
        reason_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
        for reason_variant: Variant in reason_ids:
            reasons.append({
                "source_id": source_id,
                "reason_id": StringName(reason_variant),
            })
    return {
        "active": is_active(),
        "reason_count": reasons.size(),
        "reasons": reasons,
    }

func _is_supported_reason(reason_id: StringName) -> bool:
    return reason_id == REASON_ENGAGED_HOSTILE_ENCOUNTER \
        or reason_id == REASON_UNRESOLVED_ATTACK_THREAT \
        or reason_id == REASON_CONTESTED_ENCOUNTER_OBJECTIVE \
        or reason_id == REASON_BOSS_PHASE_OR_COMMITTED_ATTACK
