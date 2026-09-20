class_name StorageTransferService
extends RefCounted

const SOURCE_ID: StringName = &"region3:storage_house"
const REASON_INVALID_INPUT: StringName = &"invalid_input"
const REASON_DUPLICATE_TRANSACTION: StringName = &"duplicate_transaction"
const REASON_ITEM_NOT_FOUND: StringName = &"item_not_found"
const REASON_DESTINATION_REJECTED: StringName = &"destination_rejected"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"

static func deposit(
    inventory: InventoryState,
    storage: StorageState,
    ledger: ClaimLedger,
    transaction_id: StringName,
    item_instance_id: StringName,
    quantity: int,
    split_instance_id: StringName = &""
) -> Dictionary:
    return _transfer_inventory_to_storage(inventory, storage, ledger, transaction_id, item_instance_id, quantity, split_instance_id)

static func withdraw(
    inventory: InventoryState,
    storage: StorageState,
    ledger: ClaimLedger,
    transaction_id: StringName,
    item_instance_id: StringName,
    quantity: int,
    split_instance_id: StringName = &""
) -> Dictionary:
    if not _base_inputs_valid(inventory, storage, ledger, transaction_id, item_instance_id, quantity):
        return _result(false, REASON_INVALID_INPUT)
    if ledger.is_claimed(transaction_id):
        return _result(false, REASON_DUPLICATE_TRANSACTION)
    var owned := storage.get_normal_slot(item_instance_id)
    if owned.is_empty() or quantity > int(owned["quantity"]):
        return _result(false, REASON_ITEM_NOT_FOUND)
    var destination_id := _destination_instance_id(item_instance_id, int(owned["quantity"]), quantity, split_instance_id)
    if destination_id == &"":
        return _result(false, REASON_INVALID_INPUT)

    var temp_inventory := InventoryState.new()
    var temp_storage := StorageState.new()
    var temp_ledger := ClaimLedger.new()
    if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_storage.load_dictionary(storage.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    var removed := temp_storage.try_remove_normal(item_instance_id, quantity)
    if not bool(removed.get("accepted", false)):
        return _result(false, REASON_ITEM_NOT_FOUND)
    var add := temp_inventory.try_add_normal(destination_id, StringName(String(owned["definition_id"])), quantity, bool(owned["stackable"]), _slot_metadata(owned))
    if not bool(add.get("accepted", false)):
        return {
            "accepted": false,
            "reason_id": REASON_DESTINATION_REJECTED,
            "destination_reason_id": StringName(add.get("reason_id", &"")),
        }
    if not temp_ledger.try_claim(transaction_id, SOURCE_ID):
        return _result(false, REASON_DUPLICATE_TRANSACTION)
    if not _commit(inventory, storage, ledger, temp_inventory, temp_storage, temp_ledger):
        return _result(false, REASON_COMMIT_FAILED)
    return _success(transaction_id, item_instance_id, destination_id, quantity)

static func _transfer_inventory_to_storage(
    inventory: InventoryState,
    storage: StorageState,
    ledger: ClaimLedger,
    transaction_id: StringName,
    item_instance_id: StringName,
    quantity: int,
    split_instance_id: StringName
) -> Dictionary:
    if not _base_inputs_valid(inventory, storage, ledger, transaction_id, item_instance_id, quantity):
        return _result(false, REASON_INVALID_INPUT)
    if ledger.is_claimed(transaction_id):
        return _result(false, REASON_DUPLICATE_TRANSACTION)
    var owned := inventory.get_normal_slot(item_instance_id)
    if owned.is_empty() or quantity > int(owned["quantity"]):
        return _result(false, REASON_ITEM_NOT_FOUND)
    var destination_id := _destination_instance_id(item_instance_id, int(owned["quantity"]), quantity, split_instance_id)
    if destination_id == &"":
        return _result(false, REASON_INVALID_INPUT)

    var temp_inventory := InventoryState.new()
    var temp_storage := StorageState.new()
    var temp_ledger := ClaimLedger.new()
    if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_storage.load_dictionary(storage.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    var removed := temp_inventory.try_remove_normal(item_instance_id, quantity)
    if not bool(removed.get("accepted", false)):
        return _result(false, REASON_ITEM_NOT_FOUND)
    var add := temp_storage.try_add_normal(destination_id, StringName(String(owned["definition_id"])), quantity, bool(owned["stackable"]), _slot_metadata(owned))
    if not bool(add.get("accepted", false)):
        return {
            "accepted": false,
            "reason_id": REASON_DESTINATION_REJECTED,
            "destination_reason_id": StringName(add.get("reason_id", &"")),
        }
    if not temp_ledger.try_claim(transaction_id, SOURCE_ID):
        return _result(false, REASON_DUPLICATE_TRANSACTION)
    if not _commit(inventory, storage, ledger, temp_inventory, temp_storage, temp_ledger):
        return _result(false, REASON_COMMIT_FAILED)
    return _success(transaction_id, item_instance_id, destination_id, quantity)

static func _destination_instance_id(source_id: StringName, source_quantity: int, moved_quantity: int, split_instance_id: StringName) -> StringName:
    if moved_quantity == source_quantity:
        return source_id
    if split_instance_id == &"" or split_instance_id == source_id or not StableId.is_valid(String(split_instance_id)):
        return &""
    return split_instance_id

static func _base_inputs_valid(
    inventory: InventoryState,
    storage: StorageState,
    ledger: ClaimLedger,
    transaction_id: StringName,
    item_instance_id: StringName,
    quantity: int
) -> bool:
    return (
        inventory != null
        and storage != null
        and ledger != null
        and StableId.is_valid(String(transaction_id))
        and StableId.is_valid(String(item_instance_id))
        and quantity > 0
        and quantity <= NormalStackQuantityValidator.MAX_QUANTITY
    )

static func _commit(
    inventory: InventoryState,
    storage: StorageState,
    ledger: ClaimLedger,
    temp_inventory: InventoryState,
    temp_storage: StorageState,
    temp_ledger: ClaimLedger
) -> bool:
    var inventory_data := temp_inventory.to_dictionary()
    var storage_data := temp_storage.to_dictionary()
    var ledger_data := temp_ledger.to_dictionary()
    if not InventoryState.validate_dictionary(inventory_data).is_empty():
        return false
    if not StorageState.validate_dictionary(storage_data).is_empty():
        return false
    if not ClaimLedger.validate_dictionary(ledger_data).is_empty():
        return false
    if not inventory.load_dictionary(inventory_data).is_empty():
        return false
    if not storage.load_dictionary(storage_data).is_empty():
        return false
    if not ledger.load_dictionary(ledger_data).is_empty():
        return false
    return true

static func _slot_metadata(slot: Dictionary) -> Dictionary:
    var metadata := {}
    for key: String in ["rarity", "affixes", "upgrade_rank", "source_claim_id"]:
        if slot.has(key):
            metadata[key] = slot[key] if key != "affixes" else (slot[key] as Array).duplicate(true)
    return metadata

static func _success(transaction_id: StringName, source_id: StringName, destination_id: StringName, quantity: int) -> Dictionary:
    return {
        "accepted": true,
        "reason_id": &"",
        "transaction_id": transaction_id,
        "source_item_instance_id": source_id,
        "requested_destination_item_instance_id": destination_id,
        "quantity": quantity,
    }

static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {"accepted": accepted, "reason_id": reason_id}
