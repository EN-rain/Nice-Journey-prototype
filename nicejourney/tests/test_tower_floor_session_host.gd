extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var host := TowerFloorSessionHost.new()
    host.name = "TowerFloorSessionHost"
    get_root().add_child(host)
    var player := PLAYER_SCENE.instantiate() as PlayerController
    get_root().add_child(player)
    await process_frame

    var fixture := _build_floor_fixture(1)
    _expect(bool(fixture.get("accepted", false)), "tower floor session fixture composes")
    if bool(fixture.get("accepted", false)):
        var runtime_root := fixture["runtime_root"] as Node2D
        var arrival := fixture["arrival"] as Dictionary
        var reset_before := player.camera.get_reset_generation()
        var activated := host.activate(runtime_root, arrival, player, player.camera)
        _expect(activated, "tower floor session host activates a validated runtime floor")
        _expect(host.has_active_floor() and host.active_floor_id == 1, "session host owns exactly the activated floor identity")
        _expect(runtime_root.get_parent() == host, "activated tower runtime is parented under the session host")
        var expected_position := (Vector2(arrival["world_tile"] as Vector2i) + Vector2(0.5, 0.5)) * float(TowerFloorSessionHost.TILE_SIZE)
        _expect(player.global_position.is_equal_approx(host.to_global(expected_position)), "player arrives at the validated entrance tile center")
        _expect(player.velocity == Vector2.ZERO, "tower activation clears stale player velocity")
        _expect(player.camera.get_reset_generation() == reset_before + 1, "tower activation resets camera smoothing after teleport")
        _expect(host.get_world_bounds().size == Vector2(TowerFloorSessionHost.WORLD_SIZE_PIXELS, TowerFloorSessionHost.WORLD_SIZE_PIXELS), "tower session exposes the full 50x50 authored world bounds")
        _expect(player.camera.is_current_visible_rect_within_bounds(), "camera visible rect remains inside active tower world bounds")

        var occupied_runtime := Node2D.new()
        occupied_runtime.set_meta(&"floor_id", 2)
        get_root().add_child(occupied_runtime)
        _expect(not host.activate(occupied_runtime, arrival, player, player.camera), "session host refuses to steal a runtime already parented elsewhere")
        occupied_runtime.queue_free()

        var invalid_arrival := arrival.duplicate(true)
        invalid_arrival["accepted"] = false
        var unused_root := Node2D.new()
        unused_root.set_meta(&"floor_id", 1)
        _expect(not host.activate(unused_root, invalid_arrival, player, player.camera), "session host rejects an unvalidated arrival without replacing the active floor")
        _expect(host.has_active_floor() and host.active_floor_id == 1, "rejected activation preserves the current tower session")
        unused_root.free()

        host.clear_active_floor()
        _expect(not host.has_active_floor() and host.active_floor_id == 0, "clearing the session removes the active tower runtime")

    player.queue_free()
    host.queue_free()
    await process_frame
    if _failures == 0:
        print("TOWER FLOOR SESSION HOST TEST PASS")
    else:
        push_error("TOWER FLOOR SESSION HOST TEST FAILURES: %d" % _failures)
    quit(_failures)

func _build_floor_fixture(floor_id: int) -> Dictionary:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        77100 + floor_id,
        &"generator:session_host_v01",
        &"modules:prototype_v01",
        &"encounters:prototype_v01",
        &"questflags:session_host_v01"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return {"accepted": false}
    var compose := TowerFloorRuntimeComposer.build(manifest, VISUAL_CATALOG)
    if not bool(compose.get("accepted", false)):
        return {"accepted": false}
    var state := TowerFloorGenerationCommitService.floor_state_from_manifest(StringName("floor_instance:session_host_%d" % floor_id), manifest)
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
