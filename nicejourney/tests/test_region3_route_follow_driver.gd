extends SceneTree

const TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const ROUTE_FOLLOW_SCRIPT: Script = preload("res://src/world/region3/layout/region3_route_follow_driver.gd")

const START_OFF_ROUTE := Vector2(2940, 3400)
const SOUTH_ROUTE_GOAL := Vector2(2912, 3040)
const PHYSICS_DELTA := 1.0 / 60.0

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var town := TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    root.add_child(town)
    await process_frame
    await physics_frame

    _expect(town != null, "Region 3 route-follow fixture instantiates")
    if town == null:
        quit(1)
        return

    var navigator := town.get_node_or_null("RouteNavigator")
    _expect(navigator != null and navigator.is_ready_for_navigation(), "route-follow driver receives the ready scene-owned navigator")
    if navigator == null or not navigator.is_ready_for_navigation():
        town.queue_free()
        quit(1)
        return

    var actor := _make_actor("RouteFollower")
    actor.global_position = START_OFF_ROUTE
    root.add_child(actor)
    await physics_frame

    var driver: RefCounted = ROUTE_FOLLOW_SCRIPT.new()
    var errors: PackedStringArray = driver.configure(actor, navigator, SOUTH_ROUTE_GOAL, 640.0, 1.0, 64.0)
    _expect(errors.is_empty(), "route-follow driver configures from a caller-authored actor, goal and movement tolerances")
    _expect(driver.last_reason_id() == &"rejoin_required", "off-route configuration preserves explicit rejoin-required feedback")
    _expect(driver.current_waypoint().is_equal_approx(Vector2(2912, 3400)), "off-route follower targets the explicit route rejoin point first")

    var before_wait := actor.global_position
    var wait_result: Dictionary = driver.physics_step(PHYSICS_DELTA, true)
    _expect(bool(wait_result.get("accepted", false)) and StringName(wait_result.get("reason_id", &"")) == &"wait_requested", "caller wait state pauses route following explicitly")
    _expect(actor.global_position.is_equal_approx(before_wait) and actor.velocity.is_zero_approx(), "wait state does not move the actor")

    var invalid_delta_result: Dictionary = driver.physics_step(0.0, false)
    _expect(not bool(invalid_delta_result.get("accepted", true)) and StringName(invalid_delta_result.get("reason_id", &"")) == &"invalid_delta", "route-follow driver rejects non-positive physics delta")
    _expect(actor.global_position.is_equal_approx(before_wait) and actor.velocity.is_zero_approx(), "invalid delta cannot move the actor")

    await physics_frame
    var first_move: Dictionary = driver.physics_step(PHYSICS_DELTA, false)
    _expect(bool(first_move.get("accepted", false)), "route-follow driver advances through ordinary CharacterBody2D physics")
    _expect(float(first_move.get("moved_distance_px", 0.0)) > 0.0, "route-follow step reports physical movement")
    _expect(not actor.global_position.is_equal_approx(Vector2(2912, 3400)), "first rejoin step does not teleport the separated actor onto the route")
    _expect(not bool(first_move.get("had_collision", true)), "clear rejoin step reports no physical collision")

    var completed := false
    for _step: int in range(180):
        await physics_frame
        var result: Dictionary = driver.physics_step(PHYSICS_DELTA, false)
        if bool(result.get("complete", false)):
            completed = true
            break
    _expect(completed and driver.is_complete(), "route-follow driver physically reaches the caller-authored route goal")
    _expect(actor.global_position.distance_to(SOUTH_ROUTE_GOAL) <= 1.0, "completed route follower ends within the caller-authored arrival tolerance")
    _expect(actor.velocity.is_zero_approx(), "completed route follower stops movement")

    actor.queue_free()
    await physics_frame

    var blocked_actor := _make_actor("BlockedRouteFollower")
    blocked_actor.global_position = START_OFF_ROUTE
    root.add_child(blocked_actor)
    var obstacle := _make_obstacle(Vector2(2926, 3400), Vector2(8, 40))
    root.add_child(obstacle)
    await physics_frame

    var blocked_driver: RefCounted = ROUTE_FOLLOW_SCRIPT.new()
    _expect(blocked_driver.configure(blocked_actor, navigator, SOUTH_ROUTE_GOAL, 640.0, 1.0, 64.0).is_empty(), "blocked route follower still configures from valid authored navigation")
    var blocked_before := blocked_actor.global_position
    var blocked_step: Dictionary = blocked_driver.physics_step(PHYSICS_DELTA, false)
    _expect(bool(blocked_step.get("accepted", false)), "physical blockage is reported without turning movement into a quest failure")
    _expect(bool(blocked_step.get("had_collision", false)), "route-follow step exposes physical collision for caller-owned repath/failure policy")
    _expect(StringName(blocked_step.get("reason_id", &"")) == &"physical_collision", "physical blockage exposes an explicit repath-feedback reason")
    _expect(blocked_actor.global_position.distance_to(Vector2(2912, 3400)) > 1.0, "blocked follower cannot teleport through collision to its route rejoin point")
    _expect(blocked_actor.global_position.distance_to(blocked_before) < blocked_before.distance_to(Vector2(2912, 3400)), "blocked follower can only make the physically permitted partial movement")

    obstacle.queue_free()
    await physics_frame
    _expect(blocked_driver.replan_from_actor(), "caller can explicitly replan from the actor's real post-collision position")
    _expect(blocked_driver.last_reason_id() == &"rejoin_required", "post-collision repath preserves explicit rejoin-required feedback")
    var recovered := false
    for _step: int in range(180):
        await physics_frame
        var result: Dictionary = blocked_driver.physics_step(PHYSICS_DELTA, false)
        if bool(result.get("complete", false)):
            recovered = true
            break
    _expect(recovered and blocked_driver.is_complete(), "route follower resumes and reaches the authored goal after caller-owned repath")
    _expect(blocked_actor.global_position.distance_to(SOUTH_ROUTE_GOAL) <= 1.0, "repath recovery remains physical and ends within the authored arrival tolerance")

    var far_actor := _make_actor("FarRouteFollower")
    far_actor.global_position = Vector2(4000, 4000)
    root.add_child(far_actor)
    await physics_frame
    var far_driver: RefCounted = ROUTE_FOLLOW_SCRIPT.new()
    var far_errors: PackedStringArray = far_driver.configure(far_actor, navigator, SOUTH_ROUTE_GOAL, 640.0, 1.0, 32.0)
    _expect(not far_errors.is_empty(), "route-follow configuration rejects actors beyond the caller-authorized rejoin distance")
    _expect(far_driver.last_reason_id() == &"", "failed configuration resets driver ownership instead of retaining a half-configured movement plan")
    var far_before := far_actor.global_position
    var far_step: Dictionary = far_driver.physics_step(PHYSICS_DELTA, false)
    _expect(not bool(far_step.get("accepted", true)) and StringName(far_step.get("reason_id", &"")) == &"not_configured", "failed configuration cannot later move the actor")
    _expect(far_actor.global_position.is_equal_approx(far_before), "rejected off-network actor remains physically unchanged")

    blocked_actor.queue_free()
    far_actor.queue_free()
    town.queue_free()
    await process_frame

    if _failures == 0:
        print("REGION 3 ROUTE FOLLOW DRIVER TEST PASS")
    else:
        push_error("REGION 3 ROUTE FOLLOW DRIVER TEST FAILURES: %d" % _failures)
    quit(_failures)


func _make_actor(actor_name: String) -> CharacterBody2D:
    var actor := CharacterBody2D.new()
    actor.name = actor_name
    actor.collision_layer = 1
    actor.collision_mask = 1
    var collision := CollisionShape2D.new()
    collision.position = Vector2(0, -5)
    var shape := RectangleShape2D.new()
    shape.size = Vector2(12, 10)
    collision.shape = shape
    actor.add_child(collision)
    return actor


func _make_obstacle(world_position: Vector2, size: Vector2) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.name = "RouteFollowObstacle"
    body.position = world_position
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
