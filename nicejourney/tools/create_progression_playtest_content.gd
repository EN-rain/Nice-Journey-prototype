extends SceneTree

const OUTPUT := "res://src/data/tuning/progression_playtest_v01.tres"


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var content := ProgressionPlaytestContent.new()
    content.resource_name = "PLAYTEST level 1-10 and finite quest XP v01"
    content.playtest_placeholder = true
    var thresholds := LevelThresholdTuning.new()
    thresholds.xp_to_next_by_level = PackedInt32Array([100, 200, 300, 400, 500, 600, 700, 800, 900])
    var policy := LevelProgressionPolicy.new()
    policy.threshold_tuning = thresholds
    policy.xp_storage_semantics = LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL
    policy.cap_overflow_behavior = LevelProgressionPolicy.CAP_OVERFLOW_DISCARD
    policy.skill_points_granted_by_transition = PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1, 1])
    for _from_level: int in range(1, 10):
        policy.stat_growth_by_transition.append({"hp": 8.0, "stamina": 2.0})
    content.policy = policy
    content.automatic_stat_base_by_class = {
        "melee": {"hp": 100.0, "stamina": 100.0},
        "ranged": {"hp": 100.0, "stamina": 100.0},
        "mage": {"hp": 100.0, "stamina": 100.0},
    }

    # One non-farmable reward claim per primary Quest Hall turn-in. Boss defeat
    # is intentionally separate from the Floor 10 primary turn-in.
    for floor_id: int in range(1, 11):
        content.xp_rewards.append(_reward(
            "primary_floor_%d" % floor_id,
            "quest:primary_floor_%d" % floor_id,
            LevelXpRewardDefinition.FAMILY_MAIN_QUEST,
            floor_id * 80
        ))
    for index: int in range(3):
        var slot_id: String = ["side_region3_escort", "side_region3_annihilation", "side_region3_defense"][index]
        content.xp_rewards.append(_reward(
            slot_id,
            "quest:%s" % slot_id,
            LevelXpRewardDefinition.FAMILY_SIDE_QUEST,
            40 + index * 20
        ))
    content.xp_rewards.append(_reward(
        "tenth_warden_boss",
        "boss:tenth_warden_floor_10",
        LevelXpRewardDefinition.FAMILY_BOSS_COMPLETION,
        160
    ))

    var errors := content.validate_content()
    if not errors.is_empty():
        push_error("PLAYTEST PROGRESSION INVALID: %s" % str(errors))
        quit(1)
        return
    var code := ResourceSaver.save(content, OUTPUT)
    print("PROGRESSION PLAYTEST BUNDLE: %d" % code)
    quit(0 if code == OK else 1)


func _reward(name: String, source: String, family: StringName, amount: int) -> LevelXpRewardDefinition:
    var reward := LevelXpRewardDefinition.new()
    reward.definition_id = StringName("xp_def:playtest:%s" % name)
    reward.source_id = StringName(source)
    reward.claim_id = StringName("xp_claim:playtest:%s" % name)
    reward.source_family = family
    reward.delivery_kind = LevelXpRewardDefinition.DELIVERY_RAW_XP
    reward.xp_amount = amount
    return reward
