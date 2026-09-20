class_name LevelProgressionProductionService
extends RefCounted

const REASON_REWARD_DEFINITION_MISSING: StringName = &"reward_definition_missing"
const REASON_REWARD_DEFINITION_INVALID: StringName = &"reward_definition_invalid"
const REASON_PRODUCTION_AUTHORITY_INCOMPLETE: StringName = &"production_authority_incomplete"
const REASON_REWARD_ABSTRACTION_UNRESOLVED: StringName = &"reward_abstraction_unresolved"


static func readiness(
    policy: LevelProgressionPolicy = null,
    reward_definitions: Array[LevelXpRewardDefinition] = []
) -> Dictionary:
    return LevelProgressionProductionAuthority.assess(policy, reward_definitions).duplicate(true)


static func prepare_reward(
    profile: ProfileSnapshot,
    current_stat_values: Dictionary,
    reward_definition: LevelXpRewardDefinition,
    policy: LevelProgressionPolicy
) -> Dictionary:
    if reward_definition == null:
        return _rejected(REASON_REWARD_DEFINITION_MISSING)

    var reward_errors := reward_definition.validate_definition()
    if not reward_errors.is_empty():
        var invalid := _rejected(REASON_REWARD_DEFINITION_INVALID)
        invalid["reward_definition_errors"] = reward_errors.duplicate()
        invalid["source_id"] = reward_definition.source_id
        invalid["claim_id"] = reward_definition.claim_id
        return invalid

    var authority := LevelProgressionProductionAuthority.assess(
        policy,
        [reward_definition]
    )
    if not bool(authority.get("production_ready", false)):
        var incomplete := _rejected(REASON_PRODUCTION_AUTHORITY_INCOMPLETE)
        incomplete["source_id"] = reward_definition.source_id
        incomplete["claim_id"] = reward_definition.claim_id
        incomplete["production_readiness"] = authority.duplicate(true)
        incomplete["missing_authoritative_fields"] = (authority.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray).duplicate()
        return incomplete

    if reward_definition.delivery_kind == LevelXpRewardDefinition.DELIVERY_REWARD_ABSTRACTION:
        var unresolved := _rejected(REASON_REWARD_ABSTRACTION_UNRESOLVED)
        unresolved["source_id"] = reward_definition.source_id
        unresolved["claim_id"] = reward_definition.claim_id
        unresolved["reward_abstraction_id"] = reward_definition.reward_abstraction_id
        return unresolved

    return LevelProgressionService.prepare_award(
        profile,
        current_stat_values,
        reward_definition.xp_amount,
        reward_definition.claim_id,
        reward_definition.source_id,
        policy
    )


static func commit_reward(
    profile: ProfileSnapshot,
    current_stat_values: Dictionary,
    reward_definition: LevelXpRewardDefinition,
    policy: LevelProgressionPolicy,
    atomic_commit_owner: Callable
) -> Dictionary:
    var prepared := prepare_reward(profile, current_stat_values, reward_definition, policy)
    if not bool(prepared.get("accepted", false)):
        return prepared
    return LevelProgressionService.commit_award(
        profile,
        current_stat_values,
        reward_definition.xp_amount,
        reward_definition.claim_id,
        reward_definition.source_id,
        policy,
        atomic_commit_owner
    )


static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "source_id": &"",
        "claim_id": &"",
        "reward_definition_errors": PackedStringArray(),
        "missing_authoritative_fields": PackedStringArray(),
        "production_readiness": {},
        "durable": false,
    }
