class_name EncounterBlackboard
extends RefCounted

const DEFAULT_FACT_CAPACITY: int = 32

var encounter_id: StringName = &""
var memory: AiObservationMemory = null
var admission: AiObservationAdmission = null
var _role_owners: Dictionary = {}

func configure(new_encounter_id: StringName, fact_capacity: int = DEFAULT_FACT_CAPACITY) -> bool:
    if not StableId.is_valid(String(new_encounter_id)) or fact_capacity <= 0:
        return false
    encounter_id = new_encounter_id
    memory = AiObservationMemory.new(fact_capacity)
    admission = AiObservationAdmission.new(memory)
    _role_owners.clear()
    return true

func publish_observed_fact(
    source_id: StringName,
    observed_position: Vector2,
    observed_state: StringName,
    observed_tick: int,
    confidence: float,
    lifetime_ticks: int,
    admission_tick: int
) -> bool:
    if admission == null:
        return false
    return admission.admit_shared_fact(
        source_id,
        observed_position,
        observed_state,
        observed_tick,
        confidence,
        lifetime_ticks,
        admission_tick
    )

func latest_fact(source_id: StringName, now_tick: int, confidence_decay_per_tick: float = 0.0) -> Dictionary:
    if memory == null:
        return {}
    return memory.latest_for_source(source_id, now_tick, confidence_decay_per_tick)

func purge_expired(now_tick: int) -> int:
    return 0 if memory == null else memory.purge_expired(now_tick)

func try_claim_role(role_id: StringName, actor_id: StringName, lifecycle: EnemyRootLifecycle) -> bool:
    if not StableId.is_valid(String(role_id)) or not StableId.is_valid(String(actor_id)):
        return false
    if lifecycle == null or not lifecycle.can_hold_group_reservation():
        return false
    if _role_owners.has(role_id):
        return StringName(String(_role_owners[role_id])) == actor_id
    for existing_role: Variant in _role_owners.keys():
        if StringName(String(_role_owners[existing_role])) == actor_id:
            return false
    _role_owners[role_id] = actor_id
    return true

func release_role(role_id: StringName, actor_id: StringName) -> bool:
    if not _role_owners.has(role_id):
        return false
    if StringName(String(_role_owners[role_id])) != actor_id:
        return false
    _role_owners.erase(role_id)
    return true

func release_actor_roles(actor_id: StringName) -> int:
    if actor_id == &"":
        return 0
    var removed := 0
    for raw_role: Variant in _role_owners.keys():
        if StringName(String(_role_owners[raw_role])) != actor_id:
            continue
        _role_owners.erase(raw_role)
        removed += 1
    return removed

func get_role_owner(role_id: StringName) -> StringName:
    return StringName(String(_role_owners.get(role_id, &"")))

func get_debug_snapshot(now_tick: int) -> Dictionary:
    var role_ids: Array = _role_owners.keys()
    role_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    var roles: Array[Dictionary] = []
    for raw_role: Variant in role_ids:
        roles.append({
            "role_id": StringName(String(raw_role)),
            "actor_id": StringName(String(_role_owners[raw_role])),
        })
    return {
        "encounter_id": encounter_id,
        "shared_observations": memory.get_debug_observations(now_tick) if memory != null else [],
        "role_owners": roles,
    }
