extends SceneTree

const LAYOUT: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const PLAYER: PackedScene = preload("res://src/player/player.tscn")
const LIVE_HOST: PackedScene = preload("res://src/world/region3/quests/region3_side_quest_runtime.tscn")
const QUESTS: Region3SideQuestsPlaytest = preload("res://src/data/tuning/region3_side_quests_playtest_v01.tres")
const PROGRESSION: ProgressionPlaytestContent = preload("res://src/data/tuning/progression_playtest_v01.tres")
const SAVE_PATH := "user://tests/region3_live_side_quest_host"
var _failures := 0
var _runtime_stats: Dictionary = {"hp": 100.0, "stamina": 100.0}

class RejectingSave:
    extends SaveService
    func save_profile(_slot_index: int, _profile: ProfileSnapshot) -> int:
        return ERR_CANT_CREATE

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var layout := LAYOUT.instantiate() as Region3AuthoredTownLayout
    root.add_child(layout)
    var player := PLAYER.instantiate() as PlayerController
    layout.add_child(player)
    player.global_position = Vector2(34, 90) * 32.0
    var host := LIVE_HOST.instantiate() as Region3SideQuestRuntime
    layout.add_child(host)
    # Test-only modifiers ensure Region 3 uses Inspector archetype stats.
    var custom_catalog := EnemyArchetypePlaytestStatsCatalog.new()
    var custom_roles := {}
    for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        var role := host.enemy_runtime_tuning.archetype_stats.stats_for(archetype_id)
        if archetype_id == &"duelist":
            role.hp_multiplier = 1.5
            role.stamina_bonus = 3.0
            role.physical_defense_bonus = 2.0
            role.arcane_defense_bonus = 4.0
            role.poise_multiplier = 1.2
        custom_roles[String(archetype_id)] = role
    custom_catalog.stats_by_archetype = custom_roles
    var tuned := host.enemy_runtime_tuning.duplicate() as TowerPrototypeEnemyRuntimeTuning
    tuned.archetype_stats = custom_catalog
    host.enemy_runtime_tuning = tuned
    await process_frame
    var save := SaveService.new(SAVE_PATH)
    save.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Side Host Test", "melee")
    _expect(save.save_profile(1, profile) == OK, "live host test profile saved")
    var invalid_tuning := tuned.duplicate() as TowerPrototypeEnemyRuntimeTuning
    invalid_tuning.archetype_stats = EnemyArchetypePlaytestStatsCatalog.new()
    host.enemy_runtime_tuning = invalid_tuning
    _expect(not bool(host.bind_world(layout, player, profile, save, 1, QUESTS, PROGRESSION, Callable(self, &"_create_state")).get("accepted", false)),
        "side-quest encounter refuses incomplete enemy archetype stat authoring")
    host.enemy_runtime_tuning = tuned
    var bound := host.bind_world(layout, player, profile, save, 1, QUESTS, PROGRESSION, Callable(self, &"_create_state"))
    _expect(bool(bound.get("accepted", false)), "region side host binds authored markers and progression")
    _expect(bool(host.get_staging_readiness().get("accepted", false)), "legacy side staging recognizes independently verified live authoring")
    var accepted := host.request_accept(Region3SideQuestAttemptService.QUEST_ANNIHILATION)
    _expect(bool(accepted.get("accepted", false)), "live annihilation quest acceptance and encounter")
    var payload := {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": 300.0,
        "dodgeable": true,
        "blockable": false,
        "parryable": false,
        "guard_pressure": 0.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }
    var ids := host.get_active_encounter_ids()
    _expect(ids.size() == 1, "live encounter registered")
    if ids.size() == 1:
        var encounter := host.get_encounter_runtime(ids[0])
        var visuals := host.get_visuals_by_actor(ids[0])
        _expect(encounter != null and encounter.get_active_enemy_count() == 5, "five live registered enemies")
        _expect(visuals.size() == 5, "five instantiated enemy presentation actors")
        var west_descriptor := host.get_descriptor(Region3SideQuestAttemptService.QUEST_ANNIHILATION)
        var duelist_id: StringName = &""
        for placement: Dictionary in west_descriptor["enemy_placements"] as Array:
            if placement["archetype_id"] == &"duelist":
                duelist_id = placement["actor_id"]
        var duelist := encounter.get_combatant(duelist_id) if encounter != null else null
        _expect(duelist != null and duelist.max_hp == roundi(float(tuned.base_hp) * 1.5)
            and is_equal_approx(duelist.current_stamina, tuned.base_stamina + 3.0)
            and is_equal_approx(duelist.physical_defense, tuned.base_physical_defense + 2.0)
            and is_equal_approx(duelist.arcane_defense, tuned.base_arcane_defense + 4.0)
            and is_equal_approx(duelist.poise_threshold, tuned.base_poise_threshold * 1.2),
            "live west duelist uses actual Inspector-authored HP, stamina, defense and poise role modifiers")
        var counter := 1
        for raw_actor_id: Variant in visuals.keys():
            var actor_id := StringName(String(raw_actor_id))
            var outcome := encounter.resolve_direct_contact(&"player:local", actor_id, counter, 0, payload, false, DirectHitResolver.DEFENSE_NONE, false)
            _expect(bool(outcome.get("accepted", false)) and bool(outcome.get("target_defeated", false)), "player contact defeats live registered enemy")
            counter += 1
        _expect(StringName(String((profile.quest_progress[String(Region3SideQuestAttemptService.QUEST_ANNIHILATION)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "live enemy deaths advance durable annihilation objective")
    _expect(host.unbind_world(), "objectives-complete annihilation can unload region without abandoning pending reward")
    await process_frame
    _expect(bool(host.bind_world(layout, player, profile, save, 1, QUESTS, PROGRESSION, Callable(self, &"_create_state")).get("accepted", false)), "pending turn-in can rebind region after travel")
    var pending := host.restore_active_quest()
    _expect(bool(pending.get("accepted", false)) and bool(pending.get("pending_turn_in", false)) and host.get_active_encounter_ids().is_empty(), "objectives-complete quest restores without respawning its defeated hostiles")
    _expect(not bool(host.request_turn_in().get("accepted", false)), "west return landmark is required for field turn-in")
    _expect(bool(host.request_turn_in(true).get("accepted", false)), "verified Quest Hall turn-in persists annihilation completion")
    var escort_id := Region3SideQuestAttemptService.QUEST_ESCORT
    var escort_accepted := host.request_accept(escort_id)
    _expect(bool(escort_accepted.get("accepted", false)), "escort accepts while player is still away from southern quest site")
    _expect(host.get_active_encounter_ids().is_empty(), "escort enemies do not assault companion before player arrives")
    var escort_actor := host.get_escort_actor()
    _expect(escort_actor != null and escort_actor.current_hp > 0, "escort live actor and health exist in region")
    if escort_actor != null:
        player.global_position = escort_actor.global_position
        for tick: int in range(34):
            await physics_frame
        _expect(host.get_active_encounter_ids().size() == 1, "escort enemies activate when player reaches south site")
        _expect(host.get_visuals_by_actor(host.get_active_encounter_ids()[0]).size() == 3, "three south enemies appear as live combat actors")
        var escort_descriptor := host.get_descriptor(escort_id)
        for route_point: Dictionary in escort_descriptor["escort_route"]:
            escort_actor.global_position = route_point["world_position"]
            player.global_position = escort_actor.global_position
            await physics_frame
            await physics_frame
        var escort_progress := (profile.quest_progress[String(escort_id)] as Dictionary).get("objective_state", {}) as Dictionary
        _expect(int(escort_progress.get("next_route_index", -1)) == (escort_descriptor["escort_route"] as Array).size(), "escort route events advance durable ordered waypoints")
        escort_actor.global_position = escort_descriptor["escort_goal_world_position"]
        player.global_position = escort_actor.global_position
        await physics_frame
        await physics_frame
        _expect(StringName(String((profile.quest_progress[String(escort_id)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "escort physical goal completes live objective")
        _expect(bool(host.request_turn_in(true).get("accepted", false)), "escort can be committed at verified Quest Hall")
    var defense_id := Region3SideQuestAttemptService.QUEST_DEFENSE
    var defense_accepted := host.request_accept(defense_id)
    _expect(bool(defense_accepted.get("accepted", false)), "defense accepts with authored objective and staged waves")
    _expect(host.get_active_encounter_ids().is_empty(), "defense waves do not destroy objective before player reaches north site")
    var defense_actor := host.get_defense_objective_actor()
    _expect(defense_actor != null and defense_actor.current_hp == 120, "protected objective starts with Inspector health")
    if defense_actor != null:
        player.global_position = defense_actor.global_position
        for tick: int in range(34):
            await physics_frame
        for wave_index: int in range(3):
            var live_ids := host.get_active_encounter_ids()
            _expect(live_ids.size() == 1, "defense wave %d activates" % (wave_index + 1))
            if live_ids.is_empty():
                break
            var live_encounter := host.get_encounter_runtime(live_ids[0])
            var live_visuals := host.get_visuals_by_actor(live_ids[0])
            _expect(live_encounter != null and live_visuals.size() == 2, "defense wave %d has exactly two live enemies" % (wave_index + 1))
            var contact_id := 300 + wave_index * 2
            for raw_actor_id: Variant in live_visuals.keys():
                var outcome := live_encounter.resolve_direct_contact(&"player:local", StringName(String(raw_actor_id)), contact_id, 0, payload, false, DirectHitResolver.DEFENSE_NONE, false)
                _expect(bool(outcome.get("accepted", false)) and bool(outcome.get("target_defeated", false)), "defense wave enemy defeat advances the authored wave")
                contact_id += 1
            await physics_frame
            await physics_frame
        _expect(StringName(String((profile.quest_progress[String(defense_id)] as Dictionary).get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "surviving all three defense waves completes durable objective")
        _expect(bool(host.request_turn_in(true).get("accepted", false)), "verified Quest Hall commits defense reward source once")
        _expect(not bool(host.request_turn_in(true).get("accepted", false)), "no duplicate defense turn-in")
    var pending_reward := PlaytestQuestXpCommitService.commit_completed_quest(
        RejectingSave.new(), 1, profile, PROGRESSION, defense_id,
        Callable(self, &"_capture_stats"), Callable(self, &"_apply_stats")
    )
    _expect(not bool(pending_reward.get("accepted", false)) and bool(pending_reward.get("runtime_rolled_back", false)), "failed defense XP save restores runtime stats and leaves claim pending")
    _expect(profile.xp == 0 and _runtime_stats == {"hp": 100.0, "stamina": 100.0}, "failed XP does not change saved level or live stat mirror")
    for quest_id: StringName in [escort_id, Region3SideQuestAttemptService.QUEST_ANNIHILATION, defense_id]:
        var xp_result := PlaytestQuestXpCommitService.commit_completed_quest(
            save, 1, profile, PROGRESSION, quest_id,
            Callable(self, &"_capture_stats"), Callable(self, &"_apply_stats")
        )
        _expect(bool(xp_result.get("accepted", false)) and bool(xp_result.get("durable", false)), "each completed regional quest pays its finite XP once")
        var duplicate_xp := PlaytestQuestXpCommitService.commit_completed_quest(
            save, 1, profile, PROGRESSION, quest_id,
            Callable(self, &"_capture_stats"), Callable(self, &"_apply_stats")
        )
        _expect(not bool(duplicate_xp.get("accepted", false)) and StringName(String(duplicate_xp.get("reason_id", &""))) == LevelProgressionService.REASON_DUPLICATE_CLAIM, "claimed side XP cannot be repeated")
    var rewarded := save.load_profile(1)
    _expect(profile.xp == 180 and rewarded != null and rewarded.xp == 180, "40 + 60 + 80 authored side XP survives a real save/load")
    host.queue_free()
    layout.queue_free()
    await process_frame
    save.delete_slot(1)
    if _failures == 0:
        print("REGION 3 LIVE SIDE QUEST HOST TEST PASS")
    else:
        push_error("REGION 3 LIVE SIDE QUEST HOST TEST FAILURES: %d" % _failures)
    quit(_failures)

func _create_state() -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    state.configure(&"player:local", 180, 50.0, 0.0, 0.0, 30.0, true, true, true)
    return state

func _capture_stats() -> Dictionary:
    return _runtime_stats.duplicate(true)

func _apply_stats(next_stats: Dictionary) -> bool:
    if not AutomaticStatState.validate_dictionary(next_stats).is_empty():
        return false
    _runtime_stats = next_stats.duplicate(true)
    return true

func _expect(ok: bool, description: String) -> void:
    if ok:
        print("PASS: %s" % description)
    else:
        _failures += 1
        push_error("FAIL: %s" % description)
