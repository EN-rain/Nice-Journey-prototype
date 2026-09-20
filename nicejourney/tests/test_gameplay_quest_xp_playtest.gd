extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_PATH := "user://tests/gameplay_quest_xp_playtest"
var _failures := 0
var _test_gameplay: GameplayRoot = null
var _reject_next_runtime_apply := false
var _skip_next_runtime_apply := false


class RejectingSave:
    extends SaveService
    func save_profile(_slot_index: int, _profile: ProfileSnapshot) -> int:
        return ERR_CANT_CREATE


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save := SaveService.new(SAVE_PATH)
    save.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "XP Playtest", "melee")
    profile.quest_progress["primary_floor_1"] = _completed(&"floor_objective")
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "fixture is valid before progression")
    _expect(save.save_profile(1, profile) == OK, "pre-award profile has a valid durable generation")

    var gameplay := GAMEPLAY.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save, 1), "live game has an authorized save owner")
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.ensure_starting_world(), "live XP test enters the Region 3 quest-hall context")
    _expect(gameplay._capture_progression_runtime_stats() == {"hp": 100.0, "stamina": 100.0}, "legacy empty automatic stats initialize from the Inspector class baseline without persisting prematurely")
    gameplay.player.health.set_current_hp(37)
    gameplay.player.stamina.apply_combat_value(19.0, false)

    var first := gameplay.request_completed_quest_xp(&"primary_floor_1")
    _expect(bool(first.get("accepted", false)) and bool(first.get("durable", false)), "completed Floor 1 primary pays XP durably in the shipped scene")
    _expect(profile.xp == 80 and profile.level == 1 and profile.skill_points == 0, "first provisional primary reward remains below the Level 2 threshold")
    _expect(profile.automatic_stats == {"hp": 100.0, "stamina": 100.0}, "first reward seeds persistent base automatic stats")
    _expect(gameplay.player.health.current_hp == 37 and is_equal_approx(gameplay.player.stamina.current_stamina, 19.0), "paying XP does not silently refill damaged health or spent stamina")
    var persisted_first := save.load_profile(1)
    _expect(persisted_first != null and persisted_first.xp == 80 and persisted_first.automatic_stats == profile.automatic_stats, "save/load preserves awarded XP, baseline and claim atomically")
    var first_before := profile.to_dictionary()
    var duplicate := gameplay.request_completed_quest_xp(&"primary_floor_1")
    _expect(not bool(duplicate.get("accepted", true)) and duplicate.get("reason_id", &"") == LevelProgressionService.REASON_DUPLICATE_CLAIM, "repeat primary payout is rejected by the claim ledger")
    _expect(profile.to_dictionary() == first_before, "duplicate payout mutates neither profile nor resource owners")

    profile.quest_progress["primary_floor_2"] = _completed(&"floor_objective")
    var second := gameplay.request_completed_quest_xp(&"primary_floor_2")
    _expect(bool(second.get("accepted", false)) and bool(second.get("durable", false)), "second completed primary can be paid independently")
    _expect(profile.level == 2 and profile.xp == 240 and profile.skill_points == 1, "cumulative playtest XP grants Level 2 and one skill point")
    _expect(profile.automatic_stats == {"hp": 108.0, "stamina": 102.0}, "level transition grants exact Inspector-authored automatic stat growth")
    _expect(gameplay.player.health.get_max_hp() == 108 and is_equal_approx(gameplay.player.stamina.get_max_stamina(), 102.0), "live Health/Stamina caps mirror the durable level-up without changing shared resource assets")
    _expect(gameplay.player.health.current_hp == 37 and is_equal_approx(gameplay.player.stamina.current_stamina, 19.0), "level-up preserves injury and spent stamina")
    var persisted_second := save.load_profile(1)
    _expect(persisted_second != null and persisted_second.level == 2 and persisted_second.xp == 240 and persisted_second.automatic_stats == profile.automatic_stats, "level-up survives real JSON save/load")

    profile.quest_progress["primary_floor_3"] = _completed(&"floor_objective")
    var before_failed := profile.to_dictionary()
    var runtime_before := gameplay._capture_progression_runtime_stats()
    var failed := PlaytestQuestXpCommitService.commit_completed_quest(
        RejectingSave.new(), 1, profile, gameplay.progression_playtest_content,
        &"primary_floor_3", Callable(gameplay, &"_capture_progression_runtime_stats"),
        Callable(gameplay, &"_apply_progression_runtime_stats")
    )
    _expect(not bool(failed.get("accepted", true)) and bool(failed.get("runtime_rolled_back", false)), "failed durable award rolls back live stat changes")
    _expect(profile.to_dictionary() == before_failed and gameplay._capture_progression_runtime_stats() == runtime_before, "failed award leaves quest, profile, claim and live stat mirror unchanged")
    _expect(gameplay.player.health.get_max_hp() == 108 and is_equal_approx(gameplay.player.stamina.get_max_stamina(), 102.0), "failed save restores previous Health/Stamina maximums")
    var third := gameplay.request_completed_quest_xp(&"primary_floor_3")
    _expect(bool(third.get("accepted", false)) and profile.xp == 480 and profile.level == 3, "after failed save the same completed quest remains claimable once")
    _expect(not bool(gameplay.request_completed_quest_xp(&"primary_floor_3").get("accepted", true)), "successful retry cannot be paid twice")
    var missing := gameplay.request_completed_quest_xp(&"primary_floor_4")
    _expect(not bool(missing.get("accepted", true)) and missing.get("reason_id", &"") == PlaytestQuestXpCommitService.REASON_QUEST_NOT_COMPLETED, "uncompleted quest cannot request its XP")

    profile.quest_progress["primary_floor_4"] = _completed(&"floor_objective")
    _test_gameplay = gameplay
    var before_partial := profile.to_dictionary()
    var stats_before_partial := gameplay._capture_progression_runtime_stats()
    _reject_next_runtime_apply = true
    var rejected_apply := PlaytestQuestXpCommitService.commit_completed_quest(
        save, 1, profile, gameplay.progression_playtest_content, &"primary_floor_4",
        Callable(gameplay, &"_capture_progression_runtime_stats"), Callable(self, &"_apply_stats_with_failure")
    )
    _expect(not bool(rejected_apply.get("accepted", true))
        and rejected_apply.get("reason_id", &"") == PlaytestQuestXpCommitService.REASON_RUNTIME_APPLY_FAILED
        and bool(rejected_apply.get("runtime_rolled_back", false)),
        "partially applied quest XP stats are restored when the runtime callback rejects")
    _expect(profile.to_dictionary() == before_partial
        and gameplay._capture_progression_runtime_stats() == stats_before_partial,
        "rejected quest XP apply leaves levels, claims and live stats unchanged")

    _skip_next_runtime_apply = true
    var false_success := PlaytestQuestXpCommitService.commit_completed_quest(
        save, 1, profile, gameplay.progression_playtest_content, &"primary_floor_4",
        Callable(gameplay, &"_capture_progression_runtime_stats"), Callable(self, &"_apply_stats_with_failure")
    )
    _expect(not bool(false_success.get("accepted", true))
        and false_success.get("reason_id", &"") == PlaytestQuestXpCommitService.REASON_RUNTIME_APPLY_MISMATCH
        and bool(false_success.get("runtime_rolled_back", false)),
        "quest XP readback rejects a callback claiming success without applying growth")
    _expect(profile.to_dictionary() == before_partial
        and gameplay._capture_progression_runtime_stats() == stats_before_partial,
        "false-success quest XP callback cannot write a claim or change live stats")
    var recovered := gameplay.request_completed_quest_xp(&"primary_floor_4")
    _expect(bool(recovered.get("accepted", false)) and bool(recovered.get("durable", false)),
        "the same unclaimed quest XP remains claimable after both runtime callback failures")
    _test_gameplay = null

    gameplay.queue_free()
    await process_frame
    save.delete_slot(1)
    if _failures == 0:
        print("GAMEPLAY QUEST XP PLAYTEST TEST PASS")
    else:
        push_error("GAMEPLAY QUEST XP PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _apply_stats_with_failure(stats: Dictionary) -> bool:
    if _skip_next_runtime_apply:
        _skip_next_runtime_apply = false
        return true
    var applied := _test_gameplay._apply_progression_runtime_stats(stats)
    if _reject_next_runtime_apply:
        _reject_next_runtime_apply = false
        return false
    return applied


func _completed(stage: StringName) -> Dictionary:
    return {
        "state": QuestProgressState.STATE_COMPLETED,
        "stage_id": stage,
        "attempt_id": &"attempt:test_xp_completion",
        "objective_state": {},
    }


func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
