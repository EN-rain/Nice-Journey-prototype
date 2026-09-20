extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_deposit_withdraw_and_split_identity()
    _test_capacity_and_repeat_click_atomicity()
    _test_profile_persistence()
    if _failures == 0:
        print("STORAGE TRANSACTIONS TEST PASS")
    else:
        push_error("STORAGE TRANSACTIONS TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_deposit_withdraw_and_split_identity() -> void:
    var inventory := InventoryState.new()
    var storage := StorageState.new()
    var ledger := ClaimLedger.new()
    _expect(storage.capacity == 64, "hub storage starts at the 64-slot tuning hypothesis")
    _expect(inventory.try_add_normal(&"item:storage_stack", &"itemdef:potion", 10, true)["accepted"], "inventory fixture owns stack before deposit")
    _expect(inventory.bind_quick_slot(0, &"item:storage_stack"), "fixture binds stack to a quick slot")

    var partial := StorageTransferService.deposit(inventory, storage, ledger, &"tx:storage:deposit_partial", &"item:storage_stack", 4, &"item:storage_split_a")
    _expect(partial["accepted"], "partial deposit commits atomically")
    _expect(inventory.get_normal_slot(&"item:storage_stack")["quantity"] == 6, "partial deposit leaves remainder on original inventory identity")
    _expect(storage.get_normal_slot(&"item:storage_split_a")["quantity"] == 4, "partial deposit creates the caller-declared split identity in storage")
    _expect(inventory.quick_slots[0] == &"item:storage_stack", "partial deposit preserves a valid quick-slot reference")

    var full := StorageTransferService.deposit(inventory, storage, ledger, &"tx:storage:deposit_full", &"item:storage_stack", 6)
    _expect(full["accepted"], "full-stack deposit moves the original identity into storage")
    _expect(inventory.get_normal_slot(&"item:storage_stack").is_empty(), "full deposit removes inventory ownership")
    _expect(inventory.quick_slots[0] == &"", "full deposit clears stale quick-slot references")
    _expect(storage.get_normal_slot(&"item:storage_stack").is_empty() and storage.get_normal_slot(&"item:storage_split_a")["quantity"] == 10, "compatible full deposit merges into the existing stored stack without consuming a second storage slot")

    var withdrawal := StorageTransferService.withdraw(inventory, storage, ledger, &"tx:storage:withdraw_partial", &"item:storage_split_a", 2, &"item:withdraw_split_a")
    _expect(withdrawal["accepted"], "partial withdrawal commits atomically")
    _expect(storage.get_normal_slot(&"item:storage_split_a")["quantity"] == 8, "partial withdrawal leaves the stored remainder after prior compatible-stack merge")
    _expect(inventory.get_normal_slot(&"item:withdraw_split_a")["quantity"] == 2, "partial withdrawal creates a distinct inventory identity")

func _test_capacity_and_repeat_click_atomicity() -> void:
    var inventory := InventoryState.new()
    var storage := StorageState.new()
    var ledger := ClaimLedger.new()
    storage.capacity = 1
    _expect(storage.try_add_normal(&"item:stored_blocker", &"itemdef:blocker", 1, false)["accepted"], "storage fixture fills its declared capacity")
    _expect(inventory.try_add_normal(&"item:deposit_rejected", &"itemdef:deposit_rejected", 1, false)["accepted"], "inventory fixture owns item before rejected deposit")
    var before_inventory := inventory.to_dictionary()
    var before_storage := storage.to_dictionary()
    var rejected := StorageTransferService.deposit(inventory, storage, ledger, &"tx:storage:capacity_reject", &"item:deposit_rejected", 1)
    _expect(not rejected["accepted"] and rejected["reason_id"] == StorageTransferService.REASON_DESTINATION_REJECTED, "full storage rejects deposit")
    _expect(inventory.to_dictionary() == before_inventory and storage.to_dictionary() == before_storage, "full-storage rejection loses no item and mutates neither side")

    storage = StorageState.new()
    ledger = ClaimLedger.new()
    var accepted := StorageTransferService.deposit(inventory, storage, ledger, &"tx:storage:dedup", &"item:deposit_rejected", 1)
    _expect(accepted["accepted"], "first storage transaction commits")
    var after_first_inventory := inventory.to_dictionary()
    var after_first_storage := storage.to_dictionary()
    var duplicate := StorageTransferService.deposit(inventory, storage, ledger, &"tx:storage:dedup", &"item:deposit_rejected", 1)
    _expect(not duplicate["accepted"] and duplicate["reason_id"] == StorageTransferService.REASON_DUPLICATE_TRANSACTION, "repeat click cannot repeat a committed storage transfer")
    _expect(inventory.to_dictionary() == after_first_inventory and storage.to_dictionary() == after_first_storage, "duplicate storage transaction leaves committed ownership unchanged")

    var full_inventory := InventoryState.new()
    for index: int in range(NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY):
        _expect(full_inventory.try_add_normal(StringName("item:full_%02d" % index), StringName("itemdef:full_%02d" % index), 1, false)["accepted"], "full-inventory fixture fills slot %d" % index)
    var withdrawal_storage := StorageState.new()
    _expect(withdrawal_storage.try_add_normal(&"item:stored_withdraw", &"itemdef:stored_withdraw", 1, false)["accepted"], "stored fixture exists before capacity-rejected withdrawal")
    var withdrawal_before := withdrawal_storage.to_dictionary()
    var withdraw_rejected := StorageTransferService.withdraw(full_inventory, withdrawal_storage, ClaimLedger.new(), &"tx:storage:withdraw_reject", &"item:stored_withdraw", 1)
    _expect(not withdraw_rejected["accepted"] and withdraw_rejected["reason_id"] == StorageTransferService.REASON_DESTINATION_REJECTED, "full inventory rejects withdrawal")
    _expect(withdrawal_storage.to_dictionary() == withdrawal_before, "rejected withdrawal leaves storage ownership intact")

func _test_profile_persistence() -> void:
    var storage := StorageState.new()
    _expect(storage.try_add_normal(&"item:persist_storage", &"itemdef:persist_storage", 17, true)["accepted"], "storage persistence fixture owns a stack")
    var profile := ProfileSnapshot.new()
    profile.profile_id = "profile:storage_fixture"
    profile.protagonist_name = "Storage Fixture"
    profile.class_id = "ranged"
    profile.storage_state = storage.to_dictionary()
    var data := profile.to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(data).is_empty(), "profile validator accepts persistent storage state")
    var restored := ProfileSnapshot.from_dictionary(data)
    _expect(restored.storage_state == profile.storage_state, "profile snapshot round-trips storage ownership exactly")
    var legacy := data.duplicate(true)
    legacy.erase("storage_state")
    _expect(ProfileSnapshot.validate_dictionary(legacy).is_empty(), "older schema-v1 snapshots without storage_state remain backward-compatible")

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
