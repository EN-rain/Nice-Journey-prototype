class_name SafeCheckpointCommitService
extends RefCounted

static func commit_checkpoint(save_service: SaveService, slot_index: int, profile: ProfileSnapshot, safe_state: Dictionary) -> int:
    if save_service == null or profile == null:
        return ERR_INVALID_PARAMETER
    if not SafeCheckpointState.validate_dictionary(safe_state).is_empty():
        return ERR_INVALID_DATA

    var floor_id: int = int(safe_state.get("floor_id", 0))
    if floor_id > 0:
        var floor_key: String = str(floor_id)
        var floor_variant: Variant = profile.tower_floor_states.get(floor_key, null)
        if not floor_variant is Dictionary:
            return ERR_INVALID_DATA
        if not FloorInstanceState.validate_dictionary(floor_variant as Dictionary).is_empty():
            return ERR_INVALID_DATA

    var staged: ProfileSnapshot = ProfileSnapshot.from_dictionary(profile.to_dictionary())
    staged.safe_state = safe_state.duplicate(true)
    if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return ERR_INVALID_DATA

    var result: int = save_service.save_profile(slot_index, staged)
    if result != OK:
        return result
    profile.safe_state = safe_state.duplicate(true)
    return OK
