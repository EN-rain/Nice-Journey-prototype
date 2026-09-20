class_name FullAiSimulationLedger
extends RefCounted

const MAX_FULL_AI_COMBATANTS: int = 12

var _encounter_by_actor: Dictionary = {}

func try_admit(actor_id: StringName, encounter_id: StringName) -> bool:
    if not StableId.is_valid(String(actor_id)) or not StableId.is_valid(String(encounter_id)):
        return false
    if _encounter_by_actor.has(actor_id) or _encounter_by_actor.size() >= MAX_FULL_AI_COMBATANTS:
        return false
    _encounter_by_actor[actor_id] = encounter_id
    return true

func release(actor_id: StringName) -> bool:
    if not StableId.is_valid(String(actor_id)) or not _encounter_by_actor.has(actor_id):
        return false
    _encounter_by_actor.erase(actor_id)
    return true

func is_admitted(actor_id: StringName) -> bool:
    return _encounter_by_actor.has(actor_id)

func is_admitted_to_encounter(actor_id: StringName, encounter_id: StringName) -> bool:
    if not _encounter_by_actor.has(actor_id):
        return false
    return StringName(_encounter_by_actor[actor_id]) == encounter_id

func get_admitted_count() -> int:
    return _encounter_by_actor.size()

func get_debug_snapshot() -> Dictionary:
    var actor_ids: Array = _encounter_by_actor.keys()
    actor_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    var admissions: Array[Dictionary] = []
    for actor_variant: Variant in actor_ids:
        var actor_id: StringName = StringName(actor_variant)
        admissions.append({
            "actor_id": actor_id,
            "encounter_id": StringName(_encounter_by_actor[actor_id]),
        })
    return {
        "active_count": _encounter_by_actor.size(),
        "hard_cap": MAX_FULL_AI_COMBATANTS,
        "admissions": admissions,
    }
