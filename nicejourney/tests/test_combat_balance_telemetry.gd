extends SceneTree

const STATUS: StatusPlaytestTuning = preload("res://src/data/tuning/status_effects_playtest_v01.tres")
var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var encounter := CombatEncounterRuntime.new()
    var player := CombatantRuntimeState.new()
    var enemy := CombatantRuntimeState.new()
    _expect(encounter.configure(&"encounter:telemetry_fixture")
        and player.configure(&"player:telemetry", 30, 12.0, 0.0, 0.0, 30.0, true, true, true)
        and enemy.configure(&"enemy:telemetry", 30, 0.0, 0.0, 0.0, 30.0, true, false, false)
        and encounter.register_player(player) and encounter.register_enemy(enemy),
        "authoritative encounter with two combatants")
    var machine := ActionStateMachine.new()
    var pool := ResourcePool.new()
    _expect(pool.define_resource(&"mana", 10.0), "configured action resource pool")
    machine.set_resource_pool(pool)
    var capture := CombatBalanceTelemetry.new()
    _expect(not capture.begin(encounter, &"player:not_registered", &"melee", &"telemetry:invalid", machine),
        "refuse unknown player identity")
    _expect(capture.begin(encounter, player.actor_id, &"melee", &"telemetry:fixture", machine),
        "attach to exact encounter signals")

    var spell := ActionDefinition.new()
    spell.action_id = &"action:telemetry_spell"
    spell.startup_ticks = 0
    spell.commit_ticks = 1
    spell.active_ticks = 1
    spell.recovery_ticks = 1
    spell.cooldown_ticks = 5
    spell.cost_resource = &"mana"
    spell.cost_amount = 3.0
    _expect(machine.request_action(spell), "mana action starts through shared action machine")
    capture.sample_resources(12.0, pool.get_value(&"mana"))
    for tick: int in range(4):
        machine.advance_fixed_tick()
        capture.advance_fixed_tick()
    _expect(not machine.request_action(spell) and machine.get_cooldown_ticks(spell.action_id) > 0,
        "repeat attempt rejected during cooldown")
    var basic := StarterKitCatalog.create(&"melee", StarterCombatTuning.new()).make_basic_attack_payload()
    var blocked := encounter.resolve_direct_contact(enemy.actor_id, player.actor_id, 101, 0, basic,
        false, DirectHitResolver.DEFENSE_BLOCK, true)
    var broken := encounter.resolve_direct_contact(enemy.actor_id, player.actor_id, 102, 0, basic,
        false, DirectHitResolver.DEFENSE_BLOCK, true)
    var dodged := encounter.resolve_direct_contact(enemy.actor_id, player.actor_id, 103, 0, basic,
        true, DirectHitResolver.DEFENSE_NONE, false)
    var parried := encounter.resolve_direct_contact(enemy.actor_id, player.actor_id, 104, 0, basic,
        false, DirectHitResolver.DEFENSE_PARRY, true)
    _expect(blocked.get("outcome") == DirectHitResolver.OUTCOME_BLOCKED
        and broken.get("outcome") == DirectHitResolver.OUTCOME_GUARD_BROKEN
        and dodged.get("outcome") == DirectHitResolver.OUTCOME_DODGED
        and parried.get("outcome") == DirectHitResolver.OUTCOME_PARRIED,
        "defenses are real resolver outcomes not fabricated counters")
    var duplicated := encounter.resolve_direct_contact(enemy.actor_id, player.actor_id, 104, 0, basic,
        false, DirectHitResolver.DEFENSE_PARRY, true)
    _expect(not bool(duplicated.get("accepted", false)), "duplicate contact is rejected")
    encounter.status_playtest_tuning = STATUS
    var applied := encounter.apply_status_to_target(enemy.actor_id,
        STATUS.application(PrototypeStatusResolver.BEHAVIOR_BURN))
    _expect(bool(applied.get("accepted", false))
        and bool(encounter.advance_status_ticks(30).get("accepted", false)),
        "actual Burn ticking passes authoritative status HP owner")
    var normal := encounter.resolve_direct_contact(player.actor_id, enemy.actor_id, 1, 0, basic,
        false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(normal.get("accepted", false)), "normal player damage passes the encounter resolver")
    capture.sample_resources(0.0, pool.get_value(&"mana"))
    var report := capture.snapshot()
    _expect(report["enemy_max_hp"] == 30 and report["damage_dealt"] == 12
        and report["status_damage_dealt"] == 2 and report["damage_taken"] == 10,
        "live HP and separate Burn are counted once")
    _expect(report["defense_outcomes"] == {"dodged": 1, "blocked": 1,
        "parried": 1, "guard_broken": 1}, "four defense outcomes counted exactly once")
    _expect(is_equal_approx(report["committed_resource_costs"]["mana"], 3.0)
        and is_equal_approx(report["observed_resource_minima"]["mana"], 7.0)
        and is_equal_approx(report["observed_resource_minima"]["stamina"], 0.0),
        "committed mana spend and observed resource minima are distinct")
    _expect(report["action_counts"].get("action:telemetry_spell", 0) == 1
        and report["rejected_actions"] == 1
        and report["cooldown_active_ticks"].get("action:telemetry_spell", 0) > 0
        and report["damage_by_action"].get("action:telemetry_spell", 0) == 10
        and report["successful_contacts_by_action"].get("action:telemetry_spell", 0) == 1,
        "start, rejection and cooldown occupancy use emitted action events")
    report["defense_outcomes"]["blocked"] = 99
    _expect(capture.snapshot()["defense_outcomes"]["blocked"] == 1,
        "snapshot mutations cannot change the telemetry recorder")
    capture.stop()
    var frozen := capture.snapshot()
    encounter.resolve_direct_contact(player.actor_id, enemy.actor_id, 106, 0, basic,
        false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(JSON.stringify(frozen) == JSON.stringify(capture.snapshot()),
        "stopped telemetry disconnects completely")
    encounter.end_encounter()
    machine.free()
    if _failures == 0:
        print("COMBAT BALANCE TELEMETRY TEST PASS")
    else:
        push_error("COMBAT BALANCE TELEMETRY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, label: String) -> bool:
    if not ok:
        _failures += 1
        push_error("FAIL: " + label)
    return ok
