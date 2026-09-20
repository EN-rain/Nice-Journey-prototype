class_name PlaytestQuestXpCommitService
extends RefCounted

# Only committed quests can pay this temporary, Inspector-authored XP.
# Quest completion and XP use separate durable transactions, so a failed XP
# save leaves a recoverable completed quest, never an unclaimable XP source.
const REASON_INVALID_CONTEXT: StringName = &"xp_context_unavailable"
const REASON_QUEST_NOT_COMPLETED: StringName = &"xp_quest_not_completed"
const REASON_BOSS_NOT_DURABLY_CLEARED: StringName = &"xp_boss_not_durably_cleared"
const REASON_REWARD_UNAVAILABLE: StringName = &"xp_reward_unavailable"
const REASON_BASELINE_INVALID: StringName = &"xp_baseline_invalid"
const REASON_RUNTIME_STATS_MISMATCH: StringName = &"xp_runtime_stats_mismatch"
const REASON_RUNTIME_APPLY_FAILED: StringName = &"xp_runtime_apply_failed"
const REASON_RUNTIME_APPLY_MISMATCH: StringName = &"xp_runtime_apply_mismatch"
const REASON_RUNTIME_ROLLBACK_FAILED: StringName = &"xp_runtime_rollback_failed"
const REASON_SAVE_FAILED: StringName = &"xp_save_failed"
const REASON_STAGED_INVALID: StringName = &"xp_staged_invalid"


static func commit_completed_quest(
    save_service: SaveService,
    slot: int,
    profile: ProfileSnapshot,
    content: ProgressionPlaytestContent,
    quest_id: StringName,
    runtime_capture: Callable,
    runtime_apply: Callable
) -> Dictionary:
    if (
        save_service == null or slot < 1 or slot > SaveService.SLOT_COUNT
        or profile == null or content == null or not runtime_capture.is_valid()
        or not runtime_apply.is_valid() or not content.validate_content().is_empty()
    ):
        return _rejected(REASON_INVALID_CONTEXT, quest_id)
    var quest: Variant = profile.quest_progress.get(String(quest_id), null)
    if not quest is Dictionary or StringName(String((quest as Dictionary).get("state", &""))) != QuestProgressState.STATE_COMPLETED:
        return _rejected(REASON_QUEST_NOT_COMPLETED, quest_id)
    var reward := content.reward_for_source(StringName("quest:%s" % String(quest_id)))
    if reward == null or reward.delivery_kind != LevelXpRewardDefinition.DELIVERY_RAW_XP or not reward.source_family in [
        LevelXpRewardDefinition.FAMILY_MAIN_QUEST,
        LevelXpRewardDefinition.FAMILY_SIDE_QUEST,
    ]:
        return _rejected(REASON_REWARD_UNAVAILABLE, quest_id)
    return _commit_reward(save_service, slot, profile, content, reward, quest_id, runtime_capture, runtime_apply)


static func commit_cleared_tenth_warden(
    save_service: SaveService,
    slot: int,
    profile: ProfileSnapshot,
    content: ProgressionPlaytestContent,
    runtime_capture: Callable,
    runtime_apply: Callable
) -> Dictionary:
    var quest_id := Floor10PrimaryBossObjectiveService.QUEST_ID
    if (
        save_service == null or slot < 1 or slot > SaveService.SLOT_COUNT
        or profile == null or content == null or not runtime_capture.is_valid()
        or not runtime_apply.is_valid() or not content.validate_content().is_empty()
    ):
        return _rejected(REASON_INVALID_CONTEXT, quest_id)
    var quest: Variant = profile.quest_progress.get(String(quest_id), null)
    var raw_floor: Variant = profile.tower_floor_states.get("10", null)
    if (
        not quest is Dictionary or StringName(String((quest as Dictionary).get("state", &""))) != QuestProgressState.STATE_COMPLETED
        or not raw_floor is Dictionary or not bool((raw_floor as Dictionary).get("boss_defeated", false))
        or not bool((raw_floor as Dictionary).get("primary_cleared", false))
        or not bool(profile.permanent_flags.get(Floor10PrimaryBossObjectiveService.FLAG_FLOOR_10_CLEARED, false))
    ):
        return _rejected(REASON_BOSS_NOT_DURABLY_CLEARED, quest_id)
    var persisted := save_service.load_profile(slot)
    if persisted == null or persisted.profile_id != profile.profile_id:
        return _rejected(REASON_BOSS_NOT_DURABLY_CLEARED, quest_id)
    var saved_quest: Variant = persisted.quest_progress.get(String(quest_id), null)
    var saved_floor: Variant = persisted.tower_floor_states.get("10", null)
    if (
        not saved_quest is Dictionary or StringName(String((saved_quest as Dictionary).get("state", &""))) != QuestProgressState.STATE_COMPLETED
        or not saved_floor is Dictionary or not bool((saved_floor as Dictionary).get("boss_defeated", false))
        or not bool((saved_floor as Dictionary).get("primary_cleared", false))
        or not bool(persisted.permanent_flags.get(Floor10PrimaryBossObjectiveService.FLAG_FLOOR_10_CLEARED, false))
    ):
        return _rejected(REASON_BOSS_NOT_DURABLY_CLEARED, quest_id)
    var reward := content.reward_for_source(&"boss:tenth_warden_floor_10")
    if reward == null or reward.source_family != LevelXpRewardDefinition.FAMILY_BOSS_COMPLETION or reward.delivery_kind != LevelXpRewardDefinition.DELIVERY_RAW_XP:
        return _rejected(REASON_REWARD_UNAVAILABLE, quest_id)
    var result := _commit_reward(save_service, slot, profile, content, reward, quest_id, runtime_capture, runtime_apply)
    result["boss_reward"] = true
    return result


static func _commit_reward(
    save_service: SaveService,
    slot: int,
    profile: ProfileSnapshot,
    content: ProgressionPlaytestContent,
    reward: LevelXpRewardDefinition,
    quest_id: StringName,
    runtime_capture: Callable,
    runtime_apply: Callable
) -> Dictionary:
    var plan_profile := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if plan_profile == null:
        return _rejected(REASON_STAGED_INVALID, quest_id)
    if plan_profile.automatic_stats.is_empty():
        var baseline: Variant = content.automatic_stat_base_by_class.get(profile.class_id, null)
        if not baseline is Dictionary or not AutomaticStatState.validate_dictionary(baseline).is_empty() or (baseline as Dictionary).is_empty():
            return _rejected(REASON_BASELINE_INVALID, quest_id)
        plan_profile.automatic_stats = AutomaticStatState.normalize_dictionary(baseline)
    var raw_before: Variant = runtime_capture.call()
    if not raw_before is Dictionary or not AutomaticStatState.equivalent(raw_before, plan_profile.automatic_stats):
        return _rejected(REASON_RUNTIME_STATS_MISMATCH, quest_id)
    var prepared := LevelProgressionService.prepare_award(
        plan_profile, raw_before, reward.xp_amount, reward.claim_id, reward.source_id, content.policy
    )
    if not bool(prepared.get("accepted", false)):
        return prepared
    var staged_raw: Variant = prepared.get("staged_profile", null)
    if not staged_raw is Dictionary:
        return _rejected(REASON_STAGED_INVALID, quest_id)
    var staged := ProfileSnapshot.from_dictionary(staged_raw as Dictionary)
    if staged == null or not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _rejected(REASON_STAGED_INVALID, quest_id)

    # Runtime mirror is applied before save, then rolled back on save rejection.
    # The live profile is not changed until both have succeeded.
    var applied: Variant = runtime_apply.call(staged.automatic_stats.duplicate(true))
    var apply_rejected := not applied is bool or not bool(applied)
    var apply_mismatched := false
    if not apply_rejected:
        apply_mismatched = not AutomaticStatState.equivalent(runtime_capture.call(), staged.automatic_stats)
    if apply_rejected or apply_mismatched:
        var apply_rollback: Variant = runtime_apply.call(raw_before.duplicate(true))
        if not apply_rollback is bool or not bool(apply_rollback) or not AutomaticStatState.equivalent(runtime_capture.call(), raw_before):
            return _rejected(REASON_RUNTIME_ROLLBACK_FAILED, quest_id)
        var apply_failed := _rejected(REASON_RUNTIME_APPLY_FAILED if apply_rejected else REASON_RUNTIME_APPLY_MISMATCH, quest_id)
        apply_failed["runtime_rolled_back"] = true
        return apply_failed
    var error := save_service.save_profile(slot, staged)
    if error != OK:
        if not bool(runtime_apply.call(raw_before.duplicate(true))) or not AutomaticStatState.equivalent(runtime_capture.call(), raw_before):
            var failed_rollback := _rejected(REASON_RUNTIME_ROLLBACK_FAILED, quest_id)
            failed_rollback["save_error"] = error
            return failed_rollback
        var failed_save := _rejected(REASON_SAVE_FAILED, quest_id)
        failed_save["save_error"] = error
        failed_save["runtime_rolled_back"] = true
        return failed_save

    profile.level = staged.level
    profile.xp = staged.xp
    profile.skill_points = staged.skill_points
    profile.automatic_stats = staged.automatic_stats.duplicate(true)
    profile.claimed_transactions = staged.claimed_transactions.duplicate(true)
    var result := prepared.duplicate(true)
    result.erase("staged_profile")
    result["durable"] = true
    result["save_error"] = OK
    result["quest_id"] = quest_id
    return result


static func _rejected(reason: StringName, quest_id: StringName) -> Dictionary:
    return {"accepted": false, "reason_id": reason, "quest_id": quest_id, "durable": false}
