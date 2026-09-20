extends SceneTree

var _failures := 0
var _commit_calls := 0
var _last_prepared: Dictionary = {}


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Recovery Transaction", "melee")
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "fixture inventory loads")
    _expect(inventory.add_gold(20), "fixture adds explicit Gold")
    profile.item_state = inventory.to_dictionary()
    var definition := _inn_definition()

    var combat_blocked := Region3RecoveryTransactionService.prepare(
        profile,
        definition,
        &"transaction:inn_rest:combat",
        true
    )
    _expect(not bool(combat_blocked.get("accepted", true)) and StringName(combat_blocked.get("reason_id", &"")) == Region3RecoveryTransactionService.REASON_COMBAT_RESTRICTED, "combat-restricted recovery rejects Active Combat")

    var before := profile.to_dictionary()
    var prepared := Region3RecoveryTransactionService.prepare(
        profile,
        definition,
        &"transaction:inn_rest:prepared",
        false
    )
    _expect(bool(prepared.get("accepted", false)), "fully authored recovery definition stages a transaction")
    _expect(int(prepared.get("price_gold", -1)) == 12, "staged transaction uses the exact authored price")
    _expect((prepared.get(Region3RecoveryTransactionService.COMMIT_INPUT_RECOVERY_AMOUNTS_KEY, {}) as Dictionary) == _recovery_payload(), "staged transaction preserves generic authored resource IDs and exact amounts")
    _expect(StringName(prepared.get(Region3RecoveryTransactionService.COMMIT_INPUT_SAVE_EVENT_ID_KEY, &"")) == &"save_event:region3_inn_rest", "save_event_id is forwarded unchanged as authored metadata")
    _expect(profile.to_dictionary() == before, "prepare phase cannot mutate live profile Gold or claims")
    var staged_profile := prepared.get("staged_profile", {}) as Dictionary
    var staged_inventory := InventoryState.new()
    _expect(staged_inventory.load_dictionary(staged_profile.get("item_state", {}) as Dictionary).is_empty() and staged_inventory.gold == 8, "staged profile deducts the exact authored Gold price")

    var malformed_definition := definition.duplicate(true)
    malformed_definition["price_gold"] = -1
    _commit_calls = 0
    var malformed_result := Region3RecoveryTransactionService.commit(
        profile,
        malformed_definition,
        &"transaction:inn_rest:malformed",
        false,
        Callable(self, &"_good_atomic_owner")
    )
    _expect(not bool(malformed_result.get("accepted", true)) and StringName(malformed_result.get("reason_id", &"")) == Region3RecoveryTransactionService.REASON_DEFINITION_INVALID, "malformed recovery definitions fail closed before the atomic owner runs")
    _expect(profile.to_dictionary() == before and _commit_calls == 0, "malformed definitions cannot mutate or invoke external commit ownership")

    var low_gold_profile := _profile_with_gold(5)
    var low_gold_before := low_gold_profile.to_dictionary()
    var insufficient := Region3RecoveryTransactionService.commit(
        low_gold_profile,
        definition,
        &"transaction:inn_rest:insufficient_gold",
        false,
        Callable(self, &"_good_atomic_owner")
    )
    _expect(not bool(insufficient.get("accepted", true)) and StringName(insufficient.get("reason_id", &"")) == Region3RecoveryTransactionService.REASON_INSUFFICIENT_GOLD, "recovery rejects insufficient Gold before the atomic owner runs")
    _expect(low_gold_profile.to_dictionary() == low_gold_before and _commit_calls == 0, "insufficient Gold is non-mutating and does not invoke external commit ownership")

    var rejected_receipt := Region3RecoveryTransactionService.commit(
        profile,
        definition,
        &"transaction:inn_rest:owner_rejected",
        false,
        Callable(self, &"_rejected_atomic_owner")
    )
    _expect(not bool(rejected_receipt.get("accepted", true)) and StringName(rejected_receipt.get("reason_id", &"")) == Region3RecoveryTransactionService.REASON_ATOMIC_COMMIT_REJECTED, "atomic owner rejection remains a rejected recovery transaction")
    _expect(profile.to_dictionary() == before, "owner rejection leaves the live profile untouched")

    var invalid_receipt := Region3RecoveryTransactionService.commit(
        profile,
        definition,
        &"transaction:inn_rest:bad_receipt",
        false,
        Callable(self, &"_bad_atomic_owner")
    )
    _expect(not bool(invalid_receipt.get("accepted", true)) and StringName(invalid_receipt.get("reason_id", &"")) == Region3RecoveryTransactionService.REASON_ATOMIC_COMMIT_RECEIPT_INVALID, "recovery commit rejects a receipt that did not atomically commit resource recovery")
    _expect(profile.to_dictionary() == before, "invalid atomic receipt cannot charge the live profile")

    var malformed_receipt := Region3RecoveryTransactionService.commit(
        profile,
        definition,
        &"transaction:inn_rest:malformed_receipt",
        false,
        Callable(self, &"_malformed_atomic_owner")
    )
    _expect(not bool(malformed_receipt.get("accepted", true)) and StringName(malformed_receipt.get("reason_id", &"")) == Region3RecoveryTransactionService.REASON_ATOMIC_COMMIT_RECEIPT_INVALID, "accepted atomic receipts require exact boolean confirmation fields")
    _expect(profile.to_dictionary() == before, "malformed accepted receipt leaves the live profile untouched")

    _commit_calls = 0
    _last_prepared.clear()
    var committed := Region3RecoveryTransactionService.commit(
        profile,
        definition,
        &"transaction:inn_rest:success",
        false,
        Callable(self, &"_good_atomic_owner")
    )
    _expect(bool(committed.get("accepted", false)) and bool(committed.get("durable", false)), "atomic recovery commit succeeds only after profile and resource state are both confirmed durable")
    var committed_inventory := InventoryState.new()
    _expect(committed_inventory.load_dictionary(profile.item_state).is_empty() and committed_inventory.gold == 8, "successful recovery transaction charges the live profile exactly once")
    _expect(profile.claimed_transactions.has("transaction:inn_rest:success"), "successful recovery transaction records duplicate-resistant identity")
    _expect(_commit_calls == 1 and (_last_prepared.get(Region3RecoveryTransactionService.COMMIT_INPUT_RECOVERY_AMOUNTS_KEY, {}) as Dictionary) == _recovery_payload(), "atomic owner receives one detached generic recovery mapping for caller-owned resources")
    _expect(StringName(_last_prepared.get(Region3RecoveryTransactionService.COMMIT_INPUT_SAVE_EVENT_ID_KEY, &"")) == &"save_event:region3_inn_rest", "atomic owner receives save_event_id as inert authored metadata")

    var after_success := profile.to_dictionary()
    var duplicate := Region3RecoveryTransactionService.commit(
        profile,
        definition,
        &"transaction:inn_rest:success",
        false,
        Callable(self, &"_good_atomic_owner")
    )
    _expect(not bool(duplicate.get("accepted", true)) and StringName(duplicate.get("reason_id", &"")) == Region3RecoveryTransactionService.REASON_DUPLICATE_TRANSACTION, "repeating a recovery transaction ID is rejected before the atomic owner runs")
    _expect(profile.to_dictionary() == after_success and _commit_calls == 1, "duplicate recovery request is non-mutating")

    var stock_only := _inn_definition()
    stock_only["role_id"] = Region3RecoveryServiceDefinition.ROLE_CLINIC_APOTHECARY
    stock_only["structure_id"] = Region3RecoveryServiceDefinition.STRUCTURE_BY_ROLE[Region3RecoveryServiceDefinition.ROLE_CLINIC_APOTHECARY]
    stock_only["service_id"] = &"service:region3_clinic"
    stock_only["recovery_amounts"] = null
    stock_only["stock_reference_id"] = &"vendor:clinic_apothecary"
    var no_direct_recovery := Region3RecoveryTransactionService.prepare(profile, stock_only, &"transaction:clinic_stock_only", false)
    _expect(not bool(no_direct_recovery.get("accepted", true)) and StringName(no_direct_recovery.get("reason_id", &"")) == Region3RecoveryTransactionService.REASON_RECOVERY_PAYLOAD_UNAVAILABLE, "stock-only Clinic remains owned by vendor transactions rather than fabricating direct healing")

    if _failures == 0:
        print("REGION 3 RECOVERY TRANSACTION SERVICE TEST PASS")
    else:
        push_error("REGION 3 RECOVERY TRANSACTION SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _inn_definition() -> Dictionary:
    return {
        "service_id": &"service:region3_inn_rest",
        "structure_id": &"r3:functional:05",
        "role_id": Region3RecoveryServiceDefinition.ROLE_INN_REST_HOUSE,
        "available": true,
        "combat_restricted": true,
        "price_gold": 12,
        "recovery_amounts": _recovery_payload(),
        "stock_reference_id": null,
        "save_event_id": &"save_event:region3_inn_rest",
    }


func _rejected_atomic_owner(_prepared: Dictionary) -> Dictionary:
    _commit_calls += 1
    return {
        Region3RecoveryTransactionService.COMMIT_RECEIPT_ACCEPTED_KEY: false,
        "reason_id": &"fixture_rejected",
    }


func _bad_atomic_owner(prepared: Dictionary) -> Dictionary:
    _commit_calls += 1
    return {
        Region3RecoveryTransactionService.COMMIT_RECEIPT_ACCEPTED_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_DURABLE_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_PROFILE_COMMITTED_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_RECOVERY_COMMITTED_KEY: false,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_TRANSACTION_ID_KEY: prepared.get("transaction_id", &""),
    }


func _malformed_atomic_owner(prepared: Dictionary) -> Dictionary:
    _commit_calls += 1
    return {
        Region3RecoveryTransactionService.COMMIT_RECEIPT_ACCEPTED_KEY: 1,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_DURABLE_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_PROFILE_COMMITTED_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_RECOVERY_COMMITTED_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_TRANSACTION_ID_KEY: prepared.get("transaction_id", &""),
    }


func _good_atomic_owner(prepared: Dictionary) -> Dictionary:
    _commit_calls += 1
    _last_prepared = prepared.duplicate(true)
    return {
        Region3RecoveryTransactionService.COMMIT_RECEIPT_ACCEPTED_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_DURABLE_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_PROFILE_COMMITTED_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_RECOVERY_COMMITTED_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_TRANSACTION_ID_KEY: prepared.get("transaction_id", &""),
    }


func _profile_with_gold(amount: int) -> ProfileSnapshot:
    var profile := ProfileCreationService.create_profile(2, "Recovery Low Gold", "melee")
    var inventory := InventoryState.new()
    if not inventory.load_dictionary(profile.item_state).is_empty():
        return null
    if not inventory.add_gold(amount):
        return null
    profile.item_state = inventory.to_dictionary()
    return profile


func _recovery_payload() -> Dictionary:
    return {
        "resource:test_vitality": 25,
        "resource:test_focus": 5.5,
    }


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
