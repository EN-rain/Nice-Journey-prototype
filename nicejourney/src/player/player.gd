class_name PlayerController
extends CharacterBody2D

@export_range(0.0, 0.5, 0.01) var vertical_facing_dead_zone: float = 0.15
@export_range(0.05, 1.0, 0.05) var climb_transition_seconds: float = 0.15
@export_range(-1.0, 0.0, 0.01) var weapon_behind_aim_y_threshold: float = -0.2
@export_range(-128, 128, 1) var weapon_base_z_index: int = 0

@onready var stamina: StaminaComponent = $StaminaComponent
@onready var health: HealthComponent = $HealthComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var ground_anchor: Marker2D = $GroundAnchor
@onready var body_visual: Node2D = $BodyVisual
@onready var grip_anchor: Marker2D = $GripAnchor
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var body_animator: PlayerBodyAnimator = $PlayerBodyAnimator
@onready var starter_weapon_visual: StarterWeaponVisual = $StarterWeaponVisual
@onready var combat_effects: PlayerCombatEffectController = $PlayerCombatEffectController
@onready var combat_outcome_effects: CombatOutcomeEffectController = $CombatOutcomeEffectController
@onready var runtime_presentation_binder: PlayerRuntimePresentationBinder = $PlayerRuntimePresentationBinder
@onready var camera: PixelCamera = $PixelCamera

var _body_facing: int = 1
var _aim_direction: Vector2 = Vector2.RIGHT
var _grip_base_position: Vector2 = Vector2.ZERO
var _input_ownership: InputOwnership = null
var _active_climb_links: Array[ClimbLink] = []
var _climb_link_in_progress: ClimbLink = null
var _climb_source_position: Vector2 = Vector2.ZERO
var _climb_time_remaining: float = 0.0
var _is_climbing: bool = false
var _status_movement_tuning: StatusPlaytestTuning = null
var _status_movement_states_provider: Callable = Callable()

func _ready() -> void:
    _grip_base_position = grip_anchor.position
    apply_aim_direction(Vector2.RIGHT)

func _physics_process(delta: float) -> void:
    _refresh_status_movement_multiplier()
    if _is_climbing:
        velocity = Vector2.ZERO
        _climb_time_remaining = maxf(0.0, _climb_time_remaining - delta)
        if _climb_time_remaining <= 0.0:
            _finish_climb()
        return
    movement.tick(self, stamina, delta)

func _process(_delta: float) -> void:
    var mouse_world: Vector2 = camera.viewport_point_to_world(get_viewport().get_mouse_position())
    var mouse_aim: Vector2 = mouse_world - global_position
    apply_pointer_aim_direction(mouse_aim)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_released(&"interact") and _input_ownership != null:
        _input_ownership.notify_action_released(&"interact")
    if event.is_action_pressed(&"interact") and try_start_climb():
        get_viewport().set_input_as_handled()

func set_status_movement_provider(tuning: StatusPlaytestTuning, states_provider: Callable) -> void:
    _status_movement_tuning = tuning
    _status_movement_states_provider = states_provider
    _refresh_status_movement_multiplier()


func set_passive_skill_runtime(runtime: RefCounted) -> void:
    var stamina_regeneration := Callable()
    var movement_cost := Callable()
    if runtime != null and runtime.has_method(&"modify_stamina_regeneration") and runtime.has_method(&"modify_movement_stamina_cost"):
        stamina_regeneration = Callable(runtime, &"modify_stamina_regeneration")
        movement_cost = Callable(runtime, &"modify_movement_stamina_cost")
    stamina.set_regeneration_modifier(stamina_regeneration)
    movement.set_burst_stamina_cost_modifier(movement_cost)


func _refresh_status_movement_multiplier() -> void:
    var multiplier := 1.0
    if _status_movement_tuning != null and _status_movement_tuning.validate_tuning().is_empty() and _status_movement_states_provider.is_valid():
        var raw_states: Variant = _status_movement_states_provider.call()
        if raw_states is Array:
            multiplier = _status_movement_tuning.slow_speed_multiplier(raw_states as Array)
    movement.set_status_speed_multiplier(multiplier)


func set_input_ownership(input_ownership: InputOwnership) -> void:
    _input_ownership = input_ownership
    movement.set_input_ownership(input_ownership)
    camera.set_input_ownership(input_ownership)

func configure_starter_visuals(
    class_id: StringName,
    action_state_machine: ActionStateMachine = null,
    class_combat_runtime: ClassCombatRuntime = null
) -> bool:
    if starter_weapon_visual == null or not starter_weapon_visual.configure_class(class_id):
        return false
    if body_animator != null:
        body_animator.bind_action_state_machine(action_state_machine, class_id)
        body_animator.bind_defense_runtime(class_combat_runtime)
    if combat_effects != null and action_state_machine != null:
        combat_effects.bind_action_state_machine(action_state_machine)
    return true


func bind_combat_runtime(runtime: CombatEncounterRuntime, actor_id: StringName) -> bool:
    if runtime_presentation_binder == null or combat_outcome_effects == null:
        return false
    var body_bound: bool = runtime_presentation_binder.bind_runtime(runtime, actor_id)
    var effects_bound: bool = combat_outcome_effects.bind_runtime(runtime, actor_id)
    if body_bound and effects_bound:
        return true
    runtime_presentation_binder.unbind_runtime()
    combat_outcome_effects.unbind_runtime()
    return false


func unbind_combat_runtime() -> void:
    if runtime_presentation_binder != null:
        runtime_presentation_binder.unbind_runtime()
    if combat_outcome_effects != null:
        combat_outcome_effects.unbind_runtime()


func present_committed_interaction(kind: StringName) -> bool:
    return body_animator != null and body_animator.play_committed_interaction(kind)

func apply_pointer_aim_direction(direction: Vector2) -> bool:
    if _input_ownership != null and _input_ownership.is_modal_open():
        camera.update_aim(Vector2.ZERO)
        return false
    apply_aim_direction(direction)
    return true

func apply_aim_direction(direction: Vector2) -> void:
    if direction.length_squared() > 0.000001:
        _aim_direction = direction.normalized()
    _body_facing = FacingResolver.resolve_horizontal_facing(
        _body_facing,
        _aim_direction,
        vertical_facing_dead_zone
    )
    body_visual.scale = Vector2(float(_body_facing), 1.0)
    grip_anchor.position = Vector2(absf(_grip_base_position.x) * float(_body_facing), _grip_base_position.y)
    weapon_pivot.position = grip_anchor.position
    weapon_pivot.rotation = _aim_direction.angle()
    weapon_pivot.z_index = weapon_base_z_index
    _update_weapon_local_order(_aim_direction.y < weapon_behind_aim_y_threshold)
    camera.update_aim(_aim_direction)

func get_body_facing() -> int:
    return _body_facing

func get_aim_direction() -> Vector2:
    return _aim_direction

func is_dodging() -> bool:
    return movement.is_dodging()

func is_dashing() -> bool:
    return movement.is_dashing()

func is_climbing() -> bool:
    return _is_climbing

func set_active_climb_link(link: ClimbLink) -> void:
    if link == null or _active_climb_links.has(link):
        return
    _active_climb_links.append(link)

func clear_active_climb_link(link: ClimbLink) -> void:
    _active_climb_links.erase(link)

func get_active_climb_link_count() -> int:
    _prune_invalid_climb_links()
    return _active_climb_links.size()

func try_start_climb() -> bool:
    if _is_climbing:
        return false
    if movement.is_dashing() or movement.is_dodging():
        return false
    if _input_ownership != null and not _input_ownership.can_route_gameplay_action(&"interact"):
        return false
    var climb_link: ClimbLink = _get_usable_climb_link()
    if climb_link == null:
        return false
    _is_climbing = true
    _climb_link_in_progress = climb_link
    _climb_source_position = global_position
    _climb_time_remaining = climb_transition_seconds
    velocity = Vector2.ZERO
    return true

func can_occupy_global_position(candidate_position: Vector2) -> bool:
    if collision_shape == null or collision_shape.shape == null or collision_shape.disabled:
        return false
    var body_transform: Transform2D = global_transform
    body_transform.origin = candidate_position
    var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
    query.shape = collision_shape.shape
    query.transform = body_transform * collision_shape.transform
    query.collision_mask = collision_mask
    query.collide_with_bodies = true
    query.collide_with_areas = false
    query.exclude = [get_rid()]
    return get_world_2d().direct_space_state.intersect_shape(query, 8).is_empty()

func is_weapon_behind_body() -> bool:
    return weapon_pivot.get_index() < body_visual.get_index()

func _update_weapon_local_order(behind_body: bool) -> void:
    var body_index: int = body_visual.get_index()
    if behind_body:
        if weapon_pivot.get_index() > body_index:
            move_child(weapon_pivot, body_index)
        return
    body_index = body_visual.get_index()
    if weapon_pivot.get_index() < body_index:
        move_child(weapon_pivot, body_index + 1)

func _get_usable_climb_link() -> ClimbLink:
    _prune_invalid_climb_links()
    for index: int in range(_active_climb_links.size() - 1, -1, -1):
        var link: ClimbLink = _active_climb_links[index]
        if link.can_player_use(self):
            return link
    return null

func _prune_invalid_climb_links() -> void:
    for index: int in range(_active_climb_links.size() - 1, -1, -1):
        var link: ClimbLink = _active_climb_links[index]
        if link == null or not is_instance_valid(link):
            _active_climb_links.remove_at(index)

func _finish_climb() -> void:
    var success: bool = false
    if _climb_link_in_progress != null and is_instance_valid(_climb_link_in_progress) and _climb_link_in_progress.can_player_use(self):
        global_position = _climb_link_in_progress.get_landing_global_position()
        camera.reset_after_teleport()
        success = true
    if not success:
        global_position = _climb_source_position
    _is_climbing = false
    _climb_time_remaining = 0.0
    _climb_link_in_progress = null
