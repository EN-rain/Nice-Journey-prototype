class_name ProgressionPlaytestContent
extends Resource

# Placeholder values only. Runtime reward handoff must still prove its own
# atomic save/stat ownership before primary quest callbacks may grant XP.
@export var playtest_placeholder: bool = true
@export var policy: LevelProgressionPolicy = null
@export var automatic_stat_base_by_class: Dictionary = {}
@export var xp_rewards: Array[LevelXpRewardDefinition] = []


func validate_content() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("provisional progression content must be flagged playtest_placeholder")
    if policy == null:
        errors.append("level progression policy is required")
        return errors
    errors.append_array(policy.validate_policy())
    for class_id: String in ["melee", "ranged", "mage"]:
        var raw_stats: Variant = automatic_stat_base_by_class.get(class_id, null)
        if not raw_stats is Dictionary:
            errors.append("base automatic stats required for class %s" % class_id)
        elif (raw_stats as Dictionary).is_empty() or not AutomaticStatState.validate_dictionary(raw_stats as Dictionary).is_empty():
            errors.append("invalid base automatic stats for class %s" % class_id)
    var seen_sources: Dictionary = {}
    var seen_claims: Dictionary = {}
    var seen_definitions: Dictionary = {}
    for reward: LevelXpRewardDefinition in xp_rewards:
        if reward == null or not reward.validate_definition().is_empty():
            errors.append("all XP rewards must be valid")
            continue
        for pair: Array in [
            ["source_id", String(reward.source_id), seen_sources],
            ["claim_id", String(reward.claim_id), seen_claims],
            ["definition_id", String(reward.definition_id), seen_definitions],
        ]:
            var key := String(pair[1])
            var seen := pair[2] as Dictionary
            if seen.has(key):
                errors.append("duplicate XP %s: %s" % [String(pair[0]), key])
            seen[key] = true
    var route := finite_required_route_status()
    if not bool(route.get("reaches_level_10", false)):
        errors.append("finite required primary-floor and boss XP must reach Level 10 without optional farming")
    return errors


# Gameplay may only award existing finite, independently claimed sources. This
# audit reports their declared required-route total without inventing combat XP.
func finite_required_route_status() -> Dictionary:
    var cap_xp := policy.threshold_tuning.total_xp_to_cap() if policy != null and policy.threshold_tuning != null else -1
    var rewards_by_source: Dictionary = {}
    for reward: LevelXpRewardDefinition in xp_rewards:
        if reward != null and reward.validate_definition().is_empty():
            rewards_by_source[String(reward.source_id)] = reward
    var total: int = 0
    var missing: PackedStringArray = PackedStringArray()
    for floor_id: int in range(1, 11):
        var source := "quest:primary_floor_%d" % floor_id
        var reward := rewards_by_source.get(source) as LevelXpRewardDefinition
        if reward == null or reward.source_family != LevelXpRewardDefinition.FAMILY_MAIN_QUEST or reward.delivery_kind != LevelXpRewardDefinition.DELIVERY_RAW_XP:
            missing.append(source)
        else:
            total += reward.xp_amount
    var boss_source := "boss:tenth_warden_floor_10"
    var boss := rewards_by_source.get(boss_source) as LevelXpRewardDefinition
    if boss == null or boss.source_family != LevelXpRewardDefinition.FAMILY_BOSS_COMPLETION or boss.delivery_kind != LevelXpRewardDefinition.DELIVERY_RAW_XP:
        missing.append(boss_source)
    else:
        total += boss.xp_amount
    return {
        "required_route_xp": total,
        "level_10_threshold": cap_xp,
        "shortfall_xp": maxi(0, cap_xp - total) if cap_xp >= 0 else -1,
        "missing_source_ids": missing,
        "reaches_level_10": cap_xp > 0 and missing.is_empty() and total >= cap_xp,
    }


func reward_for_source(source_id: StringName) -> LevelXpRewardDefinition:
    if not validate_content().is_empty():
        return null
    for reward: LevelXpRewardDefinition in xp_rewards:
        if reward.source_id == source_id:
            return reward
    return null
