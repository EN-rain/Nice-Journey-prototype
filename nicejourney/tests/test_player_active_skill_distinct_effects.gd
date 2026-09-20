extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    await _check_driving_thrust()
    await _check_fan_shot()
    await _check_backstep_and_defense()
    await _check_collision_and_interruption()
    if _failures == 0:
        print("PLAYER ACTIVE SKILL DISTINCT EFFECTS TEST PASS")
    else:
        push_error("PLAYER ACTIVE SKILL DISTINCT EFFECTS TEST FAILURES: %d" % _failures)
    quit(_failures)


func _check_driving_thrust() -> void:
    var game := await _game("melee")
    var effect := game.player_playtest_attack_delivery.content.skill_for(&"driving_thrust")
    _expect(effect.has("movement_distance_px"), "Driving Thrust has an explicitly Inspector-authored PLAYTEST advance")
    var initial := game.player.global_position
    var started := game.request_active_skill_slot(1)
    _expect(bool(started.get("accepted", false)), "Driving Thrust R starts through the approved active slot")
    _to_active(game, started)
    var distance := game.player.global_position.distance_to(initial)
    _expect(distance > 0.0 and is_equal_approx(distance, float(effect["movement_distance_px"])), "Driving Thrust actually advances its CharacterBody2D at ACTIVE")
    _expect(is_equal_approx(game.player_playtest_attack_delivery.last_skill_movement_distance_px, distance), "movement feedback measures collision-solved displacement")
    game.queue_free()
    await process_frame


func _check_fan_shot() -> void:
    var game := await _game("ranged")
    var delivery := game.player_playtest_attack_delivery
    var effect := delivery.content.skill_for(&"fan_shot")
    _expect(int(effect.get("sequence_interval_ticks", -1)) == 2, "Fan Shot uses its Inspector-authored PLAYTEST cadence")
    var started := game.request_active_skill_slot(1)
    _expect(bool(started.get("accepted", false)), "Fan Shot R starts through the equipped slot")
    _to_active(game, started)
    _expect((delivery.get("_projectiles") as Array).size() == 1, "Fan Shot spawns only its first shot on ACTIVE entry")
    await physics_frame
    await physics_frame
    await process_frame
    _expect((delivery.get("_projectiles") as Array).size() == 2, "Fan Shot spawns its next angled shot after its authored interval")
    await physics_frame
    await physics_frame
    await process_frame
    var projectiles := delivery.get("_projectiles") as Array
    _expect(projectiles.size() == 3, "Fan Shot launches all three shots sequentially before ACTIVE ends")
    if projectiles.size() == 3:
        var directions := []
        for projectile: Dictionary in projectiles:
            directions.append((projectile["direction"] as Vector2).angle())
        _expect(directions[0] < directions[1] and directions[1] < directions[2], "Fan Shot has distinct ordered spread geometry, not coincident shots")
    game.queue_free()
    await process_frame


func _check_backstep_and_defense() -> void:
    var profile := ProfileCreationService.create_profile(1, "Backstep skill", "ranged")
    profile.skill_points = 1
    _expect(SkillProgressionService.purchase_rank(profile, &"backstep_shot", &"skill_rank:test_backstep"), "third approved Ranged active can be learned")
    _expect(SkillProgressionService.equip_active(profile, 0, &"backstep_shot", true, false), "Backstep Shot may replace Q only at safe interaction")
    var game := await _game("ranged", profile)
    var delivery := game.player_playtest_attack_delivery
    var effect := delivery.content.skill_for(&"backstep_shot")
    var defender := PlayerDefenderFactsProvider.new()
    _expect(defender.configure(game.player, game.combat_runtime, game.player_defender_facts_tuning).is_empty(), "Backstep provider has real player and authored defense tuning")
    defender.set_skill_evade_window_provider(Callable(delivery, &"has_active_backstep_evade_window"))
    _expect(not delivery.has_active_backstep_evade_window(), "Backstep cannot evade before committed ACTIVE")
    var origin := game.player.global_position
    var started := game.request_active_skill_slot(0)
    _expect(bool(started.get("accepted", false)), "learned Backstep Shot Q starts through the standard action cost owner")
    _expect(not delivery.has_active_backstep_evade_window(), "Backstep startup does not grant free evasion")
    _to_active(game, started)
    var actual := origin.x - game.player.global_position.x
    _expect(actual > 0.0 and is_equal_approx(actual, float(effect["movement_distance_px"])), "Backstep Shot actually retreats opposite locked aim with collision-solved movement")
    var snapshot := defender.make_snapshot(game.player.global_position + Vector2.RIGHT * 32.0, game.player.global_position)
    _expect(bool(snapshot.get("evade_window_active", false)) and not game.player.is_dodging(), "Backstep supplies a short skill-specific evade fact without spending dodge stamina")
    var live_enemy_snapshot := game.enemy_playtest_live_delivery.defender_provider.make_snapshot(
        game.player.global_position + Vector2.RIGHT * 32.0, game.player.global_position)
    _expect(bool(live_enemy_snapshot.get("evade_window_active", false)), "normal enemy delivery reads the same wired Backstep evade fact")
    _expect(game.combat_runtime.get_defense_mode() == DirectHitResolver.DEFENSE_NONE, "Backstep does not grant block or parry")
    var attack := {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL, "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": 10.0, "dodgeable": true, "blockable": false, "parryable": false,
        "guard_pressure": 0.0, "critical_triggered": false, "critical_multiplier": 1.0,
        "weak_point_triggered": false, "weak_point_multiplier": 1.0,
    }
    var facts := {
        "evade_window_active": snapshot["evade_window_active"], "defense_mode": snapshot["defense_mode"],
        "block_supported": false, "parry_supported": false, "facing_covered": snapshot["facing_covered"],
        "current_stamina": game.player.stamina.current_stamina, "physical_defense": 0.0, "arcane_defense": 0.0,
    }
    _expect(DirectHitResolver.resolve(attack, facts).get("outcome", &"") == DirectHitResolver.OUTCOME_DODGED, "Backstep evades only attacks tagged dodgeable through the canonical resolver")
    attack["dodgeable"] = false
    _expect(DirectHitResolver.resolve(attack, facts).get("outcome", &"") != DirectHitResolver.OUTCOME_DODGED, "undodgeable attacks do not become invulnerable by Backstep")
    for _i: int in int(effect["evade_window_ticks"]):
        delivery._physics_process(1.0 / 60.0)
    _expect(not delivery.has_active_backstep_evade_window(), "Backstep iframe expires after Inspector-authored fixed ticks")
    _expect(not bool(game.enemy_playtest_live_delivery.defender_provider.make_snapshot(
        game.player.global_position + Vector2.RIGHT * 32.0, game.player.global_position).get("evade_window_active", true)), "enemy delivery also sees the expired Backstep evade fact")
    game.queue_free()
    await process_frame


func _check_collision_and_interruption() -> void:
    var melee := await _game("melee")
    var wall := StaticBody2D.new()
    wall.collision_layer = 1
    wall.collision_mask = 1
    wall.position = Vector2(274.0, 175.0)
    var wall_shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(8.0, 64.0)
    wall_shape.shape = rectangle
    wall.add_child(wall_shape)
    melee.add_child(wall)
    await physics_frame
    melee.player.apply_aim_direction(Vector2.RIGHT)
    var before := melee.player.global_position
    var thrust := melee.request_active_skill_slot(1)
    _expect(bool(thrust.get("accepted", false)), "blocked Driving Thrust still requests its paid action normally")
    _to_active(melee, thrust)
    var distance := melee.player.global_position.x - before.x
    var authored := float(melee.player_playtest_attack_delivery.content.skill_for(&"driving_thrust")["movement_distance_px"])
    _expect(distance >= 0.0 and distance < authored and melee.player.global_position.x < wall.position.x, "Driving Thrust cannot phase through a static collision wall")
    melee.queue_free()
    await process_frame

    var ranged := await _game("ranged")
    var delivery := ranged.player_playtest_attack_delivery
    var fan := ranged.request_active_skill_slot(1)
    _expect(bool(fan.get("accepted", false)), "Fan Shot interruption fixture starts R")
    _to_active(ranged, fan)
    _expect((delivery.get("_pending_shots") as Array).size() == 1, "Fan Shot still has queued projectiles when ACTIVE begins")
    _expect(ranged.combat_runtime.action_state_machine.force_interrupt(&"test:cancel_fan_sequence"), "canonical action owner interrupts the committed sequence")
    for _tick: int in 5:
        await physics_frame
    _expect((delivery.get("_pending_shots") as Array).is_empty() and (delivery.get("_projectiles") as Array).size() == 1, "interruption cancels unfired Fan Shot projectiles but preserves already fired travel")
    ranged.queue_free()
    await process_frame


func _game(class_id: String, profile: ProfileSnapshot = null) -> GameplayRoot:
    if profile == null:
        profile = ProfileCreationService.create_profile(1, "Distinct skill " + class_id, class_id)
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    root.add_child(game)
    await process_frame
    game._set_foundation_world_enabled(false)
    game.player.global_position = Vector2(250.0, 180.0)
    game.player.apply_aim_direction(Vector2.RIGHT)
    return game


func _to_active(game: GameplayRoot, started: Dictionary) -> void:
    var action := started.get("action_definition") as ActionDefinition
    if action == null:
        _expect(false, "skill has an actual ActionDefinition")
        return
    for _i: int in action.startup_ticks + action.commit_ticks:
        game.combat_runtime.action_state_machine.advance_fixed_tick()
    _expect(game.combat_runtime.action_state_machine.get_phase() == ActionStateMachine.Phase.ACTIVE, "action reaches committed ACTIVE before delivering effects")


func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: %s" % description)
    else:
        _failures += 1
        push_error("FAIL: %s" % description)
