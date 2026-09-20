extends SceneTree

const STATUS: StatusPlaytestTuning = preload("res://src/data/tuning/status_effects_playtest_v01.tres")
const SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
var _failures := 0
var _deaths := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _expect(STATUS != null and STATUS.playtest_placeholder and STATUS.validate_tuning().is_empty(), "shipped Burn and Slow values are explicitly provisional and valid")
    var burn := STATUS.application(PrototypeStatusResolver.BEHAVIOR_BURN)
    var slow := STATUS.application(PrototypeStatusResolver.BEHAVIOR_SLOW)
    _expect(burn.get("status_id", &"") == STATUS.BURN_ID and burn.get("duration_ticks", 0) == 180, "Burn source and lifetime are fixed and uniquely identified")
    _expect(slow.get("status_id", &"") == STATUS.SLOW_ID and slow.get("duration_ticks", 0) == 150, "Slow source and lifetime are fixed and uniquely identified")
    var burn_state := {"status_id": STATUS.BURN_ID, "behavior": &"burn", "remaining_ticks": 180, "magnitude": 2.0}
    _expect(STATUS.burn_damage_for_advance(burn_state, 29) == 0, "Burn does not hit before the first 30-tick cadence")
    _expect(STATUS.burn_damage_for_advance(burn_state, 30) == 2, "Burn hits at the first exact cadence")
    var advanced_burn := burn_state.duplicate(true)
    advanced_burn["remaining_ticks"] = 151
    _expect(STATUS.burn_damage_for_advance(advanced_burn, 61) == 6, "Burn accounts for multiple cadence crossings over one deterministic advance")
    var incomplete_burn := burn_state.duplicate(true)
    incomplete_burn.erase("magnitude")
    _expect(STATUS.burn_damage_for_advance(incomplete_burn, 30) == 0, "incomplete persisted Burn cannot manufacture the resource default damage")
    var corrupt_burn := burn_state.duplicate(true)
    corrupt_burn["magnitude"] = INF
    _expect(STATUS.burn_damage_for_advance(corrupt_burn, 30) == 0, "nonfinite Burn damage fails closed")
    _expect(STATUS.application(PrototypeStatusResolver.BEHAVIOR_BURN, &"enemy:ember_a").get("status_id") == &"status:playtest_burn/enemy:ember_a",
        "Burn authoring can derive a stable ID from its actual source without changing damage tuning")
    _expect(STATUS.application(PrototypeStatusResolver.BEHAVIOR_SLOW, &"enemy:controller_a").get("status_id") == &"status:playtest_slow/enemy:controller_a",
        "Slow authoring can derive a stable ID from its actual source without changing reduction tuning")
    _expect(STATUS.application(PrototypeStatusResolver.BEHAVIOR_BURN, &"bad source").is_empty(),
        "invalid source IDs cannot enter live status application")
    var source_slow_states := [
        {"status_id": STATUS.SLOW_ID, "behavior": &"slow", "remaining_ticks": 60, "magnitude": 0.25},
        {"status_id": &"status:second_slow", "behavior": &"slow", "remaining_ticks": 10, "magnitude": 0.9},
    ]
    _expect(is_equal_approx(STATUS.slow_speed_multiplier(source_slow_states), 0.4), "Slow uses strongest reduction and clamps movement to 40 percent")
    source_slow_states.append({"behavior": &"slow", "remaining_ticks": 9, "magnitude": 0.99})
    _expect(STATUS.slow_speed_multiplier(source_slow_states) == 1.0, "a malformed status collection cannot partially apply Slow")
    _expect(STATUS.slow_speed_multiplier([]) == 1.0, "no Slow leaves movement unchanged")

    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:status_playtest"), "status fixture configures encounter")
    var player := _combatant(&"player:local", 100)
    var enemy := _combatant(&"enemy:status_playtest", 100)
    _expect(encounter.register_player(player) and encounter.register_enemy(enemy), "status fixture registers live combatants")
    encounter.status_playtest_tuning = STATUS
    _expect(bool(encounter.apply_status_to_target(enemy.actor_id, burn).get("accepted", false)), "provisional Burn applies through existing authoritative state admission")
    _expect(bool(encounter.apply_status_to_target(enemy.actor_id, slow).get("accepted", false)), "provisional Slow applies as a separate status identity")
    _expect(bool(encounter.advance_status_ticks(29).get("accepted", false)) and enemy.current_hp == 100, "first 29 ticks do not deliver Burn damage")
    var tick := encounter.advance_status_ticks(1)
    _expect(bool(tick.get("accepted", false)) and int((tick.get("playtest_burn_damage_by_actor", {}) as Dictionary).get(enemy.actor_id, 0)) == 2 and enemy.current_hp == 98, "30th tick applies exact noncritical Burn damage to live HP")
    _expect(is_equal_approx(STATUS.slow_speed_multiplier(enemy.get_status_states()), 0.75), "Slow speed reduction derives from live remaining state")
    _expect(bool(encounter.advance_status_ticks(150).get("accepted", false)) and enemy.current_hp == 88, "Burn finishes all six unmitigated ticks, including final expiration")
    _expect(STATUS.slow_speed_multiplier(enemy.get_status_states()) == 1.0, "Slow expires without changing action clocks or AI cadence")
    var production := PrototypeStatusResolver.validate_production_application(burn)
    _expect(not bool(production.get("accepted", true)), "playtest Burn does not impersonate missing final production authority")
    encounter.end_encounter()

    var source_encounter := CombatEncounterRuntime.new()
    _expect(source_encounter.configure(&"encounter:status_source_playtest"), "source-specific Burn encounter configures")
    var source_target := _combatant(&"enemy:status_sources", 100)
    _expect(source_encounter.register_enemy(source_target), "source-specific Burn target enters real combat")
    source_encounter.status_playtest_tuning = STATUS
    var burn_a := STATUS.application(PrototypeStatusResolver.BEHAVIOR_BURN, &"enemy:ember_a")
    var burn_b := STATUS.application(PrototypeStatusResolver.BEHAVIOR_BURN, &"enemy:ember_b")
    _expect(bool(source_encounter.apply_status_to_target(source_target.actor_id, burn_a).get("accepted", false))
        and bool(source_encounter.apply_status_to_target(source_target.actor_id, burn_b).get("accepted", false))
        and source_target.get_status_states().size() == 2,
        "independent Burn sources coexist as two authored live statuses")
    var weaker_a := burn_a.duplicate(true)
    weaker_a["magnitude"] = float(STATUS.burn_damage_per_tick) * 0.5
    weaker_a["duration_ticks"] = int(STATUS.burn_duration_ticks / 2)
    var reapply_a := source_encounter.apply_status_to_target(source_target.actor_id, weaker_a)
    _expect(bool(reapply_a.get("accepted", false))
        and StringName(reapply_a.get("outcome", &"")) == PrototypeStatusResolver.OUTCOME_REAPPLIED
        and source_target.get_status_states().size() == 2
        and int((source_target.get_status_states()[0] as Dictionary).get("remaining_ticks", 0)) == STATUS.burn_duration_ticks
        and is_equal_approx(float((source_target.get_status_states()[0] as Dictionary).get("magnitude", 0.0)), float(STATUS.burn_damage_per_tick)),
        "same-source Burn reapplication retains strongest magnitude and greater duration without extra ticks")
    var source_tick := source_encounter.advance_status_ticks(STATUS.burn_tick_interval_ticks)
    _expect(bool(source_tick.get("accepted", false))
        and int((source_tick.get("playtest_burn_damage_by_actor", {}) as Dictionary).get(source_target.actor_id, 0)) == STATUS.burn_damage_per_tick * 2
        and source_target.current_hp == 100 - STATUS.burn_damage_per_tick * 2,
        "independent Burn sources each deliver one noncritical HP tick from the same Inspector cadence")
    source_encounter.end_encounter()

    var game := SCENE.instantiate() as GameplayRoot
    _expect(game.status_playtest_tuning == STATUS, "shipped scene assigns provisional status data")
    game.set_profile(ProfileCreationService.create_profile(1, "Status Playtest", "melee"))
    root.add_child(game)
    await process_frame
    _expect(game.tower_encounter_session_host.status_playtest_tuning == STATUS, "shipped encounter host receives playtest status tuning")
    game.queue_free()
    await process_frame
    if _failures == 0:
        print("STATUS EFFECTS SHIPPED PLAYTEST TEST PASS")
    else:
        push_error("STATUS EFFECTS SHIPPED PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _combatant(actor_id: StringName, hp: int) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    state.configure(actor_id, hp, 30.0, 0.0, 0.0, 20.0, true, false, false)
    return state


func _expect(ok: bool, name: String) -> void:
    if ok:
        print("PASS: %s" % name)
        return
    _failures += 1
    push_error("FAIL: %s" % name)
