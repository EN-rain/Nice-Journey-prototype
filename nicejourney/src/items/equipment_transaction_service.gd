class_name EquipmentTransactionService
extends RefCounted

const SOURCE_ID: StringName = &"equipment:service"
const REASON_INVALID_INPUT: StringName = &"invalid_input"
const REASON_DUPLICATE_TRANSACTION: StringName = &"duplicate_transaction"
const REASON_ITEM_NOT_FOUND: StringName = &"item_not_found"
const REASON_DEFINITION_MISSING: StringName = &"definition_missing"
const REASON_INCOMPATIBLE: StringName = &"incompatible"
const REASON_UNIQUE_CONFLICT: StringName = &"unique_conflict"
const REASON_INVENTORY_REJECTED: StringName = &"inventory_rejected"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"

static func equip_from_inventory(
    inventory: InventoryState,
    equipment: EquipmentState,
    catalog: EquipmentItemCatalog,
    ledger: ClaimLedger,
    transaction_id: StringName,
    item_instance_id: StringName,
    target_slot_id: StringName,
    class_id: StringName
) -> Dictionary:
    if not _base_inputs_valid(inventory, equipment, catalog, ledger, transaction_id, class_id):
        return _result(false, REASON_INVALID_INPUT)
    if ledger.is_claimed(transaction_id):
        return _result(false, REASON_DUPLICATE_TRANSACTION)
    if not EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS.has(target_slot_id):
        return _result(false, REASON_INVALID_INPUT)

    var incoming := inventory.get_normal_slot(item_instance_id)
    if incoming.is_empty() or bool(incoming.get("stackable", true)):
        return _result(false, REASON_ITEM_NOT_FOUND)
    var definition_id := StringName(String(incoming.get("definition_id", "")))
    var definition := catalog.get_definition(definition_id)
    if definition == null:
        return _result(false, REASON_DEFINITION_MISSING)
    if not definition.supports(target_slot_id, class_id):
        return _result(false, REASON_INCOMPATIBLE)
    if not _unique_group_allows(equipment, catalog, target_slot_id, definition):
        return _result(false, REASON_UNIQUE_CONFLICT)
    if target_slot_id == EquipmentSlotIdentityValidator.SLOT_OFF_HAND:
        var weapon := equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON)
        if not weapon.is_empty():
            var weapon_definition := catalog.get_definition(StringName(String(weapon.get("definition_id", ""))))
            if weapon_definition == null:
                return _result(false, REASON_DEFINITION_MISSING)
            if weapon_definition.two_handed and not weapon_definition.off_hand_allowed:
                return _result(false, REASON_INCOMPATIBLE)

    var temp_inventory := InventoryState.new()
    var temp_equipment := EquipmentState.new()
    var temp_ledger := ClaimLedger.new()
    if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_equipment.load_dictionary(equipment.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    if not bool(temp_inventory.try_remove_normal(item_instance_id, 1).get("accepted", false)):
        return _result(false, REASON_COMMIT_FAILED)

    var displaced: Array[Dictionary] = []
    var existing_target := temp_equipment.get_item(target_slot_id)
    if not existing_target.is_empty():
        displaced.append(existing_target)
        temp_equipment.clear_item(target_slot_id)

    if target_slot_id == EquipmentSlotIdentityValidator.SLOT_WEAPON and definition.two_handed and not definition.off_hand_allowed:
        var existing_off_hand := temp_equipment.get_item(EquipmentSlotIdentityValidator.SLOT_OFF_HAND)
        if not existing_off_hand.is_empty():
            displaced.append(existing_off_hand)
            temp_equipment.clear_item(EquipmentSlotIdentityValidator.SLOT_OFF_HAND)

    for displaced_item: Dictionary in displaced:
        var restore := _restore_to_inventory(temp_inventory, displaced_item)
        if not bool(restore.get("accepted", false)):
            return {
                "accepted": false,
                "reason_id": REASON_INVENTORY_REJECTED,
                "inventory_reason_id": StringName(restore.get("reason_id", &"")),
            }

    if not temp_equipment.set_item(target_slot_id, incoming):
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_ledger.try_claim(transaction_id, SOURCE_ID):
        return _result(false, REASON_DUPLICATE_TRANSACTION)
    if not _commit(inventory, equipment, ledger, temp_inventory, temp_equipment, temp_ledger):
        return _result(false, REASON_COMMIT_FAILED)

    return {
        "accepted": true,
        "reason_id": &"",
        "transaction_id": transaction_id,
        "item_instance_id": item_instance_id,
        "slot_id": target_slot_id,
        "displaced_count": displaced.size(),
    }

static func unequip_to_inventory(
    inventory: InventoryState,
    equipment: EquipmentState,
    ledger: ClaimLedger,
    transaction_id: StringName,
    slot_id: StringName
) -> Dictionary:
    if inventory == null or equipment == null or ledger == null:
        return _result(false, REASON_INVALID_INPUT)
    if not StableId.is_valid(String(transaction_id)) or not EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS.has(slot_id):
        return _result(false, REASON_INVALID_INPUT)
    if ledger.is_claimed(transaction_id):
        return _result(false, REASON_DUPLICATE_TRANSACTION)
    var equipped := equipment.get_item(slot_id)
    if equipped.is_empty():
        return _result(false, REASON_ITEM_NOT_FOUND)

    var temp_inventory := InventoryState.new()
    var temp_equipment := EquipmentState.new()
    var temp_ledger := ClaimLedger.new()
    if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_equipment.load_dictionary(equipment.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    var restore := _restore_to_inventory(temp_inventory, equipped)
    if not bool(restore.get("accepted", false)):
        return {
            "accepted": false,
            "reason_id": REASON_INVENTORY_REJECTED,
            "inventory_reason_id": StringName(restore.get("reason_id", &"")),
        }
    temp_equipment.clear_item(slot_id)
    if not temp_ledger.try_claim(transaction_id, SOURCE_ID):
        return _result(false, REASON_DUPLICATE_TRANSACTION)
    if not _commit(inventory, equipment, ledger, temp_inventory, temp_equipment, temp_ledger):
        return _result(false, REASON_COMMIT_FAILED)
    return {
        "accepted": true,
        "reason_id": &"",
        "transaction_id": transaction_id,
        "slot_id": slot_id,
        "item_instance_id": StringName(String(equipped.get("item_instance_id", ""))),
    }

static func _base_inputs_valid(
    inventory: InventoryState,
    equipment: EquipmentState,
    catalog: EquipmentItemCatalog,
    ledger: ClaimLedger,
    transaction_id: StringName,
    class_id: StringName
) -> bool:
    return (
        inventory != null
        and equipment != null
        and catalog != null
        and ledger != null
        and catalog.validate_catalog().is_empty()
        and EquipmentState.validate_dictionary(equipment.to_dictionary()).is_empty()
        and StableId.is_valid(String(transaction_id))
        and ProfileSnapshot.CLASS_IDS.has(String(class_id))
    )

static func _unique_group_allows(
    equipment: EquipmentState,
    catalog: EquipmentItemCatalog,
    target_slot_id: StringName,
    incoming_definition: EquipmentItemDefinition
) -> bool:
    if incoming_definition.unique_equip_group == &"":
        return true
    for slot_id: StringName in EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS:
        if slot_id == target_slot_id:
            continue
        var equipped := equipment.get_item(slot_id)
        if equipped.is_empty():
            continue
        var existing_definition := catalog.get_definition(StringName(String(equipped.get("definition_id", ""))))
        if existing_definition == null:
            return false
        if existing_definition.unique_equip_group != &"" and existing_definition.unique_equip_group == incoming_definition.unique_equip_group:
            return false
    return true

static func _restore_to_inventory(inventory: InventoryState, item: Dictionary) -> Dictionary:
    var metadata := {
        "rarity": String(item.get("rarity", "common")),
        "affixes": (item.get("affixes", []) as Array).duplicate(),
        "upgrade_rank": int(item.get("upgrade_rank", 0)),
        "source_claim_id": String(item.get("source_claim_id", "")),
    }
    return inventory.try_add_normal(
        StringName(String(item.get("item_instance_id", ""))),
        StringName(String(item.get("definition_id", ""))),
        int(item.get("quantity", 1)),
        bool(item.get("stackable", false)),
        metadata
    )

static func _commit(
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

static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {"accepted": accepted, "reason_id": reason_id}
