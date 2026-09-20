extends SceneTree

const TRACKER_SCRIPT: Script = preload("res://src/ui/quest_tracker_view_service.gd")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_no_floor_and_unrelated_side_quest()
    _test_annihilation_progress()
    _test_escort_progress()
    _test_defense_progress()
    _test_floor10_boss_progress()
    _test_invalid_objective_fails_closed()

    if _failures == 0:
        print("QUEST TRACKER VIEW SERVICE TEST PASS")
    else:
        push_error("QUEST TRACKER VIEW SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_no_floor_and_unrelated_side_quest() -> void:
    var profile := ProfileCreationService.create_profile(1, "Tracker", "melee")
    profile.quest_progress["side_region3_annihilation"] = _entry(&"annihilation_objective", {})
    var no_floor: Dictionary = TRACKER_SCRIPT.build_current_tower_primary(profile, 0)
    _expect(not bool(no_floor.get("available", true)) and StringName(no_floor.get("reason_id", &"")) == TRACKER_SCRIPT.REASON_NO_ACTIVE_TOWER_FLOOR, "quest tracker stays unavailable without an active Tower floor")
    var floor_one: Dictionary = TRACKER_SCRIPT.build_current_tower_primary(profile, 1)
    _expect(not bool(floor_one.get("available", true)) and StringName(floor_one.get("reason_id", &"")) == TRACKER_SCRIPT.REASON_QUEST_NOT_TRACKABLE, "unrelated side quests cannot become the current Tower primary tracker")


func _test_annihilation_progress() -> void:
    var profile := ProfileCreationService.create_profile(1, "Tracker", "melee")
    var objective := AnnihilationObjectiveState.new()
    _expect(objective.configure([&"enemy:a", &"enemy:b", &"enemy:c"]), "annihilation tracker fixture configures designated actors")
    _expect(bool(objective.record_actor_defeated(&"enemy:b").get("accepted", false)), "annihilation tracker fixture records one authoritative defeat")
    profile.quest_progress["primary_floor_1"] = _entry(&"floor_objective", objective.to_dictionary())

    var result: Dictionary = TRACKER_SCRIPT.build_current_tower_primary(profile, 1)
    _expect(bool(result.get("available", false)), "active Floor 1 primary becomes trackable")
    _expect(StringName(result.get("quest_id", &"")) == &"primary_floor_1" and StringName(result.get("family", &"")) == QuestDefinition.FAMILY_ANNIHILATION, "tracker preserves exact primary quest/family identity")
    _expect(StringName(result.get("progress_kind", &"")) == TRACKER_SCRIPT.PROGRESS_ANNIHILATION, "annihilation objective uses annihilation progress semantics")
    _expect(int(result.get("defeated_count", -1)) == 1 and int(result.get("required_count", -1)) == 3 and int(result.get("remaining_count", -1)) == 2, "annihilation tracker reports exact defeated/required/remaining counts")
    _expect(not bool(result.get("timer_state_available", true)), "tracker does not fabricate a timer when no timer owner exists")
    (result as Dictionary)["defeated_count"] = 99
    var repeat: Dictionary = TRACKER_SCRIPT.build_current_tower_primary(profile, 1)
    _expect(int(repeat.get("defeated_count", -1)) == 1, "mutating returned quest-tracker data cannot mutate persistent objective state")


func _test_escort_progress() -> void:
    var profile := ProfileCreationService.create_profile(1, "Tracker", "melee")
    var objective := EscortObjectiveState.new()
    _expect(objective.configure(
        &"npc:escort_test",
        [&"route:a", &"route:b", &"route:c"],
        &"goal:escort_test",
        &"origin:escort_test",
        &"failure:escort_test"
    ), "escort tracker fixture configures exact actor/route/goal policy")
    _expect(bool(objective.record_route_node_reached(&"route:a").get("accepted", false)), "escort tracker fixture advances one authored route node")
    _expect(objective.set_wait_requested(true), "escort tracker fixture owns an explicit wait request")
    profile.quest_progress["primary_floor_2"] = _entry(&"floor_objective", objective.to_dictionary())

    var result: Dictionary = TRACKER_SCRIPT.build_current_tower_primary(profile, 2)
    _expect(bool(result.get("available", false)) and StringName(result.get("progress_kind", &"")) == TRACKER_SCRIPT.PROGRESS_ESCORT, "Floor 2 primary exposes escort progress")
    _expect(int(result.get("next_route_index", -1)) == 1 and int(result.get("route_count", -1)) == 3, "escort tracker reports exact route progress")
    _expect(bool(result.get("wait_requested", false)) and not bool(result.get("goal_reached", true)), "escort tracker preserves wait/goal state without inventing failure")


func _test_defense_progress() -> void:
    var profile := ProfileCreationService.create_profile(1, "Tracker", "melee")
    var objective := TowerDefenseObjectiveState.new()
    _expect(objective.configure(
        &"objective:defense_test",
        100,
        {
            &"wave:1": [&"enemy:w1a"],
            &"wave:2": [&"enemy:w2a", &"enemy:w2b"],
        }
    ), "defense tracker fixture configures objective HP and two waves")
    _expect(bool(objective.record_actor_defeated(&"wave:1", &"enemy:w1a").get("accepted", false)), "defense tracker fixture completes wave one")
    _expect(bool(objective.apply_objective_damage(25).get("accepted", false)), "defense tracker fixture mutates authoritative objective HP")
    profile.quest_progress["primary_floor_3"] = _entry(&"floor_objective", objective.to_dictionary())

    var result: Dictionary = TRACKER_SCRIPT.build_current_tower_primary(profile, 3)
    _expect(bool(result.get("available", false)) and StringName(result.get("progress_kind", &"")) == TRACKER_SCRIPT.PROGRESS_TOWER_DEFENSE, "Floor 3 primary exposes tower-defense progress")
    _expect(int(result.get("completed_wave_count", -1)) == 1 and int(result.get("wave_count", -1)) == 2, "defense tracker reports exact completed/required wave counts")
    _expect(int(result.get("objective_current_hp", -1)) == 75 and int(result.get("objective_max_hp", -1)) == 100, "defense tracker reports exact objective HP")


func _test_floor10_boss_progress() -> void:
    var profile := ProfileCreationService.create_profile(1, "Tracker", "melee")
    profile.quest_progress["primary_floor_10"] = _entry(&"floor_objective", {
        "boss_actor_id": String(Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID),
        "boss_defeated": false,
    })
    var active: Dictionary = TRACKER_SCRIPT.build_current_tower_primary(profile, 10)
    _expect(bool(active.get("available", false)) and StringName(active.get("progress_kind", &"")) == TRACKER_SCRIPT.PROGRESS_BOSS, "Floor 10 special primary uses boss progress instead of pretending it is generic annihilation state")
    _expect(StringName(active.get("boss_actor_id", &"")) == Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID and not bool(active.get("boss_defeated", true)), "Floor 10 tracker preserves authoritative boss identity/defeat state")

    var complete_entry := (profile.quest_progress["primary_floor_10"] as Dictionary).duplicate(true)
    complete_entry["state"] = QuestProgressState.STATE_OBJECTIVES_COMPLETE
    complete_entry["objective_state"] = {
        "boss_actor_id": String(Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID),
        "boss_defeated": true,
    }
    profile.quest_progress["primary_floor_10"] = complete_entry
    var complete: Dictionary = TRACKER_SCRIPT.build_current_tower_primary(profile, 10)
    _expect(bool(complete.get("available", false)) and StringName(complete.get("progress_kind", &"")) == TRACKER_SCRIPT.PROGRESS_OBJECTIVES_COMPLETE, "objectives-complete quest state overrides family-specific in-progress presentation")


func _test_invalid_objective_fails_closed() -> void:
    var profile := ProfileCreationService.create_profile(1, "Tracker", "melee")
    profile.quest_progress["primary_floor_2"] = _entry(&"floor_objective", {
        "actor_id": "not stable whitespace",
    })
    var result: Dictionary = TRACKER_SCRIPT.build_current_tower_primary(profile, 2)
    _expect(not bool(result.get("available", true)) and StringName(result.get("reason_id", &"")) == TRACKER_SCRIPT.REASON_OBJECTIVE_INVALID, "malformed persisted objective state fails closed instead of becoming misleading HUD progress")


func _entry(stage_id: StringName, objective_state: Dictionary) -> Dictionary:
    return {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": stage_id,
        "attempt_id": "attempt:tracker_test",
        "objective_state": objective_state.duplicate(true),
    }


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
