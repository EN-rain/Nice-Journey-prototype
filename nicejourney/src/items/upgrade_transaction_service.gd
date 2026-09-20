class_name UpgradeTransactionService
extends RefCounted

const SOURCE_ID: StringName = &"region3:blacksmith"
const REASON_INVALID_INPUT: StringName = &"invalid_input"
const REASON_DUPLICATE_TRANSACTION: StringName = &"duplicate_transaction"
const REASON_ITEM_NOT_FOUND: StringName = &"item_not_found"
const REASON_RECIPE_INCOMPATIBLE: StringName = &"recipe_incompatible"
const REASON_INSUFFICIENT_GOLD: StringName = &"insufficient_gold"
const REASON_INSUFFICIENT_MATERIALS: StringName = &"insufficient_materials"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"

static func upgrade_inventory_item(
	inventory: InventoryState,
	ledger: ClaimLedger,
	transaction_id: StringName,
	item_instance_id: StringName,
	recipe: UpgradeRecipeDefinition
) -> Dictionary:
	if not _base_inputs_valid(inventory, ledger, transaction_id, item_instance_id, recipe):
		return _result(false, REASON_INVALID_INPUT)
	if ledger.is_claimed(transaction_id):
		return _result(false, REASON_DUPLICATE_TRANSACTION)
	var owned := inventory.get_normal_slot(item_instance_id)
	if owned.is_empty() or bool(owned.get("stackable", true)):
		return _result(false, REASON_ITEM_NOT_FOUND)
	var compatibility := _validate_recipe_for_slot(recipe, owned)
	if compatibility != &"":
		return _result(false, compatibility)
	var affordability := _validate_costs(inventory, recipe, StringName(String(owned["definition_id"])))
	if affordability != &"":
		return _result(false, affordability)

	var temp_inventory := InventoryState.new()
	var temp_ledger := ClaimLedger.new()
	if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty() or not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)
	if not _apply_costs(temp_inventory, recipe):
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_inventory.set_upgrade_rank(item_instance_id, recipe.result_rank):
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_ledger.try_claim(transaction_id, SOURCE_ID):
		return _result(false, REASON_DUPLICATE_TRANSACTION)
	if not _commit_inventory(inventory, ledger, temp_inventory, temp_ledger):
		return _result(false, REASON_COMMIT_FAILED)
	return _success(transaction_id, item_instance_id, recipe)

static func upgrade_storage_item(
	inventory: InventoryState,
	storage: StorageState,
	ledger: ClaimLedger,
	transaction_id: StringName,
	item_instance_id: StringName,
	recipe: UpgradeRecipeDefinition
) -> Dictionary:
	if storage == null or not _base_inputs_valid(inventory, ledger, transaction_id, item_instance_id, recipe):
		return _result(false, REASON_INVALID_INPUT)
	if ledger.is_claimed(transaction_id):
		return _result(false, REASON_DUPLICATE_TRANSACTION)
	var owned := storage.get_normal_slot(item_instance_id)
	if owned.is_empty() or bool(owned.get("stackable", true)):
		return _result(false, REASON_ITEM_NOT_FOUND)
	var compatibility := _validate_recipe_for_slot(recipe, owned)
	if compatibility != &"":
		return _result(false, compatibility)
	var affordability := _validate_costs(inventory, recipe, StringName(String(owned["definition_id"])))
	if affordability != &"":
		return _result(false, affordability)

	var temp_inventory := InventoryState.new()
	var temp_storage := StorageState.new()
	var temp_ledger := ClaimLedger.new()
	if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_storage.load_dictionary(storage.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)
	if not _apply_costs(temp_inventory, recipe):
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_storage.set_upgrade_rank(item_instance_id, recipe.result_rank):
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_ledger.try_claim(transaction_id, SOURCE_ID):
		return _result(false, REASON_DUPLICATE_TRANSACTION)
	if not _commit_storage(inventory, storage, ledger, temp_inventory, temp_storage, temp_ledger):
		return _result(false, REASON_COMMIT_FAILED)
	return _success(transaction_id, item_instance_id, recipe)


static func upgrade_equipped_item(
	inventory: InventoryState,
	equipment: EquipmentState,
	ledger: ClaimLedger,
	transaction_id: StringName,
	item_instance_id: StringName,
	recipe: UpgradeRecipeDefinition
) -> Dictionary:
	if equipment == null or not _base_inputs_valid(inventory, ledger, transaction_id, item_instance_id, recipe):
		return _result(false, REASON_INVALID_INPUT)
	if ledger.is_claimed(transaction_id):
		return _result(false, REASON_DUPLICATE_TRANSACTION)
	var slot_id := equipment.find_item_slot(item_instance_id)
	if slot_id == &"":
		return _result(false, REASON_ITEM_NOT_FOUND)
	var owned := equipment.get_item(slot_id)
	if owned.is_empty() or bool(owned.get("stackable", true)):
		return _result(false, REASON_ITEM_NOT_FOUND)
	var compatibility := _validate_recipe_for_slot(recipe, owned)
	if compatibility != &"":
		return _result(false, compatibility)
	var affordability := _validate_costs(inventory, recipe, StringName(String(owned["definition_id"])))
	if affordability != &"":
		return _result(false, affordability)

	var temp_inventory := InventoryState.new()
	var temp_equipment := EquipmentState.new()
	var temp_ledger := ClaimLedger.new()
	if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_equipment.load_dictionary(equipment.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
		return _result(false, REASON_COMMIT_FAILED)
	if not _apply_costs(temp_inventory, recipe):
		return _result(false, REASON_COMMIT_FAILED)
	var upgraded := temp_equipment.get_item(slot_id)
	upgraded["upgrade_rank"] = recipe.result_rank
	if not temp_equipment.set_item(slot_id, upgraded):
		return _result(false, REASON_COMMIT_FAILED)
	if not temp_ledger.try_claim(transaction_id, SOURCE_ID):
		return _result(false, REASON_DUPLICATE_TRANSACTION)
	if not _commit_equipment(inventory, equipment, ledger, temp_inventory, temp_equipment, temp_ledger):
		return _result(false, REASON_COMMIT_FAILED)
	var result := _success(transaction_id, item_instance_id, recipe)
	result["slot_id"] = slot_id
	return result

static func _base_inputs_valid(
	inventory: InventoryState,
	ledger: ClaimLedger,
	transaction_id: StringName,
	item_instance_id: StringName,
	recipe: UpgradeRecipeDefinition
) -> bool:
	return (
		inventory != null
		and ledger != null
		and recipe != null
		and recipe.validate_authored_definition().is_empty()
		and StableId.is_valid(String(transaction_id))
		and StableId.is_valid(String(item_instance_id))
	)

static func _validate_recipe_for_slot(recipe: UpgradeRecipeDefinition, slot: Dictionary) -> StringName:
	var definition_id := StringName(String(slot.get("definition_id", "")))
	var rarity := StringName(String(slot.get("rarity", "common")))
	var rank := int(slot.get("upgrade_rank", 0))
	if rank >= recipe.maximum_rank or not recipe.is_compatible(definition_id, rarity, rank):
		return REASON_RECIPE_INCOMPATIBLE
	return &""

static func _validate_costs(inventory: InventoryState, recipe: UpgradeRecipeDefinition, target_definition_id: StringName) -> StringName:
	if inventory.gold < recipe.gold_cost:
		return REASON_INSUFFICIENT_GOLD
	for raw_material_id: Variant in recipe.material_costs.keys():
		var material_id := StringName(String(raw_material_id))
		if material_id == target_definition_id:
			return REASON_RECIPE_INCOMPATIBLE
		if inventory.get_total_quantity(material_id) < int(recipe.material_costs[raw_material_id]):
			return REASON_INSUFFICIENT_MATERIALS
	return &""

static func _apply_costs(inventory: InventoryState, recipe: UpgradeRecipeDefinition) -> bool:
	if not inventory.spend_gold(recipe.gold_cost):
		return false
	var material_ids: Array[String] = []
	for raw_material_id: Variant in recipe.material_costs.keys():
		material_ids.append(String(raw_material_id))
	material_ids.sort()
	for material_text: String in material_ids:
		var material_id := StringName(material_text)
		if not bool(inventory.try_remove_definition_quantity(material_id, int(recipe.material_costs[material_text])).get("accepted", false)):
			return false
	return true

static func _commit_inventory(inventory: InventoryState, ledger: ClaimLedger, temp_inventory: InventoryState, temp_ledger: ClaimLedger) -> bool:
	var inventory_data := temp_inventory.to_dictionary()
	var ledger_data := temp_ledger.to_dictionary()
	if not InventoryState.validate_dictionary(inventory_data).is_empty() or not ClaimLedger.validate_dictionary(ledger_data).is_empty():
		return false
	return inventory.load_dictionary(inventory_data).is_empty() and ledger.load_dictionary(ledger_data).is_empty()

static func _commit_storage(
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
	return (
		inventory.load_dictionary(inventory_data).is_empty()
		and storage.load_dictionary(storage_data).is_empty()
		and ledger.load_dictionary(ledger_data).is_empty()
	)


static func _commit_equipment(
	inventory: InventoryState,
	equipment: EquipmentState,
	ledger: ClaimLedger,
	temp_inventory: InventoryState,
	temp_equipment: EquipmentState,
	temp_ledger: ClaimLedger
) -> bool:
	var inventory_data := temp_inventory.to_dictionary()
	var equipment_data := temp_equipment.to_dictionary()
	var ledger_data := temp_ledger.to_dictionary()
	if not InventoryState.validate_dictionary(inventory_data).is_empty():
		return false
	if not EquipmentState.validate_dictionary(equipment_data).is_empty():
		return false
	if not ClaimLedger.validate_dictionary(ledger_data).is_empty():
		return false
	return (
		inventory.load_dictionary(inventory_data).is_empty()
		and equipment.load_dictionary(equipment_data).is_empty()
		and ledger.load_dictionary(ledger_data).is_empty()
	)

static func _success(transaction_id: StringName, item_instance_id: StringName, recipe: UpgradeRecipeDefinition) -> Dictionary:
	return {
		"accepted": true,
		"reason_id": &"",
		"transaction_id": transaction_id,
		"item_instance_id": item_instance_id,
		"before_rank": recipe.source_rank,
		"after_rank": recipe.result_rank,
		"gold_cost": recipe.gold_cost,
		"material_costs": recipe.material_costs.duplicate(true),
		"stat_changes": recipe.stat_changes.duplicate(true),
	}

static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
	return {"accepted": accepted, "reason_id": reason_id}
