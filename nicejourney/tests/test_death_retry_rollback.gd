extends SceneTree

const TEST_SAVE_ROOT: String = "user://tests/death_retry_rollback"
var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service: SaveService = SaveService.new(TEST_SAVE_ROOT)
    save_service.delete_slot(1)
    _test_persistent_floor_revisit_policy()
    _test_safe_checkpoint_and_whole_state_rollback(save_service)
    _test_simultaneous_player_boss_defeat(save_service)
    _test_failed_commit_does_not_claim_safe_snapshot(save_service)
    save_service.delete_slot(1)

    if _failures == 0:
        print("DEATH RETRY ROLLBACK TEST PASS")
    else:
        push_error("DEATH RETRY ROLLBACK TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_persistent_floor_revisit_policy() -> void:
    var profile: ProfileSnapshot = ProfileCreationService.create_profile(1, "Floor Tester", "melee")
    var floor: FloorInstanceState = _make_floor_state()
    _expect(TowerFloorStateService.commit_floor_state(profile, floor), "first generated floor instance commits to the profile")
    var revisit: Dictionary = TowerFloorStateService.ordinary_revisit(profile, 1)
    _expect(not revisit.is_empty(), "ordinary revisit returns the committed floor instance")
    _expect(revisit["seed"] == 424242 and revisit["instance_id"] == "tower_floor_1:instance", "ordinary revisit preserves seed and instance identity")
    _expect((revisit["defeated_actor_ids"] as Array).has("enemy:normal_01") and (revisit["claimed_source_ids"] as Array).has("chest:floor1_a"), "ordinary revisit preserves defeated actors and claimed sources")
    _expect((revisit["loose_items"] as Dictionary).has("loose:item_01") and (revisit["vendor_state"] as Dictionary).has("vendor:floor1"), "ordinary revisit preserves loose-item and vendor state")
    _expect(not TowerFloorStateService.supports_player_fresh_reset() and not FloorInstanceState.supports_fresh_reset(), "prototype exposes no player-triggered fresh floor regeneration")

    revisit["seed"] = 7
    (revisit["defeated_actor_ids"] as Array).clear()
    var second_revisit: Dictionary = TowerFloorStateService.ordinary_revisit(profile, 1)
    _expect(second_revisit["seed"] == 424242 and not (second_revisit["defeated_actor_ids"] as Array).is_empty(), "ordinary revisit returns detached state and cannot mutate persistence by editing the read result")

    var replacement: FloorInstanceState = _make_floor_state()
    replacement.seed = 999
    _expect(not TowerFloorStateService.commit_floor_state(profile, replacement), "existing floor cannot silently change seed on revisit")
    replacement = _make_floor_state()
    replacement.instance_id = &"tower_floor_1:different_instance"
    _expect(not TowerFloorStateService.commit_floor_state(profile, replacement), "existing floor cannot silently replace its generated instance")


func _test_safe_checkpoint_and_whole_state_rollback(save_service: SaveService) -> void:
    save_service.delete_slot(1)
    var profile: ProfileSnapshot = ProfileCreationService.create_profile(1, "Rollback Tester", "mage")
    profile.skill_points = 3
    profile.permanent_flags["region3_prepared"] = true
    var floor: FloorInstanceState = _make_floor_state()
    _expect(TowerFloorStateService.commit_floor_state(profile, floor), "rollback fixture commits its floor state")

    var safe_state: Dictionary = SafeCheckpointState.make(
        &"safe:floor1_entry",
        &"tower:floor_1",
        1,
        &"checkpoint:floor1_entry",
        {"hp": 80, "stamina": 65.0, "mana": 40.0, "cooldowns": {"arcane_lance": 12}, "statuses": []},
        {"primary_stage": "floor1_objective"},
        1
    )
    _expect(not safe_state.is_empty(), "coherent safe-state fixture validates")
    _expect(SafeCheckpointCommitService.commit_checkpoint(save_service, 1, profile, safe_state) == OK, "safe checkpoint commits the complete profile generation")
    _expect(profile.safe_state == safe_state, "in-memory safe-state marker advances only after successful durable commit")

    var saved_before_attempt: ProfileSnapshot = save_service.load_profile(1)
    _expect(saved_before_attempt != null and saved_before_attempt.skill_points == 3, "committed safe generation is readable before the attempt")

    profile.skill_points = 99
    profile.xp = 777
    profile.permanent_flags["post_snapshot_reward"] = true
    var mutated_floor: FloorInstanceState = FloorInstanceState.new()
    _expect(mutated_floor.load_dictionary(profile.tower_floor_states["1"]).is_empty(), "attempt fixture can read current floor state")
    _expect(mutated_floor.mark_actor_defeated(&"enemy:elite_post_snapshot"), "attempt can defeat an additional elite after checkpoint")
    _expect(mutated_floor.claim_source(&"reward:post_snapshot"), "attempt can claim a reward after checkpoint")
    _expect(TowerFloorStateService.commit_floor_state(profile, mutated_floor), "attempt changes can exist in current unsaved timeline")
    profile.claimed_transactions["post_snapshot:claim"] = {"source_id": "reward:post_snapshot"}

    var retry: Dictionary = DeathRetryCoordinator.retry_failed_attempt(save_service, 1)
    _expect(retry["accepted"] and retry["attempt_outcome"] == DeathRetryCoordinator.OUTCOME_RETRY_RESTORED, "failed attempt retry restores the latest committed safe generation")
    var restored: ProfileSnapshot = retry["profile"] as ProfileSnapshot
    _expect(restored != null and restored.skill_points == 3 and restored.xp == 0, "whole-state retry rolls back progression earned or changed after checkpoint")
    _expect(not restored.permanent_flags.has("post_snapshot_reward") and not restored.claimed_transactions.has("post_snapshot:claim"), "retry rolls back post-snapshot reward flags and claim identity together")
    var restored_floor: Dictionary = restored.tower_floor_states["1"]
    _expect(not (restored_floor["defeated_actor_ids"] as Array).has("enemy:elite_post_snapshot"), "retry rolls back post-snapshot enemy outcome")
    _expect(not (restored_floor["claimed_source_ids"] as Array).has("reward:post_snapshot"), "retry rolls back post-snapshot source claim with its derived value")
    _expect(restored_floor["seed"] == 424242, "failed retry never chooses a new floor seed")
    _expect(retry["death_fee"] == 0, "retry/death policy adds no fee")
    _expect(String(retry["death_anchor_id"]) == "checkpoint:floor1_entry", "rollback exposes the saved valid checkpoint anchor")


func _test_simultaneous_player_boss_defeat(save_service: SaveService) -> void:
    var result: Dictionary = DeathRetryCoordinator.resolve_attempt_end(save_service, 1, true, true)
    _expect(result["accepted"] and result["attempt_outcome"] == DeathRetryCoordinator.OUTCOME_DEATH_FAILURE, "simultaneous player/boss defeat resolves as player death/failure")
    _expect(result["simultaneous_boss_defeat"], "simultaneous authoritative outcome remains observable")
    _expect(not result["boss_clear_committed"] and not result["boss_reward_committed"], "simultaneous defeat commits no boss clear flag or reward")
    _expect(result["death_fee"] == 0, "death adds no currency, durability, or generic death tax")

    var boss_only: Dictionary = DeathRetryCoordinator.resolve_attempt_end(save_service, 1, false, true)
    _expect(boss_only["accepted"] and boss_only["attempt_outcome"] == DeathRetryCoordinator.OUTCOME_BOSS_VICTORY_PENDING_COMMIT, "boss-only defeat remains pending an explicit success commit instead of pre-awarding reward")
    _expect(not boss_only["boss_clear_committed"] and not boss_only["boss_reward_committed"], "boss result owner must commit clear/reward after authoritative attempt resolution")


func _test_failed_commit_does_not_claim_safe_snapshot(save_service: SaveService) -> void:
    var profile: ProfileSnapshot = ProfileCreationService.create_profile(1, "Commit Tester", "ranged")
    var before: Dictionary = profile.safe_state.duplicate(true)
    var invalid_safe: Dictionary = {
        "snapshot_id": "bad id with spaces",
        "map_id": "tower:floor_1",
        "floor_id": 1,
        "checkpoint_anchor_id": "checkpoint:floor1_entry",
        "player_state": {},
        "quest_attempt_state": {},
        "snapshot_sequence": 1,
    }
    _expect(SafeCheckpointCommitService.commit_checkpoint(save_service, 1, profile, invalid_safe) != OK, "invalid checkpoint transaction is rejected before durable save")
    _expect(profile.safe_state == before, "failed checkpoint commit does not advertise a new in-memory safe snapshot")


func _make_floor_state() -> FloorInstanceState:
    var floor: FloorInstanceState = FloorInstanceState.new()
    floor.floor_id = 1
    floor.instance_id = &"tower_floor_1:instance"
    floor.seed = 424242
    floor.layout_revision_id = &"layout:v1"
    floor.mark_actor_defeated(&"enemy:normal_01")
    floor.claim_source(&"chest:floor1_a")
    floor.loose_items = {"loose:item_01": {"item_id": "potion_small", "claimed": false}}
    floor.vendor_state = {"vendor:floor1": {"stock_revision": 1}}
    floor.quest_state = {"primary_stage": "floor1_objective"}
    floor.add_checkpoint(&"checkpoint:floor1_entry")
    return floor


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
