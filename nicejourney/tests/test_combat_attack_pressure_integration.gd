extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_shared_pressure_across_overlapping_encounters()
    if _failures == 0:
        print("COMBAT ATTACK PRESSURE INTEGRATION TEST PASS")
    else:
        push_error("COMBAT ATTACK PRESSURE INTEGRATION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_shared_pressure_across_overlapping_encounters() -> void:
    var active := ActiveCombatRegistry.new()
    var full_ai := FullAiSimulationLedger.new()
    var pressure := AttackPressureLedger.new(2)
    var encounter_a := CombatEncounterRuntime.new()
    var encounter_b := CombatEncounterRuntime.new()
    _expect(encounter_a.configure(&"encounter:pressure_runtime_a", active, full_ai, pressure), "first overlapping encounter accepts shared pressure ownership")
    _expect(encounter_b.configure(&"encounter:pressure_runtime_b", active, full_ai, pressure), "second overlapping encounter accepts shared pressure ownership")
    var player_a := _combatant(&"player:pressure_runtime_a")
    var player_b := _combatant(&"player:pressure_runtime_b")
    var enemy_a := _combatant(&"enemy:pressure_runtime_a")
    var enemy_b1 := _combatant(&"enemy:pressure_runtime_b1")
    var enemy_b2 := _combatant(&"enemy:pressure_runtime_b2")
    _expect(encounter_a.register_player(player_a) and encounter_a.register_enemy(enemy_a), "first pressure encounter registers its combatants")
    _expect(encounter_b.register_player(player_b) and encounter_b.register_enemy(enemy_b1) and encounter_b.register_enemy(enemy_b2), "second pressure encounter registers its combatants")
    var token_a := encounter_a.reserve_enemy_attack(enemy_a.actor_id, player_a.actor_id, 61001)
    var token_b := encounter_b.reserve_enemy_attack(enemy_b1.actor_id, player_b.actor_id, 61002)
    _expect(token_a > 0 and token_b > 0, "two overlapping attacks can commit up to shared pressure cap")
    _expect(encounter_a.has_enemy_attack_ownership(enemy_a.actor_id, player_a.actor_id, 61001, token_a), "encounter verifies exact reservation plus pressure ownership for a committed attack")
    _expect(not encounter_a.has_enemy_attack_ownership(enemy_a.actor_id, player_b.actor_id, 61001, token_a), "attack ownership query rejects target remapping")
    _expect(pressure.get_active_count() == 2, "shared pressure ledger counts commitments across both encounter runtimes")
    _expect(encounter_b.reserve_enemy_attack(enemy_b2.actor_id, player_b.actor_id, 61003) == 0, "third overlapping attack cannot bypass global pressure budget")
    _expect(encounter_a.release_enemy_attack(token_a, AttackReservationLedger.RELEASE_COMPLETION), "normal action completion releases both reservation and pressure slot")
    _expect(not encounter_a.has_enemy_attack_ownership(enemy_a.actor_id, player_a.actor_id, 61001, token_a), "released attack no longer reports authoritative ownership")
    var token_b2 := encounter_b.reserve_enemy_attack(enemy_b2.actor_id, player_b.actor_id, 61003)
    _expect(token_b2 > 0, "released global pressure capacity is reusable by another encounter")
    encounter_b.end_encounter()
    _expect(pressure.get_active_count() == 0, "encounter exit releases all pressure owned by that encounter")
    encounter_a.end_encounter()

func _combatant(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, 100, 100.0, 0.0, 0.0, 20.0, true, false, false), "%s combatant validates" % String(actor_id))
    return state

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
