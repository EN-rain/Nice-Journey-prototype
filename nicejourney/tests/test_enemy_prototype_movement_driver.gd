extends SceneTree

const TUNING: EnemyPrototypeMovementTuning = preload("res://src/data/tuning/enemy_prototype_movement_default.tres")
var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_destination_contract()
    await _test_navigation_execution()
    await _test_generated_tower_room_navigation()
    if _failures == 0:
        print("ENEMY PROTOTYPE MOVEMENT DRIVER TEST PASS")
    else:
        push_error("ENEMY PROTOTYPE MOVEMENT DRIVER TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_destination_contract() -> void:
    _expect(TUNING.validate_tuning().is_empty(), "default prototype movement tuning validates")
    var approach := EnemyPrototypeMovementDriver.resolve_destination(
        &"tactic:approach", Vector2(32, 32), Vector2(160, 32), true, Vector2.ZERO, false, TUNING.withdraw_probe_distance_px
    )
    _expect(bool(approach.get("accepted", false)) and Vector2(approach.get("destination", Vector2.ZERO)) == Vector2(160, 32), "approach uses the current justified observation snapshot")

    var withdraw := EnemyPrototypeMovementDriver.resolve_destination(
        &"tactic:withdraw", Vector2(96, 32), Vector2(64, 32), true, Vector2.ZERO, false, 64.0
    )
    _expect(bool(withdraw.get("accepted", false)) and Vector2(withdraw.get("destination", Vector2.ZERO)) == Vector2(160, 32), "withdraw extends directly away from the observed target")

    var last_known := EnemyPrototypeMovementDriver.resolve_destination(
        &"tactic:reposition_last_known", Vector2(32, 32), Vector2(900, 900), false, Vector2(128, 96), true, 64.0
    )
    _expect(bool(last_known.get("accepted", false)) and Vector2(last_known.get("destination", Vector2.ZERO)) == Vector2(128, 96), "lost-sight reposition uses only the last admitted observation")
    var unseen_live := EnemyPrototypeMovementDriver.resolve_destination(
        &"tactic:approach", Vector2(32, 32), Vector2(900, 900), false, Vector2(128, 96), true, 64.0
    )
    _expect(not bool(unseen_live.get("accepted", false)), "movement cannot pursue an unseen live target without a justified current observation")

func _test_navigation_execution() -> void:
    var fixture := _runtime_fixture()
    var runtime := fixture.get("runtime") as EnemyArchetypeRuntime
    if runtime == null:
        return

    var world := Node2D.new()
    world.name = "MovementWorld"
    get_root().add_child(world)
    var region := NavigationRegion2D.new()
    var polygon := NavigationPolygon.new()
    polygon.vertices = PackedVector2Array([Vector2.ZERO, Vector2(512, 0), Vector2(512, 256), Vector2(0, 256)])
    polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
    region.navigation_polygon = polygon
    world.add_child(region)

    var visual := Node2D.new()
    visual.position = Vector2(64, 128)
    world.add_child(visual)
    var target := Node2D.new()
    target.position = Vector2(384, 128)
    world.add_child(target)

    var driver := EnemyPrototypeMovementDriver.new()
    _expect(driver.configure(runtime, visual, TUNING), "movement driver configures against a live tactical runtime")
    driver.set_target_node(target)
    _expect(visual.get_node_or_null("PrototypeNavigationAgent") is NavigationAgent2D, "movement driver owns a real NavigationAgent2D rather than teleporting")
    var applied := driver.apply_decision({
        "accepted": true,
        "selection": {"tactic_id": &"tactic:approach"},
        "observed_position": target.global_position,
    })
    _expect(applied and driver.active_tactic_id == &"tactic:approach", "authored approach tactic becomes executable movement intent")
    var captured_observation := target.global_position
    target.global_position = Vector2(16, 128)

    await physics_frame
    await physics_frame
    var start_x := visual.global_position.x
    for _index: int in range(12):
        _expect(driver.advance_fixed(1.0 / 60.0), "navigation movement tick advances")
        await physics_frame
    _expect(visual.global_position.x > start_x, "live movement intent advances along the navigation map toward the captured observation")
    _expect(driver.navigation_agent.target_position.is_equal_approx(captured_observation), "movement does not track target movement that occurred after the observation snapshot")
    _expect(visual.global_position.x < captured_observation.x, "movement remains incremental and does not teleport to its observed destination")

    visual.global_position = Vector2(96, 128)
    driver.apply_decision({
        "accepted": true,
        "selection": {"tactic_id": &"tactic:approach"},
        "observed_position": Vector2(100, 128),
    })
    var arrival_start := visual.global_position
    _expect(driver.advance_fixed(1.0 / 60.0), "arrival-tolerance tick advances")
    await physics_frame
    _expect(visual.global_position.is_equal_approx(arrival_start), "movement does not jitter when already inside authored target arrival tolerance")

    visual.global_position = Vector2(24, 128)
    driver.apply_decision({
        "accepted": true,
        "selection": {"tactic_id": &"tactic:withdraw"},
        "observed_position": Vector2(96, 128),
    })
    _expect(driver.advance_fixed(1.0 / 60.0), "boundary-aware withdraw tick advances")
    await physics_frame
    _expect(driver.navigation_agent.target_position.x >= -0.001, "withdraw target is clamped onto authored navigation instead of targeting outside the walkable map")
    for _index: int in range(30):
        driver.advance_fixed(1.0 / 60.0)
        await physics_frame
    _expect(visual.global_position.x >= -0.001, "withdraw execution cannot move the actor outside the authored navigation boundary")

    driver.apply_decision({
        "accepted": true,
        "selection": {"tactic_id": &"tactic:hold_observe"},
        "observed_position": target.global_position,
    })
    var stopped_at := visual.global_position
    for _index: int in range(3):
        driver.advance_fixed(1.0 / 60.0)
        await physics_frame
    _expect(visual.global_position.is_equal_approx(stopped_at), "hold-observe clears movement intent immediately")

    world.queue_free()
    await process_frame

func _test_generated_tower_room_navigation() -> void:
    var visual_catalog := load("res://src/world/tower/presentation/tower_room_visual_catalog.tres") as TowerRoomVisualCatalog
    _expect(visual_catalog != null and visual_catalog.validate_catalog().is_empty(), "generated-room movement fixture has a valid tower visual catalog")
    if visual_catalog == null:
        return
    var request := TowerFloorGenerationCommitService.build_request(
        1,
        93117,
        &"generator:prototype_v01",
        &"modules:prototype_v01",
        &"encounters:prototype_v01",
        &"questflags:movement_regression_v01"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    var composition := TowerFloorRuntimeComposer.build(manifest, visual_catalog)
    _expect(bool(composition.get("accepted", false)), "generated-room movement fixture composes a validated live tower floor")
    if not bool(composition.get("accepted", false)):
        return
    var floor_root := composition.get("root") as Node2D
    get_root().add_child(floor_root)
    await physics_frame
    await physics_frame

    var room_data: Dictionary = {}
    for raw_room: Variant in manifest.get("rooms", []) as Array:
        if raw_room is Dictionary:
            var candidate := raw_room as Dictionary
            var definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(candidate.get("module_id", &""))))
            if definition != null and not definition.spawn_regions.is_empty() and not definition.walkable_rects.is_empty():
                room_data = candidate
                break
    _expect(not room_data.is_empty(), "generated floor exposes a combat-capable room with authored navigation")
    if room_data.is_empty():
        floor_root.queue_free()
        await process_frame
        return

    var rooms := floor_root.get_node_or_null("Rooms") as Node2D
    var room_id := StringName(String(room_data.get("room_instance_id", &"")))
    var room_node := _find_runtime_room(rooms, room_id)
    var definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(room_data.get("module_id", &""))))
    _expect(room_node != null and definition != null, "generated movement fixture resolves its live combat room and authored module")
    if room_node == null or definition == null:
        floor_root.queue_free()
        await process_frame
        return

    var walkable := definition.walkable_rects[0]
    var tile_size := float(int(floor_root.get_meta(&"tile_size", 32)))
    var local_left := Vector2(float(walkable.position.x) + 1.5, float(walkable.position.y) + float(walkable.size.y) * 0.5) * tile_size
    var local_right := Vector2(float(walkable.end.x) - 1.5, float(walkable.position.y) + float(walkable.size.y) * 0.5) * tile_size
    var actor_start := room_node.to_global(local_left)
    var observed_target := room_node.to_global(local_right)

    var fixture := _runtime_fixture()
    var runtime := fixture.get("runtime") as EnemyArchetypeRuntime
    if runtime == null:
        floor_root.queue_free()
        await process_frame
        return
    var visual := Node2D.new()
    visual.name = "GeneratedRoomMovementEnemy"
    visual.global_position = actor_start
    floor_root.add_child(visual)
    var target := Node2D.new()
    target.name = "GeneratedRoomMovementTarget"
    target.global_position = observed_target
    floor_root.add_child(target)
    var driver := EnemyPrototypeMovementDriver.new()
    _expect(driver.configure(runtime, visual, TUNING), "movement driver configures inside generated tower navigation")

    driver.apply_decision({
        "accepted": true,
        "selection": {"tactic_id": &"tactic:approach"},
        "observed_position": observed_target,
    })
    target.global_position = room_node.to_global(Vector2(tile_size * 1.5, tile_size * 1.5))
    var generated_start := visual.global_position
    for _index: int in range(8):
        driver.advance_fixed(1.0 / 60.0)
        await physics_frame
    _expect(visual.global_position.distance_to(observed_target) < generated_start.distance_to(observed_target), "generated-room approach advances toward the admitted observation")
    _expect(driver.navigation_agent.target_position.is_equal_approx(observed_target), "generated-room movement does not pursue a target that moved after observation")

    var wall_observation := room_node.to_global(Vector2((float(walkable.position.x) + 1.5) * tile_size, 0.5 * tile_size))
    driver.apply_decision({
        "accepted": true,
        "selection": {"tactic_id": &"tactic:approach"},
        "observed_position": wall_observation,
    })
    driver.advance_fixed(1.0 / 60.0)
    await physics_frame
    _expect(not driver.navigation_agent.target_position.is_equal_approx(wall_observation), "generated-room wall observation is projected onto authored walkable navigation")

    var withdraw_start := room_node.to_global(Vector2(float(walkable.position.x) + 1.5, float(walkable.position.y) + 1.5) * tile_size)
    var withdraw_target := room_node.to_global(Vector2(float(walkable.end.x) - 1.5, float(walkable.position.y) + 1.5) * tile_size)
    visual.global_position = withdraw_start
    var withdraw_raw := EnemyPrototypeMovementDriver.resolve_destination(
        &"tactic:withdraw",
        withdraw_start,
        withdraw_target,
        true,
        Vector2.ZERO,
        false,
        TUNING.withdraw_probe_distance_px
    )
    driver.apply_decision({
        "accepted": true,
        "selection": {"tactic_id": &"tactic:withdraw"},
        "observed_position": withdraw_target,
    })
    driver.advance_fixed(1.0 / 60.0)
    await physics_frame
    _expect(bool(withdraw_raw.get("accepted", false)) and not driver.navigation_agent.target_position.is_equal_approx(withdraw_raw.get("destination", Vector2.ZERO)), "generated-room withdraw target is clamped when the raw probe exits authored navigation")
    var map_rid := driver.navigation_agent.get_navigation_map()
    var closest := NavigationServer2D.map_get_closest_point(map_rid, driver.navigation_agent.target_position)
    _expect(closest.is_equal_approx(driver.navigation_agent.target_position), "generated-room withdraw remains on synchronized tower navigation")

    floor_root.queue_free()
    await process_frame

func _find_runtime_room(rooms: Node2D, room_id: StringName) -> Node2D:
    if rooms == null:
        return null
    for child: Node in rooms.get_children():
        if child is Node2D and StringName(String(child.get_meta(&"room_instance_id", &""))) == room_id:
            return child as Node2D
    return null

func _runtime_fixture() -> Dictionary:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:movement_driver"), "movement fixture encounter configures")
    var player := CombatantRuntimeState.new()
    var enemy := CombatantRuntimeState.new()
    _expect(player.configure(&"player:movement_target", 100, 100.0, 0.0, 0.0, 20.0, true, false, false), "movement fixture player validates")
    _expect(enemy.configure(&"enemy:movement_duelist", 100, 0.0, 0.0, 0.0, 20.0, true, false, false), "movement fixture enemy validates")
    _expect(encounter.register_player(player) and encounter.register_enemy(enemy), "movement fixture combatants register")
    var runtime := EnemyArchetypeRuntime.new()
    _expect(runtime.configure(encounter, enemy.actor_id, player.actor_id, &"duelist"), "movement fixture archetype runtime configures")
    return {"encounter": encounter, "runtime": runtime}

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
