extends SceneTree

const TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const TILE_SIZE := 32.0
const MAP_SIZE := Vector2i(160, 160)
const TOWN_RECT := Rect2i(48, 48, 64, 64)
const WEST_ROAD_RECT := Rect2i(16, 64, 32, 64)
const NORTH_RUINS_RECT := Rect2i(40, 16, 72, 32)
const SOUTH_OUTSKIRTS_RECT := Rect2i(48, 112, 64, 32)
const EAST_RISK_RECT := Rect2i(112, 40, 32, 72)

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var town := TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    root.add_child(town)
    await process_frame
    await physics_frame

    _expect(town != null, "Region 3 authored town instantiates with physical structure collision")
    if town == null:
        quit(_failures)
        return

    var collision_layer := town.get_node_or_null("StructureCollisionLayer") as Node2D
    var collider_root := town.get_node_or_null("StructureCollisionLayer/StructureColliders") as Node2D
    var world_bounds := town.get_node_or_null("StructureCollisionLayer/WorldBounds") as Node2D
    _expect(collision_layer != null, "authored town owns a scene-authored collision layer")
    _expect(collider_root != null, "collision layer owns structure colliders")
    _expect(world_bounds != null and world_bounds.get_child_count() == 4, "collision layer owns four non-traversable world-edge walls")

    var player_probe := PLAYER_SCENE.instantiate() as CharacterBody2D
    var player_collision := player_probe.get_node_or_null("CollisionShape2D") as CollisionShape2D
    _expect(player_collision != null and player_collision.shape != null, "Region 3 traversal QA resolves the real player collision footprint")

    var colliders: Dictionary = {}
    var blocked: Dictionary = {}
    if collider_root != null:
        _expect(collider_root.get_child_count() == 20, "collision layer contains exactly one collider for each of the 20 structures")
        for child: Node in collider_root.get_children():
            var collider := child as Region3StructureCollider
            _expect(collider != null, "%s is a Region3StructureCollider" % child.name)
            if collider == null:
                continue
            _expect(collider.validate_collider().is_empty(), "%s collider geometry validates" % String(collider.structure_id))
            _expect(not colliders.has(collider.structure_id), "%s collider identity is unique" % String(collider.structure_id))
            colliders[collider.structure_id] = collider
            for y: int in range(collider.collision_tile_min.y, collider.collision_tile_max.y + 1):
                for x: int in range(collider.collision_tile_min.x, collider.collision_tile_max.x + 1):
                    blocked[Vector2i(x, y)] = true
            _expect(_physics_point_has_body(town, collider.global_position), "%s collider participates in the physics world" % String(collider.structure_id))
            var min_center := Vector2(collider.collision_tile_min) * TILE_SIZE
            var max_center := Vector2(collider.collision_tile_max) * TILE_SIZE
            _expect(_physics_point_has_body(town, min_center), "%s inclusive minimum collision tile center is physically solid" % String(collider.structure_id))
            _expect(_physics_point_has_body(town, max_center), "%s inclusive maximum collision tile center is physically solid" % String(collider.structure_id))
            var inside_max_corner := (Vector2(collider.collision_tile_max) + Vector2(0.49, 0.49)) * TILE_SIZE
            _expect(_physics_point_has_body(town, inside_max_corner), "%s inclusive maximum collision tile occupies its full authored tile footprint" % String(collider.structure_id))

    for child: Node in town.get_children():
        var anchor := child as Region3TownStructureAnchor
        if anchor == null:
            continue
        _expect(colliders.has(anchor.structure_id), "%s has a matching physical collider" % String(anchor.structure_id))
        if not colliders.has(anchor.structure_id):
            continue
        var collider: Region3StructureCollider = colliders[anchor.structure_id]
        _expect(collider.collision_tile_min.x >= anchor.lot_min.x and collider.collision_tile_min.y >= anchor.lot_min.y, "%s collision starts inside its reserved lot" % String(anchor.structure_id))
        _expect(collider.collision_tile_max.x <= anchor.lot_max.x and collider.collision_tile_max.y <= anchor.lot_max.y, "%s collision ends inside its reserved lot" % String(anchor.structure_id))
        if anchor.category == Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
            _expect(not collider.contains_tile(anchor.entrance_tile), "%s working entrance tile remains outside solid building collision" % String(anchor.structure_id))
            _expect(not collider.contains_tile(anchor.approach_tile), "%s exterior approach tile remains outside solid building collision" % String(anchor.structure_id))
            _expect(not _physics_point_has_body(town, anchor.entrance_world_position(TILE_SIZE)), "%s working entrance center remains physically open" % String(anchor.structure_id))
            _expect(not _physics_point_has_body(town, anchor.approach_world_position(TILE_SIZE)), "%s exterior approach is physically reachable" % String(anchor.structure_id))
            if player_collision != null and player_collision.shape != null:
                _expect(_player_footprint_is_clear(town, anchor.entrance_world_position(TILE_SIZE), player_collision), "%s working entrance fits the actual player collision footprint" % String(anchor.structure_id))
                _expect(_player_footprint_is_clear(town, anchor.approach_world_position(TILE_SIZE), player_collision), "%s exterior approach fits the actual player collision footprint" % String(anchor.structure_id))

    var routes := town.get_node_or_null("Routes") as Node2D
    _expect(routes != null, "collision-aware traversal reuses the authored route network")
    if routes != null:
        for route_child: Node in routes.get_children():
            var line := route_child as Line2D
            if line == null:
                continue
            _expect(_route_centerline_clear(line, blocked), "%s centerline does not cross solid structure collision" % line.name)
            if player_collision != null and player_collision.shape != null:
                _expect(_route_player_footprint_clear(town, line, player_collision), "%s centerline physically fits the actual player collision footprint" % line.name)

        var tower_goal := Vector2i(80, 81)
        for route_name: String in ["NorthApproach", "SouthApproach", "WestApproach"]:
            var line := routes.get_node_or_null(route_name) as Line2D
            if line == null or line.points.is_empty():
                _expect(false, "%s exists for collision-aware traversal" % route_name)
                continue
            var start := _world_to_tile(line.points[0])
            _expect(_has_tile_path(start, tower_goal, blocked, false), "%s reaches the tower/plaza without entering the optional east-risk pocket" % route_name)
        var east := routes.get_node_or_null("EastApproach") as Line2D
        if east != null and not east.points.is_empty():
            _expect(_has_tile_path(_world_to_tile(east.points[0]), tower_goal, blocked, true), "EastApproach reaches the town through collision-aware traversal")
        else:
            _expect(false, "EastApproach exists for collision-aware traversal")

        for child: Node in town.get_children():
            var anchor := child as Region3TownStructureAnchor
            if anchor == null or anchor.category != Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
                continue
            _expect(_has_tile_path(tower_goal, anchor.approach_tile, blocked, false), "%s service approach is reachable from the plaza without the optional risk zone" % String(anchor.structure_id))

    _validate_world_bounds(world_bounds)

    player_probe.free()
    town.queue_free()
    if _failures == 0:
        print("REGION 3 COLLISION TRAVERSAL TEST PASS")
    else:
        push_error("REGION 3 COLLISION TRAVERSAL TEST FAILURES: %d" % _failures)
    quit(_failures)

func _physics_point_has_body(town: Node2D, world_position: Vector2) -> bool:
    var query := PhysicsPointQueryParameters2D.new()
    query.position = world_position
    query.collision_mask = 1
    query.collide_with_bodies = true
    query.collide_with_areas = false
    return not town.get_world_2d().direct_space_state.intersect_point(query, 32).is_empty()

func _route_centerline_clear(line: Line2D, blocked: Dictionary) -> bool:
    for index: int in range(line.points.size() - 1):
        var start := line.points[index]
        var finish := line.points[index + 1]
        var distance := start.distance_to(finish)
        var steps := maxi(1, int(ceil(distance / TILE_SIZE)))
        for step: int in range(steps + 1):
            var point := start.lerp(finish, float(step) / float(steps))
            if blocked.has(_world_to_tile(point)):
                return false
    return true

func _route_player_footprint_clear(town: Node2D, line: Line2D, player_collision: CollisionShape2D) -> bool:
    for index: int in range(line.points.size() - 1):
        var start := line.to_global(line.points[index])
        var finish := line.to_global(line.points[index + 1])
        var distance := start.distance_to(finish)
        var steps := maxi(1, int(ceil(distance / 8.0)))
        for step: int in range(steps + 1):
            var ground_position := start.lerp(finish, float(step) / float(steps))
            if not _player_footprint_is_clear(town, ground_position, player_collision):
                return false
    return true

func _player_footprint_is_clear(town: Node2D, ground_position: Vector2, player_collision: CollisionShape2D) -> bool:
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = player_collision.shape
    query.transform = Transform2D(0.0, ground_position + player_collision.position)
    query.collision_mask = 1
    query.collide_with_bodies = true
    query.collide_with_areas = false
    return town.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _has_tile_path(start: Vector2i, goal: Vector2i, blocked: Dictionary, allow_east_risk: bool) -> bool:
    if not _is_walkable_zone(start, allow_east_risk) or not _is_walkable_zone(goal, allow_east_risk):
        return false
    if blocked.has(start) or blocked.has(goal):
        return false
    var visited: Dictionary = {start: true}
    var frontier: Array[Vector2i] = [start]
    var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
    while not frontier.is_empty():
        var current: Vector2i = frontier.pop_front()
        if current == goal:
            return true
        for direction: Vector2i in directions:
            var candidate := current + direction
            if candidate.x < 0 or candidate.y < 0 or candidate.x >= MAP_SIZE.x or candidate.y >= MAP_SIZE.y:
                continue
            if visited.has(candidate) or blocked.has(candidate) or not _is_walkable_zone(candidate, allow_east_risk):
                continue
            visited[candidate] = true
            frontier.append(candidate)
    return false

func _is_walkable_zone(tile: Vector2i, allow_east_risk: bool) -> bool:
    if TOWN_RECT.has_point(tile) or WEST_ROAD_RECT.has_point(tile) or NORTH_RUINS_RECT.has_point(tile) or SOUTH_OUTSKIRTS_RECT.has_point(tile):
        return true
    return allow_east_risk and EAST_RISK_RECT.has_point(tile)

func _world_to_tile(point: Vector2) -> Vector2i:
    return Vector2i(roundi(point.x / TILE_SIZE), roundi(point.y / TILE_SIZE))

func _validate_world_bounds(world_bounds: Node2D) -> void:
    if world_bounds == null:
        return
    var expected := {
        "Top": Vector2(2544, -16),
        "Bottom": Vector2(2544, 5104),
        "Left": Vector2(-16, 2544),
        "Right": Vector2(5104, 2544),
    }
    for wall_name: String in expected:
        var wall := world_bounds.get_node_or_null(wall_name) as StaticBody2D
        _expect(wall != null, "%s world-edge wall exists" % wall_name)
        if wall == null:
            continue
        _expect(wall.position.is_equal_approx(expected[wall_name]), "%s world-edge wall stays on the 160x160 authored boundary" % wall_name)
        var shape := wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
        _expect(shape != null and shape.shape is RectangleShape2D, "%s world-edge wall owns physical rectangle collision" % wall_name)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
