extends SceneTree

const MAP_MENU_SCENE: PackedScene = preload("res://src/ui/map_menu.tscn")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Safe Map UI", "melee")
    var layout := preload("res://src/world/region3/layout/region3_authored_town_layout.tscn").instantiate() as Region3AuthoredTownLayout
    _expect(layout != null and layout.validate_layout().is_empty(), "Region 3 layout is valid")
    var safe := SafeCheckpointState.make(
        &"safe:ui_region3", &"region:3", 0, &"checkpoint:region3_town",
        {"position_x": 1920.0, "position_y": 2560.0}, {}, 1
    )
    _expect(not safe.is_empty(), "snapshot fixture is valid")
    profile.safe_state = safe
    _expect(bool(Region3SubzoneDiscoveryService.mark_local_position_explored(profile, layout, Vector2(1920.0, 2560.0)).get("accepted", false)), "fixture physically discovers saved town zone")
    var layer := MapViewService.build_layer(profile, MapLayerIdentityValidator.LAYER_REGION_MAP)
    var saved := layer.get("saved_safe_location", {}) as Dictionary
    _expect(saved.get("position_tiles", Vector2.INF) == Vector2(60.0, 80.0), "map layer forwards validated pixel-to-tile saved snapshot position")
    _expect((layer.get("checkpoint_markers", []) as Array).is_empty() and not bool(layer.get("checkpoint_marker_state_available", true)), "saved location is not misrepresented as fixed checkpoint geometry")

    var menu := MAP_MENU_SCENE.instantiate() as MapMenu
    root.add_child(menu)
    var canvas := menu.get_node("Overlay/Panel/Layout/RegionCanvas") as MapRegionCanvas
    _expect(canvas != null and canvas.configure_geometry(
        layer.get("map_size_tiles", Vector2i.ZERO), layer.get("town_tile_rect", Rect2i()),
        layer.get("plaza_tile_rect", Rect2i()), layer.get("route_polylines", []),
        layer.get("public_landmarks", []), layer.get("explored_subzones", [])
    ), "Region canvas accepts validated map geometry")
    _expect(canvas.set_saved_safe_location(saved), "canvas accepts committed saved location with correct nontravel provenance")
    _expect((canvas.saved_safe_location().get("position_tiles", Vector2.INF) as Vector2) == Vector2(60.0, 80.0), "canvas preserves exact saved tile position")
    _expect(not canvas.set_saved_safe_location(saved.merged({"fixed_authored_checkpoint": true}, true)), "forged fixed checkpoint is rejected")
    _expect(not canvas.set_saved_safe_location(saved.merged({"travel_action_available": true}, true)), "forged map fast-travel action is rejected")
    _expect(not canvas.set_saved_safe_location(saved.merged({"position_tiles": Vector2(150.0, 150.0)}, true)), "saved marker outside discovered zone is rejected")
    _expect((canvas.saved_safe_location().get("position_tiles", Vector2.INF) as Vector2) == Vector2(60.0, 80.0), "invalid updates preserve last verified safe marker")
    _expect(menu._region_text(layer).contains("Saved safe position:") and menu._region_text(layer).contains("not a fixed checkpoint or fast travel"), "map text identifies provenance and forbids travel interpretation")
    _expect(canvas.set_saved_safe_location({}) and canvas.saved_safe_location().is_empty(), "opening a different map clears historical marker")
    menu.queue_free()
    layout.free()

    if _failures == 0:
        print("REGION 3 SAVED SAFE UI TEST PASS")
    else:
        push_error("REGION 3 SAVED SAFE UI TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, description: String) -> void:
    if ok:
        print("PASS: %s" % description)
    else:
        _failures += 1
        push_error("FAIL: %s" % description)
