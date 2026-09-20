extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Tower Session", "melee")
    _expect(profile != null, "gameplay tower-session fixture profile creates")
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    if profile != null:
        gameplay.set_profile(profile)
    get_root().add_child(gameplay)
    await process_frame

    var fixture := _build_floor_fixture(1)
    _expect(bool(fixture.get("accepted", false)), "gameplay tower-session runtime fixture composes")
    if bool(fixture.get("accepted", false)):
        var runtime_root := fixture["runtime_root"] as Node2D
        var arrival := fixture["arrival"] as Dictionary
        var commit_result := {
            "accepted": true,
            "runtime_root": runtime_root,
            "arrival": arrival,
        }
        _expect(gameplay.activate_committed_tower_travel(commit_result), "GameplayRoot accepts a committed validated tower runtime")
        _expect(gameplay.is_tower_floor_active(), "GameplayRoot reports active tower session")
        _expect(gameplay.tower_floor_session_host.active_floor_id == 1, "GameplayRoot exposes committed tower floor identity")
        for path: NodePath in [NodePath("TopWall"), NodePath("BottomWall"), NodePath("LeftWall"), NodePath("RightWall"), NodePath("CenterBlock")]:
            var body := gameplay.get_node(path) as CollisionObject2D
            _expect(body != null and body.collision_layer == 0 and body.collision_mask == 0 and not body.visible, "%s foundation collision is disabled while tower session is active" % String(path))
        var climb := gameplay.get_node("ClimbLink") as Area2D
        _expect(climb != null and climb.collision_layer == 0 and climb.collision_mask == 0 and not climb.monitoring and not climb.monitorable and not climb.visible, "foundation climb interaction is disabled while tower session is active")
        _expect(gameplay.player.camera.is_current_visible_rect_within_bounds(), "live gameplay camera remains clamped to active tower bounds")

        var return_position := Vector2(160, 180)
        gameplay.clear_tower_floor_session(return_position)
        _expect(not gameplay.is_tower_floor_active(), "clearing GameplayRoot tower session removes generated floor")
        _expect(gameplay.player.global_position.is_equal_approx(return_position), "tower clear applies caller-authored valid return position")
        for path: NodePath in [NodePath("TopWall"), NodePath("BottomWall"), NodePath("LeftWall"), NodePath("RightWall"), NodePath("CenterBlock")]:
            var body := gameplay.get_node(path) as CollisionObject2D
            _expect(body != null and body.collision_layer == 1 and body.collision_mask == 1 and body.visible, "%s foundation collision restores after tower session" % String(path))
        _expect(climb != null and climb.collision_mask == 1 and climb.monitoring and climb.monitorable and climb.visible, "foundation climb interaction restores after tower session")

    gameplay.queue_free()
    await process_frame
    if _failures == 0:
        print("GAMEPLAY TOWER SESSION INTEGRATION TEST PASS")
    else:
        push_error("GAMEPLAY TOWER SESSION INTEGRATION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _build_floor_fixture(floor_id: int) -> Dictionary:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        88100 + floor_id,
        &"generator:gameplay_session_v01",
        &"modules:prototype_v01",
        &"encounters:prototype_v01",
        &"questflags:gameplay_session_v01"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return {"accepted": false}
    var compose := TowerFloorRuntimeComposer.build(manifest, VISUAL_CATALOG)
    if not bool(compose.get("accepted", false)):
        return {"accepted": false}
    var state := TowerFloorGenerationCommitService.floor_state_from_manifest(StringName("floor_instance:gameplay_session_%d" % floor_id), manifest)
    if state == null:
        (compose["root"] as Node2D).free()
        return {"accepted": false}
    var arrival := TowerArrivalResolver.resolve_entrance(state)
    if not bool(arrival.get("accepted", false)):
        (compose["root"] as Node2D).free()
        return {"accepted": false}
    return {
        "accepted": true,
        "runtime_root": compose["root"],
        "arrival": arrival,
    }

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
