extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Aegis Ward Playtest", "mage")
    profile.skill_points = 1
    _expect(SkillProgressionService.purchase_rank(profile, &"aegis_ward", &"skill_rank:test_aegis"), "mage can learn the third approved active skill")
    _expect(SkillProgressionService.equip_active(profile, 0, &"aegis_ward", true, false), "learned Aegis Ward may equip in Q")
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    root.add_child(game)
    await process_frame
    var runtime := game.combat_runtime
    var player_state := game.player
    var effect := game.player_playtest_attack_delivery.content.skill_for(&"aegis_ward")
    _expect(not effect.is_empty() and effect["ward_ticks"] == 90, "Aegis Ward runtime reads explicitly provisional Inspector-owned duration")
    _expect(not runtime.supports_block() and not runtime.supports_parry(), "mage has no permanent shield block or parry")
    _expect(not runtime.activate_playtest_ward(90), "ward cannot be conjured without its committed active skill")
    var start := game.request_active_skill_slot(0)
    _expect(bool(start.get("accepted", false)), "equipped Aegis Ward starts through Q")
    var action := game.active_skills_playtest.action_definitions_by_mechanic()[&"mana_block_window_without_parry"] as ActionDefinition
    for _i: int in action.startup_ticks + action.commit_ticks:
        runtime.action_state_machine.advance_fixed_tick()
    _expect(runtime.has_active_playtest_ward() and runtime.get_defense_mode() == DirectHitResolver.DEFENSE_BLOCK, "active phase creates a real timed mage block instead of an animation-only shield")
    _expect(not runtime.supports_block() and not runtime.supports_parry() and not runtime.request_parry(), "ward adds neither permanent shield equipment nor parry")
    _expect(not runtime.request_block(true), "ward does not enable the normal hold-to-block input")
    var provider := PlayerDefenderFactsProvider.new()
    _expect(provider.configure(player_state, runtime, game.player_defender_facts_tuning).is_empty(), "live defender provider binds authored dodge/facing tuning")
    var incoming := player_state.global_position + player_state.get_aim_direction() * 30.0
    var snapshot := provider.make_snapshot(incoming, player_state.global_position)
    _expect(snapshot.get("defense_mode", &"") == DirectHitResolver.DEFENSE_BLOCK and bool(snapshot.get("playtest_ward_active", false)), "enemy and boss delivery receive the same active temporary ward fact")
    var unsupported := DirectHitResolver.resolve({
        "domain": DirectHitResolver.DOMAIN_ARCANE, "delivery": DirectHitResolver.DELIVERY_PROJECTILE,
        "raw_damage": 8.0, "dodgeable": true, "blockable": true, "parryable": false,
        "guard_pressure": 2.0, "critical_triggered": false, "critical_multiplier": 1.0,
        "weak_point_triggered": false, "weak_point_multiplier": 1.0,
    }, {
        "evade_window_active": false, "defense_mode": snapshot["defense_mode"],
        "block_supported": true, "parry_supported": false,
        "facing_covered": snapshot["facing_covered"], "current_stamina": 15.0,
        "physical_defense": 0.0, "arcane_defense": 0.0,
    })
    _expect(unsupported.get("outcome", &"") == DirectHitResolver.OUTCOME_BLOCKED, "Aegis block can stop an incoming blockable arcane projectile through the canonical damage resolver")
    for _i: int in int(effect["ward_ticks"]):
        runtime.advance_resource_tick()
    _expect(not runtime.has_active_playtest_ward() and runtime.get_defense_mode() == DirectHitResolver.DEFENSE_NONE, "ward expires exactly after its Inspector-authored duration")
    var expired := provider.make_snapshot(incoming, player_state.global_position)
    _expect(not bool(expired.get("playtest_ward_active", true)) and expired.get("defense_mode", &"") == DirectHitResolver.DEFENSE_NONE, "expired ward does not leak block eligibility into subsequent encounters")
    game.queue_free()
    await process_frame
    if _failures == 0:
        print("GAMEPLAY AEGIS WARD PLAYTEST TEST PASS")
    else:
        push_error("GAMEPLAY AEGIS WARD PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, description: String) -> void:
    if ok:
        print("PASS: %s" % description)
    else:
        _failures += 1
        push_error("FAIL: %s" % description)
