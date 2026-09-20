extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var gameplay: Node2D = GAMEPLAY_SCENE.instantiate() as Node2D
    root.add_child(gameplay)
    var player: PlayerController = gameplay.get_node("Player") as PlayerController
    var movement: MovementComponent = player.get_node("MovementComponent") as MovementComponent
    var stamina: StaminaComponent = player.get_node("StaminaComponent") as StaminaComponent
    var camera: PixelCamera = player.get_node("PixelCamera") as PixelCamera
    var ground_anchor: Marker2D = player.get_node("GroundAnchor") as Marker2D
    var grip_anchor: Marker2D = player.get_node("GripAnchor") as Marker2D
    var weapon_pivot: Node2D = player.get_node("WeaponPivot") as Node2D
    var center_block: StaticBody2D = gameplay.get_node("CenterBlock") as StaticBody2D
    var center_visual: Polygon2D = center_block.get_node("Visual") as Polygon2D
    var occluder_visual: Polygon2D = center_block.get_node("OccluderVisual") as Polygon2D
    var center_collision: CollisionShape2D = center_block.get_node("CollisionShape2D") as CollisionShape2D
    var occluder: ForegroundOccluder = center_block.get_node("Occluder") as ForegroundOccluder
    var climb_link: ClimbLink = gameplay.get_node("ClimbLink") as ClimbLink
    var climb_landing: Marker2D = climb_link.get_node("Landing") as Marker2D
    var input_ownership: InputOwnership = gameplay.get_node("InputOwnership") as InputOwnership

    _expect(gameplay.y_sort_enabled, "gameplay world sorts actors and foreground geometry from ground anchors")
    _expect(ground_anchor.position == Vector2.ZERO, "player ground anchor remains at the authoritative foot position")

    player.apply_aim_direction(Vector2.LEFT)
    _expect(player.get_body_facing() == -1, "left aim flips the side-only body left")
    _expect(grip_anchor.position.x < 0.0 and weapon_pivot.position == grip_anchor.position, "grip mirrors with body facing while weapon aim keeps a separate transform")
    player.apply_aim_direction(Vector2.UP)
    _expect(player.get_body_facing() == -1, "near-vertical aim retains the previous body facing")
    _expect(player.is_weapon_behind_body(), "upward aim places the weapon behind the body locally")
    player.apply_aim_direction(Vector2.RIGHT)
    _expect(player.get_body_facing() == 1, "right aim flips the body right")
    _expect(grip_anchor.position.x > 0.0 and weapon_pivot.position == grip_anchor.position, "right-facing grip mirrors without changing collision")
    player.apply_aim_direction(Vector2.DOWN)
    _expect(is_equal_approx(weapon_pivot.rotation, PI / 2.0), "weapon aim remains independent and continuous while body stays side-only")
    _expect(not player.is_weapon_behind_body(), "downward aim places the weapon in front of the body locally")
    _expect(weapon_pivot.z_index == 0, "local weapon ordering does not globally outrank foreground walls")

    camera.set_zoom_step(0)
    _expect(camera.zoom == Vector2.ONE, "camera zoom step 0 is pixel-safe 1x")
    camera.set_zoom_step(1)
    _expect(camera.zoom == Vector2(2.0, 2.0), "camera zoom step 1 is pixel-safe 2x")
    camera.set_zoom_step(99)
    _expect(camera.get_zoom_step() == 1, "camera clamps to authored zoom steps")
    var viewport_size: Vector2 = Vector2(640, 360)
    camera.set_zoom_step(0)
    var dead_zone_1x: Vector2 = camera.get_dead_zone_half_extents(viewport_size)
    _expect(dead_zone_1x.x > 0.0 and dead_zone_1x.y > 0.0, "camera uses a small authored follow dead zone on both axes")
    var dead_zone_center: Vector2 = Vector2(320, 180)
    var inside_dead_zone: Vector2 = camera.calculate_follow_center(dead_zone_center, dead_zone_center + dead_zone_1x * 0.5, viewport_size, 1.0 / 60.0)
    _expect(inside_dead_zone == dead_zone_center, "camera follow center stays stable while the player remains inside the dead zone")
    var outside_dead_zone: Vector2 = camera.calculate_follow_center(dead_zone_center, dead_zone_center + Vector2(dead_zone_1x.x * 2.0, 0), viewport_size, 1.0 / 60.0)
    _expect(outside_dead_zone.x > dead_zone_center.x, "camera follow center begins smoothing once the player exits the dead zone")
    camera.set_zoom_step(1)
    var dead_zone_2x: Vector2 = camera.get_dead_zone_half_extents(viewport_size)
    _expect(is_equal_approx(dead_zone_2x.x, dead_zone_1x.x * 0.5) and is_equal_approx(dead_zone_2x.y, dead_zone_1x.y * 0.5), "screen-space dead zone converts correctly to world units at 2x zoom")

    camera.set_zoom_step(0)
    camera.set_world_bounds(Rect2(0, 0, 640, 360))
    var full_room_offset: Vector2 = camera.calculate_bounded_offset(Vector2(160, 180), Vector2(20, 0), Vector2(640, 360))
    _expect(full_room_offset == Vector2(160, 0), "1x camera clamps the final visible rectangle to the greybox bounds")
    camera.set_zoom_step(1)
    var right_edge_offset: Vector2 = camera.calculate_bounded_offset(Vector2(620, 180), Vector2(20, 0), Vector2(640, 360))
    _expect(right_edge_offset == Vector2(-140, 0), "2x look-ahead cannot reveal space beyond the right world boundary")

    camera.set_zoom_step(0)
    player.position = Vector2(20, 20)
    camera.update_aim(Vector2.LEFT)
    camera.request_shake(camera.max_shake_distance, camera.max_shake_duration)
    for frame: int in range(4):
        await process_frame
        _expect(camera.is_current_visible_rect_within_bounds(), "actual 1x camera visible rectangle stays inside bounds during follow/look-ahead/shake")
    var world_probe_1x: Vector2 = Vector2(220, 140)
    var viewport_probe_1x: Vector2 = camera.get_canvas_transform() * world_probe_1x
    _expect(camera.viewport_point_to_world(viewport_probe_1x).distance_to(world_probe_1x) < 0.01, "aim coordinate conversion round-trips at 1x and a clamped boundary")

    camera.set_zoom_step(1)
    player.position = Vector2(620, 340)
    camera.update_aim(Vector2.RIGHT)
    camera.request_shake(camera.max_shake_distance, camera.max_shake_duration)
    for frame: int in range(4):
        await process_frame
        _expect(camera.is_current_visible_rect_within_bounds(), "actual 2x camera visible rectangle stays inside bounds during follow/look-ahead/shake")
    var world_probe_2x: Vector2 = Vector2(520, 260)
    var viewport_probe_2x: Vector2 = camera.get_canvas_transform() * world_probe_2x
    _expect(camera.viewport_point_to_world(viewport_probe_2x).distance_to(world_probe_2x) < 0.01, "aim coordinate conversion round-trips at 2x and a clamped boundary")
    var resized_center: Vector2 = camera.calculate_bounded_center(Vector2(620, 180), Vector2(800, 450))
    _expect(is_equal_approx(resized_center.x, 440.0), "camera bound math accounts for a wider supported viewport without revealing past the right edge")

    camera.clear_world_bounds()
    camera.set_zoom_step(1)
    camera.set_reduced_motion(false)
    camera.update_aim(Vector2.RIGHT * 1000.0)
    _expect(is_equal_approx(camera.get_requested_look_ahead().length(), camera.look_ahead_distance), "camera look-ahead stays capped independent of cursor distance")
    camera.request_shake(999.0, 999.0)
    _expect(is_equal_approx(camera.get_shake_strength(), camera.max_shake_distance), "camera shake strength is intensity-limited")
    _expect(is_equal_approx(camera.get_shake_time_remaining(), camera.max_shake_duration), "camera shake duration is bounded")
    camera.reset_after_teleport()
    _expect(camera.offset == Vector2.ZERO and is_zero_approx(camera.get_shake_strength()), "teleport reset clears camera interpolation and shake history")
    camera.set_reduced_motion(true)
    camera.update_aim(Vector2.RIGHT)
    camera.request_shake(4.0, 0.2)
    await process_frame
    _expect(camera.offset == Vector2.ZERO and is_zero_approx(camera.get_shake_strength()), "reduced motion disables camera look-ahead and shake")
    camera.set_reduced_motion(false)
    camera.set_world_bounds(Rect2(0, 0, 640, 360))

    for zoom_index: int in [0, 1]:
        camera.set_zoom_step(zoom_index)
        player.position = Vector2(384, 168)
        occluder.update_occlusion_for_world_point(player.global_position)
        _expect(occluder.is_occluded() and occluder_visual.modulate.a < 1.0, "foreground wall fades when it obscures the player ground anchor at zoom %d" % zoom_index)
        _expect(is_equal_approx(center_visual.modulate.a, 1.0), "wall base remains visible while only the obscuring foreground fades at zoom %d" % zoom_index)
        _expect(not center_collision.disabled, "wall transparency never disables authoritative collision at zoom %d" % zoom_index)
        player.apply_aim_direction(Vector2.UP)
        _expect(player.is_weapon_behind_body() and weapon_pivot.z_index == 0, "weapon stays locally behind without escaping world sort at zoom %d" % zoom_index)
        player.apply_aim_direction(Vector2.DOWN)
        _expect(not player.is_weapon_behind_body() and weapon_pivot.z_index == 0, "weapon stays locally in front without escaping world sort at zoom %d" % zoom_index)
        occluder.update_occlusion_for_world_point(Vector2(100, 100))
        _expect(not occluder.is_occluded() and is_equal_approx(occluder_visual.modulate.a, 1.0), "foreground wall restores full opacity after occlusion clears at zoom %d" % zoom_index)

    player.position = Vector2(260, 100)
    await physics_frame
    _expect(not player.try_start_climb(), "climb cannot trigger away from an authored interaction link")

    player.position = climb_link.position
    await physics_frame
    await physics_frame
    input_ownership.open_modal(&"inventory")
    _expect(not player.try_start_climb(), "modal input ownership blocks the Interact climb action")
    input_ownership.close_modal(&"inventory")

    camera.clear_world_bounds()
    camera.update_aim(Vector2.RIGHT)
    var camera_reset_generation_before_climb: int = camera.get_reset_generation()
    var climb_source: Vector2 = player.global_position
    _expect(player.try_start_climb(), "valid authored climb link starts the greybox climb transition")
    Input.action_press(&"move_right")
    Input.action_press(&"dash")
    await physics_frame
    _expect(player.is_climbing() and player.global_position == climb_source, "movement input cannot move the player during climb")
    _expect(not movement.is_dashing(), "dash input cannot overlap an active climb")
    Input.action_release(&"move_right")
    Input.action_release(&"dash")
    for frame: int in range(12):
        await physics_frame
    _expect(not player.is_climbing() and player.global_position.distance_to(climb_landing.global_position) < 0.1, "climb exits exactly at the validated landing anchor")
    _expect(camera.get_reset_generation() == camera_reset_generation_before_climb + 1, "climb traversal resets camera interpolation history")

    var valid_landing_position: Vector2 = climb_landing.global_position
    player.position = climb_link.position
    await physics_frame
    await physics_frame
    var mid_climb_source: Vector2 = player.global_position
    var reset_generation_before_failed_commit: int = camera.get_reset_generation()
    _expect(player.try_start_climb(), "climb can begin while its landing is initially valid")
    await physics_frame
    await physics_frame
    climb_landing.global_position = Vector2(384, 208)
    for frame: int in range(12):
        await physics_frame
    _expect(not player.is_climbing() and player.global_position == mid_climb_source, "landing revalidation at climb completion returns to source if the destination becomes blocked")
    _expect(camera.get_reset_generation() == reset_generation_before_failed_commit, "failed climb completion does not commit a camera teleport reset")
    climb_landing.global_position = valid_landing_position

    player.position = climb_link.position
    await physics_frame
    await physics_frame
    climb_landing.global_position = Vector2(384, 208)
    var blocked_source: Vector2 = player.global_position
    _expect(not player.try_start_climb(), "climb rejects a landing whose lower-body footprint is blocked")
    _expect(player.global_position == blocked_source, "blocked climb leaves the player at the source instead of penetrating geometry")
    climb_landing.global_position = valid_landing_position
    climb_link.player_compatible = false
    _expect(not player.try_start_climb(), "incompatible authored climb links reject player traversal")
    climb_link.player_compatible = true

    var overlapping_link: ClimbLink = ClimbLink.new()
    var overlapping_landing: Marker2D = Marker2D.new()
    overlapping_landing.name = "Landing"
    overlapping_landing.position = Vector2(0, 32)
    overlapping_link.add_child(overlapping_landing)
    gameplay.add_child(overlapping_link)
    player.set_active_climb_link(climb_link)
    player.set_active_climb_link(overlapping_link)
    _expect(player.get_active_climb_link_count() >= 2, "overlapping authored climb links are tracked without replacing the prior link")
    player.clear_active_climb_link(overlapping_link)
    _expect(player.get_active_climb_link_count() >= 1, "leaving one overlapping climb link preserves another link that is still active")
    overlapping_link.queue_free()
    camera.set_world_bounds(Rect2(0, 0, 640, 360))

    var diagonal_velocity: Vector2 = movement.calculate_move_velocity(Vector2(1.0, 1.0), false)
    _expect(absf(diagonal_velocity.length() - movement.tuning.walk_speed) < 0.5, "diagonal input is normalized to the walk speed")
    _expect(absf(absf(diagonal_velocity.x) - absf(diagonal_velocity.y)) < 0.5, "diagonal components are equal")

    stamina.restore_full()
    var dash_started: bool = movement.try_start_dash(stamina, Vector2.RIGHT)
    _expect(dash_started, "dash starts when stamina is available")
    _expect(stamina.current_stamina < stamina.get_max_stamina(), "dash spends stamina once")
    _expect(movement.is_dashing(), "dash and dodge have distinct movement states")
    var post_dash_stamina: float = stamina.current_stamina
    var nested_dodge: bool = movement.try_start_dodge(stamina, Vector2.RIGHT)
    _expect(not nested_dodge, "a dodge cannot silently cancel an active dash")
    _expect(is_equal_approx(post_dash_stamina, stamina.current_stamina), "rejected nested burst does not spend stamina")
    _expect(movement.tuning.dash_speed * movement.tuning.dash_duration > movement.tuning.dodge_speed * movement.tuning.dodge_duration, "dash has longer authored displacement than dodge")

    for frame: int in range(20):
        await physics_frame

    stamina.restore_full()
    var dodge_started: bool = movement.try_start_dodge(stamina, Vector2.LEFT)
    _expect(dodge_started and movement.is_dodging(), "dodge starts as the defensive burst state")

    for frame: int in range(20):
        await physics_frame

    player.position = Vector2(330, 208)
    stamina.restore_full()
    movement.try_start_dash(stamina, Vector2.RIGHT)
    for frame: int in range(20):
        await physics_frame
    _expect(player.position.x <= 346.5, "blocked dash stops at collision instead of tunneling through the greybox obstacle")

    Input.action_release(&"move_up")
    Input.action_release(&"move_down")
    Input.action_release(&"move_left")
    Input.action_release(&"move_right")
    Input.action_release(&"run")
    Input.action_release(&"dash")
    Input.action_release(&"dodge")

    gameplay.queue_free()
    if _failures == 0:
        print("M1 TEST PASS")
    else:
        push_error("M1 TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
