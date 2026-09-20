extends SceneTree

const CLAIM_SERVICE_SCRIPT: Script = preload("res://src/items/pending_reward_claim_transaction_service.gd")
const SAVE_ROOT: String = "user://tests/pending_reward_claim_transaction"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_outside_combat_live_claim_and_duplicate_protection()
    _test_active_combat_blocking()
    _test_inventory_full_rejection()
    _test_dr02_unbanked_then_safe_commit()
    if _failures == 0:
        print("PENDING REWARD CLAIM TRANSACTION TEST PASS")
    else:
        push_error("PENDING REWARD CLAIM TRANSACTION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_outside_combat_live_claim_and_duplicate_protection() -> void:
    var profile := _profile_with_pending(1, &"claim:live_pending", &"item:live_pending", &"itemdef:live_pending", 2)
    var guard := GameplayOperationGuard.new()
    root.add_child(guard)
    var before_safe := profile.safe_state.duplicate(true)
    var result: Dictionary = CLAIM_SERVICE_SCRIPT.claim(
        profile,
        guard,
        &"claim:live_pending",
        &"transaction:pending_reward_claim:live_pending"
    )
    _expect(bool(result.get("accepted", false)), "outside-combat pending reward claim commits atomically to live profile state")
    _expect(not bool(result.get("durable", true)) and StringName(result.get("durability_boundary", &"")) == &"next_safe_snapshot", "successful claim explicitly remains unbanked until next safe snapshot")
    var inventory := InventoryState.new()
    var economy := EconomyState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "claimed live inventory remains valid")
    _expect(economy.load_dictionary(profile.economy_state).is_empty(), "claimed live economy remains valid")
    _expect(not inventory.get_normal_slot(&"item:live_pending").is_empty() and inventory.get_total_quantity(&"itemdef:live_pending") == 2, "claim grants exact pending item identity and quantity")
    _expect(economy.get_pending_reward(&"claim:live_pending").is_empty(), "claim removes exact pending reward source from live economy")
    _expect(profile.safe_state == before_safe, "live claim does not silently promote or rewrite the committed safe snapshot")
    var duplicate: Dictionary = CLAIM_SERVICE_SCRIPT.claim(
        profile,
        guard,
        &"claim:live_pending",
        &"transaction:pending_reward_claim:live_pending"
    )
    _expect(not bool(duplicate.get("accepted", true)) and StringName(duplicate.get("reason_id", &"")) == RewardGrantService.REASON_DUPLICATE_CLAIM, "repeat click cannot claim the same pending reward twice")
    guard.queue_free()


func _test_active_combat_blocking() -> void:
    var profile := _profile_with_pending(1, &"claim:combat_blocked", &"item:combat_blocked", &"itemdef:combat_blocked", 1)
    var guard := GameplayOperationGuard.new()
    root.add_child(guard)
    var token := guard.acquire_blocker(
        &"combat:test_pending_reward",
        GameplayOperationGuard.REASON_ACTIVE_COMBAT,
        "Active combat",
        [GameplayOperationGuard.OP_SERVICE]
    )
    _expect(token != 0, "claim fixture acquires shared Active Combat service blocker")
    var before := profile.to_dictionary()
    var result: Dictionary = CLAIM_SERVICE_SCRIPT.claim(
        profile,
        guard,
        &"claim:combat_blocked",
        &"transaction:pending_reward_claim:combat_blocked"
    )
    _expect(not bool(result.get("accepted", true)) and StringName(result.get("reason_id", &"")) == CLAIM_SERVICE_SCRIPT.REASON_OPERATION_BLOCKED, "pending reward claim is blocked during Active Combat")
    var reasons := result.get("blocking_reasons", []) as Array
    _expect(not reasons.is_empty() and StringName((reasons[0] as Dictionary).get("reason_id", &"")) == GameplayOperationGuard.REASON_ACTIVE_COMBAT, "claim rejection preserves authoritative Active Combat reason")
    _expect(profile.to_dictionary() == before, "blocked claim mutates no live profile ownership")
    guard.release_blocker(token)
    guard.queue_free()


func _test_inventory_full_rejection() -> void:
    var profile := _profile_with_pending(1, &"claim:full_grid", &"item:full_grid_reward", &"itemdef:full_grid_reward", 1)
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "full-grid fixture loads starter inventory")
    for index: int in range(NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY):
        var added := inventory.try_add_normal(
            StringName("item:full_grid_%02d" % index),
            StringName("itemdef:full_grid_%02d" % index),
            1,
            false
        )
        _expect(bool(added.get("accepted", false)), "full-grid fixture fills normal slot %02d" % index)
    profile.item_state = inventory.to_dictionary()
    var guard := GameplayOperationGuard.new()
    root.add_child(guard)
    var before := profile.to_dictionary()
    var result: Dictionary = CLAIM_SERVICE_SCRIPT.claim(
        profile,
        guard,
        &"claim:full_grid",
        &"transaction:pending_reward_claim:full_grid"
    )
    _expect(not bool(result.get("accepted", true)) and StringName(result.get("reason_id", &"")) == RewardGrantService.REASON_INVENTORY_FULL, "pending reward claim revalidates current 16-slot capacity")
    _expect(profile.to_dictionary() == before, "capacity rejection preserves pending reward and all live ownership")
    guard.queue_free()


func _test_dr02_unbanked_then_safe_commit() -> void:
    var save_service := SaveService.new(SAVE_ROOT)
    save_service.delete_slot(1)
    var profile := _profile_with_pending(1, &"claim:rollback_pending", &"item:rollback_pending", &"itemdef:rollback_pending", 1)
    var safe_state := SafeCheckpointState.make(
        &"safe:pending_reward_before_claim",
        &"region3:town",
        0,
        &"checkpoint:region3_town",
        {},
        {},
        1
    )
    _expect(not safe_state.is_empty(), "DR-02 fixture builds a valid committed safe snapshot")
    _expect(SafeCheckpointCommitService.commit_checkpoint(save_service, 1, profile, safe_state) == OK, "pending reward exists in a durable pre-claim safe snapshot")

    var guard := GameplayOperationGuard.new()
    root.add_child(guard)
    var claim_result: Dictionary = CLAIM_SERVICE_SCRIPT.claim(
        profile,
        guard,
        &"claim:rollback_pending",
        &"transaction:pending_reward_claim:rollback_pending"
    )
    _expect(bool(claim_result.get("accepted", false)) and not bool(claim_result.get("durable", true)), "claim after safe snapshot is a live unbanked change")

    var retry: Dictionary = DeathRetryCoordinator.retry_failed_attempt(save_service, 1)
    _expect(bool(retry.get("accepted", false)), "DR-02 retry reloads the latest fully committed safe generation")
    var restored := retry.get("profile") as ProfileSnapshot
    _expect(restored != null, "DR-02 retry returns the committed profile snapshot")
    if restored != null:
        var restored_inventory := InventoryState.new()
        var restored_economy := EconomyState.new()
        _expect(restored_inventory.load_dictionary(restored.item_state).is_empty(), "restored inventory validates after rollback")
        _expect(restored_economy.load_dictionary(restored.economy_state).is_empty(), "restored economy validates after rollback")
        _expect(restored_inventory.get_normal_slot(&"item:rollback_pending").is_empty(), "death rollback removes the unbanked claimed item")
        _expect(not restored_economy.get_pending_reward(&"claim:rollback_pending").is_empty(), "death rollback restores the pending reward source together with its unbanked item")

        var reclaimed: Dictionary = CLAIM_SERVICE_SCRIPT.claim(
            restored,
            guard,
            &"claim:rollback_pending",
            &"transaction:pending_reward_claim:rollback_pending"
        )
        _expect(bool(reclaimed.get("accepted", false)), "restored pending reward can be claimed again after coherent rollback")
        var next_safe := SafeCheckpointState.make(
            &"safe:pending_reward_after_claim",
            &"region3:town",
            0,
            &"checkpoint:region3_town",
            {},
            {},
            2
        )
        _expect(SafeCheckpointCommitService.commit_checkpoint(save_service, 1, restored, next_safe) == OK, "next legitimate safe snapshot banks the claimed reward")
        var banked := save_service.load_profile(1)
        _expect(banked != null, "banked claim reloads from durable save")
        if banked != null:
            var banked_inventory := InventoryState.new()
            var banked_economy := EconomyState.new()
            _expect(banked_inventory.load_dictionary(banked.item_state).is_empty(), "banked claimed inventory reloads cleanly")
            _expect(banked_economy.load_dictionary(banked.economy_state).is_empty(), "banked claimed economy reloads cleanly")
            _expect(not banked_inventory.get_normal_slot(&"item:rollback_pending").is_empty(), "claimed item survives after a later safe snapshot commits it")
            _expect(banked_economy.get_pending_reward(&"claim:rollback_pending").is_empty(), "banked safe snapshot keeps the pending source consumed")
    guard.queue_free()
    save_service.delete_slot(1)


func _profile_with_pending(slot_index: int, claim_id: StringName, item_id: StringName, definition_id: StringName, quantity: int) -> ProfileSnapshot:
    var profile := ProfileCreationService.create_profile(slot_index, "Pending Reward", "melee")
    var economy := EconomyState.new()
    _expect(economy.add_pending_reward(
        claim_id,
        StringName("source:%s" % String(claim_id).replace(":", "_")),
        [{
            "item_instance_id": item_id,
            "definition_id": definition_id,
            "quantity": quantity,
            "stackable": true,
        }]
    ), "pending reward fixture creates a valid persistent claim")
    profile.economy_state = economy.to_dictionary()
    return profile


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
