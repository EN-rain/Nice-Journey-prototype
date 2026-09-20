extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var shared_combat := ActiveCombatRegistry.new()
    var shared_full_ai := FullAiSimulationLedger.new()
    var first := CombatEncounterRuntime.new()
    var second := CombatEncounterRuntime.new()
    _expect(first.configure(&"encounter:overlap_a", shared_combat, shared_full_ai), "first overlapping encounter configures against shared combat registries")
    _expect(second.configure(&"encounter:overlap_b", shared_combat, shared_full_ai), "second overlapping encounter configures against shared combat registries")

    var player_a := _combatant(&"player:overlap_a")
    var player_b := _combatant(&"player:overlap_b")
    _expect(first.register_player(player_a), "first overlapping encounter registers its player target")
    _expect(second.register_player(player_b), "second overlapping encounter registers its player target")

    for index: int in range(7):
        _expect(first.register_enemy(_combatant(StringName("enemy:overlap_a_%02d" % index))), "first encounter admits shared FULL-AI actor %d" % index)
    for index: int in range(5):
        _expect(second.register_enemy(_combatant(StringName("enemy:overlap_b_%02d" % index))), "second encounter admits shared FULL-AI actor %d" % index)
    _expect(shared_full_ai.get_admitted_count() == FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS, "overlapping encounters share one global 12 FULL-AI cap")

    var overflow := _combatant(&"enemy:overlap_b_overflow")
    _expect(not second.register_enemy(overflow), "thirteenth FULL-AI actor is rejected across encounter boundary")
    _expect(second.get_combatant(overflow.actor_id) == null, "rejected global-cap actor is not left registered locally")

    first.end_encounter()
    _expect(shared_full_ai.get_admitted_count() == 5, "ending one encounter releases only its actors from the shared FULL-AI ledger")
    _expect(second.register_enemy(overflow), "released global capacity can be reused by another overlapping encounter")
    _expect(shared_full_ai.get_admitted_count() == 6, "shared ledger reflects surviving encounter plus newly admitted actor")

    second.end_encounter()
    _expect(shared_full_ai.get_admitted_count() == 0, "ending all encounters clears shared FULL-AI admissions")
    if _failures == 0:
        print("OVERLAPPING ENCOUNTER FULL-AI CAP TEST PASS")
    else:
        push_error("OVERLAPPING ENCOUNTER FULL-AI CAP TEST FAILURES: %d" % _failures)
    quit(_failures)

func _combatant(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    state.configure(actor_id, 100, 100.0, 0.0, 0.0, 10.0, true, false, false)
    return state

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
