class_name Floor10PrimaryBossObjectiveService
extends RefCounted

const QUEST_ID: StringName = &"primary_floor_10"
const BOSS_ACTOR_ID: StringName = &"enemy:tenth_warden"
const COMPLETION_CLAIM_ID: StringName = &"quest_commit:primary_floor_10:completed"
const COMPLETION_SOURCE_ID: StringName = &"quest:primary_floor_10"
const FLAG_FLOOR_10_CLEARED: String = "tower_floor_10_cleared"


static func record_terminal_outcome(profile: ProfileSnapshot, outcome_id: StringName) -> Dictionary:
    if profile == null:
        return _progress_result(false, &"invalid_profile", false)
    var entry: Dictionary = _floor10_entry(profile)
    if entry.is_empty():
        return _progress_result(false, &"quest_not_active", false)
    var state_id := StringName(String(entry.get("state", &"")))
    if state_id != QuestProgressState.STATE_ACTIVE and state_id != QuestProgressState.STATE_OBJECTIVES_COMPLETE:
        return _progress_result(false, &"quest_not_active", false)
    if StringName(String(entry.get("stage_id", &""))) != &"floor_objective":
        return _progress_result(false, &"wrong_stage", false)

    if outcome_id == TenthWardenEncounterState.OUTCOME_FAILED_ATTEMPT:
        return _progress_result(true, &"failed_attempt_no_progress", false)
    if outcome_id != TenthWardenEncounterState.OUTCOME_VICTORY:
        return _progress_result(false, &"invalid_terminal_outcome", false)

    var floor_variant: Variant = profile.tower_floor_states.get("10", null)
    if not floor_variant is Dictionary:
        return _progress_result(false, &"floor10_instance_missing", false)
    var floor_data: Dictionary = (floor_variant as Dictionary).duplicate(true)
    if not FloorInstanceState.validate_dictionary(floor_data).is_empty():
        return _progress_result(false, &"floor10_instance_invalid", false)
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(floor_data).is_empty() or floor_state.floor_id != 10:
        return _progress_result(false, &"floor10_instance_invalid", false)

    if state_id == QuestProgressState.STATE_OBJECTIVES_COMPLETE:
        var objective_variant: Variant = entry.get("objective_state", {})
        if objective_variant is Dictionary \
            and bool((objective_variant as Dictionary).get("boss_defeated", false)) \
            and floor_state.boss_defeated:
            return _progress_result(true, &"duplicate_ignored", true)
        return _progress_result(false, &"inconsistent_completion_state", false)

    if not floor_state.mark_actor_defeated(BOSS_ACTOR_ID, true):
        return _progress_result(false, &"boss_defeat_state_rejected", false)
    entry["state"] = QuestProgressState.STATE_OBJECTIVES_COMPLETE
    entry["objective_state"] = {
        "boss_actor_id": String(BOSS_ACTOR_ID),
        "boss_defeated": true,
    }
    profile.quest_progress[String(QUEST_ID)] = entry
    profile.tower_floor_states["10"] = floor_state.to_dictionary()
    return _progress_result(true, &"", true)


static func commit_turn_in(save_service: SaveService, slot_index: int, profile: ProfileSnapshot, safe_state: Dictionary) -> Dictionary:
    if save_service == null or profile == null:
        return _commit_result(false, &"invalid_context", OK)
    if not SafeCheckpointState.validate_dictionary(safe_state).is_empty():
        return _commit_result(false, &"invalid_safe_snapshot", OK)
    var entry: Dictionary = _floor10_entry(profile)
    if entry.is_empty() or StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_OBJECTIVES_COMPLETE:
        return _commit_result(false, &"objectives_not_complete", OK)
    if StringName(String(entry.get("stage_id", &""))) != &"floor_objective":
        return _commit_result(false, &"wrong_stage", OK)

    var floor_variant: Variant = profile.tower_floor_states.get("10", null)
    if not floor_variant is Dictionary:
        return _commit_result(false, &"floor10_instance_missing", OK)
    var floor_data: Dictionary = (floor_variant as Dictionary).duplicate(true)
    if not FloorInstanceState.validate_dictionary(floor_data).is_empty() or not bool(floor_data.get("boss_defeated", false)):
        return _commit_result(false, &"boss_victory_not_recorded", OK)
    if not PrimaryFloorExitCommitProof.is_turn_in_safe_context(floor_data, 10, QUEST_ID, safe_state):
        return _commit_result(false, &"floor10_safe_snapshot_required", OK)

    var ledger := ClaimLedger.new()
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return _commit_result(false, &"invalid_claim_ledger", OK)
    if ledger.is_claimed(COMPLETION_CLAIM_ID):
        return _commit_result(false, &"already_completed", OK)

    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    var staged_ledger := ClaimLedger.new()
    if not staged_ledger.load_dictionary(staged.claimed_transactions).is_empty():
        return _commit_result(false, &"invalid_claim_ledger", OK)
    if not staged_ledger.try_claim(COMPLETION_CLAIM_ID, COMPLETION_SOURCE_ID):
        return _commit_result(false, &"claim_rejected", OK)

    var staged_entry: Dictionary = (staged.quest_progress[String(QUEST_ID)] as Dictionary).duplicate(true)
    staged_entry["state"] = QuestProgressState.STATE_COMPLETED
    staged.quest_progress[String(QUEST_ID)] = staged_entry

    var staged_floor: Dictionary = (staged.tower_floor_states["10"] as Dictionary).duplicate(true)
    staged_floor["primary_cleared"] = true
    staged.tower_floor_states["10"] = staged_floor
    staged.permanent_flags[FLAG_FLOOR_10_CLEARED] = true
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
        "floor_10_cleared": true,
        "floor_11_unlocked": false,
        "quest_state": QuestProgressState.STATE_COMPLETED,
    }


static func _floor10_entry(profile: ProfileSnapshot) -> Dictionary:
    if profile == null:
        return {}
    var raw: Variant = profile.quest_progress.get(String(QUEST_ID), null)
    if not raw is Dictionary:
        return {}
    return (raw as Dictionary).duplicate(true)


static func _progress_result(accepted: bool, reason_id: StringName, objectives_complete: bool) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "objectives_complete": objectives_complete,
        "floor_10_cleared": false,
    }


static func _commit_result(accepted: bool, reason_id: StringName, save_error: int) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "save_error": save_error,
        "floor_10_cleared": false,
        "floor_11_unlocked": false,
        "quest_state": &"",
    }
