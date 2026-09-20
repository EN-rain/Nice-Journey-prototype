class_name LevelProgressionProductionAuthority
extends RefCounted

const MASTER_INITIAL_THRESHOLD_HYPOTHESIS = [
    100, 200, 300, 400, 500, 600, 700, 800, 900,
]

const REQUIRED_POLICY_FIELDS = [
    "production_level_threshold_table",
    "xp_storage_semantics",
    "cap_overflow_behavior",
    "skill_points_granted_by_transition",
    "automatic_stat_ids",
    "automatic_stat_base_values_global_or_by_class",
    "automatic_stat_growth_by_transition",
]

const REQUIRED_REWARD_FIELDS = [
    "xp_reward_definition_ids",
    "xp_reward_source_ids",
    "xp_reward_claim_ids",
    "xp_reward_delivery_kind_per_source",
    "xp_amount_or_reward_abstraction_per_source",
    "finite_route_xp_allocation",
]


static func known_contract() -> Dictionary:
    return {
        "min_level": LevelThresholdTuning.MIN_LEVEL,
        "max_level": LevelThresholdTuning.MAX_LEVEL,
        "transition_count": LevelThresholdTuning.TRANSITION_COUNT,
        "level_11_permitted": false,
        "automatic_base_stats_grow_with_level": true,
        "manual_core_stat_allocation_required": false,
        "level_up_commits_level_stats_and_grants_together": true,
        "level_up_auto_clears_quests": false,
        "level_up_auto_unlocks_floors": false,
        "level_up_auto_refills_resources": false,
        "stable_xp_claim_ids_required": true,
        "boss_kill_and_boss_quest_rewards_must_be_separately_declared": true,
        "normal_enemy_farming_assumed": false,
        "initial_threshold_hypothesis": PackedInt32Array(MASTER_INITIAL_THRESHOLD_HYPOTHESIS),
        "initial_threshold_hypothesis_is_production_authority": false,
        "approved_primary_source_families": LevelXpRewardDefinition.PRIMARY_FAMILIES.duplicate(),
        "approved_secondary_source_families": LevelXpRewardDefinition.SECONDARY_FAMILIES.duplicate(),
    }


static func assess(
    policy: LevelProgressionPolicy = null,
    reward_definitions: Array[LevelXpRewardDefinition] = []
) -> Dictionary:
    var policy_errors := PackedStringArray()
    if policy == null:
        policy_errors.append("no production LevelProgressionPolicy resource is authored")
    else:
        policy_errors = policy.validate_policy()

    var reward_errors: Dictionary = {}
    var seen_definition_ids: Dictionary = {}
    var seen_source_ids: Dictionary = {}
    var seen_claim_ids: Dictionary = {}
    for definition: LevelXpRewardDefinition in reward_definitions:
        if definition == null:
            reward_errors["<null>"] = PackedStringArray(["reward definition cannot be null"])
            continue
        var errors := definition.validate_definition()
        var definition_key := String(definition.definition_id)
        if definition_key.is_empty():
            definition_key = "<invalid_definition_id_%d>" % reward_errors.size()
        if seen_definition_ids.has(definition.definition_id):
            errors.append("duplicate progression reward definition_id")
        if seen_source_ids.has(definition.source_id):
            errors.append("duplicate progression reward source_id")
        if seen_claim_ids.has(definition.claim_id):
            errors.append("duplicate progression reward claim_id")
        seen_definition_ids[definition.definition_id] = true
        seen_source_ids[definition.source_id] = true
        seen_claim_ids[definition.claim_id] = true
        if not errors.is_empty():
            reward_errors[definition_key] = errors.duplicate()

    var missing := PackedStringArray()
    for field: String in REQUIRED_POLICY_FIELDS:
        missing.append(field)
    for field: String in REQUIRED_REWARD_FIELDS:
        missing.append(field)

    return {
        "accepted": policy_errors.is_empty() and reward_errors.is_empty(),
        "production_ready": false,
        "reason_id": &"authoritative_progression_values_missing",
        "known_contract": known_contract().duplicate(true),
        "policy_structurally_valid": policy != null and policy_errors.is_empty(),
        "policy_errors": policy_errors.duplicate(),
        "reward_definitions_structurally_valid": reward_errors.is_empty(),
        "reward_definition_errors": reward_errors.duplicate(true),
        "reward_definition_count": reward_definitions.size(),
        "missing_authoritative_fields": missing.duplicate(),
    }


static func default_threshold_is_only_initial_hypothesis(tuning: LevelThresholdTuning) -> bool:
    return tuning != null and tuning.xp_to_next_by_level == PackedInt32Array(MASTER_INITIAL_THRESHOLD_HYPOTHESIS)
