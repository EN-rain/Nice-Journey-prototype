extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_PATH := "user://tests/region3_side_quest_live_integration"
const SIDE_A: StringName = &"side_region3_escort"
const SIDE_B: StringName = &"side_region3_annihilation"
const SIDE_C: StringName = &"side_region3_defense"
var _failures: int = 0
var _hit_id: int = 900000


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save := SaveService.new(SAVE_PATH)
    save.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Side Quest Live", "melee")
    _expect(save.save_profile(1, profile) == OK, "live side-quest test starts from a durable profile")

    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    _expect(game.set_save_context(save, 1), "live side-quest test owns save slot")
    root.add_child(game)
    await process_frame
    if not game.ensure_starting_world():
        _expect(false, "live Region 3 loads with authored quest anchors and quest host")
        await _cleanup(game, save)
        return
    _expect(true, "live Region 3 loads with authored quest anchors and quest host")
    var runtime := game._region3_side_runtime()
    if runtime == null:
        _expect(false, "gameplay binds the Region 3 side-quest runtime")
        await _cleanup(game, save)
        return
    _expect(runtime.available_quest_ids().size() == 3, "three authored side slots are exposed by the live runtime")

    var accepted_a := game.request_region3_side_quest(SIDE_A)
    _expect(bool(accepted_a.get("accepted", false)) and bool(accepted_a.get("durable", false)),
        "R3-SIDE-A acceptance is persisted before live escort begins")
    _expect(_quest_state(profile, SIDE_A) == QuestProgressState.STATE_ACTIVE,
        "escort objective is active after acceptance")
    var escort_save := runtime.capture_escort_safe_state()
    _expect(bool(escort_save.get("accepted", false)) and bool(escort_save.get("durable", false)),
        "escort actor HP and position commit as exact durable runtime state")
    _expect(save.load_profile(1) != null and
        _quest_state(save.load_profile(1), SIDE_A) == QuestProgressState.STATE_ACTIVE,
        "escort acceptance survives real save/load")
    if runtime._escort_actor != null:
        runtime._escort_actor.apply_damage(runtime._escort_actor.max_hp)
        await process_frame
        _expect(_quest_state(profile, SIDE_A) == QuestProgressState.STATE_FAILED,
            "defeated escort fails objective via the live actor signal")
        var retried_a := game.request_region3_side_quest(SIDE_A)
        _expect(bool(retried_a.get("accepted", false)) and
            _quest_state(profile, SIDE_A) == QuestProgressState.STATE_ACTIVE,
            "failed escort can start a durable fresh attempt")
    else:
        _expect(false, "escort NPC is physically instantiated")
    var leave_preview := game.request_region3_side_quest_leave(false)
    _expect(bool(leave_preview.get("accepted", false)) and not bool(leave_preview.get("durable", false)),
        "active escort leave first requires explicit confirmation without abandoning the attempt")
    var leave_a := game.request_region3_side_quest_leave(true)
    _expect(bool(leave_a.get("accepted", false)) and bool(leave_a.get("durable", false)),
        "confirmed escort departure durably abandons the attempt before another quest")

    var accepted_b := game.request_region3_side_quest(SIDE_B)
    _expect(bool(accepted_b.get("accepted", false)) and bool(accepted_b.get("durable", false)),
        "R3-SIDE-B acceptance commits before five hostiles spawn")
    if bool(accepted_b.get("accepted", false)):
        _expect(runtime.get_active_encounter_ids().size() == 1, "annihilation spawns a live encounter")
        _defeat_current_wave(runtime)
        await process_frame
        _expect(_quest_state(profile, SIDE_B) == QuestProgressState.STATE_OBJECTIVES_COMPLETE,
            "five distinct hostile defeats complete annihilation exactly once")
        var turn_b := game.request_region3_side_quest_turn_in(SIDE_B)
        _expect(bool(turn_b.get("accepted", false)) and _quest_state(profile, SIDE_B) == QuestProgressState.STATE_COMPLETED,
            "annihilation turn-in is durably completed")
        _expect(profile.xp == 60, "annihilation XP uses the authored finite 60 XP reward")
        var duplicate_b := game.request_region3_side_quest_turn_in(SIDE_B)
        _expect(not bool(duplicate_b.get("accepted", true)) and profile.xp == 60,
            "annihilation turn-in cannot duplicate the XP claim")

    var accepted_c := game.request_region3_side_quest(SIDE_C)
    _expect(bool(accepted_c.get("accepted", false)) and bool(accepted_c.get("durable", false)),
        "R3-SIDE-C acceptance commits the protected objective")
    if bool(accepted_c.get("accepted", false)):
        var destination := runtime.get_descriptor(SIDE_C).get("defense_objective_world_position", Vector2.INF) as Vector2
        _expect(destination.is_finite(), "defense objective has an authored zone position")
        if destination.is_finite():
            game.player.global_position = destination + Vector2(25, 0)
            for wave: int in 3:
                var spawned := await _await_wave(runtime, 45)
                _expect(spawned, "defense wave %d starts from a designated pair of hostiles" % (wave + 1))
                if spawned:
                    _expect(runtime.get_visuals_by_actor(runtime.get_active_encounter_ids()[0]).size() == 2,
                        "defense wave %d has exactly two actors" % (wave + 1))
                    _defeat_current_wave(runtime)
                await process_frame
            _expect(_quest_state(profile, SIDE_C) == QuestProgressState.STATE_OBJECTIVES_COMPLETE,
                "all three defense waves complete without duplicate actor credit")
            var turn_c := game.request_region3_side_quest_turn_in(SIDE_C)
            _expect(bool(turn_c.get("accepted", false)), "defense turn-in commits")
            _expect(profile.xp == 140, "annihilation and defense XP award exactly 60 + 80")
    _expect(not bool(game.request_region3_side_quest(QuestCatalog.SIDE_IDS[3]).get("accepted", false)),
        "Region 3 cannot accept the separately reserved Tower Floor 4 side quest")
    # This fixture intentionally abandoned A to test retry; set just that
    # read-only eligibility fact to complete for the all-three-exhausted check.
    var previous_escort := (profile.quest_progress[String(SIDE_A)] as Dictionary).duplicate(true)
    var complete_escort := previous_escort.duplicate(true)
    complete_escort["state"] = QuestProgressState.STATE_COMPLETED
    profile.quest_progress[String(SIDE_A)] = complete_escort
    _expect(not bool(game._accept_next_region3_side_quest_if_ready().get("attempted", true)),
        "Quest Hall does not repeatedly attempt unavailable Tower-side sockets after all three Region quests")
    profile.quest_progress[String(SIDE_A)] = previous_escort
    await _cleanup(game, save)


func _defeat_current_wave(runtime: Region3SideQuestRuntime) -> void:
    var ids := runtime.get_active_encounter_ids()
    if ids.is_empty():
        _expect(false, "encounter must be live to resolve hostile defeats")
        return
    var encounter := runtime.get_encounter_runtime(ids[0])
    if encounter == null:
        _expect(false, "active encounter supplies a combat runtime")
        return
    var visuals := runtime.get_visuals_by_actor(ids[0])
    for raw_actor_id: Variant in visuals.keys():
        var actor_id := StringName(String(raw_actor_id))
        _hit_id += 1
        var damage := {
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
        var hit := encounter.resolve_direct_contact(&"player:local", actor_id, _hit_id, 0,
            damage, false, DirectHitResolver.DEFENSE_NONE, false)
        _expect(bool(hit.get("accepted", false)) and bool(hit.get("target_defeated", false)),
            "live player combat resolves distinct designated hostile %s" % String(actor_id))


func _await_wave(runtime: Region3SideQuestRuntime, max_frames: int) -> bool:
    for unused: int in max_frames:
        if not runtime.get_active_encounter_ids().is_empty():
            return true
        await physics_frame
    return false


func _quest_state(profile: ProfileSnapshot, quest_id: StringName) -> StringName:
    var raw: Variant = profile.quest_progress.get(String(quest_id), {})
    return StringName(String((raw as Dictionary).get("state", &""))) if raw is Dictionary else &""


func _cleanup(game: GameplayRoot, save: SaveService) -> void:
    game.queue_free()
    await process_frame
    save.delete_slot(1)
    if _failures == 0:
        print("REGION3 SIDE QUEST LIVE INTEGRATION TEST PASS")
    else:
        push_error("REGION3 SIDE QUEST LIVE INTEGRATION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, label: String) -> void:
    if ok:
        print("PASS: %s" % label)
    else:
        _failures += 1
        push_error("FAIL: %s" % label)
