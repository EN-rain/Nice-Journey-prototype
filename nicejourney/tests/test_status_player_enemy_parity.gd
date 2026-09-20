extends SceneTree

const TUNING: StatusPlaytestTuning = preload("res://src/data/tuning/status_effects_playtest_v01.tres")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:status_player_enemy_parity"), "encounter initializes")
    encounter.status_playtest_tuning = TUNING
    var player := _combatant(&"player:status_parity")
    var enemy := _combatant(&"enemy:status_parity")
    _expect(encounter.register_player(player) and encounter.register_enemy(enemy), "player and enemy use the same combat status owner")
    var burn_a := TUNING.application(&"burn", &"enemy:ember_a")
    var burn_b := TUNING.application(&"burn", &"enemy:ember_b")
    var slow_a := TUNING.application(&"slow", &"enemy:controller_a")
    var slow_b := TUNING.application(&"slow", &"enemy:controller_b")
    for target: CombatantRuntimeState in [player, enemy]:
        for application: Dictionary in [burn_a, burn_b, slow_a, slow_b]:
            _expect(bool(encounter.apply_status_to_target(target.actor_id, application).get("accepted", false)), "both target types admit each source-specific Burn/Slow application")
        var first := target.get_status_states()
        _expect(first.size() == 4, "different source IDs coexist without merging on either target")
        var stronger := burn_a.duplicate(true)
        stronger["magnitude"] = float(TUNING.burn_damage_per_tick) + 1.0
        stronger["duration_ticks"] = 60
        var reapplied := encounter.apply_status_to_target(target.actor_id, stronger)
        var after := target.get_status_states()
        var selected := _find(after, StringName(burn_a["status_id"]))
        _expect(
            reapplied.get("outcome", &"") == PrototypeStatusResolver.OUTCOME_REAPPLIED
            and after.size() == 4
            and int(selected.get("remaining_ticks", -1)) == TUNING.burn_duration_ticks
            and is_equal_approx(float(selected.get("magnitude", 0)), float(TUNING.burn_damage_per_tick) + 1.0),
            "same-source stronger Burn retains maximum magnitude and longer remaining duration for either target"
        )
        var stronger_slow := slow_a.duplicate(true)
        stronger_slow["magnitude"] = 0.5
        stronger_slow["duration_ticks"] = 20
        encounter.apply_status_to_target(target.actor_id, stronger_slow)
        _expect(is_equal_approx(TUNING.slow_speed_multiplier(target.get_status_states()), 0.5), "strongest same-source Slow controls movement on both actor kinds")
        _expect(int(_find(target.get_status_states(), StringName(slow_a["status_id"])).get("remaining_ticks", 0)) == TUNING.slow_duration_ticks, "shorter Slow reapplication cannot shorten either target's status")
    var tick := encounter.advance_status_ticks(TUNING.burn_tick_interval_ticks)
    var expected := TUNING.burn_damage_per_tick * 2 + 1
    var damages := tick.get("playtest_burn_damage_by_actor", {}) as Dictionary
    _expect(
        bool(tick.get("accepted", false)) and player.current_hp == 100 - expected
        and enemy.current_hp == 100 - expected
        and int(damages.get(player.actor_id, 0)) == expected
        and int(damages.get(enemy.actor_id, 0)) == expected,
        "player and enemy lose identical exact Burn HP from two sources without direct-hit critical/mitigation"
    )
    encounter.advance_status_ticks(TUNING.burn_duration_ticks)
    _expect(player.get_status_states().is_empty() and enemy.get_status_states().is_empty(), "status duration expiry clears both actor types")
    _expect(TUNING.slow_speed_multiplier(player.get_status_states()) == 1.0 and TUNING.slow_speed_multiplier(enemy.get_status_states()) == 1.0, "Slow expiry restores both actor movement multipliers")
    encounter.end_encounter()

    if _failures == 0:
        print("STATUS PLAYER ENEMY PARITY TEST PASS")
    else:
        push_error("STATUS PLAYER ENEMY PARITY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _find(states: Array, id: StringName) -> Dictionary:
    for raw_state: Variant in states:
        var state := raw_state as Dictionary
        if StringName(state.get("status_id", &"")) == id:
            return state
    return {}


func _combatant(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    state.configure(actor_id, 100, 30.0, 0.0, 0.0, 20.0, true, false, false)
    return state


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
