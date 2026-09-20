extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const SANCTUM: PackedScene = preload("res://src/world/tower/boss/tenth_warden_sanctum.tscn")
const AUTHORING: TenthWardenProductionAuthoring = preload("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_playtest_v01.tres")

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(ProfileCreationService.create_profile(1, "Warden Motion", "melee"))
    root.add_child(game)
    await process_frame
    game._set_foundation_world_enabled(false)
    var sanctum := SANCTUM.instantiate() as TenthWardenSanctum
    game.add_child(sanctum)
    await process_frame
    sanctum.set_physics_process(false)
    var player_state := CombatantRuntimeState.new()
    _expect(player_state.configure(&"player:local", 100, 100.0, 0.0, 0.0, 10.0, true, true, true), "player combatant configures")
    _expect(sanctum.prepare_production_encounter(player_state, AUTHORING, game.shared_active_combat, game.shared_full_ai, game.tower_encounter_session_host.shared_attack_pressure), "live motion fixture owns one boss encounter")
    var defender := PlayerDefenderFactsProvider.new()
    _expect(defender.configure(game.player, game.combat_runtime, game.player_defender_facts_tuning).is_empty(), "player defense facts configure")
    _expect(sanctum.bind_live_contact_delivery(game.player, game.combat_runtime, Callable(defender, &"make_snapshot")), "boss motion and geometry share the real player")

    # Live spatial facts must enable Punishing Step only for nearby rear positioning.
    game.player.global_position = sanctum.boss_visual.global_position + Vector2(64, 0)
    sanctum._refresh_punishing_step_positioning_condition()
    _expect(sanctum.punishing_step_positioning_condition_met, "nearby player behind the boss enables authored Punishing Step")
    game.player.global_position = sanctum.boss_visual.global_position + Vector2(-64, 0)
    sanctum._refresh_punishing_step_positioning_condition()
    _expect(not sanctum.punishing_step_positioning_condition_met, "player in front cannot trigger Punishing Step")
    game.player.global_position = sanctum.boss_visual.global_position + Vector2(200, 0)
    sanctum._refresh_punishing_step_positioning_condition()
    _expect(not sanctum.punishing_step_positioning_condition_met, "distant player behind cannot trigger Punishing Step")
    game.player.global_position = sanctum.boss_visual.global_position + Vector2(-100, 0)
    game.player.velocity = Vector2.ZERO
    var machine := sanctum.autonomous_runtime.action_machine
    var action := AUTHORING.action_for_move(TenthWardenEncounterState.MOVE_WARDEN_LUNGE, TenthWardenEncounterState.PHASE_ONE)
    _expect(machine.request_action(action), "Warden Lunge starts its committed telegraph")
    _expect(sanctum.get_locked_attack_direction().is_equal_approx(Vector2.LEFT), "authored startup locks the actual target direction")
    var start := sanctum.boss_visual.global_position
    for _tick: int in action.startup_ticks:
        sanctum._advance_boss_motion(1.0 / 60.0)
        machine.advance_fixed_tick()
    _expect(sanctum.boss_visual.global_position.x < start.x, "boss physically approaches during the telegraphed windup")
    var after_startup := sanctum.boss_visual.global_position
    game.player.global_position = after_startup + Vector2(88, 0)
    _expect(sanctum.get_locked_attack_direction().is_equal_approx(Vector2.LEFT), "late target movement cannot rotate a committed lunge")
    for _tick: int in action.commit_ticks + 1:
        machine.advance_fixed_tick()
    _expect(machine.get_phase() == ActionStateMachine.Phase.ACTIVE, "committed lunge reaches its authored active window")
    sanctum._advance_boss_motion(1.0 / 60.0)
    _expect(sanctum.boss_visual.global_position.x < after_startup.x, "active lunge advances in its locked direction")
    var geometry := AUTHORING.attack_for_move(TenthWardenEncounterState.MOVE_WARDEN_LUNGE).geometry
    _expect(not sanctum.live_contact_delivery._player_is_inside_authored_geometry(geometry), "the backward side of directional hitbox does not hit a late dodge behind the boss")
    game.player.global_position = sanctum.boss_visual.global_position + Vector2(-48, 0)
    _expect(sanctum.live_contact_delivery._player_is_inside_authored_geometry(geometry), "authored forward contact rectangle covers an actual target on the locked side")

    var interior := sanctum.get_arena_rect().grow(-sanctum.boundary_thickness - sanctum.boss_boundary_margin_px)
    sanctum.boss_visual.position = Vector2(interior.position.x + 1.0, 0.0)
    sanctum._locked_target_position = sanctum.to_global(Vector2(-10000.0, 0.0))
    sanctum._advance_boss_motion(1.0 / 60.0)
    _expect(interior.has_point(sanctum.boss_visual.position), "boss movement remains inside the Inspector-authored arena margins")
    var boss_target := {"encounter_id": sanctum.encounter_id, "actor_id": sanctum.boss_runtime.boss_id,
        "position": sanctum.boss_visual.global_position, "encounter": sanctum.encounter_runtime,
        "boss": true, "sanctum": sanctum}
    var payload := {"domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT, "raw_damage": 10.0,
        "dodgeable": true, "blockable": true, "parryable": true,
        "guard_pressure": 0.0, "critical_triggered": false, "critical_multiplier": 1.0,
        "weak_point_triggered": false, "weak_point_multiplier": 1.0}
    var boss := sanctum.encounter_runtime.get_combatant(sanctum.boss_runtime.boss_id)
    var before := boss.current_hp
    var normal := game.player_playtest_attack_delivery._resolve_target(boss_target, 60001, 0, payload)
    var normal_damage := before - boss.current_hp
    _expect(bool(normal.get("accepted", false)) and normal_damage > 0, "normal player contact reaches the authored boss body")
    var weak_target := boss_target.duplicate(true)
    weak_target["weak_point"] = true
    var closed := game.player_playtest_attack_delivery._resolve_target(weak_target, 60002, 0, payload)
    _expect(not bool(closed.get("accepted", false)), "a closed weak point cannot be claimed by a player attack")
    sanctum.boss_runtime.state.phase = TenthWardenEncounterState.PHASE_TWO
    _expect(sanctum.boss_runtime.state.begin_recovery(true), "authored Phase-2 heavy recovery opens the weak-point window")
    _expect(sanctum.get_exposed_weak_point_position().is_finite(), "weak-point target exists during heavy recovery")
    before = boss.current_hp
    var weak := game.player_playtest_attack_delivery._resolve_target(weak_target, 60003, 0, payload)
    _expect(bool(weak.get("accepted", false)) and before - boss.current_hp > normal_damage, "a confirmed exposed weak-point hit applies more than a normal hit")
    sanctum.boss_runtime.state.finish_recovery()
    _expect(not sanctum.get_exposed_weak_point_position().is_finite(), "recovery end removes weak-point targeting immediately")
    sanctum.reset_for_retry()
    _expect(sanctum.boss_visual.position == sanctum.boss_spawn_position, "retry restores the authored boss spawn after movement")
    _expect(game.shared_full_ai.get_admitted_count() == 0, "retry releases the shared FULL-AI ownership")
    _expect(sanctum.prepare_production_encounter(player_state, AUTHORING, game.shared_active_combat, game.shared_full_ai, game.tower_encounter_session_host.shared_attack_pressure), "fresh attempt prepares after retry")
    _expect(sanctum.bind_live_contact_delivery(game.player, game.combat_runtime, Callable(defender, &"make_snapshot")), "fresh attempt binds live targeting")
    sanctum.autonomous_runtime._phase_one_cursor = 4
    game.player.global_position = sanctum.boss_visual.global_position + Vector2(64, 0)
    sanctum._physics_process(1.0 / 60.0)
    _expect(sanctum.autonomous_runtime.action_machine.get_current_action_id() == TenthWardenEncounterState.MOVE_PUNISHING_STEP, "live physics selects Punishing Step when the player creates the authored rear-position condition")
    sanctum.end_encounter()
    game.queue_free()
    await process_frame
    if _failures == 0:
        print("TENTH WARDEN MOTION TARGETING TEST PASS")
    else:
        push_error("TENTH WARDEN MOTION TARGETING TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
