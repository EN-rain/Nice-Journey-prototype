class_name InventoryDestroyTransactionService
extends RefCounted

const SOURCE_PREFIX: String = "inventory_destroy:"
const REASON_INVALID_INPUT: StringName = &"invalid_input"
const REASON_CONFIRMATION_REQUIRED: StringName = &"confirmation_required"
const REASON_DUPLICATE_TRANSACTION: StringName = &"duplicate_transaction"
const REASON_ITEM_NOT_FOUND: StringName = &"item_not_found"
const REASON_PROTECTED_ITEM: StringName = &"protected_item"
const REASON_INVALID_QUANTITY: StringName = &"invalid_quantity"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"


static func destroy_normal_item(
    profile: ProfileSnapshot,
    transaction_id: StringName,
    item_instance_id: StringName,
    quantity: int,
    confirmed: bool
) -> Dictionary:
    if profile == null or not StableId.is_valid(String(transaction_id)) or not StableId.is_valid(String(item_instance_id)):
        return _result(false, REASON_INVALID_INPUT)
    if quantity <= 0:
        return _result(false, REASON_INVALID_QUANTITY)
    if not confirmed:
        return _result(false, REASON_CONFIRMATION_REQUIRED)

    var inventory := InventoryState.new()
    if profile.item_state.is_empty():
        if _is_protected_profile_item(profile, item_instance_id):
            return _result(false, REASON_PROTECTED_ITEM)
        return _result(false, REASON_ITEM_NOT_FOUND)
    if not inventory.load_dictionary(profile.item_state).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if inventory.protected_items.has(String(item_instance_id)):
        var protection := inventory.protected_items[String(item_instance_id)] as Dictionary
        var policy: Dictionary = ProtectedItemOperationPolicy.evaluate(ProtectedItemOperationPolicy.OP_DESTROY, protection)
        if not bool(policy.get("allowed", false)):
            return {
                "accepted": false,
                "reason_id": REASON_PROTECTED_ITEM,
                "policy_reason_id": StringName(policy.get("reason_id", &"")),
            }
        return _result(false, REASON_ITEM_NOT_FOUND)

    var ledger := ClaimLedger.new()
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if ledger.is_claimed(transaction_id):
        return _result(false, REASON_DUPLICATE_TRANSACTION)

    var existing: Dictionary = inventory.get_normal_slot(item_instance_id)
    if existing.is_empty():
        return _result(false, REASON_ITEM_NOT_FOUND)
    if quantity > int(existing.get("quantity", 0)):
        return _result(false, REASON_INVALID_QUANTITY)

    var temp_inventory := InventoryState.new()
    var temp_ledger := ClaimLedger.new()
    if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    var removed: Dictionary = temp_inventory.try_remove_normal(item_instance_id, quantity)
    if not bool(removed.get("accepted", false)):
        return _result(false, REASON_COMMIT_FAILED)
    var source_id := StringName("%s%s" % [SOURCE_PREFIX, String(item_instance_id)])
    if not temp_ledger.try_claim(transaction_id, source_id):
        return _result(false, REASON_DUPLICATE_TRANSACTION)

    var item_data: Dictionary = temp_inventory.to_dictionary()
    var claim_data: Dictionary = temp_ledger.to_dictionary()
    if not InventoryState.validate_dictionary(item_data).is_empty() or not ClaimLedger.validate_dictionary(claim_data).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    var candidate: Dictionary = profile.to_dictionary()
    candidate["item_state"] = item_data.duplicate(true)
    candidate["claimed_transactions"] = claim_data.duplicate(true)
    if not ProfileSnapshot.validate_dictionary(candidate).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    var remaining_item: Dictionary = temp_inventory.get_normal_slot(item_instance_id)
    profile.item_state = item_data
    profile.claimed_transactions = claim_data
    return {
        "accepted": true,
        "reason_id": &"",
        "transaction_id": transaction_id,
        "item_instance_id": item_instance_id,
        "definition_id": StringName(removed.get("definition_id", &"")),
        "quantity": quantity,
        "stackable": bool(removed.get("stackable", false)),
        "remaining_quantity": int(remaining_item.get("quantity", 0)),
    }


static func _is_protected_profile_item(profile: ProfileSnapshot, item_id: StringName) -> bool:
    if profile.item_state.is_empty():
        return false
    var raw_protected: Variant = profile.item_state.get("protected_items", {})
    return raw_protected is Dictionary and (raw_protected as Dictionary).has(String(item_id))


static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {"accepted": accepted, "reason_id": reason_id}
