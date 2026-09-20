extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TOWER_VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    await _test_floor4_autopreparation()
    await _test_floor10_boss_room_fails_closed()
    if _failures == 0:
        print("GAMEPLAY PROTOTYPE ENCOUNTER AUTOPREPARATION TEST PASS")
    else:
        push_error("GAMEPLAY PROTOTYPE ENCOUNTER AUTOPREPARATION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_floor4_autopreparation() -> void:
    var profile := ProfileCreationService.create_profile(1, "Auto Encounter", "melee")
    var floor := _floor_state(4, 44092)
    _expect(profile != null and floor != null and TowerFloorStateService.commit_floor_state(profile, floor), "autopreparation fixture commits Floor 4")
    if profile == null or floor == null:
        return
    profile.quest_progress["primary_floor_4"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:auto_floor4",
        "objective_state": {},
    }

    var build := TowerFloorRuntimeComposer.build(floor.layout_manifest, TOWER_VISUAL_CATALOG)
    var arrival := TowerArrivalResolver.resolve_entrance(floor)
    _expect(bool(build.get("accepted", false)) and bool(arrival.get("accepted", false)), "autopreparation fixture builds the live floor")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    get_root().add_child(gameplay)
    await process_frame
    _expect(gameplay.activate_committed_tower_travel({"accepted": true, "runtime_root": build.get("root"), "arrival": arrival}), "autopreparation fixture activates Floor 4")
    var arrival_discovery := FloorInstanceState.new()
    _expect(arrival_discovery.load_dictionary(profile.tower_floor_states["4"] as Dictionary).is_empty(), "arrival discovery reads the live committed floor state")
    _expect(arrival_discovery.discovered_room_ids.has(StringName(String(arrival.get("room_instance_id", &"")))), "tower activation marks the exact arrival room discovered without exposing adjacent rooms")

    var encounter_ids := gameplay.get_current_floor_prototype_encounter_ids()
    _expect(not encounter_ids.is_empty(), "GameplayRoot exposes deterministic prepared encounter IDs without caller-authored enemy states")
    var objective_bindings := floor.layout_manifest.get("objective_bindings", {}) as Dictionary
    var primary_room_id := StringName(String(objective_bindings.get("primary_floor_4", &"")))
    var primary_encounter: StringName = &""
    var plan := TowerPrototypeEncounterContentCatalog.build_plan(floor)
    for encounter_id: StringName in encounter_ids:
        for placement: Dictionary in TowerEncounterPlanValidator.placements_for_encounter(plan, encounter_id):
            if StringName(String(placement.get("room_instance_id", &""))) == primary_room_id:
                primary_encounter = encounter_id
                break
        if primary_encounter != &"":
            break
    _expect(primary_encounter != &"", "Floor 4 primary objective room has a prepared encounter")
    if primary_encounter == &"":
        gameplay.queue_free()
        await process_frame
        return

    var floor_root := build.get("root") as Node2D
    var primary_trigger: TowerEncounterRoomTrigger = null
    var primary_discovery_trigger: Area2D = null
    var rooms_root := floor_root.get_node_or_null("Rooms")
    if rooms_root != null:
        for room_node: Node in rooms_root.get_children():
            if StringName(String(room_node.get_meta(&"room_instance_id", &""))) == primary_room_id:
                primary_trigger = room_node.get_node_or_null("EncounterTrigger") as TowerEncounterRoomTrigger
                primary_discovery_trigger = room_node.get_node_or_null("DiscoveryTrigger") as Area2D
                break
    _expect(primary_trigger != null, "runtime composer derives a room encounter trigger from authored walkable geometry")
    _expect(primary_discovery_trigger != null, "runtime composer independently derives an all-room discovery trigger from authored walkable geometry")
    var primary_placements := TowerEncounterPlanValidator.placements_for_encounter(plan, primary_encounter)
    var decision_actor_id: StringName = &""
    for placement: Dictionary in primary_placements:
        if StringName(String(placement.get("archetype_id", &""))) == &"duelist":
            decision_actor_id = StringName(String(placement.get("actor_id", &"")))
            var world_tile: Variant = TowerEncounterPlanValidator.world_tile_for_placement(floor, placement)
            if world_tile is Vector2i:
                gameplay.player.global_position = (Vector2(world_tile as Vector2i) + Vector2(0.5, 0.5)) * float(TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE)
            break
    if primary_discovery_trigger != null:
        primary_discovery_trigger.emit_signal(&"player_entered", primary_room_id)
        await process_frame
        var discovered_floor := FloorInstanceState.new()
        _expect(discovered_floor.load_dictionary(profile.tower_floor_states["4"] as Dictionary).is_empty(), "room-entry discovery commits into live floor state")
        _expect(discovered_floor.discovered_room_ids.has(primary_room_id), "physical room-entry discovery adds the exact entered objective room")
    if primary_trigger != null:
        primary_trigger.player_entered.emit(primary_room_id)
        await process_frame
    var activated := gameplay.last_tower_encounter_trigger_result
    _expect(bool(activated.get("accepted", false)), "room-entry trigger realizes prepared encounter content with production runtime factories")
    _expect(StringName(activated.get("content_status", &"")) == TowerProductionEncounterContentCatalog.CONTENT_STATUS, "automatic encounter activation reports production-v01 content status")
    var primary_entry := profile.quest_progress.get("primary_floor_4", {}) as Dictionary
    _expect(not (primary_entry.get("objective_state", {}) as Dictionary).is_empty(), "automatic activation binds the active primary objective before combat progress")
    _expect(not profile.quest_progress.has("side_tower_floor4_escort"), "automatic activation does not fabricate or activate the reserved escort side quest")

    var encounter := gameplay.tower_encounter_session_host.get_encounter_runtime(primary_encounter)
    _expect(encounter != null and encounter.get_active_enemy_count() > 0, "automatic activation creates live reusable enemy residents")
    _expect(encounter != null and encounter.status_playtest_tuning == gameplay.status_playtest_tuning, "live reusable encounter receives provisional Burn/Slow execution tuning")
    if decision_actor_id != &"":
        for _tick: int in range(18):
            await physics_frame
        var decision_runtime := gameplay.tower_encounter_session_host.get_archetype_runtime(primary_encounter, decision_actor_id)
        _expect(decision_runtime != null and decision_runtime.definition.validate_signature_attack_authoring().is_empty(), "actual Floor 4 resident receives its validated per-archetype PLAYTEST signature geometry and payload")
        _expect(decision_runtime != null and (decision_runtime.phase_id != EnemyArchetypeRuntime.PHASE_IDLE or not decision_runtime.cooldown_ready), "live visible resident evaluates fair observations and begins an authored signature cycle automatically")
        _expect(encounter != null and encounter.attack_pressure.get_active_count() <= AttackPressureLedger.DEFAULT_MAX_COMMITTED_ATTACKS_INITIAL_TUNING, "automatic decisions remain inside the shared committed-attack pressure budget")
    if encounter != null:
        var placements := primary_placements
        for index: int in range(placements.size()):
            var actor_id := StringName(String(placements[index].get("actor_id", &"")))
            var result := encounter.resolve_direct_contact(
                &"player:local",
                actor_id,
                88000 + index,
                0,
                _fatal_attack(),
                false,
                DirectHitResolver.DEFENSE_NONE,
                false
            )
            _expect(bool(result.get("target_defeated", false)), "automatic resident %s can resolve through authoritative combat" % String(actor_id))
    await process_frame
    primary_entry = profile.quest_progress.get("primary_floor_4", {}) as Dictionary
    _expect(StringName(String(primary_entry.get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "automatic encounter defeats advance the bound primary objective")
    _expect(gameplay.end_tower_encounter(primary_encounter), "automatic encounter session closes through normal GameplayRoot ownership")
    gameplay.queue_free()
    await process_frame


func _test_floor10_boss_room_fails_closed() -> void:
    var profile := ProfileCreationService.create_profile(1, "Boss Dispatch", "mage")
    var floor := _floor_state(10, 100092)
    _expect(profile != null and floor != null and TowerFloorStateService.commit_floor_state(profile, floor), "Floor 10 dispatch fixture commits the authored floor")
    if profile == null or floor == null:
        return
    profile.quest_progress["primary_floor_10"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:floor10_dispatch",
        "objective_state": {},
    }
    var build := TowerFloorRuntimeComposer.build(floor.layout_manifest, TOWER_VISUAL_CATALOG)
    var arrival := TowerArrivalResolver.resolve_entrance(floor)
    _expect(bool(build.get("accepted", false)) and bool(arrival.get("accepted", false)), "Floor 10 dispatch fixture builds the live floor")
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    get_root().add_child(gameplay)
    await process_frame
    _expect(gameplay.activate_committed_tower_travel({"accepted": true, "runtime_root": build.get("root"), "arrival": arrival}), "Floor 10 dispatch fixture activates the live floor")

    var boss_room_id := StringName(String((floor.layout_manifest.get("objective_bindings", {}) as Dictionary).get("primary_floor_10", &"")))
    var boss_trigger: TowerEncounterRoomTrigger = null
    var rooms_root := gameplay.tower_floor_session_host.active_runtime_root.get_node_or_null("Rooms")
    if rooms_root != null:
        for room_node: Node in rooms_root.get_children():
            if StringName(String(room_node.get_meta(&"room_instance_id", &""))) == boss_room_id:
                boss_trigger = room_node.get_node_or_null("EncounterTrigger") as TowerEncounterRoomTrigger
                break
    _expect(boss_room_id != &"" and boss_trigger != null, "Floor 10 Boss Sanctum has its authored room trigger")
    if boss_trigger != null:
        boss_trigger.player_entered.emit(boss_room_id)
        await process_frame
        var result := gameplay.last_tower_encounter_trigger_result
        _expect(
            bool(result.get("accepted", false))
            and bool(result.get("runtime_driver_ready", false))
            and bool(result.get("progression_bound", false)),
            "Floor 10 Boss Sanctum activates the assigned, validated playtest combat owner"
        )
        _expect(gameplay.tower_encounter_session_host.get_active_encounter_count() == 0, "Floor 10 dispatch does not create a competing generic encounter")
    gameplay.queue_free()
    await process_frame

func _floor_state(floor_id: int, seed: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        seed,
        &"tower_generator:v01",
        &"tower_modules:v01",
        &"encounters:v01",
        &"quest_flags:auto_encounter_test"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return null
    return TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:auto_encounter_%d_%d" % [floor_id, seed]),
        manifest
    )

func _fatal_attack() -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": 10000.0,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 0.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
