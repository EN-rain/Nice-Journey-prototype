class_name PixelCamera
extends Camera2D

@export var look_ahead_distance: float = 20.0
@export var look_ahead_response: float = 8.0
@export var follow_response: float = 8.0
@export_range(0.0, 0.25, 0.01) var horizontal_dead_zone: float = 0.04
@export_range(0.0, 0.25, 0.01) var vertical_dead_zone: float = 0.04
@export_range(0.0, 32.0, 0.5) var max_shake_distance: float = 6.0
@export_range(0.0, 1.0, 0.01) var max_shake_duration: float = 0.25

var _look_target: Vector2 = Vector2.ZERO
var _look_current: Vector2 = Vector2.ZERO
var _zoom_index: int = 0
var _world_bounds: Rect2 = Rect2()
var _world_bounds_enabled: bool = false
var _reduced_motion: bool = false
var _shake_enabled: bool = true
var _shake_intensity: float = 1.0
var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_time_remaining: float = 0.0
var _shake_elapsed: float = 0.0
var _reset_generation: int = 0
var _input_ownership: InputOwnership = null
var _follow_center: Vector2 = Vector2.ZERO
var _follow_initialized: bool = false

func _ready() -> void:
    top_level = true
    position_smoothing_enabled = false
    drag_horizontal_enabled = false
    drag_vertical_enabled = false
    set_zoom_step(0)
    var parent_2d: Node2D = get_parent() as Node2D
    if parent_2d != null:
        _follow_center = parent_2d.global_position
        _follow_initialized = true
        global_position = _follow_center.round()

func _process(delta: float) -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    var parent_2d: Node2D = get_parent() as Node2D
    if parent_2d != null:
        if not _follow_initialized:
            _follow_center = parent_2d.global_position
            _follow_initialized = true
        _follow_center = calculate_follow_center(_follow_center, parent_2d.global_position, viewport_size, delta)

    var look_blend: float = 1.0 - exp(-look_ahead_response * delta)
    _look_current = _look_current.lerp(_look_target, look_blend)
    var desired_center: Vector2 = _follow_center + _look_current + _tick_shake(delta)
    var bounded_center: Vector2 = calculate_bounded_center(desired_center, viewport_size)
    var quantized_center: Vector2 = bounded_center.round()
    global_position = calculate_bounded_center(quantized_center, viewport_size)
    offset = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
    if _input_ownership != null and _input_ownership.is_modal_open():
        return
    if event is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = event as InputEventMouseButton
        if not mouse_event.pressed:
            return
        if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
            set_zoom_step(_zoom_index + 1)
            get_viewport().set_input_as_handled()
        elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            set_zoom_step(_zoom_index - 1)
            get_viewport().set_input_as_handled()

func update_aim(aim_direction: Vector2) -> void:
    if _reduced_motion or aim_direction.length_squared() <= 0.000001:
        _look_target = Vector2.ZERO
        return
    _look_target = aim_direction.normalized() * look_ahead_distance

func set_input_ownership(input_ownership: InputOwnership) -> void:
    _input_ownership = input_ownership

func set_zoom_step(requested_index: int) -> void:
    _zoom_index = clampi(requested_index, 0, 1)
    var scale: float = 1.0 if _zoom_index == 0 else 2.0
    zoom = Vector2(scale, scale)
    _clamp_camera_immediately()

func get_zoom_step() -> int:
    return _zoom_index

func get_requested_look_ahead() -> Vector2:
    return _look_target

func set_world_bounds(bounds: Rect2) -> void:
    _world_bounds = bounds
    _world_bounds_enabled = bounds.size.x > 0.0 and bounds.size.y > 0.0
    _clamp_camera_immediately()

func clear_world_bounds() -> void:
    _world_bounds = Rect2()
    _world_bounds_enabled = false

func set_reduced_motion(enabled: bool) -> void:
    _reduced_motion = enabled
    if enabled:
        _look_target = Vector2.ZERO
        _look_current = Vector2.ZERO
        _clear_shake()
        offset = Vector2.ZERO

func is_reduced_motion_enabled() -> bool:
    return _reduced_motion

func set_shake_enabled(enabled: bool) -> void:
    _shake_enabled = enabled
    if not enabled:
        _clear_shake()

func set_shake_intensity(intensity: float) -> void:
    _shake_intensity = clampf(intensity, 0.0, 1.0)
    if is_zero_approx(_shake_intensity):
        _clear_shake()

func get_shake_intensity() -> float:
    return _shake_intensity

func request_shake(strength: float, duration: float) -> void:
    if not _shake_enabled or _reduced_motion or is_zero_approx(_shake_intensity):
        return
    _shake_strength = clampf(strength, 0.0, max_shake_distance) * _shake_intensity
    _shake_duration = clampf(duration, 0.0, max_shake_duration)
    _shake_time_remaining = _shake_duration
    _shake_elapsed = 0.0
    if _shake_strength <= 0.0 or _shake_duration <= 0.0:
        _clear_shake()

func get_shake_strength() -> float:
    return _shake_strength

func get_shake_time_remaining() -> float:
    return _shake_time_remaining

func get_reset_generation() -> int:
    return _reset_generation

func get_follow_center() -> Vector2:
    return _follow_center

func get_dead_zone_half_extents(viewport_size: Vector2) -> Vector2:
    var safe_zoom: Vector2 = Vector2(maxf(zoom.x, 0.0001), maxf(zoom.y, 0.0001))
    return Vector2(
        viewport_size.x * horizontal_dead_zone / safe_zoom.x,
        viewport_size.y * vertical_dead_zone / safe_zoom.y
    )

func calculate_follow_center(current_center: Vector2, target_position: Vector2, viewport_size: Vector2, delta: float) -> Vector2:
    var dead_zone: Vector2 = get_dead_zone_half_extents(viewport_size)
    var desired_center: Vector2 = current_center
    if target_position.x < current_center.x - dead_zone.x:
        desired_center.x = target_position.x + dead_zone.x
    elif target_position.x > current_center.x + dead_zone.x:
        desired_center.x = target_position.x - dead_zone.x
    if target_position.y < current_center.y - dead_zone.y:
        desired_center.y = target_position.y + dead_zone.y
    elif target_position.y > current_center.y + dead_zone.y:
        desired_center.y = target_position.y - dead_zone.y
    if follow_response <= 0.0:
        return desired_center
    var blend: float = 1.0 - exp(-follow_response * maxf(delta, 0.0))
    return current_center.lerp(desired_center, blend)

func calculate_bounded_center(desired_center: Vector2, viewport_size: Vector2) -> Vector2:
    if not _world_bounds_enabled:
        return desired_center
    var safe_zoom: Vector2 = Vector2(maxf(zoom.x, 0.0001), maxf(zoom.y, 0.0001))
    var half_visible: Vector2 = (viewport_size / safe_zoom) * 0.5
    var min_center: Vector2 = _world_bounds.position + half_visible
    var max_center: Vector2 = _world_bounds.end - half_visible
    var bounded_center: Vector2 = desired_center
    if min_center.x > max_center.x:
        bounded_center.x = _world_bounds.get_center().x
    else:
        bounded_center.x = clampf(desired_center.x, min_center.x, max_center.x)
    if min_center.y > max_center.y:
        bounded_center.y = _world_bounds.get_center().y
    else:
        bounded_center.y = clampf(desired_center.y, min_center.y, max_center.y)
    return bounded_center

func get_current_visible_world_rect() -> Rect2:
    var viewport_size: Vector2 = get_viewport_rect().size
    var safe_zoom: Vector2 = Vector2(maxf(zoom.x, 0.0001), maxf(zoom.y, 0.0001))
    var half_visible: Vector2 = (viewport_size / safe_zoom) * 0.5
    var screen_center: Vector2 = get_screen_center_position()
    return Rect2(screen_center - half_visible, half_visible * 2.0)

func viewport_point_to_world(viewport_point: Vector2) -> Vector2:
    return get_canvas_transform().affine_inverse() * viewport_point

func is_current_visible_rect_within_bounds(epsilon: float = 0.01) -> bool:
    if not _world_bounds_enabled:
        return true
    var visible_rect: Rect2 = get_current_visible_world_rect()
    return (
        visible_rect.position.x >= _world_bounds.position.x - epsilon
        and visible_rect.position.y >= _world_bounds.position.y - epsilon
        and visible_rect.end.x <= _world_bounds.end.x + epsilon
        and visible_rect.end.y <= _world_bounds.end.y + epsilon
    )

func calculate_bounded_offset(target_global_position: Vector2, desired_offset: Vector2, viewport_size: Vector2) -> Vector2:
    var desired_center: Vector2 = target_global_position + desired_offset
    var bounded_center: Vector2 = calculate_bounded_center(desired_center, viewport_size)
    return (bounded_center - target_global_position).round()

func reset_after_teleport() -> void:
    _look_target = Vector2.ZERO
    _look_current = Vector2.ZERO
    _clear_shake()
    offset = Vector2.ZERO
    var parent_2d: Node2D = get_parent() as Node2D
    if parent_2d != null:
        _follow_center = parent_2d.global_position
        _follow_initialized = true
        global_position = calculate_bounded_center(_follow_center, get_viewport_rect().size)
    _reset_generation += 1
    reset_smoothing()

func _tick_shake(delta: float) -> Vector2:
    if _shake_time_remaining <= 0.0 or _shake_strength <= 0.0:
        return Vector2.ZERO
    _shake_elapsed += delta
    _shake_time_remaining = maxf(0.0, _shake_time_remaining - delta)
    var remaining_ratio: float = 0.0
    if _shake_duration > 0.0:
        remaining_ratio = clampf(_shake_time_remaining / _shake_duration, 0.0, 1.0)
    var amplitude: float = _shake_strength * remaining_ratio
    var phase: float = _shake_elapsed * 47.0
    var result: Vector2 = Vector2(sin(phase), cos(phase * 1.37)) * amplitude
    if _shake_time_remaining <= 0.0:
        _clear_shake()
    return result

func _clear_shake() -> void:
    _shake_strength = 0.0
    _shake_duration = 0.0
    _shake_time_remaining = 0.0
    _shake_elapsed = 0.0

func _clamp_camera_immediately() -> void:
    if not is_inside_tree():
        return
    global_position = calculate_bounded_center(global_position, get_viewport_rect().size)
