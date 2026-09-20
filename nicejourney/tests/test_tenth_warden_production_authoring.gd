extends SceneTree

const PRODUCTION_AUTHORING_SCRIPT: Script = preload("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_production_authoring.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var missing: TenthWardenProductionAuthoring = PRODUCTION_AUTHORING_SCRIPT.new() as TenthWardenProductionAuthoring
    var missing_errors: PackedStringArray = missing.validate_authoring()
    _expect(not missing_errors.is_empty(), "production boss authoring fails closed until explicitly enabled")
    _expect(missing.build_boss_state() == null, "unconfigured production boss data cannot create a live combatant")

    var authored: TenthWardenProductionAuthoring = _complete_fixture()
    var errors: PackedStringArray = authored.validate_authoring()
    _expect(errors.is_empty(), "complete caller-authored boss stats/timing/payload/geometry validate: %s" % str(errors))
    var state: CombatantRuntimeState = authored.build_boss_state()
    _expect(state != null and state.actor_id == Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID, "valid production authoring constructs the canonical Tenth Warden combatant identity")
    _expect(state != null and state.max_hp == 900 and is_equal_approx(state.poise_threshold, 45.0), "boss state uses only explicit caller-authored combatant values")
    for move_id: StringName in TenthWardenEncounterState.MOVE_IDS:
        _expect(authored.action_for_move(move_id, TenthWardenEncounterState.PHASE_ONE) != null, "approved move %s has explicit phase-one action timing" % String(move_id))
        _expect(authored.action_for_move(move_id, TenthWardenEncounterState.PHASE_TWO) != null, "approved move %s has explicit phase-two action timing" % String(move_id))
        _expect(authored.attack_for_move(move_id) != null, "approved move %s has explicit attack geometry/payload" % String(move_id))
    _expect(authored.phase_transition_action != null, "irreversible phase transition has explicit ActionDefinition timing")
    _expect(authored.phase_one_move_order.size() >= 5 and authored.phase_two_move_order.size() >= 5, "both phases have explicit deterministic authored cadence")
    _expect(authored.is_phase_two_heavy_move(TenthWardenEncounterState.MOVE_WARDEN_LUNGE), "Phase-2 heavy recovery declaration is explicit")

    var broken: TenthWardenProductionAuthoring = _complete_fixture()
    broken.attack_for_move(TenthWardenEncounterState.MOVE_ARC_VOLLEY).payload.parryable = true
    _expect(not broken.validate_authoring().is_empty(), "Arc Volley production authoring rejects parryable projectiles")

    var missing_move: TenthWardenProductionAuthoring = _complete_fixture()
    missing_move.move_actions.pop_back()
    _expect(not missing_move.validate_authoring().is_empty(), "production authoring rejects any missing approved boss move")

    var unaffordable := _complete_fixture()
    unaffordable.move_actions[0].cost_resource = TenthWardenProductionAuthoring.STAMINA_RESOURCE_ID
    unaffordable.move_actions[0].cost_amount = unaffordable.stamina + 1.0
    _expect(not unaffordable.validate_authoring().is_empty(), "boss rejects move costs above its maximum spendable stamina")
    var exhausted := _complete_fixture()
    exhausted.move_actions[0].cost_resource = TenthWardenProductionAuthoring.STAMINA_RESOURCE_ID
    exhausted.move_actions[0].cost_amount = 1.0
    _expect(not exhausted.validate_authoring().is_empty(), "spending without stamina replenishment cannot leave the boss permanently action-starved")
    exhausted.stamina_recovery_per_tick = 0.5
    _expect(exhausted.validate_authoring().is_empty(), "Inspector-authored stamina recovery makes the same spendable move valid")

    var blocked_transition := _complete_fixture()
    blocked_transition.phase_transition_action.cost_resource = TenthWardenProductionAuthoring.STAMINA_RESOURCE_ID
    blocked_transition.phase_transition_action.cost_amount = 1.0
    _expect(not blocked_transition.validate_authoring().is_empty(), "irreversible non-damaging transition cannot stall on stamina")
    var cooled_transition := _complete_fixture()
    cooled_transition.phase_transition_action.cooldown_ticks = 12
    _expect(not cooled_transition.validate_authoring().is_empty(), "phase transition cannot stall behind cooldown")
    var cancelled_transition := _complete_fixture()
    cancelled_transition.phase_transition_action.cancellable_phase_mask = 1
    cancelled_transition.phase_transition_action.permitted_cancel_action_ids = [&"twin_cut"]
    _expect(not cancelled_transition.validate_authoring().is_empty(), "phase transition cannot be voluntarily cancelled")

    var simultaneous_volley := _complete_fixture()
    var volley_geometry := simultaneous_volley.attack_for_move(TenthWardenEncounterState.MOVE_ARC_VOLLEY).geometry
    volley_geometry.hit_interval_count = 2
    volley_geometry.hit_active_ticks = PackedInt32Array([0, 0])
    _expect(not simultaneous_volley.validate_authoring().is_empty(), "Arc Volley cannot silently collapse a ranged sequence onto one tick")
    var missing_heavy_window := _complete_fixture()
    missing_heavy_window.action_for_move(TenthWardenEncounterState.MOVE_WARDEN_LUNGE, TenthWardenEncounterState.PHASE_TWO).recovery_ticks = 0
    _expect(not missing_heavy_window.validate_authoring().is_empty(), "Phase-2 heavy recovery needs a real weak-point exposure window")
    var negative_defense := _complete_fixture()
    negative_defense.arcane_defense = -1.0
    _expect(not negative_defense.validate_authoring().is_empty(), "boss rejects negative physical or arcane defense")

    if _failures == 0:
        print("TENTH WARDEN PRODUCTION AUTHORING TEST PASS")
    else:
        push_error("TENTH WARDEN PRODUCTION AUTHORING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _complete_fixture() -> TenthWardenProductionAuthoring:
    var result: TenthWardenProductionAuthoring = PRODUCTION_AUTHORING_SCRIPT.new() as TenthWardenProductionAuthoring
    result.authored = true
    result.max_hp = 900
    result.stamina = 80.0
    result.physical_defense = 8.0
    result.arcane_defense = 12.0
    result.poise_threshold = 45.0
    result.interruptible_declared = true
    result.interruptible = true
    result.block_supported_declared = true
    result.block_supported = false
    result.parry_supported_declared = true
    result.parry_supported = false

    for move_id: StringName in TenthWardenEncounterState.MOVE_IDS:
        var action := ActionDefinition.new()
        action.action_id = move_id
        action.startup_ticks = 12
        action.commit_ticks = 1
        action.active_ticks = 6
        action.recovery_ticks = 18
        action.cooldown_ticks = 10
        result.move_actions.append(action)

        var phase_two_action := ActionDefinition.new()
        phase_two_action.action_id = move_id
        phase_two_action.startup_ticks = 10
        phase_two_action.commit_ticks = 1
        phase_two_action.active_ticks = 6
        phase_two_action.recovery_ticks = 12
        phase_two_action.cooldown_ticks = 8
        result.phase_two_move_actions.append(phase_two_action)

        var geometry := EnemyAttackGeometryAuthoring.new()
        geometry.authored = true
        geometry.geometry_id = StringName("geometry:test_tenth_warden:%s" % String(move_id))
        geometry.query_shape = RectangleShape2D.new()
        geometry.max_reach_px = 64.0
        geometry.collision_mask = 1
        geometry.hit_interval_count = 2 if move_id == TenthWardenEncounterState.MOVE_TWIN_CUT else 1
        geometry.live_placement_declared = true
        geometry.local_offset = Vector2.ZERO
        geometry.local_rotation_radians = 0.0
        geometry.hit_active_ticks = PackedInt32Array([0, 1]) if move_id == TenthWardenEncounterState.MOVE_TWIN_CUT else PackedInt32Array([0])

        var payload := EnemyAttackPayloadAuthoring.new()
        payload.authored = true
        payload.damage_domain = DirectHitResolver.DOMAIN_PHYSICAL
        payload.delivery = DirectHitResolver.DELIVERY_PROJECTILE if move_id == TenthWardenEncounterState.MOVE_ARC_VOLLEY else DirectHitResolver.DELIVERY_CONTACT
        payload.raw_damage = 20.0
        payload.guard_pressure = 5.0
        payload.dodgeable = true
        payload.blockable = move_id != TenthWardenEncounterState.MOVE_CRESCENT_SWEEP
        payload.parryable = move_id != TenthWardenEncounterState.MOVE_ARC_VOLLEY
        payload.critical_multiplier = 1.5
        payload.weak_point_multiplier = 1.5

        var attack := EnemySignatureAttackAuthoring.new()
        attack.action_id = move_id
        attack.geometry = geometry
        attack.payload = payload
        result.move_attacks.append(attack)

    var transition := ActionDefinition.new()
    transition.action_id = TenthWardenEncounterState.ACTION_PHASE_TRANSITION
    transition.startup_ticks = 4
    transition.commit_ticks = 1
    transition.active_ticks = 1
    transition.recovery_ticks = 4
    transition.cooldown_ticks = 0
    result.phase_transition_action = transition
    result.phase_one_move_order = TenthWardenEncounterState.MOVE_IDS.duplicate()
    result.phase_two_move_order = [
        TenthWardenEncounterState.MOVE_TWIN_CUT,
        TenthWardenEncounterState.MOVE_WARDEN_LUNGE,
        TenthWardenEncounterState.MOVE_ARC_VOLLEY,
        TenthWardenEncounterState.MOVE_CRESCENT_SWEEP,
        TenthWardenEncounterState.MOVE_PUNISHING_STEP,
        TenthWardenEncounterState.MOVE_WARDEN_LUNGE,
    ]
    result.phase_two_heavy_move_ids = [TenthWardenEncounterState.MOVE_WARDEN_LUNGE]
    return result


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
