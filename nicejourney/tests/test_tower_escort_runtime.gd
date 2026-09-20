extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const PRODUCTION_ESCORT_TUNING: TowerEscortRuntimeTuning = preload("res://src/data/tuning/tower_escort_runtime_production_v01.tres")
const PHYSICS_DELTA: float = 1.0 / 60.0

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _expect(PRODUCTION_ESCORT_TUNING.validate_production_tuning().is_empty(), "assigned production Escort resource includes required physical, HP and policy fields")
    _expect(PRODUCTION_ESCORT_TUNING.max_hp == 100 and PRODUCTION_ESCORT_TUNING.failure_policy_id == TowerEscortObjectiveAuthoring.FAILURE_POLICY_ACTOR_DEFEAT, "production Escort resource matches authored HP and actor-defeat failure policy")
    var fixture := _floor_fixture(2)
    _expect(bool(fixture.get("accepted", false)), "Floor 2 escort runtime fixture composes")
    if not bool(fixture.get("accepted", false)):
        quit(1)
        return

    var profile := ProfileCreationService.create_profile(1, "Tower Escort Runtime", "melee")
    profile.quest_progress["primary_floor_2"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": QuestCatalog.get_definition(&"primary_floor_2").stage_ids[-1],
        "attempt_id": &"attempt:escort_runtime_1",
        "attempt_history": ["attempt:escort_runtime_1"],
        "objective_state": {},
    }
    var floor := fixture["floor_state"] as FloorInstanceState
    var host := TowerFloorSessionHost.new()
    host.name = "TowerFloorSessionHost"
    root.add_child(host)
    var player := PLAYER_SCENE.instantiate() as PlayerController
    root.add_child(player)
    await process_frame
    _expect(host.activate(fixture["runtime_root"] as Node2D, fixture["arrival"] as Dictionary, player, player.camera), "Tower floor activates before escort runtime ownership")

    var objective_before := (profile.quest_progress["primary_floor_2"] as Dictionary).get("objective_state", {}) as Dictionary
    var missing := host.activate_escort(profile, floor, &"primary_floor_2")
    _expect(not bool(missing.get("accepted", true)) and StringName(missing.get("reason_id", &"")) == TowerEscortRuntime.REASON_TUNING_UNAVAILABLE, "production escort runtime fails closed while physical speed/tolerance/footprint are unauthored")
    _expect(host.get_escort_runtime(&"primary_floor_2") == null and (profile.quest_progress["primary_floor_2"] as Dictionary).get("objective_state", {}) == objective_before, "missing physical tuning cannot spawn an actor or mutate quest progress")

    var tuning := _authored_test_tuning()
    host.escort_tuning = tuning
    var activated := host.activate_escort(profile, floor, &"primary_floor_2", tuning)
    _expect(bool(activated.get("accepted", false)), "caller-authored physical tuning activates the Tower escort runtime")
    var runtime := host.get_escort_runtime(&"primary_floor_2")
    _expect(runtime != null and runtime.actor != null and runtime.actor.get_parent() == runtime, "Tower escort runtime owns a real CharacterBody2D actor on the active floor")
    if runtime == null or runtime.actor == null:
        await _finish(host, player)
        return
    runtime.set_physics_process(false)
    var collision := runtime.actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
    _expect(collision != null and collision.shape is RectangleShape2D and runtime.actor.collision_layer == 1 and runtime.actor.collision_mask == 1, "escort actor uses only caller-authored physical collision tuning")

    var objective := _objective(profile, &"primary_floor_2")
    _expect(objective != null and objective.next_route_index == 1, "spawn at the authored route origin commits the first reached waypoint through QuestFamilyObjectiveService")

    var wait_position := runtime.actor.global_position
    var wait := host.set_escort_wait_requested(&"primary_floor_2", true)
    _expect(bool(wait.get("accepted", false)) and _objective(profile, &"primary_floor_2").wait_requested, "wait interaction commits to the authoritative escort objective state")
    var waited := runtime.advance_fixed(PHYSICS_DELTA)
    _expect(bool(waited.get("accepted", false)) and StringName(waited.get("reason_id", &"")) == &"wait_requested" and runtime.actor.global_position.is_equal_approx(wait_position), "wait state physically stops the escort without changing route progress")
    _expect(bool(host.set_escort_wait_requested(&"primary_floor_2", false).get("accepted", false)), "follow interaction clears the persisted wait request")
    var damaged := runtime.apply_resolved_damage(25)
    _expect(bool(damaged.get("accepted", false)) and int(damaged.get("current_hp", 0)) == 75, "production Escort health accepts already-resolved HP damage without adding a second mitigation layer")

    var saved_actor_position := runtime.actor.position
    var saved_runtime_state := runtime.capture_safe_state()
    _expect(not saved_runtime_state.is_empty(), "active physical Escort exposes an exact serializable safe state")
    _expect(
        StringName(String(saved_runtime_state.get("quest_id", &""))) == &"primary_floor_2"
        and int(saved_runtime_state.get("next_route_index", -1)) == _objective(profile, &"primary_floor_2").next_route_index
        and int(saved_runtime_state.get("current_hp", 0)) == 75,
        "Escort safe state binds the authoritative quest identity, route progress, and production HP"
    )
    runtime.actor.position += Vector2(7.0, 5.0)
    var restored_runtime := runtime.configure(profile, floor, &"primary_floor_2", tuning, TowerFloorSessionHost.TILE_SIZE, saved_runtime_state)
    _expect(bool(restored_runtime.get("accepted", false)), "Escort runtime accepts its own validated coherent safe state")
    _expect(runtime.actor != null and runtime.actor.position.is_equal_approx(saved_actor_position), "Escort safe-state restore returns the actor to the exact saved physical position")
    _expect(runtime.current_hp == 75, "Escort safe-state restore returns the actor to the exact saved HP")
    runtime.set_physics_process(false)
    host.escort_tuning = tuning
    var host_capture := host.capture_escort_safe_states()
    _expect(bool(host_capture.get("accepted", false)) and (host_capture.get("states", {}) as Dictionary).has("primary_floor_2"), "Tower floor host captures all active Escort runtime states when authored tuning is restorable")

    var obstacle := _obstacle_between(runtime.actor.global_position, runtime.driver.next_world_position())
    host.active_runtime_root.add_child(obstacle)
    await physics_frame
    var collision_seen := false
    for _step: int in range(20):
        var step := runtime.advance_fixed(PHYSICS_DELTA)
        if bool(step.get("had_collision", false)):
            collision_seen = true
            _expect(StringName(step.get("reason_id", &"")) == &"physical_collision", "blocked escort exposes physical collision feedback")
            break
        await physics_frame
    _expect(collision_seen, "authored escort footprint collides with Tower physical geometry")
    _expect(_quest_state(profile, &"primary_floor_2") == QuestProgressState.STATE_ACTIVE and not _objective(profile, &"primary_floor_2").failed, "physical blockage remains non-terminal because no authored collision-failure policy exists")

    var wrong_actor := host.report_escort_actor_defeated(&"primary_floor_2", &"npc:wrong_escort")
    _expect(not bool(wrong_actor.get("accepted", true)) and StringName(wrong_actor.get("reason_id", &"")) == TowerEscortRuntime.REASON_ACTOR_MISMATCH, "failure ownership rejects a defeat event for any other actor identity")
    var actor_id := StringName(String((_objective(profile, &"primary_floor_2") as EscortObjectiveState).actor_id))
    var failed := host.report_escort_actor_defeated(&"primary_floor_2", actor_id)
    _expect(bool(failed.get("accepted", false)) and _quest_state(profile, &"primary_floor_2") == QuestProgressState.STATE_FAILED, "authored escort actor defeat commits the quest failure policy")
    _expect(_objective(profile, &"primary_floor_2").failure_reason_id == TowerEscortObjectiveAuthoring.FAILURE_POLICY_ACTOR_DEFEAT, "escort failure records the exact authored actor-defeat policy identity")

    obstacle.queue_free()
    await physics_frame
    var authored := TowerEscortObjectiveAuthoring.build(floor, &"primary_floor_2")
    var retry_tile := authored.get("safe_retry_world_tile", Vector2i.ZERO) as Vector2i
    var expected_retry_position := host.active_runtime_root.to_global((Vector2(retry_tile) + Vector2(0.5, 0.5)) * float(TowerFloorSessionHost.TILE_SIZE))
    var blocked_retry := host.retry_escort(&"primary_floor_2", &"attempt:escort_runtime_2", false)
    _expect(not bool(blocked_retry.get("accepted", true)) and _quest_state(profile, &"primary_floor_2") == QuestProgressState.STATE_FAILED, "retry requires explicit recovery-condition admission")
    var retried := host.retry_escort(&"primary_floor_2", &"attempt:escort_runtime_2", true)
    _expect(bool(retried.get("accepted", false)) and _quest_state(profile, &"primary_floor_2") == QuestProgressState.STATE_ACTIVE, "admitted retry creates a new active escort attempt through QuestActivationService: %s" % str(retried))
    _expect(runtime.actor.global_position.is_equal_approx(expected_retry_position), "retry resets the physical actor to the authored safe retry origin")
    _expect(runtime.current_hp == tuning.max_hp, "retry restores the production Escort actor HP for the new attempt")
    _expect(_objective(profile, &"primary_floor_2").next_route_index == 1, "retry rebinds objective state and commits only the route origin reached at the safe retry spawn")
    runtime.set_physics_process(false)

    var completed := false
    for _step: int in range(300):
        var step := runtime.advance_fixed(PHYSICS_DELTA)
        if bool(step.get("accepted", false)) and _quest_state(profile, &"primary_floor_2") == QuestProgressState.STATE_OBJECTIVES_COMPLETE:
            completed = true
            break
        await physics_frame
    _expect(completed and runtime.is_terminal(), "physical escort traversal commits ordered waypoints and the authored goal to ObjectivesComplete")
    _expect(runtime.actor.velocity.is_zero_approx(), "completed physical escort stops at the destination")

    await _finish(host, player)


func _floor_fixture(floor_id: int) -> Dictionary:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        91200 + floor_id,
        TowerGenerationIdentityFactory.GENERATOR_VERSION,
        TowerGenerationIdentityFactory.MODULE_CONTENT_VERSION,
        TowerGenerationIdentityFactory.ENCOUNTER_CONFIG_ID,
        &"quest_flags:tower_escort_runtime_test"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return {"accepted": false}
    var compose := TowerFloorRuntimeComposer.build(manifest, VISUAL_CATALOG)
    if not bool(compose.get("accepted", false)):
        return {"accepted": false}
    var floor := TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:tower_escort_runtime_f2", manifest)
    if floor == null:
        (compose["root"] as Node2D).free()
        return {"accepted": false}
    var arrival := TowerArrivalResolver.resolve_entrance(floor)
    if not bool(arrival.get("accepted", false)):
        (compose["root"] as Node2D).free()
        return {"accepted": false}
    return {"accepted": true, "runtime_root": compose["root"], "floor_state": floor, "arrival": arrival}


func _authored_test_tuning() -> TowerEscortRuntimeTuning:
    var tuning := TowerEscortRuntimeTuning.new()
    tuning.authored = true
    tuning.speed_px_per_second = 2048.0
    tuning.arrival_tolerance_px = 2.0
    var shape := RectangleShape2D.new()
    shape.size = Vector2(12.0, 10.0)
    tuning.collision_shape = shape
    tuning.collision_layer = 1
    tuning.collision_mask = 1
    tuning.max_hp = 100
    tuning.health_policy_id = &"health:escort_runtime_hp_v01"
    tuning.failure_policy_id = TowerEscortObjectiveAuthoring.FAILURE_POLICY_ACTOR_DEFEAT
    tuning.separation_policy_id = &"separation:nonterminal_route_owned_v01"
    tuning.repath_policy_id = &"repath:collision_retry_same_route_v01"
    tuning.save_policy_id = &"save:escort_exact_safe_state_v01"
    return tuning


func _obstacle_between(from: Vector2, to: Vector2) -> StaticBody2D:
    var obstacle := StaticBody2D.new()
    obstacle.name = "EscortBlocker"
    obstacle.global_position = from.lerp(to, 0.5)
    obstacle.collision_layer = 1
    obstacle.collision_mask = 1
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    var direction := to - from
    shape.size = Vector2(48.0, 12.0) if absf(direction.y) > absf(direction.x) else Vector2(12.0, 48.0)
    collision.shape = shape
    obstacle.add_child(collision)
    return obstacle


func _objective(profile: ProfileSnapshot, quest_id: StringName) -> EscortObjectiveState:
    var raw_entry: Variant = profile.quest_progress.get(String(quest_id), null)
    if not raw_entry is Dictionary:
        return null
    var raw_state: Variant = (raw_entry as Dictionary).get("objective_state", null)
    if not raw_state is Dictionary:
        return null
    var state := EscortObjectiveState.new()
    return state if state.load_dictionary(raw_state as Dictionary).is_empty() else null


func _quest_state(profile: ProfileSnapshot, quest_id: StringName) -> StringName:
    var raw := profile.quest_progress.get(String(quest_id), {}) as Dictionary
    return StringName(String(raw.get("state", &"")))


func _finish(host: TowerFloorSessionHost, player: PlayerController) -> void:
    if host != null:
        host.queue_free()
    if player != null:
        player.queue_free()
    await process_frame
    if _failures == 0:
        print("TOWER ESCORT RUNTIME TEST PASS")
    else:
        push_error("TOWER ESCORT RUNTIME TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
