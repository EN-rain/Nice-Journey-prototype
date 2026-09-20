class_name EquipmentItemDefinition
extends Resource

@export var definition_id: StringName = &""
@export var allowed_slot_ids: Array[StringName] = []
@export var allowed_class_ids: Array[StringName] = [&"melee", &"ranged", &"mage"]
@export var two_handed: bool = false
@export var off_hand_allowed: bool = true
@export var unique_equip_group: StringName = &""

func validate_definition() -> PackedStringArray:
	var errors := PackedStringArray()
	if not StableId.is_valid(String(definition_id)):
		errors.append("definition_id must be a stable ID")
	if allowed_slot_ids.is_empty():
		errors.append("allowed_slot_ids must not be empty")
	else:
		var seen_slots: Dictionary = {}
		for slot_id: StringName in allowed_slot_ids:
			if not EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS.has(slot_id):
				errors.append("allowed_slot_ids contains unknown slot %s" % String(slot_id))
			if seen_slots.has(slot_id):
				errors.append("allowed_slot_ids must be unique")
			seen_slots[slot_id] = true
	if allowed_class_ids.is_empty():
		errors.append("allowed_class_ids must not be empty")
	else:
		var seen_classes: Dictionary = {}
		for class_id: StringName in allowed_class_ids:
			if not ProfileSnapshot.CLASS_IDS.has(String(class_id)):
				errors.append("allowed_class_ids contains unknown class %s" % String(class_id))
			if seen_classes.has(class_id):
				errors.append("allowed_class_ids must be unique")
			seen_classes[class_id] = true
	if two_handed and not allowed_slot_ids.has(EquipmentSlotIdentityValidator.SLOT_WEAPON):
		errors.append("two_handed definitions must support the weapon slot")
	if unique_equip_group != &"" and not StableId.is_valid(String(unique_equip_group)):
		errors.append("unique_equip_group must be empty or a stable ID")
	return errors

func supports(slot_id: StringName, class_id: StringName) -> bool:
	return (
		validate_definition().is_empty()
		and allowed_slot_ids.has(slot_id)
		and allowed_class_ids.has(class_id)
	)
