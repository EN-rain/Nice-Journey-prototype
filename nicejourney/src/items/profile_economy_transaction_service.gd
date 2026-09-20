class_name ProfileEconomyTransactionService
extends RefCounted

const ECONOMY_SERVICE: Script = preload("res://src/items/economy_transaction_service.gd")

const REASON_INVALID_PROFILE: StringName = &"invalid_profile"
const REASON_STATE_INVALID: StringName = &"state_invalid"
const REASON_VENDOR_NOT_FOUND: StringName = &"vendor_not_found"
const REASON_CONTENT_UNAVAILABLE: StringName = &"content_unavailable"
const REASON_VENDOR_ALREADY_INITIALIZED: StringName = &"vendor_already_initialized"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"


static func buy(
    profile: ProfileSnapshot,
    vendor_id: StringName,
    transaction_id: StringName,
    definition_id: StringName,
    item_instance_id: StringName,
    quantity: int
) -> Dictionary:
    return _transact(profile, true, vendor_id, transaction_id, definition_id, item_instance_id, quantity)


static func sell(
    profile: ProfileSnapshot,
    vendor_id: StringName,
    transaction_id: StringName,
    item_instance_id: StringName,
    quantity: int
) -> Dictionary:
    return _transact(profile, false, vendor_id, transaction_id, &"", item_instance_id, quantity)


static func initialize_vendor_from_catalog(
    profile: ProfileSnapshot,
    catalog: VendorStockCatalog,
    vendor_id: StringName
) -> Dictionary:
    if profile == null or catalog == null or not StableId.is_valid(String(vendor_id)):
        return _result(false, REASON_INVALID_PROFILE)
    var definition: VendorStockDefinition = catalog.get_definition(vendor_id)
    if definition == null:
        var unavailable := _result(false, REASON_CONTENT_UNAVAILABLE)
        unavailable["vendor_id"] = vendor_id
        if vendor_id == VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID:
            unavailable["readiness"] = catalog.general_merchant_readiness()
        return unavailable

    var economy := EconomyState.new()
    if not profile.economy_state.is_empty() and not economy.load_dictionary(profile.economy_state).is_empty():
        return _result(false, REASON_STATE_INVALID)
    if economy.get_vendor(vendor_id) != null:
        return _result(false, REASON_VENDOR_ALREADY_INITIALIZED)
    if not economy.initialize_vendor_once(definition):
        return _result(false, REASON_COMMIT_FAILED)

    var economy_data: Dictionary = economy.to_dictionary()
    var candidate: Dictionary = profile.to_dictionary()
    candidate["economy_state"] = economy_data.duplicate(true)
    if not ProfileSnapshot.validate_dictionary(candidate).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    profile.economy_state = economy_data
    return {
        "accepted": true,
        "reason_id": &"",
        "vendor_id": vendor_id,
        "durable": false,
        "durability_boundary": &"next_safe_snapshot",
    }


static func _transact(
    profile: ProfileSnapshot,
    buying: bool,
    vendor_id: StringName,
    transaction_id: StringName,
    definition_id: StringName,
    item_instance_id: StringName,
    quantity: int
) -> Dictionary:
    var states := _load_states(profile, vendor_id)
    if not bool(states.get("accepted", false)):
        return _result(false, StringName(states.get("reason_id", REASON_STATE_INVALID)))
    var inventory := states["inventory"] as InventoryState
    var economy := states["economy"] as EconomyState
    var vendor := states["vendor"] as VendorStockState
    var ledger := states["ledger"] as ClaimLedger
    var transaction: Dictionary
    if buying:
        transaction = ECONOMY_SERVICE.buy(
            inventory,
            vendor,
            ledger,
            transaction_id,
            definition_id,
            item_instance_id,
            quantity
        )
    else:
        transaction = ECONOMY_SERVICE.sell(
            inventory,
            vendor,
            ledger,
            transaction_id,
            item_instance_id,
            quantity
        )
    if not bool(transaction.get("accepted", false)):
        return transaction.duplicate(true)
    if not economy.set_vendor(vendor):
        return _result(false, REASON_COMMIT_FAILED)

    var item_data := inventory.to_dictionary()
    var economy_data := economy.to_dictionary()
    var claim_data := ledger.to_dictionary()
    var candidate := profile.to_dictionary()
    candidate["item_state"] = item_data.duplicate(true)
    candidate["economy_state"] = economy_data.duplicate(true)
    candidate["claimed_transactions"] = claim_data.duplicate(true)
    if not ProfileSnapshot.validate_dictionary(candidate).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    profile.item_state = item_data
    profile.economy_state = economy_data
    profile.claimed_transactions = claim_data
    var result := transaction.duplicate(true)
    result["vendor_id"] = vendor_id
    result["direction"] = &"buy" if buying else &"sell"
    result["durable"] = false
    result["durability_boundary"] = &"next_safe_snapshot"
    return result


static func _load_states(profile: ProfileSnapshot, vendor_id: StringName) -> Dictionary:
    if profile == null or not StableId.is_valid(String(vendor_id)):
        return {"accepted": false, "reason_id": REASON_INVALID_PROFILE}
    var inventory := InventoryState.new()
    if not profile.item_state.is_empty() and not inventory.load_dictionary(profile.item_state).is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_INVALID}
    var economy := EconomyState.new()
    if profile.economy_state.is_empty():
        return {"accepted": false, "reason_id": REASON_VENDOR_NOT_FOUND}
    if not economy.load_dictionary(profile.economy_state).is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_INVALID}
    var vendor := economy.get_vendor(vendor_id)
    if vendor == null:
        return {"accepted": false, "reason_id": REASON_VENDOR_NOT_FOUND}
    var ledger := ClaimLedger.new()
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_INVALID}
    return {
        "accepted": true,
        "inventory": inventory,
        "economy": economy,
        "vendor": vendor,
        "ledger": ledger,
    }


static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "durable": false,
    }
