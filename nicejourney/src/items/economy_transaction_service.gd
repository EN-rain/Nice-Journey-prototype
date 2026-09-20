class_name EconomyTransactionService
extends RefCounted

const REASON_INVALID_INPUT: StringName = &"invalid_input"
const REASON_DUPLICATE_TRANSACTION: StringName = &"duplicate_transaction"
const REASON_ITEM_NOT_STOCKED: StringName = &"item_not_stocked"
const REASON_OUT_OF_STOCK: StringName = &"out_of_stock"
const REASON_NOT_SELLABLE: StringName = &"not_sellable"
const REASON_INSUFFICIENT_GOLD: StringName = &"insufficient_gold"
const REASON_INVENTORY_REJECTED: StringName = &"inventory_rejected"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"


static func buy(
	inventory: InventoryState,
	vendor: VendorStockState,
	ledger: ClaimLedger,
	transaction_id: StringName,
	definition_id: StringName,
	item_instance_id: StringName,
	quantity: int
) -> Dictionary:
	if not _base_inputs_valid(inventory, vendor, ledger, transaction_id, definition_id) or not StableId.is_valid(String(item_instance_id)):
		return _result(false, REASON_INVALID_INPUT)
	if quantity <= 0 or quantity > NormalStackQuantityValidator.MAX_QUANTITY:
		return _result(false, REASON_INVALID_INPUT)
	if ledger.is_claimed(transaction_id):
		return _result(false, REASON_DUPLICATE_TRANSACTION)
	var entry: Dictionary = vendor.get_entry(definition_id)
	if entry.is_empty():
		return _result(false, REASON_ITEM_NOT_STOCKED)
	if int(entry["quantity"]) < quantity:
		return _result(false, REASON_OUT_OF_STOCK)
	if not bool(entry["stackable"]) and quantity != 1:
		return _result(false, REASON_INVALID_INPUT)
	var total_cost: int = _safe_product(int(entry["buy_price"]), quantity)
	if total_cost < 0:
		return _result(false, REASON_INVALID_INPUT)
	if inventory.gold < total_cost:
		return _result(false, REASON_INSUFFICIENT_GOLD)

	var temp_inventory := InventoryState.new()
	var temp_vendor := VendorStockState.new()
	var temp_ledger := ClaimLedger.new()
	if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_vendor.load_dictionary(vendor.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)

	if not temp_inventory.spend_gold(total_cost):
		return _result(false, REASON_INSUFFICIENT_GOLD)
	var add: Dictionary = temp_inventory.try_add_normal(item_instance_id, definition_id, quantity, bool(entry["stackable"]))
	if not bool(add.get("accepted", false)):
		return {
			"accepted": false,
			"reason_id": REASON_INVENTORY_REJECTED,
			"inventory_reason_id": StringName(add.get("reason_id", &"")),
		}
	if not temp_vendor.adjust_quantity(definition_id, -quantity):
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_ledger.try_claim(transaction_id, vendor.vendor_id):
		return _result(false, REASON_DUPLICATE_TRANSACTION)

	if not _commit_clones(inventory, vendor, ledger, temp_inventory, temp_vendor, temp_ledger):
		return _result(false, REASON_COMMIT_FAILED)
	return {
		"accepted": true,
		"reason_id": &"",
		"transaction_id": transaction_id,
		"gold_delta": -total_cost,
		"definition_id": definition_id,
		"quantity": quantity,
	}


static func sell(
	inventory: InventoryState,
	vendor: VendorStockState,
	ledger: ClaimLedger,
	transaction_id: StringName,
	item_instance_id: StringName,
	quantity: int
) -> Dictionary:
	if inventory == null or vendor == null or ledger == null or not StableId.is_valid(String(transaction_id)) or not StableId.is_valid(String(item_instance_id)):
		return _result(false, REASON_INVALID_INPUT)
	if quantity <= 0:
		return _result(false, REASON_INVALID_INPUT)
	if ledger.is_claimed(transaction_id):
		return _result(false, REASON_DUPLICATE_TRANSACTION)
	var owned: Dictionary = inventory.get_normal_slot(item_instance_id)
	if owned.is_empty() or quantity > int(owned["quantity"]):
		return _result(false, REASON_INVALID_INPUT)
	var definition_id := StringName(String(owned["definition_id"]))
	var entry: Dictionary = vendor.get_entry(definition_id)
	if entry.is_empty():
		return _result(false, REASON_ITEM_NOT_STOCKED)
	if int(entry["sell_price"]) <= 0:
		return _result(false, REASON_NOT_SELLABLE)
	var proceeds: int = _safe_product(int(entry["sell_price"]), quantity)
	if proceeds < 0:
		return _result(false, REASON_INVALID_INPUT)

	var temp_inventory := InventoryState.new()
	var temp_vendor := VendorStockState.new()
	var temp_ledger := ClaimLedger.new()
	if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_vendor.load_dictionary(vendor.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)

	if not temp_inventory.try_remove_normal(item_instance_id, quantity).get("accepted", false):
		return _result(false, REASON_INVALID_INPUT)
	if not temp_inventory.add_gold(proceeds):
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_vendor.adjust_quantity(definition_id, quantity):
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_ledger.try_claim(transaction_id, vendor.vendor_id):
		return _result(false, REASON_DUPLICATE_TRANSACTION)

	if not _commit_clones(inventory, vendor, ledger, temp_inventory, temp_vendor, temp_ledger):
		return _result(false, REASON_COMMIT_FAILED)
	return {
		"accepted": true,
		"reason_id": &"",
		"transaction_id": transaction_id,
		"gold_delta": proceeds,
		"definition_id": definition_id,
		"quantity": quantity,
	}


static func _commit_clones(
	inventory: InventoryState,
	vendor: VendorStockState,
	ledger: ClaimLedger,
	temp_inventory: InventoryState,
	temp_vendor: VendorStockState,
	temp_ledger: ClaimLedger
) -> bool:
	var inventory_data: Dictionary = temp_inventory.to_dictionary()
	var vendor_data: Dictionary = temp_vendor.to_dictionary()
	var ledger_data: Dictionary = temp_ledger.to_dictionary()
	if not InventoryState.validate_dictionary(inventory_data).is_empty():
		return false
	if not VendorStockState.validate_dictionary(vendor_data).is_empty():
		return false
	if not ClaimLedger.validate_dictionary(ledger_data).is_empty():
		return false
	if not inventory.load_dictionary(inventory_data).is_empty():
		return false
	if not vendor.load_dictionary(vendor_data).is_empty():
		return false
	if not ledger.load_dictionary(ledger_data).is_empty():
		return false
	return true


static func _base_inputs_valid(
	inventory: InventoryState,
	vendor: VendorStockState,
	ledger: ClaimLedger,
	transaction_id: StringName,
	definition_id: StringName
) -> bool:
	return (
		inventory != null
		and vendor != null
		and ledger != null
		and StableId.is_valid(String(transaction_id))
		and StableId.is_valid(String(definition_id))
	)


static func _safe_product(left: int, right: int) -> int:
	if left < 0 or right < 0:
		return -1
	var product: int = left * right
	if right != 0 and product / right != left:
		return -1
	return product


static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
	return {"accepted": accepted, "reason_id": reason_id}
