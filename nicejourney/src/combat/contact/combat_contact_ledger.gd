class_name CombatContactLedger
extends RefCounted

var _contacts_by_action_instance: Dictionary = {}

func try_admit_contact(action_instance_id: int, target_id: StringName, hit_interval_index: int) -> bool:
    if action_instance_id <= 0 or hit_interval_index < 0 or not StableId.is_valid(String(target_id)):
        return false
    var targets: Dictionary = _contacts_by_action_instance.get(action_instance_id, {})
    var intervals: Dictionary = targets.get(target_id, {})
    if intervals.has(hit_interval_index):
        return false
    intervals[hit_interval_index] = true
    targets[target_id] = intervals
    _contacts_by_action_instance[action_instance_id] = targets
    return true

func has_contact(action_instance_id: int, target_id: StringName, hit_interval_index: int) -> bool:
    var targets: Dictionary = _contacts_by_action_instance.get(action_instance_id, {})
    var intervals: Dictionary = targets.get(target_id, {})
    return intervals.has(hit_interval_index)

func get_contact_snapshots(action_instance_id: int, max_records: int = 8) -> Array[Dictionary]:
    var snapshots: Array[Dictionary] = []
    if action_instance_id <= 0 or max_records <= 0:
        return snapshots
    var targets: Dictionary = _contacts_by_action_instance.get(action_instance_id, {})
    var target_ids: Array = targets.keys()
    target_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
    for target_variant: Variant in target_ids:
        var target_id: StringName = StringName(target_variant)
        var intervals: Array = (targets.get(target_id, {}) as Dictionary).keys()
        intervals.sort()
        for interval_variant: Variant in intervals:
            snapshots.append({
                "action_instance_id": action_instance_id,
                "target_id": target_id,
                "hit_interval_index": int(interval_variant),
            })
            if snapshots.size() >= max_records:
                return snapshots
    return snapshots

func clear_action_instance(action_instance_id: int) -> bool:
    return _contacts_by_action_instance.erase(action_instance_id)
