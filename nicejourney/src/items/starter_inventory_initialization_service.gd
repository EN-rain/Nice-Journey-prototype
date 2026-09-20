class_name StarterInventoryInitializationService
extends RefCounted

const STARTER_EQUIPMENT_CATALOG: Script = preload("res://src/items/starter_equipment_catalog.gd")


static func initialize_new_profile(profile: ProfileSnapshot) -> bool:
    if profile == null or not StableId.is_valid(profile.profile_id):
        return false
    var class_id := StringName(profile.class_id)
    if not ProfileSnapshot.CLASS_IDS.has(String(class_id)):
        return false
    # This initializer is creation-only. Existing/legacy item ownership is never rewritten.
    if not profile.item_state.is_empty() or not profile.equipment_state.is_empty():
        return false

    var catalog: EquipmentItemCatalog = STARTER_EQUIPMENT_CATALOG.build() as EquipmentItemCatalog
    if catalog == null or not catalog.validate_catalog().is_empty():
        return false
    var inventory := InventoryState.new()
    var equipment := EquipmentState.new()

    for definition_id: StringName in STARTER_EQUIPMENT_CATALOG.definition_ids_for_class(class_id):
        var definition: EquipmentItemDefinition = catalog.get_definition(definition_id)
        if definition == null:
            return false
        var slot_id: StringName = EquipmentSlotIdentityValidator.SLOT_WEAPON
        if definition.allowed_slot_ids.has(EquipmentSlotIdentityValidator.SLOT_OFF_HAND):
            slot_id = EquipmentSlotIdentityValidator.SLOT_OFF_HAND
        var item := {
            "item_instance_id": _instance_id(profile.profile_id, definition_id),
            "definition_id": definition_id,
            "quantity": 1,
            "stackable": false,
        }
        if not equipment.set_item(slot_id, item):
            return false

    var item_data := inventory.to_dictionary()
    var equipment_data := equipment.to_dictionary()
    if not InventoryState.validate_dictionary(item_data).is_empty():
        return false
    if not EquipmentState.validate_dictionary(equipment_data).is_empty():
        return false
    profile.item_state = item_data
    profile.equipment_state = equipment_data
    return true


static func _instance_id(profile_id: String, definition_id: StringName) -> StringName:
    return StringName("%s:item:%s" % [profile_id, String(definition_id)])
