extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TEST_SAVE_ROOT := "user://tests/gameplay_manual_save_flow"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service := SaveService.new(TEST_SAVE_ROOT)
    for slot_index: int in range(1, SaveService.SLOT_COUNT + 1):
        save_service.delete_slot(slot_index)

    await _test_region_pause_save_and_restore(save_service)
    await _test_tower_manual_save_and_restore(save_service)
    await _test_tower_escort_manual_save_and_restore(save_service)
    await _test_manual_save_restrictions(save_service)

    for slot_index: int in range(1, SaveService.SLOT_COUNT + 1):
        save_service.delete_slot(slot_index)
    if _failures == 0:
        print("GAMEPLAY MANUAL SAVE FLOW TEST PASS")
    else:
        push_error("GAMEPLAY MANUAL SAVE FLOW TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_region_pause_save_and_restore(save_service: SaveService) -> void:
    var profile := ProfileCreationService.create_profile(1, "Manual Region", "melee")
    _expect(profile != null and save_service.save_profile(1, profile) == OK, "Region manual-save fixture creates and persists")
    if profile == null:
        return
    var gameplay := await _spawn_gameplay(profile, save_service, 1)
    _expect(gameplay.ensure_starting_world() and gameplay.is_region3_active(), "Region manual-save fixture enters authored Region 3")
    var target_local := Vector2(64, 80) * 32.0
    gameplay.player.global_position = gameplay.region3_town_session_host.to_global(target_local)
    gameplay.player.velocity = Vector2.ZERO
    profile.xp = 77

    gameplay.pause_coordinator.request_pause(&"manual_pause")
    _expect(paused, "Pause Save is exercised from the real paused state")
    _expect(gameplay.manual_save_button != null and gameplay.manual_save_button.text == "Save Game", "Pause menu exposes the player-facing Save Game action")
    gameplay.manual_save_button.pressed.emit()
    _expect(StringName(String(gameplay.last_manual_save_result.get("state", &""))) == SaveRequestCoordinator.STATE_SUCCEEDED, "Pause Save commits the Region snapshot")
    _expect(gameplay.manual_save_status_label.text == "Game saved.", "Pause Save reports durable success in the pause menu")
    var saved_position := gameplay.player.global_position
    gameplay.pause_coordinator.resume()

    var durable := save_service.load_profile(1)
    _expect(
        durable != null
        and durable.xp == 77
        and String(durable.safe_state.get("snapshot_id", "")).begins_with("safe:manual_region3_")
        and StringName(String(durable.safe_state.get("checkpoint_anchor_id", &""))) == GameplayRoot.REGION3_TOWN_CHECKPOINT_ID,
        "Region manual save persists live progression while retaining the authored town death anchor"
    )
    if durable != null:
        var safe_player := durable.safe_state.get("player_state", {}) as Dictionary
        _expect(_state_position(safe_player).is_equal_approx(saved_position), "Region manual save persists the exact supported player location")

    gameplay.queue_free()
    await process_frame
    if durable != null:
        var restored := await _spawn_gameplay(durable, save_service, 1)
        _expect(restored.ensure_starting_world(), "Region manual save reload re-enters the saved world")
        _expect(restored.player.global_position.is_equal_approx(saved_position), "Region manual load restores the exact saved out-of-combat position")
        restored.queue_free()
        await process_frame


func _test_tower_manual_save_and_restore(save_service: SaveService) -> void:
    save_service.delete_slot(2)
    var profile := ProfileCreationService.create_profile(2, "Manual Tower", "ranged")
    if profile == null:
        _expect(false, "Tower manual-save fixture creates profile")
        return
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    _expect(save_service.save_profile(2, profile) == OK, "Tower manual-save fixture persists")
    var gameplay := await _spawn_gameplay(profile, save_service, 2)
    _expect(gameplay.ensure_starting_world(), "Tower manual-save fixture enters Region 3")
    var travel := gameplay.request_tower_travel(1, false)
    _expect(bool(travel.get("accepted", false)) and gameplay.is_tower_floor_active(), "Tower manual-save fixture enters Floor 1 through the production travel commit")
    if not gameplay.is_tower_floor_active():
        gameplay.queue_free()
        await process_frame
        return
    var floor := gameplay.call("_load_current_floor_state", 1) as FloorInstanceState
    var saved_position := gameplay.player.global_position
    var offset_candidate := saved_position + Vector2(4.0, 4.0)
    if floor != null and bool(gameplay.call("_tower_position_is_authored_traversable", floor, offset_candidate)):
        saved_position = offset_candidate
        gameplay.player.global_position = saved_position
    profile.xp = 55

    var status := gameplay.request_manual_save()
    _expect(StringName(String(status.get("state", &""))) == SaveRequestCoordinator.STATE_SUCCEEDED, "safe Tower manual save commits through the production boundary")
    var durable := save_service.load_profile(2)
    _expect(
        durable != null
        and durable.xp == 55
        and int(durable.safe_state.get("floor_id", 0)) == 1
        and String(durable.safe_state.get("snapshot_id", "")).begins_with("safe:manual_tower_floor_1_"),
        "Tower manual save persists current profile state and explicit manual snapshot identity"
    )
    if durable != null:
        _expect(_state_position(durable.safe_state.get("player_state", {}) as Dictionary).is_equal_approx(saved_position), "Tower manual save records the exact validated traversable position")

    gameplay.queue_free()
    await process_frame
    if durable != null:
        var restored := await _spawn_gameplay(durable, save_service, 2)
        _expect(restored.is_tower_floor_active() and restored.tower_floor_session_host.active_floor_id == 1, "Tower manual load restores the persisted Floor 1 instance")
        _expect(restored.player.global_position.is_equal_approx(saved_position), "Tower manual load restores the saved traversable player position instead of only the death anchor")
        restored.queue_free()
        await process_frame


func _test_tower_escort_manual_save_and_restore(save_service: SaveService) -> void:
    save_service.delete_slot(2)
    var profile := ProfileCreationService.create_profile(2, "Manual Escort", "melee")
    if profile == null:
        _expect(false, "production Escort manual-save fixture creates profile")
        return
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_2_unlocked"] = true
    profile.quest_progress["primary_floor_2"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:manual_escort_floor2",
        "attempt_history": ["attempt:manual_escort_floor2"],
        "objective_state": {},
    }
    _expect(save_service.save_profile(2, profile) == OK, "production Escort manual-save fixture persists")

    var gameplay := await _spawn_gameplay(profile, save_service, 2)
    _expect(gameplay.ensure_starting_world(), "production Escort manual-save fixture enters Region 3")
    var travel := gameplay.request_tower_travel(2, false)
    _expect(
        bool(travel.get("accepted", false))
        and gameplay.is_tower_floor_active()
        and bool(gameplay.last_tower_escort_activation_result.get("accepted", false))
        and bool(gameplay.last_tower_escort_activation_result.get("activated", false)),
        "entering active Floor 2 automatically starts the production Escort runtime: travel=%s escort=%s" % [str(travel), str(gameplay.last_tower_escort_activation_result)]
    )
    var runtime := gameplay.tower_floor_session_host.get_escort_runtime(&"primary_floor_2")
    _expect(runtime != null and runtime.current_hp == 100, "live Floor 2 owns the production Escort actor with full HP")
    if runtime == null:
        gameplay.queue_free()
        await process_frame
        return

    runtime.set_physics_process(false)
    _expect(bool(gameplay.tower_floor_session_host.set_escort_wait_requested(&"primary_floor_2", true).get("accepted", false)), "live production Escort persists an explicit Wait request")
    var damaged := runtime.apply_resolved_damage(30)
    _expect(bool(damaged.get("accepted", false)) and runtime.current_hp == 70, "live production Escort accepts resolved HP damage")
    var saved_actor_position := runtime.actor.position
    var save_status := gameplay.request_manual_save()
    _expect(StringName(String(save_status.get("state", &""))) == SaveRequestCoordinator.STATE_SUCCEEDED, "active production Escort permits manual save when exact actor state is serializable")

    var durable := save_service.load_profile(2)
    var durable_attempt := durable.safe_state.get("quest_attempt_state", {}) as Dictionary if durable != null else {}
    var durable_escort_states := durable_attempt.get("escort_runtime_states", {}) as Dictionary
    var durable_escort := durable_escort_states.get("primary_floor_2", {}) as Dictionary
    _expect(
        durable != null
        and int(durable.safe_state.get("floor_id", 0)) == 2
        and int(durable_escort.get("current_hp", 0)) == 70
        and bool(durable_escort.get("wait_requested", false)),
        "manual save persists production Escort HP, wait state, route state, and tower floor"
    )

    gameplay.queue_free()
    await process_frame
    if durable == null:
        return

    var restored := await _spawn_gameplay(durable, save_service, 2)
    _expect(
        restored.is_tower_floor_active()
        and bool(restored.tower_restore_status.get("accepted", false))
        and StringName(String((restored.tower_restore_status.get("escort_restore", {}) as Dictionary).get("reason_id", &""))) == &"",
        "loading the Escort snapshot restores the persistent Floor 2 session and Escort ownership: restore=%s objective=%s escort=%s" % [str(restored.tower_restore_status), str((durable.quest_progress["primary_floor_2"] as Dictionary).get("objective_state", {})), str(durable_escort)]
    )
    var restored_runtime := restored.tower_floor_session_host.get_escort_runtime(&"primary_floor_2")
    _expect(
        restored_runtime != null
        and restored_runtime.current_hp == 70
        and restored_runtime.actor.position.is_equal_approx(saved_actor_position),
        "production Escort restore recovers exact actor HP and position: restore=%s runtime=%s" % [str(restored.tower_restore_status), str(restored_runtime)]
    )
    if restored_runtime != null:
        var restored_objective := (durable.quest_progress["primary_floor_2"] as Dictionary).get("objective_state", {}) as Dictionary
        _expect(bool(restored_objective.get("wait_requested", false)), "production Escort restore retains the persisted Wait state")
    restored.queue_free()
    await process_frame


func _test_manual_save_restrictions(save_service: SaveService) -> void:
    save_service.delete_slot(3)
    var profile := ProfileCreationService.create_profile(3, "Manual Guards", "mage")
    _expect(profile != null and save_service.save_profile(3, profile) == OK, "manual-save restriction fixture persists")
    if profile == null:
        return
    var gameplay := await _spawn_gameplay(profile, save_service, 3)
    _expect(gameplay.ensure_starting_world(), "manual-save restriction fixture enters Region 3")
    var before := profile.safe_state.duplicate(true)

    gameplay.shared_active_combat.acquire(&"encounter:manual_save_guard", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER)
    gameplay.pause_coordinator.request_pause(&"manual_pause")
    gameplay.manual_save_button.pressed.emit()
    var combat_blocked := gameplay.last_manual_save_result
    _expect(
        StringName(String(combat_blocked.get("state", &""))) == SaveRequestCoordinator.STATE_FAILED
        and StringName(String(combat_blocked.get("reason_id", &""))) == GameplayOperationGuard.REASON_ACTIVE_COMBAT,
        "manual save rejects active combat with the shared guard reason"
    )
    _expect(
        gameplay.manual_save_status_label.text.contains("Save unavailable")
        and gameplay.manual_save_status_label.text.contains("active combat"),
        "Pause Save reports the active-combat restriction to the player"
    )
    gameplay.pause_coordinator.resume()
    gameplay.shared_active_combat.release_source(&"encounter:manual_save_guard")

    profile.quest_progress["side_region3_escort"] = {"state": QuestProgressState.STATE_ACTIVE}
    var escort_blocked := gameplay.request_manual_save()
    _expect(
        StringName(String(escort_blocked.get("state", &""))) == SaveRequestCoordinator.STATE_FAILED
        and StringName(String(escort_blocked.get("reason_id", &""))) == GameplayOperationGuard.REASON_UNSUPPORTED_TRANSIENT_STATE
        and String(escort_blocked.get("reason_text", "")).contains("Escort"),
        "manual save fails closed for an active Escort whose physical actor position is not serializable"
    )
    profile.quest_progress.erase("side_region3_escort")

    gameplay.call("_enter_death_retry_flow")
    var death_blocked := gameplay.request_manual_save()
    _expect(
        StringName(String(death_blocked.get("state", &""))) == SaveRequestCoordinator.STATE_FAILED
        and StringName(String(death_blocked.get("reason_id", &""))) == GameplayOperationGuard.REASON_UNSUPPORTED_TRANSIENT_STATE,
        "manual save rejects the death/retry transient state"
    )
    gameplay.call("_exit_death_retry_flow")
    _expect(profile.safe_state == before, "rejected combat/Escort/death manual saves do not advance the live safe snapshot")

    gameplay.queue_free()
    await process_frame


func _spawn_gameplay(profile: ProfileSnapshot, save_service: SaveService, slot_index: int) -> GameplayRoot:
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save_service, slot_index), "GameplayRoot accepts manual-save slot context")
    root.add_child(gameplay)
    await process_frame
    return gameplay


func _state_position(state: Dictionary) -> Vector2:
    return Vector2(float(state.get("position_x", INF)), float(state.get("position_y", INF)))


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
