extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_atomic_stack_and_capacity_behavior()
    _test_protected_and_quick_slot_behavior()
    _test_profile_persistence_round_trip()
    if _failures == 0:
        print("INVENTORY STATE TEST PASS")
    else:
        push_error("INVENTORY STATE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_atomic_stack_and_capacity_behavior() -> void:
    var inventory := InventoryState.new()
    _expect(inventory.try_add_normal(&"item:potion_stack_a", &"itemdef:potion", 80, true)["accepted"], "first stack enters one normal slot")
    _expect(inventory.normal_slots.size() == 1 and inventory.normal_slots[0]["quantity"] == 80, "first stack quantity is owned exactly")
    _expect(inventory.try_add_normal(&"item:potion_stack_b", &"itemdef:potion", 30, true)["accepted"], "compatible stack merges then allocates at most one overflow slot")
    _expect(inventory.normal_slots.size() == 2 and inventory.normal_slots[0]["quantity"] == 99 and inventory.normal_slots[1]["quantity"] == 11, "stack cap 99 is preserved while remainder receives its own slot")

    for index: int in range(14):
        _expect(inventory.try_add_normal(StringName("item:gear_%02d" % index), StringName("itemdef:gear_%02d" % index), 1, false)["accepted"], "nonstackable fixture fills slot %d" % (index + 3))
    _expect(inventory.normal_slots.size() == NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY, "fixture reaches exactly sixteen normal slots")

    var before: Dictionary = inventory.to_dictionary()
    var rejected: Dictionary = inventory.try_add_normal(&"item:new_full", &"itemdef:new_full", 1, false)
    _expect(not rejected["accepted"] and rejected["reason_id"] == InventoryState.REASON_INVENTORY_FULL, "full inventory rejects a new normal slot")
    _expect(inventory.to_dictionary() == before, "full-inventory rejection is atomic and cannot partially mutate existing stacks")

    var merge_only: Dictionary = inventory.try_add_normal(&"item:potion_stack_c", &"itemdef:potion", 5, true)
    _expect(merge_only["accepted"], "full inventory still accepts compatible quantity when an existing stack has room")
    _expect(inventory.normal_slots[1]["quantity"] == 16, "merge-only pickup consumes no new normal slot")


func _test_protected_and_quick_slot_behavior() -> void:
    var inventory := InventoryState.new()
    _expect(inventory.grant_protected(&"quest:key_alpha"), "critical quest item is owned outside the normal grid")
    _expect(inventory.normal_slots.is_empty(), "protected quest ownership consumes no normal slot")
    _expect(inventory.grant_protected(InventoryState.TOWER_SIGIL_ID, true), "permanent Tower Sigil entitlement is grantable through protected ownership")
    var sigil_remove: Dictionary = inventory.remove_protected_by_quest(InventoryState.TOWER_SIGIL_ID)
    _expect(not sigil_remove["accepted"] and sigil_remove["policy_reason_id"] == ProtectedItemOperationPolicy.REASON_PERMANENT_TOWER_SIGIL, "ordinary quest removal cannot remove the permanent Tower Sigil")
    _expect(inventory.remove_protected_by_quest(&"quest:key_alpha")["accepted"], "ordinary protected quest item may be removed only by quest logic")

    _expect(inventory.try_add_normal(&"item:consumable_a", &"itemdef:consumable", 4, true)["accepted"], "normal consumable fixture is added")
    _expect(inventory.bind_quick_slot(0, &"item:consumable_a"), "quick slot references an owned item instance without duplicating ownership")
    _expect(inventory.quick_slots[0] == &"item:consumable_a", "quick-slot reference is stable")
    _expect(inventory.try_remove_normal(&"item:consumable_a", 4)["accepted"], "removing the final owned stack succeeds")
    _expect(inventory.quick_slots[0] == &"", "removing an owned stack clears stale quick-slot references")


func _test_profile_persistence_round_trip() -> void:
    var inventory := InventoryState.new()
    _expect(inventory.add_gold(125), "gold is added as the single prototype currency")
    _expect(not inventory.spend_gold(126), "overspend cannot mutate gold")
    _expect(inventory.gold == 125, "failed gold spend is atomic")
    _expect(inventory.try_add_normal(&"item:profile_stack", &"itemdef:profile_consumable", 7, true)["accepted"], "profile inventory fixture owns a normal stack")
    _expect(inventory.grant_protected(InventoryState.TOWER_SIGIL_ID, true), "profile inventory fixture owns permanent Sigil")

    var profile := ProfileSnapshot.new()
    profile.profile_id = "profile:inventory_fixture"
    profile.protagonist_name = "Inventory Fixture"
    profile.class_id = "melee"
    profile.item_state = inventory.to_dictionary()
    var data: Dictionary = profile.to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(data).is_empty(), "profile validator accepts populated item/economy state")
    var restored: ProfileSnapshot = ProfileSnapshot.from_dictionary(data)
    _expect(restored.item_state == profile.item_state, "profile snapshot round-trips item/economy ownership exactly")

    var legacy := data.duplicate(true)
    legacy.erase("item_state")
    _expect(ProfileSnapshot.validate_dictionary(legacy).is_empty(), "older schema-v1 snapshots without item_state remain backward-compatible")


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
