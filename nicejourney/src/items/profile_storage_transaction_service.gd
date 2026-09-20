class_name ProfileStorageTransactionService
extends RefCounted

const TRANSFER_SERVICE: Script = preload("res://src/items/storage_transfer_service.gd")
const REASON_INVALID_PROFILE: StringName = &"invalid_profile"
const REASON_STATE_INVALID: StringName = &"state_invalid"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"


static func deposit(
    profile: ProfileSnapshot,
    transaction_id: StringName,
    item_instance_id: StringName,
    quantity: int,
    split_instance_id: StringName = &""
) -> Dictionary:
    return _transfer(profile, true, transaction_id, item_instance_id, quantity, split_instance_id)


static func withdraw(
    profile: ProfileSnapshot,
    transaction_id: StringName,
    item_instance_id: StringName,
    quantity: int,
    split_instance_id: StringName = &""
) -> Dictionary:
    return _transfer(profile, false, transaction_id, item_instance_id, quantity, split_instance_id)


static func _transfer(
    profile: ProfileSnapshot,
    depositing: bool,
    transaction_id: StringName,
    item_instance_id: StringName,
    quantity: int,
    split_instance_id: StringName
) -> Dictionary:
    if profile == null:
        return _result(false, REASON_INVALID_PROFILE)

    var states := _load_states(profile)
    if not bool(states.get("accepted", false)):
        return _result(false, StringName(states.get("reason_id", REASON_STATE_INVALID)))

    var inventory := states["inventory"] as InventoryState
    var storage := states["storage"] as StorageState
    var ledger := states["ledger"] as ClaimLedger
    var transfer: Dictionary
    if depositing:
        transfer = TRANSFER_SERVICE.deposit(
            inventory,
            storage,
            ledger,
            transaction_id,
            item_instance_id,
            quantity,
            split_instance_id
        )
    else:
        transfer = TRANSFER_SERVICE.withdraw(
            inventory,
            storage,
            ledger,
            transaction_id,
            item_instance_id,
            quantity,
            split_instance_id
        )
    if not bool(transfer.get("accepted", false)):
        return transfer.duplicate(true)

    var item_data := inventory.to_dictionary()
    var storage_data := storage.to_dictionary()
    var claim_data := ledger.to_dictionary()
    var candidate := profile.to_dictionary()
    candidate["item_state"] = item_data.duplicate(true)
    candidate["storage_state"] = storage_data.duplicate(true)
    candidate["claimed_transactions"] = claim_data.duplicate(true)
    if not ProfileSnapshot.validate_dictionary(candidate).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    profile.item_state = item_data
    profile.storage_state = storage_data
    profile.claimed_transactions = claim_data
    var result := transfer.duplicate(true)
    result["durable"] = false
    result["durability_boundary"] = &"next_safe_snapshot"
    result["direction"] = &"deposit" if depositing else &"withdraw"
    return result


static func _load_states(profile: ProfileSnapshot) -> Dictionary:
    var inventory := InventoryState.new()
    if not profile.item_state.is_empty() and not inventory.load_dictionary(profile.item_state).is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_INVALID}

    var storage := StorageState.new()
    if not profile.storage_state.is_empty() and not storage.load_dictionary(profile.storage_state).is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_INVALID}

    var ledger := ClaimLedger.new()
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_INVALID}

    return {
        "accepted": true,
        "inventory": inventory,
        "storage": storage,
        "ledger": ledger,
    }


static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {"accepted": accepted, "reason_id": reason_id}
