extends SceneTree

const DEFAULT_THRESHOLDS: LevelThresholdTuning = preload("res://src/progression/leveling/level_threshold_default.tres")
const SAVE_ROOT: String = "user://test_level_progression_profile_commit"

var _failures: int = 0
var _runtime_stats: Dictionary = {}
var _runtime_apply_count: int = 0
var _reject_next_runtime_apply: bool = false
var _skip_next_runtime_apply: bool = false


class FailingSaveService:
    extends SaveService

    func save_profile(_slot_index: int, _profile: ProfileSnapshot) -> int:
        return ERR_CANT_CREATE


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_legacy_profile_without_automatic_stats_remains_readable()
    _test_durable_profile_stat_owner_and_load_restore()
    _test_save_failure_rolls_runtime_back()
    _test_failed_or_incomplete_runtime_apply_rolls_back_before_save()
    _test_duplicate_claim_and_runtime_mismatch_fail_before_apply()

    if _failures == 0:
        print("LEVEL PROGRESSION PROFILE COMMIT TEST PASS")
    else:
        push_error("LEVEL PROGRESSION PROFILE COMMIT TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_legacy_profile_without_automatic_stats_remains_readable() -> void:
    var profile := ProfileCreationService.create_profile(1, "Legacy Progression", "melee")
    var legacy_payload := profile.to_dictionary()
    legacy_payload.erase("automatic_stats")
    _expect(ProfileSnapshot.validate_dictionary(legacy_payload).is_empty(), "schema-1 profiles from before automatic_stats remain backward-compatible")
    var restored := ProfileSnapshot.from_dictionary(legacy_payload)
    _expect(restored != null and restored.automatic_stats.is_empty(), "legacy profile load represents unauthored automatic stats explicitly as empty rather than inventing values")

    var invalid_payload := profile.to_dictionary()
    invalid_payload["automatic_stats"] = {"hp": -1.0}
    _expect(not ProfileSnapshot.validate_dictionary(invalid_payload).is_empty(), "profile persistence rejects invalid automatic-stat values")


func _test_durable_profile_stat_owner_and_load_restore() -> void:
    var save_service := SaveService.new(SAVE_ROOT)
    save_service.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Durable Stats", "melee")
    profile.automatic_stats = {"hp": 100.0, "stamina": 50.0}
    _runtime_stats = profile.automatic_stats.duplicate(true)
    _runtime_apply_count = 0

    var committed := LevelProgressionProfileCommitService.commit_award(
        save_service,
        1,
        profile,
        350,
        &"xp_claim:test:durable_profile_stats",
        &"xp_source:test:quest_fixture",
        _make_policy(),
        Callable(self, &"_capture_runtime_stats"),
        Callable(self, &"_apply_runtime_stats")
    )
    _expect(bool(committed.get("accepted", false)) and bool(committed.get("durable", false)), "coherent progression transaction commits through SaveService")
    _expect(profile.level == 3 and profile.xp == 350 and profile.skill_points == 3, "level, XP and unspent skill points commit together")
    _expect(AutomaticStatState.equivalent(profile.automatic_stats, {"hp": 115.0, "stamina": 53.0}), "profile owns the exact durable automatic-stat result")
    _expect(AutomaticStatState.equivalent(_runtime_stats, profile.automatic_stats), "live runtime stat mirror matches the durable profile after commit")
    _expect(_runtime_apply_count == 1, "successful progression applies runtime automatic stats exactly once")

    var loaded := save_service.load_profile(1)
    _expect(loaded != null and loaded.level == 3 and loaded.xp == 350 and loaded.skill_points == 3, "save/load restores exact progression fields")
    _expect(loaded != null and AutomaticStatState.equivalent(loaded.automatic_stats, profile.automatic_stats), "save/load restores exact durable automatic stats")

    _runtime_stats = {"hp": 1.0, "stamina": 1.0}
    var restored := LevelProgressionProfileCommitService.restore_runtime_from_profile(
        loaded,
        Callable(self, &"_apply_runtime_stats")
    )
    _expect(bool(restored.get("accepted", false)) and AutomaticStatState.equivalent(_runtime_stats, loaded.automatic_stats), "load restoration reapplies the profile-owned automatic stat state to the runtime mirror")
    save_service.delete_slot(1)


func _test_save_failure_rolls_runtime_back() -> void:
    var profile := ProfileCreationService.create_profile(2, "Rollback Stats", "ranged")
    profile.automatic_stats = {"hp": 100.0, "stamina": 50.0}
    _runtime_stats = profile.automatic_stats.duplicate(true)
    _runtime_apply_count = 0
    var before_profile := profile.to_dictionary()

    var result := LevelProgressionProfileCommitService.commit_award(
        FailingSaveService.new(),
        2,
        profile,
        350,
        &"xp_claim:test:rollback",
        &"xp_source:test:quest_fixture",
        _make_policy(),
        Callable(self, &"_capture_runtime_stats"),
        Callable(self, &"_apply_runtime_stats")
    )
    _expect(not bool(result.get("accepted", true)) and StringName(result.get("reason_id", &"")) == LevelProgressionProfileCommitService.REASON_SAVE_FAILED, "durable save failure rejects the progression transaction")
    _expect(bool(result.get("runtime_rolled_back", false)), "durable save failure reports successful runtime rollback")
    _expect(profile.to_dictionary() == before_profile, "failed durable commit leaves the live profile unchanged")
    _expect(AutomaticStatState.equivalent(_runtime_stats, {"hp": 100.0, "stamina": 50.0}), "failed durable commit restores the exact pre-award runtime automatic stats")
    _expect(_runtime_apply_count == 2, "save failure performs one staged runtime apply and one rollback")


func _test_failed_or_incomplete_runtime_apply_rolls_back_before_save() -> void:
    var save_service := SaveService.new(SAVE_ROOT)
    save_service.delete_slot(2)
    var profile := ProfileCreationService.create_profile(2, "Partial Apply", "melee")
    profile.automatic_stats = {"hp": 100.0, "stamina": 50.0}
    _runtime_stats = profile.automatic_stats.duplicate(true)
    var before := profile.to_dictionary()

    _reject_next_runtime_apply = true
    var rejected := LevelProgressionProfileCommitService.commit_award(
        save_service, 2, profile, 350, &"xp_claim:test:partial_apply",
        &"xp_source:test:partial_apply", _make_policy(),
        Callable(self, &"_capture_runtime_stats"), Callable(self, &"_apply_runtime_stats_with_failure")
    )
    _expect(not bool(rejected.get("accepted", true))
        and rejected.get("reason_id", &"") == LevelProgressionProfileCommitService.REASON_RUNTIME_STAT_APPLY_REJECTED
        and bool(rejected.get("runtime_rolled_back", false)),
        "callback that mutates then rejects restores the prior automatic-stat mirror")
    _expect(profile.to_dictionary() == before and AutomaticStatState.equivalent(_runtime_stats, before["automatic_stats"])
        and save_service.load_profile(2) == null,
        "partial-apply rejection commits no XP, points, claim or saved profile")

    _skip_next_runtime_apply = true
    var mismatched := LevelProgressionProfileCommitService.commit_award(
        save_service, 2, profile, 350, &"xp_claim:test:missing_apply",
        &"xp_source:test:missing_apply", _make_policy(),
        Callable(self, &"_capture_runtime_stats"), Callable(self, &"_apply_runtime_stats_with_failure")
    )
    _expect(not bool(mismatched.get("accepted", true))
        and mismatched.get("reason_id", &"") == LevelProgressionProfileCommitService.REASON_RUNTIME_STAT_APPLY_MISMATCH
        and bool(mismatched.get("runtime_rolled_back", false)),
        "callback returning success without applying stats fails runtime readback and rolls back")
    _expect(profile.to_dictionary() == before and AutomaticStatState.equivalent(_runtime_stats, before["automatic_stats"])
        and save_service.load_profile(2) == null,
        "false-success runtime callback cannot save a progression claim")
    save_service.delete_slot(2)


func _test_duplicate_claim_and_runtime_mismatch_fail_before_apply() -> void:
    var save_service := SaveService.new(SAVE_ROOT)
    save_service.delete_slot(3)
    var profile := ProfileCreationService.create_profile(3, "Idempotent Stats", "mage")
    profile.automatic_stats = {"hp": 100.0, "stamina": 50.0}
    _runtime_stats = profile.automatic_stats.duplicate(true)
    _runtime_apply_count = 0
    var policy := _make_policy()

    var first := LevelProgressionProfileCommitService.commit_award(
        save_service,
        3,
        profile,
        100,
        &"xp_claim:test:idempotent",
        &"xp_source:test:boss_fixture",
        policy,
        Callable(self, &"_capture_runtime_stats"),
        Callable(self, &"_apply_runtime_stats")
    )
    _expect(bool(first.get("accepted", false)) and profile.level == 2, "first stable XP claim commits once")
    var after_first := profile.to_dictionary()
    var apply_count_after_first := _runtime_apply_count

    var duplicate := LevelProgressionProfileCommitService.commit_award(
        save_service,
        3,
        profile,
        100,
        &"xp_claim:test:idempotent",
        &"xp_source:test:boss_fixture",
        policy,
        Callable(self, &"_capture_runtime_stats"),
        Callable(self, &"_apply_runtime_stats")
    )
    _expect(not bool(duplicate.get("accepted", true)) and StringName(duplicate.get("reason_id", &"")) == LevelProgressionService.REASON_DUPLICATE_CLAIM, "duplicate XP claim cannot replay level, skill-point or stat grants")
    _expect(profile.to_dictionary() == after_first and _runtime_apply_count == apply_count_after_first, "duplicate XP delivery performs no second runtime mutation")

    _runtime_stats = {"hp": 999.0, "stamina": 999.0}
    var mismatch := LevelProgressionProfileCommitService.commit_award(
        save_service,
        3,
        profile,
        1,
        &"xp_claim:test:runtime_mismatch",
        &"xp_source:test:boss_fixture",
        policy,
        Callable(self, &"_capture_runtime_stats"),
        Callable(self, &"_apply_runtime_stats")
    )
    _expect(not bool(mismatch.get("accepted", true)) and StringName(mismatch.get("reason_id", &"")) == LevelProgressionProfileCommitService.REASON_RUNTIME_STAT_MISMATCH, "runtime automatic-stat drift is rejected instead of becoming a second permanent owner")
    _expect(_runtime_apply_count == apply_count_after_first, "runtime mismatch rejects before any staged runtime apply")
    save_service.delete_slot(3)


func _capture_runtime_stats() -> Dictionary:
    return _runtime_stats.duplicate(true)


func _apply_runtime_stats(stats: Dictionary) -> bool:
    if not AutomaticStatState.validate_dictionary(stats).is_empty():
        return false
    _runtime_stats = AutomaticStatState.normalize_dictionary(stats)
    _runtime_apply_count += 1
    return true


func _apply_runtime_stats_with_failure(stats: Dictionary) -> bool:
    if _skip_next_runtime_apply:
        _skip_next_runtime_apply = false
        return true
    var applied := _apply_runtime_stats(stats)
    if _reject_next_runtime_apply:
        _reject_next_runtime_apply = false
        return false
    return applied


func _make_policy() -> LevelProgressionPolicy:
    var policy := LevelProgressionPolicy.new()
    policy.threshold_tuning = DEFAULT_THRESHOLDS
    policy.xp_storage_semantics = LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL
    policy.cap_overflow_behavior = LevelProgressionPolicy.CAP_OVERFLOW_DISCARD
    policy.skill_points_granted_by_transition = PackedInt32Array([1, 2, 0, 1, 0, 2, 1, 0, 3])
    policy.stat_growth_by_transition = [
        {"hp": 10.0, "stamina": 2.0},
        {"hp": 5.0, "stamina": 1.0},
        {"hp": 8.0, "stamina": 1.5},
        {"hp": 6.0, "stamina": 1.0},
        {"hp": 7.0, "stamina": 2.0},
        {"hp": 9.0, "stamina": 1.0},
        {"hp": 5.0, "stamina": 1.0},
        {"hp": 10.0, "stamina": 2.5},
        {"hp": 12.0, "stamina": 3.0},
    ]
    return policy


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
