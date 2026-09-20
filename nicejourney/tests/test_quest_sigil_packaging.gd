extends SceneTree

const TEST_SAVE_ROOT: String = "user://tests/quest_sigil_packaging"
var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var service: SaveService = SaveService.new(TEST_SAVE_ROOT)
    service.delete_slot(1)
    _test_exact_manifest()
    _test_region3_atomic_access_and_floor1_chain(service)
    service.delete_slot(1)

    if _failures == 0:
        print("QUEST SIGIL PACKAGING TEST PASS")
    else:
        push_error("QUEST SIGIL PACKAGING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_exact_manifest() -> void:
    var definitions: Array[QuestDefinition] = QuestCatalog.all_definitions()
    _expect(QuestCatalog.validate_catalog().is_empty(), "exact DR-03 quest catalog validates")
    _expect(definitions.size() == 15, "quest catalog contains exactly 15 definitions and no separate regional prelude definition")

    var primary_count: int = 0
    var side_count: int = 0
    for definition: QuestDefinition in definitions:
        if definition.kind == QuestDefinition.KIND_PRIMARY:
            primary_count += 1
        elif definition.kind == QuestDefinition.KIND_SIDE:
            side_count += 1
        _expect([
            QuestDefinition.FAMILY_ANNIHILATION,
            QuestDefinition.FAMILY_ESCORT,
            QuestDefinition.FAMILY_TOWER_DEFENSE,
        ].has(definition.family), "%s stays inside the three approved quest families" % String(definition.quest_id))
    _expect(primary_count == 10 and side_count == 5, "manifest contains exactly ten primary and five side definitions")

    var floor1: QuestDefinition = QuestCatalog.get_definition(&"primary_floor_1")
    _expect(floor1 != null, "Floor 1 primary definition exists")
    if floor1 != null:
        _expect(floor1.stage_ids == [&"region3_preparation", &"tower_access_commit", &"floor_objective"], "Floor 1 packages regional preparation, access commit and floor objective as stages of one definition")
        _expect(floor1.includes_region3_preparation and floor1.grants_tower_sigil and floor1.unlocks_floor_id == 1, "Floor 1 definition owns the initial Region 3 preparation -> Sigil + Floor 1 unlock chain")
        _expect(floor1.family == QuestDefinition.FAMILY_ANNIHILATION, "Floor 1 keeps the approved Annihilation objective family")


func _test_region3_atomic_access_and_floor1_chain(service: SaveService) -> void:
    var profile: ProfileSnapshot = ProfileCreationService.create_profile(1, "Quest Tester", "melee")
    _expect(profile != null, "quest fixture profile creates")
    if profile == null:
        return

    _expect(not Region3PreparationCommitService.has_tower_sigil(profile), "Tower Sigil is unavailable before the committed Region 3 preparation stage")
    _expect(not Region3PreparationCommitService.can_physically_enter_floor_1(profile), "physical Floor 1 entry is unavailable before the same committed preparation stage")
    _expect(not Region3PreparationCommitService.can_use_sigil(profile, false), "Sigil travel is unavailable before Sigil ownership")

    var region_safe: Dictionary = SafeCheckpointState.make(
        &"safe:region3_preparation",
        &"region:3",
        0,
        &"checkpoint:region3_town",
        {"hp": 100, "stamina": 100.0},
        {"primary_floor_1": {"stage": "region3_preparation"}},
        1
    )
    _expect(not region_safe.is_empty(), "Region 3 preparation uses a coherent safe snapshot")

    var combat_reject: Dictionary = Region3PreparationCommitService.commit(service, 1, profile, region_safe, true, &"attempt:floor1_primary")
    _expect(not combat_reject["accepted"] and combat_reject["reason_id"] == &"active_combat", "out-of-combat story transaction rejects while Active Combat is true")
    _expect(not Region3PreparationCommitService.has_tower_sigil(profile) and not Region3PreparationCommitService.is_floor_1_unlocked(profile), "rejected story transaction cannot partially grant access")

    var bad_slot_profile: ProfileSnapshot = ProfileSnapshot.from_dictionary(profile.to_dictionary())
    var failed_save: Dictionary = Region3PreparationCommitService.commit(service, 0, bad_slot_profile, region_safe, false, &"attempt:floor1_primary")
    _expect(not failed_save["accepted"] and failed_save["pending_retry"], "failed durable story save remains visibly retryable")
    _expect(not Region3PreparationCommitService.has_tower_sigil(bad_slot_profile) and not Region3PreparationCommitService.is_floor_1_unlocked(bad_slot_profile), "failed save leaves live profile without a false durable Sigil/unlock claim")

    var committed: Dictionary = Region3PreparationCommitService.commit(service, 1, profile, region_safe, false, &"attempt:floor1_primary")
    _expect(committed["accepted"], "Region 3 preparation commits successfully out of combat")
    _expect(Region3PreparationCommitService.has_tower_sigil(profile) and Region3PreparationCommitService.is_floor_1_unlocked(profile), "Tower Sigil and Floor 1 unlock become true atomically")
    _expect(Region3PreparationCommitService.can_use_sigil(profile, false), "owned Tower Sigil is usable outside Active Combat")
    _expect(not Region3PreparationCommitService.can_use_sigil(profile, true), "owned Tower Sigil remains blocked during Active Combat")
    _expect(Region3PreparationCommitService.can_physically_enter_floor_1(profile), "physical Floor 1 entry becomes legal only after the committed preparation stage")

    var progress: Dictionary = profile.quest_progress["primary_floor_1"]
    _expect(progress["state"] == QuestProgressState.STATE_ACTIVE and progress["stage_id"] == &"floor_objective", "successful preparation continues the same Floor 1 definition into its floor objective stage")
    _expect(profile.claimed_transactions.has(String(Region3PreparationCommitService.CLAIM_ID)), "preparation transaction stores one durable claim identity")
    var duplicate: Dictionary = Region3PreparationCommitService.commit(service, 1, profile, region_safe, false, &"attempt:floor1_primary")
    _expect(not duplicate["accepted"] and duplicate["reason_id"] == &"already_committed", "Region 3 preparation cannot grant permanent access twice")

    var loaded_after_access: ProfileSnapshot = service.load_profile(1)
    _expect(loaded_after_access != null and Region3PreparationCommitService.has_tower_sigil(loaded_after_access) and Region3PreparationCommitService.is_floor_1_unlocked(loaded_after_access), "atomic access grant survives save/load")

    var floor: FloorInstanceState = FloorInstanceState.new()
    floor.floor_id = 1
    floor.instance_id = &"tower_floor_1:quest_fixture"
    floor.seed = 1337
    floor.layout_revision_id = &"layout:floor1_v1"
    floor.quest_state = {"primary_floor_1": "active"}
    floor.add_checkpoint(&"checkpoint:floor1_entry")
    _expect(TowerFloorStateService.commit_floor_state(profile, floor), "Floor 1 generated instance binds before objective attempt state is checkpointed")

    var required_ids: Array[StringName] = [&"enemy:floor1_onboarding_a", &"enemy:floor1_onboarding_b"]
    _expect(Floor1PrimaryObjectiveService.bind_designated_group(profile, required_ids), "Floor 1 Annihilation objective binds a caller-authored designated group without inventing its count in the quest definition")
    _expect(not Floor1PrimaryObjectiveService.bind_designated_group(profile, [&"enemy:dup", &"enemy:dup"]), "designated group binding rejects duplicate actor identities")

    var floor_safe: Dictionary = SafeCheckpointState.make(
        &"safe:floor1_objective",
        &"tower:floor_1",
        1,
        &"checkpoint:floor1_entry",
        {"hp": 100, "stamina": 100.0},
        {"primary_floor_1": {"stage": "floor_objective"}},
        2
    )
    _expect(SafeCheckpointCommitService.commit_checkpoint(service, 1, profile, floor_safe) == OK, "bound Floor 1 attempt baseline commits as a coherent safe snapshot")

    var wrong_target: Dictionary = Floor1PrimaryObjectiveService.record_designated_actor_defeat(profile, &"enemy:not_required")
    _expect(not wrong_target["accepted"] and wrong_target["reason_id"] == &"actor_not_required", "incidental enemy defeat does not progress the designated Annihilation objective")
    var first: Dictionary = Floor1PrimaryObjectiveService.record_designated_actor_defeat(profile, required_ids[0])
    _expect(first["accepted"] and first["defeated_count"] == 1 and not first["objectives_complete"], "first required target advances Floor 1 objective once")
    var repeated: Dictionary = Floor1PrimaryObjectiveService.record_designated_actor_defeat(profile, required_ids[0])
    _expect(repeated["accepted"] and repeated["reason_id"] == &"duplicate_ignored" and repeated["defeated_count"] == 1, "duplicate defeat event cannot duplicate quest progress")

    var rollback: Dictionary = DeathRetryCoordinator.retry_failed_attempt(service, 1)
    _expect(rollback["accepted"], "failed Floor 1 attempt restores the committed attempt baseline")
    var restored: ProfileSnapshot = rollback["profile"] as ProfileSnapshot
    _expect(restored != null, "retry returns a coherent restored profile")
    if restored == null:
        return
    var restored_progress: Dictionary = restored.quest_progress["primary_floor_1"]
    var restored_objective: Dictionary = restored_progress["objective_state"]
    _expect((restored_objective["defeated_actor_ids"] as Array).is_empty(), "retry rolls back attempt-local kill progress without revoking permanent Sigil/Floor 1 access")
    _expect(Region3PreparationCommitService.has_tower_sigil(restored) and Region3PreparationCommitService.is_floor_1_unlocked(restored), "DR-01/02 rollback preserves access committed before the restored attempt snapshot")

    var r1: Dictionary = Floor1PrimaryObjectiveService.record_designated_actor_defeat(restored, required_ids[0])
    var r2: Dictionary = Floor1PrimaryObjectiveService.record_designated_actor_defeat(restored, required_ids[1])
    _expect(r1["accepted"] and r2["accepted"] and r2["objectives_complete"], "all designated Floor 1 targets transition the quest to ObjectivesComplete")
    _expect((restored.quest_progress["primary_floor_1"] as Dictionary)["state"] == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "Floor 1 objective chain reaches the explicit ObjectivesComplete state")

    var completion_safe: Dictionary = floor_safe.duplicate(true)
    completion_safe["snapshot_sequence"] = 3
    var turn_in: Dictionary = Floor1PrimaryObjectiveService.commit_turn_in(service, 1, restored, completion_safe)
    _expect(turn_in["accepted"], "Floor 1 objective turn-in commits after all required targets are complete")
    _expect(turn_in["floor_1_cleared"] and turn_in["floor_2_unlocked"], "Floor 1 clear and Floor 2 unlock commit atomically at declared turn-in")
    _expect((restored.quest_progress["primary_floor_1"] as Dictionary)["state"] == QuestProgressState.STATE_COMPLETED, "Floor 1 primary definition reaches Completed without creating another definition")
    _expect(bool((restored.tower_floor_states["1"] as Dictionary)["primary_cleared"]), "persistent Floor 1 instance records primary clear")
    _expect(restored.claimed_transactions.has(String(Floor1PrimaryObjectiveService.COMPLETION_CLAIM_ID)), "Floor 1 completion has one durable claim identity")

    var completed_loaded: ProfileSnapshot = service.load_profile(1)
    _expect(completed_loaded != null and bool(completed_loaded.permanent_flags.get(Floor1PrimaryObjectiveService.FLAG_FLOOR_1_CLEARED, false)), "Floor 1 clear survives save/load")
    _expect(completed_loaded != null and bool(completed_loaded.permanent_flags.get(Floor1PrimaryObjectiveService.FLAG_FLOOR_2_UNLOCKED, false)), "Floor 2 unlock survives the same completion transaction")
    if completed_loaded != null:
        var second_turn_in: Dictionary = Floor1PrimaryObjectiveService.commit_turn_in(service, 1, completed_loaded, completion_safe)
        _expect(not second_turn_in["accepted"], "completed Floor 1 quest cannot grant its clear/unlock transaction twice")


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
