class_name PrimaryFloorTurnInService
extends RefCounted

const FIRST_GENERIC_FLOOR: int = 2
const LAST_GENERIC_FLOOR: int = 9


static func commit_turn_in(
    save_service: SaveService,
    slot_index: int,
    profile: ProfileSnapshot,
    floor_id: int,
    safe_state: Dictionary
) -> Dictionary:
    if save_service == null or profile == null or floor_id < FIRST_GENERIC_FLOOR or floor_id > LAST_GENERIC_FLOOR:
        return _result(false, &"invalid_context", OK, floor_id)
    if not SafeCheckpointState.validate_dictionary(safe_state).is_empty():
        return _result(false, &"invalid_safe_snapshot", OK, floor_id)
    var quest_id: StringName = QuestCatalog.FLOOR_PRIMARY_IDS[floor_id - 1]
    var raw_entry: Variant = profile.quest_progress.get(String(quest_id), null)
    if not raw_entry is Dictionary:
        return _result(false, &"quest_progress_missing", OK, floor_id)
    var entry: Dictionary = raw_entry as Dictionary
    if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_OBJECTIVES_COMPLETE:
        return _result(false, &"objectives_not_complete", OK, floor_id)
    if StringName(String(entry.get("stage_id", &""))) != &"floor_objective":
        return _result(false, &"wrong_stage", OK, floor_id)

    var floor_key := str(floor_id)
    var raw_floor: Variant = profile.tower_floor_states.get(floor_key, null)
    if not raw_floor is Dictionary:
        return _result(false, &"floor_instance_missing", OK, floor_id)
    var floor_data: Dictionary = (raw_floor as Dictionary).duplicate(true)
    if not FloorInstanceState.validate_dictionary(floor_data).is_empty() or int(floor_data.get("floor_id", 0)) != floor_id:
        return _result(false, &"floor_instance_invalid", OK, floor_id)
    if not PrimaryFloorExitCommitProof.is_turn_in_safe_context(floor_data, floor_id, quest_id, safe_state):
        return _result(false, &"matching_floor_safe_snapshot_required", OK, floor_id)
    if bool(floor_data.get("primary_cleared", false)):
        return _result(false, &"already_completed", OK, floor_id)

    var completion_claim_id := StringName("quest_commit:primary_floor_%d:completed" % floor_id)
    var completion_source_id := StringName("quest:primary_floor_%d" % floor_id)
    var ledger := ClaimLedger.new()
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return _result(false, &"invalid_claim_ledger", OK, floor_id)
    if ledger.is_claimed(completion_claim_id):
        return _result(false, &"already_completed", OK, floor_id)

    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    var staged_ledger := ClaimLedger.new()
    if not staged_ledger.load_dictionary(staged.claimed_transactions).is_empty():
        return _result(false, &"invalid_claim_ledger", OK, floor_id)
    if not staged_ledger.try_claim(completion_claim_id, completion_source_id):
        return _result(false, &"claim_rejected", OK, floor_id)

    var staged_entry: Dictionary = (staged.quest_progress[String(quest_id)] as Dictionary).duplicate(true)
    staged_entry["state"] = QuestProgressState.STATE_COMPLETED
    staged.quest_progress[String(quest_id)] = staged_entry

    var staged_floor: Dictionary = (staged.tower_floor_states[floor_key] as Dictionary).duplicate(true)
    staged_floor["primary_cleared"] = true
    staged.tower_floor_states[floor_key] = staged_floor

    var next_floor_id := floor_id + 1
    staged.permanent_flags["tower_floor_%d_cleared" % floor_id] = true
    staged.permanent_flags["tower_floor_%d_unlocked" % next_floor_id] = true
    staged.claimed_transactions = staged_ledger.to_dictionary()
    staged.safe_state = safe_state.duplicate(true)

    if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _result(false, &"staged_profile_invalid", OK, floor_id)
    var save_error := save_service.save_profile(slot_index, staged)
    if save_error != OK:
        return _result(false, &"save_failed", save_error, floor_id)

    profile.quest_progress = staged.quest_progress.duplicate(true)
    profile.tower_floor_states = staged.tower_floor_states.duplicate(true)
    profile.permanent_flags = staged.permanent_flags.duplicate(true)
    profile.claimed_transactions = staged.claimed_transactions.duplicate(true)
    profile.safe_state = staged.safe_state.duplicate(true)
    return {
        "accepted": true,
        "reason_id": &"",
        "save_error": OK,
        "floor_id": floor_id,
        "floor_cleared": true,
        "next_floor_id": next_floor_id,
        "next_floor_unlocked": true,
        "quest_state": QuestProgressState.STATE_COMPLETED,
    }


static func _result(accepted: bool, reason_id: StringName, save_error: int, floor_id: int) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "save_error": save_error,
        "floor_id": floor_id,
        "floor_cleared": false,
        "next_floor_id": floor_id + 1 if floor_id >= FIRST_GENERIC_FLOOR and floor_id <= LAST_GENERIC_FLOOR else 0,
        "next_floor_unlocked": false,
        "quest_state": &"",
    }
