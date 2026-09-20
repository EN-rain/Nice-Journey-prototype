extends SceneTree

const MAP_REGION_CANVAS_SCRIPT: Script = preload("res://src/ui/map_region_canvas.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var canvas := MAP_REGION_CANVAS_SCRIPT.new() as Control
    canvas.name = "MapRegionCanvasFixture"
    canvas.size = Vector2(320, 120)
    root.add_child(canvas)
    await process_frame

    var routes: Array = [
        {"route_name": &"SouthApproach", "points_tiles": PackedVector2Array([Vector2(91, 112), Vector2(91, 95), Vector2(92, 95)])},
        {"route_name": &"CirculationLoop", "points_tiles": PackedVector2Array([Vector2(68, 65), Vector2(92, 65), Vector2(92, 95), Vector2(68, 95), Vector2(68, 65)])},
    ]
    var landmarks: Array = [
        {"landmark_id": &"r3:functional:01", "landmark_kind": &"central_tower", "position_tiles": Vector2(80.0, 73.5)},
    ]
    var explored_subzones: Array = [
        {"zone_id": &"R3-TOWN", "tile_rect": Rect2i(48, 48, 64, 64)},
        {"zone_id": &"R3-OUTSKIRTS", "tile_rect": Rect2i(48, 112, 64, 32)},
    ]
    _expect(bool(canvas.call("configure_geometry", Vector2i(160, 160), Rect2i(48, 48, 64, 64), Rect2i(69, 81, 23, 13), routes, landmarks, explored_subzones)), "Region map canvas accepts authored tile-space geometry plus validated explored subzones")
    _expect(int(canvas.call("route_count")) == 2, "Region map canvas preserves supplied route count")
    _expect(int(canvas.call("landmark_count")) == 1, "Region map canvas preserves the public landmark count")
    _expect(int(canvas.call("explored_subzone_count")) == 2, "Region map canvas preserves only supplied explored-subzone geometry")
    var scoped_risk := {"zone_id": &"R3-OUTSKIRTS", "tile_rect": Rect2i(48, 112, 64, 32), "recommended_level": 2, "player_level": 1, "danger_display": "Risk"}
    _expect(bool(canvas.call("set_risk_markers", [scoped_risk])), "Region canvas accepts only an explicitly authored risk marker inside an explored zone")
    _expect(int(canvas.call("risk_marker_count")) == 1, "Region canvas has one visible explored risk marker")
    var detached_risks := canvas.call("risk_markers") as Array
    (detached_risks[0] as Dictionary)["recommended_level"] = 99
    _expect(int(((canvas.call("risk_markers") as Array)[0] as Dictionary).get("recommended_level", 0)) == 2, "risk markers return detached read-only geometry and recommendation")
    _expect(not bool(canvas.call("set_risk_markers", [{"zone_id": &"R3-HIDDEN", "tile_rect": Rect2i(5, 5, 10, 10), "recommended_level": 9}])), "undiscovered region risk geometry cannot be injected into the canvas")
    _expect(not bool(canvas.call("set_risk_markers", [{"zone_id": &"R3-OUTSKIRTS", "tile_rect": Rect2i(48, 112, 64, 32), "recommended_level": -1}])), "unauthored concrete recommended level is not presented as danger")
    _expect(not bool(canvas.call("set_risk_markers", [{"zone_id": &"R3-OUTSKIRTS", "tile_rect": Rect2i(48, 112, 64, 32), "recommended_level": 2.5}])), "fractional recommended levels cannot silently truncate into UI danger data")
    _expect(int(canvas.call("risk_marker_count")) == 1, "rejected risk marker changes leave the previous valid view unchanged")
    var normalized_routes := canvas.call("route_polylines") as Array
    _expect(StringName((normalized_routes[0] as Dictionary).get("route_name", &"")) == &"CirculationLoop", "Region map canvas orders route identities deterministically")
    var normalized_landmarks := canvas.call("public_landmarks") as Array
    _expect(StringName((normalized_landmarks[0] as Dictionary).get("landmark_id", &"")) == &"r3:functional:01", "Region map canvas preserves the exact Central Tower landmark identity")

    var detached_routes := canvas.call("route_polylines") as Array
    (detached_routes[0] as Dictionary)["points_tiles"] = PackedVector2Array([Vector2.ZERO, Vector2.ONE])
    _expect(((canvas.call("route_polylines") as Array)[0] as Dictionary).get("points_tiles") != PackedVector2Array([Vector2.ZERO, Vector2.ONE]), "callers cannot mutate the Region canvas route snapshot")
    var detached_landmarks := canvas.call("public_landmarks") as Array
    (detached_landmarks[0] as Dictionary)["position_tiles"] = Vector2(1, 1)
    _expect(((canvas.call("public_landmarks") as Array)[0] as Dictionary).get("position_tiles") == Vector2(80.0, 73.5), "callers cannot mutate the Region canvas landmark snapshot")
    var detached_subzones := canvas.call("explored_subzones") as Array
    (detached_subzones[0] as Dictionary)["tile_rect"] = Rect2i(1, 1, 1, 1)
    _expect(((canvas.call("explored_subzones") as Array)[0] as Dictionary).get("tile_rect") != Rect2i(1, 1, 1, 1), "callers cannot mutate the Region canvas explored-subzone snapshot")

    _expect(not bool(canvas.call("configure_geometry", Vector2i.ZERO, Rect2i(48, 48, 64, 64), Rect2i(69, 81, 23, 13), routes, landmarks)), "Region map canvas rejects a non-positive map reservation")
    _expect(int(canvas.call("route_count")) == 2, "rejected Region geometry preserves the previous valid snapshot")
    _expect(not bool(canvas.call("configure_geometry", Vector2i(160, 160), Rect2i(48, 48, 64, 64), Rect2i(69, 81, 23, 13), [
        {"route_name": &"BadRoute", "points_tiles": PackedVector2Array([Vector2(1, 1), Vector2(200, 1)])},
    ], landmarks)), "Region map canvas rejects route points outside the authored map reservation")
    _expect(not bool(canvas.call("configure_geometry", Vector2i(160, 160), Rect2i(48, 48, 64, 64), Rect2i(69, 81, 23, 13), [
        {"route_name": &"Duplicate", "points_tiles": PackedVector2Array([Vector2(1, 1), Vector2(2, 2)])},
        {"route_name": &"Duplicate", "points_tiles": PackedVector2Array([Vector2(3, 3), Vector2(4, 4)])},
    ], landmarks)), "Region map canvas rejects duplicate route names")
    _expect(not bool(canvas.call("configure_geometry", Vector2i(160, 160), Rect2i(48, 48, 64, 64), Rect2i(69, 81, 23, 13), routes, [
        {"landmark_id": &"bad id", "landmark_kind": &"central_tower", "position_tiles": Vector2(80, 73.5)},
    ])), "Region map canvas rejects invalid landmark identities")
    _expect(not bool(canvas.call("configure_geometry", Vector2i(160, 160), Rect2i(48, 48, 64, 64), Rect2i(69, 81, 23, 13), routes, landmarks, [
        {"zone_id": &"R3-TOWN", "tile_rect": Rect2i(48, 48, 64, 64)},
        {"zone_id": &"R3-TOWN", "tile_rect": Rect2i(48, 48, 64, 64)},
    ])), "Region map canvas rejects duplicate explored-zone identities")

    canvas.queue_redraw()
    await process_frame
    _expect(int(canvas.call("route_count")) == 2 and int(canvas.call("landmark_count")) == 1 and int(canvas.call("explored_subzone_count")) == 2, "drawing Region map geometry does not mutate its data")
    canvas.call("clear_geometry")
    _expect(int(canvas.call("route_count")) == 0 and int(canvas.call("landmark_count")) == 0 and int(canvas.call("explored_subzone_count")) == 0 and int(canvas.call("risk_marker_count")) == 0, "Region map canvas clears authored/explored/risk geometry explicitly")

    canvas.queue_free()
    await process_frame
    if _failures == 0:
        print("MAP REGION CANVAS TEST PASS")
    else:
        push_error("MAP REGION CANVAS TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
