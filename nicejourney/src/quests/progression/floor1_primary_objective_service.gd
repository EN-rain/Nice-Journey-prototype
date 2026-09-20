class_name Floor1PrimaryObjectiveService
extends RefCounted

const QUEST_ID: StringName = &"primary_floor_1"
const COMPLETION_CLAIM_ID: StringName = &"quest_commit:primary_floor_1:completed"
const COMPLETION_SOURCE_ID: StringName = &"quest:primary_floor_1"
const FLAG_FLOOR_1_CLEARED: String = "tower_floor_1_cleared"
const FLAG_FLOOR_2_UNLOCKED: String = "tower_floor_2_unlocked"


static func bind_designated_group(profile: ProfileSnapshot, required_actor_ids: Array[StringName]) -> bool:
    if profile == null or required_actor_ids.is_empty():
        return false
    var entry: Dictionary = _floor1_entry(profile)
    if entry.is_empty():
        return false
    if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_ACTIVE:
        return false
    if StringName(String(entry.get("stage_id", &""))) != &"floor_objective":
        return false
    var seen: Dictionary = {}
    var serialized_required: Array[String] = []
    for actor_id: StringName in required_actor_ids:
        if not StableId.is_valid(String(actor_id)) or seen.has(actor_id):
            return false
        seen[actor_id] = true
        serialized_required.append(String(actor_id))
    serialized_required.sort()
    entry["objective_state"] = {
        "required_actor_ids": serialized_required,
        "defeated_actor_ids": [],
    }
    profile.quest_progress[String(QUEST_ID)] = entry
    return true


static func record_designated_actor_defeat(profile: ProfileSnapshot, actor_id: StringName) -> Dictionary:
    if profile == null or not StableId.is_valid(String(actor_id)):
        return _progress_result(false, &"invalid_actor_id", 0, 0, false)
    var entry: Dictionary = _floor1_entry(profile)
    if entry.is_empty():
        return _progress_result(false, &"quest_not_active", 0, 0, false)
    if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_ACTIVE:
        return _progress_result(false, &"quest_not_active", 0, 0, false)
    if StringName(String(entry.get("stage_id", &""))) != &"floor_objective":
        return _progress_result(false, &"wrong_stage", 0, 0, false)
    var objective_variant: Variant = entry.get("objective_state", {})
    if not objective_variant is Dictionary:
        return _progress_result(false, &"objective_unbound", 0, 0, false)
    var objective: Dictionary = (objective_variant as Dictionary).duplicate(true)
    var required_variant: Variant = objective.get("required_actor_ids", [])
    var defeated_variant: Variant = objective.get("defeated_actor_ids", [])
    if not required_variant is Array or not defeated_variant is Array:
        return _progress_result(false, &"objective_invalid", 0, 0, false)
    var required: Array = required_variant as Array
    var defeated: Array = defeated_variant as Array
    if not required.has(String(actor_id)):
        return _progress_result(false, &"actor_not_required", defeated.size(), required.size(), false)
    if defeated.has(String(actor_id)):
        return _progress_result(true, &"duplicate_ignored", defeated.size(), required.size(), defeated.size() == required.size())
    defeated.append(String(actor_id))
    defeated.sort()
    objective["defeated_actor_ids"] = defeated
    entry["objective_state"] = objective
    var complete: bool = defeated.size() == required.size()
    if complete:
        entry["state"] = QuestProgressState.STATE_OBJECTIVES_COMPLETE
    profile.quest_progress[String(QUEST_ID)] = entry
    return _progress_result(true, &"", defeated.size(), required.size(), complete)


static func commit_turn_in(save_service: SaveService, slot_index: int, profile: ProfileSnapshot, safe_state: Dictionary) -> Dictionary:
    if save_service == null or profile == null:
        return _commit_result(false, &"invalid_context", OK)
    if not SafeCheckpointState.validate_dictionary(safe_state).is_empty():
        return _commit_result(false, &"invalid_safe_snapshot", OK)
    var entry: Dictionary = _floor1_entry(profile)
    if entry.is_empty() or StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_OBJECTIVES_COMPLETE:
        return _commit_result(false, &"objectives_not_complete", OK)
    if StringName(String(entry.get("stage_id", &""))) != &"floor_objective":
        return _commit_result(false, &"wrong_stage", OK)

    var floor_variant: Variant = profile.tower_floor_states.get("1", null)
    if not floor_variant is Dictionary:
        return _commit_result(false, &"floor1_instance_missing", OK)
    var floor_data: Dictionary = (floor_variant as Dictionary).duplicate(true)
    if not FloorInstanceState.validate_dictionary(floor_data).is_empty():
        return _commit_result(false, &"floor1_instance_invalid", OK)
    if not PrimaryFloorExitCommitProof.is_turn_in_safe_context(floor_data, 1, QUEST_ID, safe_state):
        return _commit_result(false, &"floor1_safe_snapshot_required", OK)

    var ledger: ClaimLedger = ClaimLedger.new()
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return _commit_result(false, &"invalid_claim_ledger", OK)
    if ledger.is_claimed(COMPLETION_CLAIM_ID):
        return _commit_result(false, &"already_completed", OK)

    var staged: ProfileSnapshot = ProfileSnapshot.from_dictionary(profile.to_dictionary())
    var staged_ledger: ClaimLedger = ClaimLedger.new()
    if not staged_ledger.load_dictionary(staged.claimed_transactions).is_empty():
        return _commit_result(false, &"invalid_claim_ledger", OK)
    if not staged_ledger.try_claim(COMPLETION_CLAIM_ID, COMPLETION_SOURCE_ID):
        return _commit_result(false, &"claim_rejected", OK)

    var staged_entry: Dictionary = (staged.quest_progress[String(QUEST_ID)] as Dictionary).duplicate(true)
    staged_entry["state"] = QuestProgressState.STATE_COMPLETED
    staged.quest_progress[String(QUEST_ID)] = staged_entry

    var staged_floor: Dictionary = (staged.tower_floor_states["1"] as Dictionary).duplicate(true)
    staged_floor["primary_cleared"] = true
    staged.tower_floor_states["1"] = staged_floor
    staged.permanent_flags[FLAG_FLOOR_1_CLEARED] = true
    staged.permanent_flags[FLAG_FLOOR_2_UNLOCKED] = true
    staged.claimed_transactions = staged_ledger.to_dictionary()
    staged.safe_state = safe_state.duplicate(true)

    if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _commit_result(false, &"staged_profile_invalid", OK)
    var save_error: int = save_service.save_profile(slot_index, staged)
    if save_error != OK:
        return _commit_result(false, &"save_failed", save_error)

    profile.quest_progress = staged.quest_progress.duplicate(true)
    profile.tower_floor_states = staged.tower_floor_states.duplicate(true)
    profile.permanent_flags = staged.permanent_flags.duplicate(true)
    profile.claimed_transactions = staged.claimed_transactions.duplicate(true)
    profile.safe_state = staged.safe_state.duplicate(true)
    return {
        "accepted": true,
        "reason_id": &"",
        "save_error": OK,
        "floor_1_cleared": true,
        "floor_2_unlocked": true,
        "quest_state": QuestProgressState.STATE_COMPLETED,
    }


static func _floor1_entry(profile: ProfileSnapshot) -> Dictionary:
    if profile == null:
        return {}
    var raw: Variant = profile.quest_progress.get(String(QUEST_ID), null)
    if not raw is Dictionary:
        return {}
    return (raw as Dictionary).duplicate(true)


static func _progress_result(accepted: bool, reason_id: StringName, defeated: int, required: int, complete: bool) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "defeated_count": defeated,
        "required_count": required,
        "objectives_complete": complete,
    }


static func _commit_result(accepted: bool, reason_id: StringName, save_error: int) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "save_error": save_error,
        "floor_1_cleared": false,
        "floor_2_unlocked": false,
        "quest_state": &"",
    }
