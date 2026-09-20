class_name TowerFloorStateService
extends RefCounted


static func commit_floor_state(profile: ProfileSnapshot, floor_state: FloorInstanceState) -> bool:
    if profile == null or floor_state == null:
        return false
    var candidate: Dictionary = floor_state.to_dictionary()
    if not FloorInstanceState.validate_dictionary(candidate).is_empty():
        return false
    var key: String = str(floor_state.floor_id)
    if profile.tower_floor_states.has(key):
        var existing_variant: Variant = profile.tower_floor_states[key]
        if not existing_variant is Dictionary:
            return false
        var existing: Dictionary = existing_variant as Dictionary
        if String(existing.get("instance_id", "")) != String(floor_state.instance_id):
            return false
        if int(existing.get("seed", -1)) != floor_state.seed:
            return false
        if String(existing.get("layout_revision_id", "")) != String(floor_state.layout_revision_id):
            return false
    profile.tower_floor_states[key] = candidate.duplicate(true)
    return true


static func ordinary_revisit(profile: ProfileSnapshot, floor_id: int) -> Dictionary:
    if profile == null or floor_id < 1 or floor_id > 10:
        return {}
    var key: String = str(floor_id)
    var raw: Variant = profile.tower_floor_states.get(key, null)
    if not raw is Dictionary:
        return {}
    var data: Dictionary = raw as Dictionary
    if not FloorInstanceState.validate_dictionary(data).is_empty():
        return {}
    return data.duplicate(true)


static func supports_player_fresh_reset() -> bool:
    return false
