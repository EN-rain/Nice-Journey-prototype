extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const SANCTUM: PackedScene = preload("res://src/world/tower/boss/tenth_warden_sanctum.tscn")
const AUTHORING: TenthWardenProductionAuthoring = preload("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_playtest_v01.tres")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(ProfileCreationService.create_profile(1, "Arc Volley Projectile", "melee"))
    root.add_child(game)
    await process_frame
    game._set_foundation_world_enabled(false)
    var sanctum := SANCTUM.instantiate() as TenthWardenSanctum
    game.add_child(sanctum)
    await process_frame
    sanctum.set_physics_process(false)
    _expect(sanctum.arc_volley_projectile_scene != null and sanctum.arc_volley_projectile_speed_px_s > 0.0 and sanctum.arc_volley_projectile_radius_px > 0.0, "Arc Volley projectile scene, speed and hit radius are Inspector-owned")
    var projectile_template := sanctum.arc_volley_projectile_scene.instantiate() as Node2D
    _expect(projectile_template != null and projectile_template.get_node_or_null("Body") is ColorRect, "projectiles use a Godot-native ColorRect, not generated artwork")
    if projectile_template != null:
        projectile_template.free()
    game.player.global_position = sanctum.to_global(Vector2(30, 0))
    game.player.apply_aim_direction(Vector2.RIGHT)
    await physics_frame
    await process_frame
    var player_state := CombatantRuntimeState.new()
    _expect(player_state.configure(&"player:local", 100, 100.0, 0.0, 0.0, 10.0, true, true, true), "real player combatant is valid")
    _expect(sanctum.prepare_production_encounter(player_state, AUTHORING, game.shared_active_combat, game.shared_full_ai, game.tower_encounter_session_host.shared_attack_pressure), "real boss, shared encounter and action clock configure")
    var facts := PlayerDefenderFactsProvider.new()
    _expect(facts.configure(game.player, game.combat_runtime, game.player_defender_facts_tuning).is_empty(), "real defender provider configures")
    _expect(sanctum.bind_live_contact_delivery(game.player, game.combat_runtime, Callable(facts, &"make_snapshot")), "live Arc Volley owner binds real combat and player")
    var machine := sanctum.autonomous_runtime.action_machine
    var action := AUTHORING.action_for_move(TenthWardenEncounterState.MOVE_ARC_VOLLEY, TenthWardenEncounterState.PHASE_ONE)
    _expect(machine.request_action(action), "authored Arc Volley action begins")
    for _tick: int in action.startup_ticks + action.commit_ticks:
        machine.advance_fixed_tick()
    _expect(machine.get_phase() == ActionStateMachine.Phase.ACTIVE and player_state.current_hp == 100, "boss windup and commit do not teleport projectile damage")

    # Leave projectiles moving while the machine reaches recovery; they retain
    # their validated action-instance/interval ticket and actual world position.
    for _tick: int in action.active_ticks:
        machine.advance_fixed_tick()
        sanctum.live_contact_delivery.advance_fixed_tick()
    _expect(sanctum.live_contact_delivery._arc_volley_projectiles.size() > 0, "Arc Volley emits three separate traveling ColorRect projectiles")
    for _tick: int in 30:
        machine.advance_fixed_tick()
        sanctum.live_contact_delivery.advance_fixed_tick()
        if player_state.current_hp < 100:
            break
    var impact := sanctum.live_contact_delivery.last_arc_volley_impact
    _expect(player_state.current_hp < 100 and bool(impact.get("accepted", false)), "moving projectile confirms geometric contact and deals real resolved HP damage")
    _expect(bool(impact.get("projectile_travel_confirmed", false)) and impact.get("action_id", &"") == TenthWardenEncounterState.MOVE_ARC_VOLLEY, "impact carries authenticated Arc Volley instance and travel evidence")
    var after := player_state.current_hp
    for _tick: int in 110:
        sanctum.live_contact_delivery.advance_fixed_tick()
    _expect(sanctum.live_contact_delivery._arc_volley_projectiles.is_empty() and player_state.current_hp >= 85 and player_state.current_hp <= after, "up to three authored projectile intervals resolve once and expire independently")
    var expired_hp := player_state.current_hp
    for _tick: int in 30:
        sanctum.live_contact_delivery.advance_fixed_tick()
    _expect(player_state.current_hp == expired_hp, "expired projectiles cannot damage the player again")
    var attacker := sanctum.encounter_runtime.get_combatant(sanctum.boss_runtime.boss_id)
    attacker.current_hp = 0
    sanctum.live_contact_delivery.advance_fixed_tick()
    _expect(sanctum.live_contact_delivery._arc_volley_projectiles.is_empty(), "boss defeat prevents leftover projectile hit admission")
    sanctum.end_encounter()
    _expect(sanctum.live_contact_delivery == null, "normal end-encounter releases live projectile delivery owner")
    game.queue_free()
    await process_frame
    if _failures == 0:
        print("TENTH WARDEN ARC VOLLEY PROJECTILE TEST PASS")
    else:
        push_error("TENTH WARDEN ARC VOLLEY PROJECTILE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
