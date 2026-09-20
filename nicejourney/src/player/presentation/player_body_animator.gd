class_name PlayerBodyAnimator
extends Node

const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_RUN: StringName = &"run"
const STATE_DASH: StringName = &"dash"
const STATE_DODGE: StringName = &"dodge"
const STATE_CLIMB: StringName = &"climb"

@export_node_path("Sprite2D") var body_path: NodePath = NodePath("../BodyVisual/Body")
@export_node_path("AnimationPlayer") var animation_player_path: NodePath = NodePath("../BodyAnimationPlayer")

@export_category("Locomotion animations")
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var run_animation: StringName = &"run"
@export var dash_animation: StringName = &"dash"
@export var dodge_animation: StringName = &"dodge"
@export var climb_animation: StringName = &"climb"

@export_category("Action animations")
@export var basic_attack_animation: StringName = &"attack"
@export var heavy_attack_animation: StringName = &"heavy_attack"
@export var basic_cast_animation: StringName = &"cast"

@export_category("Defense / reaction animations")
@export var block_animation: StringName = &"block"
@export var parry_animation: StringName = &"parry"
@export var hit_animation: StringName = &"hit"
@export var death_animation: StringName = &"death"

@export_category("Interaction animations")
@export var interact_animation: StringName = &"interact"
@export var pickup_animation: StringName = &"pickup"
@export var use_item_animation: StringName = &"use_item"
@export var sleep_animation: StringName = &"sleep"

@export_category("State thresholds")
@export_range(0.0, 5.0, 0.01) var stationary_speed_epsilon: float = 0.01
@export_range(0.0, 1.0, 0.05) var run_threshold_ratio: float = 0.5

var player: PlayerController = null
var body: Sprite2D = null
var animation_player: AnimationPlayer = null
var _state: StringName = &""
var _action_state_machine: ActionStateMachine = null
var _defense_runtime: ClassCombatRuntime = null
var _configured_class_id: StringName = &""
var _action_override: StringName = &""
var _block_active: bool = false
var _block_feedback_override: bool = false
var _parry_override: bool = false
var _reaction_override: StringName = &""
var _reaction_terminal: bool = false
var _interaction_override: StringName = &""


func _ready() -> void:
	player = get_parent() as PlayerController
	body = get_node_or_null(body_path) as Sprite2D
	animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	if body != null:
		body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if animation_player != null and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	_apply_state(STATE_IDLE, true)


func _process(_delta: float) -> void:
	if player == null or body == null or animation_player == null:
		return
	var requested: StringName = resolve_state(
		player.is_climbing(),
		player.is_dashing(),
		player.is_dodging(),
		player.velocity.length(),
		_walk_speed(),
		_run_speed()
	)
	if requested != _state:
		_state = requested
		_refresh_visible_animation(false)


func get_state() -> StringName:
	return _state


func get_action_override() -> StringName:
	return _action_override


func get_visible_semantic_animation() -> StringName:
	return _resolve_visible_animation()


func get_animation_player() -> AnimationPlayer:
	return animation_player


func validate_animation_setup() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if body == null:
		errors.append("body Sprite2D is unavailable")
	if animation_player == null:
		errors.append("AnimationPlayer is unavailable")
		return errors
	var required: Array[StringName] = [
		idle_animation,
		walk_animation,
		run_animation,
		dash_animation,
		dodge_animation,
		climb_animation,
		basic_attack_animation,
		heavy_attack_animation,
		basic_cast_animation,
		block_animation,
		parry_animation,
		hit_animation,
		death_animation,
		interact_animation,
		pickup_animation,
		use_item_animation,
		sleep_animation,
	]
	for animation_name: StringName in required:
		if animation_name == &"":
			errors.append("animation names cannot be empty")
		elif not animation_player.has_animation(animation_name):
			errors.append("missing AnimationPlayer animation: %s" % String(animation_name))
	return errors


func bind_action_state_machine(machine: ActionStateMachine, class_id: StringName) -> void:
	if _action_state_machine != null:
		if _action_state_machine.action_started.is_connected(_on_action_started):
			_action_state_machine.action_started.disconnect(_on_action_started)
		if _action_state_machine.action_finished.is_connected(_on_action_finished):
			_action_state_machine.action_finished.disconnect(_on_action_finished)
		if _action_state_machine.action_cancelled.is_connected(_on_action_cancelled):
			_action_state_machine.action_cancelled.disconnect(_on_action_cancelled)
		if _action_state_machine.action_interrupted.is_connected(_on_action_interrupted):
			_action_state_machine.action_interrupted.disconnect(_on_action_interrupted)
	_action_state_machine = machine
	_configured_class_id = class_id
	_action_override = &""
	if _action_state_machine == null:
		_refresh_visible_animation(false)
		return
	_action_state_machine.action_started.connect(_on_action_started)
	_action_state_machine.action_finished.connect(_on_action_finished)
	_action_state_machine.action_cancelled.connect(_on_action_cancelled)
	_action_state_machine.action_interrupted.connect(_on_action_interrupted)
	_refresh_visible_animation(false)


func bind_defense_runtime(runtime: ClassCombatRuntime) -> void:
	unbind_defense_runtime()
	_defense_runtime = runtime
	if _defense_runtime == null:
		return
	_defense_runtime.defense_mode_changed.connect(_on_defense_mode_changed)
	_defense_runtime.parry_started.connect(_on_parry_started)
	_block_active = _defense_runtime.get_defense_mode() == DirectHitResolver.DEFENSE_BLOCK
	_refresh_visible_animation(false)


func unbind_defense_runtime() -> void:
	if _defense_runtime != null:
		if _defense_runtime.defense_mode_changed.is_connected(_on_defense_mode_changed):
			_defense_runtime.defense_mode_changed.disconnect(_on_defense_mode_changed)
		if _defense_runtime.parry_started.is_connected(_on_parry_started):
			_defense_runtime.parry_started.disconnect(_on_parry_started)
	_defense_runtime = null
	_block_active = false


func play_hit_reaction() -> bool:
	if _reaction_terminal:
		return false
	_reaction_override = hit_animation
	_reaction_terminal = false
	_refresh_visible_animation(true)
	return true


func play_death_reaction() -> bool:
	_reaction_override = death_animation
	_reaction_terminal = true
	_parry_override = false
	_block_active = false
	_block_feedback_override = false
	_action_override = &""
	_interaction_override = &""
	_refresh_visible_animation(true)
	return true


func play_block_feedback() -> bool:
	if _reaction_terminal:
		return false
	_parry_override = false
	_block_feedback_override = true
	_refresh_visible_animation(true)
	return true


func play_parry_feedback() -> bool:
	if _reaction_terminal:
		return false
	_parry_override = true
	_refresh_visible_animation(true)
	return true


func play_committed_interaction(kind: StringName) -> bool:
	if _reaction_terminal:
		return false
	var animation_name: StringName = _interaction_animation_for_kind(kind)
	if animation_name == &"":
		return false
	_interaction_override = animation_name
	_refresh_visible_animation(true)
	return true


func resolve_state(
	climbing: bool,
	dashing: bool,
	dodging: bool,
	speed: float,
	walk_speed: float,
	run_speed: float
) -> StringName:
	if climbing:
		return STATE_CLIMB
	if dashing:
		return STATE_DASH
	if dodging:
		return STATE_DODGE
	if speed <= stationary_speed_epsilon:
		return STATE_IDLE
	var run_threshold: float = walk_speed + maxf(0.0, run_speed - walk_speed) * run_threshold_ratio
	if run_speed > walk_speed and speed >= run_threshold:
		return STATE_RUN
	return STATE_WALK


func _apply_state(state: StringName, force_restart: bool) -> void:
	_state = state
	_refresh_visible_animation(force_restart)


func _on_action_started(action_id: StringName, _action_instance_id: int) -> void:
	if action_id == StarterKitCatalog.BASIC_MAGE or _configured_class_id == StarterKitCatalog.CLASS_MAGE:
		_begin_action_override(basic_cast_animation)
	elif action_id == StarterKitCatalog.BASIC_MELEE or action_id == StarterKitCatalog.BASIC_RANGED:
		_begin_action_override(basic_attack_animation)


func _on_action_finished(_action_id: StringName, _action_instance_id: int) -> void:
	_end_action_override()


func _on_action_cancelled(_action_id: StringName, _action_instance_id: int, _reason: String) -> void:
	_end_action_override()


func _on_action_interrupted(_action_id: StringName, _action_instance_id: int, _reason_id: StringName) -> void:
	_end_action_override()


func _on_defense_mode_changed(mode: StringName) -> void:
	_block_active = mode == DirectHitResolver.DEFENSE_BLOCK
	if _block_active:
		_parry_override = false
	_refresh_visible_animation(_block_active)


func _on_parry_started(_window_ticks: int) -> void:
	play_parry_feedback()


func _on_animation_finished(animation_name: StringName) -> void:
	var changed: bool = false
	if _reaction_override == animation_name and not _reaction_terminal:
		_reaction_override = &""
		changed = true
	if _block_feedback_override and animation_name == block_animation:
		_block_feedback_override = false
		changed = true
	if _parry_override and animation_name == parry_animation:
		_parry_override = false
		changed = true
	if _interaction_override == animation_name:
		_interaction_override = &""
		changed = true
	if changed:
		_refresh_visible_animation(false)


func _begin_action_override(animation_name: StringName) -> void:
	_action_override = animation_name
	_refresh_visible_animation(true)


func _end_action_override() -> void:
	if _action_override == &"":
		return
	_action_override = &""
	_refresh_visible_animation(false)


func _refresh_visible_animation(force_restart: bool) -> void:
	_play_inspector_animation(_resolve_visible_animation(), force_restart)


func _resolve_visible_animation() -> StringName:
	if _reaction_override != &"":
		return _reaction_override
	if _parry_override:
		return parry_animation
	if _state == STATE_DODGE:
		return dodge_animation
	if _block_active or _block_feedback_override:
		return block_animation
	if _action_override != &"":
		return _action_override
	if _interaction_override != &"":
		return _interaction_override
	return _animation_for_state(_state)


func _play_inspector_animation(animation_name: StringName, force_restart: bool) -> void:
	if animation_player == null or animation_name == &"" or not animation_player.has_animation(animation_name):
		return
	if not force_restart and animation_player.current_animation == String(animation_name):
		return
	animation_player.play(animation_name)


func _animation_for_state(state: StringName) -> StringName:
	match state:
		STATE_WALK:
			return walk_animation
		STATE_RUN:
			return run_animation
		STATE_DASH:
			return dash_animation
		STATE_DODGE:
			return dodge_animation
		STATE_CLIMB:
			return climb_animation
		_:
			return idle_animation


func _interaction_animation_for_kind(kind: StringName) -> StringName:
	match kind:
		&"interact":
			return interact_animation
		&"pickup":
			return pickup_animation
		&"use_item":
			return use_item_animation
		&"sleep":
			return sleep_animation
		_:
			return &""


func _walk_speed() -> float:
	if player == null or player.movement == null or player.movement.tuning == null:
		return 0.0
	return player.movement.tuning.walk_speed


func _run_speed() -> float:
	if player == null or player.movement == null or player.movement.tuning == null:
		return 0.0
	return player.movement.tuning.run_speed
