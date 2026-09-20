extends SceneTree

# Three-class DR-02 route regression. Real floor residents, damage/defeat,
# death overlay, safe-snapshot retry and Quest Hall payout; contact damage
# magnitude and room-trigger emission are controlled test inputs.
const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_ROOT := "user://tests/three_class_live_death_retry"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save := SaveService.new("%s/%d" % [SAVE_ROOT, OS.get_process_id()])
    for class_id: String in ["melee", "ranged", "mage"]:
        save.delete_slot(1)
        await _verify_class_retry(save, class_id)
    save.delete_slot(1)
    if _failures == 0:
        print("THREE CLASS LIVE DEATH RETRY TEST PASS (controlled damage)")
    else:
        push_error("THREE CLASS LIVE DEATH RETRY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _verify_class_retry(save: SaveService, class_id: String) -> void:
    var profile := ProfileCreationService.create_profile(1, "Retry " + class_id, class_id)
    if not _expect(profile != null and save.save_profile(1, profile) == OK,
        "%s: clean profile saved" % class_id):
        return
    var game := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    game.set_profile(profile)
    if not _expect(game.set_save_context(save, 1), "%s: save context bound" % class_id):
        game.free()
        return
    root.add_child(game)
    await process_frame
    if not _expect(game.ensure_starting_world(), "%s: Region 3 world starts" % class_id):
        await _dispose(game)
        return
    var quest_hall := game.region3_town_session_host.active_runtime_root.get_node_or_null(
        "QuestHall/ServiceInteraction") as Region3FunctionalServiceInteraction
    if not _expect(quest_hall != null, "%s: physical Quest Hall exists" % class_id):
        await _dispose(game)
        return
    quest_hall.call("_on_body_entered", game.player)
    var prepared := quest_hall.request_service(StringName("interaction:retry:%s:prepare" % class_id))
    quest_hall.call("_on_body_exited", game.player)
    if not _expect(bool(prepared.get("admitted", false))
        and bool(game.last_region3_quest_hall_preparation_result.get("accepted", false)),
        "%s: Quest Hall preparation succeeds" % class_id):
        await _dispose(game)
        return
    var travel := game.request_tower_travel(1, true)
    if not _expect(bool(travel.get("accepted", false)) and game.is_tower_floor_active(),
        "%s: Floor 1 entry commits safe checkpoint" % class_id):
        await _dispose(game)
        return
    var checkpoint := save.load_profile(1)
    var raw_floor := profile.tower_floor_states.get("1", {}) as Dictionary
    var floor := FloorInstanceState.new()
    if not _expect(checkpoint != null and floor.load_dictionary(raw_floor).is_empty(),
        "%s: checkpoint and generated Floor 1 are valid" % class_id):
        await _dispose(game)
        return
    var plan := TowerPrototypeEncounterContentCatalog.build_plan(floor)
    var primary_room := StringName(String((floor.layout_manifest.get("objective_bindings", {}) as Dictionary).get(
        "primary_floor_1", &"")))
    var encounter_id: StringName = &""
    for candidate: StringName in TowerPrototypeEncounterContentCatalog.encounter_ids(plan):
        var placements := TowerEncounterPlanValidator.placements_for_encounter(plan, candidate)
        if not placements.is_empty() and StringName(String(placements[0].get("room_instance_id", &""))) == primary_room:
            encounter_id = candidate
            break
    var trigger := _encounter_trigger(game, primary_room)
    if not _expect(encounter_id != &"" and trigger != null,
        "%s: Floor 1 has a real primary combat room" % class_id):
        await _dispose(game)
        return
    trigger.player_entered.emit(primary_room)
    await process_frame
    var encounter := game.tower_encounter_session_host.get_encounter_runtime(encounter_id)
    var residents := TowerEncounterPlanValidator.placements_for_encounter(plan, encounter_id)
    if not _expect(encounter != null and residents.size() >= 2,
        "%s: live primary encounter activates with multiple residents" % class_id):
        await _dispose(game)
        return
    var first_id := StringName(String(residents[0].get("actor_id", &"")))
    var second_id := StringName(String(residents[1].get("actor_id", &"")))
    var first_hit := encounter.resolve_direct_contact(
        &"player:local", first_id, 810001, 0, _fatal_hit(),
        false, DirectHitResolver.DEFENSE_NONE, false)
    if not _expect(bool(first_hit.get("target_defeated", false)),
        "%s: one real resident dies during the unsaved attempt" % class_id):
        await _dispose(game)
        return
    var after_kill := profile.tower_floor_states.get("1", {}) as Dictionary
    var disk_before_retry := save.load_profile(1)
    if not _expect((after_kill.get("defeated_actor_ids", []) as Array).has(String(first_id))
        and disk_before_retry != null
        and not ((disk_before_retry.tower_floor_states.get("1", {}) as Dictionary).get(
            "defeated_actor_ids", []) as Array).has(String(first_id))
        and not game.operation_guard.is_allowed(GameplayOperationGuard.OP_MANUAL_SAVE),
        "%s: combat defeat is unbanked and manual saving is blocked" % class_id):
        await _dispose(game)
        return
    var fatal := encounter.resolve_direct_contact(
        second_id, &"player:local", 810002, 0, _fatal_hit(),
        false, DirectHitResolver.DEFENSE_NONE, false)
    await process_frame
    if not _expect(bool(fatal.get("target_defeated", false)) and game.is_death_retry_open(),
        "%s: live enemy contact opens death/retry" % class_id):
        await _dispose(game)
        return
    game.death_retry_overlay.retry_requested.emit()
    await process_frame
    var restored := game._profile as ProfileSnapshot
    var restored_floor := restored.tower_floor_states.get("1", {}) as Dictionary if restored != null else {}
    if not _expect(restored != null and game.is_tower_floor_active()
        and not game.is_death_retry_open()
        and not (restored_floor.get("defeated_actor_ids", []) as Array).has(String(first_id))
        and restored.xp == checkpoint.xp
        and restored.level == checkpoint.level
        and restored_floor.get("instance_id", &"") == raw_floor.get("instance_id", &"")
        and restored_floor.get("seed", -1) == raw_floor.get("seed", -2)
        and not game.shared_active_combat.is_active(),
        "%s: retry reconstructs the same floor with unsaved defeat/XP rolled back" % class_id):
        await _dispose(game)
        return
    var retry_trigger := _encounter_trigger(game, primary_room)
    if not _expect(retry_trigger != null, "%s: restored room trigger exists" % class_id):
        await _dispose(game)
        return
    retry_trigger.player_entered.emit(primary_room)
    await process_frame
    var retried_encounter := game.tower_encounter_session_host.get_encounter_runtime(encounter_id)
    if not _expect(retried_encounter != null
        and retried_encounter.get_combatant(first_id) != null
        and not retried_encounter.get_combatant(first_id).is_defeated(),
        "%s: rolled-back enemy respawns in the legitimate retry encounter" % class_id):
        await _dispose(game)
        return
    for index: int in range(residents.size()):
        var actor_id := StringName(String(residents[index].get("actor_id", &"")))
        var hit := retried_encounter.resolve_direct_contact(
            &"player:local", actor_id, 820000 + index, 0, _fatal_hit(),
            false, DirectHitResolver.DEFENSE_NONE, false)
        if not _expect(bool(hit.get("target_defeated", false)),
            "%s: retried resident %s is defeated through live combat" % [class_id, String(actor_id)]):
            await _dispose(game)
            return
    await process_frame
    var objective := restored.quest_progress.get("primary_floor_1", {}) as Dictionary
    if not _expect(StringName(String(objective.get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE
        and game.end_tower_encounter(encounter_id),
        "%s: retried live objective completes and releases combat" % class_id):
        await _dispose(game)
        return
    var exit_id := StringName(String(floor.layout_manifest.get("exit_room_id", &"")))
    var exit_trigger := _discovery_trigger(game, exit_id)
    if not _expect(exit_trigger != null, "%s: restored floor exit exists" % class_id):
        await _dispose(game)
        return
    exit_trigger.emit_signal(&"player_entered", exit_id)
    await process_frame
    if not _expect(bool(game.last_tower_primary_exit_result.get("durable", false))
        and game.is_region3_active(), "%s: completed retry exits durably" % class_id):
        await _dispose(game)
        return
    quest_hall = game.region3_town_session_host.active_runtime_root.get_node_or_null(
        "QuestHall/ServiceInteraction") as Region3FunctionalServiceInteraction
    if not _expect(quest_hall != null, "%s: Quest Hall returns" % class_id):
        await _dispose(game)
        return
    quest_hall.call("_on_body_entered", game.player)
    var turn := quest_hall.request_service(StringName("interaction:retry:%s:turnin" % class_id))
    var disk := save.load_profile(1)
    _expect(bool(turn.get("admitted", false))
        and bool(game.last_region3_primary_turn_in_result.get("accepted", false))
        and disk != null and disk.xp == 80
        and not bool(game.request_completed_quest_xp(&"primary_floor_1").get("accepted", true)),
        "%s: retry turn-in grants one durable primary reward" % class_id)
    quest_hall.call("_on_body_exited", game.player)
    await _dispose(game)


func _encounter_trigger(game: GameplayRoot, room_id: StringName) -> TowerEncounterRoomTrigger:
    var rooms := game.tower_floor_session_host.active_runtime_root.get_node_or_null("Rooms")
    if rooms == null:
        return null
    for room: Node in rooms.get_children():
        if StringName(String(room.get_meta(&"room_instance_id", &""))) == room_id:
            return room.get_node_or_null("EncounterTrigger") as TowerEncounterRoomTrigger
    return null


func _discovery_trigger(game: GameplayRoot, room_id: StringName) -> Area2D:
    var rooms := game.tower_floor_session_host.active_runtime_root.get_node_or_null("Rooms")
    if rooms == null:
        return null
    for room: Node in rooms.get_children():
        if StringName(String(room.get_meta(&"room_instance_id", &""))) == room_id:
            return room.get_node_or_null("DiscoveryTrigger") as Area2D
    return null


func _fatal_hit() -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": 10000.0,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 0.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }


func _dispose(game: GameplayRoot) -> void:
    game.queue_free()
    await process_frame


func _expect(ok: bool, message: String) -> bool:
    if ok:
        print("PASS: %s" % message)
        return true
    _failures += 1
    push_error("FAIL: %s" % message)
    return false
