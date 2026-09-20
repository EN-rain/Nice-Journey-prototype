extends SceneTree

const MAP_ROOM_CANVAS_SCRIPT: Script = preload("res://src/ui/map_room_canvas.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var canvas := MAP_ROOM_CANVAS_SCRIPT.new() as Control
    canvas.name = "MapRoomCanvasFixture"
    canvas.size = Vector2(320, 120)
    root.add_child(canvas)
    await process_frame

    var entries: Array = [
        {"room_instance_id": &"room:zeta", "rect": Rect2i(20, 10, 8, 6)},
        {"room_instance_id": &"room:alpha", "rect": Rect2i(2, 3, 6, 5)},
    ]
    _expect(bool(canvas.call("set_room_entries", entries)), "map room canvas accepts discovered room summaries")
    _expect(int(canvas.call("visible_room_count")) == 2, "map room canvas counts only supplied discovered rooms")
    var normalized: Array = canvas.call("room_entries") as Array
    _expect(StringName((normalized[0] as Dictionary).get("room_instance_id", &"")) == &"room:alpha", "map room canvas orders stable room identities deterministically")
    _expect(StringName((normalized[1] as Dictionary).get("room_instance_id", &"")) == &"room:zeta", "map room canvas preserves the full supplied discovered set")
    var connections: Array = [
        {"from_room_id": &"room:zeta", "to_room_id": &"room:alpha"},
    ]
    _expect(bool(canvas.call("set_room_connections", connections)), "map room canvas accepts connections only between visible discovered rooms")
    var normalized_connections := canvas.call("room_connections") as Array
    _expect(normalized_connections.size() == 1 and StringName((normalized_connections[0] as Dictionary).get("from_room_id", &"")) == &"room:alpha" and StringName((normalized_connections[0] as Dictionary).get("to_room_id", &"")) == &"room:zeta", "map room canvas canonicalizes visible connection endpoints deterministically")
    _expect(not bool(canvas.call("set_room_connections", [{"from_room_id": &"room:alpha", "to_room_id": &"room:hidden"}])), "map room canvas rejects connections to rooms absent from the visible discovered set")
    _expect((canvas.call("room_connections") as Array).size() == 1, "rejected room-connection input preserves the previous valid connection set")
    var risk_markers: Array = [
        {"room_instance_id": &"room:alpha", "risk_id": &"risk:combat"},
        {"room_instance_id": &"room:zeta", "risk_id": &"risk:boss"},
    ]
    _expect(bool(canvas.call("set_risk_markers", risk_markers)), "map room canvas accepts stable risk markers only for visible discovered rooms")
    var normalized_risks := canvas.call("risk_markers") as Array
    _expect(normalized_risks.size() == 2 and StringName((normalized_risks[0] as Dictionary).get("room_instance_id", &"")) == &"room:alpha", "map room canvas keeps risk markers deterministically ordered by visible room")
    _expect(not bool(canvas.call("set_risk_markers", [{"room_instance_id": &"room:hidden", "risk_id": &"risk:boss"}])), "map room canvas rejects risk markers for undiscovered rooms")
    _expect((canvas.call("risk_markers") as Array).size() == 2, "rejected risk-marker input preserves the previous valid risk set")
    var markers: Array = [
        {"checkpoint_id": &"checkpoint:alpha", "room_instance_id": &"room:alpha", "world_tile": Vector2i(3, 4)},
    ]
    _expect(bool(canvas.call("set_checkpoint_markers", markers)), "map room canvas accepts checkpoint markers only after discovered room geometry is present")
    var normalized_markers := canvas.call("checkpoint_markers") as Array
    _expect(normalized_markers.size() == 1 and StringName((normalized_markers[0] as Dictionary).get("checkpoint_id", &"")) == &"checkpoint:alpha", "map room canvas preserves the exact visible checkpoint identity")
    _expect(not bool(canvas.call("set_checkpoint_markers", [{"checkpoint_id": &"checkpoint:hidden", "room_instance_id": &"room:alpha", "world_tile": Vector2i(99, 99)}])), "map room canvas rejects checkpoint markers outside their visible discovered room")
    _expect((canvas.call("checkpoint_markers") as Array).size() == 1, "rejected checkpoint marker input preserves the previous valid marker set")
    _expect(bool(canvas.call("set_player_marker", Vector2(3.5, 4.5))), "map room canvas accepts the player marker only inside visible discovered room geometry")
    _expect(bool(canvas.call("player_marker_visible")) and (canvas.call("player_marker_tile") as Vector2).is_equal_approx(Vector2(3.5, 4.5)), "player marker preserves the exact visible tile position")
    _expect(not bool(canvas.call("set_player_marker", Vector2(14.5, 14.5))), "map room canvas rejects a player position outside all visible discovered rooms")
    _expect((canvas.call("player_marker_tile") as Vector2).is_equal_approx(Vector2(3.5, 4.5)), "rejected hidden-space player marker does not replace the last valid visible position")
    canvas.call("clear_player_marker")
    _expect(not bool(canvas.call("player_marker_visible")), "player marker can be explicitly hidden without clearing discovered room data")

    var detached: Array = canvas.call("room_entries") as Array
    (detached[0] as Dictionary)["rect"] = Rect2i(99, 99, 1, 1)
    _expect((canvas.call("room_entries") as Array)[0]["rect"] == Rect2i(2, 3, 6, 5), "callers cannot mutate the canvas room snapshot")

    var detached_connections := canvas.call("room_connections") as Array
    (detached_connections[0] as Dictionary)["from_room_id"] = &"room:mutated"
    _expect(StringName((canvas.call("room_connections") as Array)[0]["from_room_id"]) == &"room:alpha", "callers cannot mutate the canvas connection snapshot")

    var detached_risks := canvas.call("risk_markers") as Array
    (detached_risks[0] as Dictionary)["risk_id"] = &"risk:mutated"
    _expect(StringName((canvas.call("risk_markers") as Array)[0]["risk_id"]) == &"risk:combat", "callers cannot mutate the canvas risk-marker snapshot")

    var detached_markers := canvas.call("checkpoint_markers") as Array
    (detached_markers[0] as Dictionary)["world_tile"] = Vector2i(77, 77)
    _expect((canvas.call("checkpoint_markers") as Array)[0]["world_tile"] == Vector2i(3, 4), "callers cannot mutate the canvas checkpoint snapshot")

    _expect(not bool(canvas.call("set_room_entries", [{"room_instance_id": &"room:bad"}])), "map room canvas rejects room entries without authored geometry")
    _expect(int(canvas.call("visible_room_count")) == 2, "rejected canvas input leaves the previous valid discovered set intact")
    _expect(not bool(canvas.call("set_room_entries", [
        {"room_instance_id": &"room:duplicate", "rect": Rect2i(0, 0, 2, 2)},
        {"room_instance_id": &"room:duplicate", "rect": Rect2i(3, 0, 2, 2)},
    ])), "map room canvas rejects duplicate stable room identities")
    _expect(not bool(canvas.call("set_room_entries", [{"room_instance_id": &"room:zero", "rect": Rect2i(0, 0, 0, 2)}])), "map room canvas rejects non-positive room geometry")
    _expect(not bool(canvas.call("set_room_connections", [
        {"from_room_id": &"room:alpha", "to_room_id": &"room:zeta"},
        {"from_room_id": &"room:zeta", "to_room_id": &"room:alpha"},
    ])), "map room canvas rejects duplicate undirected connection identities")
    _expect(not bool(canvas.call("set_risk_markers", [
        {"room_instance_id": &"room:alpha", "risk_id": &"risk:combat"},
        {"room_instance_id": &"room:alpha", "risk_id": &"risk:elite"},
    ])), "map room canvas rejects duplicate risk markers for one room")
    _expect(not bool(canvas.call("set_checkpoint_markers", [
        {"checkpoint_id": &"checkpoint:duplicate", "room_instance_id": &"room:alpha", "world_tile": Vector2i(3, 4)},
        {"checkpoint_id": &"checkpoint:duplicate", "room_instance_id": &"room:zeta", "world_tile": Vector2i(21, 11)},
    ])), "map room canvas rejects duplicate checkpoint identities")

    canvas.queue_redraw()
    await process_frame
    _expect(int(canvas.call("visible_room_count")) == 2, "drawing auto-fit geometry does not mutate discovered-room data")
    canvas.call("clear_rooms")
    _expect(int(canvas.call("visible_room_count")) == 0, "map room canvas clears discovered geometry explicitly")
    _expect((canvas.call("room_connections") as Array).is_empty(), "clearing discovered rooms also clears visible connections")
    _expect((canvas.call("risk_markers") as Array).is_empty(), "clearing discovered rooms also clears visible risk markers")
    _expect((canvas.call("checkpoint_markers") as Array).is_empty(), "clearing discovered rooms also clears visible checkpoint markers")
    _expect(not bool(canvas.call("player_marker_visible")), "clearing discovered rooms also clears the player marker")

    canvas.queue_free()
    await process_frame
    if _failures == 0:
        print("MAP ROOM CANVAS TEST PASS")
    else:
        push_error("MAP ROOM CANVAS TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
