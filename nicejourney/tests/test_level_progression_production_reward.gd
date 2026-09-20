extends SceneTree

const DEFAULT_THRESHOLDS: LevelThresholdTuning = preload("res://src/progression/leveling/level_threshold_default.tres")

var _failures := 0
var _atomic_called := false


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_production_reward_path_is_fail_closed()
    _test_invalid_reward_rejected_before_authority_check()
    _test_reward_abstraction_never_becomes_hidden_raw_xp()

    if _failures == 0:
        print("LEVEL PROGRESSION PRODUCTION REWARD TEST PASS")
    else:
        push_error("LEVEL PROGRESSION PRODUCTION REWARD TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_production_reward_path_is_fail_closed() -> void:
    var profile := ProfileCreationService.create_profile(1, "Production Reward Gate", "melee")
    profile.automatic_stats = {"fixture_hp": 100.0}
    var policy := _fixture_policy()
    var reward := _raw_reward()
    var before := profile.to_dictionary()

    var prepared := LevelProgressionProductionService.prepare_reward(
        profile,
        profile.automatic_stats,
        reward,
        policy
    )
    _expect(not bool(prepared.get("accepted", true)) and StringName(prepared.get("reason_id", &"")) == LevelProgressionProductionService.REASON_PRODUCTION_AUTHORITY_INCOMPLETE, "production reward preparation rejects structurally valid fixture policy/reward data while authority is missing")
    var missing := prepared.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray
    _expect(missing.has("xp_storage_semantics") and missing.has("xp_amount_or_reward_abstraction_per_source"), "production rejection exposes unresolved policy and reward authority fields")
    _expect(profile.to_dictionary() == before, "failed production preparation cannot mutate live progression state")

    _atomic_called = false
    var committed := LevelProgressionProductionService.commit_reward(
        profile,
        profile.automatic_stats,
        reward,
        policy,
        Callable(self, &"_atomic_owner")
    )
    _expect(not bool(committed.get("accepted", true)) and not _atomic_called, "fail-closed production commit never invokes a persistence owner")
    _expect(profile.to_dictionary() == before, "failed production commit cannot stage XP, level, stats, skill points, or claims")


func _test_invalid_reward_rejected_before_authority_check() -> void:
    var invalid := LevelXpRewardDefinition.new()
    var result := LevelProgressionProductionService.prepare_reward(null, {}, invalid, null)
    _expect(not bool(result.get("accepted", true)) and StringName(result.get("reason_id", &"")) == LevelProgressionProductionService.REASON_REWARD_DEFINITION_INVALID, "malformed progression reward is rejected with a dedicated reason before production authority evaluation")
    _expect(not (result.get("reward_definition_errors", PackedStringArray()) as PackedStringArray).is_empty(), "invalid reward rejection exposes exact validator errors")


func _test_reward_abstraction_never_becomes_hidden_raw_xp() -> void:
    var reward := LevelXpRewardDefinition.new()
    reward.definition_id = &"xp_reward:test_abstraction"
    reward.source_id = &"xp_source:test_abstraction"
    reward.claim_id = &"xp_claim:test_abstraction"
    reward.source_family = LevelXpRewardDefinition.FAMILY_SIDE_QUEST
    reward.delivery_kind = LevelXpRewardDefinition.DELIVERY_REWARD_ABSTRACTION
    reward.reward_abstraction_id = &"reward:test_progression_bundle"
    _expect(reward.validate_definition().is_empty(), "explicit reward abstraction validates independently of raw XP")
    var readiness := LevelProgressionProductionService.readiness(_fixture_policy(), [reward])
    _expect(not bool(readiness.get("production_ready", true)), "structurally valid reward abstraction still requires authoritative production policy/content")


func _fixture_policy() -> LevelProgressionPolicy:
    var policy := LevelProgressionPolicy.new()
    policy.threshold_tuning = DEFAULT_THRESHOLDS
    policy.xp_storage_semantics = LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL
    policy.cap_overflow_behavior = LevelProgressionPolicy.CAP_OVERFLOW_DISCARD
    policy.skill_points_granted_by_transition = PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1, 1])
    policy.stat_growth_by_transition = [
        {"fixture_hp": 1.0}, {"fixture_hp": 1.0}, {"fixture_hp": 1.0},
        {"fixture_hp": 1.0}, {"fixture_hp": 1.0}, {"fixture_hp": 1.0},
        {"fixture_hp": 1.0}, {"fixture_hp": 1.0}, {"fixture_hp": 1.0},
    ]
    return policy


func _raw_reward() -> LevelXpRewardDefinition:
    var reward := LevelXpRewardDefinition.new()
    reward.definition_id = &"xp_reward:test_production_gate"
    reward.source_id = &"xp_source:test_production_gate"
    reward.claim_id = &"xp_claim:test_production_gate"
    reward.source_family = LevelXpRewardDefinition.FAMILY_MAIN_QUEST
    reward.delivery_kind = LevelXpRewardDefinition.DELIVERY_RAW_XP
    reward.xp_amount = 100
    return reward


func _atomic_owner(_prepared: Dictionary) -> Dictionary:
    _atomic_called = true
    return {
        "accepted": true,
        "durable": true,
        "profile_committed": true,
        "stat_growth_committed": true,
    }


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
