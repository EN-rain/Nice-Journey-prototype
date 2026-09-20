extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_locked_reapplication_semantics()
    _test_strict_production_application_rejects_incomplete_authority()
    _test_strict_execution_never_interprets_opaque_magnitude()
    _test_supported_snapshot_duration_round_trip()

    if _failures == 0:
        print("STATUS PRODUCTION EXECUTION TEST PASS")
    else:
        push_error("STATUS PRODUCTION EXECUTION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_locked_reapplication_semantics() -> void:
    var first := PrototypeStatusResolver.apply_status([], _application(&"burn:prod_contract", PrototypeStatusResolver.BEHAVIOR_BURN, 2.0, 60))
    _expect(bool(first.get("accepted", false)), "generic status foundation accepts a structurally valid Burn state")

    var stronger_shorter := PrototypeStatusResolver.apply_status(
        first.get("states", []),
        _application(&"burn:prod_contract", PrototypeStatusResolver.BEHAVIOR_BURN, 4.0, 30)
    )
    var merged := (stronger_shorter.get("states", []) as Array)[0] as Dictionary
    _expect(
        is_equal_approx(float(merged.get("magnitude", 0.0)), 4.0)
        and int(merged.get("remaining_ticks", 0)) == 60,
        "same-ID Burn reapplication keeps strongest magnitude without shortening remaining duration"
    )

    var weaker_longer := PrototypeStatusResolver.apply_status(
        stronger_shorter.get("states", []),
        _application(&"burn:prod_contract", PrototypeStatusResolver.BEHAVIOR_BURN, 1.0, 90)
    )
    merged = (weaker_longer.get("states", []) as Array)[0] as Dictionary
    _expect(
        is_equal_approx(float(merged.get("magnitude", 0.0)), 4.0)
        and int(merged.get("remaining_ticks", 0)) == 90,
        "same-ID Burn reapplication keeps strongest magnitude and greatest current/new duration"
    )

    var coexisting := PrototypeStatusResolver.apply_status(
        weaker_longer.get("states", []),
        _application(&"burn:second_source", PrototypeStatusResolver.BEHAVIOR_BURN, 3.0, 45)
    )
    _expect((coexisting.get("states", []) as Array).size() == 2, "different stable status IDs may coexist without hidden same-ID stacking")


func _test_strict_production_application_rejects_incomplete_authority() -> void:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:status_production_gate"), "production status fixture configures")
    var target := _combatant(&"player:status_production_gate")
    _expect(encounter.register_player(target), "production status fixture registers target")

    var before := encounter.get_status_states(target.actor_id)
    var burn := encounter.apply_production_status_to_target(
        target.actor_id,
        _application(&"burn:production_gate", PrototypeStatusResolver.BEHAVIOR_BURN, 3.0, 60)
    )
    _expect(
        not bool(burn.get("accepted", true))
        and StringName(burn.get("reason_id", &"")) == PrototypeStatusResolver.REASON_PRODUCTION_AUTHORITY_INCOMPLETE,
        "production Burn application is rejected while cadence/damage authority is incomplete"
    )
    var burn_missing := burn.get("production_missing_fields", PackedStringArray()) as PackedStringArray
    _expect(
        burn_missing.has("tick_interval_ticks")
        and burn_missing.has("first_tick_timing")
        and burn_missing.has("damage_per_tick")
        and burn_missing.has("damage_domain")
        and burn_missing.has("mitigation_or_defense_interaction"),
        "Burn production rejection reports exact unresolved cadence/damage/domain/mitigation fields"
    )
    _expect(encounter.get_status_states(target.actor_id) == before, "rejected production Burn application is non-mutating")

    var slow := encounter.apply_production_status_to_target(
        target.actor_id,
        _application(&"slow:production_gate", PrototypeStatusResolver.BEHAVIOR_SLOW, 0.2, 90)
    )
    _expect(
        not bool(slow.get("accepted", true))
        and StringName(slow.get("reason_id", &"")) == PrototypeStatusResolver.REASON_PRODUCTION_AUTHORITY_INCOMPLETE,
        "production Slow application is rejected while magnitude/domain/clamp authority is incomplete"
    )
    var slow_missing := slow.get("production_missing_fields", PackedStringArray()) as PackedStringArray
    _expect(
        slow_missing.has("magnitude_semantics_percent_or_multiplier")
        and slow_missing.has("affected_movement_domains")
        and slow_missing.has("cross_status_id_aggregation_policy")
        and slow_missing.has("minimum_or_maximum_speed_clamp_policy"),
        "Slow production rejection reports exact unresolved magnitude/movement/aggregation/clamp fields"
    )
    var slow_semantics := slow.get("production_known_semantics", {}) as Dictionary
    _expect(
        bool(slow_semantics.get("movement_speed_reduction_only", false))
        and not bool(slow_semantics.get("affects_action_clocks", true))
        and not bool(slow_semantics.get("affects_ai_reaction_timing", true)),
        "Slow production authority preserves movement-only behavior without changing action or AI clocks"
    )


func _test_strict_execution_never_interprets_opaque_magnitude() -> void:
    var state := _combatant(&"player:status_execution_gate")
    _expect(bool(state.apply_status(_application(&"burn:execution_gate", PrototypeStatusResolver.BEHAVIOR_BURN, 7.5, 45)).get("accepted", false)), "fixture seeds generic Burn state")
    _expect(bool(state.apply_status(_application(&"slow:execution_gate", PrototypeStatusResolver.BEHAVIOR_SLOW, 0.37, 60)).get("accepted", false)), "fixture seeds generic Slow state")

    var generic := state.get_status_execution_requests()
    _expect(bool(generic.get("accepted", false)) and (generic.get("requests", []) as Array).size() == 2, "generic boundary can expose opaque status values for presentation/testing")

    var production := state.get_production_status_execution_requests()
    _expect(
        not bool(production.get("accepted", true))
        and StringName(production.get("reason_id", &"")) == PrototypeStatusResolver.REASON_PRODUCTION_AUTHORITY_INCOMPLETE,
        "strict production execution refuses to execute statuses with unresolved effect semantics"
    )
    _expect((production.get("requests", []) as Array).is_empty(), "strict production status execution emits no executable request when any authority is incomplete")
    var unresolved := production.get("unresolved_statuses", []) as Array
    _expect(unresolved.size() == 2, "strict production status execution identifies each unresolved active status")
    for raw_entry: Variant in unresolved:
        var entry := raw_entry as Dictionary
        var known := entry.get("known_semantics", {}) as Dictionary
        var behavior := StringName(entry.get("behavior", &""))
        if behavior == PrototypeStatusResolver.BEHAVIOR_BURN:
            _expect(
                not bool(known.get("can_crit", true))
                and not bool(known.get("can_weak_point", true)),
                "Burn execution authority preserves the DR-06 no-crit/no-weak-point rule"
            )
        elif behavior == PrototypeStatusResolver.BEHAVIOR_SLOW:
            _expect(
                not bool(known.get("affects_action_clocks", true))
                and not bool(known.get("affects_ai_reaction_timing", true)),
                "Slow execution authority preserves action-clock and AI-reaction independence"
            )


func _test_supported_snapshot_duration_round_trip() -> void:
    var original := _combatant(&"player:status_snapshot_source")
    _expect(bool(original.apply_status(_application(&"burn:snapshot", PrototypeStatusResolver.BEHAVIOR_BURN, 2.0, 30)).get("accepted", false)), "snapshot fixture seeds Burn duration")
    _expect(bool(original.apply_status(_application(&"slow:snapshot", PrototypeStatusResolver.BEHAVIOR_SLOW, 0.2, 45)).get("accepted", false)), "snapshot fixture seeds Slow duration")
    var snapshot := original.get_status_states()

    var restored := _combatant(&"player:status_snapshot_restored")
    var restore_result := restored.restore_status_states(snapshot)
    _expect(bool(restore_result.get("accepted", false)) and restored.get_status_states() == snapshot, "supported status durations round-trip through the existing snapshot representation")

    var burn_authority := PrototypeStatusProductionAuthority.readiness(PrototypeStatusResolver.BEHAVIOR_BURN)
    var slow_authority := PrototypeStatusProductionAuthority.readiness(PrototypeStatusResolver.BEHAVIOR_SLOW)
    _expect(
        bool((burn_authority.get("known_semantics", {}) as Dictionary).get("safe_snapshot_duration_supported", false))
        and bool((slow_authority.get("known_semantics", {}) as Dictionary).get("safe_snapshot_duration_supported", false)),
        "Burn and Slow authority explicitly recognizes supported safe-snapshot duration persistence"
    )
    _expect(
        (burn_authority.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray).has("encounter_handoff_policy")
        and (slow_authority.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray).has("encounter_handoff_policy"),
        "snapshot duration support does not invent an encounter-handoff policy"
    )


func _application(status_id: StringName, behavior: StringName, magnitude: float, duration_ticks: int) -> Dictionary:
    return {
        "status_id": status_id,
        "behavior": behavior,
        "magnitude": magnitude,
        "duration_ticks": duration_ticks,
    }


func _combatant(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(
        state.configure(actor_id, 100, 100.0, 0.0, 0.0, 50.0, true, false, false),
        "%s combatant fixture validates" % String(actor_id)
    )
    return state


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
