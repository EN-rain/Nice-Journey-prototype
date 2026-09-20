extends SceneTree

const DEFAULT_TUNING: TenthWardenEncounterTuning = preload("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_encounter_default.tres")

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:tenth_warden_fixture"), "boss fixture configures the genuine encounter runtime")
    var player := _combatant(&"player:tenth_warden_fixture", 100, 30.0, true, true)
    var boss := _combatant(&"enemy:tenth_warden", 60, 0.0, false, false)
    _expect(encounter.register_player(player), "boss fixture registers player combatant")
    _expect(encounter.register_enemy(boss), "Tenth Warden registers through the normal enemy runtime path")
    _expect(encounter.full_ai.is_admitted_to_encounter(boss.actor_id, encounter.encounter_id), "Tenth Warden counts as one FULL-AI combatant")

    var runtime := TenthWardenCombatRuntime.new()
    _expect(runtime.configure(encounter, player.actor_id, boss.actor_id, DEFAULT_TUNING), "boss runtime composes the existing encounter owner and approved state machine")
    _expect(runtime.evaluate_live_outcome() == TenthWardenEncounterState.OUTCOME_ONGOING, "live boss outcome starts ongoing")

    _expect(not runtime.begin_move(TenthWardenEncounterState.MOVE_PUNISHING_STEP, 1001, false), "Punishing Step cannot reserve an attack when its authored positioning condition is false")
    _expect(encounter.reservations.get_active_count() == 0, "rejected Punishing Step does not leak a reservation")

    _expect(runtime.begin_move(TenthWardenEncounterState.MOVE_ARC_VOLLEY, 1002), "Arc Volley begins only after normal attack-participation admission")
    _expect(encounter.reservations.get_active_count() == 1, "active boss move owns exactly one attack reservation")
    var invalid_arc := _attack(10.0, DirectHitResolver.DELIVERY_PROJECTILE, true, true, true)
    var invalid_result := runtime.resolve_boss_contact(1002, 0, invalid_arc, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(not invalid_result["accepted"] and invalid_result["reason_id"] == TenthWardenCombatRuntime.REASON_INVALID_MOVE_PAYLOAD, "Arc Volley rejects a parryable projectile payload before contact admission")
    _expect(not encounter.contacts.has_contact(1002, player.actor_id, 0), "invalid boss payload cannot poison the shared contact ledger")

    var arc := _attack(10.0, DirectHitResolver.DELIVERY_PROJECTILE, true, true, false)
    var arc_result := runtime.resolve_boss_contact(1002, 0, arc, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(arc_result["accepted"] and player.current_hp == 90, "valid Arc Volley uses the shared DR-06 resolver and authoritative player HP")
    _expect(runtime.begin_recovery(false), "Arc Volley enters normal recovery")
    var recovery_contact := runtime.resolve_boss_contact(1002, 1, arc, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(not recovery_contact["accepted"] and recovery_contact["reason_id"] == TenthWardenCombatRuntime.REASON_RECOVERY_ACTIVE, "boss recovery closes contact delivery before reservation release")
    _expect(runtime.finish_recovery(), "Arc Volley recovery releases its attack reservation")
    _expect(encounter.reservations.get_active_count() == 0, "completed boss move leaves no reservation")

    _expect(runtime.begin_move(TenthWardenEncounterState.MOVE_WARDEN_LUNGE, 1005), "parry fixture Warden Lunge begins through normal ownership")
    var parry_melee := _attack(5.0, DirectHitResolver.DELIVERY_CONTACT, true, true, true)
    var parried := runtime.resolve_boss_contact(1005, 0, parry_melee, false, DirectHitResolver.DEFENSE_PARRY, true)
    _expect(parried["accepted"] and parried["outcome"] == DirectHitResolver.OUTCOME_PARRIED, "supported player parry negates a parryable boss contact")
    _expect(runtime.state.recovery_active, "successful boss parry interruption enters the existing recovery state")
    var post_parry_contact := runtime.resolve_boss_contact(1005, 1, parry_melee, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(not post_parry_contact["accepted"] and post_parry_contact["reason_id"] == TenthWardenCombatRuntime.REASON_RECOVERY_ACTIVE, "parried boss cannot deliver another contact during recovery")
    _expect(runtime.finish_recovery(), "parry recovery releases boss attack ownership")

    _expect(runtime.begin_move(TenthWardenEncounterState.MOVE_TWIN_CUT, 1003), "Twin Cut begins through the same reservation path")
    var melee := _attack(5.0, DirectHitResolver.DELIVERY_CONTACT, true, true, true)
    _expect(runtime.resolve_boss_contact(1003, 0, melee, false, DirectHitResolver.DEFENSE_NONE, false)["accepted"], "Twin Cut first hit interval resolves")
    _expect(runtime.resolve_boss_contact(1003, 1, melee, false, DirectHitResolver.DEFENSE_NONE, false)["accepted"], "Twin Cut second hit interval resolves")
    var third_hit := runtime.resolve_boss_contact(1003, 2, melee, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(not third_hit["accepted"] and third_hit["reason_id"] == TenthWardenCombatRuntime.REASON_INVALID_MOVE_PAYLOAD, "Twin Cut cannot invent a third hit interval")
    _expect(runtime.begin_recovery(false) and runtime.finish_recovery(), "Twin Cut completes and releases ownership")

    var player_attack := _attack(30.0, DirectHitResolver.DELIVERY_CONTACT, true, true, true)
    var player_hit := runtime.resolve_player_contact(2001, 0, player_attack)
    _expect(player_hit["accepted"] and boss.current_hp == 30, "player damage mutates the same boss combatant registered in the encounter runtime")
    _expect(runtime.state.transition_action_requested, "crossing the approved 50 percent threshold while idle requests the irreversible phase transition")
    _expect(runtime.commit_phase_transition(), "phase transition commits explicitly through the boss state owner")
    _expect(runtime.state.phase == TenthWardenEncounterState.PHASE_TWO, "boss runtime enters phase two without healing or resetting encounter state")
    _expect(boss.current_hp == 30, "phase transition preserves live boss HP")

    _expect(runtime.begin_move(TenthWardenEncounterState.MOVE_WARDEN_LUNGE, 1004), "phase-two Warden Lunge begins from the learned move family")
    _expect(runtime.begin_recovery(true), "phase-two heavy move enters authored recovery")
    _expect(runtime.state.weak_point_exposed, "phase-two heavy recovery exposes the DR-06 weak point")
    _expect(runtime.finish_recovery(), "phase-two heavy recovery completes")
    _expect(not runtime.state.weak_point_exposed, "weak point closes when recovery ends")

    var simultaneous := CombatEncounterRuntime.new()
    _expect(simultaneous.configure(&"encounter:tenth_warden_tie_fixture"), "tie fixture configures")
    var tie_player := _combatant(&"player:tenth_warden_tie", 10, 0.0, false, false)
    var tie_boss := _combatant(&"enemy:tenth_warden_tie", 10, 0.0, false, false)
    _expect(simultaneous.register_player(tie_player) and simultaneous.register_enemy(tie_boss), "tie fixture registers both actors")
    var tie_runtime := TenthWardenCombatRuntime.new()
    _expect(tie_runtime.configure(simultaneous, tie_player.actor_id, tie_boss.actor_id, DEFAULT_TUNING), "tie runtime configures")
    _expect(tie_player.apply_direct_hit_result(_damage_result(10)) and tie_boss.apply_direct_hit_result(_damage_result(10)), "tie fixture reaches authoritative simultaneous defeat state")
    _expect(tie_runtime.evaluate_live_outcome() == TenthWardenEncounterState.OUTCOME_FAILED_ATTEMPT, "simultaneous player/boss defeat remains a failed attempt with no victory claim")

    runtime.end_encounter()
    _expect(encounter.full_ai.get_admitted_count() == 0 and not encounter.active_combat.is_active(), "boss encounter exit releases normal combat ownership")

    var source := FileAccess.get_file_as_string("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_combat_runtime.gd")
    _expect(not source.contains("rand") and not source.contains("spawn_add") and not source.contains("grant_reward"), "boss runtime does not invent RNG selection, adds, or reward commitment")
    _expect(not source.contains("res://assets/art"), "boss runtime contains no presentation asset paths")

    if _failures == 0:
        print("TENTH WARDEN COMBAT RUNTIME INTEGRATION TEST PASS")
    else:
        push_error("TENTH WARDEN COMBAT RUNTIME INTEGRATION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _combatant(actor_id: StringName, hp: int, stamina: float, block_supported: bool, parry_supported: bool) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, hp, stamina, 0.0, 0.0, 30.0, true, block_supported, parry_supported), "%s combatant validates" % String(actor_id))
    return state

func _attack(raw_damage: float, delivery: StringName, dodgeable: bool, blockable: bool, parryable: bool) -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": delivery,
        "raw_damage": raw_damage,
        "dodgeable": dodgeable,
        "blockable": blockable,
        "parryable": parryable,
        "guard_pressure": 5.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }

func _damage_result(amount: int) -> Dictionary:
    return {
        "accepted": true,
        "outcome": DirectHitResolver.OUTCOME_HIT,
        "hp_damage": amount,
    }

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
