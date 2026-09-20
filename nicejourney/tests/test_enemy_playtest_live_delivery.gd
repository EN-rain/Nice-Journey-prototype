extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Enemy Live Hit", "melee")
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    root.add_child(game)
    await process_frame
    game._set_foundation_world_enabled(false)
    game.player.global_position = Vector2(250, 180)
    game.player.apply_aim_direction(Vector2.RIGHT)
    var host := game.tower_encounter_session_host
    host.set_physics_process(false) # This fixture advances the real action driver explicitly.
    var encounter := CombatEncounterRuntime.new()
    var eid := &"encounter:test_enemy_live"
    var actor := &"enemy:test_enemy_live"
    var p_state := CombatantRuntimeState.new()
    var e_state := CombatantRuntimeState.new()
    _expect(encounter.configure(eid, game.shared_active_combat, game.shared_full_ai), "real combat encounter is created")
    _expect(p_state.configure(&"player:local", 100, 100.0, 0.0, 0.0, 10.0, true, true, true), "player defender supports block and parry")
    _expect(e_state.configure(actor, 100, 0.0, 0.0, 0.0, 10.0, true, false, false), "enemy combatant configured")
    _expect(encounter.register_player(p_state) and encounter.register_enemy(e_state), "both actual combatants are registered")
    var runtime := EnemyArchetypeRuntime.new()
    _expect(runtime.configure(encounter, actor, &"player:local", &"duelist"), "duelist configured")
    runtime.definition.signature_attack_authoring = game.enemy_playtest_attacks.attack_for(&"duelist")
    _expect(runtime.definition.validate_signature_attack_authoring().is_empty(), "Inspector-authored duelist geometry/payload exists")
    var driver := EnemySignatureActionPhaseDriver.new()
    _expect(driver.configure(runtime, EnemySignatureActionTimingCatalog.get_timing(&"duelist")), "duelist action driver is configured")
    var executor := EnemyActiveAttackDeliveryExecutor.new()
    _expect(executor.configure(runtime, driver), "duelist ACTIVE executor owns hit delivery")
    var enemy_visual := Node2D.new()
    enemy_visual.position = Vector2(280, 180)
    host.add_child(enemy_visual)
    await physics_frame
    await process_frame # Flush manually relocated CharacterBody2D into PhysicsServer2D before shape queries.
    host._sessions[eid] = {
        "encounter_runtime": encounter,
        "archetype_runtimes": {actor: runtime},
        "action_phase_drivers": {actor: driver}, # Keep authoritative driver addressable; suspend the host tick above.
        "attack_delivery_executors": {actor: executor},
        "visuals_by_actor": {actor: enemy_visual},
    }
    var live := game.enemy_playtest_live_delivery
    _expect(live != null and live.defender_provider.is_configured(), "shipped scene binds the real player defender facts provider")
    var pre_hit := p_state.current_hp
    host.enemy_active_delivery_window_opened.emit(eid, {
        "accepted": false, "encounter_id": eid, "actor_id": actor,
    })
    _expect(p_state.current_hp == pre_hit, "unverified enemy delivery window cannot damage player")

    _expect(_begin_live(runtime, driver, 89001), "first duelist signature enters ACTIVE")
    var context := runtime.get_active_delivery_context(89001)
    context["has_committed_observation_position"] = true
    context["committed_observation_position"] = game.player.global_position
    host.enemy_active_delivery_window_opened.emit(eid, context)
    _expect(p_state.current_hp < pre_hit and bool(live.last_delivery_result.get("accepted", false)), "physics-confirmed authored melee hit damages player through the encounter")
    var once := p_state.current_hp
    host.enemy_active_delivery_window_opened.emit(eid, context)
    _expect(p_state.current_hp == once, "duplicate active-window emission cannot hit the same player twice")
    driver.cancel()
    for _tick: int in int(driver.timing["cooldown_ticks"]):
        driver.advance_fixed_tick()

    game.player.apply_aim_direction(Vector2.RIGHT) # Fixture faces the authored attacker, not the headless cursor.
    game.combat_runtime.request_block(true)
    _expect(_begin_live(runtime, driver, 89002), "second signature starts for frontal shield block")
    var blocked_context := runtime.get_active_delivery_context(89002)
    blocked_context["has_committed_observation_position"] = true
    blocked_context["committed_observation_position"] = game.player.global_position
    host.enemy_active_delivery_window_opened.emit(eid, blocked_context)
    _expect(p_state.current_hp == once and live.last_delivery_result.get("outcome", &"") == DirectHitResolver.OUTCOME_BLOCKED, "real player facing/block facts prevent HP damage")
    driver.cancel()
    for _tick: int in int(driver.timing["cooldown_ticks"]):
        driver.advance_fixed_tick()
    game.combat_runtime.request_block(false)

    game.player.apply_aim_direction(Vector2.RIGHT)
    _expect(game.combat_runtime.request_parry(), "melee shield opens supported parry window")
    _expect(_begin_live(runtime, driver, 89003), "third signature starts during player parry")
    var parry_context := runtime.get_active_delivery_context(89003)
    parry_context["has_committed_observation_position"] = true
    parry_context["committed_observation_position"] = game.player.global_position
    host.enemy_active_delivery_window_opened.emit(eid, parry_context)
    _expect(live.last_delivery_result.get("outcome", &"") == DirectHitResolver.OUTCOME_PARRIED and game._successful_parry_ticks > 0, "real supported parry interrupts enemy and enables finite Riposte window")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE, "parried enemy releases authoritative ACTIVE reservation")

    var skills := SkillLoadoutState.new()
    _expect(skills.load_dictionary(profile.skill_state).is_empty() and skills.try_increase_rank(&"riposte"), "fixture unlocks the existing Riposte skill identity")
    _expect(skills.equip_active(0, &"riposte", true, false), "fixture equips Riposte in Q")
    profile.skill_state = skills.to_dictionary()
    var riposte := game.request_active_skill_slot(0)
    _expect(bool(riposte.get("accepted", false)) and riposte.get("skill_id", &"") == &"riposte" and game._successful_parry_ticks == 0, "Riposte consumes the verified parry event exactly once")
    game.combat_runtime.action_state_machine.force_interrupt(&"test:reset")
    _expect(not bool(game.request_active_skill_slot(0).get("accepted", true)), "Riposte cannot repeat without another verified parry")

    game.tower_encounter_session_host.end_encounter(eid)
    game.queue_free()
    await process_frame
    if _failures == 0:
        print("ENEMY PLAYTEST LIVE DELIVERY TEST PASS")
    else:
        push_error("ENEMY PLAYTEST LIVE DELIVERY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _begin_live(runtime: EnemyArchetypeRuntime, driver: EnemySignatureActionPhaseDriver, instance_id: int) -> bool:
    var selection := runtime.choose_tactic({
        "target_visible": true,
        "observation_confidence": 1.0,
        "reaction_delay_satisfied": true,
        "distance_band": EnemyArchetypeDefinition.RANGE_CLOSE,
        "reservation_available": true,
        "cooldown_ready": true,
        "objective_contested": false,
        "observed_player_recovering": true,
        "observed_player_committed": false,
        "observation_age_ticks": 0,
    }, {})
    if not bool(driver.begin(selection, instance_id, {}).get("accepted", false)):
        return false
    for _tick: int in int(driver.timing["windup_ticks"]):
        driver.advance_fixed_tick()
    return runtime.phase_id == EnemyArchetypeRuntime.PHASE_ACTIVE


func _expect(ok: bool, label: String) -> void:
    if ok:
        print("PASS: %s" % label)
    else:
        _failures += 1
        push_error("FAIL: %s" % label)
