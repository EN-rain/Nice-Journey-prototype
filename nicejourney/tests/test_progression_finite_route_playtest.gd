extends SceneTree

const CONTENT: ProgressionPlaytestContent = preload("res://src/data/tuning/progression_playtest_v01.tres")
var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _expect(CONTENT != null and CONTENT.playtest_placeholder and CONTENT.validate_content().is_empty(),
        "finite route uses valid and explicitly provisional Inspector progression")
    if CONTENT == null or not CONTENT.validate_content().is_empty():
        quit(1)
        return
    var route := CONTENT.finite_required_route_status()
    _expect(bool(route.get("reaches_level_10", false))
        and int(route.get("required_route_xp", -1)) == 4560
        and int(route.get("level_10_threshold", -1)) == 4500
        and int(route.get("shortfall_xp", -1)) == 0,
        "the shipped PLAYTEST resource explicitly proves a finite route to Level 10")
    var underfunded := ProgressionPlaytestContent.new()
    underfunded.policy = CONTENT.policy
    underfunded.automatic_stat_base_by_class = CONTENT.automatic_stat_base_by_class.duplicate(true)
    for source_reward: Variant in CONTENT.xp_rewards:
        var copy := (source_reward as LevelXpRewardDefinition).duplicate() as LevelXpRewardDefinition
        if copy.source_id == &"quest:primary_floor_10":
            copy.xp_amount = 400
        underfunded.xp_rewards.append(copy)
    _expect(not bool(underfunded.finite_required_route_status().get("reaches_level_10", true))
        and not underfunded.validate_content().is_empty(),
        "underfunded finite-route tuning fails resource readiness instead of implying repeatable XP")
    var profile := ProfileCreationService.create_profile(1, "Finite XP Route", "melee")
    profile.automatic_stats = (CONTENT.automatic_stat_base_by_class["melee"] as Dictionary).duplicate(true)
    var total := 0
    for floor_id: int in range(1, 11):
        var reward := CONTENT.reward_for_source(StringName("quest:primary_floor_%d" % floor_id))
        _expect(reward != null and reward.source_family == LevelXpRewardDefinition.FAMILY_MAIN_QUEST,
            "floor %d has a finite and uniquely claimed primary reward" % floor_id)
        if reward == null:
            quit(1)
            return
        _expect(reward.xp_amount == 80 * floor_id,
            "floor %d owns its explicit provisional finite-route payout" % floor_id)
        var prepared := LevelProgressionService.prepare_award(
            profile, profile.automatic_stats, reward.xp_amount,
            reward.claim_id, reward.source_id, CONTENT.policy)
        _expect(bool(prepared.get("accepted", false)), "floor %d award prepares" % floor_id)
        if not bool(prepared.get("accepted", false)):
            quit(1)
            return
        var next := ProfileSnapshot.from_dictionary(prepared.get("staged_profile", {}) as Dictionary)
        _expect(next != null and next.xp >= profile.xp and next.level >= profile.level,
            "floor %d makes monotonic durable-ready progression" % floor_id)
        if next == null:
            quit(1)
            return
        total += reward.xp_amount
        profile = next
        _expect(profile.xp == total, "floor %d keeps exact cumulative XP before cap" % floor_id)
        if floor_id == 9:
            _expect(profile.xp == 3600 and profile.level == 9,
                "Floor 10 remains enterable underleveled on the required route")
    _expect(total == 4400 and profile.level == 9,
        "ten required quest turn-ins alone leave a finite 100-XP gap to the cap")
    var boss := CONTENT.reward_for_source(&"boss:tenth_warden_floor_10")
    _expect(boss != null and boss.xp_amount == 160
        and boss.claim_id != CONTENT.reward_for_source(&"quest:primary_floor_10").claim_id,
        "boss milestone uses its separately authored one-time claim")
    if boss == null:
        quit(1)
        return
    var completed := LevelProgressionService.prepare_award(
        profile, profile.automatic_stats, boss.xp_amount, boss.claim_id, boss.source_id, CONTENT.policy)
    _expect(bool(completed.get("accepted", false)) and int(completed.get("to_level", 0)) == 10
        and int(completed.get("to_xp", 0)) == 4500
        and int(completed.get("cap_overflow_amount", -1)) == 60,
        "finite required route reaches Level 10 and discards 60 excess XP without Level 11")
    var capped := ProfileSnapshot.from_dictionary(completed.get("staged_profile", {}) as Dictionary)
    if capped != null:
        _expect(capped.skill_points == 9
            and is_equal_approx(float(capped.automatic_stats.get("hp", 0.0)), 172.0)
            and is_equal_approx(float(capped.automatic_stats.get("stamina", 0.0)), 118.0),
            "nine transitions apply nine points and authored stat growth exactly once")
        var duplicate := LevelProgressionService.prepare_award(
            capped, capped.automatic_stats, boss.xp_amount, boss.claim_id, boss.source_id, CONTENT.policy)
        _expect(not bool(duplicate.get("accepted", true))
            and duplicate.get("reason_id", &"") == LevelProgressionService.REASON_DUPLICATE_CLAIM,
            "replaying boss reward after cap cannot grant XP or points")
        for side_id: String in ["side_region3_escort", "side_region3_annihilation", "side_region3_defense"]:
            var optional := CONTENT.reward_for_source(StringName("quest:%s" % side_id))
            _expect(optional != null and optional.source_family == LevelXpRewardDefinition.FAMILY_SIDE_QUEST,
                "optional %s remains independently claimable" % side_id)
            if optional != null:
                var optional_award := LevelProgressionService.prepare_award(
                    capped, capped.automatic_stats, optional.xp_amount, optional.claim_id, optional.source_id, CONTENT.policy)
                _expect(bool(optional_award.get("accepted", false)) and int(optional_award.get("to_level", 0)) == 10
                    and int(optional_award.get("to_xp", 0)) == 4500
                    and int(optional_award.get("skill_points_granted", -1)) == 0,
                    "optional %s can claim after cap without Level 11 or extra points" % side_id)
                if bool(optional_award.get("accepted", false)):
                    var optional_profile := ProfileSnapshot.from_dictionary(optional_award.get("staged_profile", {}) as Dictionary)
                    if optional_profile != null:
                        capped = optional_profile
    if _failures == 0:
        print("PROGRESSION FINITE ROUTE PLAYTEST TEST PASS")
    else:
        push_error("PROGRESSION FINITE ROUTE PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(ok: bool, description: String) -> void:
    if ok:
        print("PASS: %s" % description)
    else:
        _failures += 1
        push_error("FAIL: %s" % description)
