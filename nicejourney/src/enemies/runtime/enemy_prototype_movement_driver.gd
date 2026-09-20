class_name EnemyPrototypeMovementDriver
extends RefCounted

const TACTIC_NONE: StringName = &""

var runtime: EnemyArchetypeRuntime = null
var visual: Node2D = null
var target: Node2D = null
var tuning: EnemyPrototypeMovementTuning = null
var status_playtest_tuning: StatusPlaytestTuning = null
var navigation_agent: NavigationAgent2D = null
var active_tactic_id: StringName = TACTIC_NONE
var observed_destination: Vector2 = Vector2.ZERO
var _has_observed_destination: bool = false

func configure(
    source_runtime: EnemyArchetypeRuntime,
    source_visual: Node2D,
    source_tuning: EnemyPrototypeMovementTuning
) -> bool:
    if source_runtime == null or source_visual == null or source_tuning == null:
        return false
    if not source_runtime.is_configured() or not source_tuning.validate_tuning().is_empty():
        return false
    runtime = source_runtime
    visual = source_visual
    tuning = source_tuning
    navigation_agent = visual.get_node_or_null("PrototypeNavigationAgent") as NavigationAgent2D
    if navigation_agent == null:
        navigation_agent = NavigationAgent2D.new()
        navigation_agent.name = "PrototypeNavigationAgent"
        navigation_agent.avoidance_enabled = false
        visual.add_child(navigation_agent)
    navigation_agent.path_desired_distance = tuning.path_desired_distance_px
    navigation_agent.target_desired_distance = tuning.target_desired_distance_px
    clear_intent()
    return true

func set_target_node(source_target: Node2D) -> void:
    target = source_target

func apply_decision(decision: Variant) -> bool:
    if runtime == null or not decision is Dictionary:
        return false
    var data := decision as Dictionary
    if not bool(data.get("accepted", false)):
        return false
    var selection_variant: Variant = data.get("selection", null)
    if not selection_variant is Dictionary:
        return false
    var tactic_id := StringName(String((selection_variant as Dictionary).get("tactic_id", &"")))
    if tactic_id == runtime.definition.signature_action_id or tactic_id == &"tactic:hold_observe" or tactic_id == &"tactic:contest_objective":
        clear_intent()
        return true
    if not [&"tactic:approach", &"tactic:withdraw", &"tactic:reposition_last_known"].has(tactic_id):
        clear_intent()
        return false
    active_tactic_id = tactic_id
    var observed_variant: Variant = data.get("observed_position", null)
    _has_observed_destination = observed_variant is Vector2 and (observed_variant as Vector2).is_finite()
    observed_destination = observed_variant as Vector2 if _has_observed_destination else Vector2.ZERO
    return true

func clear_intent() -> void:
    active_tactic_id = TACTIC_NONE
    observed_destination = Vector2.ZERO
    _has_observed_destination = false
    if navigation_agent != null and visual != null and is_instance_valid(visual):
        navigation_agent.target_position = visual.global_position

func advance_fixed(delta: float) -> bool:
    if runtime == null or visual == null or navigation_agent == null or tuning == null:
        return false
    if not is_finite(delta) or delta <= 0.0:
        return false
    if not is_instance_valid(visual) or not runtime.is_tactical_eligible():
        clear_intent()
        return true
    if runtime.phase_id != EnemyArchetypeRuntime.PHASE_IDLE or active_tactic_id == TACTIC_NONE:
        return true

    # Movement consumes the observation snapshot captured by the decision driver.
    # Do not follow the live target node between perception/decision evaluations.
    var destination_result := resolve_destination(
        active_tactic_id,
        visual.global_position,
        observed_destination,
        _has_observed_destination,
        observed_destination,
        _has_observed_destination,
        tuning.withdraw_probe_distance_px
    )
    if not bool(destination_result.get("accepted", false)):
        return true
    var navigation_destination := _closest_navigation_point(destination_result["destination"] as Vector2)
    if not navigation_destination.is_finite():
        return false
    navigation_agent.target_position = navigation_destination
    if visual.global_position.distance_to(navigation_destination) <= tuning.target_desired_distance_px:
        return true
    if navigation_agent.is_navigation_finished():
        return true
    var next_position := navigation_agent.get_next_path_position()
    if not next_position.is_finite():
        return false
    var speed_multiplier := 1.0
    if status_playtest_tuning != null and runtime.encounter != null:
        var combatant := runtime.encounter.get_combatant(runtime.actor_id)
        if combatant != null:
            speed_multiplier = status_playtest_tuning.slow_speed_multiplier(combatant.get_status_states())
    var max_step := tuning.move_speed_px_per_second * speed_multiplier * delta
    if max_step <= 0.0:
        return true
    var before := visual.global_position
    visual.global_position = visual.global_position.move_toward(next_position, max_step)
    var horizontal_step := visual.global_position.x - before.x
    if absf(horizontal_step) > 0.001 and visual is EnemyVisualController:
        (visual as EnemyVisualController).set_facing_left(horizontal_step < 0.0)
    return true

static func resolve_destination(
    tactic_id: StringName,
    current_position: Vector2,
    live_target_position: Vector2,
    has_live_target: bool,
    last_observed_position: Vector2,
    has_last_observation: bool,
    withdraw_probe_distance_px: float
) -> Dictionary:
    if not current_position.is_finite() or not is_finite(withdraw_probe_distance_px) or withdraw_probe_distance_px <= 0.0:
        return _destination_rejected(&"invalid_context")
    match tactic_id:
        &"tactic:approach":
            if not has_live_target or not live_target_position.is_finite():
                return _destination_rejected(&"live_target_required")
            return _destination_accepted(live_target_position)
        &"tactic:withdraw":
            if not has_live_target or not live_target_position.is_finite():
                return _destination_rejected(&"live_target_required")
            var away := current_position - live_target_position
            if away.length_squared() <= 0.0001:
                return _destination_rejected(&"separation_direction_unavailable")
            return _destination_accepted(current_position + away.normalized() * withdraw_probe_distance_px)
        &"tactic:reposition_last_known":
            if not has_last_observation or not last_observed_position.is_finite():
                return _destination_rejected(&"last_observation_required")
            return _destination_accepted(last_observed_position)
        _:
            return _destination_rejected(&"unsupported_tactic")

func _closest_navigation_point(destination: Vector2) -> Vector2:
    if navigation_agent == null or not destination.is_finite():
        return Vector2(INF, INF)
    var navigation_map: RID = navigation_agent.get_navigation_map()
    if not navigation_map.is_valid() or NavigationServer2D.map_get_iteration_id(navigation_map) <= 0:
        return destination
    return NavigationServer2D.map_get_closest_point(navigation_map, destination)

static func _destination_accepted(destination: Vector2) -> Dictionary:
    return {"accepted": true, "reason_id": &"", "destination": destination}

static func _destination_rejected(reason_id: StringName) -> Dictionary:
    return {"accepted": false, "reason_id": reason_id, "destination": Vector2.ZERO}
