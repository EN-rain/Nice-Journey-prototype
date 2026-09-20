extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(ProfileCreationService.create_profile(1, "Region Live Delivery", "melee"))
    root.add_child(game)
    await process_frame
    game._set_foundation_world_enabled(false)
    game.player.global_position = Vector2(250, 180)
    game.player.apply_aim_direction(Vector2.RIGHT)
    var tower := game.tower_encounter_session_host
    tower.set_physics_process(false)
    var live := game.enemy_playtest_live_delivery
    live.set_physics_process(false)
    var region := Region3SideQuestRuntime.new()
    root.add_child(region)
    region.set_physics_process(false)
    live.set_region3_host(region)
    _expect(live.region3_host == region and region.enemy_active_delivery_window_opened.get_connections().size() == 1,
        "optional Region 3 host connects exactly one delivery callback")

    var region_id := &"encounter:region3_live_delivery"
    var region_actor := &"enemy:region3_duelist"
    var fixture := _combat_fixture(region_id, region_actor, &"duelist", game)
    _install_region_fixture(region, fixture)
    var player_state := fixture["player_state"] as CombatantRuntimeState
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var driver := fixture["driver"] as EnemySignatureActionPhaseDriver
    var executor := fixture["executor"] as EnemyActiveAttackDeliveryExecutor
    await physics_frame
    await process_frame
    var initial_hp := player_state.current_hp
    region.enemy_active_delivery_window_opened.emit(region_id, {"accepted": false, "encounter_id": region_id, "actor_id": region_actor})
    _expect(player_state.current_hp == initial_hp, "uncommitted Region 3 signal cannot damage player")
    _expect(_begin_live(runtime, driver, 91001, game.player.global_position), "Region 3 enemy reaches an authenticated ACTIVE window")
    var context := runtime.get_active_delivery_context(91001)
    region.enemy_active_delivery_window_opened.emit(region_id, context)
    _expect(player_state.current_hp < initial_hp
        and live.last_delivery_result.get("encounter_id", &"") == region_id,
        "physics-confirmed Region 3 melee reaches only its encounter's combatant")
    var once := player_state.current_hp
    region.enemy_active_delivery_window_opened.emit(region_id, context)
    _expect(player_state.current_hp == once, "Region 3 duplicate melee window cannot damage twice")
    region._end_encounter()
    _expect(live._source_for_encounter(region_id) == null,
        "ended Region 3 encounter immediately loses delivery ownership")

    var tower_id := &"encounter:tower_after_region3"
    var tower_actor := &"enemy:tower_after_region3"
    var tower_fixture := _combat_fixture(tower_id, tower_actor, &"duelist", game)
    var tower_state := tower_fixture["player_state"] as CombatantRuntimeState
    tower._sessions[tower_id] = {
        "encounter_runtime": tower_fixture["encounter"],
        "archetype_runtimes": {tower_actor: tower_fixture["runtime"]},
        "action_phase_drivers": {tower_actor: tower_fixture["driver"]},
        "attack_delivery_executors": {tower_actor: tower_fixture["executor"]},
        "visuals_by_actor": {tower_actor: tower_fixture["visual"]},
    }
    await physics_frame
    await process_frame
    _expect(_begin_live(tower_fixture["runtime"], tower_fixture["driver"], 91002, game.player.global_position),
        "tower actor commits normally while optional region source remains connected")
    var tower_context := (tower_fixture["runtime"] as EnemyArchetypeRuntime).get_active_delivery_context(91002)
    region.enemy_active_delivery_window_opened.emit(tower_id, tower_context)
    _expect(tower_state.current_hp == tower_state.max_hp,
        "Region 3 signal cannot impersonate an active Tower encounter ID")
    tower.enemy_active_delivery_window_opened.emit(tower_id, tower_context)
    _expect(tower_state.current_hp < tower_state.max_hp
        and live.last_delivery_result.get("encounter_id", &"") == tower_id,
        "tower delivery remains functional with Region 3 host registered")

    var ranged_id := &"encounter:region3_projectile"
    var ranged_actor := &"enemy:region3_marksman"
    var ranged := _combat_fixture(ranged_id, ranged_actor, &"marksman", game)
    _install_region_fixture(region, ranged)
    _expect(_begin_live(ranged["runtime"], ranged["driver"], 91003, game.player.global_position),
        "Region 3 ranged action reaches ACTIVE before projectile launch")
    var ranged_context := (ranged["runtime"] as EnemyArchetypeRuntime).get_active_delivery_context(91003)
    region.enemy_active_delivery_window_opened.emit(ranged_id, ranged_context)
    _expect(live._projectiles.size() == 1 and (live._projectiles[0] as Dictionary).get("source") == region,
        "Region 3 projectile retains the exact encounter host that spawned it")
    var ranged_state := ranged["player_state"] as CombatantRuntimeState
    var ranged_initial_hp := ranged_state.current_hp
    for _tick: int in 40:
        live._physics_process(1.0 / 60.0)
        if live._projectiles.is_empty():
            break
    _expect(ranged_state.current_hp < ranged_initial_hp
        and live.last_delivery_result.get("encounter_id", &"") == ranged_id,
        "Region 3 projectile ray confirms a live player hit through the correct executor")
    region.enemy_active_delivery_window_opened.emit(ranged_id, ranged_context)
    _expect(live._projectiles.size() == 1, "second projectile is still owned by its Region 3 encounter")
    region._end_encounter()
    _expect(live._projectiles.is_empty(), "Region 3 encounter-end signal immediately clears pending projectiles")

    live.set_region3_host(null)
    _expect(region.enemy_active_delivery_window_opened.get_connections().is_empty()
        and region.encounter_ended.get_connections().is_empty(),
        "Region 3 detach removes both delivery and teardown callbacks")
    tower.end_encounter(tower_id)
    region.queue_free()
    game.queue_free()
    await process_frame
    if _failures == 0:
        print("ENEMY PLAYTEST REGION 3 LIVE DELIVERY TEST PASS")
    else:
        push_error("ENEMY PLAYTEST REGION 3 LIVE DELIVERY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _install_region_fixture(region: Region3SideQuestRuntime, fixture: Dictionary) -> void:
    var actor_id := StringName(String(fixture["actor_id"]))
    region._encounter_id = StringName(String(fixture["encounter_id"]))
    region._encounter = fixture["encounter"] as CombatEncounterRuntime
    region._archetype_runtimes = {actor_id: fixture["runtime"]}
    region._phase_drivers = {actor_id: fixture["driver"]}
    region._attack_executors = {actor_id: fixture["executor"]}
    region._visuals = {actor_id: fixture["visual"]}


func _combat_fixture(encounter_id: StringName, actor_id: StringName, archetype_id: StringName,
    game: GameplayRoot) -> Dictionary:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(encounter_id, game.shared_active_combat, game.shared_full_ai),
        "encounter fixture configures %s" % String(encounter_id))
    var player_state := CombatantRuntimeState.new()
    var enemy_state := CombatantRuntimeState.new()
    _expect(player_state.configure(&"player:local", 100, 100.0, 0.0, 0.0, 10.0, true, true, true),
        "fixture player configures")
    _expect(enemy_state.configure(actor_id, 100, 0.0, 0.0, 0.0, 10.0, true, false, false),
        "fixture attacker configures")
    _expect(encounter.register_player(player_state) and encounter.register_enemy(enemy_state),
        "fixture player and enemy register under counted combat")
    var runtime := EnemyArchetypeRuntime.new()
    _expect(runtime.configure(encounter, actor_id, &"player:local", archetype_id),
        "fixture archetype configures")
    runtime.definition.signature_attack_authoring = game.enemy_playtest_attacks.attack_for(archetype_id)
    var driver := EnemySignatureActionPhaseDriver.new()
    _expect(driver.configure(runtime, EnemySignatureActionTimingCatalog.get_timing(archetype_id)),
        "fixture action clock configures")
    var executor := EnemyActiveAttackDeliveryExecutor.new()
    _expect(executor.configure(runtime, driver), "fixture attack executor configures")
    var visual := Node2D.new()
    visual.position = Vector2(280, 180)
    game.tower_encounter_session_host.add_child(visual)
    return {"encounter_id": encounter_id, "actor_id": actor_id, "encounter": encounter,
        "player_state": player_state, "runtime": runtime, "driver": driver,
        "executor": executor, "visual": visual}


func _begin_live(runtime: EnemyArchetypeRuntime, driver: EnemySignatureActionPhaseDriver,
    instance_id: int, target: Vector2) -> bool:
    var started := driver.begin({"accepted": true, "tactic_id": runtime.definition.signature_action_id},
        instance_id, {"observed_target_position": target, "line_of_sight_observed": true})
    if not bool(started.get("accepted", false)):
        return false
    for _tick: int in int(driver.timing["windup_ticks"]):
        if not driver.advance_fixed_tick():
            return false
    return runtime.phase_id == EnemyArchetypeRuntime.PHASE_ACTIVE


func _expect(condition: bool, label: String) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        _failures += 1
        push_error("FAIL: %s" % label)
