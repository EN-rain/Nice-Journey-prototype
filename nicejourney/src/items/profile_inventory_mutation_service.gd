class_name ProfileInventoryMutationService
extends RefCounted

const EQUIPMENT_SERVICE: Script = preload("res://src/items/equipment_transaction_service.gd")
const QUICK_SOURCE_ID: StringName = &"inventory:quick_slot"

const REASON_INVALID_PROFILE: StringName = &"invalid_profile"
const REASON_STATE_INVALID: StringName = &"state_invalid"
const REASON_INVALID_INPUT: StringName = &"invalid_input"
const REASON_DUPLICATE_TRANSACTION: StringName = &"duplicate_transaction"
const REASON_ITEM_NOT_FOUND: StringName = &"item_not_found"
const REASON_CATEGORY_AUTHORITY_MISSING: StringName = &"quick_slot_category_authority_missing"
const REASON_CATEGORY_AUTHORITY_INVALID: StringName = &"quick_slot_category_authority_invalid"
const REASON_ITEM_CATEGORY_UNAUTHORED: StringName = &"quick_slot_item_category_unauthored"
const REASON_ITEM_NOT_CONSUMABLE: StringName = &"quick_slot_requires_consumable"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"


static func equip(
    profile: ProfileSnapshot,
    catalog: EquipmentItemCatalog,
    transaction_id: StringName,
    item_instance_id: StringName,
    target_slot_id: StringName
) -> Dictionary:
    var states := _load_states(profile)
    if not bool(states.get("accepted", false)):
        return _result(false, StringName(states.get("reason_id", REASON_STATE_INVALID)))
    var transaction: Dictionary = EQUIPMENT_SERVICE.equip_from_inventory(
        states["inventory"] as InventoryState,
        states["equipment"] as EquipmentState,
        catalog,
        states["ledger"] as ClaimLedger,
        transaction_id,
        item_instance_id,
        target_slot_id,
        StringName(profile.class_id)
    )
    return _commit_if_accepted(profile, states, transaction)


static func unequip(
    profile: ProfileSnapshot,
    transaction_id: StringName,
    slot_id: StringName
) -> Dictionary:
    var states := _load_states(profile)
    if not bool(states.get("accepted", false)):
        return _result(false, StringName(states.get("reason_id", REASON_STATE_INVALID)))
    var transaction: Dictionary = EQUIPMENT_SERVICE.unequip_to_inventory(
        states["inventory"] as InventoryState,
        states["equipment"] as EquipmentState,
        states["ledger"] as ClaimLedger,
        transaction_id,
        slot_id
    )
    return _commit_if_accepted(profile, states, transaction)


static func bind_quick_slot(
    profile: ProfileSnapshot,
    transaction_id: StringName,
    slot_index: int,
    item_instance_id: StringName,
    category_catalog: ItemCategoryCatalog = null
) -> Dictionary:
    if (
        profile == null
        or not StableId.is_valid(String(transaction_id))
        or slot_index < 0
        or slot_index >= InventoryState.QUICK_SLOT_COUNT
        or (item_instance_id != &"" and not StableId.is_valid(String(item_instance_id)))
    ):
        return _result(false, REASON_INVALID_INPUT)
    var states := _load_states(profile)
    if not bool(states.get("accepted", false)):
        return _result(false, StringName(states.get("reason_id", REASON_STATE_INVALID)))
    var inventory := states["inventory"] as InventoryState
    var ledger := states["ledger"] as ClaimLedger
    if ledger.is_claimed(transaction_id):
        return _result(false, REASON_DUPLICATE_TRANSACTION)
    if item_instance_id != &"":
        var owned := inventory.get_normal_slot(item_instance_id)
        if owned.is_empty():
            return _result(false, REASON_ITEM_NOT_FOUND)
        if category_catalog == null:
            return _result(false, REASON_CATEGORY_AUTHORITY_MISSING)
        if not category_catalog.validate_catalog().is_empty():
            return _result(false, REASON_CATEGORY_AUTHORITY_INVALID)
        var definition_id := StringName(String(owned.get("definition_id", &"")))
        var category := category_catalog.category_for(definition_id)
        if category == &"":
            return _result(false, REASON_ITEM_CATEGORY_UNAUTHORED)
        if category != ItemCategoryCatalog.CATEGORY_CONSUMABLE:
            return _result(false, REASON_ITEM_NOT_CONSUMABLE)
    if not inventory.bind_quick_slot(slot_index, item_instance_id):
        return _result(false, REASON_ITEM_NOT_FOUND)
    if not ledger.try_claim(transaction_id, QUICK_SOURCE_ID):
        return _result(false, REASON_DUPLICATE_TRANSACTION)
    var transaction := {
        "accepted": true,
        "reason_id": &"",
        "transaction_id": transaction_id,
        "slot_index": slot_index,
        "item_instance_id": item_instance_id,
        "reference_only": true,
        "consumable_category_validated": item_instance_id == &"" or category_catalog != null,
    }
    return _commit_if_accepted(profile, states, transaction)


static func _load_states(profile: ProfileSnapshot) -> Dictionary:
    if profile == null:
        return {"accepted": false, "reason_id": REASON_INVALID_PROFILE}
    var inventory := InventoryState.new()
    if not profile.item_state.is_empty() and not inventory.load_dictionary(profile.item_state).is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_INVALID}
    var equipment := EquipmentState.new()
    if not profile.equipment_state.is_empty() and not equipment.load_dictionary(profile.equipment_state).is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_INVALID}
    var ledger := ClaimLedger.new()
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_INVALID}
    return {
        "accepted": true,
        "inventory": inventory,
        "equipment": equipment,
        "ledger": ledger,
    }


static func _commit_if_accepted(profile: ProfileSnapshot, states: Dictionary, transaction: Dictionary) -> Dictionary:
    if not bool(transaction.get("accepted", false)):
        return transaction.duplicate(true)
    var item_data := (states["inventory"] as InventoryState).to_dictionary()
    var equipment_data := (states["equipment"] as EquipmentState).to_dictionary()
    var claim_data := (states["ledger"] as ClaimLedger).to_dictionary()
    var candidate := profile.to_dictionary()
    candidate["item_state"] = item_data.duplicate(true)
    candidate["equipment_state"] = equipment_data.duplicate(true)
    candidate["claimed_transactions"] = claim_data.duplicate(true)
    if not ProfileSnapshot.validate_dictionary(candidate).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    profile.item_state = item_data
    profile.equipment_state = equipment_data
    profile.claimed_transactions = claim_data
    var result := transaction.duplicate(true)
    result["durable"] = false
    result["durability_boundary"] = &"next_safe_snapshot"
    return result


static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "durable": false,
    }
