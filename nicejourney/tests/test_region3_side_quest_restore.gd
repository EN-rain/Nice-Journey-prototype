extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_PATH := "user://tests/region3_side_quest_restore"
const ESCORT_ID: StringName = &"side_region3_escort"
const DEFENSE_ID: StringName = &"side_region3_defense"

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save := SaveService.new(SAVE_PATH)
    save.delete_slot(1)
    var initial := ProfileCreationService.create_profile(1, "Region 3 Side Restore", "melee")
    _expect(save.save_profile(1, initial) == OK, "initial profile is persisted")
    var numeric_snapshot := {"actor_pos_x": 2912.0, "actor_pos_y": 4240.0, "escort_hp": 73.0}
    _expect(Region3SideQuestAttemptService._valid_runtime_snapshot(numeric_snapshot),
        "JSON float-valued integral escort HP is valid")
    numeric_snapshot["escort_hp"] = 73.25
    _expect(not Region3SideQuestAttemptService._valid_runtime_snapshot(numeric_snapshot),
        "fractional escort HP remains rejected rather than truncated")
    numeric_snapshot["escort_hp"] = INF
    _expect(not Region3SideQuestAttemptService._valid_runtime_snapshot(numeric_snapshot),
        "nonfinite escort HP remains rejected")
    var game := await _new_game(initial, save)
    if game == null:
        save.delete_slot(1)
        quit(1)
        return
    var runtime := game._region3_side_runtime()
    var accepted := game.request_region3_side_quest(ESCORT_ID)
    _expect(bool(accepted.get("accepted", false)), "escort starts from a durable quest attempt")
    if runtime._escort_actor != null:
        runtime._escort_actor.global_position += Vector2(0, -16)
        runtime._escort_actor.apply_damage(17)
        var snapshot := runtime.capture_escort_safe_state()
        _expect(bool(snapshot.get("accepted", false)) and bool(snapshot.get("durable", false)),
            "moved and injured escort persists an exact snapshot")
        var saved := save.load_profile(1)
        _expect(saved != null, "escort save loads as valid profile")
        if saved != null:
            var entry := saved.quest_progress.get(String(ESCORT_ID), {}) as Dictionary
            var expected := entry.get("runtime_state", {}) as Dictionary
            _expect(expected.size() == 3 and int(expected.get("escort_hp", -1)) == runtime._escort_actor.current_hp,
                "saved escort contains exact HP and finite position")
            game.queue_free()
            await process_frame
            game = await _new_game(saved, save)
            if game != null:
                runtime = game._region3_side_runtime()
                var restored := runtime._escort_actor
                _expect(restored != null, "region reload instantiates active escort again")
                if restored != null:
                    _expect(restored.current_hp == int(expected["escort_hp"]) and
                        restored.global_position.is_equal_approx(Vector2(
                            float(expected["actor_pos_x"]), float(expected["actor_pos_y"]))),
                        "region reload restores escort HP and world position without resetting attempt")
                _expect((saved.quest_progress[String(ESCORT_ID)] as Dictionary).get("attempt_id", &"") ==
                    (entry.get("attempt_id", &"")), "escort attempt identity survives reload")
        else:
            game.queue_free()
            await process_frame
            game = null
    else:
        _expect(false, "escort actor exists before save")

    if game != null:
        runtime = game._region3_side_runtime()
        if runtime.is_quest_attempt_active():
            var leave := runtime.request_leave(true)
            _expect(bool(leave.get("accepted", false)), "escort can leave explicitly after reload")
        var defense := game.request_region3_side_quest(DEFENSE_ID)
        _expect(bool(defense.get("accepted", false)), "defense can start after persisted escort leave")
        if bool(defense.get("accepted", false)):
            var destination := runtime.get_descriptor(DEFENSE_ID).get(
                "defense_objective_world_position", Vector2.INF) as Vector2
            game.player.global_position = destination + Vector2(20, 0)
            var spawned := await _await_wave(runtime, 45)
            _expect(spawned, "defense hostile wave activates near the protected objective")
            if spawned:
                var authored_interval := int(runtime._descriptor["hostile_objective_contact_cooldown_ticks"])
                for iteration: int in 100:
                    var encounter_ids := runtime.get_active_encounter_ids()
                    if encounter_ids.is_empty() or runtime._defense_actor == null:
                        break
                    var visuals := runtime.get_visuals_by_actor(encounter_ids[0])
                    for raw_visual: Variant in visuals.values():
                        var visual := raw_visual as Node2D
                        if visual != null:
                            visual.global_position = runtime._defense_actor.global_position + Vector2(2, 0)
                    runtime._physics_tick += authored_interval
                    runtime._advance_objective_hazards()
                _expect(_quest_state(game._profile, DEFENSE_ID) == QuestProgressState.STATE_FAILED,
                    "live hostile objective contacts fail defense at zero HP")
                _expect(not runtime.is_quest_attempt_active(),
                    "destroyed defense objective releases the failed live attempt")
                var retry := game.request_region3_side_quest(DEFENSE_ID)
                _expect(bool(retry.get("accepted", false)) and
                    _quest_state(game._profile, DEFENSE_ID) == QuestProgressState.STATE_ACTIVE,
                    "failed defense can retry with existing authoring and a new attempt")
        game.queue_free()
        await process_frame
    save.delete_slot(1)
    if _failures == 0:
        print("REGION3 SIDE QUEST RESTORE TEST PASS")
    else:
        push_error("REGION3 SIDE QUEST RESTORE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _new_game(profile: ProfileSnapshot, save: SaveService) -> GameplayRoot:
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    game.set_save_context(save, 1)
    root.add_child(game)
    await process_frame
    if game.ensure_starting_world():
        return game
    _expect(false, "Region 3 activation and side-quest restore succeeds")
    game.queue_free()
    await process_frame
    return null


func _await_wave(runtime: Region3SideQuestRuntime, max_frames: int) -> bool:
    for unused: int in max_frames:
        if not runtime.get_active_encounter_ids().is_empty():
            return true
        await physics_frame
    return false


func _quest_state(profile: ProfileSnapshot, quest_id: StringName) -> StringName:
    var raw: Variant = profile.quest_progress.get(String(quest_id), {})
    return StringName(String((raw as Dictionary).get("state", &""))) if raw is Dictionary else &""


func _expect(ok: bool, label: String) -> void:
    if ok:
        print("PASS: %s" % label)
    else:
        _failures += 1
        push_error("FAIL: %s" % label)
