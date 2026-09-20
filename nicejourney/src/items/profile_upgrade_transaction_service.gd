class_name ProfileUpgradeTransactionService
extends RefCounted

const UPGRADE_SERVICE: Script = preload("res://src/items/upgrade_transaction_service.gd")

const LOCATION_INVENTORY: StringName = &"inventory"
const LOCATION_STORAGE: StringName = &"storage"
const LOCATION_EQUIPMENT: StringName = &"equipment"

const REASON_INVALID_PROFILE: StringName = &"invalid_profile"
const REASON_STATE_INVALID: StringName = &"state_invalid"
const REASON_INVALID_LOCATION: StringName = &"invalid_location"
const REASON_RECIPE_CONTENT_UNAVAILABLE: StringName = &"upgrade_recipe_content_unavailable"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"


static func upgrade(
    profile: ProfileSnapshot,
    location_id: StringName,
    transaction_id: StringName,
    item_instance_id: StringName,
    recipe: UpgradeRecipeDefinition
) -> Dictionary:
    if location_id not in [LOCATION_INVENTORY, LOCATION_STORAGE, LOCATION_EQUIPMENT]:
        return _result(false, REASON_INVALID_LOCATION)
    if recipe == null or not recipe.validate_authored_definition().is_empty():
        var rejected := _result(false, REASON_RECIPE_CONTENT_UNAVAILABLE)
        rejected["recipe_errors"] = PackedStringArray() if recipe == null else recipe.validate_authored_definition().duplicate()
        return rejected
    var states := _load_states(profile)
    if not bool(states.get("accepted", false)):
        return _result(false, StringName(states.get("reason_id", REASON_STATE_INVALID)))
    var inventory := states["inventory"] as InventoryState
    var storage := states["storage"] as StorageState
    var equipment := states["equipment"] as EquipmentState
    var ledger := states["ledger"] as ClaimLedger
    var transaction: Dictionary
    if location_id == LOCATION_INVENTORY:
        transaction = UPGRADE_SERVICE.upgrade_inventory_item(
            inventory,
            ledger,
            transaction_id,
            item_instance_id,
            recipe
        )
    elif location_id == LOCATION_STORAGE:
        transaction = UPGRADE_SERVICE.upgrade_storage_item(
            inventory,
            storage,
            ledger,
            transaction_id,
            item_instance_id,
            recipe
        )
    else:
        transaction = UPGRADE_SERVICE.upgrade_equipped_item(
            inventory,
            equipment,
            ledger,
            transaction_id,
            item_instance_id,
            recipe
        )
    if not bool(transaction.get("accepted", false)):
        return transaction.duplicate(true)

    var item_data := inventory.to_dictionary()
    var storage_data := storage.to_dictionary()
    var equipment_data := equipment.to_dictionary()
    var claim_data := ledger.to_dictionary()
    var candidate := profile.to_dictionary()
    candidate["item_state"] = item_data.duplicate(true)
    candidate["storage_state"] = storage_data.duplicate(true)
    candidate["equipment_state"] = equipment_data.duplicate(true)
    candidate["claimed_transactions"] = claim_data.duplicate(true)
    if not ProfileSnapshot.validate_dictionary(candidate).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    profile.item_state = item_data
    profile.storage_state = storage_data
    profile.equipment_state = equipment_data
    profile.claimed_transactions = claim_data
    var result := transaction.duplicate(true)
    result["location_id"] = location_id
    result["durable"] = false
    result["durability_boundary"] = &"next_safe_snapshot"
    return result


static func _load_states(profile: ProfileSnapshot) -> Dictionary:
    if profile == null:
        return {"accepted": false, "reason_id": REASON_INVALID_PROFILE}
    var inventory := InventoryState.new()
    if not profile.item_state.is_empty() and not inventory.load_dictionary(profile.item_state).is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_INVALID}
    var storage := StorageState.new()
    if not profile.storage_state.is_empty() and not storage.load_dictionary(profile.storage_state).is_empty():
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
        "storage": storage,
        "equipment": equipment,
        "ledger": ledger,
    }


static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "durable": false,
    }
