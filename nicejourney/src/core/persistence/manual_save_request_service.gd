class_name ManualSaveRequestService
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"


static func request(
    coordinator: SaveRequestCoordinator,
    slot_index: int,
    live_profile: ProfileSnapshot,
    safe_state_provider: Callable
) -> Dictionary:
    if coordinator == null or live_profile == null:
        return _rejected(slot_index, REASON_INVALID_CONTEXT, "Manual save context is unavailable.", ERR_INVALID_PARAMETER)

    var capture_context: Dictionary = {}
    var snapshot_provider := func() -> Variant:
        if not safe_state_provider.is_valid():
            return null
        var safe_variant: Variant = safe_state_provider.call()
        if not safe_variant is Dictionary:
            return null
        var safe_state := (safe_variant as Dictionary).duplicate(true)
        if not SafeCheckpointState.validate_dictionary(safe_state).is_empty():
            return null

        var floor_id := int(safe_state.get("floor_id", -1))
        if floor_id > 0:
            var floor_variant: Variant = live_profile.tower_floor_states.get(str(floor_id), null)
            if not floor_variant is Dictionary:
                return null
            if not FloorInstanceState.validate_dictionary(floor_variant as Dictionary).is_empty():
                return null

        var staged := ProfileSnapshot.from_dictionary(live_profile.to_dictionary())
        if staged == null:
            return null
        staged.safe_state = safe_state
        if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
            return null
        capture_context["safe_state"] = safe_state.duplicate(true)
        return staged

    var status := coordinator.request_save(
        slot_index,
        SaveRequestCoordinator.REQUEST_MANUAL,
        snapshot_provider
    )
    if (
        StringName(status.get("state", &"")) == SaveRequestCoordinator.STATE_SUCCEEDED
        and capture_context.has("safe_state")
    ):
        live_profile.safe_state = (capture_context["safe_state"] as Dictionary).duplicate(true)
    return status


static func _rejected(slot_index: int, reason_id: StringName, reason_text: String, error_code: int) -> Dictionary:
    return {
        "slot_index": slot_index,
        "request_id": 0,
        "request_kind": SaveRequestCoordinator.REQUEST_MANUAL,
        "state": SaveRequestCoordinator.STATE_FAILED,
        "reason_id": reason_id,
        "reason_text": reason_text,
        "error_code": error_code,
    }
