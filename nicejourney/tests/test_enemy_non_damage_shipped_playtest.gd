extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(ProfileCreationService.create_profile(1, "Non Damage", "melee"))
    root.add_child(game)
    await process_frame
    game._set_foundation_world_enabled(false)
    game.player.global_position = Vector2(250, 180)
    var host := game.tower_encounter_session_host
    host.set_physics_process(false)
    var owner := game.enemy_non_damage_playtest_delivery
    owner.set_physics_process(false)
    _expect(owner != null and owner.content.playtest_placeholder and owner.content.validate_tuning(game.status_playtest_tuning).is_empty(), "live scene assigns valid, provisional Inspector tuning and native markers")
    var encounter := CombatEncounterRuntime.new()
    var eid := &"encounter:non_damage_playtest"
    _expect(encounter.configure(eid, game.shared_active_combat, game.shared_full_ai), "real shared encounter configures")
    var player_state := _actor(&"player:local")
    _expect(encounter.register_player(player_state), "real player combatant admitted")
    var visuals: Dictionary = {}
    var runtimes: Dictionary = {}
    var drivers: Dictionary = {}
    for archetype: StringName in [&"support", &"bruiser", &"controller_disruptor", &"summoner"]:
        var actor := StringName("enemy:%s" % String(archetype))
        var state := _actor(actor)
        _expect(encounter.register_enemy(state), "%s admitted as a real, capped enemy" % String(archetype))
        var runtime := EnemyArchetypeRuntime.new()
        _expect(runtime.configure(encounter, actor, &"player:local", archetype), "%s canonical non-damage archetype configured" % String(archetype))
        var driver := EnemySignatureActionPhaseDriver.new()
        _expect(driver.configure(runtime, EnemySignatureActionTimingCatalog.get_timing(archetype)), "%s configured its own action windup/active clock" % String(archetype))
        var visual := Node2D.new()
        visual.position = Vector2(300, 180) if archetype == &"support" else (Vector2(306, 180) if archetype == &"bruiser" else Vector2(380, 180))
        host.add_child(visual)
        visuals[actor] = visual
        runtimes[actor] = runtime
        drivers[actor] = driver
    host._sessions[eid] = {
        "encounter_runtime": encounter,
        "archetype_runtimes": runtimes,
        "action_phase_drivers": drivers,
        "visuals_by_actor": visuals,
    }
    _expect(owner.resolve_active_window(eid, {"accepted": false}).get("reason_id", &"") == owner.REASON_INVALID_CONTEXT, "unverified active window can neither buff nor slow")

    var support := runtimes[&"enemy:support"] as EnemyArchetypeRuntime
    var support_driver := drivers[&"enemy:support"] as EnemySignatureActionPhaseDriver
    var support_state := encounter.get_combatant(&"enemy:support")
    var ally := encounter.get_combatant(&"enemy:bruiser")
    var unsupported := support.get_active_delivery_context(1)
    _expect(not bool(unsupported.get("accepted", false)), "noncommitted support tactic is not a ward")
    _expect(_begin_active(support, support_driver, 1001, {"ally_observed": true}), "Support commits a real observed-ally action")
    var support_context := support.get_active_delivery_context(1001)
    host.enemy_active_delivery_window_opened.emit(eid, support_context)
    _expect(bool(owner.last_result.get("accepted", false)) and owner.last_result.get("target_id", &"") == &"enemy:bruiser", "Support wards a nearby distinct ally, not itself or the player")
    _expect(is_equal_approx(ally.physical_defense, 4.0) and is_equal_approx(ally.arcane_defense, 4.0) and is_equal_approx(support_state.physical_defense, 0.0), "only observed ally gains provisional two-domain defense")
    host.enemy_active_delivery_window_opened.emit(eid, support_context)
    _expect(not bool(owner.last_result.get("accepted", true)) and is_equal_approx(ally.physical_defense, 4.0), "replayed active-window event cannot stack or duplicate a ward")
    for _tick: int in owner.content.ward_duration_ticks:
        owner.advance_fixed_tick()
    _expect(is_equal_approx(ally.physical_defense, 0.0) and is_equal_approx(ally.arcane_defense, 0.0), "ward expires and exactly restores ally defense")

    var controller := runtimes[&"enemy:controller_disruptor"] as EnemyArchetypeRuntime
    var controller_driver := drivers[&"enemy:controller_disruptor"] as EnemySignatureActionPhaseDriver
    _expect(_begin_active(controller, controller_driver, 2001, {"telegraph_ready": true, "observed_target_position": game.player.global_position}), "Controller commits a telegraphed field at observed player position")
    host.enemy_active_delivery_window_opened.emit(eid, controller.get_active_delivery_context(2001))
    _expect(bool(owner.last_result.get("accepted", false)) and owner.last_result.get("mode", &"") == &"slow_field", "Controller places visible native ColorRect field instead of inventing contact damage")
    owner.advance_fixed_tick()
    _expect(is_equal_approx(game.status_playtest_tuning.slow_speed_multiplier(player_state.get_status_states()), 0.75), "player in field receives existing bounded Slow rather than a new status type")
    var first_slow_id := StringName("%s/%s" % [String(StatusPlaytestTuning.SLOW_ID), String(&"enemy:controller_disruptor")])
    _expect(player_state.get_status_states().size() == 1 and (player_state.get_status_states()[0] as Dictionary).get("status_id") == first_slow_id,
        "the first Controller field identifies its actual caster, not a global Slow source")
    # Keep the first field alive, then deliver another Controller's real ACTIVE
    # window into the same target. Only matching source IDs may refresh each other.
    for previous_driver: EnemySignatureActionPhaseDriver in [support_driver, controller_driver]:
        for _tick: int in int(previous_driver.timing["active_ticks"]) + int(previous_driver.timing["recovery_ticks"]) + int(previous_driver.timing["cooldown_ticks"]) + 1:
            previous_driver.advance_fixed_tick()
    var second_controller_id := &"enemy:controller_disruptor_second"
    _expect(encounter.register_enemy(_actor(second_controller_id)), "second Controller shares the same live encounter")
    var second_controller := EnemyArchetypeRuntime.new()
    _expect(second_controller.configure(encounter, second_controller_id, &"player:local", &"controller_disruptor"), "second Controller has its own action identity")
    var second_controller_driver := EnemySignatureActionPhaseDriver.new()
    _expect(second_controller_driver.configure(second_controller, EnemySignatureActionTimingCatalog.get_timing(&"controller_disruptor")), "second Controller has an independent authored windup")
    var second_controller_visual := Node2D.new()
    second_controller_visual.position = Vector2(385, 180)
    host.add_child(second_controller_visual)
    visuals[second_controller_id] = second_controller_visual
    runtimes[second_controller_id] = second_controller
    drivers[second_controller_id] = second_controller_driver
    _expect(_begin_active(second_controller, second_controller_driver, 2002, {"telegraph_ready": true, "observed_target_position": game.player.global_position}), "independent Controller commits an authenticated field")
    host.enemy_active_delivery_window_opened.emit(eid, second_controller.get_active_delivery_context(2002))
    owner.advance_fixed_tick()
    var second_slow_id := StringName("%s/%s" % [String(StatusPlaytestTuning.SLOW_ID), String(second_controller_id)])
    var overlapping := player_state.get_status_states()
    _expect(overlapping.size() == 2 and (overlapping[0] as Dictionary).get("status_id") == first_slow_id
        and (overlapping[1] as Dictionary).get("status_id") == second_slow_id,
        "independent Controller fields coexist by caster ID instead of merging into one global Slow")
    _expect(is_equal_approx(game.status_playtest_tuning.slow_speed_multiplier(overlapping), 0.75),
        "two Slow sources do not sum movement reduction")
    for _tick: int in owner.content.control_slow_apply_interval_ticks - 1:
        encounter.advance_status_ticks(1)
        owner.advance_fixed_tick()
    var refreshed := player_state.get_status_states()
    _expect(refreshed.size() == 2 and (refreshed[0] as Dictionary).get("status_id") == first_slow_id
        and (refreshed[1] as Dictionary).get("status_id") == second_slow_id
        and int((refreshed[0] as Dictionary).get("remaining_ticks", 0)) == owner.content.control_slow_refresh_ticks,
        "first source reapplication refreshes its own duration without duplicating status IDs")
    for _tick: int in 1:
        encounter.advance_status_ticks(1)
        owner.advance_fixed_tick()
    refreshed = player_state.get_status_states()
    _expect(refreshed.size() == 2 and int((refreshed[1] as Dictionary).get("remaining_ticks", 0)) == owner.content.control_slow_refresh_ticks,
        "second source independently refreshes its own duration on its own cadence")
    game.player.global_position = Vector2(470, 180)
    for _tick: int in owner.content.control_slow_refresh_ticks:
        encounter.advance_status_ticks(1)
        owner.advance_fixed_tick()
    _expect(player_state.get_status_states().is_empty(), "player leaves field and Slow expires after short bounded refresh without hidden pursuit")
    encounter.get_combatant(&"enemy:controller_disruptor").current_hp = 0
    encounter.get_combatant(second_controller_id).current_hp = 0
    owner.advance_fixed_tick()
    _expect(owner._fields.is_empty(), "defeated Controllers cannot keep live damaging/control zones")

    var summoner := runtimes[&"enemy:summoner"] as EnemyArchetypeRuntime
    var summoner_driver := drivers[&"enemy:summoner"] as EnemySignatureActionPhaseDriver
    _expect(_begin_active(summoner, summoner_driver, 3001, {"reinforcement_budget_available": true}), "Summoner can reach its independently governed active-window contract")
    host.enemy_active_delivery_window_opened.emit(eid, summoner.get_active_delivery_context(3001))
    _expect(owner.last_result.get("reason_id", &"") == owner.REASON_UNBUDGETED_SUMMON and encounter.full_ai.get_admitted_count() == 5, "Summoner does not create free or untracked reinforcements from missing finite spawn authoring")

    owner.reset()
    host.end_encounter(eid)
    game.queue_free()
    await process_frame
    if _failures == 0:
        print("ENEMY NON-DAMAGE SHIPPED PLAYTEST TEST PASS")
    else:
        push_error("ENEMY NON-DAMAGE SHIPPED PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _actor(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, 100, 100.0, 0.0, 0.0, 20.0, true, false, false), "%s state valid" % String(actor_id))
    return state


func _begin_active(runtime: EnemyArchetypeRuntime, driver: EnemySignatureActionPhaseDriver, instance_id: int, facts: Dictionary) -> bool:
    var selection := {"accepted": true, "tactic_id": runtime.definition.signature_action_id}
    if not bool(driver.begin(selection, instance_id, facts).get("accepted", false)):
        return false
    for _tick: int in int(driver.timing["windup_ticks"]):
        if not driver.advance_fixed_tick():
            return false
    return runtime.phase_id == EnemyArchetypeRuntime.PHASE_ACTIVE


func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
