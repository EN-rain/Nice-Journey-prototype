extends SceneTree

const SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const CONTENT: ProgressionPlaytestContent = preload("res://src/data/tuning/progression_playtest_v01.tres")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _expect(CONTENT != null and CONTENT.playtest_placeholder and CONTENT.validate_content().is_empty(), "provisional level/XP authoring is explicit and valid")
    _expect(CONTENT.xp_rewards.size() == 14, "10 primary + 3 side + independently claimed boss XP sources exist")
    _expect(CONTENT.policy.xp_storage_semantics == LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL and CONTENT.policy.cap_overflow_behavior == LevelProgressionPolicy.CAP_OVERFLOW_DISCARD, "provisional cumulative XP and Level-10 cap semantics are explicit")
    _expect(CONTENT.policy.skill_points_granted_by_transition.size() == 9 and CONTENT.policy.stat_growth_by_transition.size() == 9, "each Level 1–9 transition has authored skill grants and stat growth")
    var boss_reward := CONTENT.reward_for_source(&"boss:tenth_warden_floor_10")
    var quest_reward := CONTENT.reward_for_source(&"quest:primary_floor_10")
    _expect(boss_reward != null and quest_reward != null and boss_reward.claim_id != quest_reward.claim_id, "boss defeat and Floor 10 turn-in cannot share an XP claim")
    _expect(CONTENT.reward_for_source(&"quest:side_region3_escort") != null and CONTENT.reward_for_source(&"quest:side_region3_annihilation") != null and CONTENT.reward_for_source(&"quest:side_region3_defense") != null, "all three reserved side-quest slots have provisional XP definitions")

    var profile := ProfileCreationService.create_profile(1, "Progression Placeholder", "melee")
    var stats := (CONTENT.automatic_stat_base_by_class["melee"] as Dictionary).duplicate(true)
    profile.automatic_stats = stats.duplicate(true)
    var reward := CONTENT.reward_for_source(&"quest:primary_floor_1")
    var prepared := LevelProgressionService.prepare_award(
        profile,
        stats,
        reward.xp_amount,
        reward.claim_id,
        reward.source_id,
        CONTENT.policy
    )
    _expect(bool(prepared.get("accepted", false)), "provisional XP reward can be staged without mutating current profile")
    _expect(profile.level == 1 and profile.xp == 0, "planning does not prematurely grant XP")
    if bool(prepared.get("accepted", false)):
        _expect(int(prepared.get("to_xp", -1)) == reward.xp_amount and int(prepared.get("to_level", -1)) == 1, "first turn-in preserves exact provisional XP below the next threshold")
        _expect((prepared.get("staged_profile", {}) as Dictionary).get("automatic_stats", {}) == stats, "staged reward keeps authoritative automatic stats coherent")
    var rewards: Array[LevelXpRewardDefinition] = []
    for entry: Variant in CONTENT.xp_rewards:
        rewards.append(entry as LevelXpRewardDefinition)
    var status := LevelProgressionProductionService.readiness(CONTENT.policy, rewards)
    _expect(bool(status.get("policy_structurally_valid", false)) and bool(status.get("reward_definitions_structurally_valid", false)) and not bool(status.get("production_ready", true)), "valid provisional XP policy is not falsely promoted to final production authority")

    var gameplay := SCENE.instantiate() as GameplayRoot
    _expect(gameplay.progression_playtest_content == CONTENT and gameplay.progression_playtest_content.playtest_placeholder, "shipped Gameplay scene references progression playtest resource")
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.level_progression_policy == CONTENT.policy, "shipped scene applies provisional progression policy for future atomic XP integration")
    gameplay.queue_free()
    await process_frame

    if _failures == 0:
        print("PROGRESSION SHIPPED PLAYTEST TEST PASS")
    else:
        push_error("PROGRESSION SHIPPED PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, name: String) -> void:
    if ok:
        print("PASS: %s" % name)
        return
    _failures += 1
    push_error("FAIL: %s" % name)
