extends SceneTree

const LAYOUT: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const MARKERS: PackedScene = preload("res://src/world/region3/quests/region3_side_quest_authored_markers.tscn")
const LIVE_HOST: PackedScene = preload("res://src/world/region3/quests/region3_side_quest_runtime.tscn")
const QUESTS: Region3SideQuestsPlaytest = preload("res://src/data/tuning/region3_side_quests_playtest_v01.tres")
const PROGRESSION: ProgressionPlaytestContent = preload("res://src/data/tuning/progression_playtest_v01.tres")
const SAVE_PATH := "user://tests/region3_live_side_quest_attempts"
var _failures := 0

class RejectingSave:
    extends SaveService
    func save_profile(_slot_index: int, _profile: ProfileSnapshot) -> int:
        return ERR_CANT_CREATE

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var layout := LAYOUT.instantiate() as Region3AuthoredTownLayout
    root.add_child(layout)
    var markers := MARKERS.instantiate() as Region3SideQuestPlaytestAnchorLayer
    layout.add_child(markers)
    await process_frame
    _expect(QUESTS.validate_content(PROGRESSION).is_empty(), "shipped three-slot side quest plans remain valid provisional authoring")
    _expect(not _plan_with_override(0, "enemy_counts_by_wave", PackedInt32Array([1, 2])).validate_content(PROGRESSION).is_empty(), "escort cannot author a second wave that its runtime cannot advance")
    _expect(not _plan_with_override(1, "enemy_counts_by_wave", PackedInt32Array([2, 3])).validate_content(PROGRESSION).is_empty(), "annihilation cannot silently author an unsupported second wave")
    _expect(not _plan_with_override(0, "leave_policy_id", &"").validate_content(PROGRESSION).is_empty(), "escort requires a declared stable leave rule")
    _expect(not _plan_with_override(2, "retry_policy_id", &"bad policy").validate_content(PROGRESSION).is_empty(), "defense requires a stable retry rule")
    _expect(not _plan_with_override(1, "staging_route_name", &"SouthApproach").validate_content(PROGRESSION).is_empty(), "west objective cannot be misbound to the south approach")
    _expect(not _plan_with_override(2, "xp_reward", "80").validate_content(PROGRESSION).is_empty(), "numeric-looking text cannot pass the finite XP source check")
    var unmatched_plan := _plan_with_override(1, "enemy_counts_by_wave", PackedInt32Array([4]))
    _expect(unmatched_plan.validate_content(PROGRESSION).is_empty(), "single-wave enemy counts remain inspector-tunable")
    _expect(not bool(Region3SideQuestAttemptService.build_authored_descriptors(layout, markers, unmatched_plan, PROGRESSION).get("accepted", false)), "wave total must match actual Inspector-authored hostile placements")
    var original_west_paths := markers.west_hostile_spawn_paths.duplicate()
    var original_west_archetypes := markers.west_enemy_archetype_ids.duplicate()
    markers.west_hostile_spawn_paths.remove_at(4)
    markers.west_enemy_archetype_ids.remove_at(4)
    var matched_plan := Region3SideQuestAttemptService.build_authored_descriptors(layout, markers, unmatched_plan, PROGRESSION)
    var matched_west := (matched_plan.get("descriptors", {}) as Dictionary).get(Region3SideQuestAttemptService.QUEST_ANNIHILATION, {}) as Dictionary
    _expect(bool(matched_plan.get("accepted", false)) and (matched_west.get("enemy_placements", []) as Array).size() == 4, "matching revised Inspector wave count and four real west markers can bind without a hardcoded five-enemy gate")
    markers.west_hostile_spawn_paths = original_west_paths
    markers.west_enemy_archetype_ids = original_west_archetypes
    var authored := Region3SideQuestAttemptService.build_authored_descriptors(layout, markers, QUESTS, PROGRESSION)
    _expect(bool(authored.get("accepted", false)), "all three authored side quest sites validate")
    var descriptors := authored.get("descriptors", {}) as Dictionary
    _expect(descriptors.size() == 3, "three regional side slots have separate bindings")
    if descriptors.size() != 3:
        quit(_failures + 1)
        return
    var escort := descriptors[Region3SideQuestAttemptService.QUEST_ESCORT] as Dictionary
    var west := descriptors[Region3SideQuestAttemptService.QUEST_ANNIHILATION] as Dictionary
    var defense := descriptors[Region3SideQuestAttemptService.QUEST_DEFENSE] as Dictionary
    _expect((escort["enemy_placements"] as Array).size() == 3 and (west["enemy_placements"] as Array).size() == 5 and (defense["enemy_placements"] as Array).size() == 6, "enemy placement counts follow Inspector-backed playtest content")
    _expect((defense["wave_ids"] as Array).size() == 3, "defense wave membership is partitioned into exactly three waves")
    _expect(escort["escort_goal_world_position"] != escort["escort_start_world_position"], "escort goal and actor start are distinct authored markers")
    _expect(west["return_landmark_world_position"].is_finite(), "annihilation return landmark is physically authored")
    var save := SaveService.new(SAVE_PATH)
    save.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Regional Side Test", "melee")
    _expect(save.save_profile(1, profile) == OK, "starting profile is durable")
    for descriptor: Dictionary in [escort, west, defense]:
        var quest_id := descriptor["quest_id"] as StringName
        var first := Region3SideQuestAttemptService.commit_accept(save, 1, profile, descriptor, StringName("attempt:%s:one" % String(quest_id)))
        _expect(bool(first.get("accepted", false)) and bool(first.get("durable", false)), "%s accepts and binds a durable first attempt" % String(quest_id))
        var persisted := save.load_profile(1)
        var persisted_entry := persisted.quest_progress.get(String(quest_id), {}) as Dictionary if persisted != null else {}
        _expect(persisted != null and StringName(String(persisted_entry.get("state", &""))) == QuestProgressState.STATE_ACTIVE and not (persisted_entry.get("objective_state", {}) as Dictionary).is_empty(), "saved objective bindings mirror live quest state")
        var partial_event: StringName = &""
        var partial_payload: Dictionary = {}
        match quest_id:
            Region3SideQuestAttemptService.QUEST_ESCORT:
                partial_event = QuestFamilyObjectiveService.EVENT_ROUTE_NODE_REACHED
                partial_payload = {"route_node_id": (descriptor["objective_config"] as Dictionary)["route_node_ids"][0]}
            Region3SideQuestAttemptService.QUEST_ANNIHILATION:
                partial_event = QuestFamilyObjectiveService.EVENT_ACTOR_DEFEATED
                partial_payload = {"actor_id": (descriptor["enemy_placements"] as Array)[0]["actor_id"]}
            Region3SideQuestAttemptService.QUEST_DEFENSE:
                partial_event = QuestFamilyObjectiveService.EVENT_OBJECTIVE_DAMAGE
                partial_payload = {"amount": 10}
        var partial := Region3SideQuestAttemptService.commit_event(save, 1, profile, quest_id,
            StringName("attempt:%s:one" % String(quest_id)), partial_event, partial_payload)
        _expect(bool(partial.get("accepted", false)) and bool(partial.get("durable", false)), "each quest records real attempt-local progress before departure")
        var before_preview: Dictionary = (profile.quest_progress[String(quest_id)] as Dictionary).duplicate(true)
        var failure := Region3SideQuestAttemptService.commit_leave(save, 1, profile, descriptor, false)
        _expect(bool(failure.get("accepted", false)) and bool(failure.get("confirmation_required", false)), "leaving requires explicit confirmation")
        _expect(profile.quest_progress[String(quest_id)] == before_preview, "leave preview cannot alter current objective progress")
        var leave := Region3SideQuestAttemptService.commit_leave(save, 1, profile, descriptor, true)
        _expect(bool(leave.get("accepted", false)) and bool(leave.get("durable", false)), "confirmed leave durably abandons only the active attempt")
        var retry := Region3SideQuestAttemptService.commit_accept(save, 1, profile, descriptor, StringName("attempt:%s:two" % String(quest_id)))
        _expect(bool(retry.get("accepted", false)), "abandoned regional quest can retry with new attempt")
        var fresh_state := (profile.quest_progress[String(quest_id)] as Dictionary).get("objective_state", {}) as Dictionary
        match quest_id:
            Region3SideQuestAttemptService.QUEST_ESCORT:
                _expect(int(fresh_state.get("next_route_index", -1)) == 0, "escort retry resets the previous route progress")
            Region3SideQuestAttemptService.QUEST_ANNIHILATION:
                _expect((fresh_state.get("defeated_actor_ids", []) as Array).is_empty(), "annihilation retry restores previously defeated designated enemies")
            Region3SideQuestAttemptService.QUEST_DEFENSE:
                _expect(int(fresh_state.get("objective_current_hp", -1)) == int((descriptor["objective_config"] as Dictionary)["objective_max_hp"]), "defense retry restores its protected objective to authored full HP")
        _expect(profile.xp == 0, "abandon and retry cannot claim finite quest XP")
        _expect(not bool(Region3SideQuestAttemptService.commit_accept(save, 1, profile, descriptor, StringName("attempt:%s:one" % String(quest_id))).get("accepted", false)), "old or simultaneous attempt cannot overwrite active attempt")
        var before := profile.to_dictionary()
        var rejected := Region3SideQuestAttemptService.commit_event(RejectingSave.new(), 1, profile, quest_id, StringName("attempt:%s:two" % String(quest_id)), &"actor_defeated", {"actor_id": &"invalid"})
        _expect(not bool(rejected.get("accepted", false)) and profile.to_dictionary() == before, "invalid objective event cannot mutate profile")
    var b_id := Region3SideQuestAttemptService.QUEST_ANNIHILATION
    var b_attempt := StringName("attempt:%s:two" % String(b_id))
    for placement: Dictionary in west["enemy_placements"]:
        var event := Region3SideQuestAttemptService.commit_event(save, 1, profile, b_id, b_attempt, QuestFamilyObjectiveService.EVENT_ACTOR_DEFEATED, {"actor_id": placement["actor_id"]})
        _expect(bool(event.get("accepted", false)), "designated west enemy defeat is durable")
        var duplicate := Region3SideQuestAttemptService.commit_event(save, 1, profile, b_id, b_attempt, QuestFamilyObjectiveService.EVENT_ACTOR_DEFEATED, {"actor_id": placement["actor_id"]})
        _expect((bool(duplicate.get("accepted", false)) and duplicate.get("reason_id", &"") == &"duplicate_ignored") or (StringName(String((profile.quest_progress[String(b_id)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE and not bool(duplicate.get("accepted", false))), "duplicate defeated actor never advances count")
    _expect(StringName(String((profile.quest_progress[String(b_id)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "all five required enemies complete annihilation")
    _expect(not bool(Region3SideQuestAttemptService.commit_turn_in(RejectingSave.new(), 1, profile, b_id, b_attempt).get("accepted", false)), "failed turn-in save retains pending objective completion")
    _expect(bool(Region3SideQuestAttemptService.commit_turn_in(save, 1, profile, b_id, b_attempt).get("accepted", false)), "successful turn-in makes side completion durable")
    _expect(not bool(Region3SideQuestAttemptService.commit_turn_in(save, 1, profile, b_id, b_attempt).get("accepted", false)), "completed side quest cannot turn in twice")
    var saved_final := save.load_profile(1)
    _expect(saved_final != null and StringName(String((saved_final.quest_progress[String(b_id)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_COMPLETED, "finished side reward source survives save/load")
    save.delete_slot(1)
    layout.queue_free()
    await process_frame
    if _failures == 0:
        print("REGION 3 LIVE SIDE QUEST ATTEMPTS TEST PASS")
    else:
        push_error("REGION 3 LIVE SIDE QUEST ATTEMPTS TEST FAILURES: %d" % _failures)
    quit(_failures)

func _plan_with_override(index: int, field: String, value: Variant) -> Region3SideQuestsPlaytest:
    var plan := Region3SideQuestsPlaytest.new()
    plan.quest_specs = QUESTS.quest_specs.duplicate(true)
    plan.quest_specs[index][field] = value
    return plan

func _expect(ok: bool, description: String) -> void:
    if ok:
        print("PASS: %s" % description)
    else:
        _failures += 1
        push_error("FAIL: %s" % description)
