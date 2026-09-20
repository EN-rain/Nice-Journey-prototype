extends SceneTree

var _failures := 0
var _delivery_windows: Array[Dictionary] = []

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_catalog()
    _test_full_phase_and_cooldown_cycle()
    _test_interruption_starts_cooldown()
    _test_defeat_clears_local_phase_clock()
    _test_target_defeat_invalidates_committed_action()
    if _failures == 0:
        print("ENEMY SIGNATURE ACTION PHASE DRIVER TEST PASS")
    else:
        push_error("ENEMY SIGNATURE ACTION PHASE DRIVER TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_catalog() -> void:
    _expect(EnemySignatureActionTimingCatalog.validate_catalog().is_empty(), "all twelve reusable archetypes have explicit reversible signature timing")
    for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        var timing := EnemySignatureActionTimingCatalog.get_timing(archetype_id)
        _expect(not timing.is_empty(), "%s exposes timing data" % String(archetype_id))
        _expect(int(timing.get("windup_ticks", 0)) > 0 and int(timing.get("active_ticks", 0)) > 0, "%s keeps readable windup/active timing" % String(archetype_id))

func _test_full_phase_and_cooldown_cycle() -> void:
    var fixture := _fixture(&"duelist", &"encounter:phase_driver", &"enemy:phase_duelist")
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var encounter := fixture["encounter"] as CombatEncounterRuntime
    var driver := EnemySignatureActionPhaseDriver.new()
    var timing := EnemySignatureActionTimingCatalog.get_timing(&"duelist")
    _expect(driver.configure(runtime, timing), "phase driver configures against a live archetype runtime")
    _delivery_windows.clear()
    driver.active_delivery_window_opened.connect(_on_active_delivery_window_opened)
    var selection := runtime.choose_tactic(_selector_context(), {})
    _expect(StringName(selection.get("tactic_id", &"")) == runtime.definition.signature_action_id, "fixture selects its signature action")
    var begin := driver.begin(selection, 51001, {})
    _expect(bool(begin.get("accepted", false)), "phase driver commits signature through authoritative reservation owner")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_WINDUP, "driver begins in windup")
    var premature_delivery := runtime.get_active_delivery_context(51001)
    _expect(not bool(premature_delivery.get("accepted", false)) and StringName(premature_delivery.get("reason_id", &"")) == EnemyArchetypeRuntime.REASON_INVALID_PHASE, "windup cannot expose an active delivery window")

    _advance(driver, int(timing["windup_ticks"]))
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_ACTIVE, "windup clock enters active phase exactly at authored boundary")
    _expect(_delivery_windows.size() == 1, "active phase opens exactly one authoritative delivery window")
    if not _delivery_windows.is_empty():
        var delivery := _delivery_windows[0]
        _expect(bool(delivery.get("accepted", false)), "active delivery window is admitted")
        _expect(StringName(delivery.get("actor_id", &"")) == runtime.actor_id and StringName(delivery.get("target_id", &"")) == runtime.target_id, "delivery window preserves committed actor and target identity")
        _expect(StringName(delivery.get("action_id", &"")) == runtime.definition.signature_action_id and int(delivery.get("action_instance_id", 0)) == 51001, "delivery window preserves signature action and action-instance identity")
        _expect(encounter.has_enemy_attack_ownership(runtime.actor_id, runtime.target_id, 51001, int(delivery.get("reservation_token", 0))), "delivery window is backed by live reservation and global pressure ownership")
    var live_delivery := runtime.get_active_delivery_context(51001)
    _expect(bool(live_delivery.get("accepted", false)), "runtime exposes active delivery context only during the ACTIVE phase")
    _advance(driver, int(timing["active_ticks"]))
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_RECOVERY, "active clock enters recovery exactly at authored boundary")
    _expect(not bool(runtime.get_active_delivery_context(51001).get("accepted", false)), "recovery closes the active delivery window")
    _advance(driver, int(timing["recovery_ticks"]))
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE, "recovery clock releases action reservation and returns to idle")
    _expect(not runtime.cooldown_ready, "completed action cannot immediately recommit before cooldown")
    _expect(encounter.reservations.get_active_count() == 0, "completed phase cycle leaks no attack reservation")

    var held := runtime.choose_tactic(_selector_context(), {})
    _expect(StringName(held.get("tactic_id", &"")) == &"tactic:hold_observe", "cooldown keeps selector on a noncommitting tactic")
    _advance(driver, int(timing["cooldown_ticks"]))
    _expect(runtime.cooldown_ready, "authored cooldown automatically reopens signature admission")
    encounter.end_encounter()

func _test_interruption_starts_cooldown() -> void:
    var fixture := _fixture(&"bruiser", &"encounter:phase_interrupt", &"enemy:phase_bruiser")
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var encounter := fixture["encounter"] as CombatEncounterRuntime
    var driver := EnemySignatureActionPhaseDriver.new()
    var timing := EnemySignatureActionTimingCatalog.get_timing(&"bruiser")
    _expect(driver.configure(runtime, timing), "interruption driver configures")
    var selection := runtime.choose_tactic(_selector_context(), {})
    _delivery_windows.clear()
    driver.active_delivery_window_opened.connect(_on_active_delivery_window_opened)
    _expect(bool(driver.begin(selection, 52001, {}).get("accepted", false)), "interrupt fixture commits signature")
    _advance(driver, 3)
    _expect(driver.cancel(AttackReservationLedger.RELEASE_INTERRUPTION), "driver interruption releases authoritative reservation")
    _expect(_delivery_windows.is_empty(), "interruption during windup cannot leak an ACTIVE delivery window")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE and not runtime.cooldown_ready, "interrupted action returns idle but still respects cooldown")
    _expect(driver.cooldown_ticks_remaining == int(timing["cooldown_ticks"]), "interrupted action receives the authored cooldown")
    _advance(driver, int(timing["cooldown_ticks"]))
    _expect(runtime.cooldown_ready, "interruption cooldown eventually reopens action")
    encounter.end_encounter()

func _test_defeat_clears_local_phase_clock() -> void:
    var fixture := _fixture(&"duelist", &"encounter:phase_defeat", &"enemy:phase_defeat")
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var encounter := fixture["encounter"] as CombatEncounterRuntime
    var player := fixture["player"] as CombatantRuntimeState
    var enemy := fixture["enemy"] as CombatantRuntimeState
    var driver := EnemySignatureActionPhaseDriver.new()
    _expect(driver.configure(runtime, EnemySignatureActionTimingCatalog.get_timing(&"duelist")), "defeat fixture phase driver configures")
    var selection := runtime.choose_tactic(_selector_context(), {})
    _expect(bool(driver.begin(selection, 53001, {}).get("accepted", false)), "defeat fixture commits a readable windup")
    _expect(encounter.reservations.get_active_count() == 1, "defeat fixture owns one live attack reservation")
    var fatal := encounter.resolve_direct_contact(player.actor_id, enemy.actor_id, 53002, 0, {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": 200.0,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 0.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(fatal.get("target_defeated", false)), "defeat fixture resolves authoritative enemy death mid-windup")
    _expect(encounter.reservations.get_active_count() == 0, "authoritative defeat releases the committed reservation immediately")
    _expect(driver.advance_fixed_tick(), "phase driver tolerates externally resolved actor without desync")
    var snapshot := driver.get_debug_snapshot()
    _expect(int(snapshot.get("action_instance_id", -1)) == 0 and int(snapshot.get("phase_ticks_remaining", -1)) == 0, "defeat clears local phase-clock identity instead of advancing a dead actor")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE and runtime.active_reservation_token == 0, "defeat reconciles runtime action identity after external reservation release")

func _test_target_defeat_invalidates_committed_action() -> void:
    var fixture := _fixture(&"duelist", &"encounter:phase_target_defeat", &"enemy:phase_target_defeat")
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var encounter := fixture["encounter"] as CombatEncounterRuntime
    var player := fixture["player"] as CombatantRuntimeState
    var enemy := fixture["enemy"] as CombatantRuntimeState
    var driver := EnemySignatureActionPhaseDriver.new()
    _expect(driver.configure(runtime, EnemySignatureActionTimingCatalog.get_timing(&"duelist")), "target-defeat fixture phase driver configures")
    var selection := runtime.choose_tactic(_selector_context(), {})
    _delivery_windows.clear()
    driver.active_delivery_window_opened.connect(_on_active_delivery_window_opened)
    _expect(bool(driver.begin(selection, 54001, {}).get("accepted", false)), "target-defeat fixture commits a readable windup")
    _expect(encounter.reservations.get_active_count() == 1, "target-defeat fixture owns one live reservation")
    var fatal := encounter.resolve_direct_contact(enemy.actor_id, player.actor_id, 54002, 0, {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": 200.0,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 0.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(fatal.get("target_defeated", false)), "authoritative contact defeats the committed action target")
    _expect(encounter.reservations.get_active_count() == 0 and encounter.attack_pressure.get_active_count() == 0, "target defeat releases reservation and global pressure ownership")
    _expect(not runtime.is_tactical_eligible(), "enemy loses tactical eligibility when its configured target is defeated")
    _expect(driver.advance_fixed_tick(), "phase driver reconciles target invalidation without advancing the obsolete action")
    _expect(_delivery_windows.is_empty(), "target invalidation during windup cannot leak an ACTIVE delivery window")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE and runtime.active_reservation_token == 0, "target invalidation clears stale runtime action ownership")
    _expect(not bool(runtime.choose_tactic(_selector_context(), {}).get("accepted", false)), "enemy cannot choose another tactic against a defeated target")
    _expect(encounter.reserve_enemy_attack(enemy.actor_id, player.actor_id, 54003) == 0, "encounter rejects new attack reservations against defeated targets")

func _fixture(archetype_id: StringName, encounter_id: StringName, enemy_id: StringName) -> Dictionary:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(encounter_id), "fixture encounter configures")
    var player := _combatant(&"player:phase_driver")
    var enemy := _combatant(enemy_id)
    _expect(encounter.register_player(player), "fixture player registers")
    _expect(encounter.register_enemy(enemy), "fixture enemy registers")
    var runtime := EnemyArchetypeRuntime.new()
    _expect(runtime.configure(encounter, enemy.actor_id, player.actor_id, archetype_id), "fixture archetype runtime configures")
    return {"encounter": encounter, "runtime": runtime, "player": player, "enemy": enemy}

func _combatant(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, 100, 100.0, 0.0, 0.0, 20.0, true, false, false), "%s combatant validates" % String(actor_id))
    return state

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

func _advance(driver: EnemySignatureActionPhaseDriver, ticks: int) -> void:
    for _index: int in range(ticks):
        _expect(driver.advance_fixed_tick(), "phase/cooldown tick advances")

func _on_active_delivery_window_opened(context: Dictionary) -> void:
    _delivery_windows.append(context.duplicate(true))

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
