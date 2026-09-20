extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TOWER_VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const TEST_SAVE_ROOT: String = "user://tests/gameplay_region3_startup"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service := SaveService.new(TEST_SAVE_ROOT)
    save_service.delete_slot(1)

    var profile := ProfileCreationService.create_profile(1, "Region Starter", "melee")
    _expect(profile != null, "Region 3 startup fixture creates a profile")
    if profile == null:
        quit(1)
        return
    _expect(profile.safe_state.is_empty(), "profile creation itself does not fabricate a world checkpoint before live gameplay exists")
    _expect(save_service.save_profile(1, profile) == OK, "Region 3 startup fixture persists the pre-gameplay profile")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save_service, 1), "Region 3 startup fixture supplies the real save context")
    root.add_child(gameplay)
    await process_frame

    _expect(gameplay.ensure_starting_world(), "GameplayRoot enters the required Region 3 starting world")
    _expect(gameplay.is_region3_active(), "authored Region 3 runtime is active after starting-world admission")
    _expect(not gameplay.is_tower_floor_active(), "Region 3 startup does not fabricate a Tower session")
    var host := gameplay.region3_town_session_host
    _expect(host != null and host.has_loaded_region() and host.has_active_region(), "Region 3 session host owns one active authored town runtime")

    var expected_start := host.resolve_start_position()
    var actual_local := host.to_local(gameplay.player.global_position)
    _expect(expected_start.is_equal_approx(Vector2(60, 80) * 32.0), "Region 3 start resolves from the authored Quest Hall approach tile")
    _expect(actual_local.is_equal_approx(expected_start), "player starts at the authored R3-MAIN-START Quest Hall approach")
    _expect(host.get_world_bounds().size.is_equal_approx(Vector2(160, 160) * 32.0), "Region 3 camera/world bounds use the authored 160x160 logical tile space")
    _expect(gameplay.player.camera.is_current_visible_rect_within_bounds(), "Region 3 startup camera is clamped inside authored world bounds")
    _expect(StringName(String(gameplay.last_region3_subzone_discovery_result.get("zone_id", &""))) == &"R3-TOWN", "live Region 3 activation records physical discovery of the starting town subzone")
    var initial_explored := profile.region_state.get("explored_zone_ids", []) as Array
    _expect(initial_explored.size() == 1 and String(initial_explored[0]) == "R3-TOWN", "startup profile contains only the physically entered town discovery")
    _expect(StringName(String(profile.region_state.get("map_revision_id", &""))) == Region3AuthoredTownLayout.MAP_REVISION_ID, "startup discovery state is bound to the authored Region 3 map revision")

    for path: NodePath in [NodePath("TopWall"), NodePath("BottomWall"), NodePath("LeftWall"), NodePath("RightWall"), NodePath("CenterBlock")]:
        var body := gameplay.get_node(path) as CollisionObject2D
        _expect(body != null and body.collision_layer == 0 and body.collision_mask == 0 and not body.visible, "%s foundation greybox collision is disabled while Region 3 owns the world" % String(path))
    var climb := gameplay.get_node("ClimbLink") as Area2D
    _expect(climb != null and not climb.monitoring and not climb.monitorable and not climb.visible, "foundation climb diagnostic is disabled while Region 3 owns the world")

    var safe := profile.safe_state
    _expect(StringName(String(safe.get("snapshot_id", &""))) == GameplayRoot.REGION3_START_SAFE_ID, "first live Region 3 entry creates the dedicated starting safe snapshot")
    _expect(StringName(String(safe.get("map_id", &""))) == GameplayRoot.REGION3_MAP_ID and int(safe.get("floor_id", -1)) == 0, "Region 3 starting snapshot uses the existing region map identity and non-Tower floor marker")
    _expect(StringName(String(safe.get("checkpoint_anchor_id", &""))) == GameplayRoot.REGION3_TOWN_CHECKPOINT_ID, "Region 3 starting snapshot uses the existing town checkpoint identity")
    var safe_player := safe.get("player_state", {}) as Dictionary
    _expect(is_equal_approx(float(safe_player.get("position_x", -1.0)), gameplay.player.global_position.x) and is_equal_approx(float(safe_player.get("position_y", -1.0)), gameplay.player.global_position.y), "Region 3 starting safe snapshot captures the live authored arrival position")
    _expect(safe_player.has("health_state") and safe_player.has("stamina_state") and safe_player.has("combat_state"), "Region 3 starting safe snapshot captures live resource/combat state instead of guessed profile values")

    var durable := save_service.load_profile(1)
    _expect(durable != null, "Region 3 starting safe snapshot is durable through SaveService before gameplay continues")
    if durable != null:
        var durable_safe := durable.safe_state
        var durable_player := durable_safe.get("player_state", {}) as Dictionary
        _expect(
            StringName(String(durable_safe.get("snapshot_id", &""))) == GameplayRoot.REGION3_START_SAFE_ID
            and StringName(String(durable_safe.get("map_id", &""))) == GameplayRoot.REGION3_MAP_ID
            and StringName(String(durable_safe.get("checkpoint_anchor_id", &""))) == GameplayRoot.REGION3_TOWN_CHECKPOINT_ID,
            "JSON-loaded Region 3 starting snapshot preserves exact stable identities"
        )
        _expect(
            is_equal_approx(float(durable_player.get("position_x", -1.0)), gameplay.player.global_position.x)
            and is_equal_approx(float(durable_player.get("position_y", -1.0)), gameplay.player.global_position.y)
            and durable_player.get("health_state", null) is Dictionary
            and durable_player.get("stamina_state", null) is Dictionary
            and durable_player.get("combat_state", null) is Dictionary,
            "JSON-loaded Region 3 starting snapshot preserves position and coherent live resource state"
        )
        var durable_explored := durable.region_state.get("explored_zone_ids", []) as Array
        _expect(durable_explored.size() == 1 and String(durable_explored[0]) == "R3-TOWN", "initial Region 3 checkpoint durably includes the starting town discovery")

    gameplay.player.global_position = host.to_global(Vector2(70, 120) * 32.0)
    await process_frame
    _expect(StringName(String(gameplay.last_region3_subzone_discovery_result.get("zone_id", &""))) == &"R3-OUTSKIRTS", "live traversal into the authored south reservation records Outskirts discovery")
    var live_region_map := MapViewService.build_layer(profile, MapLayerIdentityValidator.LAYER_REGION_MAP)
    var live_explored := live_region_map.get("explored_subzones", []) as Array
    _expect(bool(live_region_map.get("explored_subzone_state_available", false)) and live_explored.size() == 2, "Region Map exposes exactly Town + Outskirts after physical traversal")
    gameplay.player.global_position = host.to_global(expected_start)
    await process_frame

    var storage := host.get_storage_interaction()
    _expect(storage != null, "active Region 3 runtime exposes the authored Storage House service trigger")
    if storage != null:
        storage.call("_on_body_entered", gameplay.player)
        var service_result := storage.request_service(&"interaction:test_region3_runtime_storage")
        _expect(bool(service_result.get("admitted", false)), "live Region 3 Storage House trigger is bound to GameplayRoot input/service owners")
        _expect(
            StringName(String(gameplay.last_region3_storage_service_request.get("structure_id", &""))) == &"r3:functional:06"
            and StringName(String(gameplay.last_region3_storage_service_request.get("role_id", &""))) == &"storage_house",
            "GameplayRoot receives exact authored Storage House service identity"
        )
        storage.call("_on_body_exited", gameplay.player)

    var region_return_position := host.to_local(gameplay.player.global_position)
    var tower_fixture := _build_floor_fixture(1)
    _expect(bool(tower_fixture.get("accepted", false)), "Region 3 suspend/resume fixture composes a Tower floor")
    if bool(tower_fixture.get("accepted", false)):
        _expect(gameplay.activate_committed_tower_travel(tower_fixture), "Tower activation accepts while Region 3 is live")
        _expect(gameplay.is_tower_floor_active(), "Tower runtime becomes active after committed travel")
        _expect(host.has_loaded_region() and host.is_suspended() and not host.has_active_region(), "Tower entry suspends but does not rebuild/destroy the authored Region 3 runtime")
        gameplay.clear_tower_floor_session(Vector2(160, 180))
        _expect(not gameplay.is_tower_floor_active() and gameplay.is_region3_active(), "clearing Tower runtime resumes the same authored Region 3 runtime")
        _expect(host.to_local(gameplay.player.global_position).is_equal_approx(region_return_position), "Tower clear returns to the recorded Region 3 entry position instead of the foundation-world fallback coordinate")
        _expect(not gameplay.get_node("TopWall").visible, "foundation greybox remains disabled after Region 3 resumes")

    gameplay.queue_free()
    await process_frame

    var restored_profile := save_service.load_profile(1)
    _expect(restored_profile != null, "Region 3 durable-start profile reloads for runtime restore")
    if restored_profile != null:
        var restored_gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
        restored_gameplay.set_profile(restored_profile)
        _expect(restored_gameplay.set_save_context(save_service, 1), "restored Region 3 fixture supplies save context")
        root.add_child(restored_gameplay)
        await process_frame
        _expect(restored_gameplay.ensure_starting_world(), "existing Region 3 safe snapshot restores without creating a new start snapshot")
        _expect(restored_gameplay.is_region3_active(), "existing Region 3 safe snapshot activates authored town runtime")
        _expect(
            restored_gameplay.region3_town_session_host.to_local(restored_gameplay.player.global_position).is_equal_approx(expected_start),
            "existing Region 3 safe snapshot restores the saved player location"
        )
        _expect(bool(restored_gameplay.last_region3_start_result.get("restored_safe_state", false)), "Region 3 startup reports safe-state restoration rather than a second initial commit")
        restored_gameplay.queue_free()
        await process_frame

    save_service.delete_slot(1)
    if _failures == 0:
        print("GAMEPLAY REGION 3 STARTUP TEST PASS")
    else:
        push_error("GAMEPLAY REGION 3 STARTUP TEST FAILURES: %d" % _failures)
    quit(_failures)


func _build_floor_fixture(floor_id: int) -> Dictionary:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        99000 + floor_id,
        &"generator:region3_startup_test_v01",
        &"modules:prototype_v01",
        &"encounters:prototype_v01",
        &"questflags:region3_startup_test_v01"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return {"accepted": false}
    var compose := TowerFloorRuntimeComposer.build(manifest, TOWER_VISUAL_CATALOG)
    if not bool(compose.get("accepted", false)):
        return {"accepted": false}
    var floor := TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:region3_startup_%d" % floor_id),
        manifest
    )
    if floor == null:
        (compose.get("root") as Node2D).free()
        return {"accepted": false}
    var arrival := TowerArrivalResolver.resolve_entrance(floor)
    if not bool(arrival.get("accepted", false)):
        (compose.get("root") as Node2D).free()
        return {"accepted": false}
    return {
        "accepted": true,
        "runtime_root": compose.get("root"),
        "arrival": arrival,
    }


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
