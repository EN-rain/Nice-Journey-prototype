extends SceneTree
var failures := 0
func _init() -> void:
    call_deferred(&"_run")
func _run() -> void:
    var encounter := CombatEncounterRuntime.new()
    _check(encounter.configure(&"encounter:first_enemy_slice"), "encounter configures")
    var player := _combatant(&"player:first_enemy_slice")
    _check(encounter.register_player(player), "player registers")
    var action_id := 9000
    for definition: EnemyArchetypeDefinition in EnemyArchetypeCatalog.first_slice_definitions():
        var enemy_id := StringName("enemy:%s_fixture" % String(definition.archetype_id))
        _check(encounter.register_enemy(_combatant(enemy_id)), "%s enters counted simulation" % definition.role_name)
        action_id += 1
        var token := encounter.reserve_enemy_attack(enemy_id, player.actor_id, action_id)
        _check(token > 0, "%s obtains reservation" % definition.role_name)
        _check(encounter.release_enemy_attack(token, AttackReservationLedger.RELEASE_CANCELLATION), "%s releases reservation" % definition.role_name)
    _check(encounter.get_active_enemy_count() == 4, "four active archetypes")
    _check(encounter.full_ai.get_admitted_count() == 4, "four counted full-AI actors")
    encounter.end_encounter()
    _check(encounter.full_ai.get_admitted_count() == 0 and not encounter.active_combat.is_active(), "encounter exit clears ownership")
    if failures == 0: print("ENEMY SLICE ENCOUNTER INTEGRATION TEST PASS")
    quit(failures)
func _combatant(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _check(state.configure(actor_id, 30, 0.0, 0.0, 0.0, 20.0, true, false, false), "%s validates" % String(actor_id))
    return state
func _check(ok: bool, label: String) -> void:
    if ok: print("PASS: %s" % label)
    else:
        failures += 1
        push_error("FAIL: %s" % label)
