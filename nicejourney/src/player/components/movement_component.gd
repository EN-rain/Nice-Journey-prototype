class_name MovementComponent
extends Node

enum BurstKind {
    NONE,
    DASH,
    DODGE,
}

signal burst_started(kind: BurstKind, duration: float)
signal burst_ended(kind: BurstKind)

@export var tuning: MovementTuning

var _burst_kind: BurstKind = BurstKind.NONE
var _burst_time_remaining: float = 0.0
var _burst_direction: Vector2 = Vector2.RIGHT
var _last_move_direction: Vector2 = Vector2.RIGHT
var _input_ownership: InputOwnership = null
var _run_toggle_enabled: bool = false
var _run_toggled: bool = false
# Applied to movement velocity only. Do not scale action, dodge, or AI clocks.
var _status_speed_multiplier: float = 1.0
var _burst_stamina_cost_modifier: Callable = Callable()


func set_burst_stamina_cost_modifier(modifier: Callable) -> void:
    _burst_stamina_cost_modifier = modifier


func set_status_speed_multiplier(multiplier: float) -> bool:
    if not is_finite(multiplier) or multiplier <= 0.0 or multiplier > 1.0:
        return false
    _status_speed_multiplier = multiplier
    return true


func get_status_speed_multiplier() -> float:
    return _status_speed_multiplier

func set_input_ownership(input_ownership: InputOwnership) -> void:
    _input_ownership = input_ownership

func tick(body: CharacterBody2D, stamina: StaminaComponent, delta: float) -> void:
    if tuning == null:
        body.velocity = Vector2.ZERO
        return
    if _burst_kind != BurstKind.NONE:
        _tick_burst(body, delta)
        return

    if _input_ownership != null and _input_ownership.is_modal_open():
        body.velocity = Vector2.ZERO
        body.move_and_slide()
        return

    var move_input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
    if move_input.length_squared() > 0.000001:
        move_input = move_input.normalized()
        _last_move_direction = move_input

    if _can_route_action(&"dodge") and Input.is_action_just_pressed(&"dodge") and try_start_dodge(stamina, move_input):
        _tick_burst(body, delta)
        return
    if _can_route_action(&"dash") and Input.is_action_just_pressed(&"dash") and try_start_dash(stamina, move_input):
        _tick_burst(body, delta)
        return

    var running: bool = false
    if _can_route_action(&"run"):
        running = resolve_run_active(Input.is_action_pressed(&"run"), Input.is_action_just_pressed(&"run"))
    body.velocity = calculate_move_velocity(move_input, running)
    body.move_and_slide()

func _can_route_action(action_id: StringName) -> bool:
    return _input_ownership == null or _input_ownership.can_route_gameplay_action(action_id)

func calculate_move_velocity(move_input: Vector2, running: bool) -> Vector2:
    if move_input.length_squared() <= 0.000001:
        return Vector2.ZERO
    if tuning == null:
        return Vector2.ZERO
    var target_speed: float = tuning.run_speed if running else tuning.walk_speed
    return move_input.normalized() * target_speed * _status_speed_multiplier

func set_run_toggle_enabled(enabled: bool) -> void:
    if _run_toggle_enabled == enabled:
        return
    _run_toggle_enabled = enabled
    _run_toggled = false

func is_run_toggle_enabled() -> bool:
    return _run_toggle_enabled

func is_run_toggled() -> bool:
    return _run_toggled

func resolve_run_active(run_pressed: bool, run_just_pressed: bool) -> bool:
    if not _run_toggle_enabled:
        return run_pressed
    if run_just_pressed:
        _run_toggled = not _run_toggled
    return _run_toggled

func try_start_dash(stamina: StaminaComponent, desired_direction: Vector2) -> bool:
    if tuning == null:
        return false
    return _try_start_burst(
        BurstKind.DASH,
        stamina,
        tuning.dash_stamina_cost,
        tuning.dash_duration,
        desired_direction
    )

func try_start_dodge(stamina: StaminaComponent, desired_direction: Vector2) -> bool:
    if tuning == null:
        return false
    return _try_start_burst(
        BurstKind.DODGE,
        stamina,
        tuning.dodge_stamina_cost,
        tuning.dodge_duration,
        desired_direction
    )

func is_dodging() -> bool:
    return _burst_kind == BurstKind.DODGE

func is_dashing() -> bool:
    return _burst_kind == BurstKind.DASH

func get_dodge_elapsed_seconds() -> float:
    if tuning == null or _burst_kind != BurstKind.DODGE:
        return -1.0
    return clampf(tuning.dodge_duration - _burst_time_remaining, 0.0, tuning.dodge_duration)

func get_burst_kind() -> BurstKind:
    return _burst_kind

func _try_start_burst(
    kind: BurstKind,
    stamina: StaminaComponent,
    stamina_cost: float,
    duration: float,
    desired_direction: Vector2
) -> bool:
    if _burst_kind != BurstKind.NONE:
        return false
    var actual_cost := stamina_cost
    if _burst_stamina_cost_modifier.is_valid():
        var modified: Variant = _burst_stamina_cost_modifier.call(stamina_cost)
        if not (typeof(modified) == TYPE_INT or typeof(modified) == TYPE_FLOAT) or not is_finite(float(modified)) or float(modified) < 0.0:
            return false
        actual_cost = float(modified)
    if not stamina.try_spend(actual_cost):
        return false

    var direction: Vector2 = desired_direction
    if direction.length_squared() <= 0.000001:
        direction = _last_move_direction
    _burst_direction = direction.normalized()
    _last_move_direction = _burst_direction
    _burst_kind = kind
    _burst_time_remaining = duration
    burst_started.emit(kind, duration)
    return true

func _tick_burst(body: CharacterBody2D, delta: float) -> void:
    if tuning == null:
        _burst_kind = BurstKind.NONE
        body.velocity = Vector2.ZERO
        return
    var speed: float = tuning.dash_speed if _burst_kind == BurstKind.DASH else tuning.dodge_speed
    body.velocity = _burst_direction * speed * _status_speed_multiplier
    body.move_and_slide()
    _burst_time_remaining = maxf(0.0, _burst_time_remaining - delta)
    if _burst_time_remaining <= 0.0:
        var completed_kind: BurstKind = _burst_kind
        _burst_kind = BurstKind.NONE
        body.velocity = Vector2.ZERO
        burst_ended.emit(completed_kind)
