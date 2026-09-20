extends SceneTree

const DESTROY_SERVICE: Script = preload("res://src/items/inventory_destroy_transaction_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Destroy Test", "melee")
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "destroy fixture loads initialized inventory")
    _expect(bool(inventory.try_add_normal(&"item:potion_stack", &"potion_basic", 5, true).get("accepted", false)), "destroy fixture owns stackable normal item")
    _expect(inventory.bind_quick_slot(0, &"item:potion_stack"), "destroy fixture binds quick slot to stack")
    _expect(inventory.grant_protected(InventoryState.TOWER_SIGIL_ID, true), "destroy fixture owns protected Tower Sigil")
    profile.item_state = inventory.to_dictionary()

    var before_unconfirmed := profile.to_dictionary()
    var unconfirmed: Dictionary = DESTROY_SERVICE.destroy_normal_item(profile, &"destroy:potion_1", &"item:potion_stack", 2, false)
    _expect(not bool(unconfirmed.get("accepted", true)) and StringName(unconfirmed.get("reason_id", &"")) == DESTROY_SERVICE.REASON_CONFIRMATION_REQUIRED, "normal item destroy requires explicit confirmation")
    _expect(profile.to_dictionary() == before_unconfirmed, "unconfirmed destroy mutates no ownership or claim state")

    var first: Dictionary = DESTROY_SERVICE.destroy_normal_item(profile, &"destroy:potion_1", &"item:potion_stack", 2, true)
    _expect(bool(first.get("accepted", false)) and int(first.get("remaining_quantity", -1)) == 3, "confirmed destroy removes exactly the requested stack quantity")
    var after_first := InventoryState.new()
    _expect(after_first.load_dictionary(profile.item_state).is_empty(), "post-destroy inventory remains valid")
    _expect(int(after_first.get_normal_slot(&"item:potion_stack").get("quantity", 0)) == 3, "partial destroy preserves the same item instance with reduced quantity")
    _expect(after_first.quick_slots[0] == &"item:potion_stack", "partial destroy preserves a valid quick-slot reference")
    var ledger := ClaimLedger.new()
    _expect(ledger.load_dictionary(profile.claimed_transactions).is_empty() and ledger.is_claimed(&"destroy:potion_1"), "confirmed destroy records duplicate-resistant transaction identity")

    var before_duplicate := profile.to_dictionary()
    var duplicate: Dictionary = DESTROY_SERVICE.destroy_normal_item(profile, &"destroy:potion_1", &"item:potion_stack", 1, true)
    _expect(not bool(duplicate.get("accepted", true)) and StringName(duplicate.get("reason_id", &"")) == DESTROY_SERVICE.REASON_DUPLICATE_TRANSACTION, "duplicate destroy transaction cannot spend item quantity twice")
    _expect(profile.to_dictionary() == before_duplicate, "duplicate destroy leaves profile unchanged")

    var over_quantity: Dictionary = DESTROY_SERVICE.destroy_normal_item(profile, &"destroy:potion_too_many", &"item:potion_stack", 4, true)
    _expect(not bool(over_quantity.get("accepted", true)) and StringName(over_quantity.get("reason_id", &"")) == DESTROY_SERVICE.REASON_INVALID_QUANTITY, "destroy rejects quantity larger than the owned stack")

    var final: Dictionary = DESTROY_SERVICE.destroy_normal_item(profile, &"destroy:potion_final", &"item:potion_stack", 3, true)
    _expect(bool(final.get("accepted", false)) and int(final.get("remaining_quantity", -1)) == 0, "confirmed final destroy removes the remaining stack")
    var after_final := InventoryState.new()
    _expect(after_final.load_dictionary(profile.item_state).is_empty(), "final destroy leaves valid inventory state")
    _expect(after_final.get_normal_slot(&"item:potion_stack").is_empty(), "final destroy removes the exact normal item instance")
    _expect(after_final.quick_slots[0] == &"", "destroying the full referenced stack clears its quick-slot reference")

    var before_protected := profile.to_dictionary()
    var protected_result: Dictionary = DESTROY_SERVICE.destroy_normal_item(profile, &"destroy:sigil", InventoryState.TOWER_SIGIL_ID, 1, true)
    _expect(not bool(protected_result.get("accepted", true)) and StringName(protected_result.get("reason_id", &"")) == DESTROY_SERVICE.REASON_PROTECTED_ITEM, "protected quest/key item cannot be destroyed")
    _expect(StringName(protected_result.get("policy_reason_id", &"")) == ProtectedItemOperationPolicy.REASON_PERMANENT_TOWER_SIGIL, "Tower Sigil destroy rejection preserves the permanent-item policy reason")
    _expect(profile.to_dictionary() == before_protected, "protected-item rejection mutates no profile state")

    var starter_weapon_id := &"profile:slot_1:item:starter_sword"
    var equipped_result: Dictionary = DESTROY_SERVICE.destroy_normal_item(profile, &"destroy:equipped", starter_weapon_id, 1, true)
    _expect(not bool(equipped_result.get("accepted", true)) and StringName(equipped_result.get("reason_id", &"")) == DESTROY_SERVICE.REASON_ITEM_NOT_FOUND, "destroy-normal transaction cannot silently destroy equipped ownership")

    var invalid_quantity: Dictionary = DESTROY_SERVICE.destroy_normal_item(profile, &"destroy:bad_quantity", &"item:missing", 0, true)
    _expect(not bool(invalid_quantity.get("accepted", true)) and StringName(invalid_quantity.get("reason_id", &"")) == DESTROY_SERVICE.REASON_INVALID_QUANTITY, "zero destroy quantity is rejected")

    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "all accepted destroy mutations preserve a persistence-valid profile")

    if _failures == 0:
        print("INVENTORY DESTROY TRANSACTION TEST PASS")
    else:
        push_error("INVENTORY DESTROY TRANSACTION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
