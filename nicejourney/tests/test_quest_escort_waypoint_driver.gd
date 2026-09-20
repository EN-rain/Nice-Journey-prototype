extends SceneTree

const DRIVER_SCRIPT: Script = preload("res://src/quests/runtime/quest_escort_waypoint_driver.gd")
const PHYSICS_DELTA := 1.0 / 60.0
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var actor := _actor(&"EscortFollower")
    actor.global_position = Vector2(32, 32)
    root.add_child(actor)
    await physics_frame
    var driver: RefCounted = DRIVER_SCRIPT.new()
    var waypoints: Array[Dictionary] = [
        {"route_node_id": &"route:escort:a", "world_position": Vector2(32, 32)},
        {"route_node_id": &"route:escort:b", "world_position": Vector2(96, 32)},
        {"route_node_id": &"route:escort:goal", "world_position": Vector2(160, 32)},
    ]
    _expect(driver.configure(actor, waypoints, 320.0, 1.0).is_empty(), "escort waypoint driver accepts caller-authored route and movement tuning")
    _expect(driver.next_route_node_id() == &"route:escort:b", "configure consumes an already-reached starting route node without teleporting")
    var wait_position := actor.global_position
    var wait: Dictionary = driver.physics_step(PHYSICS_DELTA, true)
    _expect(bool(wait.get("accepted", false)) and wait.get("reason_id") == &"wait_requested", "explicit escort wait state pauses physical following")
    _expect(actor.global_position.is_equal_approx(wait_position) and actor.velocity.is_zero_approx(), "wait state cannot drift or teleport the actor")
    var invalid: Dictionary = driver.physics_step(0.0, false)
    _expect(not bool(invalid.get("accepted", true)) and invalid.get("reason_id") == &"invalid_delta", "invalid physics delta rejects without movement")

    var reached: Array[StringName] = [&"route:escort:a"]
    for _step: int in range(120):
        await physics_frame
        var result: Dictionary = driver.physics_step(PHYSICS_DELTA, false)
        for raw_id: Variant in result.get("reached_route_node_ids", []) as Array:
            reached.append(StringName(String(raw_id)))
        if bool(result.get("complete", false)):
            break
    _expect(driver.is_complete(), "escort waypoint driver physically reaches the final authored waypoint")
    _expect(reached == [&"route:escort:a", &"route:escort:b", &"route:escort:goal"], "route-node progress is emitted once in authored order")
    _expect(actor.global_position.distance_to(Vector2(160, 32)) <= 1.0 and actor.velocity.is_zero_approx(), "completed escort ends physically at the authored destination")

    actor.queue_free()
    await physics_frame
    var blocked_actor := _actor(&"BlockedEscort")
    blocked_actor.global_position = Vector2(32, 96)
    root.add_child(blocked_actor)
    var obstacle := _obstacle(Vector2(64, 96), Vector2(8, 48))
    root.add_child(obstacle)
    await physics_frame
    var blocked: RefCounted = DRIVER_SCRIPT.new()
    _expect(blocked.configure(blocked_actor, [
        {"route_node_id": &"route:blocked:start", "world_position": Vector2(32, 96)},
        {"route_node_id": &"route:blocked:goal", "world_position": Vector2(128, 96)},
    ], 320.0, 1.0).is_empty(), "blocked escort fixture configures")
    var collision_seen := false
    for _step: int in range(30):
        await physics_frame
        var result: Dictionary = blocked.physics_step(PHYSICS_DELTA, false)
        if bool(result.get("had_collision", false)):
            collision_seen = true
            _expect(result.get("reason_id") == &"physical_collision", "escort collision is explicit caller-owned repath/failure feedback")
            break
    _expect(collision_seen and not blocked.is_complete(), "physical blockage cannot silently complete or teleport the escort")
    _expect(blocked_actor.global_position.x < 128.0, "blocked escort remains on the physically reachable side of the obstacle")

    var resumed_actor := _actor(&"ResumedEscort")
    resumed_actor.global_position = Vector2(96, 160)
    root.add_child(resumed_actor)
    await physics_frame
    var resumed: RefCounted = DRIVER_SCRIPT.new()
    _expect(resumed.configure(resumed_actor, [
        {"route_node_id": &"route:resume:a", "world_position": Vector2(32, 160)},
        {"route_node_id": &"route:resume:b", "world_position": Vector2(96, 160)},
        {"route_node_id": &"route:resume:c", "world_position": Vector2(160, 160)},
    ], 320.0, 1.0, 2).is_empty(), "escort waypoint driver accepts an authoritative persisted next-route index")
    _expect(resumed.next_route_index() == 2 and resumed.next_route_node_id() == &"route:resume:c", "persisted route progress resumes at the next unresolved waypoint without backtracking")

    obstacle.queue_free()
    blocked_actor.queue_free()
    resumed_actor.queue_free()
    await process_frame
    if _failures == 0:
        print("QUEST ESCORT WAYPOINT DRIVER TEST PASS")
    else:
        push_error("QUEST ESCORT WAYPOINT DRIVER TEST FAILURES: %d" % _failures)
    quit(_failures)


func _actor(actor_name: StringName) -> CharacterBody2D:
    var actor := CharacterBody2D.new()
    actor.name = String(actor_name)
    actor.collision_layer = 1
    actor.collision_mask = 1
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(12, 10)
    collision.shape = shape
    actor.add_child(collision)
    return actor


func _obstacle(position: Vector2, size: Vector2) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = position
    body.collision_layer = 1
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    return body


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
