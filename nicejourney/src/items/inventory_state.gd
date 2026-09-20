class_name InventoryState
extends RefCounted

const QUICK_SLOT_COUNT: int = 4
const TOWER_SIGIL_ID: StringName = &"tower_sigil"
const RARITY_AFFIX_TARGETS: Dictionary = {
    "common": 0,
    "rare": 1,
    "epic": 2,
    "legendary": 3,
}

const REASON_INVALID_ITEM: StringName = &"invalid_item"
const REASON_DUPLICATE_ITEM_INSTANCE: StringName = &"duplicate_item_instance"
const REASON_INVENTORY_FULL: StringName = &"inventory_full"
const REASON_ITEM_NOT_FOUND: StringName = &"item_not_found"
const REASON_INVALID_QUANTITY: StringName = &"invalid_quantity"
const REASON_PROTECTED_OPERATION: StringName = &"protected_operation"
const REASON_INSUFFICIENT_GOLD: StringName = &"insufficient_gold"
const REASON_INVALID_GOLD: StringName = &"invalid_gold"

var gold: int = 0
var normal_slots: Array[Dictionary] = []
var protected_items: Dictionary = {}
var quick_slots: Array[StringName] = [&"", &"", &"", &""]


func try_add_normal(item_instance_id: StringName, definition_id: StringName, quantity: int, stackable: bool, metadata: Dictionary = {}) -> Dictionary:
    var preview: Dictionary = preview_add_normal(item_instance_id, definition_id, quantity, stackable, metadata)
    if not bool(preview.get("accepted", false)):
        return preview
    normal_slots = _typed_slot_array(preview["normal_slots"] as Array)
    return preview


func preview_add_normal(item_instance_id: StringName, definition_id: StringName, quantity: int, stackable: bool, metadata: Dictionary = {}) -> Dictionary:
    if not StableId.is_valid(String(item_instance_id)) or not StableId.is_valid(String(definition_id)):
        return _result(false, REASON_INVALID_ITEM)
    if not NormalStackQuantityValidator.is_valid(quantity):
        return _result(false, REASON_INVALID_QUANTITY)
    if not stackable and quantity != 1:
        return _result(false, REASON_INVALID_QUANTITY)
    if not _validate_metadata(metadata).is_empty():
        return _result(false, REASON_INVALID_ITEM)
    if _has_normal_instance(item_instance_id) or protected_items.has(String(item_instance_id)):
        return _result(false, REASON_DUPLICATE_ITEM_INSTANCE)

    var candidate: Array[Dictionary] = _copy_slots(normal_slots)
    var remaining := quantity
    if stackable:
        for index: int in range(candidate.size()):
            var slot: Dictionary = candidate[index]
            if not bool(slot["stackable"]) or StringName(String(slot["definition_id"])) != definition_id or not _stack_metadata_compatible(slot, metadata):
                continue
            var room: int = NormalStackQuantityValidator.MAX_QUANTITY - int(slot["quantity"])
            if room <= 0:
                continue
            var moved: int = mini(room, remaining)
            slot["quantity"] = int(slot["quantity"]) + moved
            candidate[index] = slot
            remaining -= moved
            if remaining == 0:
                break

    if remaining > 0:
        var capacity: Dictionary = NormalInventoryCapacityPolicy.evaluate({
            &"occupied_normal_slots": candidate.size(),
            &"protected_quest_key": false,
            &"needs_new_normal_slot": true,
        })
        if not bool(capacity.get("allowed", false)):
            return _result(false, REASON_INVENTORY_FULL)
        var new_slot: Dictionary = {
            "item_instance_id": item_instance_id,
            "definition_id": definition_id,
            "quantity": remaining,
            "stackable": stackable,
        }
        _apply_metadata(new_slot, metadata)
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
    var index: int = _normal_index(item_instance_id)
    if index < 0:
        return _result(false, REASON_ITEM_NOT_FOUND)
    var slot: Dictionary = normal_slots[index]
    if quantity > int(slot["quantity"]):
        return _result(false, REASON_INVALID_QUANTITY)
    var removed_definition := StringName(String(slot["definition_id"]))
    var removed_stackable := bool(slot["stackable"])
    if quantity == int(slot["quantity"]):
        normal_slots.remove_at(index)
        _clear_quick_slot_references(item_instance_id)
    else:
        slot["quantity"] = int(slot["quantity"]) - quantity
        normal_slots[index] = slot
    return {
        "accepted": true,
        "reason_id": &"",
        "definition_id": removed_definition,
        "quantity": quantity,
        "stackable": removed_stackable,
    }


func grant_protected(item_id: StringName, tower_sigil: bool = false) -> bool:
    if not StableId.is_valid(String(item_id)) or protected_items.has(String(item_id)) or _has_normal_instance(item_id):
        return false
    if tower_sigil and item_id != TOWER_SIGIL_ID:
        return false
    protected_items[String(item_id)] = {
        "protected_quest_key": true,
        "tower_sigil": tower_sigil,
    }
    return true


func remove_protected_by_quest(item_id: StringName) -> Dictionary:
    if not protected_items.has(String(item_id)):
        return _result(false, REASON_ITEM_NOT_FOUND)
    var protection: Dictionary = protected_items[String(item_id)] as Dictionary
    var policy: Dictionary = ProtectedItemOperationPolicy.evaluate(ProtectedItemOperationPolicy.OP_QUEST_REMOVE, protection)
    if not bool(policy.get("allowed", false)):
        return {
            "accepted": false,
            "reason_id": REASON_PROTECTED_OPERATION,
            "policy_reason_id": StringName(policy.get("reason_id", &"")),
        }
    protected_items.erase(String(item_id))
    return {"accepted": true, "reason_id": &""}


func get_normal_slot(item_instance_id: StringName) -> Dictionary:
    var index: int = _normal_index(item_instance_id)
    if index < 0:
        return {}
    return normal_slots[index].duplicate(true)


func get_total_quantity(definition_id: StringName) -> int:
    var total := 0
    for slot: Dictionary in normal_slots:
        if StringName(String(slot["definition_id"])) == definition_id:
            total += int(slot["quantity"])
    return total


func try_remove_definition_quantity(definition_id: StringName, quantity: int) -> Dictionary:
    if not StableId.is_valid(String(definition_id)) or quantity <= 0 or get_total_quantity(definition_id) < quantity:
        return _result(false, REASON_INVALID_QUANTITY)
    var remaining := quantity
    for index: int in range(normal_slots.size() - 1, -1, -1):
        var slot: Dictionary = normal_slots[index]
        if StringName(String(slot["definition_id"])) != definition_id:
            continue
        var moved := mini(remaining, int(slot["quantity"]))
        if moved == int(slot["quantity"]):
            var removed_id := StringName(String(slot["item_instance_id"]))
            normal_slots.remove_at(index)
            _clear_quick_slot_references(removed_id)
        else:
            slot["quantity"] = int(slot["quantity"]) - moved
            normal_slots[index] = slot
        remaining -= moved
        if remaining == 0:
            break
    return {"accepted": true, "reason_id": &"", "definition_id": definition_id, "quantity": quantity}


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


func bind_quick_slot(slot_index: int, item_instance_id: StringName) -> bool:
    if slot_index < 0 or slot_index >= QUICK_SLOT_COUNT:
        return false
    if item_instance_id == &"":
        quick_slots[slot_index] = &""
        return true
    if not _has_normal_instance(item_instance_id):
        return false
    quick_slots[slot_index] = item_instance_id
    return true


func add_gold(amount: int) -> bool:
    if amount < 0 or gold > 2147483647 - amount:
        return false
    gold += amount
    return true


func spend_gold(amount: int) -> bool:
    if amount < 0 or amount > gold:
        return false
    gold -= amount
    return true


func to_dictionary() -> Dictionary:
    var protected_copy: Dictionary = {}
    for key: Variant in protected_items.keys():
        protected_copy[String(key)] = (protected_items[key] as Dictionary).duplicate(true)
    return {
        "gold": gold,
        "normal_slots": _copy_slots(normal_slots),
        "protected_items": protected_copy,
        "quick_slots": _string_array(quick_slots),
    }


func load_dictionary(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = validate_dictionary(data)
    if not errors.is_empty():
        return errors
    gold = int(data.get("gold", 0))
    normal_slots = _typed_slot_array(data.get("normal_slots", []) as Array)
    protected_items = (data.get("protected_items", {}) as Dictionary).duplicate(true)
    quick_slots = _to_quick_slots(data.get("quick_slots", []) as Array)
    return errors


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    var raw_gold: Variant = data.get("gold", null)
    if not _is_integral_number(raw_gold) or int(raw_gold) < 0:
        errors.append("gold must be a nonnegative integer")
    if not data.get("normal_slots", null) is Array:
        errors.append("normal_slots must be an array")
    else:
        var slots: Array = data["normal_slots"] as Array
        if slots.size() > NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY:
            errors.append("normal_slots exceeds the 16-slot capacity")
        var seen_instances: Dictionary = {}
        for index: int in range(slots.size()):
            var raw_slot: Variant = slots[index]
            if not raw_slot is Dictionary:
                errors.append("normal slot %d must be a dictionary" % index)
                continue
            var slot: Dictionary = raw_slot as Dictionary
            if not _stable_field(slot, "item_instance_id") or not _stable_field(slot, "definition_id"):
                errors.append("normal slot %d requires stable item/definition IDs" % index)
            var instance_id := String(slot.get("item_instance_id", ""))
            if seen_instances.has(instance_id):
                errors.append("duplicate normal item_instance_id: %s" % instance_id)
            seen_instances[instance_id] = true
            if typeof(slot.get("stackable", null)) != TYPE_BOOL:
                errors.append("normal slot %d stackable must be boolean" % index)
            if not _is_persisted_stack_quantity(slot.get("quantity", null)):
                errors.append("normal slot %d quantity must be 1..99" % index)
            elif typeof(slot.get("stackable", null)) == TYPE_BOOL and not bool(slot["stackable"]) and int(slot["quantity"]) != 1:
                errors.append("nonstackable normal slot %d quantity must equal 1" % index)
            for metadata_error: String in _validate_metadata(slot):
                errors.append("normal slot %d metadata: %s" % [index, metadata_error])
    if not data.get("protected_items", null) is Dictionary:
        errors.append("protected_items must be a dictionary")
    else:
        for key: Variant in (data["protected_items"] as Dictionary).keys():
            var item_id := String(key)
            var state: Variant = (data["protected_items"] as Dictionary)[key]
            if not StableId.is_valid(item_id) or not state is Dictionary:
                errors.append("protected item entries require stable IDs and dictionaries")
                continue
            var protection: Dictionary = state as Dictionary
            if typeof(protection.get("protected_quest_key", null)) != TYPE_BOOL or not bool(protection.get("protected_quest_key", false)):
                errors.append("protected item %s must remain marked protected_quest_key" % item_id)
            if typeof(protection.get("tower_sigil", null)) != TYPE_BOOL:
                errors.append("protected item %s tower_sigil must be boolean" % item_id)
            elif bool(protection["tower_sigil"]) and item_id != String(TOWER_SIGIL_ID):
                errors.append("only tower_sigil may carry the permanent Tower Sigil flag")
    if not data.get("quick_slots", null) is Array:
        errors.append("quick_slots must be an array")
    else:
        var quick: Array = data["quick_slots"] as Array
        if quick.size() != QUICK_SLOT_COUNT:
            errors.append("quick_slots must contain exactly four references")
        var owned: Dictionary = {}
        if data.get("normal_slots", null) is Array:
            for raw_slot: Variant in data["normal_slots"] as Array:
                if raw_slot is Dictionary:
                    owned[String((raw_slot as Dictionary).get("item_instance_id", ""))] = true
        for reference: Variant in quick:
            if not (typeof(reference) == TYPE_STRING or typeof(reference) == TYPE_STRING_NAME):
                errors.append("quick slot references must be strings")
                continue
            var reference_id := String(reference)
            if not reference_id.is_empty() and (not StableId.is_valid(reference_id) or not owned.has(reference_id)):
                errors.append("quick slot references must point to owned normal item instances")
    return errors


func _has_normal_instance(item_instance_id: StringName) -> bool:
    return _normal_index(item_instance_id) >= 0


func _normal_index(item_instance_id: StringName) -> int:
    for index: int in range(normal_slots.size()):
        if StringName(String(normal_slots[index]["item_instance_id"])) == item_instance_id:
            return index
    return -1


func _clear_quick_slot_references(item_instance_id: StringName) -> void:
    for index: int in range(quick_slots.size()):
        if quick_slots[index] == item_instance_id:
            quick_slots[index] = &""


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


static func _is_persisted_stack_quantity(value: Variant) -> bool:
    return (
        _is_integral_number(value)
        and int(value) >= NormalStackQuantityValidator.MIN_QUANTITY
        and int(value) <= NormalStackQuantityValidator.MAX_QUANTITY
    )


static func _validate_metadata(data: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    var rarity := String(data.get("rarity", "common"))
    if not RARITY_AFFIX_TARGETS.has(rarity):
        errors.append("rarity must be common/rare/epic/legendary")
    var raw_affixes: Variant = data.get("affixes", [])
    if not raw_affixes is Array:
        errors.append("affixes must be an array")
    else:
        var seen: Dictionary = {}
        for raw_affix: Variant in raw_affixes as Array:
            if not (typeof(raw_affix) == TYPE_STRING or typeof(raw_affix) == TYPE_STRING_NAME) or not StableId.is_valid(String(raw_affix)):
                errors.append("affixes require stable IDs")
                continue
            var affix := String(raw_affix)
            if seen.has(affix):
                errors.append("affixes must be unique")
            seen[affix] = true
        if RARITY_AFFIX_TARGETS.has(rarity) and (raw_affixes as Array).size() != int(RARITY_AFFIX_TARGETS[rarity]):
            errors.append("affix count must match realized rarity target")
    var raw_rank: Variant = data.get("upgrade_rank", 0)
    if not _is_integral_number(raw_rank) or int(raw_rank) < 0:
        errors.append("upgrade_rank must be a nonnegative integer")
    var raw_source: Variant = data.get("source_claim_id", "")
    if not (typeof(raw_source) == TYPE_STRING or typeof(raw_source) == TYPE_STRING_NAME):
        errors.append("source_claim_id must be a string")
    elif not String(raw_source).is_empty() and not StableId.is_valid(String(raw_source)):
        errors.append("source_claim_id must be empty or a stable ID")
    return errors


static func _apply_metadata(slot: Dictionary, metadata: Dictionary) -> void:
    if metadata.is_empty():
        return
    slot["rarity"] = String(metadata.get("rarity", "common"))
    var affixes: Array[String] = []
    for raw_affix: Variant in metadata.get("affixes", []) as Array:
        affixes.append(String(raw_affix))
    slot["affixes"] = affixes
    slot["upgrade_rank"] = int(metadata.get("upgrade_rank", 0))
    slot["source_claim_id"] = String(metadata.get("source_claim_id", ""))


static func _stack_metadata_compatible(slot: Dictionary, metadata: Dictionary) -> bool:
    if metadata.is_empty():
        return not slot.has("rarity") and not slot.has("affixes") and not slot.has("upgrade_rank") and not slot.has("source_claim_id")
    return (
        String(slot.get("rarity", "common")) == String(metadata.get("rarity", "common"))
        and (slot.get("affixes", []) as Array) == (metadata.get("affixes", []) as Array)
        and int(slot.get("upgrade_rank", 0)) == int(metadata.get("upgrade_rank", 0))
        and String(slot.get("source_claim_id", "")) == String(metadata.get("source_claim_id", ""))
    )


static func _copy_slots(source: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for raw_slot: Variant in source:
        result.append((raw_slot as Dictionary).duplicate(true))
    return result


static func _typed_slot_array(source: Array) -> Array[Dictionary]:
    return _copy_slots(source)


static func _string_array(values: Array[StringName]) -> Array[String]:
    var result: Array[String] = []
    for value: StringName in values:
        result.append(String(value))
    return result


static func _to_quick_slots(values: Array) -> Array[StringName]:
    var result: Array[StringName] = []
    for value: Variant in values:
        result.append(StringName(String(value)))
    return result


static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {"accepted": accepted, "reason_id": reason_id}
