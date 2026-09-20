extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_action_admission_contracts()
    _test_runtime_commit_lifecycle()
    _test_non_attack_tactic_boundary()
    _test_defeated_enemy_tactical_ineligibility()
    _test_summoner_uses_live_full_ai_capacity()
    if _failures == 0:
        print("ENEMY ARCHETYPE RUNTIME TEST PASS")
    else:
        push_error("ENEMY ARCHETYPE RUNTIME TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_action_admission_contracts() -> void:
    _expect_admission(&"duelist", {}, true, &"accepted")
    _expect_admission(&"marksman", {}, false, EnemyArchetypeActionAdmission.REASON_INVALID_FACTS)
    _expect_admission(&"marksman", {"line_of_sight_observed": false}, false, EnemyArchetypeActionAdmission.REASON_LINE_OF_SIGHT_REQUIRED)
    _expect_admission(&"marksman", {"line_of_sight_observed": true}, true, &"accepted")
    _expect_admission(&"assassin", {"flank_observed": false}, false, EnemyArchetypeActionAdmission.REASON_FLANK_REQUIRED)
    _expect_admission(&"assassin", {"flank_observed": true}, true, &"accepted")
    _expect_admission(&"caster", {"telegraph_ready": false}, false, EnemyArchetypeActionAdmission.REASON_TELEGRAPH_REQUIRED)
    _expect_admission(&"caster", {"telegraph_ready": true}, true, &"accepted")
    _expect_admission(&"support", {"ally_observed": false}, false, EnemyArchetypeActionAdmission.REASON_ALLY_REQUIRED)
    _expect_admission(&"support", {"ally_observed": true}, true, &"accepted")
    _expect_admission(
        &"summoner",
        {"reinforcement_budget_available": true, "full_ai_slot_available": false},
        false,
        EnemyArchetypeActionAdmission.REASON_FULL_AI_SLOT_REQUIRED
    )
    _expect_admission(
        &"summoner",
        {"reinforcement_budget_available": true, "full_ai_slot_available": true},
        true,
        &"accepted"
    )
    _expect_admission(&"flying_harrier", {"visible_targeting_window": false}, false, EnemyArchetypeActionAdmission.REASON_VISIBLE_TARGETING_REQUIRED)
    _expect_admission(&"flying_harrier", {"visible_targeting_window": true}, true, &"accepted")
    _expect_admission(&"controller_disruptor", {"telegraph_ready": false}, false, EnemyArchetypeActionAdmission.REASON_TELEGRAPH_REQUIRED)
    _expect_admission(&"controller_disruptor", {"telegraph_ready": true}, true, &"accepted")


func _test_runtime_commit_lifecycle() -> void:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:archetype_runtime"), "runtime fixture encounter configures")
    var player := _combatant(&"player:archetype_runtime")
    var enemy := _combatant(&"enemy:assassin_runtime")
    _expect(encounter.register_player(player), "runtime fixture player registers")
    _expect(encounter.register_enemy(enemy), "runtime fixture enemy registers and owns FULL-AI admission")

    var runtime := EnemyArchetypeRuntime.new()
    _expect(runtime.configure(encounter, enemy.actor_id, player.actor_id, &"assassin"), "Assassin runtime configures against live encounter ownership")

    var illegal_selection: Dictionary = runtime.choose_tactic(_selector_context(), {"flank_observed": false})
    _expect(bool(illegal_selection.get("accepted", false)), "failed signature precondition resolves to a legal non-committing tactic")
    _expect(StringName(illegal_selection.get("tactic_id", &"")) == &"tactic:hold_observe", "Assassin cannot commit signature without observed flank")
    _expect(StringName(illegal_selection.get("admission_reason_id", &"")) == EnemyArchetypeActionAdmission.REASON_FLANK_REQUIRED, "selection exposes the concrete failed fairness precondition")

    var facts := {"flank_observed": true}
    var selection: Dictionary = runtime.choose_tactic(_selector_context(), facts)
    _expect(StringName(selection.get("tactic_id", &"")) == &"action:assassin_flank_strike", "Assassin selects authored signature when observed flank is legal")

    var begin: Dictionary = runtime.begin_signature_action(selection, 41001, facts)
    _expect(bool(begin.get("accepted", false)), "signature action atomically acquires attack reservation before commitment")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_WINDUP, "commit enters readable windup phase")
    _expect(runtime.tactical_state_id == EnemyArchetypeRuntime.TACTICAL_ATTACK, "signature commitment enters the tactical Attack state")
    _expect(runtime.active_reservation_token > 0, "committed signature retains reservation ownership")
    _expect(not runtime.cooldown_ready, "commit consumes external cooldown-ready gate")
    _expect(runtime.begin_active(41001), "matching action instance enters active phase")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_ACTIVE, "active phase is explicit")
    _expect(not runtime.begin_recovery(99999), "mismatched action instance cannot advance commitment")
    _expect(runtime.begin_recovery(41001), "matching action instance enters authored recovery")
    _expect(runtime.tactical_state_id == EnemyArchetypeRuntime.TACTICAL_RECOVER, "authored recovery owns the tactical Recover state")
    _expect(runtime.finish_recovery(41001), "recovery completion releases reservation with completion cause")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE and runtime.active_reservation_token == 0, "completed action returns to idle with no leaked reservation")
    _expect(runtime.tactical_state_id == EnemyArchetypeRuntime.TACTICAL_OBSERVE, "completed commitment returns to tactical Observe")

    var held: Dictionary = runtime.choose_tactic(_selector_context(), facts)
    _expect(StringName(held.get("tactic_id", &"")) == &"tactic:hold_observe", "cooldown gate suppresses immediate repeated signature spam")
    _expect(runtime.mark_cooldown_ready(), "external cooldown owner can reopen signature admission only while idle")
    var second_selection: Dictionary = runtime.choose_tactic(_selector_context(), facts)
    var second_begin: Dictionary = runtime.begin_signature_action(second_selection, 41002, facts)
    _expect(bool(second_begin.get("accepted", false)), "signature can recommit after external cooldown readiness")
    _expect(runtime.cancel_action(AttackReservationLedger.RELEASE_INTERRUPTION), "authored interruption releases reservation with exact interruption cause")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE and runtime.active_reservation_token == 0, "interruption cannot leak action ownership")
    encounter.end_encounter()


func _test_non_attack_tactic_boundary() -> void:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:archetype_movement"), "movement fixture encounter configures")
    var player := _combatant(&"player:archetype_movement")
    var enemy := _combatant(&"enemy:marksman_movement")
    _expect(encounter.register_player(player), "movement fixture player registers")
    _expect(encounter.register_enemy(enemy), "movement fixture enemy registers")
    var runtime := EnemyArchetypeRuntime.new()
    _expect(runtime.configure(encounter, enemy.actor_id, player.actor_id, &"marksman"), "Marksman runtime configures")
    var context := _selector_context()
    context["distance_band"] = EnemyArchetypeDefinition.RANGE_CLOSE
    var selection: Dictionary = runtime.choose_tactic(context, {"line_of_sight_observed": true})
    _expect(StringName(selection.get("tactic_id", &"")) == &"tactic:withdraw", "Marksman chooses authored withdraw intent when player is too close")
    _expect(runtime.request_non_attack_tactic(selection), "runtime exposes legal movement/tactical intent without inventing navigation geometry")
    _expect(runtime.tactical_state_id == EnemyArchetypeRuntime.TACTICAL_DISENGAGE, "withdraw intent maps to the tactical Disengage state")
    _expect(not runtime.begin_signature_action(selection, 42001, {"line_of_sight_observed": true}).get("accepted", false), "movement tactic cannot bypass signature-action commitment gate")
    encounter.end_encounter()


func _test_defeated_enemy_tactical_ineligibility() -> void:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:defeated_tactical"), "defeated tactical fixture configures")
    var player := _combatant(&"player:defeated_tactical")
    var enemy := _combatant(&"enemy:defeated_tactical")
    _expect(encounter.register_player(player) and encounter.register_enemy(enemy), "defeated tactical fixture registers combatants")
    var runtime := EnemyArchetypeRuntime.new()
    _expect(runtime.configure(encounter, enemy.actor_id, player.actor_id, &"duelist"), "defeated tactical runtime configures while actor is Active")
    _expect(runtime.is_tactical_eligible(), "Active enemy is tactical-state eligible")
    var fatal := encounter.resolve_direct_contact(player.actor_id, enemy.actor_id, 43001, 0, {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": 100.0,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 0.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(fatal.get("target_defeated", false)), "fixture resolves authoritative enemy defeat")
    _expect(not runtime.is_tactical_eligible(), "Defeated enemy immediately loses tactical eligibility")
    var selection := runtime.choose_tactic(_selector_context(), {})
    _expect(not bool(selection.get("accepted", false)) and selection.get("reason_id", &"") == &"tactical_ineligible", "Defeated enemy cannot select a new tactic")
    _expect(not runtime.request_non_attack_tactic({"accepted": true, "tactic_id": &"tactic:approach"}), "Defeated enemy cannot emit movement/tactical requests")


func _test_summoner_uses_live_full_ai_capacity() -> void:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:summoner_capacity"), "Summoner capacity fixture encounter configures")
    var player := _combatant(&"player:summoner_capacity")
    _expect(encounter.register_player(player), "Summoner capacity fixture player registers")
    var summoner := _combatant(&"enemy:summoner_capacity")
    _expect(encounter.register_enemy(summoner), "Summoner enters counted simulation")
    for index: int in range(11):
        var filler := _combatant(StringName("enemy:capacity_filler_%02d" % index))
        _expect(encounter.register_enemy(filler), "capacity filler %02d enters counted simulation" % index)
    _expect(encounter.full_ai.get_admitted_count() == FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS, "fixture reaches the shared FULL-AI hard cap")

    var runtime := EnemyArchetypeRuntime.new()
    _expect(runtime.configure(encounter, summoner.actor_id, player.actor_id, &"summoner"), "Summoner runtime configures at the cap")
    var context := _selector_context()
    context["distance_band"] = EnemyArchetypeDefinition.RANGE_LONG
    var selection: Dictionary = runtime.choose_tactic(
        context,
        {"reinforcement_budget_available": true, "full_ai_slot_available": true}
    )
    _expect(StringName(selection.get("tactic_id", &"")) == &"tactic:hold_observe", "Summoner cannot commit reinforcement call when the live FULL-AI ledger has no slot")
    _expect(StringName(selection.get("admission_reason_id", &"")) == EnemyArchetypeActionAdmission.REASON_FULL_AI_SLOT_REQUIRED, "Summoner rejection reports live FULL-AI capacity as the blocking fact")
    encounter.end_encounter()


func _expect_admission(archetype_id: StringName, facts: Dictionary, expected: bool, reason_id: StringName) -> void:
    var definition: EnemyArchetypeDefinition = EnemyArchetypeCatalog.get_definition(archetype_id)
    var result: Dictionary = EnemyArchetypeActionAdmission.validate_signature_commit(definition, facts)
    _expect(bool(result.get("accepted", false)) == expected, "%s admission expected=%s" % [String(archetype_id), str(expected)])
    _expect(StringName(result.get("reason_id", &"")) == reason_id, "%s admission reports %s" % [String(archetype_id), String(reason_id)])


func _selector_context() -> Dictionary:
    return {
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
    }


func _combatant(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, 40, 0.0, 0.0, 0.0, 20.0, true, false, false), "%s validates" % String(actor_id))
    return state


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
