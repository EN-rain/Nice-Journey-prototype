extends SceneTree

const TEST_SAVE_ROOT: String = "user://tests/floor10_primary_boss_objective"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service := SaveService.new(TEST_SAVE_ROOT)
    save_service.delete_slot(1)

    var profile := ProfileCreationService.create_profile(1, "Floor Ten Tester", "melee")
    _expect(profile != null, "Floor 10 boss-objective fixture profile creates")
    if profile == null:
        quit(1)
        return

    profile.quest_progress[String(Floor10PrimaryBossObjectiveService.QUEST_ID)] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:floor10_boss",
        "objective_state": {},
    }
    var floor := FloorInstanceState.new()
    floor.floor_id = 10
    floor.instance_id = &"tower_floor_10:boss_fixture"
    floor.seed = 1010
    floor.layout_revision_id = &"layout:floor10_boss_v1"
    floor.quest_state = {"primary_floor_10": "active"}
    floor.add_checkpoint(&"checkpoint:floor10_preboss")
    _expect(TowerFloorStateService.commit_floor_state(profile, floor), "Floor 10 persistent instance exists before boss objective resolution")
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "Floor 10 objective fixture remains a valid profile snapshot")

    var before_failed := profile.to_dictionary()
    var failed_attempt := Floor10PrimaryBossObjectiveService.record_terminal_outcome(profile, TenthWardenEncounterState.OUTCOME_FAILED_ATTEMPT)
    _expect(failed_attempt["accepted"] and failed_attempt["reason_id"] == &"failed_attempt_no_progress", "failed boss attempt is accepted as a no-progress terminal fact")
    _expect(profile.to_dictionary() == before_failed, "failed boss attempt cannot mutate boss-clear, quest-complete, or persistent floor state")

    var ongoing := Floor10PrimaryBossObjectiveService.record_terminal_outcome(profile, TenthWardenEncounterState.OUTCOME_ONGOING)
    _expect(not ongoing["accepted"] and ongoing["reason_id"] == &"invalid_terminal_outcome", "ongoing encounter state cannot be mistaken for a boss objective result")
    _expect(profile.to_dictionary() == before_failed, "invalid terminal outcome leaves the profile unchanged")

    var victory := Floor10PrimaryBossObjectiveService.record_terminal_outcome(profile, TenthWardenEncounterState.OUTCOME_VICTORY)
    _expect(victory["accepted"] and victory["objectives_complete"], "valid Tenth Warden victory marks the Floor 10 primary objective complete")
    var quest_entry: Dictionary = profile.quest_progress[String(Floor10PrimaryBossObjectiveService.QUEST_ID)] as Dictionary
    _expect(StringName(String(quest_entry["state"])) == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "Floor 10 quest reaches ObjectivesComplete before durable turn-in")
    var objective: Dictionary = quest_entry["objective_state"] as Dictionary
    _expect(bool(objective.get("boss_defeated", false)) and StringName(String(objective.get("boss_actor_id", &""))) == Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID, "objective state records only the approved Tenth Warden defeat identity")
    var floor_after_victory: Dictionary = profile.tower_floor_states["10"] as Dictionary
    _expect(bool(floor_after_victory["boss_defeated"]), "valid victory marks boss defeated in attempt-local Floor 10 state")
    _expect(not bool(floor_after_victory["primary_cleared"]), "boss defeat alone does not silently commit Floor 10 clear before declared turn-in")
    _expect(not bool(profile.permanent_flags.get(Floor10PrimaryBossObjectiveService.FLAG_FLOOR_10_CLEARED, false)), "boss defeat alone does not create a permanent floor-clear flag")

    var duplicate := Floor10PrimaryBossObjectiveService.record_terminal_outcome(profile, TenthWardenEncounterState.OUTCOME_VICTORY)
    _expect(duplicate["accepted"] and duplicate["reason_id"] == &"duplicate_ignored", "duplicate boss-victory delivery cannot duplicate objective progress")

    var safe_floor10 := SafeCheckpointState.make(
        &"safe:floor10_boss_clear",
        &"tower:floor_10",
        10,
        &"checkpoint:floor10_boss_clear",
        {"hp": 100, "stamina": 100.0},
        {"primary_floor_10": {"stage": "floor_objective", "boss_defeated": true}},
        10
    )
    _expect(not safe_floor10.is_empty(), "Floor 10 turn-in uses a coherent floor-10 safe snapshot")

    var wrong_safe := safe_floor10.duplicate(true)
    wrong_safe["floor_id"] = 9
    wrong_safe["map_id"] = "tower:floor_9"
    var wrong_floor_turn_in := Floor10PrimaryBossObjectiveService.commit_turn_in(save_service, 1, profile, wrong_safe)
    _expect(not wrong_floor_turn_in["accepted"] and wrong_floor_turn_in["reason_id"] == &"floor10_safe_snapshot_required", "Floor 10 completion rejects a non-Floor-10 safe snapshot")

    var failed_save_profile := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    var failed_save := Floor10PrimaryBossObjectiveService.commit_turn_in(save_service, 0, failed_save_profile, safe_floor10)
    _expect(not failed_save["accepted"] and failed_save["reason_id"] == &"save_failed", "failed durable Floor 10 save is reported truthfully")
    _expect(not bool((failed_save_profile.tower_floor_states["10"] as Dictionary)["primary_cleared"]), "failed Floor 10 save cannot falsely mark live floor clear")
    _expect(not bool(failed_save_profile.permanent_flags.get(Floor10PrimaryBossObjectiveService.FLAG_FLOOR_10_CLEARED, false)), "failed Floor 10 save cannot falsely create permanent clear")
    _expect(not failed_save_profile.claimed_transactions.has(String(Floor10PrimaryBossObjectiveService.COMPLETION_CLAIM_ID)), "failed Floor 10 save cannot consume the completion claim")

    var turn_in := Floor10PrimaryBossObjectiveService.commit_turn_in(save_service, 1, profile, safe_floor10)
    _expect(turn_in["accepted"] and turn_in["floor_10_cleared"], "declared Floor 10 turn-in durably commits the prototype floor clear")
    _expect(not turn_in["floor_11_unlocked"], "Floor 10 completion explicitly does not unlock Floor 11")
    _expect(not turn_in.has("reward") and not turn_in.has("reward_id") and not turn_in.has("loot"), "Floor 10 clear service does not invent a boss-clear reward")
    _expect(StringName(String((profile.quest_progress[String(Floor10PrimaryBossObjectiveService.QUEST_ID)] as Dictionary)["state"])) == QuestProgressState.STATE_COMPLETED, "Floor 10 primary quest reaches Completed at turn-in")
    _expect(bool((profile.tower_floor_states["10"] as Dictionary)["primary_cleared"]), "persistent Floor 10 instance records primary clear")
    _expect(bool(profile.permanent_flags.get(Floor10PrimaryBossObjectiveService.FLAG_FLOOR_10_CLEARED, false)), "profile records durable Floor 10 clear flag")
    _expect(not profile.permanent_flags.has("tower_floor_11_unlocked"), "prototype milestone does not fabricate a Floor 11 unlock flag")
    _expect(profile.claimed_transactions.has(String(Floor10PrimaryBossObjectiveService.COMPLETION_CLAIM_ID)), "Floor 10 completion has one durable claim identity")

    var loaded := save_service.load_profile(1)
    _expect(loaded != null, "completed Floor 10 profile reloads")
    if loaded != null:
        _expect(bool((loaded.tower_floor_states["10"] as Dictionary)["boss_defeated"]), "boss defeat survives Floor 10 save/load")
        _expect(bool((loaded.tower_floor_states["10"] as Dictionary)["primary_cleared"]), "Floor 10 primary clear survives save/load")
        _expect(bool(loaded.permanent_flags.get(Floor10PrimaryBossObjectiveService.FLAG_FLOOR_10_CLEARED, false)), "permanent Floor 10 clear survives save/load")
        _expect(not loaded.permanent_flags.has("tower_floor_11_unlocked"), "reloaded milestone still has no Floor 11 unlock")
        var duplicate_turn_in := Floor10PrimaryBossObjectiveService.commit_turn_in(save_service, 1, loaded, safe_floor10)
        _expect(not duplicate_turn_in["accepted"] and duplicate_turn_in["reason_id"] != &"", "completed Floor 10 turn-in cannot commit twice")

    var source := FileAccess.get_file_as_string("res://src/quests/progression/floor10_primary_boss_objective_service.gd")
    _expect(not source.contains("floor_11_unlocked\"] = true") and not source.contains("tower_floor_11_unlocked\"] = true"), "Floor 10 service contains no hidden Floor 11 unlock mutation")
    _expect(not source.contains("grant_reward") and not source.contains("award_reward") and not source.contains("roll_loot"), "Floor 10 service contains no hidden reward grant path")

    save_service.delete_slot(1)
    if _failures == 0:
        print("FLOOR 10 PRIMARY BOSS OBJECTIVE TEST PASS")
    else:
        push_error("FLOOR 10 PRIMARY BOSS OBJECTIVE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
