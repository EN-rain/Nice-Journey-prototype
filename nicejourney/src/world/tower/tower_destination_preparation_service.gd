class_name TowerDestinationPreparationService
extends RefCounted

const REASON_INVALID_GENERATION_INPUT: StringName = &"invalid_generation_input"
const REASON_GENERATION_FAILED: StringName = &"generation_failed"
const REASON_ARRIVAL_INVALID: StringName = &"arrival_invalid"

static func prepare(
    profile: ProfileSnapshot,
    operation_guard: GameplayOperationGuard,
    floor_id: int,
    generation_seed: int,
    generator_version: StringName,
    module_content_version: StringName,
    encounter_config_id: StringName,
    quest_world_flags_signature: StringName,
    instance_id: StringName,
    candidates: Array = []
) -> Dictionary:
    var eligibility := TowerAccessMenuService.validate_selection(profile, operation_guard, floor_id)
    if not bool(eligibility.get("accepted", false)):
        return _rejected(StringName(eligibility.get("reason_id", &"")), floor_id)

    var existing: Variant = profile.tower_floor_states.get(str(floor_id), null)
    if existing is Dictionary:
        var existing_result := TowerTravelPreparationService.prepare_existing_destination(profile, operation_guard, floor_id)
        if not bool(existing_result.get("accepted", false)):
            return existing_result
        existing_result["newly_generated"] = false
        existing_result["generation_result"] = {}
        return existing_result

    if generation_seed < 0 or not StableId.is_valid(String(instance_id)):
        return _rejected(REASON_INVALID_GENERATION_INPUT, floor_id)
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        generation_seed,
        generator_version,
        module_content_version,
        encounter_config_id,
        quest_world_flags_signature
    )
    if not TowerFloorGenerationCommitService.validate_request(request).is_empty():
        return _rejected(REASON_INVALID_GENERATION_INPUT, floor_id)

    var fallback := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if fallback.is_empty():
        return _rejected(REASON_GENERATION_FAILED, floor_id)
    var generation_result := TowerFloorGenerationCommitService.choose_valid_manifest(request, candidates, fallback)
    if not bool(generation_result.get("accepted", false)):
        var rejected := _rejected(REASON_GENERATION_FAILED, floor_id)
        rejected["generation_result"] = generation_result.duplicate(true)
        return rejected

    var state := TowerFloorGenerationCommitService.floor_state_from_manifest(instance_id, generation_result["manifest"])
    if state == null:
        return _rejected(REASON_GENERATION_FAILED, floor_id)
    var arrival := TowerArrivalResolver.resolve_entrance(state)
    if not bool(arrival.get("accepted", false)):
        var rejected := _rejected(REASON_ARRIVAL_INVALID, floor_id)
        rejected["arrival_reason_id"] = StringName(arrival.get("reason_id", &""))
        return rejected

    return {
        "accepted": true,
        "reason_id": &"",
        "floor_id": floor_id,
        "entry": (eligibility.get("entry", {}) as Dictionary).duplicate(true),
        "floor_instance": state.to_dictionary(),
        "arrival": arrival.duplicate(true),
        "newly_generated": true,
        "generation_result": generation_result.duplicate(true),
        "source_state_mutated": false,
    }

static func _rejected(reason_id: StringName, floor_id: int) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "floor_id": floor_id,
        "entry": {},
        "floor_instance": {},
        "arrival": {},
        "newly_generated": false,
        "generation_result": {},
        "source_state_mutated": false,
    }
