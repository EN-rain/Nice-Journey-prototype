class_name EquipmentState
extends RefCounted

var slots: Dictionary = {}

func _init() -> void:
    for slot_id: StringName in EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS:
        slots[String(slot_id)] = {}

func get_item(slot_id: StringName) -> Dictionary:
    if not slots.has(String(slot_id)):
        return {}
    return (slots[String(slot_id)] as Dictionary).duplicate(true)

func set_item(slot_id: StringName, item: Dictionary) -> bool:
    if not EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS.has(slot_id):
        return false
    if not item.is_empty() and not _validate_equipped_item(item).is_empty():
        return false
    slots[String(slot_id)] = item.duplicate(true)
    return true

func clear_item(slot_id: StringName) -> bool:
    if not EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS.has(slot_id):
        return false
    slots[String(slot_id)] = {}
    return true

func find_item_slot(item_instance_id: StringName) -> StringName:
    for slot_id: StringName in EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS:
        var item: Dictionary = slots.get(String(slot_id), {}) as Dictionary
        if not item.is_empty() and StringName(String(item.get("item_instance_id", ""))) == item_instance_id:
            return slot_id
    return &""

func to_dictionary() -> Dictionary:
    var result: Dictionary = {"slots": {}}
    var slot_copy: Dictionary = result["slots"] as Dictionary
    for slot_id: StringName in EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS:
        slot_copy[String(slot_id)] = (slots.get(String(slot_id), {}) as Dictionary).duplicate(true)
    return result

func load_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := validate_dictionary(data)
    if not errors.is_empty():
        return errors
    slots.clear()
    var raw_slots := data["slots"] as Dictionary
    for slot_id: StringName in EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS:
        slots[String(slot_id)] = (raw_slots[String(slot_id)] as Dictionary).duplicate(true)
    return errors

static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    if not data.get("slots", null) is Dictionary:
        errors.append("slots must be a dictionary")
        return errors
    var raw_slots := data["slots"] as Dictionary
    if raw_slots.size() != EquipmentSlotIdentityValidator.SLOT_COUNT:
        errors.append("slots must contain exactly five equipment slots")
    var seen_items: Dictionary = {}
    for slot_id: StringName in EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS:
        var key := String(slot_id)
        if not raw_slots.has(key):
            errors.append("missing equipment slot %s" % key)
            continue
        var raw_item: Variant = raw_slots[key]
        if not raw_item is Dictionary:
            errors.append("equipment slot %s must be a dictionary" % key)
            continue
        var item := raw_item as Dictionary
        if item.is_empty():
            continue
        for item_error: String in _validate_equipped_item(item):
            errors.append("equipment slot %s: %s" % [key, item_error])
        var instance_id := String(item.get("item_instance_id", ""))
        if seen_items.has(instance_id):
            errors.append("equipped item instance cannot occupy two slots: %s" % instance_id)
        seen_items[instance_id] = true
    for raw_key: Variant in raw_slots.keys():
        if not EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS.has(StringName(String(raw_key))):
            errors.append("unknown equipment slot %s" % String(raw_key))
    return errors

static func _validate_equipped_item(item: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    if not _stable_field(item, "item_instance_id") or not _stable_field(item, "definition_id"):
        errors.append("equipped item requires stable item/definition IDs")
    var raw_quantity: Variant = item.get("quantity", null)
    if not _is_integral_number(raw_quantity) or int(raw_quantity) != 1:
        errors.append("equipped item quantity must equal 1")
    if typeof(item.get("stackable", null)) != TYPE_BOOL or bool(item.get("stackable", true)):
        errors.append("equipped item must be nonstackable")
    for metadata_error: String in InventoryState._validate_metadata(item):
        errors.append("metadata: %s" % metadata_error)
    return errors

static func _stable_field(data: Dictionary, key: String) -> bool:
    var value: Variant = data.get(key, null)
    return (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME) and StableId.is_valid(String(value))


static func _is_integral_number(value: Variant) -> bool:
    var value_type: int = typeof(value)
    if value_type == TYPE_INT:
        return true
    if value_type != TYPE_FLOAT:
        return false
    var numeric: float = float(value)
    return is_finite(numeric) and is_equal_approx(numeric, round(numeric))
