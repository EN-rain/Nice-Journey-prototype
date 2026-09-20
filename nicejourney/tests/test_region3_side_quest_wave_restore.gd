extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_PATH := "user://tests/region3_side_quest_wave_restore"
const DEFENSE_ID: StringName = &"side_region3_defense"
var _failures: int = 0
var _instance_id: int = 300000


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save := SaveService.new(SAVE_PATH)
    save.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Regional Wave Restore", "melee")
    _expect(save.save_profile(1, profile) == OK, "created a valid durable test profile")
    var game := await _make_game(profile, save)
    if game == null:
        _finish(null, save)
        return
    var runtime := game._region3_side_runtime()
    var started := game.request_region3_side_quest(DEFENSE_ID)
    _expect(bool(started.get("accepted", false)), "defense starts with an authored wave plan")
    var site := runtime.get_descriptor(DEFENSE_ID).get("defense_objective_world_position", Vector2.INF) as Vector2
    game.player.global_position = site + Vector2(20.0, 0.0)
    _expect(await _wait_for_wave(runtime, 0), "defense wave 1 activates")
    _defeat_current_wave(runtime)
    _expect(await _wait_for_wave(runtime, 1), "wave 2 activates after both wave 1 enemies are defeated")
    _expect(_defeat_one(runtime), "one wave 2 hostile is defeated and durably recorded")
    var loaded := save.load_profile(1)
    _expect(loaded != null, "mid-wave profile loads from actual JSON save")
    if loaded == null:
        _finish(game, save)
        return
    var objective := (loaded.quest_progress[String(DEFENSE_ID)] as Dictionary).get("objective_state", {}) as Dictionary
    var recorded := (objective.get("defeated_actor_ids_by_wave", {}) as Dictionary).get("side_region3_defense:wave:02", []) as Array
    _expect(recorded.size() == 1, "mid-wave durable objective records one of two defeated actors")

    game.queue_free()
    await process_frame
    game = await _make_game(loaded, save)
    if game == null:
        _finish(null, save)
        return
    runtime = game._region3_side_runtime()
    _expect(runtime.progress_snapshot().get("current_wave_index", -1) == 1,
        "saved attempt restores at wave 2, not wave 1")
    game.player.global_position = site + Vector2(20.0, 0.0)
    _expect(await _wait_for_wave(runtime, 1), "wave 2 can activate after a real process restart")
    var active_ids := runtime.get_active_encounter_ids()
    if not active_ids.is_empty():
        _expect(runtime.get_visuals_by_actor(active_ids[0]).size() == 1,
            "wave 2 respawns only the hostile missing from the durable defeat ledger")
        _expect(_defeat_one(runtime), "remaining wave 2 hostile can be defeated")
    var wave_three := await _wait_for_wave(runtime, 2)
    if not wave_three:
        print("WAVE3_DIAG ", runtime.progress_snapshot(), " encounters=", runtime.get_active_encounter_ids(),
            " player_hp=", game.player.health.current_hp, " failed=", game.last_region3_side_quest_result)
    _expect(wave_three, "wave 3 activates after resumed wave 2")
    _defeat_current_wave(runtime)
    await physics_frame
    var entry := loaded.quest_progress.get(String(DEFENSE_ID), {}) as Dictionary
    _expect(StringName(String(entry.get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE,
        "resumed wave 2 plus wave 3 completes the original attempt")
    var turn_in := game.request_region3_side_quest_turn_in(DEFENSE_ID)
    _expect(bool(turn_in.get("accepted", false)) and loaded.xp == 80,
        "resumed defense pays its XP reward exactly once")
    _finish(game, save)


func _defeat_one(runtime: Region3SideQuestRuntime) -> bool:
    var active := runtime.get_active_encounter_ids()
    if active.is_empty():
        return false
    var encounter := runtime.get_encounter_runtime(active[0])
    if encounter == null:
        return false
    var visuals := runtime.get_visuals_by_actor(active[0])
    if visuals.is_empty():
        return false
    var actor_id: StringName = &""
    for raw_id: Variant in visuals.keys():
        var candidate_id := StringName(String(raw_id))
        var candidate := encounter.get_combatant(candidate_id)
        if candidate != null and not candidate.is_defeated():
            actor_id = candidate_id
            break
    if actor_id == &"":
        return false
    _instance_id += 1
    var resolved := encounter.resolve_direct_contact(
        &"player:local", actor_id, _instance_id, 0,
        {"domain": DirectHitResolver.DOMAIN_PHYSICAL,
         "delivery": DirectHitResolver.DELIVERY_CONTACT,
         "raw_damage": 10000.0,
         "dodgeable": true, "blockable": true, "parryable": true, "guard_pressure": 0.0,
         "critical_triggered": false, "critical_multiplier": 1.0,
         "weak_point_triggered": false, "weak_point_multiplier": 1.0},
        false, DirectHitResolver.DEFENSE_NONE, false)
    return bool(resolved.get("accepted", false)) and bool(resolved.get("target_defeated", false))


func _defeat_current_wave(runtime: Region3SideQuestRuntime) -> void:
    var active := runtime.get_active_encounter_ids()
    if active.is_empty():
        _expect(false, "wave has a live encounter before defeat")
        return
    var ids := runtime.get_visuals_by_actor(active[0]).keys()
    for unused: int in ids.size():
        _expect(_defeat_one(runtime), "designated hostile defeat resolves through canonical combat")


func _wait_for_wave(runtime: Region3SideQuestRuntime, wave_index: int) -> bool:
    for unused: int in 150:
        if (
            runtime.progress_snapshot().get("current_wave_index", -1) == wave_index
            and not runtime.get_active_encounter_ids().is_empty()
        ):
            return true
        await physics_frame
    return false


func _make_game(profile: ProfileSnapshot, save: SaveService) -> GameplayRoot:
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    game.set_save_context(save, 1)
    root.add_child(game)
    await process_frame
    if game.ensure_starting_world():
        return game
    _expect(false, "Region 3 can bind the persisted regional quest session")
    game.queue_free()
    await process_frame
    return null


func _finish(game: GameplayRoot, save: SaveService) -> void:
    if game != null:
        game.queue_free()
    save.delete_slot(1)
    if _failures == 0:
        print("REGION3 SIDE QUEST WAVE RESTORE TEST PASS")
    else:
        push_error("REGION3 SIDE QUEST WAVE RESTORE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, label: String) -> void:
    if ok:
        print("PASS: %s" % label)
    else:
        _failures += 1
        push_error("FAIL: %s" % label)
