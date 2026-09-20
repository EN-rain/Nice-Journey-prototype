class_name Region3PreparationCommitService
extends RefCounted

const QUEST_ID: StringName = &"primary_floor_1"
const CLAIM_ID: StringName = &"quest_commit:primary_floor_1:region3_preparation"
const CLAIM_SOURCE_ID: StringName = &"quest:primary_floor_1"
const FLAG_REGION3_PREPARATION_COMMITTED: String = "quest:primary_floor_1:region3_preparation_committed"
const FLAG_TOWER_SIGIL_OWNED: String = "tower_sigil_owned"
const FLAG_TOWER_FLOOR_1_UNLOCKED: String = "tower_floor_1_unlocked"


static func commit(
    save_service: SaveService,
    slot_index: int,
    profile: ProfileSnapshot,
    safe_state: Dictionary,
    active_combat: bool,
    attempt_id: StringName
) -> Dictionary:
    if save_service == null or profile == null:
        return _rejected(&"invalid_context")
    if active_combat:
        return _rejected(&"active_combat")
    if not StableId.is_valid(String(attempt_id)):
        return _rejected(&"invalid_attempt_id")
    if not SafeCheckpointState.validate_dictionary(safe_state).is_empty():
        return _rejected(&"invalid_safe_snapshot")
    if int(safe_state.get("floor_id", -1)) != 0:
        return _rejected(&"region3_safe_snapshot_required")
    if not QuestCatalog.validate_catalog().is_empty():
        return _rejected(&"invalid_quest_catalog")

    var ledger: ClaimLedger = ClaimLedger.new()
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return _rejected(&"invalid_claim_ledger")
    if ledger.is_claimed(CLAIM_ID):
        return _rejected(&"already_committed")
    if _has_any_access_flag(profile) and not _has_complete_access_flags(profile):
        return _rejected(&"partial_access_state")
    if _has_complete_access_flags(profile):
        return _rejected(&"already_committed")

    var staged: ProfileSnapshot = ProfileSnapshot.from_dictionary(profile.to_dictionary())
    var staged_ledger: ClaimLedger = ClaimLedger.new()
    if not staged_ledger.load_dictionary(staged.claimed_transactions).is_empty():
        return _rejected(&"invalid_claim_ledger")
    if not staged_ledger.try_claim(CLAIM_ID, CLAIM_SOURCE_ID):
        return _rejected(&"claim_rejected")

    staged.claimed_transactions = staged_ledger.to_dictionary()
    staged.permanent_flags[FLAG_REGION3_PREPARATION_COMMITTED] = true
    staged.permanent_flags[FLAG_TOWER_SIGIL_OWNED] = true
    staged.permanent_flags[FLAG_TOWER_FLOOR_1_UNLOCKED] = true
    staged.quest_progress[String(QUEST_ID)] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": attempt_id,
    }
    staged.safe_state = safe_state.duplicate(true)

    if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _rejected(&"staged_profile_invalid")
    var save_error: int = save_service.save_profile(slot_index, staged)
    if save_error != OK:
        var failed: Dictionary = _rejected(&"save_failed")
        failed["save_error"] = save_error
        failed["pending_retry"] = true
        return failed

    profile.claimed_transactions = staged.claimed_transactions.duplicate(true)
    profile.permanent_flags = staged.permanent_flags.duplicate(true)
    profile.quest_progress = staged.quest_progress.duplicate(true)
    profile.safe_state = staged.safe_state.duplicate(true)
    return {
        "accepted": true,
        "reason_id": &"",
        "save_error": OK,
        "pending_retry": false,
        "tower_sigil_owned": true,
        "floor_1_unlocked": true,
        "next_stage_id": &"floor_objective",
    }


static func has_tower_sigil(profile: ProfileSnapshot) -> bool:
    return profile != null and bool(profile.permanent_flags.get(FLAG_TOWER_SIGIL_OWNED, false))


static func is_floor_1_unlocked(profile: ProfileSnapshot) -> bool:
    return profile != null and bool(profile.permanent_flags.get(FLAG_TOWER_FLOOR_1_UNLOCKED, false))


static func can_use_sigil(profile: ProfileSnapshot, active_combat: bool) -> bool:
    return has_tower_sigil(profile) and not active_combat


static func can_physically_enter_floor_1(profile: ProfileSnapshot) -> bool:
    return is_floor_1_unlocked(profile)


static func _has_any_access_flag(profile: ProfileSnapshot) -> bool:
    return (
        bool(profile.permanent_flags.get(FLAG_REGION3_PREPARATION_COMMITTED, false))
        or bool(profile.permanent_flags.get(FLAG_TOWER_SIGIL_OWNED, false))
        or bool(profile.permanent_flags.get(FLAG_TOWER_FLOOR_1_UNLOCKED, false))
    )


static func _has_complete_access_flags(profile: ProfileSnapshot) -> bool:
    return (
        bool(profile.permanent_flags.get(FLAG_REGION3_PREPARATION_COMMITTED, false))
        and bool(profile.permanent_flags.get(FLAG_TOWER_SIGIL_OWNED, false))
        and bool(profile.permanent_flags.get(FLAG_TOWER_FLOOR_1_UNLOCKED, false))
    )


static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "save_error": OK,
        "pending_retry": false,
        "tower_sigil_owned": false,
        "floor_1_unlocked": false,
        "next_stage_id": &"",
    }
