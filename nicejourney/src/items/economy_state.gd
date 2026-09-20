class_name EconomyState
extends RefCounted

var vendor_states: Dictionary = {}
var pending_reward_claims: Dictionary = {}


func initialize_vendor_once(definition: VendorStockDefinition) -> bool:
	if definition == null or not definition.validate_definition().is_empty():
		return false
	if vendor_states.has(String(definition.vendor_id)):
		return false
	var vendor: VendorStockState = definition.build_state()
	return vendor != null and set_vendor(vendor)


func set_vendor(vendor: VendorStockState) -> bool:
	if vendor == null:
		return false
	var data: Dictionary = vendor.to_dictionary()
	if not VendorStockState.validate_dictionary(data).is_empty():
		return false
	vendor_states[String(vendor.vendor_id)] = data.duplicate(true)
	return true


func get_vendor(vendor_id: StringName) -> VendorStockState:
	var raw: Variant = vendor_states.get(String(vendor_id), null)
	if not raw is Dictionary:
		return null
	var vendor: VendorStockState = VendorStockState.new()
	if not vendor.load_dictionary(raw as Dictionary).is_empty():
		return null
	return vendor


func add_pending_reward(claim_id: StringName, source_id: StringName, normal_rewards: Array) -> bool:
	var entry := {
		"claim_id": claim_id,
		"source_id": source_id,
		"normal_rewards": normal_rewards.duplicate(true),
	}
	if not _validate_pending_entry(entry, true).is_empty() or pending_reward_claims.has(String(claim_id)):
		return false
	pending_reward_claims[String(claim_id)] = entry.duplicate(true)
	return true


func get_pending_reward(claim_id: StringName) -> Dictionary:
	var raw: Variant = pending_reward_claims.get(String(claim_id), null)
	if not raw is Dictionary:
		return {}
	return (raw as Dictionary).duplicate(true)


func remove_pending_reward(claim_id: StringName) -> bool:
	if not pending_reward_claims.has(String(claim_id)):
		return false
	pending_reward_claims.erase(String(claim_id))
	return true


func to_dictionary() -> Dictionary:
	return {
		"vendor_states": vendor_states.duplicate(true),
		"pending_reward_claims": pending_reward_claims.duplicate(true),
	}


func load_dictionary(data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = validate_dictionary(data)
	if not errors.is_empty():
		return errors
	vendor_states = _normalize_vendor_states(data.get("vendor_states", {}) as Dictionary)
	pending_reward_claims = _normalize_pending_rewards(data.get("pending_reward_claims", {}) as Dictionary)
	return errors


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data.get("vendor_states", null) is Dictionary:
		errors.append("vendor_states must be a dictionary")
		return errors
	for key: Variant in (data["vendor_states"] as Dictionary).keys():
		var vendor_id := String(key)
		var raw: Variant = (data["vendor_states"] as Dictionary)[key]
		if not StableId.is_valid(vendor_id) or not raw is Dictionary:
			errors.append("vendor state entries require stable IDs and dictionaries")
			continue
		var vendor_data: Dictionary = raw as Dictionary
		if String(vendor_data.get("vendor_id", "")) != vendor_id:
			errors.append("vendor state key must match embedded vendor_id: %s" % vendor_id)
			continue
		for vendor_error: String in VendorStockState.validate_dictionary(vendor_data):
			errors.append("vendor_states[%s]: %s" % [vendor_id, vendor_error])
	var raw_pending: Variant = data.get("pending_reward_claims", {})
	if not raw_pending is Dictionary:
		errors.append("pending_reward_claims must be a dictionary")
		return errors
	for key: Variant in (raw_pending as Dictionary).keys():
		var claim_id := String(key)
		var raw_entry: Variant = (raw_pending as Dictionary)[key]
		if not StableId.is_valid(claim_id) or not raw_entry is Dictionary:
			errors.append("pending reward entries require stable IDs and dictionaries")
			continue
		var entry: Dictionary = raw_entry as Dictionary
		if String(entry.get("claim_id", "")) != claim_id:
			errors.append("pending reward key must match embedded claim_id: %s" % claim_id)
		for pending_error: String in _validate_pending_entry(entry, false):
			errors.append("pending_reward_claims[%s]: %s" % [claim_id, pending_error])
	return errors


static func _validate_pending_entry(entry: Dictionary, strict_live_quantity: bool = false) -> PackedStringArray:
	var errors := PackedStringArray()
	for key: String in ["claim_id", "source_id"]:
		var value: Variant = entry.get(key, null)
		if not (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME) or not StableId.is_valid(String(value)):
			errors.append("%s must be a stable ID" % key)
	if not entry.get("normal_rewards", null) is Array:
		errors.append("normal_rewards must be an array")
		return errors
	var seen_instances: Dictionary = {}
	for index: int in range((entry["normal_rewards"] as Array).size()):
		var raw_reward: Variant = (entry["normal_rewards"] as Array)[index]
		if not raw_reward is Dictionary:
			errors.append("normal reward %d must be a dictionary" % index)
			continue
		var reward: Dictionary = raw_reward as Dictionary
		for key: String in ["item_instance_id", "definition_id"]:
			var value: Variant = reward.get(key, null)
			if not (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME) or not StableId.is_valid(String(value)):
				errors.append("normal reward %d %s must be stable" % [index, key])
		var instance_id := String(reward.get("item_instance_id", ""))
		if seen_instances.has(instance_id):
			errors.append("normal_rewards contains duplicate item_instance_id: %s" % instance_id)
		seen_instances[instance_id] = true
		if typeof(reward.get("stackable", null)) != TYPE_BOOL:
			errors.append("normal reward %d stackable must be boolean" % index)
		var quantity_value: Variant = reward.get("quantity", null)
		var quantity_valid := NormalStackQuantityValidator.is_valid(quantity_value) if strict_live_quantity else _is_persisted_stack_quantity(quantity_value)
		if not quantity_valid:
			errors.append("normal reward %d quantity must be 1..99" % index)
		elif typeof(reward.get("stackable", null)) == TYPE_BOOL and not bool(reward["stackable"]) and int(quantity_value) != 1:
			errors.append("normal reward %d nonstackable quantity must equal 1" % index)
	return errors


static func _normalize_vendor_states(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_key: Variant in source.keys():
		var raw_vendor: Variant = source[raw_key]
		if not raw_vendor is Dictionary:
			continue
		var vendor: VendorStockState = VendorStockState.new()
		if vendor.load_dictionary(raw_vendor as Dictionary).is_empty():
			result[String(raw_key)] = vendor.to_dictionary()
	return result


static func _normalize_pending_rewards(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	for raw_key: Variant in result.keys():
		var raw_entry: Variant = result[raw_key]
		if not raw_entry is Dictionary:
			continue
		var entry := (raw_entry as Dictionary).duplicate(true)
		var rewards_variant: Variant = entry.get("normal_rewards", null)
		if rewards_variant is Array:
			var rewards: Array = []
			for raw_reward: Variant in rewards_variant as Array:
				if not raw_reward is Dictionary:
					continue
				var reward := (raw_reward as Dictionary).duplicate(true)
				if _is_persisted_stack_quantity(reward.get("quantity", null)):
					reward["quantity"] = int(reward["quantity"])
				rewards.append(reward)
			entry["normal_rewards"] = rewards
		result[raw_key] = entry
	return result


static func _is_persisted_stack_quantity(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= NormalStackQuantityValidator.MIN_QUANTITY and int(value) <= NormalStackQuantityValidator.MAX_QUANTITY
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return (
		is_finite(number)
		and number >= float(NormalStackQuantityValidator.MIN_QUANTITY)
		and number <= float(NormalStackQuantityValidator.MAX_QUANTITY)
		and is_equal_approx(number, round(number))
	)
