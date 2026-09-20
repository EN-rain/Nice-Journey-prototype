class_name TowerEscortRuntime
extends Node2D

signal progress_committed(quest_id: StringName, result: Dictionary)
signal collision_feedback(quest_id: StringName, actor_id: StringName, result: Dictionary)
signal escort_failed(quest_id: StringName, actor_id: StringName, result: Dictionary)
signal escort_completed(quest_id: StringName, actor_id: StringName, result: Dictionary)
signal escort_retried(quest_id: StringName, actor_id: StringName, result: Dictionary)

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_AUTHORING_UNAVAILABLE: StringName = &"authoring_unavailable"
const REASON_TUNING_UNAVAILABLE: StringName = &"tuning_unavailable"
const REASON_QUEST_NOT_ACTIVE: StringName = &"quest_not_active"
const REASON_OBJECTIVE_BIND_FAILED: StringName = &"objective_bind_failed"
const REASON_OBJECTIVE_MISMATCH: StringName = &"objective_mismatch"
const REASON_DRIVER_CONFIG_FAILED: StringName = &"driver_config_failed"
const REASON_PROGRESS_COMMIT_FAILED: StringName = &"progress_commit_failed"
const REASON_ACTOR_MISMATCH: StringName = &"actor_mismatch"
const REASON_FAILURE_POLICY_MISMATCH: StringName = &"failure_policy_mismatch"
const REASON_RETRY_FAILED: StringName = &"retry_failed"
const REASON_SAFE_STATE_INVALID: StringName = &"safe_state_invalid"
const SAFE_STATE_SCHEMA_VERSION: int = 1

var profile: ProfileSnapshot = null
var floor_state: FloorInstanceState = null
var quest_id: StringName = &""
var actor: CharacterBody2D = null
var driver: QuestEscortWaypointDriver = null
var tuning: TowerEscortRuntimeTuning = null
@export var npc_visual_profile: NpcVisualProfile = null
var current_hp: int = 0

var _authoring: Dictionary = {}
var _physical_waypoints: Array[Dictionary] = []
var _configured: bool = false
var _terminal: bool = false
var _tile_size: int = TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE


func _ready() -> void:
    set_physics_process(false)


func configure(
    source_profile: ProfileSnapshot,
    source_floor_state: FloorInstanceState,
    source_quest_id: StringName,
    source_tuning: TowerEscortRuntimeTuning,
    tile_size: int = TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE,
    restored_safe_state: Dictionary = {}
) -> Dictionary:
    _clear_runtime_actor()
    _configured = false
    _terminal = false
    if source_profile == null or source_floor_state == null or source_tuning == null or tile_size <= 0 or get_parent() == null:
        return _rejected(REASON_INVALID_CONTEXT)
    if not FloorInstanceState.validate_dictionary(source_floor_state.to_dictionary()).is_empty():
        return _rejected(REASON_INVALID_CONTEXT)

    var definition := QuestCatalog.get_definition(source_quest_id)
    var production_mode := (
        definition != null
        and definition.kind == QuestDefinition.KIND_PRIMARY
        and definition.floor_id >= 2
        and not definition.playtest_placeholder
    )
    var authored := (
        TowerEscortObjectiveAuthoring.build_production_v01(source_floor_state, source_quest_id)
        if production_mode
        else TowerEscortObjectiveAuthoring.build(source_floor_state, source_quest_id)
    )
    if authored.is_empty():
        return _rejected(REASON_AUTHORING_UNAVAILABLE)
    var tuning_errors := (
        source_tuning.validate_production_tuning()
        if production_mode
        else source_tuning.validate_tuning()
    )
    if not tuning_errors.is_empty():
        var unavailable := _rejected(REASON_TUNING_UNAVAILABLE)
        unavailable["errors"] = tuning_errors.duplicate()
        return unavailable

    profile = source_profile
    floor_state = source_floor_state
    quest_id = source_quest_id
    tuning = source_tuning
    current_hp = source_tuning.max_hp if source_tuning.max_hp > 0 else 0
    _tile_size = tile_size
    _authoring = authored.duplicate(true)
    _physical_waypoints = _make_physical_waypoints(authored.get("waypoints", []) as Array, tile_size)
    if _physical_waypoints.is_empty():
        return _reset_and_reject(REASON_AUTHORING_UNAVAILABLE)

    var quest_progress_before := source_profile.quest_progress.duplicate(true)
    var objective_result := _ensure_bound_objective()
    if not bool(objective_result.get("accepted", false)):
        return _reset_and_reject(StringName(objective_result.get("reason_id", REASON_OBJECTIVE_BIND_FAILED)))
    var objective := _load_objective_state()
    if objective == null:
        source_profile.quest_progress = quest_progress_before
        return _reset_and_reject(REASON_OBJECTIVE_MISMATCH)

    actor = _make_actor(source_tuning)
    if actor == null:
        source_profile.quest_progress = quest_progress_before
        return _reset_and_reject(REASON_TUNING_UNAVAILABLE)
    add_child(actor)
    if restored_safe_state.is_empty():
        _position_actor_for_progress(objective.next_route_index)
    elif not _restore_actor_safe_state(restored_safe_state, objective):
        source_profile.quest_progress = quest_progress_before
        return _reset_and_reject(REASON_SAFE_STATE_INVALID)

    driver = QuestEscortWaypointDriver.new()
    var driver_errors := driver.configure(
        actor,
        _physical_waypoints,
        source_tuning.speed_px_per_second,
        source_tuning.arrival_tolerance_px,
        objective.next_route_index
    )
    if not driver_errors.is_empty():
        source_profile.quest_progress = quest_progress_before
        var rejected := _reset_and_reject(REASON_DRIVER_CONFIG_FAILED)
        rejected["errors"] = driver_errors.duplicate()
        return rejected
    if not restored_safe_state.is_empty() and driver.next_route_index() != int(restored_safe_state.get("next_route_index", -1)):
        source_profile.quest_progress = quest_progress_before
        return _reset_and_reject(REASON_SAFE_STATE_INVALID)
    var sync := _commit_driver_progress(objective.next_route_index, driver.next_route_index())
    if not bool(sync.get("accepted", false)):
        source_profile.quest_progress = quest_progress_before
        return _reset_and_reject(REASON_PROGRESS_COMMIT_FAILED)

    _configured = true
    set_physics_process(true)
    return {
        "accepted": true,
        "reason_id": &"",
        "quest_id": quest_id,
        "actor_id": _actor_id(),
        "actor": actor,
        "objective_state": _objective_dictionary(),
        "initial_progress": sync.duplicate(true),
        "errors": PackedStringArray(),
    }


func _physics_process(delta: float) -> void:
    advance_fixed(delta)


func advance_fixed(delta: float) -> Dictionary:
    if not _configured or actor == null or driver == null:
        return _rejected(&"not_configured")
    if _terminal:
        actor.velocity = Vector2.ZERO
        _sync_escort_visual(true, 0.0, actor.global_position, true)
        return _rejected(&"objective_terminal")
    var objective := _load_objective_state()
    if objective == null:
        actor.velocity = Vector2.ZERO
        _sync_escort_visual(true, 0.0, actor.global_position, false)
        return _rejected(REASON_OBJECTIVE_MISMATCH)
    var position_before := actor.global_position
    var result := driver.physics_step(delta, objective.wait_requested)
    if not bool(result.get("accepted", false)):
        _sync_escort_visual(true, 0.0, position_before, false)
        return result

    var reached := result.get("reached_route_node_ids", []) as Array
    for raw_id: Variant in reached:
        var commit := QuestFamilyObjectiveService.apply_event(
            profile,
            quest_id,
            QuestFamilyObjectiveService.EVENT_ROUTE_NODE_REACHED,
            {"route_node_id": StringName(String(raw_id))}
        )
        if not bool(commit.get("accepted", false)):
            actor.velocity = Vector2.ZERO
            return _rejected_with_detail(REASON_PROGRESS_COMMIT_FAILED, commit)
        progress_committed.emit(quest_id, commit.duplicate(true))

    if bool(result.get("had_collision", false)):
        collision_feedback.emit(quest_id, _actor_id(), result.duplicate(true))

    if bool(result.get("complete", false)):
        var goal := QuestFamilyObjectiveService.apply_event(
            profile,
            quest_id,
            QuestFamilyObjectiveService.EVENT_GOAL_REACHED,
            {"goal_id": StringName(String((_authoring.get("objective_config", {}) as Dictionary).get("goal_id", &"")))}
        )
        if not bool(goal.get("accepted", false)):
            actor.velocity = Vector2.ZERO
            return _rejected_with_detail(REASON_PROGRESS_COMMIT_FAILED, goal)
        _terminal = bool(goal.get("objectives_complete", false))
        actor.velocity = Vector2.ZERO
        progress_committed.emit(quest_id, goal.duplicate(true))
        if _terminal:
            escort_completed.emit(quest_id, _actor_id(), goal.duplicate(true))
    _sync_escort_visual(objective.wait_requested, float(result.get("moved_distance_px", 0.0)), position_before, bool(result.get("complete", false)))
    result["objective_state"] = _objective_dictionary()
    return result


func set_wait_requested(wait_requested: bool) -> Dictionary:
    if not _configured or _terminal:
        return _rejected(&"objective_terminal" if _terminal else &"not_configured")
    var result := QuestFamilyObjectiveService.apply_event(
        profile,
        quest_id,
        QuestFamilyObjectiveService.EVENT_WAIT_CHANGED,
        {"wait_requested": wait_requested}
    )
    if bool(result.get("accepted", false)):
        if wait_requested and actor != null:
            _sync_escort_visual(true, 0.0, actor.global_position, false)
        progress_committed.emit(quest_id, result.duplicate(true))
    return result


func _sync_escort_visual(wait_requested: bool, moved_distance_px: float, position_before: Vector2, complete: bool) -> void:
    # Presentation follows actual movement and the persisted wait request; it
    # never decides route progress, collision, panic, or any quest state.
    if actor == null:
        return
    var presenter := actor.get_node_or_null("NpcVisualPresenter") as NpcVisualPresenter
    if presenter == null:
        return
    var moving := not wait_requested and not complete and moved_distance_px > 0.01
    presenter.set_semantic_state(&"follow" if moving else &"wait")
    var delta_x := actor.global_position.x - position_before.x
    if presenter.sprite != null and absf(delta_x) > 0.01:
        presenter.facing_right = delta_x > 0.0
        presenter.sprite.flip_h = not presenter.facing_right and presenter.profile != null and presenter.profile.mirror_left


func apply_resolved_damage(amount: int) -> Dictionary:
    if not _configured or _terminal or tuning == null or tuning.max_hp <= 0:
        return _rejected(&"escort_health_unavailable")
    if amount <= 0:
        return _rejected(&"invalid_resolved_damage")
    current_hp = maxi(0, current_hp - amount)
    if current_hp > 0:
        return {
            "accepted": true,
            "reason_id": &"",
            "quest_id": quest_id,
            "actor_id": _actor_id(),
            "current_hp": current_hp,
            "defeated": false,
        }
    var defeated := report_actor_defeated(_actor_id())
    defeated["current_hp"] = current_hp
    defeated["defeated"] = bool(defeated.get("accepted", false))
    return defeated


func report_actor_defeated(actor_id: StringName) -> Dictionary:
    if not _configured or _terminal:
        return _rejected(&"objective_terminal" if _terminal else &"not_configured")
    if actor_id != _actor_id():
        return _rejected(REASON_ACTOR_MISMATCH)
    var config := _authoring.get("objective_config", {}) as Dictionary
    var failure_policy := StringName(String(config.get("failure_policy_id", &"")))
    if failure_policy != TowerEscortObjectiveAuthoring.FAILURE_POLICY_ACTOR_DEFEAT:
        return _rejected(REASON_FAILURE_POLICY_MISMATCH)
    var result := QuestFamilyObjectiveService.apply_event(
        profile,
        quest_id,
        QuestFamilyObjectiveService.EVENT_FAILED,
        {"reason_id": failure_policy}
    )
    if bool(result.get("accepted", false)):
        _terminal = true
        actor.velocity = Vector2.ZERO
        progress_committed.emit(quest_id, result.duplicate(true))
        escort_failed.emit(quest_id, actor_id, result.duplicate(true))
    return result


func retry(
    new_attempt_id: StringName,
    recovery_conditions_satisfied: bool
) -> Dictionary:
    if not _configured or profile == null or actor == null or tuning == null:
        return _rejected(&"not_configured")
    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null:
        return _rejected(REASON_RETRY_FAILED)
    var ready := QuestActivationService.mark_retry_ready(staged, quest_id, recovery_conditions_satisfied)
    if not bool(ready.get("accepted", false)):
        return _rejected_with_detail(REASON_RETRY_FAILED, ready)
    var config := (_authoring.get("objective_config", {}) as Dictionary).duplicate(true)
    var retried := QuestActivationService.retry(staged, quest_id, new_attempt_id, true, config)
    if not bool(retried.get("accepted", false)):
        return _rejected_with_detail(REASON_RETRY_FAILED, retried)

    var staged_objective := _load_objective_state_from(staged)
    if staged_objective == null:
        return _rejected(REASON_RETRY_FAILED)
    var old_position := actor.global_position
    var new_driver := QuestEscortWaypointDriver.new()
    actor.global_position = _safe_retry_global_position()
    actor.velocity = Vector2.ZERO
    var driver_errors := new_driver.configure(
        actor,
        _physical_waypoints,
        tuning.speed_px_per_second,
        tuning.arrival_tolerance_px,
        staged_objective.next_route_index
    )
    if not driver_errors.is_empty():
        actor.global_position = old_position
        var rejected := _rejected(REASON_RETRY_FAILED)
        rejected["errors"] = driver_errors.duplicate()
        return rejected
    var sync := _commit_driver_progress_on_profile(staged, staged_objective.next_route_index, new_driver.next_route_index())
    if not bool(sync.get("accepted", false)):
        actor.global_position = old_position
        return _rejected_with_detail(REASON_RETRY_FAILED, sync)

    profile.quest_progress = staged.quest_progress.duplicate(true)
    driver = new_driver
    current_hp = tuning.max_hp if tuning.max_hp > 0 else 0
    _terminal = false
    set_physics_process(true)
    var result := {
        "accepted": true,
        "reason_id": &"",
        "quest_id": quest_id,
        "actor_id": _actor_id(),
        "attempt_id": new_attempt_id,
        "safe_retry_origin_id": StringName(String(config.get("safe_retry_origin_id", &""))),
        "objective_state": _objective_dictionary(),
    }
    escort_retried.emit(quest_id, _actor_id(), result.duplicate(true))
    return result


func is_configured() -> bool:
    return _configured


func is_terminal() -> bool:
    return _terminal


func capture_safe_state() -> Dictionary:
    if not _configured or _terminal or actor == null or driver == null:
        return {}
    var objective := _load_objective_state()
    if objective == null or objective.next_route_index != driver.next_route_index():
        return {}
    var state := {
        "schema_version": SAFE_STATE_SCHEMA_VERSION,
        "quest_id": String(quest_id),
        "actor_id": String(_actor_id()),
        "position_x": actor.position.x,
        "position_y": actor.position.y,
        "next_route_index": driver.next_route_index(),
        "wait_requested": objective.wait_requested,
    }
    if tuning != null and tuning.max_hp > 0:
        state["current_hp"] = current_hp
    return state if validate_safe_state(state).is_empty() else {}


static func validate_safe_state(data: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    var schema_variant: Variant = data.get("schema_version", null)
    if not _is_integral(schema_variant) or int(schema_variant) != SAFE_STATE_SCHEMA_VERSION:
        errors.append("schema_version must match the supported escort safe-state schema")
    if not StableId.is_valid(String(data.get("quest_id", ""))):
        errors.append("quest_id must be a stable ID")
    if not StableId.is_valid(String(data.get("actor_id", ""))):
        errors.append("actor_id must be a stable ID")
    for key: String in ["position_x", "position_y"]:
        var value: Variant = data.get(key, null)
        if (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT) or not is_finite(float(value)):
            errors.append("%s must be finite numeric data" % key)
    var index_variant: Variant = data.get("next_route_index", null)
    if not _is_integral(index_variant) or int(index_variant) < 0:
        errors.append("next_route_index must be a nonnegative integer")
    if not data.get("wait_requested", null) is bool:
        errors.append("wait_requested must be boolean")
    if data.has("current_hp"):
        var hp_variant: Variant = data.get("current_hp", null)
        if not _is_integral(hp_variant) or int(hp_variant) < 0:
            errors.append("current_hp must be a nonnegative integer")
    return errors


func get_debug_snapshot() -> Dictionary:
    return {
        "configured": _configured,
        "terminal": _terminal,
        "quest_id": quest_id,
        "actor_id": _actor_id(),
        "actor_position": actor.global_position if actor != null else Vector2.ZERO,
        "next_route_node_id": driver.next_route_node_id() if driver != null else &"",
        "objective_state": _objective_dictionary(),
        "current_hp": current_hp,
        "max_hp": tuning.max_hp if tuning != null else 0,
    }


func _restore_actor_safe_state(raw_state: Dictionary, objective: EscortObjectiveState) -> bool:
    if actor == null or objective == null or not validate_safe_state(raw_state).is_empty():
        return false
    if StringName(String(raw_state.get("quest_id", &""))) != quest_id:
        return false
    if StringName(String(raw_state.get("actor_id", &""))) != _actor_id():
        return false
    if int(raw_state.get("next_route_index", -1)) != objective.next_route_index:
        return false
    if bool(raw_state.get("wait_requested", false)) != objective.wait_requested:
        return false
    if tuning != null and tuning.max_hp > 0:
        if not raw_state.has("current_hp"):
            return false
        var restored_hp := int(raw_state.get("current_hp", -1))
        if restored_hp <= 0 or restored_hp > tuning.max_hp:
            return false
        current_hp = restored_hp
    var restored_position := Vector2(float(raw_state.get("position_x", NAN)), float(raw_state.get("position_y", NAN)))
    var world_extent := float(TowerFloorLayoutManifestValidator.MAX_FOOTPRINT_TILES * _tile_size)
    if restored_position.x < 0.0 or restored_position.y < 0.0 or restored_position.x >= world_extent or restored_position.y >= world_extent:
        return false
    actor.position = restored_position
    actor.velocity = Vector2.ZERO
    return true


static func _is_integral(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return true
    if typeof(value) != TYPE_FLOAT:
        return false
    var number := float(value)
    return is_finite(number) and is_equal_approx(number, round(number))


func _ensure_bound_objective() -> Dictionary:
    var raw_entry: Variant = profile.quest_progress.get(String(quest_id), null)
    if not raw_entry is Dictionary:
        return _rejected(REASON_QUEST_NOT_ACTIVE)
    var entry := raw_entry as Dictionary
    if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_ACTIVE:
        return _rejected(REASON_QUEST_NOT_ACTIVE)
    var raw_objective: Variant = entry.get("objective_state", {})
    if raw_objective is Dictionary and (raw_objective as Dictionary).is_empty():
        var config := _authoring.get("objective_config", {}) as Dictionary
        var bind := QuestFamilyObjectiveService.bind(profile, quest_id, config)
        return bind if bool(bind.get("accepted", false)) else _rejected_with_detail(REASON_OBJECTIVE_BIND_FAILED, bind)
    var objective := _load_objective_state()
    if objective == null or not _objective_matches_authoring(objective):
        return _rejected(REASON_OBJECTIVE_MISMATCH)
    return {"accepted": true, "reason_id": &""}


func _objective_matches_authoring(objective: EscortObjectiveState) -> bool:
    var config := _authoring.get("objective_config", {}) as Dictionary
    return objective.actor_id == StringName(String(config.get("actor_id", &""))) \
        and objective.route_node_ids == _names(config.get("route_node_ids", []) as Array) \
        and objective.goal_id == StringName(String(config.get("goal_id", &""))) \
        and objective.safe_retry_origin_id == StringName(String(config.get("safe_retry_origin_id", &""))) \
        and objective.failure_policy_id == StringName(String(config.get("failure_policy_id", &"")))


func _make_actor(source_tuning: TowerEscortRuntimeTuning) -> CharacterBody2D:
    if source_tuning == null or not source_tuning.validate_tuning().is_empty():
        return null
    var body := CharacterBody2D.new()
    body.name = _node_name(String(_actor_id()))
    body.collision_layer = source_tuning.collision_layer
    body.collision_mask = source_tuning.collision_mask
    body.set_meta(&"actor_id", _actor_id())
    body.set_meta(&"quest_id", quest_id)
    var collision := CollisionShape2D.new()
    collision.name = "CollisionShape2D"
    collision.shape = source_tuning.collision_shape.duplicate(true) as Shape2D
    if collision.shape == null:
        body.free()
        return null
    body.add_child(collision)
    if npc_visual_profile != null:
        var presenter := NpcVisualPresenter.new()
        presenter.name = "NpcVisualPresenter"
        presenter.profile = npc_visual_profile
        body.add_child(presenter)
    return body


func _make_physical_waypoints(raw_waypoints: Array, tile_size: int) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for raw: Variant in raw_waypoints:
        if not raw is Dictionary:
            return []
        var waypoint := raw as Dictionary
        var tile_variant: Variant = waypoint.get("world_tile", null)
        if not tile_variant is Vector2i:
            return []
        var local_position := (Vector2(tile_variant as Vector2i) + Vector2(0.5, 0.5)) * float(tile_size)
        result.append({
            "route_node_id": StringName(String(waypoint.get("route_node_id", &""))),
            "world_position": to_global(local_position),
        })
    return result


func _position_actor_for_progress(next_index: int) -> void:
    if actor == null or _physical_waypoints.is_empty():
        return
    var spawn_index := 0 if next_index <= 0 else mini(next_index - 1, _physical_waypoints.size() - 1)
    actor.global_position = (_physical_waypoints[spawn_index] as Dictionary).get("world_position", Vector2.ZERO) as Vector2
    actor.velocity = Vector2.ZERO


func _safe_retry_global_position() -> Vector2:
    var tile_variant: Variant = _authoring.get("safe_retry_world_tile", null)
    if not tile_variant is Vector2i:
        return (_physical_waypoints[0] as Dictionary).get("world_position", Vector2.ZERO) as Vector2
    var local_position := (Vector2(tile_variant as Vector2i) + Vector2(0.5, 0.5)) * float(_tile_size)
    return to_global(local_position)


func _commit_driver_progress(start_index: int, end_index: int) -> Dictionary:
    return _commit_driver_progress_on_profile(profile, start_index, end_index)


func _commit_driver_progress_on_profile(target_profile: ProfileSnapshot, start_index: int, end_index: int) -> Dictionary:
    var config := _authoring.get("objective_config", {}) as Dictionary
    var route := _names(config.get("route_node_ids", []) as Array)
    for index: int in range(start_index, mini(end_index, route.size())):
        var commit := QuestFamilyObjectiveService.apply_event(
            target_profile,
            quest_id,
            QuestFamilyObjectiveService.EVENT_ROUTE_NODE_REACHED,
            {"route_node_id": route[index]}
        )
        if not bool(commit.get("accepted", false)):
            return _rejected_with_detail(REASON_PROGRESS_COMMIT_FAILED, commit)
        if target_profile == profile:
            progress_committed.emit(quest_id, commit.duplicate(true))
    return {"accepted": true, "reason_id": &"", "next_route_index": end_index}


func _load_objective_state() -> EscortObjectiveState:
    return _load_objective_state_from(profile)


func _load_objective_state_from(source_profile: ProfileSnapshot) -> EscortObjectiveState:
    if source_profile == null:
        return null
    var raw_entry: Variant = source_profile.quest_progress.get(String(quest_id), null)
    if not raw_entry is Dictionary:
        return null
    var raw_state: Variant = (raw_entry as Dictionary).get("objective_state", null)
    if not raw_state is Dictionary:
        return null
    var state := EscortObjectiveState.new()
    if not state.load_dictionary(raw_state as Dictionary).is_empty():
        return null
    return state


func _objective_dictionary() -> Dictionary:
    var objective := _load_objective_state()
    return objective.to_dictionary() if objective != null else {}


func _actor_id() -> StringName:
    var config := _authoring.get("objective_config", {}) as Dictionary
    return StringName(String(config.get("actor_id", &"")))


func _names(values: Array) -> Array[StringName]:
    var result: Array[StringName] = []
    for value: Variant in values:
        result.append(StringName(String(value)))
    return result


func _clear_runtime_actor() -> void:
    if actor != null and is_instance_valid(actor):
        actor.free()
    actor = null
    driver = null
    set_physics_process(false)


func _reset_and_reject(reason_id: StringName) -> Dictionary:
    _clear_runtime_actor()
    profile = null
    floor_state = null
    quest_id = &""
    tuning = null
    current_hp = 0
    _authoring = {}
    _physical_waypoints = []
    _tile_size = TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE
    return _rejected(reason_id)


func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "quest_id": quest_id,
        "actor_id": _actor_id(),
        "errors": PackedStringArray(),
    }


func _rejected_with_detail(reason_id: StringName, detail: Dictionary) -> Dictionary:
    var result := _rejected(reason_id)
    result["detail"] = detail.duplicate(true)
    return result


func _node_name(value: String) -> String:
    return value.replace(":", "_").replace("/", "_").replace("-", "_").replace(".", "_")
