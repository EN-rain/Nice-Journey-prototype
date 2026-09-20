extends SceneTree

const PROFILE_STORAGE_SERVICE: Script = preload("res://src/items/profile_storage_transaction_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_profile_level_deposit_withdraw()
    _test_rejection_atomicity_and_legacy_defaults()
    if _failures == 0:
        print("PROFILE STORAGE TRANSACTION TEST PASS")
    else:
        push_error("PROFILE STORAGE TRANSACTION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_profile_level_deposit_withdraw() -> void:
    var profile := ProfileCreationService.create_profile(1, "Storage Profile", "melee")
    _expect(profile != null, "profile storage fixture creates")
    if profile == null:
        return

    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "profile storage fixture loads initialized inventory")
    _expect(bool(inventory.try_add_normal(
        &"item:profile_storage_stack",
        &"itemdef:profile_storage_stack",
        8,
        true,
        {
            "rarity": "rare",
            "affixes": ["guarded"],
            "upgrade_rank": 1,
            "source_claim_id": "loot:profile_storage",
        }
    ).get("accepted", false)), "profile storage fixture owns metadata-bearing portable stack")
    _expect(inventory.bind_quick_slot(0, &"item:profile_storage_stack"), "profile storage fixture binds quick reference")
    profile.item_state = inventory.to_dictionary()

    var deposited: Dictionary = PROFILE_STORAGE_SERVICE.deposit(
        profile,
        &"tx:profile_storage:deposit_partial",
        &"item:profile_storage_stack",
        3,
        &"item:profile_storage_split"
    )
    _expect(bool(deposited.get("accepted", false)), "profile-level partial storage deposit commits")
    _expect(not bool(deposited.get("durable", true)) and StringName(deposited.get("durability_boundary", &"")) == &"next_safe_snapshot", "profile storage transfer follows DR-02 live-unbanked semantics")
    _expect(StringName(deposited.get("direction", &"")) == &"deposit", "profile storage transfer reports deposit direction")
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "accepted profile storage deposit leaves whole profile valid")

    var post_inventory := InventoryState.new()
    var post_storage := StorageState.new()
    _expect(post_inventory.load_dictionary(profile.item_state).is_empty(), "post-deposit portable inventory loads")
    _expect(post_storage.load_dictionary(profile.storage_state).is_empty(), "post-deposit storage loads")
    _expect(int(post_inventory.get_normal_slot(&"item:profile_storage_stack").get("quantity", 0)) == 5, "partial deposit preserves portable remainder")
    _expect(post_inventory.quick_slots[0] == &"item:profile_storage_stack", "partial deposit preserves valid quick reference")
    var stored := post_storage.get_normal_slot(&"item:profile_storage_split")
    _expect(int(stored.get("quantity", 0)) == 3, "partial deposit creates exact caller-declared split identity")
    _expect(String(stored.get("rarity", "")) == "rare" and (stored.get("affixes", []) as Array) == ["guarded"] and int(stored.get("upgrade_rank", -1)) == 1 and String(stored.get("source_claim_id", "")) == "loot:profile_storage", "profile storage deposit preserves realized metadata/provenance")

    var withdrawn: Dictionary = PROFILE_STORAGE_SERVICE.withdraw(
        profile,
        &"tx:profile_storage:withdraw_partial",
        &"item:profile_storage_split",
        2,
        &"item:profile_storage_withdraw"
    )
    _expect(bool(withdrawn.get("accepted", false)), "profile-level partial storage withdrawal commits")
    _expect(StringName(withdrawn.get("direction", &"")) == &"withdraw", "profile storage transfer reports withdrawal direction")
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "accepted profile storage withdrawal leaves whole profile valid")

    post_inventory = InventoryState.new()
    post_storage = StorageState.new()
    post_inventory.load_dictionary(profile.item_state)
    post_storage.load_dictionary(profile.storage_state)
    _expect(int(post_storage.get_normal_slot(&"item:profile_storage_split").get("quantity", 0)) == 1, "partial withdrawal preserves stored remainder")
    _expect(int(post_inventory.get_normal_slot(&"item:profile_storage_stack").get("quantity", 0)) == 7, "partial withdrawal merges into the existing compatible portable stack")
    _expect(post_inventory.get_normal_slot(&"item:profile_storage_withdraw").is_empty(), "compatible-stack merge does not fabricate a second portable instance")

    var before_duplicate := profile.to_dictionary()
    var duplicate: Dictionary = PROFILE_STORAGE_SERVICE.withdraw(
        profile,
        &"tx:profile_storage:withdraw_partial",
        &"item:profile_storage_split",
        1
    )
    _expect(not bool(duplicate.get("accepted", true)) and StringName(duplicate.get("reason_id", &"")) == StorageTransferService.REASON_DUPLICATE_TRANSACTION, "profile storage repeat transaction is duplicate-resistant")
    _expect(profile.to_dictionary() == before_duplicate, "duplicate profile storage transaction mutates no ownership")


func _test_rejection_atomicity_and_legacy_defaults() -> void:
    var profile := ProfileCreationService.create_profile(2, "Storage Reject", "ranged")
    _expect(profile != null, "profile storage rejection fixture creates")
    if profile == null:
        return

    var inventory := InventoryState.new()
    inventory.load_dictionary(profile.item_state)
    _expect(bool(inventory.try_add_normal(&"item:storage_reject", &"itemdef:storage_reject", 1, false).get("accepted", false)), "profile storage rejection fixture owns portable item")
    profile.item_state = inventory.to_dictionary()

    var full_storage := StorageState.new()
    full_storage.capacity = 1
    _expect(bool(full_storage.try_add_normal(&"item:storage_blocker", &"itemdef:storage_blocker", 1, false).get("accepted", false)), "profile storage rejection fixture fills declared storage capacity")
    profile.storage_state = full_storage.to_dictionary()
    var before_full := profile.to_dictionary()
    var rejected: Dictionary = PROFILE_STORAGE_SERVICE.deposit(
        profile,
        &"tx:profile_storage:full_reject",
        &"item:storage_reject",
        1
    )
    _expect(not bool(rejected.get("accepted", true)) and StringName(rejected.get("reason_id", &"")) == StorageTransferService.REASON_DESTINATION_REJECTED, "profile-level full storage rejects deposit")
    _expect(profile.to_dictionary() == before_full, "full-storage rejection preserves profile bit-for-bit")

    var legacy := ProfileCreationService.create_profile(3, "Storage Legacy", "mage")
    _expect(legacy != null, "legacy storage fixture creates")
    if legacy == null:
        return
    legacy.storage_state = {}
    var legacy_inventory := InventoryState.new()
    legacy_inventory.load_dictionary(legacy.item_state)
    _expect(bool(legacy_inventory.try_add_normal(&"item:legacy_storage", &"itemdef:legacy_storage", 1, false).get("accepted", false)), "legacy storage fixture owns portable item")
    legacy.item_state = legacy_inventory.to_dictionary()
    var legacy_deposit: Dictionary = PROFILE_STORAGE_SERVICE.deposit(
        legacy,
        &"tx:profile_storage:legacy_default",
        &"item:legacy_storage",
        1
    )
    _expect(bool(legacy_deposit.get("accepted", false)), "legacy profile with empty storage_state lazily receives default storage on first successful service transaction")
    var restored_storage := StorageState.new()
    _expect(restored_storage.load_dictionary(legacy.storage_state).is_empty() and restored_storage.capacity == StorageState.DEFAULT_CAPACITY, "legacy successful storage transaction commits the declared default capacity")
    _expect(restored_storage.get_normal_slot(&"item:legacy_storage").size() > 0, "legacy successful storage transaction preserves exact item identity")

    var empty_legacy := ProfileCreationService.create_profile(2, "Storage Empty Legacy", "melee")
    _expect(empty_legacy != null, "empty legacy rejection fixture creates")
    if empty_legacy == null:
        return
    empty_legacy.item_state = {}
    empty_legacy.storage_state = {}
    var before_missing := empty_legacy.to_dictionary()
    var missing: Dictionary = PROFILE_STORAGE_SERVICE.deposit(
        empty_legacy,
        &"tx:profile_storage:legacy_missing",
        &"item:not_owned",
        1
    )
    _expect(not bool(missing.get("accepted", true)), "legacy profile rejects deposit for unowned item")
    _expect(empty_legacy.to_dictionary() == before_missing, "rejected legacy storage transaction does not initialize or mutate live profile state")


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
