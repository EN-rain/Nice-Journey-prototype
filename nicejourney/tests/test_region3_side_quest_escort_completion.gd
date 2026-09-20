extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_PATH := "user://tests/region3_side_quest_escort_completion"
const ESCORT_ID: StringName = &"side_region3_escort"
var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save := SaveService.new(SAVE_PATH)
    save.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Region Escort Finish", "melee")
    _expect(save.save_profile(1, profile) == OK, "escort completion starts with durable profile")
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    game.set_save_context(save, 1)
    root.add_child(game)
    await process_frame
    if not game.ensure_starting_world():
        _expect(false, "Region 3 loads the escort route")
        await _finish(game, save)
        return
    var runtime := game._region3_side_runtime()
    var accepted := game.request_region3_side_quest(ESCORT_ID)
    _expect(bool(accepted.get("accepted", false)), "escort acceptance commits a live attempt")
    var escort := runtime.get_escort_actor()
    if escort == null:
        _expect(false, "escort actor appears at the authored start")
        await _finish(game, save)
        return
    game.player.global_position = escort.global_position + Vector2(40, 0)
    var spawned := await _await_encounter(runtime, 100)
    _expect(spawned, "three escort hostiles spawn at the south outskirts")
    if not spawned:
        await _finish(game, save)
        return
    var encounters := runtime.get_active_encounter_ids()
    var encounter := runtime.get_encounter_runtime(encounters[0])
    var visuals := runtime.get_visuals_by_actor(encounters[0])
    _expect(visuals.size() == 3, "authored escort spawns exactly three enemies")
    var instance_id := 790000
    for raw_id: Variant in visuals.keys():
        instance_id += 1
        var hit := encounter.resolve_direct_contact(
            &"player:local", StringName(String(raw_id)), instance_id, 0,
            {"domain": DirectHitResolver.DOMAIN_PHYSICAL,
             "delivery": DirectHitResolver.DELIVERY_CONTACT, "raw_damage": 10000.0,
             "dodgeable": true, "blockable": true, "parryable": true, "guard_pressure": 0.0,
             "critical_triggered": false, "critical_multiplier": 1.0,
             "weak_point_triggered": false, "weak_point_multiplier": 1.0},
            false, DirectHitResolver.DEFENSE_NONE, false)
        _expect(bool(hit.get("accepted", false)) and bool(hit.get("target_defeated", false)),
            "escort hostile %s defeated by live player combat" % String(raw_id))
    _expect(encounter.get_active_enemy_count() == 0, "escort travel clears hostile pressure")

    var goal_reached := false
    for step: int in 1350:
        if escort == null or not is_instance_valid(escort):
            break
        game.player.global_position = escort.global_position + Vector2(40, 0)
        var entry := profile.quest_progress.get(String(ESCORT_ID), {}) as Dictionary
        if StringName(String(entry.get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE:
            goal_reached = true
            break
        await physics_frame
    _expect(goal_reached, "escort physically reaches all authored route nodes and goal")
    if goal_reached:
        var state := (profile.quest_progress[String(ESCORT_ID)] as Dictionary).get("objective_state", {}) as Dictionary
        _expect(int(state.get("next_route_index", -1)) ==
            (state.get("route_node_ids", []) as Array).size() and bool(state.get("goal_reached", false)),
            "escort objective records every route node and the final goal")
        var turn_in := game.request_region3_side_quest_turn_in(ESCORT_ID)
        _expect(bool(turn_in.get("accepted", false)) and bool(turn_in.get("durable", false)),
            "Quest Hall completion durably commits escort turn-in")
        _expect(profile.xp == 40, "escort XP awards exactly its finite 40 XP")
        var repeat := game.request_region3_side_quest_turn_in(ESCORT_ID)
        _expect(not bool(repeat.get("accepted", true)) and profile.xp == 40,
            "completed escort cannot claim XP twice")
    await _finish(game, save)


func _await_encounter(runtime: Region3SideQuestRuntime, frames: int) -> bool:
    for unused: int in frames:
        if not runtime.get_active_encounter_ids().is_empty():
            return true
        await physics_frame
    return false


func _finish(game: GameplayRoot, save: SaveService) -> void:
    game.queue_free()
    await process_frame
    save.delete_slot(1)
    if _failures == 0:
        print("REGION3 SIDE QUEST ESCORT COMPLETION TEST PASS")
    else:
        push_error("REGION3 SIDE QUEST ESCORT COMPLETION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, label: String) -> void:
    if ok:
        print("PASS: %s" % label)
    else:
        _failures += 1
        push_error("FAIL: %s" % label)
