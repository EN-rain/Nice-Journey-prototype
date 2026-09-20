extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_approved_source_families_and_raw_xp_shape()
    _test_reward_abstraction_shape()
    _test_exploration_requires_explicit_authoring()
    _test_disallowed_enemy_death_and_malformed_rewards()

    if _failures == 0:
        print("LEVEL XP REWARD DEFINITION TEST PASS")
    else:
        push_error("LEVEL XP REWARD DEFINITION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_approved_source_families_and_raw_xp_shape() -> void:
    var families: Array[StringName] = [
        LevelXpRewardDefinition.FAMILY_MAIN_QUEST,
        LevelXpRewardDefinition.FAMILY_SIDE_QUEST,
        LevelXpRewardDefinition.FAMILY_BOSS_COMPLETION,
        LevelXpRewardDefinition.FAMILY_COMBAT_ENCOUNTER,
        LevelXpRewardDefinition.FAMILY_ELITE,
    ]
    for family: StringName in families:
        var definition := _raw_reward(family)
        _expect(definition.validate_definition().is_empty(), "%s accepts an explicitly authored raw-XP reward shape" % String(family))
        _expect(definition.is_primary_source() == LevelXpRewardDefinition.PRIMARY_FAMILIES.has(family), "%s primary/secondary classification matches the master" % String(family))
        var request := definition.make_award_request()
        _expect(bool(request.get("accepted", false)) and int(request.get("xp_amount", 0)) == 123, "%s request preserves authored XP without reinterpretation" % String(family))

    var boss_kill := _raw_reward(LevelXpRewardDefinition.FAMILY_BOSS_COMPLETION)
    boss_kill.definition_id = &"xp_reward:boss_kill"
    boss_kill.source_id = &"xp_source:boss_kill"
    boss_kill.claim_id = &"xp_claim:boss_kill"
    var boss_quest := _raw_reward(LevelXpRewardDefinition.FAMILY_MAIN_QUEST)
    boss_quest.definition_id = &"xp_reward:boss_quest"
    boss_quest.source_id = &"xp_source:boss_quest"
    boss_quest.claim_id = &"xp_claim:boss_quest"
    _expect(boss_kill.source_id != boss_quest.source_id and boss_kill.claim_id != boss_quest.claim_id, "boss kill XP and boss quest reward can be declared as distinct stable sources/claims")


func _test_reward_abstraction_shape() -> void:
    var definition := LevelXpRewardDefinition.new()
    definition.definition_id = &"xp_reward:abstraction"
    definition.source_id = &"xp_source:abstraction"
    definition.claim_id = &"xp_claim:abstraction"
    definition.source_family = LevelXpRewardDefinition.FAMILY_MAIN_QUEST
    definition.delivery_kind = LevelXpRewardDefinition.DELIVERY_REWARD_ABSTRACTION
    definition.reward_abstraction_id = &"reward:quest_progression_bundle"
    _expect(definition.validate_definition().is_empty(), "reward definition supports an explicit non-raw-XP progression abstraction without inventing an amount")
    _expect(int(definition.make_award_request().get("xp_amount", -1)) == 0, "reward abstraction carries no hidden raw XP amount")

    definition.xp_amount = 1
    _expect(not definition.validate_definition().is_empty(), "reward abstraction cannot silently carry a second raw XP award")


func _test_exploration_requires_explicit_authoring() -> void:
    var exploration := _raw_reward(LevelXpRewardDefinition.FAMILY_EXPLORATION_OBJECTIVE)
    _expect(not exploration.validate_definition().is_empty(), "exploration XP fails closed unless the objective is explicitly authored for XP")
    exploration.explicitly_authored_exploration_objective = true
    _expect(exploration.validate_definition().is_empty() and exploration.is_secondary_source(), "explicitly authored exploration objective is an approved secondary XP source")


func _test_disallowed_enemy_death_and_malformed_rewards() -> void:
    var enemy := _raw_reward(&"normal_enemy_death")
    _expect(not enemy.validate_definition().is_empty(), "generic normal-enemy death is not an approved XP source family")

    var zero := _raw_reward(LevelXpRewardDefinition.FAMILY_COMBAT_ENCOUNTER)
    zero.xp_amount = 0
    _expect(not zero.validate_definition().is_empty(), "raw XP rewards require an explicit positive amount")

    var invalid_id := _raw_reward(LevelXpRewardDefinition.FAMILY_ELITE)
    invalid_id.claim_id = &""
    _expect(not invalid_id.validate_definition().is_empty(), "reward definitions reject missing stable claim identity")


func _raw_reward(family: StringName) -> LevelXpRewardDefinition:
    var definition := LevelXpRewardDefinition.new()
    definition.definition_id = StringName("xp_reward:test_%s" % String(family))
    definition.source_id = StringName("xp_source:test_%s" % String(family))
    definition.claim_id = StringName("xp_claim:test_%s" % String(family))
    definition.source_family = family
    definition.delivery_kind = LevelXpRewardDefinition.DELIVERY_RAW_XP
    definition.xp_amount = 123
    return definition


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
