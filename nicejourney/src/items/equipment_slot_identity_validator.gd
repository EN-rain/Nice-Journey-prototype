class_name EquipmentSlotIdentityValidator
extends RefCounted

const SLOT_COUNT: int = 5

const SLOT_WEAPON: StringName = &"weapon"
const SLOT_ARMOR: StringName = &"armor"
const SLOT_OFF_HAND: StringName = &"off_hand"
const SLOT_ACCESSORY_1: StringName = &"accessory_1"
const SLOT_ACCESSORY_2: StringName = &"accessory_2"

const REQUIRED_SLOT_IDS: Array[StringName] = [
	SLOT_WEAPON,
	SLOT_ARMOR,
	SLOT_OFF_HAND,
	SLOT_ACCESSORY_1,
	SLOT_ACCESSORY_2,
]

static func validate_entries(raw_entries: Variant) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if not raw_entries is Array:
		errors.append("entries must be an array")
		return errors

	var entries: Array = raw_entries as Array
	if entries.size() != SLOT_COUNT:
		errors.append("entries must contain exactly 5 equipment slots")

	var seen_slot_ids: Dictionary = {}
	for index: int in range(entries.size()):
		var raw_entry: Variant = entries[index]
		if not raw_entry is Dictionary:
			errors.append("entries[%d] must be a dictionary" % index)
			continue

		var entry: Dictionary = raw_entry as Dictionary
		var slot_id: StringName = _read_slot_id(entry, index, errors)
		if slot_id != &"":
			if seen_slot_ids.has(slot_id):
				errors.append("entries[%d]: duplicate slot_id %s" % [index, String(slot_id)])
			else:
				seen_slot_ids[slot_id] = true

		_validate_optional_name(entry, index, errors)

	for slot_id: StringName in REQUIRED_SLOT_IDS:
		if not seen_slot_ids.has(slot_id):
			errors.append("missing slot_id %s" % String(slot_id))

	return errors

static func _read_slot_id(entry: Dictionary, index: int, errors: PackedStringArray) -> StringName:
	if not entry.has("slot_id"):
		errors.append("entries[%d]: missing slot_id" % index)
		return &""
	var value: Variant = entry.get("slot_id")
	if not (value is String or value is StringName):
		errors.append("entries[%d]: slot_id must be a string" % index)
		return &""
	var slot_id: StringName = StringName(String(value))
	if not REQUIRED_SLOT_IDS.has(slot_id):
		errors.append("entries[%d]: unknown slot_id %s" % [index, String(slot_id)])
		return &""
	return slot_id

static func _validate_optional_name(entry: Dictionary, index: int, errors: PackedStringArray) -> void:
	if not entry.has("name"):
		return
	var value: Variant = entry.get("name")
	if not (value is String or value is StringName):
		errors.append("entries[%d]: name must be a string when present" % index)
