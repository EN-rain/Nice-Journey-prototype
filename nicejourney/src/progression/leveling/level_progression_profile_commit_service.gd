class_name LevelProgressionProfileCommitService
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_RUNTIME_STAT_OWNER_MISSING: StringName = &"runtime_stat_owner_missing"
const REASON_RUNTIME_STAT_CAPTURE_INVALID: StringName = &"runtime_stat_capture_invalid"
const REASON_RUNTIME_STAT_MISMATCH: StringName = &"runtime_stat_mismatch"
const REASON_RUNTIME_STAT_APPLY_REJECTED: StringName = &"runtime_stat_apply_rejected"
const REASON_RUNTIME_STAT_APPLY_MISMATCH: StringName = &"runtime_stat_apply_mismatch"
const REASON_RUNTIME_STAT_ROLLBACK_FAILED: StringName = &"runtime_stat_rollback_failed"
const REASON_STAGED_PROFILE_INVALID: StringName = &"staged_profile_invalid"
const REASON_SAVE_FAILED: StringName = &"save_failed"


static func commit_award(
    save_service: SaveService,
    slot_index: int,
    profile: ProfileSnapshot,
    xp_award: int,
    claim_id: StringName,
    source_id: StringName,
    policy: LevelProgressionPolicy,
    runtime_stat_capture: Callable,
    runtime_stat_apply: Callable
) -> Dictionary:
    if save_service == null or profile == null or slot_index < 1 or slot_index > SaveService.SLOT_COUNT:
        return _rejected(REASON_INVALID_CONTEXT, claim_id, source_id)
    if not runtime_stat_capture.is_valid() or not runtime_stat_apply.is_valid():
        return _rejected(REASON_RUNTIME_STAT_OWNER_MISSING, claim_id, source_id)

    var raw_runtime_before: Variant = runtime_stat_capture.call()
    if not raw_runtime_before is Dictionary:
        return _rejected(REASON_RUNTIME_STAT_CAPTURE_INVALID, claim_id, source_id)
    var runtime_before := AutomaticStatState.normalize_dictionary(raw_runtime_before)
    if not AutomaticStatState.validate_dictionary(raw_runtime_before).is_empty():
        return _rejected(REASON_RUNTIME_STAT_CAPTURE_INVALID, claim_id, source_id)
    if not AutomaticStatState.equivalent(runtime_before, profile.automatic_stats):
        return _rejected(REASON_RUNTIME_STAT_MISMATCH, claim_id, source_id)

    var prepared := LevelProgressionService.prepare_award(
        profile,
        runtime_before,
        xp_award,
        claim_id,
        source_id,
        policy
    )
    if not bool(prepared.get("accepted", false)):
        return prepared

    var staged_payload: Variant = prepared.get("staged_profile", null)
    if not staged_payload is Dictionary:
        return _rejected(REASON_STAGED_PROFILE_INVALID, claim_id, source_id)
    var staged := ProfileSnapshot.from_dictionary(staged_payload as Dictionary)
    if staged == null or not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _rejected(REASON_STAGED_PROFILE_INVALID, claim_id, source_id)
    var resulting_stats := prepared.get("resulting_stat_values", {}) as Dictionary
    if not AutomaticStatState.equivalent(staged.automatic_stats, resulting_stats):
        return _rejected(REASON_STAGED_PROFILE_INVALID, claim_id, source_id)

    var applied: Variant = runtime_stat_apply.call(staged.automatic_stats.duplicate(true))
    var apply_rejected := not applied is bool or not bool(applied)
    var apply_mismatched := false
    if not apply_rejected:
        apply_mismatched = not AutomaticStatState.equivalent(runtime_stat_capture.call(), staged.automatic_stats)
    if apply_rejected or apply_mismatched:
        var apply_rollback: Variant = runtime_stat_apply.call(runtime_before.duplicate(true))
        if not apply_rollback is bool or not bool(apply_rollback) or not AutomaticStatState.equivalent(runtime_stat_capture.call(), runtime_before):
            return _rejected(REASON_RUNTIME_STAT_ROLLBACK_FAILED, claim_id, source_id)
        var apply_failed := _rejected(REASON_RUNTIME_STAT_APPLY_REJECTED if apply_rejected else REASON_RUNTIME_STAT_APPLY_MISMATCH, claim_id, source_id)
        apply_failed["runtime_rolled_back"] = true
        return apply_failed

    var save_error := save_service.save_profile(slot_index, staged)
    if save_error != OK:
        var rollback_result: Variant = runtime_stat_apply.call(runtime_before.duplicate(true))
        if not rollback_result is bool or not bool(rollback_result) or not AutomaticStatState.equivalent(runtime_stat_capture.call(), runtime_before):
            var rollback_failed := _rejected(REASON_RUNTIME_STAT_ROLLBACK_FAILED, claim_id, source_id)
            rollback_failed["save_error"] = save_error
            return rollback_failed
        var save_failed := _rejected(REASON_SAVE_FAILED, claim_id, source_id)
        save_failed["save_error"] = save_error
        save_failed["runtime_rolled_back"] = true
        return save_failed

    _apply_progression_fields(profile, staged)
    var result := prepared.duplicate(true)
    result["accepted"] = true
    result["durable"] = true
    result["save_error"] = OK
    result["runtime_stats_applied"] = true
    result["runtime_rolled_back"] = false
    return result


static func restore_runtime_from_profile(
    profile: ProfileSnapshot,
    runtime_stat_apply: Callable
) -> Dictionary:
    if profile == null or not runtime_stat_apply.is_valid():
        return {
            "accepted": false,
            "reason_id": REASON_RUNTIME_STAT_OWNER_MISSING,
        }
    if not ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty():
        return {
            "accepted": false,
            "reason_id": REASON_INVALID_CONTEXT,
        }
    var result: Variant = runtime_stat_apply.call(profile.automatic_stats.duplicate(true))
    if not result is bool or not bool(result):
        return {
            "accepted": false,
            "reason_id": REASON_RUNTIME_STAT_APPLY_REJECTED,
        }
    return {
        "accepted": true,
        "reason_id": &"",
        "automatic_stats": profile.automatic_stats.duplicate(true),
    }


static func _apply_progression_fields(profile: ProfileSnapshot, staged: ProfileSnapshot) -> void:
    profile.level = staged.level
    profile.xp = staged.xp
    profile.skill_points = staged.skill_points
    profile.automatic_stats = staged.automatic_stats.duplicate(true)
    profile.claimed_transactions = staged.claimed_transactions.duplicate(true)


static func _rejected(reason_id: StringName, claim_id: StringName, source_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "claim_id": claim_id,
        "source_id": source_id,
        "durable": false,
        "save_error": OK,
        "runtime_stats_applied": false,
        "runtime_rolled_back": false,
    }
