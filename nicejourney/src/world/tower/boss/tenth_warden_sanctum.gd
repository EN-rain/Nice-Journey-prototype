class_name TenthWardenSanctum
extends Node2D

signal terminal_outcome_committed(outcome_id: StringName)
signal boss_active_delivery_window_opened(context: Dictionary)

@export var encounter_id: StringName = &"encounter:tenth_warden_floor_10"
@export var arena_size: Vector2 = Vector2(448.0, 256.0)
@export_range(4.0, 64.0, 1.0) var boundary_thickness: float = 16.0
@export var player_spawn_position: Vector2 = Vector2(-128.0, 0.0)
@export var boss_spawn_position: Vector2 = Vector2(128.0, 0.0)
@export var floor_color: Color = Color(0.09, 0.09, 0.12, 1.0)
@export var boundary_color: Color = Color(0.26, 0.27, 0.32, 1.0)
@export var encounter_tuning: TenthWardenEncounterTuning
@export var production_authoring: TenthWardenProductionAuthoring = null
@export_category("PLAYTEST Arc Volley — Replace with approved tuning")
@export var arc_volley_projectile_scene: PackedScene = null
@export_range(1.0, 2000.0, 1.0) var arc_volley_projectile_speed_px_s: float = 540.0
@export_range(1.0, 32.0, 0.5) var arc_volley_projectile_radius_px: float = 7.0
@export_range(1, 300, 1) var arc_volley_projectile_lifetime_ticks: int = 90
@export_range(0.0, 45.0, 0.5) var arc_volley_spread_degrees: float = 8.0
@export_category("PLAYTEST Boss Motion — Replace with approved tuning")
@export_range(0.0, 800.0, 1.0) var approach_speed_px_s: float = 150.0
@export_range(0.0, 1200.0, 1.0) var lunge_speed_px_s: float = 420.0
@export_range(0.0, 800.0, 1.0) var punishing_step_speed_px_s: float = 250.0
@export_range(1.0, 80.0, 1.0) var minimum_player_separation_px: float = 28.0
@export_range(0.0, 80.0, 1.0) var boss_boundary_margin_px: float = 20.0
@export_range(1.0, 300.0, 1.0) var punishing_step_trigger_radius_px: float = 112.0
@export_range(-1.0, 0.0, 0.05) var punishing_step_behind_dot_threshold: float = -0.35
@export_category("PLAYTEST Exposed Weak Point — Replace with approved tuning")
@export var weak_point_local_offset: Vector2 = Vector2(0.0, -66.0)
@export_range(1.0, 5.0, 0.05) var weak_point_damage_multiplier: float = 1.5
@export_node_path("Marker2D") var player_spawn_path: NodePath = NodePath("PlayerSpawn")
@export_node_path("Marker2D") var boss_spawn_path: NodePath = NodePath("BossSpawn")
@export_node_path("TenthWardenVisualController") var boss_visual_path: NodePath = NodePath("TenthWardenVisual")

@onready var player_spawn: Marker2D = get_node_or_null(player_spawn_path) as Marker2D
@onready var boss_spawn: Marker2D = get_node_or_null(boss_spawn_path) as Marker2D
@onready var boss_visual: TenthWardenVisualController = get_node_or_null(boss_visual_path) as TenthWardenVisualController
@onready var top_shape: CollisionShape2D = get_node_or_null("TopBoundary/CollisionShape2D") as CollisionShape2D
@onready var bottom_shape: CollisionShape2D = get_node_or_null("BottomBoundary/CollisionShape2D") as CollisionShape2D
@onready var left_shape: CollisionShape2D = get_node_or_null("LeftBoundary/CollisionShape2D") as CollisionShape2D
@onready var right_shape: CollisionShape2D = get_node_or_null("RightBoundary/CollisionShape2D") as CollisionShape2D

var encounter_runtime: CombatEncounterRuntime = null
var boss_runtime: TenthWardenCombatRuntime = null
var autonomous_runtime: TenthWardenEncounterController = null
var live_contact_delivery: TenthWardenLiveContactDelivery = null
var committed_terminal_outcome: StringName = TenthWardenEncounterState.OUTCOME_ONGOING
var punishing_step_positioning_condition_met: bool = false
var _live_player: PlayerController = null
var _locked_attack_direction: Vector2 = Vector2.LEFT
var _locked_target_position: Vector2 = Vector2.ZERO

func _ready() -> void:
    apply_authoring()

func _exit_tree() -> void:
    end_encounter()

func _physics_process(delta: float) -> void:
    if autonomous_runtime == null or boss_runtime == null:
        return
    if boss_runtime.evaluate_live_outcome() != TenthWardenEncounterState.OUTCOME_ONGOING:
        commit_terminal_outcome()
        return
    _advance_boss_motion(delta)
    _refresh_punishing_step_positioning_condition()
    autonomous_runtime.advance_fixed_tick(punishing_step_positioning_condition_met)
    if live_contact_delivery != null:
        live_contact_delivery.advance_fixed_tick(delta)
    if boss_runtime != null and boss_runtime.evaluate_live_outcome() != TenthWardenEncounterState.OUTCOME_ONGOING:
        commit_terminal_outcome()

func validate_authoring() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(encounter_id)):
        errors.append("encounter_id must be a stable ID")
    if not _finite_vector(arena_size) or arena_size.x <= boundary_thickness * 4.0 or arena_size.y <= boundary_thickness * 4.0:
        errors.append("arena_size must be finite and leave readable interior space")
    if not is_finite(boundary_thickness) or boundary_thickness <= 0.0:
        errors.append("boundary_thickness must be finite and positive")
    if not _spawn_is_valid(player_spawn_position):
        errors.append("player spawn must be finite and inside the fixed sanctum boundary")
    if not _spawn_is_valid(boss_spawn_position):
        errors.append("boss spawn must be finite and inside the fixed sanctum boundary")
    if not is_finite(approach_speed_px_s) or not is_finite(lunge_speed_px_s) or not is_finite(punishing_step_speed_px_s):
        errors.append("boss motion speeds must be finite")
    if not is_finite(minimum_player_separation_px) or not is_finite(boss_boundary_margin_px):
        errors.append("boss motion margins must be finite")
    if (not is_finite(punishing_step_trigger_radius_px) or punishing_step_trigger_radius_px <= minimum_player_separation_px
        or not is_finite(punishing_step_behind_dot_threshold)
        or punishing_step_behind_dot_threshold < -1.0 or punishing_step_behind_dot_threshold > 0.0):
        errors.append("Punishing Step proximity and rear-angle playtest tuning must be valid")
    if not _finite_vector(weak_point_local_offset) or not is_finite(weak_point_damage_multiplier) or weak_point_damage_multiplier < 1.0:
        errors.append("boss weak-point placement and multiplier must be finite")
    if player_spawn_position.distance_to(boss_spawn_position) <= boundary_thickness * 2.0:
        errors.append("player and boss spawns must have readable separation")
    if encounter_tuning == null or not encounter_tuning.validate_tuning().is_empty():
        errors.append("valid Tenth Warden encounter tuning is required")
    return errors

func apply_authoring() -> bool:
    if not validate_authoring().is_empty():
        return false
    if player_spawn == null or boss_spawn == null or boss_visual == null:
        return false
    if top_shape == null or bottom_shape == null or left_shape == null or right_shape == null:
        return false
    var top_rect := top_shape.shape as RectangleShape2D
    var bottom_rect := bottom_shape.shape as RectangleShape2D
    var left_rect := left_shape.shape as RectangleShape2D
    var right_rect := right_shape.shape as RectangleShape2D
    if top_rect == null or bottom_rect == null or left_rect == null or right_rect == null:
        return false

    var half := arena_size * 0.5
    top_rect.size = Vector2(arena_size.x, boundary_thickness)
    bottom_rect.size = Vector2(arena_size.x, boundary_thickness)
    left_rect.size = Vector2(boundary_thickness, arena_size.y - boundary_thickness * 2.0)
    right_rect.size = Vector2(boundary_thickness, arena_size.y - boundary_thickness * 2.0)
    $TopBoundary.position = Vector2(0.0, -half.y + boundary_thickness * 0.5)
    $BottomBoundary.position = Vector2(0.0, half.y - boundary_thickness * 0.5)
    $LeftBoundary.position = Vector2(-half.x + boundary_thickness * 0.5, 0.0)
    $RightBoundary.position = Vector2(half.x - boundary_thickness * 0.5, 0.0)
    player_spawn.position = player_spawn_position
    boss_spawn.position = boss_spawn_position
    boss_visual.position = boss_spawn_position
    _locked_attack_direction = Vector2.LEFT
    _locked_target_position = boss_spawn_position
    queue_redraw()
    return true

func prepare_encounter(
    player_state: CombatantRuntimeState,
    boss_state: CombatantRuntimeState,
    shared_active_combat: ActiveCombatRegistry = null,
    shared_full_ai: FullAiSimulationLedger = null,
    shared_attack_pressure: AttackPressureLedger = null
) -> bool:
    if encounter_runtime != null or boss_runtime != null:
        return false
    if player_state == null or boss_state == null or boss_visual == null:
        return false
    var binder := boss_visual.get_node_or_null("StatePresentationBinder") as TenthWardenPresentationStateBinder
    if binder == null:
        return false

    var candidate_encounter := CombatEncounterRuntime.new()
    if not candidate_encounter.configure(encounter_id, shared_active_combat, shared_full_ai, shared_attack_pressure):
        return false
    if not candidate_encounter.register_player(player_state) or not candidate_encounter.register_enemy(boss_state):
        candidate_encounter.end_encounter()
        return false

    var candidate_boss_runtime := TenthWardenCombatRuntime.new()
    if not candidate_boss_runtime.configure(candidate_encounter, player_state.actor_id, boss_state.actor_id, encounter_tuning):
        candidate_encounter.end_encounter()
        return false
    if not binder.bind_state(candidate_boss_runtime.state):
        candidate_encounter.end_encounter()
        return false
    if not binder.bind_combat_runtime(candidate_encounter, boss_state.actor_id):
        binder.unbind_state()
        candidate_encounter.end_encounter()
        return false
    var status := boss_visual.get_node_or_null("CombatStatus") as EnemyCombatStatusPresenter
    if status == null:
        status = EnemyCombatStatusPresenter.new()
        status.name = "CombatStatus"
        status.z_index = 50
        boss_visual.add_child(status)
    if not status.bind_runtime(candidate_encounter, boss_state.actor_id):
        binder.unbind_state()
        binder.unbind_combat_runtime()
        candidate_encounter.end_encounter()
        return false

    encounter_runtime = candidate_encounter
    boss_runtime = candidate_boss_runtime
    committed_terminal_outcome = TenthWardenEncounterState.OUTCOME_ONGOING
    return true

func validate_production_readiness(source_authoring: TenthWardenProductionAuthoring = null) -> PackedStringArray:
    var errors := validate_authoring()
    var resolved_authoring := source_authoring if source_authoring != null else production_authoring
    if resolved_authoring == null:
        errors.append("Tenth Warden production authoring is required")
        return errors
    for error: String in resolved_authoring.validate_authoring():
        errors.append("production_authoring: %s" % error)
    return errors

func prepare_production_encounter(
    player_state: CombatantRuntimeState,
    source_authoring: TenthWardenProductionAuthoring = null,
    shared_active_combat: ActiveCombatRegistry = null,
    shared_full_ai: FullAiSimulationLedger = null,
    shared_attack_pressure: AttackPressureLedger = null
) -> bool:
    if encounter_runtime != null or boss_runtime != null or autonomous_runtime != null:
        return false
    var resolved_authoring := source_authoring if source_authoring != null else production_authoring
    if not validate_production_readiness(resolved_authoring).is_empty():
        return false
    var boss_state: CombatantRuntimeState = resolved_authoring.build_boss_state()
    if boss_state == null:
        return false
    if not prepare_encounter(
        player_state,
        boss_state,
        shared_active_combat,
        shared_full_ai,
        shared_attack_pressure
    ):
        return false
    var controller := TenthWardenEncounterController.new()
    if not controller.configure(boss_runtime, resolved_authoring):
        end_encounter()
        return false
    controller.active_delivery_window_opened.connect(_on_boss_active_delivery_window_opened)
    controller.action_machine.action_started.connect(_on_live_boss_action_started)
    autonomous_runtime = controller
    production_authoring = resolved_authoring
    punishing_step_positioning_condition_met = false
    return true

func bind_live_contact_delivery(
    source_player: PlayerController,
    source_class_runtime: ClassCombatRuntime,
    defender_facts_provider: Callable
) -> bool:
    if autonomous_runtime == null or boss_runtime == null or boss_visual == null:
        return false
    var driver := TenthWardenLiveContactDelivery.new()
    if not driver.configure(
        self,
        source_player,
        source_class_runtime,
        boss_visual,
        defender_facts_provider
    ):
        return false
    live_contact_delivery = driver
    _live_player = source_player
    return true

func get_locked_attack_direction() -> Vector2:
    return _locked_attack_direction

func get_exposed_weak_point_position() -> Vector2:
    if boss_runtime == null or boss_runtime.state == null or not boss_runtime.state.weak_point_exposed or boss_visual == null:
        return Vector2.INF
    return boss_visual.to_global(weak_point_local_offset)

func _on_live_boss_action_started(_move_id: StringName, _action_instance_id: int) -> void:
    if _live_player == null or not is_instance_valid(_live_player) or boss_visual == null:
        return
    _locked_target_position = _live_player.global_position
    var aim := _locked_target_position - boss_visual.global_position
    if aim.length_squared() > 0.0001 and aim.is_finite():
        _locked_attack_direction = aim.normalized()

func _advance_boss_motion(delta: float) -> void:
    if (
        _live_player == null or not is_instance_valid(_live_player) or boss_visual == null
        or autonomous_runtime == null or autonomous_runtime.action_machine == null
        or not is_finite(delta) or delta <= 0.0
    ):
        return
    var machine := autonomous_runtime.action_machine
    var action_id := machine.get_current_action_id()
    var phase := machine.get_phase()
    var speed := 0.0
    if phase == ActionStateMachine.Phase.STARTUP and action_id != TenthWardenEncounterState.MOVE_ARC_VOLLEY:
        speed = approach_speed_px_s
    elif phase == ActionStateMachine.Phase.ACTIVE:
        if action_id == TenthWardenEncounterState.MOVE_WARDEN_LUNGE:
            speed = lunge_speed_px_s
        elif action_id == TenthWardenEncounterState.MOVE_PUNISHING_STEP:
            speed = punishing_step_speed_px_s
    if speed <= 0.0:
        return
    var to_target := _locked_target_position - boss_visual.global_position
    var remaining := to_target.length() - minimum_player_separation_px
    if remaining <= 0.0:
        return
    var step := minf(speed * delta, remaining)
    var destination := boss_visual.global_position + _locked_attack_direction * step
    var interior := get_arena_rect().grow(-boundary_thickness - boss_boundary_margin_px)
    boss_visual.position = to_local(destination).clamp(interior.position, interior.end)


func _refresh_punishing_step_positioning_condition() -> void:
    punishing_step_positioning_condition_met = false
    if (_live_player == null or not is_instance_valid(_live_player) or boss_visual == null
        or boss_runtime == null or boss_runtime.evaluate_live_outcome() != TenthWardenEncounterState.OUTCOME_ONGOING):
        return
    var relative := _live_player.global_position - boss_visual.global_position
    var distance := relative.length()
    if (not is_finite(distance) or distance <= minimum_player_separation_px
        or distance > punishing_step_trigger_radius_px):
        return
    var forward := _locked_attack_direction
    if not forward.is_finite() or forward.length_squared() <= 0.0001:
        return
    punishing_step_positioning_condition_met = relative.normalized().dot(forward.normalized()) <= punishing_step_behind_dot_threshold

func set_punishing_step_positioning_condition(met: bool) -> void:
    punishing_step_positioning_condition_met = met

func resolve_confirmed_boss_contact(
    contact_facts: Variant,
    evade_window_active: bool,
    defense_mode: StringName,
    facing_covered: bool
) -> Dictionary:
    if autonomous_runtime == null:
        return {
            "accepted": false,
            "reason_id": TenthWardenEncounterController.REASON_NOT_CONFIGURED,
            "outcome": DirectHitResolver.OUTCOME_REJECTED,
            "hp_damage": 0,
            "target_defeated": false,
        }
    return autonomous_runtime.resolve_authored_contact(
        contact_facts,
        evade_window_active,
        defense_mode,
        facing_covered
    )

func commit_terminal_outcome() -> bool:
    if boss_runtime == null or encounter_runtime == null:
        return false
    if committed_terminal_outcome != TenthWardenEncounterState.OUTCOME_ONGOING:
        return false
    var outcome := boss_runtime.evaluate_live_outcome()
    if outcome == TenthWardenEncounterState.OUTCOME_ONGOING:
        return false
    committed_terminal_outcome = outcome
    terminal_outcome_committed.emit(outcome)
    end_encounter()
    return true

func reset_for_retry() -> bool:
    end_encounter()
    if boss_visual != null:
        boss_visual.position = boss_spawn_position
    committed_terminal_outcome = TenthWardenEncounterState.OUTCOME_ONGOING
    punishing_step_positioning_condition_met = false
    if boss_visual != null:
        boss_visual.apply_profile()
    return encounter_runtime == null and boss_runtime == null and autonomous_runtime == null

func end_encounter() -> void:
    _live_player = null
    _locked_attack_direction = Vector2.LEFT
    _locked_target_position = boss_spawn_position
    if live_contact_delivery != null:
        live_contact_delivery.reset()
        live_contact_delivery = null
    if autonomous_runtime != null:
        autonomous_runtime.reset()
        autonomous_runtime = null
    if boss_visual != null:
        var binder := boss_visual.get_node_or_null("StatePresentationBinder") as TenthWardenPresentationStateBinder
        if binder != null:
            binder.unbind_state()
            binder.unbind_combat_runtime()
        boss_visual.set_weak_point_exposed(false)
        var status := boss_visual.get_node_or_null("CombatStatus") as EnemyCombatStatusPresenter
        if status != null:
            status.unbind_runtime()
    if boss_runtime != null:
        boss_runtime.end_encounter()
    encounter_runtime = null
    boss_runtime = null
    punishing_step_positioning_condition_met = false

func _on_boss_active_delivery_window_opened(context: Dictionary) -> void:
    boss_active_delivery_window_opened.emit(context.duplicate(true))

func get_arena_rect() -> Rect2:
    return Rect2(-arena_size * 0.5, arena_size)

func _draw() -> void:
    if arena_size.x <= 0.0 or arena_size.y <= 0.0 or boundary_thickness <= 0.0:
        return
    var half := arena_size * 0.5
    var arena_rect := Rect2(-half, arena_size)
    draw_rect(arena_rect, floor_color, true)
    draw_rect(Rect2(Vector2(-half.x, -half.y), Vector2(arena_size.x, boundary_thickness)), boundary_color, true)
    draw_rect(Rect2(Vector2(-half.x, half.y - boundary_thickness), Vector2(arena_size.x, boundary_thickness)), boundary_color, true)
    draw_rect(Rect2(Vector2(-half.x, -half.y + boundary_thickness), Vector2(boundary_thickness, arena_size.y - boundary_thickness * 2.0)), boundary_color, true)
    draw_rect(Rect2(Vector2(half.x - boundary_thickness, -half.y + boundary_thickness), Vector2(boundary_thickness, arena_size.y - boundary_thickness * 2.0)), boundary_color, true)

func _spawn_is_valid(spawn_position: Vector2) -> bool:
    if not _finite_vector(spawn_position) or not _finite_vector(arena_size) or not is_finite(boundary_thickness):
        return false
    var half := arena_size * 0.5
    var margin := boundary_thickness * 1.5
    return absf(spawn_position.x) <= half.x - margin and absf(spawn_position.y) <= half.y - margin

func _finite_vector(value: Vector2) -> bool:
    return is_finite(value.x) and is_finite(value.y)
