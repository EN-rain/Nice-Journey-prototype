extends SceneTree

const SANCTUM_SCENE: PackedScene = preload("res://src/world/tower/boss/tenth_warden_sanctum.tscn")

var _failures := 0
var _delivery_contexts: Array[Dictionary] = []
var _terminal_outcomes: Array[StringName] = []


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var sanctum := SANCTUM_SCENE.instantiate() as TenthWardenSanctum
    root.add_child(sanctum)
    await process_frame
    sanctum.set_physics_process(false)
    sanctum.boss_active_delivery_window_opened.connect(_on_delivery_window)
    sanctum.terminal_outcome_committed.connect(_on_terminal_outcome)

    var authoring := _complete_authoring_fixture()
    _expect(authoring.validate_authoring().is_empty(), "autonomous fixture provides complete explicit production authoring")

    var player := _combatant(&"player:tenth_warden_autonomous", 100)
    var shared_active := ActiveCombatRegistry.new()
    var shared_full_ai := FullAiSimulationLedger.new()
    var shared_pressure := AttackPressureLedger.new()

    _expect(
        sanctum.prepare_production_encounter(player, authoring, shared_active, shared_full_ai, shared_pressure),
        "Boss Sanctum creates the authored boss combatant plus autonomous runtime from complete production data"
    )
    _expect(sanctum.autonomous_runtime != null and sanctum.boss_runtime != null, "production preparation owns both low-level combat and autonomous lifecycle runtimes")
    var boss: CombatantRuntimeState = sanctum.encounter_runtime.get_combatant(Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID)
    _expect(boss != null and boss.max_hp == authoring.max_hp and boss.current_hp == authoring.max_hp, "production preparation constructs boss HP only from authoring")
    _expect(shared_full_ai.get_admitted_count() == 1 and shared_active.is_active(), "production preparation reuses shared FULL-AI and active-combat ownership")

    sanctum.set_punishing_step_positioning_condition(false)
    _expect(sanctum.autonomous_runtime.advance_fixed_tick(false), "autonomous lifecycle selects the first legal authored move")
    _expect(sanctum.boss_runtime.state.active_move_id == TenthWardenEncounterState.MOVE_TWIN_CUT, "Punishing Step is skipped while its external authored positioning condition is false")
    _expect(sanctum.autonomous_runtime.advance_fixed_tick(false), "authored startup reaches commit")
    _expect(sanctum.autonomous_runtime.advance_fixed_tick(false), "authored commit reaches active delivery")
    _expect(_delivery_contexts.size() == 1, "active window emits one geometry delivery request")
    var first_context: Dictionary = _delivery_contexts[0]
    _expect(first_context.get("action_id", &"") == TenthWardenEncounterState.MOVE_TWIN_CUT, "delivery request identifies the selected authored move")
    _expect(first_context.get("query_shape", null) != null and float(first_context.get("max_reach_px", 0.0)) > 0.0, "delivery request exposes authored geometry without deriving values from presentation")

    var mismatch_facts := _contact_facts(first_context, 0)
    mismatch_facts["geometry_id"] = &"geometry:wrong"
    var mismatch := sanctum.resolve_confirmed_boss_contact(
        mismatch_facts,
        false,
        DirectHitResolver.DEFENSE_NONE,
        false
    )
    _expect(not bool(mismatch.get("accepted", false)) and mismatch.get("reason_id", &"") == TenthWardenEncounterController.REASON_GEOMETRY_MISMATCH, "authored contact rejects mismatched geometry identity before shared DR-06 resolution")

    var hit := sanctum.resolve_confirmed_boss_contact(
        _contact_facts(first_context, 0),
        false,
        DirectHitResolver.DEFENSE_NONE,
        false
    )
    _expect(bool(hit.get("accepted", false)) and player.current_hp == 93, "confirmed authored contact uses the shared encounter resolver and authored payload")

    _expect(sanctum.autonomous_runtime.advance_fixed_tick(false), "active move enters authored recovery")
    _expect(sanctum.boss_runtime.state.recovery_active, "recovery state opens from ActionDefinition timing")
    var player_attack := _player_attack(50.0)
    var threshold_hit := sanctum.boss_runtime.resolve_player_contact(9101, 0, player_attack)
    _expect(bool(threshold_hit.get("accepted", false)) and boss.current_hp == 50, "player damage reaches the exact 50 percent transition threshold through shared combat")
    _expect(sanctum.boss_runtime.state.transition_pending and not sanctum.boss_runtime.state.transition_action_requested, "phase transition waits for the committed move recovery to finish")

    _expect(sanctum.autonomous_runtime.advance_fixed_tick(false), "authored recovery continues")
    _expect(sanctum.autonomous_runtime.advance_fixed_tick(false), "recovery completion starts the explicit non-damaging transition action")
    _expect(sanctum.boss_runtime.state.transition_action_requested and sanctum.boss_runtime.state.phase == TenthWardenEncounterState.PHASE_ONE, "transition remains an explicit action before phase commit")

    for _tick: int in range(4):
        _expect(sanctum.autonomous_runtime.advance_fixed_tick(false), "phase transition action advances from authored timing")
    _expect(sanctum.boss_runtime.state.phase == TenthWardenEncounterState.PHASE_TWO, "authored transition completes irreversibly into phase two")
    _expect(boss.current_hp == 50, "phase transition does not heal or reset boss HP")
    _expect(sanctum.boss_runtime.state.active_move_id == TenthWardenEncounterState.MOVE_WARDEN_LUNGE, "phase two immediately resumes the authored cadence using the same learned move families")

    _expect(sanctum.autonomous_runtime.advance_fixed_tick(false), "phase-two startup reaches commit")
    _expect(sanctum.autonomous_runtime.advance_fixed_tick(false), "phase-two commit reaches active")
    _expect(sanctum.autonomous_runtime.advance_fixed_tick(false), "phase-two heavy action enters recovery")
    _expect(sanctum.boss_runtime.state.recovery_active and sanctum.boss_runtime.state.weak_point_exposed, "declared Phase-2 heavy recovery exposes the approved weak point window")
    _expect(sanctum.get_exposed_weak_point_position().is_finite() and sanctum.boss_visual.weak_point_marker.visible, "heavy recovery exposes a separate visible authored weak-point target")

    var final_hit := sanctum.boss_runtime.resolve_player_contact(9102, 0, _player_attack(50.0))
    _expect(bool(final_hit.get("accepted", false)) and boss.is_defeated(), "boss terminal defeat still resolves through the shared damage model")
    _expect(sanctum.autonomous_runtime.advance_fixed_tick(false), "autonomous lifecycle observes terminal outcome and cancels remaining attack ownership")
    _expect(sanctum.encounter_runtime.reservations.get_active_count() == 0, "terminal cleanup leaves no boss attack reservation")
    _expect(sanctum.commit_terminal_outcome(), "Sanctum commits the observed authoritative terminal outcome")
    _expect(not sanctum.get_exposed_weak_point_position().is_finite() and not sanctum.boss_visual.weak_point_marker.visible, "encounter teardown closes the weak-point target and hides its placeholder marker")
    _expect(_terminal_outcomes == [TenthWardenEncounterState.OUTCOME_VICTORY], "valid boss defeat emits exactly one victory event")
    _expect(not shared_active.is_active() and shared_full_ai.get_admitted_count() == 0, "terminal commit releases shared encounter ownership")

    _expect(sanctum.reset_for_retry(), "retry reset is cleanup-only and does not mutate an old combatant back to full health")
    var retry_player := _combatant(&"player:tenth_warden_retry", 100)
    _expect(sanctum.prepare_production_encounter(retry_player, authoring, shared_active, shared_full_ai, shared_pressure), "retry starts only by preparing a fresh authored encounter")
    var retry_boss: CombatantRuntimeState = sanctum.encounter_runtime.get_combatant(Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID)
    _expect(retry_boss != null and retry_boss != boss and retry_boss.current_hp == authoring.max_hp, "retry receives a fresh boss combatant from production authoring instead of healing the prior defeated state")
    _expect(sanctum.committed_terminal_outcome == TenthWardenEncounterState.OUTCOME_ONGOING, "retry clears only the Sanctum attempt outcome boundary")
    _expect(sanctum.reset_for_retry(), "retry teardown releases the second encounter cleanly")
    _expect(not shared_active.is_active() and shared_full_ai.get_admitted_count() == 0, "retry teardown leaves no shared combat/FULL-AI ownership")

    var controller_source := FileAccess.get_file_as_string("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_encounter_controller.gd")
    _expect(not controller_source.contains("rand") and not controller_source.contains("spawn_add") and not controller_source.contains("grant_reward"), "autonomous controller contains no random replacement mechanics, adds, or reward grants")
    _expect(not controller_source.contains("res://assets/art"), "autonomous controller derives no combat timing or geometry from presentation assets")

    sanctum.queue_free()
    await process_frame

    if _failures == 0:
        print("TENTH WARDEN AUTONOMOUS LIFECYCLE TEST PASS")
    else:
        push_error("TENTH WARDEN AUTONOMOUS LIFECYCLE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _complete_authoring_fixture() -> TenthWardenProductionAuthoring:
    var result := TenthWardenProductionAuthoring.new()
    result.authored = true
    result.max_hp = 100
    result.stamina = 20.0
    result.physical_defense = 0.0
    result.arcane_defense = 0.0
    result.poise_threshold = 10.0
    result.interruptible_declared = true
    result.interruptible = true
    result.block_supported_declared = true
    result.block_supported = false
    result.parry_supported_declared = true
    result.parry_supported = false

    for move_id: StringName in TenthWardenEncounterState.MOVE_IDS:
        result.move_actions.append(_action(move_id, 1, 1, 1, 2))
        result.phase_two_move_actions.append(_action(move_id, 1, 1, 1, 1))

        var geometry := EnemyAttackGeometryAuthoring.new()
        geometry.authored = true
        geometry.geometry_id = StringName("geometry:test_autonomous:%s" % String(move_id))
        geometry.query_shape = RectangleShape2D.new()
        geometry.max_reach_px = 32.0
        geometry.collision_mask = 1
        geometry.hit_interval_count = 2 if move_id == TenthWardenEncounterState.MOVE_TWIN_CUT else 1
        geometry.live_placement_declared = true
        geometry.local_offset = Vector2.ZERO
        geometry.local_rotation_radians = 0.0
        geometry.hit_active_ticks = PackedInt32Array([0, 0]) if move_id == TenthWardenEncounterState.MOVE_TWIN_CUT else PackedInt32Array([0])

        var payload := EnemyAttackPayloadAuthoring.new()
        payload.authored = true
        payload.damage_domain = DirectHitResolver.DOMAIN_PHYSICAL
        payload.delivery = DirectHitResolver.DELIVERY_PROJECTILE if move_id == TenthWardenEncounterState.MOVE_ARC_VOLLEY else DirectHitResolver.DELIVERY_CONTACT
        payload.raw_damage = 7.0
        payload.guard_pressure = 0.0
        payload.dodgeable = true
        payload.blockable = move_id != TenthWardenEncounterState.MOVE_CRESCENT_SWEEP
        payload.parryable = move_id != TenthWardenEncounterState.MOVE_ARC_VOLLEY
        payload.critical_multiplier = 1.0
        payload.weak_point_multiplier = 1.0

        var attack := EnemySignatureAttackAuthoring.new()
        attack.action_id = move_id
        attack.geometry = geometry
        attack.payload = payload
        result.move_attacks.append(attack)

    result.phase_transition_action = _action(TenthWardenEncounterState.ACTION_PHASE_TRANSITION, 1, 1, 1, 1)
    result.phase_one_move_order = [
        TenthWardenEncounterState.MOVE_PUNISHING_STEP,
        TenthWardenEncounterState.MOVE_TWIN_CUT,
        TenthWardenEncounterState.MOVE_WARDEN_LUNGE,
        TenthWardenEncounterState.MOVE_ARC_VOLLEY,
        TenthWardenEncounterState.MOVE_CRESCENT_SWEEP,
    ]
    result.phase_two_move_order = [
        TenthWardenEncounterState.MOVE_WARDEN_LUNGE,
        TenthWardenEncounterState.MOVE_TWIN_CUT,
        TenthWardenEncounterState.MOVE_ARC_VOLLEY,
        TenthWardenEncounterState.MOVE_CRESCENT_SWEEP,
        TenthWardenEncounterState.MOVE_PUNISHING_STEP,
    ]
    result.phase_two_heavy_move_ids = [TenthWardenEncounterState.MOVE_WARDEN_LUNGE]
    return result


func _action(action_id: StringName, startup: int, commit: int, active: int, recovery: int) -> ActionDefinition:
    var result := ActionDefinition.new()
    result.action_id = action_id
    result.startup_ticks = startup
    result.commit_ticks = commit
    result.active_ticks = active
    result.recovery_ticks = recovery
    result.cooldown_ticks = 0
    return result


func _combatant(actor_id: StringName, hp: int) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, hp, 20.0, 0.0, 0.0, 10.0, true, true, true), "%s combatant validates" % String(actor_id))
    return state


func _contact_facts(context: Dictionary, hit_interval_index: int) -> Dictionary:
    return {
        "actor_id": context.get("actor_id", &""),
        "target_id": context.get("target_id", &""),
        "action_id": context.get("action_id", &""),
        "action_instance_id": int(context.get("action_instance_id", 0)),
        "hit_interval_index": hit_interval_index,
        "geometry_id": context.get("geometry_id", &""),
        "contact_confirmed": true,
        "critical_triggered": false,
        "weak_point_triggered": false,
    }


func _player_attack(raw_damage: float) -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": raw_damage,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 0.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }


func _on_delivery_window(context: Dictionary) -> void:
    _delivery_contexts.append(context.duplicate(true))


func _on_terminal_outcome(outcome_id: StringName) -> void:
    _terminal_outcomes.append(outcome_id)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
