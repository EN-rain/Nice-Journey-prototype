class_name SafeCheckpointState
extends RefCounted


static func make(
    snapshot_id: StringName,
    map_id: StringName,
    floor_id: int,
    checkpoint_anchor_id: StringName,
    player_state: Dictionary,
    quest_attempt_state: Dictionary,
    snapshot_sequence: int
) -> Dictionary:
    var data: Dictionary = {
        "snapshot_id": String(snapshot_id),
        "map_id": String(map_id),
        "floor_id": floor_id,
        "checkpoint_anchor_id": String(checkpoint_anchor_id),
        "player_state": player_state.duplicate(true),
        "quest_attempt_state": quest_attempt_state.duplicate(true),
        "snapshot_sequence": snapshot_sequence,
    }
    if not validate_dictionary(data).is_empty():
        return {}
    return data


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    var map_id := String(data.get("map_id", ""))
    if not StableId.is_valid(String(data.get("snapshot_id", ""))):
        errors.append("snapshot_id must be a stable ID")
    if not StableId.is_valid(map_id):
        errors.append("map_id must be a stable ID")
    if not _is_integral(data.get("floor_id", null)):
        errors.append("floor_id must be an integer")
    else:
        var floor_id: int = int(data["floor_id"])
        if floor_id < 0 or floor_id > 10:
            errors.append("floor_id must be 0 for region or 1 through 10 for tower")
        elif floor_id > 0 and map_id != "tower:floor_%d" % floor_id:
            errors.append("tower safe-state map_id must match floor_id")
    if not StableId.is_valid(String(data.get("checkpoint_anchor_id", ""))):
        errors.append("checkpoint_anchor_id must be a stable ID")
    if not data.get("player_state", null) is Dictionary:
        errors.append("player_state must be a dictionary")
    if not data.get("quest_attempt_state", null) is Dictionary:
        errors.append("quest_attempt_state must be a dictionary")
    if not _is_integral(data.get("snapshot_sequence", null)) or int(data.get("snapshot_sequence", -1)) < 0:
        errors.append("snapshot_sequence must be a nonnegative integer")
    return errors


static func _is_integral(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return true
    if typeof(value) != TYPE_FLOAT:
        return false
    var number: float = float(value)
    return is_finite(number) and is_equal_approx(number, round(number))
