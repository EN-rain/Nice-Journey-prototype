extends SceneTree

const DEFAULT_THRESHOLDS: LevelThresholdTuning = preload("res://src/progression/leveling/level_threshold_default.tres")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_known_master_contract()
    _test_current_repository_is_explicitly_not_production_ready()
    _test_structural_policy_does_not_become_authority()

    if _failures == 0:
        print("LEVEL PROGRESSION PRODUCTION AUTHORITY TEST PASS")
    else:
        push_error("LEVEL PROGRESSION PRODUCTION AUTHORITY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_known_master_contract() -> void:
    var contract := LevelProgressionProductionAuthority.known_contract()
    _expect(int(contract.get("min_level", 0)) == 1 and int(contract.get("max_level", 0)) == 10, "production authority preserves the locked Level 1-10 range")
    _expect(not bool(contract.get("level_11_permitted", true)), "production authority explicitly forbids Level 11")
    _expect(bool(contract.get("automatic_base_stats_grow_with_level", false)), "production authority preserves automatic base-stat growth")
    _expect(not bool(contract.get("manual_core_stat_allocation_required", true)), "prototype progression requires no manual core-stat allocation")
    _expect(bool(contract.get("level_up_commits_level_stats_and_grants_together", false)), "level/stat/grant progression remains one coherent commit")
    _expect(not bool(contract.get("level_up_auto_clears_quests", true)) and not bool(contract.get("level_up_auto_unlocks_floors", true)) and not bool(contract.get("level_up_auto_refills_resources", true)), "level-up cannot invent quest, floor-unlock, or resource-refill side effects")
    _expect(bool(contract.get("stable_xp_claim_ids_required", false)), "XP sources require stable claim identities")
    _expect(bool(contract.get("boss_kill_and_boss_quest_rewards_must_be_separately_declared", false)), "boss kill XP and boss quest rewards remain separately declared")
    _expect(not bool(contract.get("normal_enemy_farming_assumed", true)), "production progression does not assume a renewable normal-enemy farming loop")

    var primary := contract.get("approved_primary_source_families", []) as Array
    var secondary := contract.get("approved_secondary_source_families", []) as Array
    _expect(primary.size() == 3 and primary.has(LevelXpRewardDefinition.FAMILY_MAIN_QUEST) and primary.has(LevelXpRewardDefinition.FAMILY_SIDE_QUEST) and primary.has(LevelXpRewardDefinition.FAMILY_BOSS_COMPLETION), "primary XP source families exactly match the master")
    _expect(secondary.size() == 3 and secondary.has(LevelXpRewardDefinition.FAMILY_COMBAT_ENCOUNTER) and secondary.has(LevelXpRewardDefinition.FAMILY_ELITE) and secondary.has(LevelXpRewardDefinition.FAMILY_EXPLORATION_OBJECTIVE), "secondary XP source families exactly match the master")


func _test_current_repository_is_explicitly_not_production_ready() -> void:
    var readiness := LevelProgressionProductionAuthority.assess()
    _expect(not bool(readiness.get("production_ready", true)), "production progression stays fail-closed while authoritative values are absent")
    _expect(StringName(readiness.get("reason_id", &"")) == &"authoritative_progression_values_missing", "production readiness names the missing-authority condition")
    var missing := readiness.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray
    for required: String in [
        "production_level_threshold_table",
        "xp_storage_semantics",
        "cap_overflow_behavior",
        "skill_points_granted_by_transition",
        "automatic_stat_ids",
        "automatic_stat_base_values_global_or_by_class",
        "automatic_stat_growth_by_transition",
        "xp_reward_definition_ids",
        "xp_reward_source_ids",
        "xp_reward_claim_ids",
        "xp_reward_delivery_kind_per_source",
        "xp_amount_or_reward_abstraction_per_source",
        "finite_route_xp_allocation",
    ]:
        _expect(missing.has(required), "readiness reports unresolved production field: %s" % required)

    _expect(LevelProgressionProductionAuthority.default_threshold_is_only_initial_hypothesis(DEFAULT_THRESHOLDS), "default threshold resource is recognized as the master's initial tuning hypothesis")
    var known := readiness.get("known_contract", {}) as Dictionary
    _expect(not bool(known.get("initial_threshold_hypothesis_is_production_authority", true)), "100 x Level thresholds are never mislabeled as production authority")


func _test_structural_policy_does_not_become_authority() -> void:
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
    _expect(policy.validate_policy().is_empty(), "generic structurally valid progression fixtures remain usable for deterministic engine tests")
    var readiness := LevelProgressionProductionAuthority.assess(policy)
    _expect(bool(readiness.get("policy_structurally_valid", false)), "production audit can distinguish structural validity from source authority")
    _expect(not bool(readiness.get("production_ready", true)), "a caller-authored complete fixture cannot promote itself to production authority")


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
