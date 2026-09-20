class_name TowerTravelPlanService
extends RefCounted

const REASON_INVALID_LEAVE_PLAN: StringName = &"invalid_leave_plan"
const REASON_LEAVE_REJECTED: StringName = &"quest_leave_rejected"
const REASON_STAGED_PROFILE_INVALID: StringName = &"staged_profile_invalid"
const REASON_LEAVE_PLAN_MISSING: StringName = &"leave_plan_missing"

static func stage(
    profile: ProfileSnapshot,
    operation_guard: GameplayOperationGuard,
    floor_id: int,
    generation_seed: int,
    generator_version: StringName,
    module_content_version: StringName,
    encounter_config_id: StringName,
    quest_world_flags_signature: StringName,
    instance_id: StringName,
    leave_plans: Array = [],
    candidates: Array = []
) -> Dictionary:
    if profile == null:
        return _rejected(TowerAccessMenuService.REASON_INVALID_CONTEXT, floor_id)

    # Destination is prepared first against the unchanged source profile. A failed
    # target never consumes quest-leave state or creates a persistent floor.
    var destination := TowerDestinationPreparationService.prepare(
        profile,
        operation_guard,
        floor_id,
        generation_seed,
        generator_version,
        module_content_version,
        encounter_config_id,
        quest_world_flags_signature,
        instance_id,
        candidates
    )
    if not bool(destination.get("accepted", false)):
        var rejected := _rejected(StringName(destination.get("reason_id", &"")), floor_id)
        rejected["destination"] = destination.duplicate(true)
        return rejected

    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null:
        return _rejected(REASON_STAGED_PROFILE_INVALID, floor_id)
    var leave_results: Array[Dictionary] = []
    var seen_quests: Dictionary = {}
    for raw_plan: Variant in leave_plans:
        if not raw_plan is Dictionary:
            return _leave_plan_rejected(REASON_INVALID_LEAVE_PLAN, floor_id, destination, leave_results)
        var plan := raw_plan as Dictionary
        var quest_id := StringName(String(plan.get("quest_id", &"")))
        var rule_variant: Variant = plan.get("rule", null)
        if not StableId.is_valid(String(quest_id)) or seen_quests.has(quest_id) or not rule_variant is QuestLeaveRuleDefinition:
            return _leave_plan_rejected(REASON_INVALID_LEAVE_PLAN, floor_id, destination, leave_results)
        seen_quests[quest_id] = true
        var confirmed_variant: Variant = plan.get("confirmed", false)
        if typeof(confirmed_variant) != TYPE_BOOL:
            return _leave_plan_rejected(REASON_INVALID_LEAVE_PLAN, floor_id, destination, leave_results)
        var leave_result := QuestLeaveTransactionService.apply(
            staged,
            quest_id,
            rule_variant as QuestLeaveRuleDefinition,
            bool(confirmed_variant)
        )
        leave_results.append(leave_result.duplicate(true))
        if not bool(leave_result.get("accepted", false)):
            var rejected := _leave_plan_rejected(REASON_LEAVE_REJECTED, floor_id, destination, leave_results)
            rejected["leave_reason_id"] = StringName(leave_result.get("reason_id", &""))
            rejected["leave_quest_id"] = quest_id
            return rejected

    for required_quest_id: StringName in _required_leave_quest_ids(profile, floor_id):
        if seen_quests.has(required_quest_id):
            continue
        var rejected := _leave_plan_rejected(REASON_LEAVE_PLAN_MISSING, floor_id, destination, leave_results)
        rejected["leave_quest_id"] = required_quest_id
        return rejected

    if bool(destination.get("newly_generated", false)):
        var floor_state := FloorInstanceState.new()
        if not floor_state.load_dictionary(destination["floor_instance"] as Dictionary).is_empty():
            return _leave_plan_rejected(REASON_STAGED_PROFILE_INVALID, floor_id, destination, leave_results)
        if not TowerFloorStateService.commit_floor_state(staged, floor_state):
            return _leave_plan_rejected(REASON_STAGED_PROFILE_INVALID, floor_id, destination, leave_results)

    if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _leave_plan_rejected(REASON_STAGED_PROFILE_INVALID, floor_id, destination, leave_results)
    return {
        "accepted": true,
        "reason_id": &"",
        "floor_id": floor_id,
        "destination": destination.duplicate(true),
        "leave_results": leave_results.duplicate(true),
        "source_profile": profile.to_dictionary(),
        "staged_profile": staged.to_dictionary(),
        "source_state_mutated": false,
        "ready_for_transfer_commit": true,
    }

static func _required_leave_quest_ids(profile: ProfileSnapshot, destination_floor_id: int) -> Array[StringName]:
    var result: Array[StringName] = []
    if profile == null:
        return result
    for raw_quest_id: Variant in profile.quest_progress.keys():
        var raw_entry: Variant = profile.quest_progress[raw_quest_id]
        if not raw_entry is Dictionary:
            continue
        var state_id := StringName(String((raw_entry as Dictionary).get("state", &"")))
        if state_id not in [QuestProgressState.STATE_ACTIVE, QuestProgressState.STATE_OBJECTIVES_COMPLETE]:
            continue
        var quest_id := StringName(String(raw_quest_id))
        var definition := QuestCatalog.get_definition(quest_id)
        if definition == null:
            continue
        # Travelling to the same floor as a tower-bound quest does not leave that
        # quest's authored scope. Region quests (floor 0) and other-floor quests do.
        if definition.floor_id == destination_floor_id and destination_floor_id > 0:
            continue
        result.append(quest_id)
    result.sort()
    return result

static func _leave_plan_rejected(reason_id: StringName, floor_id: int, destination: Dictionary, leave_results: Array[Dictionary]) -> Dictionary:
    var result := _rejected(reason_id, floor_id)
    result["destination"] = destination.duplicate(true)
    result["leave_results"] = leave_results.duplicate(true)
    return result

static func _rejected(reason_id: StringName, floor_id: int) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "floor_id": floor_id,
        "destination": {},
        "leave_results": [],
        "source_profile": {},
        "staged_profile": {},
        "source_state_mutated": false,
        "ready_for_transfer_commit": false,
    }
