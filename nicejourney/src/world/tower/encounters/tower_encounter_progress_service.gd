class_name TowerEncounterProgressService
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_ALREADY_DEFEATED: StringName = &"duplicate_ignored"
const REASON_INVALID_BINDING: StringName = &"invalid_quest_binding"
const REASON_QUEST_EVENT_REJECTED: StringName = &"quest_event_rejected"
const REASON_FLOOR_COMMIT_REJECTED: StringName = &"floor_commit_rejected"
const REASON_STAGED_PROFILE_INVALID: StringName = &"staged_profile_invalid"

static func record_enemy_defeat(
    profile: ProfileSnapshot,
    floor_state: FloorInstanceState,
    actor_id: StringName,
    quest_bindings: Array = []
) -> Dictionary:
    if profile == null or floor_state == null or not StableId.is_valid(String(actor_id)):
        return _rejected(REASON_INVALID_CONTEXT, actor_id)
    if not FloorInstanceState.validate_dictionary(floor_state.to_dictionary()).is_empty():
        return _rejected(REASON_INVALID_CONTEXT, actor_id)
    if floor_state.defeated_actor_ids.has(actor_id):
        return {
            "accepted": true,
            "reason_id": REASON_ALREADY_DEFEATED,
            "actor_id": actor_id,
            "quest_results": [],
            "floor_defeat_recorded": true,
        }

    var staged_profile := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    var staged_floor := FloorInstanceState.new()
    if staged_profile == null or not staged_floor.load_dictionary(floor_state.to_dictionary()).is_empty():
        return _rejected(REASON_STAGED_PROFILE_INVALID, actor_id)
    if not staged_floor.mark_actor_defeated(actor_id):
        return _rejected(REASON_FLOOR_COMMIT_REJECTED, actor_id)

    var quest_results: Array[Dictionary] = []
    var seen_quests: Dictionary = {}
    for raw_binding: Variant in quest_bindings:
        if not raw_binding is Dictionary:
            return _rejected_with_results(REASON_INVALID_BINDING, actor_id, quest_results)
        var binding := raw_binding as Dictionary
        var quest_id := StringName(String(binding.get("quest_id", &"")))
        if not StableId.is_valid(String(quest_id)) or seen_quests.has(quest_id):
            return _rejected_with_results(REASON_INVALID_BINDING, actor_id, quest_results)
        seen_quests[quest_id] = true
        var definition := QuestCatalog.get_definition(quest_id)
        if definition == null or definition.family == QuestDefinition.FAMILY_ESCORT:
            return _rejected_with_results(REASON_INVALID_BINDING, actor_id, quest_results)
        var payload := {"actor_id": actor_id}
        if definition.family == QuestDefinition.FAMILY_TOWER_DEFENSE:
            var wave_id := StringName(String(binding.get("wave_id", &"")))
            if not StableId.is_valid(String(wave_id)):
                return _rejected_with_results(REASON_INVALID_BINDING, actor_id, quest_results)
            payload["wave_id"] = wave_id
        var quest_result := QuestFamilyObjectiveService.apply_event(
            staged_profile,
            quest_id,
            QuestFamilyObjectiveService.EVENT_ACTOR_DEFEATED,
            payload
        )
        quest_results.append({
            "quest_id": quest_id,
            "result": quest_result.duplicate(true),
        })
        if not bool(quest_result.get("accepted", false)):
            return _rejected_with_results(REASON_QUEST_EVENT_REJECTED, actor_id, quest_results)

    if not TowerFloorStateService.commit_floor_state(staged_profile, staged_floor):
        return _rejected_with_results(REASON_FLOOR_COMMIT_REJECTED, actor_id, quest_results)
    if not ProfileSnapshot.validate_dictionary(staged_profile.to_dictionary()).is_empty():
        return _rejected_with_results(REASON_STAGED_PROFILE_INVALID, actor_id, quest_results)

    _apply_profile(profile, staged_profile)
    if not floor_state.load_dictionary(staged_floor.to_dictionary()).is_empty():
        return _rejected_with_results(REASON_STAGED_PROFILE_INVALID, actor_id, quest_results)
    return {
        "accepted": true,
        "reason_id": &"",
        "actor_id": actor_id,
        "quest_results": quest_results.duplicate(true),
        "floor_defeat_recorded": true,
    }

static func _apply_profile(target: ProfileSnapshot, source: ProfileSnapshot) -> void:
    target.profile_id = source.profile_id
    target.protagonist_name = source.protagonist_name
    target.class_id = source.class_id
    target.level = source.level
    target.xp = source.xp
    target.skill_points = source.skill_points
    target.skill_state = source.skill_state.duplicate(true)
    target.item_state = source.item_state.duplicate(true)
    target.storage_state = source.storage_state.duplicate(true)
    target.equipment_state = source.equipment_state.duplicate(true)
    target.economy_state = source.economy_state.duplicate(true)
    target.tower_floor_states = source.tower_floor_states.duplicate(true)
    target.safe_state = source.safe_state.duplicate(true)
    target.quest_progress = source.quest_progress.duplicate(true)
    target.permanent_flags = source.permanent_flags.duplicate(true)
    target.claimed_transactions = source.claimed_transactions.duplicate(true)

static func _rejected(reason_id: StringName, actor_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "actor_id": actor_id,
        "quest_results": [],
        "floor_defeat_recorded": false,
    }

static func _rejected_with_results(reason_id: StringName, actor_id: StringName, quest_results: Array[Dictionary]) -> Dictionary:
    var result := _rejected(reason_id, actor_id)
    result["quest_results"] = quest_results.duplicate(true)
    return result
