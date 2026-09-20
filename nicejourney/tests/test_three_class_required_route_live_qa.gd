extends SceneTree

# Mechanical route gate, not a human-input combat or visual-fairness playtest.
# Each class uses the shipped GameplayRoot, actual Tower travel/exit scene,
# Quest Hall interaction, JSON save and separately claimed XP. Completion of
# each primary encounter is explicitly supplied by the fixture; dedicated
# encounter/escort/defense/boss tests own the corresponding combat evidence.
const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_ROOT: String = "user://tests/three_class_required_route_live_qa"

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save := SaveService.new(SAVE_ROOT)
    for class_id: String in ["melee", "ranged", "mage"]:
        save.delete_slot(1)
        await _verify_class_route(save, class_id)
    save.delete_slot(1)
    if _failures == 0:
        print("THREE CLASS REQUIRED ROUTE LIVE QA TEST PASS (fixture-authored objective outcomes)")
    else:
        push_error("THREE CLASS REQUIRED ROUTE LIVE QA TEST FAILURES: %d" % _failures)
    quit(_failures)


func _verify_class_route(save: SaveService, class_id: String) -> void:
    var profile := ProfileCreationService.create_profile(1, "Full Route " + class_id, class_id)
    if not _expect(profile != null, "%s: creates valid profile" % class_id):
        return
    if not _expect(save.save_profile(1, profile) == OK, "%s: initial profile is durable" % class_id):
        return

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    if not _expect(gameplay.set_save_context(save, 1), "%s: save context accepted" % class_id):
        gameplay.free()
        return
    root.add_child(gameplay)
    await process_frame
    if not _expect(gameplay.ensure_starting_world() and gameplay.is_region3_active(), "%s: live Region 3 starts" % class_id):
        gameplay.queue_free()
        await process_frame
        return

    var quest_hall := _quest_hall(gameplay)
    if not _expect(quest_hall != null, "%s: authored Quest Hall is present" % class_id):
        gameplay.queue_free()
        await process_frame
        return
    quest_hall.call("_on_body_entered", gameplay.player)
    var preparation := quest_hall.request_service(StringName("interaction:route:%s:prepare" % class_id))
    var prep_result := gameplay.last_region3_quest_hall_preparation_result
    var prepared := _expect(bool(preparation.get("admitted", false))
        and bool(prep_result.get("accepted", false))
        and Region3PreparationCommitService.has_tower_sigil(profile)
        and Region3PreparationCommitService.is_floor_1_unlocked(profile),
        "%s: Quest Hall grants Sigil and Floor 1 from live preparation" % class_id)
    quest_hall.call("_on_body_exited", gameplay.player)
    if not prepared:
        gameplay.queue_free()
        await process_frame
        return

    var expected_xp := 0
    for floor_id: int in range(1, 11):
        var label := "%s Floor %d" % [class_id, floor_id]
        var quest_id := StringName("primary_floor_%d" % floor_id)
        var raw_quest: Variant = profile.quest_progress.get(String(quest_id), null)
        if not _expect(raw_quest is Dictionary
            and StringName(String((raw_quest as Dictionary).get("state", &""))) == QuestProgressState.STATE_ACTIVE,
            "%s: current primary explicitly Active before travel" % label):
            break
        var travel := gameplay.request_tower_travel(floor_id, true)
        if not _expect(bool(travel.get("accepted", false))
            and gameplay.is_tower_floor_active()
            and gameplay.tower_floor_session_host.active_floor_id == floor_id,
            "%s: real floor travel/arrival accepted (%s)" % [label, String(travel.get("reason_id", &""))]):
            break
        var durable_travel := save.load_profile(1)
        if not _expect(durable_travel != null
            and int(durable_travel.safe_state.get("floor_id", 0)) == floor_id,
            "%s: floor-entry checkpoint persists" % label):
            break
        var raw_floor: Variant = profile.tower_floor_states.get(str(floor_id), null)
        var floor := FloorInstanceState.new()
        if not _expect(raw_floor is Dictionary
            and floor.load_dictionary(raw_floor as Dictionary).is_empty()
            and floor.floor_id == floor_id,
            "%s: generated floor state is valid" % label):
            break

        var exit_room_id := StringName(String(floor.layout_manifest.get("exit_room_id", &"")))
        var exit_trigger := _discovery_trigger(gameplay.tower_floor_session_host.active_runtime_root, exit_room_id)
        if not _expect(exit_trigger != null, "%s: physically authored safe exit exists" % label):
            break
        exit_trigger.emit_signal(&"player_entered", exit_room_id)
        if not _expect(not bool(gameplay.last_tower_primary_exit_result.get("accepted", true))
            and gameplay.is_tower_floor_active(),
            "%s: exit cannot bank an unfinished primary" % label):
            break

        # Floor 1 is an actual resident defeat through the live encounter,
        # not a fabricated objectives-complete state. The other primary
        # objective families are fixture-completed here and covered by their
        # dedicated escort/defense/annihilation tests.
        if floor_id == 1:
            if not await _defeat_live_floor1_primary(gameplay, floor, label):
                break
        elif floor_id == 10:
            var victory := Floor10PrimaryBossObjectiveService.record_terminal_outcome(
                profile, TenthWardenEncounterState.OUTCOME_VICTORY)
            if not _expect(bool(victory.get("accepted", false))
                and bool(victory.get("objectives_complete", false)),
                "%s: authoritative boss-result boundary records fixture victory" % label):
                break
        else:
            var quest := (profile.quest_progress[String(quest_id)] as Dictionary).duplicate(true)
            quest["state"] = QuestProgressState.STATE_OBJECTIVES_COMPLETE
            quest["stage_id"] = &"floor_objective"
            profile.quest_progress[String(quest_id)] = quest

        exit_trigger.emit_signal(&"player_entered", exit_room_id)
        await process_frame
        var exit_result := gameplay.last_tower_primary_exit_result
        if not _expect(bool(exit_result.get("accepted", false))
            and bool(exit_result.get("durable", false))
            and gameplay.is_region3_active()
            and not gameplay.is_tower_floor_active(),
            "%s: authored exit banks primary state and returns to Region 3 (%s)"
                % [label, String(exit_result.get("reason_id", &""))]):
            break
        quest_hall = _quest_hall(gameplay)
        if not _expect(quest_hall != null, "%s: Quest Hall exists after region return" % label):
            break
        quest_hall.call("_on_body_entered", gameplay.player)
        var turn_request := quest_hall.request_service(
            StringName("interaction:route:%s:floor_%d:turn_in" % [class_id, floor_id]))
        var turn_in := gameplay.last_region3_primary_turn_in_result
        expected_xp += 80 * floor_id
        if floor_id == 10:
            expected_xp += 160
        expected_xp = mini(expected_xp, 4500)
        if not _expect(bool(turn_request.get("admitted", false))
            and bool(turn_in.get("accepted", false))
            and bool((turn_in.get("xp_award", {}) as Dictionary).get("durable", false))
            and (floor_id != 10 or bool((turn_in.get("boss_xp_award", {}) as Dictionary).get("durable", false))),
            "%s: Quest Hall commits actual separate finite rewards (%s)"
                % [label, String(turn_in.get("reason_id", &""))]):
            break
        if not _expect(profile.xp == expected_xp
            and profile.level <= 10
            and not profile.permanent_flags.has("tower_floor_11_unlocked"),
            "%s: finite cumulative XP, Level 10 cap and no Floor 11" % label):
            break
        var disk := save.load_profile(1)
        if not _expect(disk != null
            and disk.xp == profile.xp
            and disk.level == profile.level
            and int(disk.safe_state.get("floor_id", -1)) == 0,
            "%s: Quest Hall XP/level and Region safe checkpoint survive disk round trip" % label):
            break
        var before_duplicate := profile.to_dictionary()
        var duplicate := gameplay.request_completed_quest_xp(quest_id)
        if not _expect(not bool(duplicate.get("accepted", true))
            and profile.to_dictionary() == before_duplicate,
            "%s: repeated primary XP claim leaves profile unchanged" % label):
            break
        if floor_id < 10:
            var accepted_request := quest_hall.request_service(
                StringName("interaction:route:%s:floor_%d:accept_next" % [class_id, floor_id]))
            var accepted := gameplay.last_region3_primary_accept_result
            if not _expect(bool(accepted_request.get("admitted", false))
                and bool(accepted.get("durable", false))
                and StringName(String((profile.quest_progress["primary_floor_%d" % (floor_id + 1)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_ACTIVE,
                "%s: next primary explicitly accepted and durable" % label):
                break
        quest_hall.call("_on_body_exited", gameplay.player)

    _expect(profile.level == 10 and profile.xp == 4500 and profile.skill_points == 9
        and bool(profile.permanent_flags.get(Floor10PrimaryBossObjectiveService.FLAG_FLOOR_10_CLEARED, false))
        and not profile.permanent_flags.has("tower_floor_11_unlocked"),
        "%s: all ten floors reach finite Level 10 milestone without farming" % class_id)
    gameplay.queue_free()
    await process_frame


func _defeat_live_floor1_primary(gameplay: GameplayRoot, floor: FloorInstanceState, label: String) -> bool:
    var plan := TowerPrototypeEncounterContentCatalog.build_plan(floor)
    var bindings := floor.layout_manifest.get("objective_bindings", {}) as Dictionary
    var primary_room := StringName(String(bindings.get("primary_floor_1", &"")))
    var encounter_id: StringName = &""
    for candidate: StringName in TowerPrototypeEncounterContentCatalog.encounter_ids(plan):
        for placement: Dictionary in TowerEncounterPlanValidator.placements_for_encounter(plan, candidate):
            if StringName(String(placement.get("room_instance_id", &""))) == primary_room:
                encounter_id = candidate
                break
        if encounter_id != &"":
            break
    var trigger := _encounter_trigger(gameplay.tower_floor_session_host.active_runtime_root, primary_room)
    if not _expect(primary_room != &"" and encounter_id != &"" and trigger != null,
        "%s: generated Floor 1 has real primary encounter/room trigger" % label):
        return false
    trigger.player_entered.emit(primary_room)
    await process_frame
    var activated := gameplay.last_tower_encounter_trigger_result
    var encounter := gameplay.tower_encounter_session_host.get_encounter_runtime(encounter_id)
    if not _expect(bool(activated.get("accepted", false)) and encounter != null,
        "%s: physical primary-room signal activates authoritative combat" % label):
        return false
    var residents := TowerEncounterPlanValidator.placements_for_encounter(plan, encounter_id)
    if not _expect(not residents.is_empty(), "%s: primary encounter owns real enemies" % label):
        return false
    for index: int in range(residents.size()):
        var actor := StringName(String(residents[index].get("actor_id", &"")))
        var attack := {
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
        var hit := encounter.resolve_direct_contact(
            &"player:local", actor, 880000 + index, 0, attack,
            false, DirectHitResolver.DEFENSE_NONE, false)
        if not _expect(bool(hit.get("target_defeated", false)),
            "%s: real resident %s defeated through combat contact" % [label, String(actor)]):
            return false
    await process_frame
    var primary := gameplay._profile.quest_progress.get("primary_floor_1", {}) as Dictionary
    if not _expect(StringName(String(primary.get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE,
        "%s: live defeated resident set completes Floor 1 objective" % label):
        return false
    return _expect(gameplay.end_tower_encounter(encounter_id),
        "%s: authoritative combat releases floor-exit guard" % label)


func _encounter_trigger(runtime_root: Node2D, room_id: StringName) -> TowerEncounterRoomTrigger:
    if runtime_root == null:
        return null
    var rooms := runtime_root.get_node_or_null("Rooms")
    if rooms == null:
        return null
    for room_node: Node in rooms.get_children():
        if StringName(String(room_node.get_meta(&"room_instance_id", &""))) == room_id:
            return room_node.get_node_or_null("EncounterTrigger") as TowerEncounterRoomTrigger
    return null


func _quest_hall(gameplay: GameplayRoot) -> Region3FunctionalServiceInteraction:
    if not gameplay.is_region3_active():
        return null
    return gameplay.region3_town_session_host.active_runtime_root.get_node_or_null(
        "QuestHall/ServiceInteraction") as Region3FunctionalServiceInteraction


func _discovery_trigger(runtime_root: Node2D, room_id: StringName) -> Area2D:
    if runtime_root == null:
        return null
    var rooms := runtime_root.get_node_or_null("Rooms")
    if rooms == null:
        return null
    for room_node: Node in rooms.get_children():
        if StringName(String(room_node.get_meta(&"room_instance_id", &""))) == room_id:
            return room_node.get_node_or_null("DiscoveryTrigger") as Area2D
    return null


func _expect(ok: bool, description: String) -> bool:
    if ok:
        print("PASS: %s" % description)
        return true
    _failures += 1
    push_error("FAIL: %s" % description)
    return false
