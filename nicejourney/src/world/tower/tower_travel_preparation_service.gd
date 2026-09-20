class_name TowerTravelPreparationService
extends RefCounted

const REASON_DESTINATION_INSTANCE_MISSING: StringName = &"destination_instance_missing"
const REASON_DESTINATION_INSTANCE_INVALID: StringName = &"destination_instance_invalid"
const REASON_DESTINATION_ARRIVAL_INVALID: StringName = &"destination_arrival_invalid"

static func prepare_existing_destination(
    profile: ProfileSnapshot,
    operation_guard: GameplayOperationGuard,
    floor_id: int
) -> Dictionary:
    var eligibility := TowerAccessMenuService.validate_selection(profile, operation_guard, floor_id)
    if not bool(eligibility.get("accepted", false)):
        return {
            "accepted": false,
            "reason_id": StringName(eligibility.get("reason_id", &"")),
            "floor_id": floor_id,
            "entry": {},
            "arrival": {},
        }

    var raw_floor: Variant = profile.tower_floor_states.get(str(floor_id), null)
    if not raw_floor is Dictionary:
        return _rejected(REASON_DESTINATION_INSTANCE_MISSING, floor_id, eligibility.get("entry", {}) as Dictionary)
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(raw_floor as Dictionary).is_empty() or floor_state.floor_id != floor_id:
        return _rejected(REASON_DESTINATION_INSTANCE_INVALID, floor_id, eligibility.get("entry", {}) as Dictionary)

    var arrival := TowerArrivalResolver.resolve_entrance(floor_state)
    if not bool(arrival.get("accepted", false)):
        var result := _rejected(REASON_DESTINATION_ARRIVAL_INVALID, floor_id, eligibility.get("entry", {}) as Dictionary)
        result["arrival_reason_id"] = StringName(arrival.get("reason_id", &""))
        return result

    return {
        "accepted": true,
        "reason_id": &"",
        "floor_id": floor_id,
        "entry": (eligibility.get("entry", {}) as Dictionary).duplicate(true),
        "floor_instance": floor_state.to_dictionary(),
        "arrival": arrival.duplicate(true),
        "source_state_mutated": false,
    }

static func _rejected(reason_id: StringName, floor_id: int, entry: Dictionary) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "floor_id": floor_id,
        "entry": entry.duplicate(true),
        "arrival": {},
        "source_state_mutated": false,
    }
