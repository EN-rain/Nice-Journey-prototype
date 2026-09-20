class_name StorageState
extends RefCounted

const DEFAULT_CAPACITY: int = 64

const REASON_INVALID_ITEM: StringName = &"invalid_item"
const REASON_DUPLICATE_ITEM_INSTANCE: StringName = &"duplicate_item_instance"
const REASON_STORAGE_FULL: StringName = &"storage_full"
const REASON_ITEM_NOT_FOUND: StringName = &"item_not_found"
const REASON_INVALID_QUANTITY: StringName = &"invalid_quantity"

var capacity: int = DEFAULT_CAPACITY
var normal_slots: Array[Dictionary] = []

func try_add_normal(item_instance_id: StringName, definition_id: StringName, quantity: int, stackable: bool, metadata: Dictionary = {}) -> Dictionary:
	var preview := preview_add_normal(item_instance_id, definition_id, quantity, stackable, metadata)
	if not bool(preview.get("accepted", false)):
		return preview
	normal_slots = _copy_slots(preview["normal_slots"] as Array)
	return preview

func preview_add_normal(item_instance_id: StringName, definition_id: StringName, quantity: int, stackable: bool, metadata: Dictionary = {}) -> Dictionary:
	if not StableId.is_valid(String(item_instance_id)) or not StableId.is_valid(String(definition_id)):
		return _result(false, REASON_INVALID_ITEM)
	if not NormalStackQuantityValidator.is_valid(quantity):
		return _result(false, REASON_INVALID_QUANTITY)
	if not stackable and quantity != 1:
		return _result(false, REASON_INVALID_QUANTITY)
	if not InventoryState._validate_metadata(metadata).is_empty():
		return _result(false, REASON_INVALID_ITEM)
	if _normal_index(item_instance_id) >= 0:
		return _result(false, REASON_DUPLICATE_ITEM_INSTANCE)

	var candidate := _copy_slots(normal_slots)
	var remaining := quantity
	if stackable:
		for index: int in range(candidate.size()):
			var slot: Dictionary = candidate[index]
			if not bool(slot["stackable"]) or StringName(String(slot["definition_id"])) != definition_id or not InventoryState._stack_metadata_compatible(slot, metadata):
				continue
			var room := NormalStackQuantityValidator.MAX_QUANTITY - int(slot["quantity"])
			if room <= 0:
				continue
			var moved := mini(room, remaining)
			slot["quantity"] = int(slot["quantity"]) + moved
			candidate[index] = slot
			remaining -= moved
			if remaining == 0:
				break

	if remaining > 0:
		if candidate.size() >= capacity:
			return _result(false, REASON_STORAGE_FULL)
		var new_slot: Dictionary = {
			"item_instance_id": item_instance_id,
			"definition_id": definition_id,
			"quantity": remaining,
			"stackable": stackable,
		}
		InventoryState._apply_metadata(new_slot, metadata)
		candidate.append(new_slot)

	return {
		"accepted": true,
		"reason_id": &"",
		"normal_slots": _copy_slots(candidate),
		"occupied_normal_slots": candidate.size(),
	}

func try_remove_normal(item_instance_id: StringName, quantity: int) -> Dictionary:
	if not StableId.is_valid(String(item_instance_id)) or quantity <= 0:
		return _result(false, REASON_INVALID_QUANTITY)
	var index := _normal_index(item_instance_id)
	if index < 0:
		return _result(false, REASON_ITEM_NOT_FOUND)
	var slot: Dictionary = normal_slots[index]
	if quantity > int(slot["quantity"]):
		return _result(false, REASON_INVALID_QUANTITY)
	var definition_id := StringName(String(slot["definition_id"]))
	var stackable := bool(slot["stackable"])
	if quantity == int(slot["quantity"]):
		normal_slots.remove_at(index)
	else:
		slot["quantity"] = int(slot["quantity"]) - quantity
		normal_slots[index] = slot
	return {
		"accepted": true,
		"reason_id": &"",
		"definition_id": definition_id,
		"quantity": quantity,
		"stackable": stackable,
	}

func get_normal_slot(item_instance_id: StringName) -> Dictionary:
	var index := _normal_index(item_instance_id)
	if index < 0:
		return {}
	return normal_slots[index].duplicate(true)

func get_upgrade_rank(item_instance_id: StringName) -> int:
	var index := _normal_index(item_instance_id)
	if index < 0:
		return -1
	return int(normal_slots[index].get("upgrade_rank", 0))

func set_upgrade_rank(item_instance_id: StringName, rank: int) -> bool:
	var index := _normal_index(item_instance_id)
	if index < 0 or rank < 0 or bool(normal_slots[index].get("stackable", false)):
		return false
	var slot: Dictionary = normal_slots[index]
	slot["upgrade_rank"] = rank
	normal_slots[index] = slot
	return true

func get_rarity(item_instance_id: StringName) -> StringName:
	var index := _normal_index(item_instance_id)
	if index < 0:
		return &""
	return StringName(String(normal_slots[index].get("rarity", "common")))

func to_dictionary() -> Dictionary:
	return {
		"capacity": capacity,
		"normal_slots": _copy_slots(normal_slots),
	}

func load_dictionary(data: Dictionary) -> PackedStringArray:
	var errors := validate_dictionary(data)
	if not errors.is_empty():
		return errors
	capacity = int(data.get("capacity", DEFAULT_CAPACITY))
	normal_slots = _copy_slots(data.get("normal_slots", []) as Array)
	for index: int in range(normal_slots.size()):
		var slot: Dictionary = normal_slots[index]
		slot["quantity"] = int(slot.get("quantity", 0))
		if slot.has("upgrade_rank"):
			slot["upgrade_rank"] = int(slot.get("upgrade_rank", 0))
		normal_slots[index] = slot
	return errors

static func validate_dictionary(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _is_integral_number(data.get("capacity", null)) or int(data.get("capacity", 0)) <= 0:
		errors.append("capacity must be a positive integer")
		return errors
	var candidate_capacity := int(data["capacity"])
	if not data.get("normal_slots", null) is Array:
		errors.append("normal_slots must be an array")
		return errors
	var slots: Array = data["normal_slots"] as Array
	if slots.size() > candidate_capacity:
		errors.append("normal_slots exceeds storage capacity")
	var seen: Dictionary = {}
	for index: int in range(slots.size()):
		var raw_slot: Variant = slots[index]
		if not raw_slot is Dictionary:
			errors.append("storage slot %d must be a dictionary" % index)
			continue
		var slot := raw_slot as Dictionary
		var instance_id := String(slot.get("item_instance_id", ""))
		var definition_id := String(slot.get("definition_id", ""))
		if not StableId.is_valid(instance_id) or not StableId.is_valid(definition_id):
			errors.append("storage slot %d requires stable item/definition IDs" % index)
		if seen.has(instance_id):
			errors.append("duplicate storage item_instance_id: %s" % instance_id)
		seen[instance_id] = true
		if typeof(slot.get("stackable", null)) != TYPE_BOOL:
			errors.append("storage slot %d stackable must be boolean" % index)
		if not _is_persisted_stack_quantity(slot.get("quantity", null)):
			errors.append("storage slot %d quantity must be 1..99" % index)
		elif typeof(slot.get("stackable", null)) == TYPE_BOOL and not bool(slot["stackable"]) and int(slot["quantity"]) != 1:
			errors.append("nonstackable storage slot %d quantity must equal 1" % index)
		for metadata_error: String in InventoryState._validate_metadata(slot):
			errors.append("storage slot %d metadata: %s" % [index, metadata_error])
	return errors

func _normal_index(item_instance_id: StringName) -> int:
	for index: int in range(normal_slots.size()):
		if StringName(String(normal_slots[index]["item_instance_id"])) == item_instance_id:
			return index
	return -1

static func _copy_slots(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_slot: Variant in source:
		result.append((raw_slot as Dictionary).duplicate(true))
	return result

static func _is_integral_number(value: Variant) -> bool:
	var value_type := typeof(value)
	if value_type == TYPE_INT:
		return true
	if value_type != TYPE_FLOAT:
		return false
	var numeric := float(value)
	return is_finite(numeric) and is_equal_approx(numeric, round(numeric))

static func _is_persisted_stack_quantity(value: Variant) -> bool:
	return (
		_is_integral_number(value)
		and int(value) >= NormalStackQuantityValidator.MIN_QUANTITY
		and int(value) <= NormalStackQuantityValidator.MAX_QUANTITY
	)

static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
	return {"accepted": accepted, "reason_id": reason_id}
