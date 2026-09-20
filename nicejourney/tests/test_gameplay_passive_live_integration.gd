extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    await _melee_cost_and_rank_rebind()
    await _ranged_burst_and_regeneration()
    await _mage_mana_and_recovery()
    await _authenticated_parry_recovery()
    if _failures == 0:
        print("GAMEPLAY PASSIVE LIVE INTEGRATION TEST PASS")
    else:
        push_error("GAMEPLAY PASSIVE LIVE INTEGRATION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _melee_cost_and_rank_rebind() -> void:
    var profile := _profile(&"melee")
    var game := await _game(profile)
    var content := game.passive_skills_playtest
    var runtime := game.combat_runtime.get_passive_skill_runtime()
    _expect(content != null and content.playtest_placeholder and content.validate_content().is_empty(), "shipped passive resource is valid and explicitly provisional")
    _expect(runtime != null and runtime == game._passive_skill_runtime and runtime.rank_for(&"efficient_footwork") == 1, "real class combat runtime binds starting Melee passives")
    var base := game.active_skills_playtest.action_definitions_by_mechanic().get(&"wide_committed_melee_sweep") as ActionDefinition
    _expect(base != null, "Melee action is available from the Inspector bundle")
    if base != null:
        var before := runtime.modify_action(base)
        _expect(is_equal_approx(before.cost_amount, base.cost_amount * content.efficient_footwork_stamina_cost_multiplier[0]), "Melee action uses actual starting passive cost reduction")
        profile.skill_points = 2
        _expect(SkillProgressionService.purchase_rank(profile, &"efficient_footwork", &"test:passive:footwork:2") and SkillProgressionService.purchase_rank(profile, &"efficient_footwork", &"test:passive:footwork:3"), "Melee passive advances through existing rank owner")
        game.set_profile(profile)
        var after := game.combat_runtime.get_passive_skill_runtime().modify_action(base)
        _expect(is_equal_approx(after.cost_amount, base.cost_amount * content.efficient_footwork_stamina_cost_multiplier[2]), "rank-three action cost replaces prior passive magnitude immediately")
        _expect(is_equal_approx(base.cost_amount, game.active_skills_playtest.actions[0].cost_amount), "rank changes never mutate authored action resources")
        var reloaded := ProfileSnapshot.from_dictionary(profile.to_dictionary())
        game.set_profile(reloaded)
        _expect(is_equal_approx(game.combat_runtime.get_passive_skill_runtime().modify_action(base).cost_amount, after.cost_amount), "load-style profile replacement restores exactly one rank-three bonus")
    await _cleanup(game)


func _ranged_burst_and_regeneration() -> void:
    var game := await _game(_profile(&"ranged"))
    var content := game.passive_skills_playtest
    var stamina := game.player.stamina
    var baseline_cost := game.player.movement.tuning.dash_stamina_cost
    var before := stamina.current_stamina
    _expect(game.player.movement.try_start_dash(stamina, Vector2.RIGHT), "real dash consumes equipped Ranged passive cost")
    _expect(is_equal_approx(stamina.current_stamina, before - baseline_cost * content.fleet_recovery_movement_stamina_cost_multiplier[0]), "Fleet Recovery modifies real movement stamina debit")
    _expect(stamina.apply_combat_value(10.0, false), "stamina fixture starts below cap")
    stamina._regeneration_block_time = 0.0
    stamina._physics_process(1.0)
    _expect(is_equal_approx(stamina.current_stamina, 10.0 + stamina.tuning.regeneration_per_second * content.fleet_recovery_stamina_regeneration_multiplier[0]), "Fleet Recovery modifies real stamina regeneration from authored base")
    await _cleanup(game)


func _mage_mana_and_recovery() -> void:
    var profile := _profile(&"mage")
    var game := await _game(profile)
    var content := game.passive_skills_playtest
    var runtime := game.combat_runtime
    _expect(runtime.has_mana() and runtime.resource_pool.set_value(&"mana", 0.0), "Mage fixture has one authoritative mana pool")
    _expect(runtime.mana_regenerator.restore_remaining_delay_ticks(0), "Mage fixture clears delayed regen without replacing authored baseline")
    runtime.advance_resource_tick()
    _expect(is_equal_approx(runtime.get_mana(), runtime.tuning.mage_regeneration_per_tick * content.flow_recovery_mana_regeneration_multiplier[0]), "Flow Recovery modifies real mana regeneration")
    profile.skill_points = 1
    _expect(SkillProgressionService.purchase_rank(profile, &"stable_casting", &"test:passive:casting:1") and SkillProgressionService.equip_passive(profile, 1, &"stable_casting", true, false), "Mage can replace Flow Recovery with Stable Casting")
    game.set_profile(profile)
    _expect(is_equal_approx(runtime.mana_regenerator.amount_per_tick, runtime.tuning.mage_regeneration_per_tick), "unequipping Flow Recovery restores authored mana rate")
    game.combat_hud.call("refresh_from_runtime")
    var slot := ((game.combat_hud.call("current_snapshot") as Dictionary).get("skill_loadout", {}) as Dictionary).get("active_slots", []) as Array
    var authored := game.active_skills_playtest.action_definitions_by_mechanic().get(&"focused_arcane_projectile") as ActionDefinition
    if not slot.is_empty() and authored != null:
        _expect(int((slot[0] as Dictionary).get("recovery_ticks", -1)) == maxi(1, roundi(float(authored.recovery_ticks) * content.stable_casting_recovery_ticks_multiplier[0])), "HUD reports the real Stable Casting recovery interval")
        _expect(is_equal_approx(float((slot[0] as Dictionary).get("cost_amount", -1.0)), authored.cost_amount * content.mana_weave_mana_cost_multiplier[0]), "HUD reports actual Mana Weave action cost")
    else:
        _expect(false, "Mage HUD has an executable ranked action snapshot")
    await _cleanup(game)


func _authenticated_parry_recovery() -> void:
    var profile := _profile(&"melee")
    profile.skill_points = 1
    _expect(SkillProgressionService.purchase_rank(profile, &"parry_recovery", &"test:passive:parry:1") and SkillProgressionService.equip_passive(profile, 1, &"parry_recovery", true, false), "Melee equips the alternative Parry Recovery")
    var game := await _game(profile)
    var stamina := game.player.stamina
    _expect(stamina.apply_combat_value(20.0, false), "parry recovery fixture has missing stamina")
    _expect(game.combat_runtime.request_parry(), "Melee enters a valid supported parry window")
    var before := stamina.current_stamina
    game._on_playtest_successful_parry(&"encounter:test", &"enemy:test")
    _expect(is_equal_approx(stamina.current_stamina, before + game.passive_skills_playtest.parry_recovery_stamina_restore[0]), "authenticated parry grants exactly one equipped passive recovery")
    var after := stamina.current_stamina
    game._on_playtest_successful_parry(&"encounter:test", &"enemy:test")
    _expect(is_equal_approx(stamina.current_stamina, after), "repeated signal outside a live parry cannot farm another recovery")
    await _cleanup(game)


func _profile(class_id: StringName) -> ProfileSnapshot:
    return ProfileCreationService.create_profile(1, "Passive Live", String(class_id))


func _game(profile: ProfileSnapshot) -> GameplayRoot:
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    root.add_child(game)
    await process_frame
    return game


func _cleanup(game: GameplayRoot) -> void:
    game.queue_free()
    await process_frame


func _expect(ok: bool, description: String) -> void:
    if not ok:
        _failures += 1
        push_error(description)
