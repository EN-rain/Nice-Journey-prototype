extends SceneTree

const CONTENT: PassiveSkillsPlaytestContent = preload("res://src/combat/skills/passive_skills_playtest_v01.tres")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_authoring_contract_and_rank_previews()
    _test_melee_actions_poise_and_parry()
    _test_ranged_distance_weak_point_and_recovery()
    _test_mage_cost_recovery_and_regeneration()
    _test_rebind_save_load_swap_and_fail_closed()
    if _failures == 0:
        print("PASSIVE SKILL RUNTIME PLAYTEST TEST PASS")
    else:
        push_error("PASSIVE SKILL RUNTIME PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_authoring_contract_and_rank_previews() -> void:
    _expect(CONTENT != null and CONTENT.playtest_placeholder and CONTENT.validate_content().is_empty(), "shipped nine-passive tuning is complete and visibly provisional")
    var invalid := CONTENT.duplicate(true) as PassiveSkillsPlaytestContent
    invalid.breaker_poise_multiplier = PackedFloat32Array([1.1, 1.2])
    _expect(not invalid.validate_content().is_empty(), "missing rank refuses provisional authoring")
    invalid = CONTENT.duplicate(true) as PassiveSkillsPlaytestContent
    invalid.flow_recovery_mana_regeneration_multiplier = PackedFloat32Array([1.1, 1.1, 1.3])
    _expect(not invalid.validate_content().is_empty(), "rank plateau is rejected because no effect would be visible")
    invalid = CONTENT.duplicate(true) as PassiveSkillsPlaytestContent
    invalid.playtest_placeholder = false
    _expect(not invalid.validate_content().is_empty(), "PLAYTEST cannot be silently promoted to final")

    for class_id: StringName in [&"melee", &"ranged", &"mage"]:
        var runtime := _for_class(class_id)
        _expect(runtime != null, "%s profile binds exactly two valid starting passives" % String(class_id))
        if runtime == null:
            continue
        var ids: Array = SkillCatalog.PASSIVE_IDS_BY_CLASS[class_id]
        for skill_id: StringName in ids:
            for rank: int in [1, 2, 3]:
                var preview := runtime.preview_for_skill(skill_id, rank)
                _expect(bool(preview.get("accepted", false)) and bool(preview.get("playtest_placeholder", false)) and not (preview.get("values", {}) as Dictionary).is_empty(), "%s rank %d has explicit effect preview" % [String(skill_id), rank])
        _expect(not bool(runtime.preview_for_skill(ids[0], 4).get("accepted", true)), "rank 4 cannot receive a preview")
        _expect(not bool(runtime.preview_for_skill(&"unknown_passive", 1).get("accepted", true)), "unknown skills fail closed")


func _test_melee_actions_poise_and_parry() -> void:
    var profile := _profile(&"melee")
    var runtime := _bind(profile)
    var action := _action(&"action:playtest:arc_cleave", &"stamina", 20.0, 20)
    var first := runtime.modify_action(action)
    _near(first.cost_amount, 20.0 * CONTENT.efficient_footwork_stamina_cost_multiplier[0], "Efficient Footwork rank 1 reduces action stamina cost")
    _near(runtime.modify_movement_stamina_cost(20), 20.0 * CONTENT.efficient_footwork_stamina_cost_multiplier[0], "Efficient Footwork also reduces movement stamina cost")
    _near(action.cost_amount, 20.0, "authored action cost remains immutable")
    _expect(runtime.modify_action(action) != first and runtime.modify_action(action).cost_amount == first.cost_amount, "repeated action resolve does not compound modifiers")
    var zero_recovery := _action(&"action:playtest:arc_cleave", &"stamina", 20.0, 0)
    _expect(runtime.modify_action(zero_recovery).recovery_ticks == 0, "cost-only efficiency cannot invent an authored recovery interval")
    var payload := {"raw_damage": 10.0, "poise_damage": 7.0, "weak_point_triggered": false}
    var modified := runtime.modify_attack_payload(payload, Vector2.ZERO, Vector2(50, 0), false)
    _near(float(modified["poise_damage"]), 7.0 * CONTENT.breaker_poise_multiplier[0], "Breaker rank 1 increases only poise pressure")
    _near(float(modified["raw_damage"]), 10.0, "Breaker does not invent HP damage")
    _near(float(payload["poise_damage"]), 7.0, "Breaker does not modify original payload")
    _near(runtime.parry_recovery_stamina_gain(), 0.0, "locked Parry Recovery has no hidden effect")
    _expect(_purchase(profile, &"efficient_footwork", 2) and _purchase(profile, &"breaker", 2), "both starting melee passives upgrade through durable rank owner")
    _expect(runtime.bind_profile(profile, CONTENT), "new rank profile binds successfully")
    _near(runtime.modify_action(action).cost_amount, 20.0 * CONTENT.efficient_footwork_stamina_cost_multiplier[2], "Efficient Footwork rank 3 replaces rank 1 without stacking")
    _near(float(runtime.modify_attack_payload(payload, Vector2.ZERO, Vector2(50, 0), false)["poise_damage"]), 7.0 * CONTENT.breaker_poise_multiplier[2], "Breaker rank 3 replaces rank 1")
    _expect(_purchase(profile, &"parry_recovery", 3) and SkillProgressionService.equip_passive(profile, 0, &"parry_recovery", true, false), "Parry Recovery rank 3 can be learned and safely equipped")
    _expect(runtime.bind_profile(profile, CONTENT), "passive swap binds")
    _near(runtime.parry_recovery_stamina_gain(), CONTENT.parry_recovery_stamina_restore[2], "Parry Recovery grants one authenticated parry's authored stamina restoration")
    _near(runtime.modify_movement_stamina_cost(20), 20.0, "unequipped Efficient Footwork restores normal movement cost")
    _near(float(runtime.modify_attack_payload(payload, Vector2.ZERO, Vector2(50, 0), false)["poise_damage"]), 7.0 * CONTENT.breaker_poise_multiplier[2], "other passive remains active after swap")


func _test_ranged_distance_weak_point_and_recovery() -> void:
    var profile := _profile(&"ranged")
    var runtime := _bind(profile)
    var payload := {"raw_damage": 10.0, "poise_damage": 3.0, "weak_point_triggered": true, "weak_point_multiplier": 1.5}
    var minimum := CONTENT.longshot_minimum_distance_px[0]
    _near(float(runtime.modify_attack_payload(payload, Vector2.ZERO, Vector2(minimum - 1.0, 0.0), true)["raw_damage"]), 10.0, "Longshot never rewards short range")
    _near(float(runtime.modify_attack_payload(payload, Vector2.ZERO, Vector2(minimum, 0.0), true)["raw_damage"]), 10.0 * CONTENT.longshot_damage_multiplier[0], "Longshot applies at exact authored range boundary")
    _near(float(runtime.modify_attack_payload(payload, Vector2.ZERO, Vector2(minimum, 0.0), true)["weak_point_multiplier"]), 1.5, "locked Expose cannot affect visible weak points")
    _near(runtime.modify_movement_stamina_cost(10.0), 10.0 * CONTENT.fleet_recovery_movement_stamina_cost_multiplier[0], "Fleet Recovery reduces movement stamina cost")
    _near(runtime.modify_stamina_regeneration(3.0), 3.0 * CONTENT.fleet_recovery_stamina_regeneration_multiplier[0], "Fleet Recovery improves stamina recovery rate")
    _expect(_purchase(profile, &"expose", 3) and SkillProgressionService.equip_passive(profile, 1, &"expose", true, false), "Expose can reach rank 3 then replace Fleet Recovery")
    _expect(_purchase(profile, &"longshot", 2) and runtime.bind_profile(profile, CONTENT), "Longshot rank 3 and Expose rank 3 rebind")
    var far := runtime.modify_attack_payload(payload, Vector2.ZERO, Vector2(CONTENT.longshot_minimum_distance_px[2], 0.0), true)
    _near(float(far["raw_damage"]), 10.0 * CONTENT.longshot_damage_multiplier[2], "Longshot rank 3 uses its new distance and magnitude")
    _near(float(far["weak_point_multiplier"]), 1.5 * CONTENT.expose_visible_weak_point_multiplier[2], "Expose rank 3 improves the existing visible weak-point multiplier")
    _near(float(runtime.modify_attack_payload(payload, Vector2.ZERO, Vector2.ZERO, false)["weak_point_multiplier"]), 1.5, "Expose requires authenticated visible weak-point target")
    _near(runtime.modify_stamina_regeneration(3.0), 3.0, "unequipped Fleet Recovery restores baseline stamina recovery")
    _near(float(payload["weak_point_multiplier"]), 1.5, "target-specific passive application leaves base payload untouched")


func _test_mage_cost_recovery_and_regeneration() -> void:
    var profile := _profile(&"mage")
    var runtime := _bind(profile)
    var lance := _action(&"action:playtest:arcane_lance", &"mana", 20.0, 20)
    _near(runtime.modify_action(lance).cost_amount, 20.0 * CONTENT.mana_weave_mana_cost_multiplier[0], "Mana Weave rank 1 reduces mana cost")
    _near(runtime.modify_mana_regeneration(2.0), 2.0 * CONTENT.flow_recovery_mana_regeneration_multiplier[0], "Flow Recovery rank 1 improves mana rate without touching delay")
    _expect(_purchase(profile, &"mana_weave", 2) and _purchase(profile, &"flow_recovery", 2), "Mage starting passives rank up")
    _expect(runtime.bind_profile(profile, CONTENT), "Mage rank 3 rebind")
    _near(runtime.modify_action(lance).cost_amount, 20.0 * CONTENT.mana_weave_mana_cost_multiplier[2], "Mana Weave rank 3 replaces prior rank")
    _near(runtime.modify_mana_regeneration(2.0), 2.0 * CONTENT.flow_recovery_mana_regeneration_multiplier[2], "Flow Recovery rank 3 replaces prior rank")
    _expect(_purchase(profile, &"stable_casting", 3) and SkillProgressionService.equip_passive(profile, 1, &"stable_casting", true, false), "Stable Casting rank 3 replaces Flow Recovery")
    _expect(runtime.bind_profile(profile, CONTENT), "Stable Casting binds")
    _expect(runtime.modify_action(lance).recovery_ticks == maxi(1, roundi(20.0 * CONTENT.stable_casting_recovery_ticks_multiplier[2])), "Stable Casting improves recovery without shortening commit or active window")
    _expect(runtime.modify_action(lance).commit_ticks == lance.commit_ticks and runtime.modify_action(lance).active_ticks == lance.active_ticks and lance.recovery_ticks == 20, "Stable Casting preserves authored action commitment and base resource")
    var zero_recovery := _action(&"action:playtest:arcane_lance", &"mana", 20.0, 0)
    _expect(runtime.modify_action(zero_recovery).recovery_ticks == 0, "Stable Casting does not invent recovery when authored recovery is zero")
    _near(runtime.modify_mana_regeneration(2.0), 2.0, "unequipped Flow Recovery removes its rate bonus")


func _test_rebind_save_load_swap_and_fail_closed() -> void:
    var profile := _profile(&"melee")
    var runtime := _bind(profile)
    _expect(_purchase(profile, &"parry_recovery", 1) and SkillProgressionService.equip_passive(profile, 1, &"parry_recovery", true, false), "alternative passive can replace starting Breaker")
    var disk := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    _expect(disk != null and runtime.bind_profile(disk, CONTENT), "persisted loadout can be rebound after save/load or retry")
    _near(runtime.parry_recovery_stamina_gain(), CONTENT.parry_recovery_stamina_restore[0], "rebound alternative grants exact saved rank effect")
    _expect(runtime.bind_profile(disk, CONTENT), "repeated profile bind remains valid")
    _near(runtime.parry_recovery_stamina_gain(), CONTENT.parry_recovery_stamina_restore[0], "repeated bind cannot double a passive grant")
    _expect(SkillProgressionService.equip_passive(disk, 1, &"breaker", true, false) and runtime.bind_profile(disk, CONTENT), "switching back instantly removes previous bonus")
    _near(runtime.parry_recovery_stamina_gain(), 0.0, "Parry Recovery is reversible")
    var invalid_profile := ProfileSnapshot.from_dictionary(disk.to_dictionary())
    invalid_profile.skill_state["passive_slots"] = ["breaker", "breaker"]
    _expect(not runtime.bind_profile(invalid_profile, CONTENT), "invalid duplicate passive loadout refuses bind")
    _near(runtime.modify_movement_stamina_cost(20.0), 20.0 * CONTENT.efficient_footwork_stamina_cost_multiplier[0], "failed bind retains last valid profile instead of partial mutation")
    runtime.clear()
    _near(runtime.modify_movement_stamina_cost(20.0), 20.0, "explicit new-run/death teardown removes all effective modifiers")
    _near(runtime.parry_recovery_stamina_gain(), 0.0, "teardown removes event grants")


func _profile(class_id: StringName) -> ProfileSnapshot:
    var profile := ProfileCreationService.create_profile(1, "Passive Test", String(class_id))
    if profile != null:
        profile.skill_points = 12
    return profile


func _for_class(class_id: StringName) -> PassiveSkillRuntime:
    return _bind(_profile(class_id))


func _bind(profile: ProfileSnapshot) -> PassiveSkillRuntime:
    var runtime := PassiveSkillRuntime.new()
    _expect(profile != null and runtime.bind_profile(profile, CONTENT), "valid profile binds passive runtime")
    return runtime


func _purchase(profile: ProfileSnapshot, skill_id: StringName, count: int) -> bool:
    for i: int in count:
        if not SkillProgressionService.purchase_rank(profile, skill_id, StringName("skill_tx:passive:%s:%d" % [String(skill_id), i])):
            return false
    return true


func _action(action_id: StringName, resource: StringName, cost: float, recovery: int) -> ActionDefinition:
    var action := ActionDefinition.new()
    action.action_id = action_id
    action.cost_resource = resource
    action.cost_amount = cost
    action.recovery_ticks = recovery
    return action


func _near(actual: float, expected: float, description: String) -> void:
    _expect(is_equal_approx(actual, expected), "%s (actual %.4f, expected %.4f)" % [description, actual, expected])


func _expect(condition: bool, description: String) -> void:
    if not condition:
        _failures += 1
        push_error(description)
