extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TOWER_VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const TEST_SAVE_ROOT: String = "user://tests/gameplay_primary_floor_progression_flow"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service := SaveService.new(TEST_SAVE_ROOT)
    save_service.delete_slot(1)
    await _test_live_floor_turn_in(save_service, 1, 110091)
    save_service.delete_slot(1)
    await _test_live_floor_turn_in(save_service, 4, 440091)
    save_service.delete_slot(1)
    await _test_floor10_turn_in_after_authoritative_victory(save_service)
    save_service.delete_slot(1)
    if _failures == 0:
        print("GAMEPLAY PRIMARY FLOOR PROGRESSION FLOW TEST PASS")
    else:
        push_error("GAMEPLAY PRIMARY FLOOR PROGRESSION FLOW TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_live_floor_turn_in(save_service: SaveService, floor_id: int, seed: int) -> void:
    var profile := ProfileCreationService.create_profile(1, "Floor Progression %d" % floor_id, "melee")
    _expect(profile != null, "Floor %d live progression fixture creates a profile" % floor_id)
    if profile == null:
        return
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_%d_unlocked" % floor_id] = true
    if floor_id == 1:
        profile.permanent_flags[Region3PreparationCommitService.FLAG_REGION3_PREPARATION_COMMITTED] = true
    var quest_id := StringName("primary_floor_%d" % floor_id)
    profile.quest_progress[String(quest_id)] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": StringName("attempt:gameplay_floor_%d" % floor_id),
        "objective_state": {},
    }
    _expect(save_service.save_profile(1, profile) == OK, "Floor %d fixture persists its pre-gameplay profile" % floor_id)

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save_service, 1), "Floor %d fixture supplies save ownership" % floor_id)
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.ensure_starting_world(), "Floor %d fixture starts in the authored Region 3 town" % floor_id)

    var floor := _floor_state(floor_id, seed)
    _expect(floor != null and TowerFloorStateService.commit_floor_state(profile, floor), "Floor %d fixture commits its generated floor instance" % floor_id)
    if floor == null:
        gameplay.queue_free()
        await process_frame
        return
    var build := TowerFloorRuntimeComposer.build(floor.layout_manifest, TOWER_VISUAL_CATALOG)
    var arrival := TowerArrivalResolver.resolve_entrance(floor)
    _expect(bool(build.get("accepted", false)) and bool(arrival.get("accepted", false)), "Floor %d fixture builds a validated live floor runtime" % floor_id)
    _expect(
        gameplay.activate_committed_tower_travel({"accepted": true, "runtime_root": build.get("root"), "arrival": arrival}),
        "Floor %d fixture enters Tower while preserving the suspended Region 3 runtime" % floor_id
    )

    var plan := TowerPrototypeEncounterContentCatalog.build_plan(floor)
    var objective_bindings := floor.layout_manifest.get("objective_bindings", {}) as Dictionary
    var primary_room_id := StringName(String(objective_bindings.get(String(quest_id), objective_bindings.get(quest_id, &""))))
    var primary_encounter := _encounter_for_room(plan, primary_room_id)
    var primary_trigger := _encounter_trigger(gameplay.tower_floor_session_host.active_runtime_root, primary_room_id)
    _expect(primary_room_id != &"" and primary_encounter != &"" and primary_trigger != null, "Floor %d resolves the authored primary encounter room" % floor_id)
    if primary_trigger == null or primary_encounter == &"":
        gameplay.queue_free()
        await process_frame
        return
    primary_trigger.player_entered.emit(primary_room_id)
    await process_frame
    var activation := gameplay.last_tower_encounter_trigger_result
    _expect(bool(activation.get("accepted", false)), "Floor %d live room entry activates the authored primary encounter" % floor_id)
    var encounter := gameplay.tower_encounter_session_host.get_encounter_runtime(primary_encounter)
    _expect(encounter != null, "Floor %d primary encounter owns a live combat runtime" % floor_id)
    if encounter == null:
        gameplay.queue_free()
        await process_frame
        return
    var primary_placements := TowerEncounterPlanValidator.placements_for_encounter(plan, primary_encounter)
    _expect(not primary_placements.is_empty(), "Floor %d primary encounter has authored reusable residents" % floor_id)
    for index: int in range(primary_placements.size()):
        var actor_id := StringName(String(primary_placements[index].get("actor_id", &"")))
        var defeat := encounter.resolve_direct_contact(
            &"player:local",
            actor_id,
            900000 + floor_id * 100 + index,
            0,
            _fatal_attack(),
            false,
            DirectHitResolver.DEFENSE_NONE,
            false
        )
        _expect(bool(defeat.get("target_defeated", false)), "Floor %d required resident %s resolves through authoritative combat" % [floor_id, String(actor_id)])
    await process_frame
    var completed_entry := profile.quest_progress.get(String(quest_id), {}) as Dictionary
    _expect(
        StringName(String(completed_entry.get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE,
        "Floor %d live objective reaches ObjectivesComplete before any clear/unlock grant" % floor_id
    )
    _expect(
        not bool(profile.permanent_flags.get("tower_floor_%d_cleared" % floor_id, false)),
        "Floor %d objective completion alone does not fabricate durable floor clear" % floor_id
    )
    _expect(gameplay.end_tower_encounter(primary_encounter), "Floor %d primary combat session ends before entering the safe exit" % floor_id)

    var exit_room_id := StringName(String(floor.layout_manifest.get("exit_room_id", &"")))
    var exit_trigger := _discovery_trigger(gameplay.tower_floor_session_host.active_runtime_root, exit_room_id)
    _expect(exit_room_id != &"" and exit_trigger != null, "Floor %d exposes the authored safe exit room discovery boundary" % floor_id)
    if exit_trigger == null:
        gameplay.queue_free()
        await process_frame
        return
    exit_trigger.emit_signal(&"player_entered", exit_room_id)
    await process_frame
    var exit_result := gameplay.last_tower_primary_exit_result
    _expect(
        bool(exit_result.get("accepted", false))
        and bool(exit_result.get("durable", false))
        and int(exit_result.get("floor_id", 0)) == floor_id,
        "Floor %d exit commits the completed objective at an authored safe checkpoint boundary" % floor_id
    )
    _expect(not gameplay.is_tower_floor_active() and gameplay.is_region3_active(), "Floor %d exit returns to the same suspended Region 3 runtime" % floor_id)
    _expect(
        int((exit_result.get("safe_state", {}) as Dictionary).get("floor_id", 0)) == floor_id
        and StringName(String((exit_result.get("safe_state", {}) as Dictionary).get("checkpoint_anchor_id", &""))) == exit_room_id,
        "Floor %d floor-completion checkpoint uses the exact authored exit-room identity before hub return" % floor_id
    )
    _expect(
        StringName(String(gameplay.last_region3_hub_autosave_result.get("state", &""))) == SaveRequestCoordinator.STATE_SUCCEEDED
        and int(profile.safe_state.get("floor_id", -1)) == 0
        and String(profile.safe_state.get("snapshot_id", "")).begins_with("safe:autosave_region3_")
        and StringName(String(profile.safe_state.get("checkpoint_anchor_id", &""))) == GameplayRoot.REGION3_TOWN_CHECKPOINT_ID,
        "Floor %d return to the Region 3 hub commits the required hub-entry autosave after the floor checkpoint" % floor_id
    )
    var disk_at_exit := save_service.load_profile(1)
    _expect(
        disk_at_exit != null
        and int(disk_at_exit.safe_state.get("floor_id", -1)) == 0
        and String(disk_at_exit.safe_state.get("snapshot_id", "")).begins_with("safe:autosave_region3_")
        and StringName(String((disk_at_exit.quest_progress[String(quest_id)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE,
        "Floor %d ObjectivesComplete state and hub-entry autosave survive immediate durable reload" % floor_id
    )

    var quest_hall := gameplay.region3_town_session_host.active_runtime_root.get_node("QuestHall/ServiceInteraction") as Region3FunctionalServiceInteraction
    _expect(quest_hall != null, "Floor %d return path reaches the authored Quest Hall service" % floor_id)
    if quest_hall == null:
        gameplay.queue_free()
        await process_frame
        return
    quest_hall.call("_on_body_entered", gameplay.player)
    var service_request := quest_hall.request_service(StringName("interaction:test_floor_%d_turn_in" % floor_id))
    _expect(bool(service_request.get("admitted", false)), "Floor %d Quest Hall turn-in request passes shared service admission" % floor_id)
    var turn_in := gameplay.last_region3_primary_turn_in_result
    var next_floor_id := floor_id + 1
    _expect(bool(turn_in.get("attempted", false)) and bool(turn_in.get("accepted", false)), "Floor %d Quest Hall dispatches the authoritative primary turn-in service" % floor_id)
    var xp_result := turn_in.get("xp_award", {}) as Dictionary
    _expect(bool(xp_result.get("accepted", false)) and bool(xp_result.get("durable", false)) and profile.xp == floor_id * 80, "Floor %d Quest Hall pays the separate provisional XP claim exactly once after durable completion" % floor_id)
    _expect(
        StringName(String((profile.quest_progress[String(quest_id)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_COMPLETED
        and bool(profile.permanent_flags.get("tower_floor_%d_cleared" % floor_id, false))
        and bool((profile.tower_floor_states[str(floor_id)] as Dictionary).get("primary_cleared", false)),
        "Floor %d turn-in atomically records Completed quest and persistent floor clear" % floor_id
    )
    _expect(
        bool(profile.permanent_flags.get("tower_floor_%d_unlocked" % next_floor_id, false)),
        "Floor %d turn-in unlocks exactly Floor %d" % [floor_id, next_floor_id]
    )
    _expect(
        bool(turn_in.get("region3_safe_snapshot_committed", false))
        and int(profile.safe_state.get("floor_id", -1)) == 0
        and StringName(String(profile.safe_state.get("checkpoint_anchor_id", &""))) == GameplayRoot.REGION3_TOWN_CHECKPOINT_ID,
        "Floor %d successful Quest Hall turn-in advances to a legitimate Region 3 safe snapshot" % floor_id
    )

    var next_quest_id := StringName("primary_floor_%d" % next_floor_id)
    var raw_next: Variant = profile.quest_progress.get(String(next_quest_id), null)
    var next_state := StringName(String((raw_next as Dictionary).get("state", &""))) if raw_next is Dictionary else &""
    _expect(
        next_state == QuestProgressState.STATE_AVAILABLE
        and StringName(turn_in.get("next_primary_quest_id", &"")) == next_quest_id
        and bool(turn_in.get("next_primary_activation_policy_available", false))
        and StringName(turn_in.get("next_primary_activation_reason_id", &"")) == &"",
        "Floor %d turn-in exposes Floor %d as Available without auto-accepting it" % [floor_id, next_floor_id]
    )
    var next_production_status := turn_in.get("next_primary_production_status", {}) as Dictionary
    _expect(
        int(next_production_status.get("floor_id", 0)) == next_floor_id
        and StringName(next_production_status.get("quest_id", &"")) == next_quest_id
        and bool(next_production_status.get("production_ready", false))
        and not bool(next_production_status.get("playtest_placeholder", true))
        and (next_production_status.get("unauthored_contract_fields", PackedStringArray()) as PackedStringArray).is_empty(),
        "Floor %d turn-in exposes production-ready policy for Floor %d" % [floor_id, next_floor_id]
    )
    var disk_after_turn_in := save_service.load_profile(1)
    _expect(
        disk_after_turn_in != null
        and bool(disk_after_turn_in.permanent_flags.get("tower_floor_%d_cleared" % floor_id, false))
        and bool(disk_after_turn_in.permanent_flags.get("tower_floor_%d_unlocked" % next_floor_id, false))
        and StringName(String((disk_after_turn_in.quest_progress[String(next_quest_id)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_AVAILABLE
        and int(disk_after_turn_in.safe_state.get("floor_id", -1)) == 0,
        "Floor %d turn-in, Floor %d availability, and Region 3 safe state survive durable reload" % [floor_id, next_floor_id]
    )

    var accept_request := quest_hall.request_service(StringName("interaction:test_floor_%d_accept_next" % floor_id))
    _expect(bool(accept_request.get("admitted", false)), "Floor %d second Quest Hall interaction admits Floor %d acceptance" % [floor_id, next_floor_id])
    var accepted_next := gameplay.last_region3_primary_accept_result
    _expect(
        bool(accepted_next.get("attempted", false))
        and bool(accepted_next.get("accepted", false))
        and bool(accepted_next.get("durable", false))
        and int(accepted_next.get("floor_id", 0)) == next_floor_id
        and StringName(String((profile.quest_progress[String(next_quest_id)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_ACTIVE,
        "Floor %d next primary is explicitly accepted at Quest Hall and enters Active" % next_floor_id
    )
    var disk_after_accept := save_service.load_profile(1)
    _expect(
        disk_after_accept != null
        and StringName(String((disk_after_accept.quest_progress[String(next_quest_id)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_ACTIVE
        and int(disk_after_accept.safe_state.get("floor_id", -1)) == 0,
        "Floor %d Quest Hall acceptance survives durable reload" % next_floor_id
    )
    quest_hall.call("_on_body_exited", gameplay.player)

    gameplay.queue_free()
    await process_frame


func _test_floor10_turn_in_after_authoritative_victory(save_service: SaveService) -> void:
    var profile := ProfileCreationService.create_profile(1, "Floor 10 Turn In", "mage")
    _expect(profile != null, "Floor 10 turn-in fixture creates a profile")
    if profile == null:
        return
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_10_unlocked"] = true
    profile.quest_progress["primary_floor_10"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:gameplay_floor_10",
        "objective_state": {},
    }
    _expect(save_service.save_profile(1, profile) == OK, "Floor 10 turn-in fixture persists its pre-gameplay profile")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save_service, 1), "Floor 10 turn-in fixture supplies save ownership")
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.ensure_starting_world(), "Floor 10 turn-in fixture starts in Region 3")

    var floor := _floor_state(10, 1000091)
    _expect(floor != null and TowerFloorStateService.commit_floor_state(profile, floor), "Floor 10 turn-in fixture commits its generated floor")
    if floor == null:
        gameplay.queue_free()
        await process_frame
        return
    var build := TowerFloorRuntimeComposer.build(floor.layout_manifest, TOWER_VISUAL_CATALOG)
    var arrival := TowerArrivalResolver.resolve_entrance(floor)
    _expect(bool(build.get("accepted", false)) and bool(arrival.get("accepted", false)), "Floor 10 turn-in fixture builds the live floor")
    _expect(
        gameplay.activate_committed_tower_travel({"accepted": true, "runtime_root": build.get("root"), "arrival": arrival}),
        "Floor 10 turn-in fixture enters Tower while preserving Region 3"
    )

    var victory := Floor10PrimaryBossObjectiveService.record_terminal_outcome(
        profile,
        TenthWardenEncounterState.OUTCOME_VICTORY
    )
    _expect(
        bool(victory.get("accepted", false))
        and bool(victory.get("objectives_complete", false))
        and StringName(String((profile.quest_progress["primary_floor_10"] as Dictionary).get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE,
        "authoritative Floor 10 boss outcome can hand GameplayRoot an ObjectivesComplete primary state"
    )

    var exit_room_id := StringName(String(floor.layout_manifest.get("exit_room_id", &"")))
    var exit_trigger := _discovery_trigger(gameplay.tower_floor_session_host.active_runtime_root, exit_room_id)
    _expect(exit_trigger != null, "Floor 10 post-victory route exposes the authored safe exit room")
    if exit_trigger == null:
        gameplay.queue_free()
        await process_frame
        return
    exit_trigger.emit_signal(&"player_entered", exit_room_id)
    await process_frame
    _expect(
        bool(gameplay.last_tower_primary_exit_result.get("accepted", false))
        and not gameplay.is_tower_floor_active()
        and gameplay.is_region3_active(),
        "Floor 10 authoritative victory can bank the post-clear exit snapshot and return to Region 3"
    )
    _expect(
        StringName(String(gameplay.last_region3_hub_autosave_result.get("state", &""))) == SaveRequestCoordinator.STATE_SUCCEEDED
        and int(profile.safe_state.get("floor_id", -1)) == 0
        and String(profile.safe_state.get("snapshot_id", "")).begins_with("safe:autosave_region3_"),
        "Floor 10 return commits the required Region 3 hub-entry autosave before Quest Hall turn-in"
    )

    var premature_boss_xp := gameplay.request_cleared_tenth_warden_xp()
    _expect(not bool(premature_boss_xp.get("accepted", true)) and premature_boss_xp.get("reason_id", &"") == PlaytestQuestXpCommitService.REASON_BOSS_NOT_DURABLY_CLEARED, "verified victory alone cannot claim the boss XP before a durable Floor 10 Quest Hall turn-in")
    var quest_hall := gameplay.region3_town_session_host.active_runtime_root.get_node("QuestHall/ServiceInteraction") as Region3FunctionalServiceInteraction
    _expect(quest_hall != null, "Floor 10 post-clear return reaches Quest Hall")
    if quest_hall != null:
        quest_hall.call("_on_body_entered", gameplay.player)
        var request := quest_hall.request_service(&"interaction:test_floor_10_turn_in")
        _expect(bool(request.get("admitted", false)), "Floor 10 Quest Hall turn-in request passes service admission")
        var turn_in := gameplay.last_region3_primary_turn_in_result
        _expect(
            bool(turn_in.get("attempted", false))
            and bool(turn_in.get("accepted", false))
            and bool(profile.permanent_flags.get(Floor10PrimaryBossObjectiveService.FLAG_FLOOR_10_CLEARED, false)),
            "Quest Hall dispatches the authoritative Floor 10 turn-in after boss-owned victory"
        )
        var boss_xp := turn_in.get("boss_xp_award", {}) as Dictionary
        var primary_xp := turn_in.get("xp_award", {}) as Dictionary
        _expect(bool(primary_xp.get("accepted", false)) and bool(boss_xp.get("accepted", false)) and bool(boss_xp.get("durable", false)) and bool(boss_xp.get("boss_reward", false)), "Floor 10 Quest Hall grants independently claimed primary and boss playtest XP only after durable completion")
        _expect(profile.xp == 960, "Floor 10 primary 800 XP and independently claimed boss 160 XP accumulate without Level-11 progress")
        var before_duplicate_boss_xp := profile.to_dictionary()
        _expect(not bool(gameplay.request_cleared_tenth_warden_xp().get("accepted", true)) and profile.to_dictionary() == before_duplicate_boss_xp, "Tenth Warden boss XP cannot be claimed twice")
        _expect(
            not profile.permanent_flags.has("tower_floor_11_unlocked")
            and StringName(turn_in.get("next_primary_activation_reason_id", &"")) == &"prototype_milestone_complete",
            "Floor 10 completion ends the prototype milestone without fabricating Floor 11 or another primary quest"
        )
        _expect(
            int(profile.safe_state.get("floor_id", -1)) == 0
            and StringName(String(profile.safe_state.get("checkpoint_anchor_id", &""))) == GameplayRoot.REGION3_TOWN_CHECKPOINT_ID,
            "Floor 10 turn-in finishes on a legitimate durable Region 3 Quest Hall safe snapshot"
        )
        quest_hall.call("_on_body_exited", gameplay.player)

    var durable := save_service.load_profile(1)
    _expect(
        durable != null
        and bool(durable.permanent_flags.get(Floor10PrimaryBossObjectiveService.FLAG_FLOOR_10_CLEARED, false))
        and not durable.permanent_flags.has("tower_floor_11_unlocked")
        and int(durable.safe_state.get("floor_id", -1)) == 0
        and durable.xp == 960,
        "Floor 10 milestone, 960 XP and no-Floor-11 boundary survive durable reload"
    )
    gameplay.queue_free()
    await process_frame


func _floor_state(floor_id: int, seed: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        seed,
        &"tower_generator:v01",
        &"tower_modules:v01",
        &"encounters:v01",
        &"quest_flags:gameplay_progression_flow"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return null
    return TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:gameplay_progression_%02d_%d" % [floor_id, seed]),
        manifest
    )


func _encounter_for_room(plan: Dictionary, room_instance_id: StringName) -> StringName:
    for encounter_id: StringName in TowerPrototypeEncounterContentCatalog.encounter_ids(plan):
        for placement: Dictionary in TowerEncounterPlanValidator.placements_for_encounter(plan, encounter_id):
            if StringName(String(placement.get("room_instance_id", &""))) == room_instance_id:
                return encounter_id
    return &""


func _encounter_trigger(root_node: Node2D, room_instance_id: StringName) -> TowerEncounterRoomTrigger:
    if root_node == null:
        return null
    var rooms := root_node.get_node_or_null("Rooms")
    if rooms == null:
        return null
    for room_node: Node in rooms.get_children():
        if StringName(String(room_node.get_meta(&"room_instance_id", &""))) == room_instance_id:
            return room_node.get_node_or_null("EncounterTrigger") as TowerEncounterRoomTrigger
    return null


func _discovery_trigger(root_node: Node2D, room_instance_id: StringName) -> Area2D:
    if root_node == null:
        return null
    var rooms := root_node.get_node_or_null("Rooms")
    if rooms == null:
        return null
    for room_node: Node in rooms.get_children():
        if StringName(String(room_node.get_meta(&"room_instance_id", &""))) == room_instance_id:
            return room_node.get_node_or_null("DiscoveryTrigger") as Area2D
    return null


func _fatal_attack() -> Dictionary:
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


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
