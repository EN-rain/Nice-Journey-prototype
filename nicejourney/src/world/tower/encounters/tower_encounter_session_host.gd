class_name TowerEncounterSessionHost
extends Node2D

const DECISION_TUNING: EnemyPrototypeDecisionTuning = preload("res://src/data/tuning/enemy_prototype_decision_default.tres")
const MOVEMENT_TUNING: EnemyPrototypeMovementTuning = preload("res://src/data/tuning/enemy_prototype_movement_default.tres")

signal encounter_started(encounter_id: StringName)
signal encounter_progressed(encounter_id: StringName, result: Dictionary)
signal encounter_ended(encounter_id: StringName)
signal enemy_active_delivery_window_opened(encounter_id: StringName, context: Dictionary)

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_ALREADY_ACTIVE: StringName = &"encounter_already_active"
const REASON_RUNTIME_FAILED: StringName = &"runtime_failed"
const REASON_PRESENTATION_FAILED: StringName = &"presentation_failed"
const REASON_PROGRESS_BIND_FAILED: StringName = &"progress_binding_failed"
const REINFORCEMENT_SPENT_KEY: String = "summoner_reinforcement_spent_actor_ids"

var shared_active_combat: ActiveCombatRegistry = ActiveCombatRegistry.new()
var shared_full_ai: FullAiSimulationLedger = FullAiSimulationLedger.new()
var shared_attack_pressure: AttackPressureLedger = AttackPressureLedger.new()
# Explicitly optional, provisional per-archetype authored hit/payload values.
# Null preserves legacy tests and makes missing authoring fail closed.
var playtest_attack_catalog: EnemyPlaytestAttackCatalog = null
var status_playtest_tuning: StatusPlaytestTuning = null
var reinforcement_tuning: SummonerReinforcementPlaytestTuning = null
var decision_target: PlayerController = null
var decision_action_state_machine: ActionStateMachine = null
var _sessions: Dictionary = {}
var _decision_tick: int = 0
var _next_enemy_action_instance_id: int = 1000000

func set_decision_target(target: PlayerController) -> void:
    decision_target = target

func set_decision_action_state_machine(machine: ActionStateMachine) -> void:
    decision_action_state_machine = machine

func set_reinforcement_tuning(tuning: SummonerReinforcementPlaytestTuning) -> bool:
    if tuning == null or not tuning.validate_tuning().is_empty():
        return false
    reinforcement_tuning = tuning
    return true

func activate_encounter(
    profile: ProfileSnapshot,
    floor_state: FloorInstanceState,
    plan: Dictionary,
    encounter_id: StringName,
    player_state: CombatantRuntimeState,
    enemy_states: Dictionary,
    visual_catalog: EnemyVisualSceneCatalog,
    quest_bindings_by_actor: Dictionary = {}
) -> Dictionary:
    if profile == null or floor_state == null or visual_catalog == null or not StableId.is_valid(String(encounter_id)):
        return _rejected(REASON_INVALID_CONTEXT, encounter_id)
    if _sessions.has(encounter_id):
        return _rejected(REASON_ALREADY_ACTIVE, encounter_id)

    var reinforcement_plan: Dictionary = {}
    if reinforcement_tuning != null:
        reinforcement_plan = SummonerReinforcementPlan.build(plan, floor_state, encounter_id, reinforcement_tuning)
        if not bool(reinforcement_plan.get("accepted", false)):
            var budget_rejected := _rejected(REASON_RUNTIME_FAILED, encounter_id)
            budget_rejected["runtime_reason_id"] = StringName(reinforcement_plan.get("reason_id", &""))
            return budget_rejected

    var activation := TowerEncounterRuntimeFactory.activate(
        floor_state,
        plan,
        encounter_id,
        player_state,
        enemy_states,
        shared_active_combat,
        shared_full_ai,
        shared_attack_pressure
    )
    if not bool(activation.get("accepted", false)):
        var rejected := _rejected(REASON_RUNTIME_FAILED, encounter_id)
        rejected["runtime_reason_id"] = StringName(activation.get("reason_id", &""))
        rejected["runtime_errors"] = (activation.get("errors", PackedStringArray()) as PackedStringArray).duplicate()
        return rejected
    if bool(activation.get("resolved", false)):
        return {
            "accepted": true,
            "reason_id": StringName(activation.get("reason_id", &"encounter_already_resolved")),
            "encounter_id": encounter_id,
            "resolved": true,
            "presentation_root": null,
            "active_enemy_count": 0,
        }

    var encounter := activation.get("encounter_runtime") as CombatEncounterRuntime
    if encounter == null:
        return _rejected(REASON_RUNTIME_FAILED, encounter_id)
    if status_playtest_tuning != null and status_playtest_tuning.validate_tuning().is_empty():
        encounter.status_playtest_tuning = status_playtest_tuning
    var presentation := TowerEncounterPresentationFactory.build(activation, visual_catalog)
    if not bool(presentation.get("accepted", false)):
        encounter.end_encounter()
        var rejected := _rejected(REASON_PRESENTATION_FAILED, encounter_id)
        rejected["presentation_reason_id"] = StringName(presentation.get("reason_id", &""))
        rejected["presentation_errors"] = (presentation.get("errors", PackedStringArray()) as PackedStringArray).duplicate()
        return rejected
    var presentation_root := presentation.get("root") as Node2D
    if presentation_root == null:
        encounter.end_encounter()
        return _rejected(REASON_PRESENTATION_FAILED, encounter_id)

    var blackboard := EncounterBlackboard.new()
    if not blackboard.configure(encounter_id):
        presentation_root.free()
        encounter.end_encounter()
        return _rejected(REASON_RUNTIME_FAILED, encounter_id)

    var progress_binder := TowerEncounterProgressBinder.new()
    if not progress_binder.bind(profile, floor_state, encounter, quest_bindings_by_actor):
        presentation_root.free()
        encounter.end_encounter()
        return _rejected(REASON_PROGRESS_BIND_FAILED, encounter_id)
    progress_binder.progress_committed.connect(_on_progress_committed.bind(encounter_id))
    encounter.enemy_defeated.connect(_on_encounter_enemy_defeated.bind(encounter_id))

    var action_phase_drivers: Dictionary = {}
    var attack_delivery_executors: Dictionary = {}
    var decision_drivers: Dictionary = {}
    var movement_drivers: Dictionary = {}
    var visuals_by_actor := presentation.get("visuals_by_actor", {}) as Dictionary
    var archetype_runtimes := activation.get("archetype_runtimes", {}) as Dictionary
    for raw_actor_id: Variant in archetype_runtimes.keys():
        var actor_id := StringName(String(raw_actor_id))
        var archetype_runtime := archetype_runtimes[raw_actor_id] as EnemyArchetypeRuntime
        if archetype_runtime == null or archetype_runtime.definition == null:
            progress_binder.unbind()
            presentation_root.free()
            encounter.end_encounter()
            return _rejected(REASON_RUNTIME_FAILED, encounter_id)
        if playtest_attack_catalog != null and playtest_attack_catalog.validate_catalog().is_empty():
            var playtest_attack := playtest_attack_catalog.attack_for(archetype_runtime.definition.archetype_id)
            if playtest_attack != null:
                archetype_runtime.definition.signature_attack_authoring = playtest_attack
        var timing := EnemySignatureActionTimingCatalog.get_timing(archetype_runtime.definition.archetype_id)
        var driver := EnemySignatureActionPhaseDriver.new()
        if timing.is_empty() or not driver.configure(archetype_runtime, timing):
            progress_binder.unbind()
            presentation_root.free()
            encounter.end_encounter()
            return _rejected(REASON_RUNTIME_FAILED, encounter_id)
        driver.active_delivery_window_opened.connect(_on_enemy_active_delivery_window_opened.bind(encounter_id))
        action_phase_drivers[actor_id] = driver
        var delivery_executor := EnemyActiveAttackDeliveryExecutor.new()
        if not delivery_executor.configure(archetype_runtime, driver):
            progress_binder.unbind()
            presentation_root.free()
            encounter.end_encounter()
            return _rejected(REASON_RUNTIME_FAILED, encounter_id)
        attack_delivery_executors[actor_id] = delivery_executor
        var decision_driver := EnemyPrototypeDecisionDriver.new()
        if not decision_driver.configure(archetype_runtime, driver, DECISION_TUNING):
            progress_binder.unbind()
            presentation_root.free()
            encounter.end_encounter()
            return _rejected(REASON_RUNTIME_FAILED, encounter_id)
        decision_drivers[actor_id] = decision_driver
        var visual := visuals_by_actor.get(actor_id, visuals_by_actor.get(String(actor_id), null)) as Node2D
        var movement_driver := EnemyPrototypeMovementDriver.new()
        if visual == null or not movement_driver.configure(archetype_runtime, visual, MOVEMENT_TUNING):
            progress_binder.unbind()
            presentation_root.free()
            encounter.end_encounter()
            return _rejected(REASON_RUNTIME_FAILED, encounter_id)
        movement_driver.set_target_node(decision_target)
        movement_driver.status_playtest_tuning = status_playtest_tuning
        movement_drivers[actor_id] = movement_driver

    presentation_root.name = _node_name("Encounter_%s" % String(encounter_id))
    add_child(presentation_root)
    _sessions[encounter_id] = {
        "encounter_runtime": encounter,
        "archetype_runtimes": archetype_runtimes.duplicate(),
        "action_phase_drivers": action_phase_drivers,
        "attack_delivery_executors": attack_delivery_executors,
        "decision_drivers": decision_drivers,
        "movement_drivers": movement_drivers,
        "blackboard": blackboard,
        "visuals_by_actor": visuals_by_actor.duplicate(),
        "presentation_root": presentation_root,
        "visual_catalog": visual_catalog,
        "progress_binder": progress_binder,
        "profile": profile,
        "floor_state": floor_state,
        "reinforcements_by_summoner": reinforcement_plan.get("slots_by_summoner", {}),
        "reinforcements_used": {},
        "reinforcement_action_instances": {},
    }
    encounter_started.emit(encounter_id)
    return {
        "accepted": true,
        "reason_id": &"",
        "encounter_id": encounter_id,
        "resolved": false,
        "presentation_root": presentation_root,
        "active_enemy_count": encounter.get_active_enemy_count(),
    }

func end_encounter(encounter_id: StringName) -> bool:
    if not _sessions.has(encounter_id):
        return false
    var session := _sessions[encounter_id] as Dictionary
    var binder := session.get("progress_binder") as TowerEncounterProgressBinder
    if binder != null:
        binder.unbind()
    var root := session.get("presentation_root") as Node2D
    if root != null and is_instance_valid(root):
        root.queue_free()
    var encounter := session.get("encounter_runtime") as CombatEncounterRuntime
    if encounter != null:
        if encounter.enemy_defeated.is_connected(_on_encounter_enemy_defeated.bind(encounter_id)):
            encounter.enemy_defeated.disconnect(_on_encounter_enemy_defeated.bind(encounter_id))
        encounter.end_encounter()
    _sessions.erase(encounter_id)
    encounter_ended.emit(encounter_id)
    return true

func end_all_encounters() -> void:
    var ids: Array = _sessions.keys()
    ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    for raw_id: Variant in ids:
        end_encounter(StringName(String(raw_id)))

func is_encounter_active(encounter_id: StringName) -> bool:
    return _sessions.has(encounter_id)

func get_active_encounter_count() -> int:
    return _sessions.size()

func get_active_encounter_ids() -> Array[StringName]:
    var result: Array[StringName] = []
    for raw_id: Variant in _sessions.keys():
        result.append(StringName(String(raw_id)))
    result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
    return result


func get_visuals_by_actor(encounter_id: StringName) -> Dictionary:
    if not _sessions.has(encounter_id):
        return {}
    return ((_sessions[encounter_id] as Dictionary).get("visuals_by_actor", {}) as Dictionary).duplicate()


func get_encounter_runtime(encounter_id: StringName) -> CombatEncounterRuntime:
    if not _sessions.has(encounter_id):
        return null
    return (_sessions[encounter_id] as Dictionary).get("encounter_runtime") as CombatEncounterRuntime

func get_archetype_runtime(encounter_id: StringName, actor_id: StringName) -> EnemyArchetypeRuntime:
    if not _sessions.has(encounter_id):
        return null
    var runtimes := (_sessions[encounter_id] as Dictionary).get("archetype_runtimes", {}) as Dictionary
    return runtimes.get(actor_id, runtimes.get(String(actor_id), null)) as EnemyArchetypeRuntime

func get_action_phase_driver(encounter_id: StringName, actor_id: StringName) -> EnemySignatureActionPhaseDriver:
    if not _sessions.has(encounter_id):
        return null
    var drivers := (_sessions[encounter_id] as Dictionary).get("action_phase_drivers", {}) as Dictionary
    return drivers.get(actor_id, drivers.get(String(actor_id), null)) as EnemySignatureActionPhaseDriver

func get_attack_delivery_executor(encounter_id: StringName, actor_id: StringName) -> EnemyActiveAttackDeliveryExecutor:
    if not _sessions.has(encounter_id):
        return null
    var executors := (_sessions[encounter_id] as Dictionary).get("attack_delivery_executors", {}) as Dictionary
    return executors.get(actor_id, executors.get(String(actor_id), null)) as EnemyActiveAttackDeliveryExecutor

func get_blackboard(encounter_id: StringName) -> EncounterBlackboard:
    if not _sessions.has(encounter_id):
        return null
    return (_sessions[encounter_id] as Dictionary).get("blackboard") as EncounterBlackboard

func get_decision_driver(encounter_id: StringName, actor_id: StringName) -> EnemyPrototypeDecisionDriver:
    if not _sessions.has(encounter_id):
        return null
    var drivers := (_sessions[encounter_id] as Dictionary).get("decision_drivers", {}) as Dictionary
    return drivers.get(actor_id, drivers.get(String(actor_id), null)) as EnemyPrototypeDecisionDriver

func get_movement_driver(encounter_id: StringName, actor_id: StringName) -> EnemyPrototypeMovementDriver:
    if not _sessions.has(encounter_id):
        return null
    var drivers := (_sessions[encounter_id] as Dictionary).get("movement_drivers", {}) as Dictionary
    return drivers.get(actor_id, drivers.get(String(actor_id), null)) as EnemyPrototypeMovementDriver

func has_reinforcement_budget(encounter_id: StringName, summoner_id: StringName) -> bool:
    if reinforcement_tuning == null or not _sessions.has(encounter_id):
        return false
    var session := _sessions[encounter_id] as Dictionary
    var encounter := session.get("encounter_runtime") as CombatEncounterRuntime
    var summoner := get_archetype_runtime(encounter_id, summoner_id)
    if (
        encounter == null or summoner == null or summoner.definition == null
        or summoner.definition.archetype_id != &"summoner"
        or not encounter.is_enemy_tactical_eligible(summoner_id)
    ):
        return false
    return not _next_reinforcement_slot(session, summoner_id).is_empty()

func spawn_summoner_reinforcement(encounter_id: StringName, summoner_id: StringName,
    context: Dictionary) -> Dictionary:
    if not has_reinforcement_budget(encounter_id, summoner_id):
        return {"accepted": false, "reason_id": &"reinforcement_budget_exhausted"}
    var session := _sessions[encounter_id] as Dictionary
    var encounter := session.get("encounter_runtime") as CombatEncounterRuntime
    var summoner := get_archetype_runtime(encounter_id, summoner_id)
    var driver := get_action_phase_driver(encounter_id, summoner_id)
    var action_instance_id := int(context.get("action_instance_id", 0))
    if (
        not bool(context.get("accepted", false))
        or StringName(String(context.get("encounter_id", &""))) != encounter_id
        or StringName(String(context.get("actor_id", &""))) != summoner_id
        or StringName(String(context.get("action_id", &""))) != &"action:summoner_reinforcement_call"
        or summoner.phase_id != EnemyArchetypeRuntime.PHASE_ACTIVE
        or driver == null or action_instance_id <= 0 or driver.action_instance_id != action_instance_id
        or not encounter.has_enemy_attack_ownership(summoner_id, summoner.target_id,
            action_instance_id, int(context.get("reservation_token", 0)))
    ):
        return {"accepted": false, "reason_id": &"reinforcement_unauthenticated_action"}
    var action_instances := session.get("reinforcement_action_instances", {}) as Dictionary
    if int(action_instances.get(summoner_id, 0)) == action_instance_id:
        return {"accepted": false, "reason_id": &"reinforcement_duplicate_action"}
    if shared_full_ai.get_admitted_count() >= FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS:
        return {"accepted": false, "reason_id": &"reinforcement_full_ai_cap"}
    var placement := _next_reinforcement_slot(session, summoner_id)
    var actor_id := StringName(String(placement.get("actor_id", &"")))
    var world_tile := placement.get("world_tile", Vector2i.ZERO) as Vector2i
    var position := (Vector2(world_tile) + Vector2(0.5, 0.5)) * float(TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE)
    if decision_target == null or not is_instance_valid(decision_target) or position.distance_to(decision_target.global_position) < reinforcement_tuning.spawn_min_distance_from_player_px:
        return {"accepted": false, "reason_id": &"reinforcement_spawn_space_denied"}
    var root := session.get("presentation_root") as Node2D
    var catalog := session.get("visual_catalog") as EnemyVisualSceneCatalog
    if root == null or not is_instance_valid(root) or catalog == null:
        return {"accepted": false, "reason_id": &"reinforcement_presentation_unavailable"}
    var scene := catalog.get_scene(reinforcement_tuning.reinforcement_archetype_id)
    if scene == null:
        return {"accepted": false, "reason_id": &"reinforcement_scene_missing"}
    var visual := scene.instantiate() as EnemyVisualController
    if visual == null or visual.profile == null or visual.profile.archetype_id != reinforcement_tuning.reinforcement_archetype_id:
        if visual != null:
            visual.free()
        return {"accepted": false, "reason_id": &"reinforcement_visual_invalid"}
    var presentation_binder := visual.get_node_or_null("RuntimePresentationBinder") as EnemyRuntimePresentationBinder
    if presentation_binder == null:
        visual.free()
        return {"accepted": false, "reason_id": &"reinforcement_binder_missing"}
    var one_actor_plan := {
        "plan_id": &"encounter_plan:reinforcement_runtime",
        "floor_id": (session["floor_state"] as FloorInstanceState).floor_id,
        "complete_floor_plan": false,
        "placements": [placement],
    }
    var states := TowerPrototypeEnemyRuntimeFactory.build_states(session["floor_state"] as FloorInstanceState,
        one_actor_plan, reinforcement_tuning.enemy_state_tuning)
    var state := states.get(actor_id) as CombatantRuntimeState
    if state == null or not encounter.register_enemy(state):
        visual.free()
        return {"accepted": false, "reason_id": &"reinforcement_ai_admission_failed"}
    var runtime := EnemyArchetypeRuntime.new()
    var phase_driver := EnemySignatureActionPhaseDriver.new()
    var attack_executor := EnemyActiveAttackDeliveryExecutor.new()
    var decision_driver := EnemyPrototypeDecisionDriver.new()
    var movement_driver := EnemyPrototypeMovementDriver.new()
    var timing := EnemySignatureActionTimingCatalog.get_timing(reinforcement_tuning.reinforcement_archetype_id)
    if (
        not runtime.configure(encounter, actor_id, summoner.target_id, reinforcement_tuning.reinforcement_archetype_id)
        or not phase_driver.configure(runtime, timing)
        or not attack_executor.configure(runtime, phase_driver)
        or not decision_driver.configure(runtime, phase_driver, DECISION_TUNING)
        or not movement_driver.configure(runtime, visual, MOVEMENT_TUNING)
    ):
        visual.free()
        end_encounter(encounter_id) # Fail closed: release the admitted actor and shared AI slot.
        return {"accepted": false, "reason_id": &"reinforcement_runtime_failed"}
    visual.name = _node_name(String(actor_id))
    visual.position = position
    visual.set_meta(&"actor_id", actor_id)
    visual.set_meta(&"archetype_id", reinforcement_tuning.reinforcement_archetype_id)
    visual.set_meta(&"elite", false)
    root.add_child(visual)
    if not presentation_binder.bind_runtime(encounter, actor_id) or not presentation_binder.bind_archetype_runtime(runtime):
        end_encounter(encounter_id)
        return {"accepted": false, "reason_id": &"reinforcement_presentation_bind_failed"}
    var status := EnemyCombatStatusPresenter.new()
    status.name = "CombatStatus"
    status.z_index = 50
    visual.add_child(status)
    if not status.bind_runtime(encounter, actor_id):
        end_encounter(encounter_id)
        return {"accepted": false, "reason_id": &"reinforcement_status_bind_failed"}
    phase_driver.active_delivery_window_opened.connect(_on_enemy_active_delivery_window_opened.bind(encounter_id))
    movement_driver.set_target_node(decision_target)
    movement_driver.status_playtest_tuning = status_playtest_tuning
    if playtest_attack_catalog != null and playtest_attack_catalog.validate_catalog().is_empty():
        var attack := playtest_attack_catalog.attack_for(reinforcement_tuning.reinforcement_archetype_id)
        if attack != null:
            runtime.definition.signature_attack_authoring = attack
    (session["archetype_runtimes"] as Dictionary)[actor_id] = runtime
    (session["action_phase_drivers"] as Dictionary)[actor_id] = phase_driver
    (session["attack_delivery_executors"] as Dictionary)[actor_id] = attack_executor
    (session["decision_drivers"] as Dictionary)[actor_id] = decision_driver
    (session["movement_drivers"] as Dictionary)[actor_id] = movement_driver
    (session["visuals_by_actor"] as Dictionary)[actor_id] = visual
    var profile := session.get("profile") as ProfileSnapshot
    var floor_state := session.get("floor_state") as FloorInstanceState
    var staged_floor := FloorInstanceState.new()
    if (
        profile == null or floor_state == null
        or not staged_floor.load_dictionary(floor_state.to_dictionary()).is_empty()
    ):
        end_encounter(encounter_id)
        return {"accepted": false, "reason_id": &"reinforcement_floor_state_invalid"}
    var spent_variant: Variant = staged_floor.quest_state.get(REINFORCEMENT_SPENT_KEY, [])
    if not spent_variant is Array or (spent_variant as Array).has(String(actor_id)):
        end_encounter(encounter_id)
        return {"accepted": false, "reason_id": &"reinforcement_spent_state_invalid"}
    var spent_ids := (spent_variant as Array).duplicate()
    spent_ids.append(String(actor_id))
    spent_ids.sort()
    staged_floor.quest_state[REINFORCEMENT_SPENT_KEY] = spent_ids
    if not TowerFloorStateService.commit_floor_state(profile, staged_floor):
        end_encounter(encounter_id)
        return {"accepted": false, "reason_id": &"reinforcement_spent_commit_failed"}
    if not floor_state.load_dictionary(staged_floor.to_dictionary()).is_empty():
        end_encounter(encounter_id)
        return {"accepted": false, "reason_id": &"reinforcement_floor_sync_failed"}
    (session["reinforcements_used"] as Dictionary)[actor_id] = true
    action_instances[summoner_id] = action_instance_id
    return {"accepted": true, "reason_id": &"", "mode": &"reinforcement",
        "actor_id": actor_id, "archetype_id": reinforcement_tuning.reinforcement_archetype_id,
        "remaining_budget": _remaining_reinforcement_count(session, summoner_id)}

func _next_reinforcement_slot(session: Dictionary, summoner_id: StringName) -> Dictionary:
    var slots := (session.get("reinforcements_by_summoner", {}) as Dictionary).get(summoner_id, []) as Array
    var used := session.get("reinforcements_used", {}) as Dictionary
    for raw_slot: Variant in slots:
        var slot := raw_slot as Dictionary
        var actor_id := StringName(String(slot.get("actor_id", &"")))
        if not used.has(actor_id) and _reinforcement_slot_available(session, actor_id):
            return slot
    return {}

func _remaining_reinforcement_count(session: Dictionary, summoner_id: StringName) -> int:
    var slots := (session.get("reinforcements_by_summoner", {}) as Dictionary).get(summoner_id, []) as Array
    var used := session.get("reinforcements_used", {}) as Dictionary
    var remaining := 0
    for raw_slot: Variant in slots:
        var actor_id := StringName(String((raw_slot as Dictionary).get("actor_id", &"")))
        if not used.has(actor_id) and _reinforcement_slot_available(session, actor_id):
            remaining += 1
    return remaining

func _reinforcement_slot_available(session: Dictionary, actor_id: StringName) -> bool:
    var floor_state := session.get("floor_state") as FloorInstanceState
    if floor_state == null or floor_state.defeated_actor_ids.has(actor_id):
        return false
    var spent_variant: Variant = floor_state.quest_state.get(REINFORCEMENT_SPENT_KEY, [])
    return spent_variant is Array and not (spent_variant as Array).has(String(actor_id))

func _physics_process(_delta: float) -> void:
    _decision_tick += 1
    var encounter_ids: Array = _sessions.keys()
    encounter_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    for raw_encounter_id: Variant in encounter_ids:
        var session_variant: Variant = _sessions.get(raw_encounter_id, null)
        if not session_variant is Dictionary:
            continue
        var session := session_variant as Dictionary
        var phase_drivers := session.get("action_phase_drivers", {}) as Dictionary
        var phase_actor_ids: Array = phase_drivers.keys()
        phase_actor_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
        for raw_actor_id: Variant in phase_actor_ids:
            var driver := phase_drivers.get(raw_actor_id) as EnemySignatureActionPhaseDriver
            if driver != null:
                driver.advance_fixed_tick()
        var encounter := session.get("encounter_runtime") as CombatEncounterRuntime
        if encounter != null:
            encounter.advance_status_ticks(1)
        _advance_session_movement(session, _delta)
        if decision_target == null or not is_instance_valid(decision_target):
            continue
        _advance_session_decisions(session)

func _advance_session_movement(session: Dictionary, delta: float) -> void:
    var movement_drivers := session.get("movement_drivers", {}) as Dictionary
    var actor_ids: Array = movement_drivers.keys()
    actor_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    for raw_actor_id: Variant in actor_ids:
        var movement_driver := movement_drivers.get(raw_actor_id) as EnemyPrototypeMovementDriver
        if movement_driver == null:
            continue
        movement_driver.set_target_node(decision_target if decision_target != null and is_instance_valid(decision_target) else null)
        movement_driver.advance_fixed(delta)

func _advance_session_decisions(session: Dictionary) -> void:
    var encounter := session.get("encounter_runtime") as CombatEncounterRuntime
    var decision_drivers := session.get("decision_drivers", {}) as Dictionary
    var movement_drivers := session.get("movement_drivers", {}) as Dictionary
    var visuals := session.get("visuals_by_actor", {}) as Dictionary
    var blackboard := session.get("blackboard") as EncounterBlackboard
    var actor_ids: Array = decision_drivers.keys()
    actor_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    if blackboard != null:
        blackboard.purge_expired(_decision_tick)

    var visibility_by_actor: Dictionary = {}
    var any_target_visible := false
    var shared_target_id: StringName = &""
    for raw_actor_id: Variant in actor_ids:
        var actor_id := StringName(String(raw_actor_id))
        var decision_driver := decision_drivers.get(raw_actor_id) as EnemyPrototypeDecisionDriver
        var visual := visuals.get(actor_id, visuals.get(String(actor_id), null)) as Node2D
        if decision_driver == null or visual == null or not is_instance_valid(visual):
            continue
        var target_visible := _has_line_of_sight(visual.global_position, decision_target.global_position)
        visibility_by_actor[actor_id] = target_visible
        if target_visible:
            any_target_visible = true
            shared_target_id = decision_driver.runtime.target_id

    if blackboard != null and any_target_visible and shared_target_id != &"" and _decision_tick % DECISION_TUNING.evaluation_interval_ticks == 0:
        blackboard.publish_observed_fact(
            shared_target_id,
            decision_target.global_position,
            EnemyPrototypeDecisionDriver.OBSERVED_TARGET_STATE,
            _decision_tick,
            1.0,
            DECISION_TUNING.observation_lifetime_ticks,
            _decision_tick
        )

    var shared_fact: Dictionary = {}
    if blackboard != null and shared_target_id != &"":
        shared_fact = blackboard.latest_fact(shared_target_id, _decision_tick, 0.0)

    for raw_actor_id: Variant in actor_ids:
        var actor_id := StringName(String(raw_actor_id))
        var decision_driver := decision_drivers.get(raw_actor_id) as EnemyPrototypeDecisionDriver
        var visual := visuals.get(actor_id, visuals.get(String(actor_id), null)) as Node2D
        if decision_driver == null or visual == null or not is_instance_valid(visual):
            continue
        var target_visible := bool(visibility_by_actor.get(actor_id, false))
        if not target_visible and not shared_fact.is_empty():
            decision_driver.admit_shared_observation(shared_fact, _decision_tick)
        var action_observation := _observed_player_action_state(target_visible)
        var internal_facts := {
            "ally_observed": _has_observed_ally(actor_id, visual.global_position, visuals, encounter),
            "flank_observed": target_visible and _is_observed_flank(visual.global_position),
            "reinforcement_budget_available": has_reinforcement_budget(encounter.encounter_id, actor_id),
            "telegraph_ready": true,
            "objective_contested": false,
            "observed_player_recovering": bool(action_observation.get("recovering", false)),
            "observed_player_committed": bool(action_observation.get("committed", false)),
        }
        var decision := decision_driver.observe_and_decide(
            _decision_tick,
            visual.global_position,
            decision_target.global_position,
            target_visible,
            _next_enemy_action_instance_id,
            internal_facts
        )
        var movement_driver := movement_drivers.get(actor_id, movement_drivers.get(String(actor_id), null)) as EnemyPrototypeMovementDriver
        if movement_driver != null:
            movement_driver.apply_decision(decision)
        if bool(decision.get("committed", false)):
            _next_enemy_action_instance_id += 1

func _observed_player_action_state(target_visible: bool) -> Dictionary:
    if not target_visible or decision_action_state_machine == null:
        return {"committed": false, "recovering": false}
    var phase := decision_action_state_machine.get_phase()
    return {
        "committed": phase == ActionStateMachine.Phase.COMMIT or phase == ActionStateMachine.Phase.ACTIVE,
        "recovering": phase == ActionStateMachine.Phase.RECOVERY,
    }

func _has_observed_ally(actor_id: StringName, actor_position: Vector2, visuals: Dictionary, encounter: CombatEncounterRuntime) -> bool:
    if encounter == null:
        return false
    var ally_ids: Array = visuals.keys()
    ally_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    for raw_ally_id: Variant in ally_ids:
        var ally_id := StringName(String(raw_ally_id))
        if ally_id == actor_id or not encounter.is_enemy_tactical_eligible(ally_id):
            continue
        var ally := visuals.get(raw_ally_id) as Node2D
        if ally == null or not is_instance_valid(ally):
            continue
        if _has_line_of_sight(actor_position, ally.global_position):
            return true
    return false

func _has_line_of_sight(from_position: Vector2, to_position: Vector2) -> bool:
    if from_position.distance_squared_to(to_position) <= 0.0001:
        return true
    var query := PhysicsRayQueryParameters2D.create(from_position, to_position, 1)
    query.collide_with_areas = false
    query.collide_with_bodies = true
    var hit := get_world_2d().direct_space_state.intersect_ray(query)
    return hit.is_empty() or hit.get("collider") == decision_target

func _is_observed_flank(enemy_position: Vector2) -> bool:
    if decision_target == null:
        return false
    var horizontal_delta := enemy_position.x - decision_target.global_position.x
    if absf(horizontal_delta) < 1.0:
        return false
    return signf(horizontal_delta) != float(decision_target.get_body_facing())

func _on_enemy_active_delivery_window_opened(context: Dictionary, encounter_id: StringName) -> void:
    if not _sessions.has(encounter_id):
        return
    if StringName(context.get("encounter_id", &"")) != encounter_id:
        return
    enemy_active_delivery_window_opened.emit(encounter_id, context.duplicate(true))

func _on_progress_committed(result: Dictionary, encounter_id: StringName) -> void:
    encounter_progressed.emit(encounter_id, result.duplicate(true))

func _on_encounter_enemy_defeated(actor_id: StringName, encounter_id: StringName) -> void:
    var blackboard := get_blackboard(encounter_id)
    if blackboard != null:
        blackboard.release_actor_roles(actor_id)

func _exit_tree() -> void:
    end_all_encounters()

func _node_name(value: String) -> String:
    return value.replace(":", "_").replace("/", "_").replace("-", "_").replace(".", "_")

func _rejected(reason_id: StringName, encounter_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "encounter_id": encounter_id,
        "resolved": false,
        "presentation_root": null,
        "active_enemy_count": 0,
        "runtime_reason_id": &"",
        "runtime_errors": PackedStringArray(),
        "presentation_reason_id": &"",
        "presentation_errors": PackedStringArray(),
    }
