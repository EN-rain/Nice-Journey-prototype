extends SceneTree

const LAYOUT: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const PLAYER: PackedScene = preload("res://src/player/player.tscn")
const HOST: PackedScene = preload("res://src/world/region3/quests/region3_side_quest_runtime.tscn")
const QUESTS: Region3SideQuestsPlaytest = preload("res://src/data/tuning/region3_side_quests_playtest_v01.tres")
const PROGRESSION: ProgressionPlaytestContent = preload("res://src/data/tuning/progression_playtest_v01.tres")
const SAVE_PATH := "user://tests/region3_side_quest_failure_recovery"
var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var save := SaveService.new(SAVE_PATH)
    save.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Side Failure Test", "melee")
    _expect(save.save_profile(1, profile) == OK, "failure test profile saved")
    var layout := LAYOUT.instantiate() as Region3AuthoredTownLayout
    root.add_child(layout)
    var player := PLAYER.instantiate() as PlayerController
    layout.add_child(player)
    var host := HOST.instantiate() as Region3SideQuestRuntime
    layout.add_child(host)
    await process_frame
    _expect(bool(host.bind_world(layout, player, profile, save, 1, QUESTS, PROGRESSION, Callable(self, &"_create_state")).get("accepted", false)), "live failure host binds quest authoring")
    var escort_id := Region3SideQuestAttemptService.QUEST_ESCORT
    player.global_position = (host.get_descriptor(escort_id) as Dictionary)["escort_start_world_position"]
    _expect(bool(host.request_accept(escort_id).get("accepted", false)), "escort attempt starts")
    var actor := host.get_escort_actor()
    _expect(actor != null and actor.current_hp > 0, "escort is an actual damageable actor")
    if actor != null:
        actor.apply_damage(actor.current_hp)
        var failed := profile.quest_progress.get(String(escort_id), {}) as Dictionary
        _expect(StringName(String(failed.get("state", &""))) == QuestProgressState.STATE_FAILED, "escort death commits failed quest")
        _expect(save.load_profile(1) != null and StringName(String((save.load_profile(1).quest_progress[String(escort_id)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_FAILED, "escort failure is durable")
        _expect(host.get_escort_actor() == null and host.get_active_encounter_ids().is_empty(), "failed escort clears live actor and encounter")
        _expect(bool(host.request_accept(escort_id).get("accepted", false)), "escort retries with a fresh bound attempt")
        actor = host.get_escort_actor()
        _expect(actor != null and actor.current_hp == actor.max_hp, "retry restores full temporary actor health")
        for tick: int in range(34):
            await physics_frame
        if not host.get_active_encounter_ids().is_empty():
            var visuals := host.get_visuals_by_actor(host.get_active_encounter_ids()[0])
            var first_visual := visuals.values().front() as Node2D
            first_visual.global_position = actor.global_position
            host._advance_objective_hazards()
            _expect(actor.current_hp < actor.max_hp, "registered live hostile can damage escort")
            var checkpoint := host.capture_escort_safe_state()
            _expect(bool(checkpoint.get("accepted", false)) and bool(checkpoint.get("durable", false)), "escort location and health checkpoint saves atomically")
            var persisted := save.load_profile(1)
            var runtime_state := (persisted.quest_progress[String(escort_id)] as Dictionary).get("runtime_state", {}) as Dictionary
            _expect(int(runtime_state.get("escort_hp", -1)) == actor.current_hp, "escort HP is durable in side attempt")
            var hp_before := actor.current_hp
            host.queue_free()
            await process_frame
            var replacement := HOST.instantiate() as Region3SideQuestRuntime
            layout.add_child(replacement)
            _expect(bool(replacement.bind_world(layout, player, persisted, save, 1, QUESTS, PROGRESSION, Callable(self, &"_create_state")).get("accepted", false)), "reloaded host binds original authored markers")
            var recovered := replacement.restore_active_quest()
            _expect(bool(recovered.get("accepted", false)) and bool(recovered.get("restored", false)), "active escort attempt can resume after unloading world")
            _expect(replacement.get_escort_actor() != null and replacement.get_escort_actor().current_hp == hp_before, "restored escort actor retains saved health (expected %d, got %d)" % [hp_before, replacement.get_escort_actor().current_hp if replacement.get_escort_actor() != null else -1])
            _expect(not replacement.unbind_world(), "active quest cannot silently unbind on travel")
            _expect(bool(replacement.request_leave(true).get("accepted", false)), "confirmed departure durably abandons escort attempt")
            _expect(replacement.unbind_world(), "departure cleanup releases world when quest is terminal")
            replacement.queue_free()
            await process_frame
    layout.queue_free()
    await process_frame

    layout = LAYOUT.instantiate() as Region3AuthoredTownLayout
    root.add_child(layout)
    player = PLAYER.instantiate() as PlayerController
    layout.add_child(player)
    host = HOST.instantiate() as Region3SideQuestRuntime
    layout.add_child(host)
    await process_frame
    _expect(bool(host.bind_world(layout, player, profile, save, 1, QUESTS, PROGRESSION, Callable(self, &"_create_state")).get("accepted", false)), "defense host binds after escort release")
    var defense_id := Region3SideQuestAttemptService.QUEST_DEFENSE
    player.global_position = (host.get_descriptor(defense_id) as Dictionary)["defense_objective_world_position"]
    _expect(bool(host.request_accept(defense_id).get("accepted", false)), "defense encounter is an independent quest attempt")
    for tick: int in range(34):
        await physics_frame
    var objective := host.get_defense_objective_actor()
    _expect(objective != null and objective.current_hp > 0, "north objective has physical health")
    if objective != null and not host.get_active_encounter_ids().is_empty():
        var visuals := host.get_visuals_by_actor(host.get_active_encounter_ids()[0])
        for visual: Node2D in visuals.values():
            visual.global_position = objective.global_position
        for hit_index: int in range(32):
            if host.get_defense_objective_actor() == null:
                break
            host._physics_tick += 70
            host._advance_objective_hazards()
        _expect(StringName(String((profile.quest_progress[String(defense_id)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_FAILED, "registered hostile contact destroys defense objective and fails attempt")
        _expect(host.get_active_encounter_ids().is_empty() and host.get_defense_objective_actor() == null, "defense failure cleans actors and releases AI budget")
        _expect(bool(host.request_accept(defense_id).get("accepted", false)), "failed defense can retry from full objective HP")
        _expect(host.get_defense_objective_actor().current_hp == host.get_defense_objective_actor().max_hp, "defense retry resets protected objective")
    host.queue_free()
    layout.queue_free()
    await process_frame
    save.delete_slot(1)
    if _failures == 0:
        print("REGION 3 SIDE QUEST FAILURE RECOVERY TEST PASS")
    else:
        push_error("REGION 3 SIDE QUEST FAILURE RECOVERY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _create_state() -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    state.configure(&"player:local", 180, 50.0, 0.0, 0.0, 30.0, true, true, true)
    return state

func _expect(ok: bool, description: String) -> void:
    if ok:
        print("PASS: %s" % description)
    else:
        _failures += 1
        push_error("FAIL: %s" % description)
