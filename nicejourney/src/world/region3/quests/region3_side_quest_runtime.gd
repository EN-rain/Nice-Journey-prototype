class_name Region3SideQuestRuntime
extends Node2D

signal encounter_started(encounter_id: StringName, encounter: CombatEncounterRuntime)
signal encounter_ended(encounter_id: StringName)
signal enemy_active_delivery_window_opened(encounter_id: StringName, context: Dictionary)
signal quest_progressed(quest_id: StringName, result: Dictionary)
signal quest_failed(quest_id: StringName, reason_id: StringName)
signal escort_separation_changed(waiting_for_player: bool)

const MARKERS: PackedScene = preload("res://src/world/region3/quests/region3_side_quest_authored_markers.tscn")
const DECISION_TUNING: EnemyPrototypeDecisionTuning = preload("res://src/data/tuning/enemy_prototype_decision_default.tres")
const MOVEMENT_TUNING: EnemyPrototypeMovementTuning = preload("res://src/data/tuning/enemy_prototype_movement_default.tres")

@export var visual_catalog: EnemyVisualSceneCatalog = preload("res://src/enemies/presentation/enemy_visual_scene_catalog.tres")
@export var enemy_runtime_tuning: TowerPrototypeEnemyRuntimeTuning = preload("res://src/data/tuning/tower_prototype_enemy_runtime_default.tres")
@export var playtest_attack_catalog: EnemyPlaytestAttackCatalog = null
@export var status_playtest_tuning: StatusPlaytestTuning = null
@export_range(8, 128, 1) var turn_in_radius_px: float = 50.0
@export_range(1, 360, 1) var escort_hazard_check_interval_ticks: int = 1
@export_range(64, 512, 1) var site_activation_radius_px: float = 224.0

var shared_active_combat: ActiveCombatRegistry = ActiveCombatRegistry.new()
var shared_full_ai: FullAiSimulationLedger = FullAiSimulationLedger.new()
var shared_attack_pressure: AttackPressureLedger = AttackPressureLedger.new()
var _layout: Region3AuthoredTownLayout = null
var _markers: Region3SideQuestPlaytestAnchorLayer = null
var _player: PlayerController = null
var _profile: ProfileSnapshot = null
var _save: SaveService = null
var _slot: int = 0
var _player_state_provider: Callable
var _descriptors: Dictionary = {}
var _active_quest_id: StringName = &""
var _active_attempt_id: StringName = &""
var _descriptor: Dictionary = {}
var _encounter: CombatEncounterRuntime = null
var _encounter_id: StringName = &""
var _wave_index: int = 0
var _wave_transition_pending: bool = false
var _visual_root: Node2D = null
var _visuals: Dictionary = {}
var _archetype_runtimes: Dictionary = {}
var _phase_drivers: Dictionary = {}
var _decision_drivers: Dictionary = {}
var _movement_drivers: Dictionary = {}
var _attack_executors: Dictionary = {}
var _escort_actor: Region3EscortActor = null
var _escort_driver: QuestEscortWaypointDriver = null
var _defense_actor: Region3DefenseObjectiveActor = null
var _pending_defeats: Array[StringName] = []
var _hazard_cooldown_by_actor: Dictionary = {}
var _separation_waiting: bool = false
var _physics_tick: int = 0
var _next_enemy_action_id: int = 2000000

func bind_world(
    layout: Region3AuthoredTownLayout, player: PlayerController,
    profile: ProfileSnapshot, save: SaveService, slot: int,
    quests: Region3SideQuestsPlaytest, progression: ProgressionPlaytestContent,
    player_state_provider: Callable,
    active_combat: ActiveCombatRegistry = null,
    full_ai: FullAiSimulationLedger = null,
    attack_pressure: AttackPressureLedger = null
) -> Dictionary:
    if (
        _layout != null or layout == null or player == null or profile == null or save == null
        or slot < 1 or slot > SaveService.SLOT_COUNT or not player_state_provider.is_valid()
        or get_parent() != layout or visual_catalog == null or not visual_catalog.validate_catalog().is_empty()
        or enemy_runtime_tuning == null or not enemy_runtime_tuning.validate_tuning().is_empty()
    ):
        return _rejected(&"region3_quest_binding_unavailable")
    var anchors := MARKERS.instantiate() as Region3SideQuestPlaytestAnchorLayer
    if anchors == null:
        return _rejected(&"region3_quest_markers_missing")
    layout.add_child(anchors)
    var authored := Region3SideQuestAttemptService.build_authored_descriptors(layout, anchors, quests, progression)
    if not bool(authored.get("accepted", false)):
        anchors.queue_free()
        return authored
    _markers = anchors
    _layout = layout
    _player = player
    _profile = profile
    _save = save
    _slot = slot
    _player_state_provider = player_state_provider
    _descriptors = (authored.get("descriptors", {}) as Dictionary).duplicate(true)
    if active_combat != null:
        shared_active_combat = active_combat
    if full_ai != null:
        shared_full_ai = full_ai
    if attack_pressure != null:
        shared_attack_pressure = attack_pressure
    return {"accepted": true, "reason_id": &"", "quest_ids": _descriptors.keys()}

func available_quest_ids() -> Array[StringName]:
    var result: Array[StringName] = []
    for raw_id: Variant in _descriptors.keys():
        result.append(StringName(String(raw_id)))
    result.sort()
    return result

func get_descriptor(quest_id: StringName) -> Dictionary:
    return (_descriptors.get(quest_id, {}) as Dictionary).duplicate(true)

func get_staging_readiness() -> Dictionary:
    if _layout == null or _markers == null:
        return _rejected(&"region3_quest_binding_unavailable")
    return Region3SideQuestStagingService.build_from_layout(_layout, _markers, _descriptors)

func request_accept(quest_id: StringName, attempt_id: StringName = &"") -> Dictionary:
    if _layout == null or _active_quest_id != &"" or not _descriptors.has(quest_id):
        return _rejected(&"region3_quest_unavailable")
    var descriptor := _descriptors[quest_id] as Dictionary
    var counts := _placements_for_wave(descriptor, 0)
    if shared_full_ai.get_admitted_count() + counts.size() > FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS:
        return _rejected(&"region3_quest_ai_budget_exhausted")
    var player_state_variant: Variant = _player_state_provider.call()
    if not player_state_variant is CombatantRuntimeState or (player_state_variant as CombatantRuntimeState).is_defeated():
        return _rejected(&"region3_quest_player_state_unavailable")
    if attempt_id == &"":
        var raw: Variant = _profile.quest_progress.get(String(quest_id), {})
        var history: Array = (raw as Dictionary).get("attempt_history", []) as Array if raw is Dictionary else []
        attempt_id = StringName("%s:attempt:%03d" % [String(quest_id), history.size() + 1])
    var activation := Region3SideQuestAttemptService.commit_accept(_save, _slot, _profile, descriptor, attempt_id)
    if not bool(activation.get("accepted", false)):
        return activation
    _active_quest_id = quest_id
    _active_attempt_id = attempt_id
    _descriptor = descriptor.duplicate(true)
    _wave_index = 0
    var start_ok := _start_actors()
    if start_ok and _active_quest_id == Region3SideQuestAttemptService.QUEST_ANNIHILATION:
        start_ok = _start_wave(player_state_variant as CombatantRuntimeState)
    if not start_ok:
        var rollback := Region3SideQuestAttemptService.commit_leave(_save, _slot, _profile, descriptor, true)
        _clear_live_session()
        var rejected := _rejected(&"region3_quest_actor_spawn_failed")
        rejected["retry_ready"] = bool(rollback.get("accepted", false))
        return rejected
    activation["encounter_id"] = _encounter_id
    activation["quest_id"] = quest_id
    return activation

func restore_active_quest() -> Dictionary:
    if _layout == null or _active_quest_id != &"":
        return _rejected(&"region3_quest_unavailable")
    for raw_id: Variant in _descriptors.keys():
        var quest_id := StringName(String(raw_id))
        var raw: Variant = _profile.quest_progress.get(String(quest_id), null)
        if not raw is Dictionary:
            continue
        var entry := raw as Dictionary
        if StringName(String(entry.get("state", &""))) not in [
            QuestProgressState.STATE_ACTIVE, QuestProgressState.STATE_OBJECTIVES_COMPLETE,
        ]:
            continue
        if _active_quest_id != &"":
            _clear_live_session()
            return _rejected(&"region3_quest_multiple_active_attempts")
        _active_quest_id = quest_id
        _active_attempt_id = StringName(String(entry.get("attempt_id", &"")))
        _descriptor = (_descriptors[quest_id] as Dictionary).duplicate(true)
    if _active_quest_id == &"":
        return {"accepted": true, "restored": false}
    var restored_state: Variant = (_profile.quest_progress[String(_active_quest_id)] as Dictionary).get("state", &"")
    if StringName(String(restored_state)) == QuestProgressState.STATE_OBJECTIVES_COMPLETE:
        return {"accepted": true, "restored": true, "pending_turn_in": true, "quest_id": _active_quest_id, "encounter_id": &""}
    if not _start_actors():
        _clear_live_session()
        return _rejected(&"region3_quest_restore_actor_failed")
    var objective := (_profile.quest_progress[String(_active_quest_id)] as Dictionary).get("objective_state", {}) as Dictionary
    var required_waves := _descriptor.get("objective_config", {}).get("required_actor_ids_by_wave", {}) as Dictionary
    if _active_quest_id == Region3SideQuestAttemptService.QUEST_DEFENSE:
        var defeated := objective.get("defeated_actor_ids_by_wave", {}) as Dictionary
        for wave_index: int in range((_descriptor["wave_ids"] as Array).size()):
            var wave_id := String((_descriptor["wave_ids"] as Array)[wave_index])
            if (defeated.get(wave_id, []) as Array).size() < (required_waves.get(wave_id, []) as Array).size():
                _wave_index = wave_index
                break
        if _defense_actor != null:
            _defense_actor.current_hp = int(objective.get("objective_current_hp", _defense_actor.current_hp))
            _defense_actor.queue_redraw()
    if _active_quest_id == Region3SideQuestAttemptService.QUEST_ANNIHILATION:
        var player_state_variant: Variant = _player_state_provider.call()
        if not player_state_variant is CombatantRuntimeState or not _start_wave(player_state_variant as CombatantRuntimeState):
            _clear_live_session()
            return _rejected(&"region3_quest_restore_encounter_failed")
    return {"accepted": true, "restored": true, "quest_id": _active_quest_id, "encounter_id": _encounter_id}

func get_active_encounter_ids() -> Array[StringName]:
    var result: Array[StringName] = []
    if _encounter != null:
        result.append(_encounter_id)
    return result

func active_quest_id() -> StringName:
    return _active_quest_id

func is_quest_attempt_active() -> bool:
    return _active_quest_id != &""

func get_escort_actor() -> Region3EscortActor:
    return _escort_actor

func get_defense_objective_actor() -> Region3DefenseObjectiveActor:
    return _defense_actor

func is_encounter_active(encounter_id: StringName) -> bool:
    return _encounter != null and _encounter_id == encounter_id

func get_encounter_runtime(encounter_id: StringName) -> CombatEncounterRuntime:
    return _encounter if is_encounter_active(encounter_id) else null

func get_visuals_by_actor(encounter_id: StringName) -> Dictionary:
    return _visuals.duplicate() if is_encounter_active(encounter_id) else {}

func get_archetype_runtime(encounter_id: StringName, actor_id: StringName) -> EnemyArchetypeRuntime:
    return _archetype_runtimes.get(actor_id) as EnemyArchetypeRuntime if is_encounter_active(encounter_id) else null

func get_action_phase_driver(encounter_id: StringName, actor_id: StringName) -> EnemySignatureActionPhaseDriver:
    return _phase_drivers.get(actor_id) as EnemySignatureActionPhaseDriver if is_encounter_active(encounter_id) else null

func get_attack_delivery_executor(encounter_id: StringName, actor_id: StringName) -> EnemyActiveAttackDeliveryExecutor:
    return _attack_executors.get(actor_id) as EnemyActiveAttackDeliveryExecutor if is_encounter_active(encounter_id) else null

func request_escort_wait(wait_requested: bool) -> Dictionary:
    if _escort_actor == null or _active_quest_id != Region3SideQuestAttemptService.QUEST_ESCORT:
        return _rejected(&"region3_escort_not_active")
    if _player.global_position.distance_to(_escort_actor.global_position) > _descriptor["escort_follow_distance_px"]:
        return _rejected(&"region3_escort_too_distant")
    return _record_event(QuestFamilyObjectiveService.EVENT_WAIT_CHANGED, {"wait_requested": wait_requested})

func request_leave(confirmed: bool) -> Dictionary:
    if _active_quest_id == &"":
        return _rejected(&"region3_quest_not_active")
    var result := Region3SideQuestAttemptService.commit_leave(_save, _slot, _profile, _descriptor, confirmed)
    if confirmed and bool(result.get("accepted", false)):
        _clear_live_session()
    return result

func request_turn_in(quest_hall_verified: bool = false) -> Dictionary:
    if _active_quest_id == &"":
        return _rejected(&"region3_quest_not_active")
    var landmark := Vector2.ZERO
    match _active_quest_id:
        Region3SideQuestAttemptService.QUEST_ESCORT:
            landmark = _descriptor["escort_goal_world_position"]
        Region3SideQuestAttemptService.QUEST_ANNIHILATION:
            landmark = _descriptor["return_landmark_world_position"]
        Region3SideQuestAttemptService.QUEST_DEFENSE:
            landmark = _descriptor["defense_objective_world_position"]
    if not quest_hall_verified and _player.global_position.distance_to(landmark) > turn_in_radius_px:
        return _rejected(&"region3_quest_return_landmark_required")
    var result := Region3SideQuestAttemptService.commit_turn_in(_save, _slot, _profile, _active_quest_id, _active_attempt_id)
    if bool(result.get("accepted", false)):
        _clear_live_session()
    return result

func capture_escort_safe_state() -> Dictionary:
    if _active_quest_id != Region3SideQuestAttemptService.QUEST_ESCORT or _escort_actor == null:
        return {"accepted": true, "durable": true, "reason_id": &"no_active_escort"}
    return Region3SideQuestAttemptService.commit_runtime_snapshot(
        _save, _slot, _profile, _active_quest_id, _active_attempt_id, _escort_runtime_snapshot()
    )

func clear_runtime() -> bool:
    # An active attempt needs request_leave() first so travel cannot silently
    # erase live quest state while a saved entry still says active.
    if _active_quest_id != &"":
        var entry := _profile.quest_progress.get(String(_active_quest_id), {}) as Dictionary if _profile != null else {}
        if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_OBJECTIVES_COMPLETE:
            return false
    _clear_live_session()
    return true

func unbind_world(checkpoint_restore: bool = false) -> bool:
    # Checkpoint retry has already loaded a valid durable profile. It must
    # discard the failed live attempt before rebinding that saved generation.
    if checkpoint_restore:
        _clear_live_session()
    elif not clear_runtime():
        return false
    if _markers != null and is_instance_valid(_markers):
        _markers.queue_free()
        _markers = null
    _layout = null
    _player = null
    _profile = null
    _save = null
    _slot = 0
    _player_state_provider = Callable()
    _descriptors.clear()
    return true

func progress_snapshot() -> Dictionary:
    var entry := _profile.quest_progress.get(String(_active_quest_id), {}) as Dictionary if _profile != null else {}
    return {
        "quest_id": _active_quest_id,
        "attempt_id": _active_attempt_id,
        "state": StringName(String(entry.get("state", &""))),
        "objective_state": (entry.get("objective_state", {}) as Dictionary).duplicate(true),
        "current_wave_index": _wave_index,
        "active_enemy_count": _encounter.get_active_enemy_count() if _encounter != null else 0,
        "escort_hp": _escort_actor.current_hp if _escort_actor != null else 0,
        "defense_hp": _defense_actor.current_hp if _defense_actor != null else 0,
        "escort_waiting_for_player": _separation_waiting,
    }

func _start_actors() -> bool:
    match _active_quest_id:
        Region3SideQuestAttemptService.QUEST_ESCORT:
            _escort_actor = Region3EscortActor.new()
            _escort_actor.name = "RegionalEscort"
            add_child(_escort_actor)
            _escort_actor.global_position = _descriptor["escort_start_world_position"]
            var shape := CollisionShape2D.new()
            var circle := CircleShape2D.new()
            circle.radius = _escort_actor.body_radius_px
            shape.shape = circle
            _escort_actor.add_child(shape)
            _escort_actor.collision_layer = 0
            _escort_actor.collision_mask = 1
            if not _escort_actor.configure(int(_descriptor["escort_max_hp"])):
                return false
            _escort_actor.actor_defeated.connect(_on_escort_defeated)
            var state := (_profile.quest_progress[String(_active_quest_id)] as Dictionary).get("objective_state", {}) as Dictionary
            var raw_runtime: Variant = (_profile.quest_progress[String(_active_quest_id)] as Dictionary).get("runtime_state", {})
            if not raw_runtime is Dictionary:
                return false
            var persisted_runtime := raw_runtime as Dictionary
            var next_index := int(state.get("next_route_index", 0))
            var route := _descriptor["escort_route"] as Array
            if next_index > 0 and next_index <= route.size():
                _escort_actor.global_position = (route[next_index - 1] as Dictionary)["world_position"]
            if not persisted_runtime.is_empty():
                if not Region3SideQuestAttemptService._valid_runtime_snapshot(persisted_runtime):
                    return false
                if int(persisted_runtime["escort_hp"]) > _escort_actor.max_hp:
                    return false
                var restored_position := Vector2(float(persisted_runtime["actor_pos_x"]), float(persisted_runtime["actor_pos_y"]))
                var map_bounds := Rect2(Vector2.ZERO, Vector2(_layout.map_size_tiles * _layout.tile_size))
                if not map_bounds.has_point(_layout.to_local(restored_position)):
                    return false
                _escort_actor.global_position = restored_position
                _escort_actor.current_hp = int(persisted_runtime["escort_hp"])
                _escort_actor.queue_redraw()
            _escort_driver = QuestEscortWaypointDriver.new()
            return _escort_driver.configure(
                _escort_actor, route, float(_descriptor["escort_speed_px_per_second"]),
                float(_descriptor["escort_arrival_tolerance_px"]), next_index
            ).is_empty()
        Region3SideQuestAttemptService.QUEST_DEFENSE:
            _defense_actor = Region3DefenseObjectiveActor.new()
            _defense_actor.name = "RegionalDefenseObjective"
            add_child(_defense_actor)
            _defense_actor.global_position = _descriptor["defense_objective_world_position"]
            return _defense_actor.configure(int((_descriptor["objective_config"] as Dictionary)["objective_max_hp"]))
        Region3SideQuestAttemptService.QUEST_ANNIHILATION:
            return true
    return false

func _start_wave(player_state: CombatantRuntimeState) -> bool:
    var remaining := _placements_for_wave(_descriptor, _wave_index)
    if remaining.is_empty():
        return false
    var encounter_id := StringName("region3:%s:wave:%02d" % [String(_active_quest_id), _wave_index + 1])
    var candidate := CombatEncounterRuntime.new()
    if not candidate.configure(encounter_id, shared_active_combat, shared_full_ai, shared_attack_pressure) or not candidate.register_player(player_state):
        candidate.end_encounter()
        return false
    var candidate_visual_root := Node2D.new()
    candidate_visual_root.name = "QuestWaveVisuals"
    add_child(candidate_visual_root)
    var visuals: Dictionary = {}
    var runtimes: Dictionary = {}
    var phases: Dictionary = {}
    var decisions: Dictionary = {}
    var movements: Dictionary = {}
    var executors: Dictionary = {}
    for placement: Dictionary in remaining:
        var actor_id := StringName(String(placement["actor_id"]))
        var archetype_id := StringName(String(placement["archetype_id"]))
        var role_stats: EnemyArchetypePlaytestStats = null
        if enemy_runtime_tuning.archetype_stats != null:
            role_stats = enemy_runtime_tuning.archetype_stats.stats_for(archetype_id)
            if role_stats == null:
                return _abort_spawn(candidate, candidate_visual_root)
        var combatant := CombatantRuntimeState.new()
        # Region 3 has no tower floor scaling. Apply the same source-owned role
        # modifiers as TowerPrototypeEnemyRuntimeFactory to the region baseline.
        var hp := maxi(1, roundi(float(enemy_runtime_tuning.base_hp) * (role_stats.hp_multiplier if role_stats != null else 1.0)))
        var stamina := (enemy_runtime_tuning.defender_stamina if archetype_id == &"defender" else enemy_runtime_tuning.base_stamina) + (role_stats.stamina_bonus if role_stats != null else 0.0)
        var physical_defense := enemy_runtime_tuning.base_physical_defense + (role_stats.physical_defense_bonus if role_stats != null else 0.0)
        var arcane_defense := enemy_runtime_tuning.base_arcane_defense + (role_stats.arcane_defense_bonus if role_stats != null else 0.0)
        var poise := enemy_runtime_tuning.base_poise_threshold * (role_stats.poise_multiplier if role_stats != null else 1.0)
        if not combatant.configure(actor_id, hp, stamina, physical_defense,
            arcane_defense, poise, true, archetype_id == &"defender", false):
            return _abort_spawn(candidate, candidate_visual_root)
        if not candidate.register_enemy(combatant):
            return _abort_spawn(candidate, candidate_visual_root)
        var runtime := EnemyArchetypeRuntime.new()
        if not runtime.configure(candidate, actor_id, player_state.actor_id, archetype_id):
            return _abort_spawn(candidate, candidate_visual_root)
        if playtest_attack_catalog != null and playtest_attack_catalog.validate_catalog().is_empty():
            var authored_attack := playtest_attack_catalog.attack_for(archetype_id)
            if authored_attack != null:
                runtime.definition.signature_attack_authoring = authored_attack
        var scene := visual_catalog.get_scene(archetype_id)
        var visual := scene.instantiate() as EnemyVisualController if scene != null else null
        if visual == null:
            return _abort_spawn(candidate, candidate_visual_root)
        candidate_visual_root.add_child(visual)
        visual.global_position = placement["world_position"]
        visual.set_meta(&"actor_id", actor_id)
        var binder := visual.get_node_or_null("RuntimePresentationBinder") as EnemyRuntimePresentationBinder
        var status := EnemyCombatStatusPresenter.new()
        visual.add_child(status)
        if binder == null or not binder.bind_runtime(candidate, actor_id) or not binder.bind_archetype_runtime(runtime) or not status.bind_runtime(candidate, actor_id):
            return _abort_spawn(candidate, candidate_visual_root)
        var phase := EnemySignatureActionPhaseDriver.new()
        var timing := EnemySignatureActionTimingCatalog.get_timing(archetype_id)
        if timing.is_empty() or not phase.configure(runtime, timing):
            return _abort_spawn(candidate, candidate_visual_root)
        phase.active_delivery_window_opened.connect(_on_enemy_active_delivery_window.bind(encounter_id))
        var executor := EnemyActiveAttackDeliveryExecutor.new()
        if not executor.configure(runtime, phase):
            return _abort_spawn(candidate, candidate_visual_root)
        var decision := EnemyPrototypeDecisionDriver.new()
        if not decision.configure(runtime, phase, DECISION_TUNING):
            return _abort_spawn(candidate, candidate_visual_root)
        var movement := EnemyPrototypeMovementDriver.new()
        if not movement.configure(runtime, visual, MOVEMENT_TUNING):
            return _abort_spawn(candidate, candidate_visual_root)
        movement.set_target_node(_player)
        movement.status_playtest_tuning = status_playtest_tuning
        visuals[actor_id] = visual
        runtimes[actor_id] = runtime
        phases[actor_id] = phase
        decisions[actor_id] = decision
        movements[actor_id] = movement
        executors[actor_id] = executor
    if status_playtest_tuning != null and status_playtest_tuning.validate_tuning().is_empty():
        candidate.status_playtest_tuning = status_playtest_tuning
    _encounter = candidate
    _encounter_id = encounter_id
    _visual_root = candidate_visual_root
    _visuals = visuals
    _archetype_runtimes = runtimes
    _phase_drivers = phases
    _decision_drivers = decisions
    _movement_drivers = movements
    _attack_executors = executors
    candidate.enemy_defeated.connect(_on_enemy_defeated)
    encounter_started.emit(encounter_id, candidate)
    return true

func _abort_spawn(candidate: CombatEncounterRuntime, visuals: Node2D) -> bool:
    candidate.end_encounter()
    visuals.queue_free()
    return false

func _placements_for_wave(descriptor: Dictionary, index: int) -> Array[Dictionary]:
    var wave_ids := descriptor.get("wave_ids", []) as Array
    var result: Array[Dictionary] = []
    if index < 0 or index >= wave_ids.size():
        return result
    var wave_id := StringName(String(wave_ids[index]))
    var objective: Dictionary = {}
    if _profile != null and descriptor.get("quest_id", &"") != &"":
        var raw_entry: Variant = _profile.quest_progress.get(String(descriptor["quest_id"]), null)
        if raw_entry is Dictionary:
            objective = (raw_entry as Dictionary).get("objective_state", {}) as Dictionary
    var already_defeated := objective.get("defeated_actor_ids", []) as Array
    if descriptor.get("quest_id", &"") == Region3SideQuestAttemptService.QUEST_DEFENSE:
        already_defeated = (objective.get("defeated_actor_ids_by_wave", {}) as Dictionary).get(String(wave_id), []) as Array
    for placement: Dictionary in descriptor.get("enemy_placements", []) as Array:
        if StringName(String(placement["wave_id"])) == wave_id and not already_defeated.has(String(placement["actor_id"])):
            result.append(placement)
    return result

func _on_enemy_active_delivery_window(context: Dictionary, encounter_id: StringName) -> void:
    if encounter_id == _encounter_id:
        enemy_active_delivery_window_opened.emit(encounter_id, context.duplicate(true))

func _on_enemy_defeated(actor_id: StringName) -> void:
    if _active_quest_id == &"" or _pending_defeats.has(actor_id):
        return
    if not _descriptor.get("enemy_placements", []).any(func(raw: Dictionary) -> bool: return raw["actor_id"] == actor_id):
        return
    _pending_defeats.append(actor_id)
    var visual := _visuals.get(actor_id) as Node2D
    if visual != null:
        visual.visible = false
    _commit_pending_defeats()

func _commit_pending_defeats() -> void:
    if _active_quest_id == &"":
        return
    for actor_id: StringName in _pending_defeats.duplicate():
        var payload := {"actor_id": actor_id}
        if _active_quest_id == Region3SideQuestAttemptService.QUEST_DEFENSE:
            payload["wave_id"] = StringName(String((_descriptor["wave_ids"] as Array)[_wave_index]))
        if _active_quest_id == Region3SideQuestAttemptService.QUEST_ESCORT:
            _pending_defeats.erase(actor_id)
            continue
        var result := _record_event(QuestFamilyObjectiveService.EVENT_ACTOR_DEFEATED, payload)
        if not bool(result.get("accepted", false)):
            continue
        _pending_defeats.erase(actor_id)
        if bool(result.get("objectives_complete", false)) or _active_quest_id == Region3SideQuestAttemptService.QUEST_DEFENSE and _encounter != null and _encounter.get_active_enemy_count() == 0:
            _wave_transition_pending = true
            break

func _record_event(event_id: StringName, payload: Dictionary) -> Dictionary:
    if _active_quest_id == &"":
        return _rejected(&"region3_quest_not_active")
    var snapshot := _escort_runtime_snapshot() if _escort_actor != null and _escort_actor.current_hp > 0 else {}
    var result := Region3SideQuestAttemptService.commit_event(_save, _slot, _profile,
        _active_quest_id, _active_attempt_id, event_id, payload, snapshot)
    if bool(result.get("accepted", false)):
        quest_progressed.emit(_active_quest_id, result.duplicate(true))
        if bool(result.get("failed", false)):
            quest_failed.emit(_active_quest_id, StringName(String(payload.get("reason_id", &"objective_destroyed"))))
    return result

func _escort_runtime_snapshot() -> Dictionary:
    if _escort_actor == null or _escort_actor.current_hp <= 0:
        return {}
    return {
        "actor_pos_x": _escort_actor.global_position.x,
        "actor_pos_y": _escort_actor.global_position.y,
        "escort_hp": _escort_actor.current_hp,
    }

func _on_escort_defeated() -> void:
    var result := _record_event(QuestFamilyObjectiveService.EVENT_FAILED, {"reason_id": &"escort_actor_defeated"})
    if bool(result.get("accepted", false)):
        _clear_live_session()

func _physics_process(delta: float) -> void:
    if _active_quest_id == &"" or _profile == null or _player == null:
        return
    _physics_tick += 1
    if not _pending_defeats.is_empty():
        _commit_pending_defeats()
    if _wave_transition_pending:
        _wave_transition_pending = false
        _advance_wave_if_ready()
    if _encounter == null and _physics_tick % 30 == 0:
        _maybe_activate_site_wave()
    _advance_escort(delta)
    if _encounter == null:
        return
    _encounter.advance_status_ticks(1)
    var actor_ids := _visuals.keys()
    actor_ids.sort()
    for raw_actor_id: Variant in actor_ids:
        var actor_id := StringName(String(raw_actor_id))
        if not _encounter.is_enemy_tactical_eligible(actor_id):
            continue
        var phase := _phase_drivers.get(actor_id) as EnemySignatureActionPhaseDriver
        if phase != null:
            phase.advance_fixed_tick()
        var visual := _visuals.get(actor_id) as Node2D
        var decision := _decision_drivers.get(actor_id) as EnemyPrototypeDecisionDriver
        var movement := _movement_drivers.get(actor_id) as EnemyPrototypeMovementDriver
        if visual == null or decision == null or movement == null:
            continue
        var visible := _has_line_of_sight(visual.global_position, _player.global_position)
        var selection := decision.observe_and_decide(
            _physics_tick, visual.global_position, _player.global_position, visible,
            _next_enemy_action_id, {"telegraph_ready": true, "reinforcement_budget_available": false}
        )
        if bool(selection.get("committed", false)):
            _next_enemy_action_id += 1
        movement.apply_decision(selection)
        if _active_quest_id == Region3SideQuestAttemptService.QUEST_DEFENSE and _defense_actor != null:
            visual.global_position = visual.global_position.move_toward(_defense_actor.global_position, MOVEMENT_TUNING.move_speed_px_per_second * delta)
        else:
            movement.advance_fixed(delta)
    if _physics_tick % escort_hazard_check_interval_ticks == 0:
        _advance_objective_hazards()

func _maybe_activate_site_wave() -> void:
    if _encounter != null or _active_quest_id not in [
        Region3SideQuestAttemptService.QUEST_ESCORT,
        Region3SideQuestAttemptService.QUEST_DEFENSE,
    ]:
        return
    if _wave_index < 0 or _wave_index >= (_descriptor.get("wave_ids", []) as Array).size():
        return
    # A saved defense attempt can resume in wave 2 or 3. The persisted
    # defeated-actor ledger determines which actors remain in that wave.
    if _placements_for_wave(_descriptor, _wave_index).is_empty():
        return
    var entry := _profile.quest_progress.get(String(_active_quest_id), {}) as Dictionary
    if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_ACTIVE:
        return
    var site := _escort_actor.global_position if _escort_actor != null else _defense_actor.global_position
    if _player.global_position.distance_to(site) > site_activation_radius_px:
        return
    var player_state_variant: Variant = _player_state_provider.call()
    if player_state_variant is CombatantRuntimeState:
        _start_wave(player_state_variant as CombatantRuntimeState)

func _advance_escort(delta: float) -> void:
    if _escort_actor == null or _escort_driver == null or _active_quest_id != Region3SideQuestAttemptService.QUEST_ESCORT:
        return
    var entry := _profile.quest_progress.get(String(_active_quest_id), {}) as Dictionary
    if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_ACTIVE:
        return
    var objective := entry.get("objective_state", {}) as Dictionary
    var is_far := _player.global_position.distance_to(_escort_actor.global_position) > float(_descriptor["escort_follow_distance_px"])
    if is_far != _separation_waiting:
        _separation_waiting = is_far
        escort_separation_changed.emit(is_far)
    var waiting := bool(objective.get("wait_requested", false)) or is_far
    if _encounter == null and _escort_driver.next_route_index() == 0:
        waiting = true
    var update := _escort_driver.physics_step(delta, waiting)
    for node_id: StringName in update.get("reached_route_node_ids", []) as Array[StringName]:
        var event := _record_event(QuestFamilyObjectiveService.EVENT_ROUTE_NODE_REACHED, {"route_node_id": node_id})
        if not bool(event.get("accepted", false)):
            _escort_actor.velocity = Vector2.ZERO
            _restore_escort_checkpoint()
            return
    if bool(update.get("complete", false)):
        if waiting:
            return
        var goal := _descriptor["escort_goal_world_position"] as Vector2
        var distance := _escort_actor.global_position.distance_to(goal)
        if distance > float(_descriptor["escort_arrival_tolerance_px"]):
            _escort_actor.velocity = _escort_actor.global_position.direction_to(goal) * minf(float(_descriptor["escort_speed_px_per_second"]), distance / delta)
            _escort_actor.move_and_slide()
        if _escort_actor.global_position.distance_to(goal) <= float(_descriptor["escort_arrival_tolerance_px"]):
            _record_event(QuestFamilyObjectiveService.EVENT_GOAL_REACHED, {"goal_id": (_descriptor["objective_config"] as Dictionary)["goal_id"]})

func _restore_escort_checkpoint() -> void:
    if _escort_actor == null or _escort_driver == null:
        return
    var entry := _profile.quest_progress.get(String(_active_quest_id), {}) as Dictionary
    var objective := entry.get("objective_state", {}) as Dictionary
    var index := int(objective.get("next_route_index", 0))
    var route := _descriptor["escort_route"] as Array
    _escort_actor.global_position = (route[index - 1] as Dictionary)["world_position"] if index > 0 and index <= route.size() else _descriptor["escort_start_world_position"]
    _escort_driver.configure(_escort_actor, route, float(_descriptor["escort_speed_px_per_second"]),
        float(_descriptor["escort_arrival_tolerance_px"]), index)

func _advance_objective_hazards() -> void:
    var target: Node2D = _defense_actor if _defense_actor != null else _escort_actor
    if target == null or _active_quest_id == &"":
        return
    var entry := _profile.quest_progress.get(String(_active_quest_id), {}) as Dictionary
    if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_ACTIVE:
        return
    for raw_actor_id: Variant in _visuals.keys():
        var actor_id := StringName(String(raw_actor_id))
        var visual := _visuals.get(actor_id) as Node2D
        if visual == null or not _encounter.is_enemy_tactical_eligible(actor_id):
            continue
        if visual.global_position.distance_to(target.global_position) > float(_descriptor["hostile_objective_contact_radius_px"]):
            continue
        if _physics_tick < int(_hazard_cooldown_by_actor.get(actor_id, 0)):
            continue
        if _defense_actor != null:
            var event := _record_event(QuestFamilyObjectiveService.EVENT_OBJECTIVE_DAMAGE, {"amount": int(_descriptor["hostile_objective_damage"])})
            if bool(event.get("accepted", false)):
                _defense_actor.apply_damage(int(_descriptor["hostile_objective_damage"]))
                _hazard_cooldown_by_actor[actor_id] = _physics_tick + int(_descriptor["hostile_objective_contact_cooldown_ticks"])
                if bool(event.get("failed", false)):
                    _clear_live_session()
                    return
        elif _escort_actor != null:
            var hp_before := _escort_actor.current_hp
            if not _escort_actor.apply_damage(int(_descriptor["hostile_objective_damage"])):
                continue
            if _active_quest_id == &"":
                return
            if _escort_actor.current_hp == 0:
                # Failed durability must leave the actor available for retrying
                # the terminal event on the next verified contact.
                _escort_actor.current_hp = hp_before
                _escort_actor.queue_redraw()
                return
            var saved := capture_escort_safe_state()
            if not bool(saved.get("accepted", false)):
                _escort_actor.current_hp = hp_before
                _escort_actor.queue_redraw()
                return
            _hazard_cooldown_by_actor[actor_id] = _physics_tick + int(_descriptor["hostile_objective_contact_cooldown_ticks"])

func _advance_wave_if_ready() -> void:
    if _active_quest_id != Region3SideQuestAttemptService.QUEST_DEFENSE or _encounter == null:
        return
    if _encounter.get_active_enemy_count() > 0 or not _pending_defeats.is_empty():
        return
    _end_encounter()
    _wave_index += 1
    if _wave_index >= (_descriptor["wave_ids"] as Array).size():
        return
    var player_state_variant: Variant = _player_state_provider.call()
    if not player_state_variant is CombatantRuntimeState or not _start_wave(player_state_variant as CombatantRuntimeState):
        quest_failed.emit(_active_quest_id, &"region3_quest_next_wave_unavailable")

func _has_line_of_sight(start: Vector2, goal: Vector2) -> bool:
    if start.distance_squared_to(goal) <= 0.0001:
        return true
    var query := PhysicsRayQueryParameters2D.create(start, goal, 1)
    query.collide_with_bodies = true
    query.collide_with_areas = false
    var hit := get_world_2d().direct_space_state.intersect_ray(query)
    return hit.is_empty() or hit.get("collider") == _player

func _end_encounter() -> void:
    if _encounter == null:
        return
    var old_id := _encounter_id
    _encounter.end_encounter()
    _encounter = null
    _encounter_id = &""
    _visuals.clear()
    _archetype_runtimes.clear()
    _phase_drivers.clear()
    _decision_drivers.clear()
    _movement_drivers.clear()
    _attack_executors.clear()
    _hazard_cooldown_by_actor.clear()
    if _visual_root != null:
        _visual_root.queue_free()
        _visual_root = null
    encounter_ended.emit(old_id)

func _clear_live_session() -> void:
    _end_encounter()
    if _escort_actor != null:
        _escort_actor.queue_free()
        _escort_actor = null
    _escort_driver = null
    if _defense_actor != null:
        _defense_actor.queue_free()
        _defense_actor = null
    _active_quest_id = &""
    _active_attempt_id = &""
    _descriptor.clear()
    _wave_index = 0
    _pending_defeats.clear()
    _separation_waiting = false
    _wave_transition_pending = false

func _exit_tree() -> void:
    _clear_live_session()
    if _markers != null and is_instance_valid(_markers):
        _markers.queue_free()
        _markers = null

func _rejected(reason_id: StringName) -> Dictionary:
    return {"accepted": false, "reason_id": reason_id, "durable": false}
