class_name StarterEquipmentCatalog
extends RefCounted


static func build() -> EquipmentItemCatalog:
    var catalog := EquipmentItemCatalog.new()
    catalog.definitions = [
        _definition(
            StarterKitCatalog.WEAPON_MELEE_SWORD,
            [EquipmentSlotIdentityValidator.SLOT_WEAPON],
            [&"melee"],
            false,
            true
        ),
        _definition(
            StarterKitCatalog.OFF_HAND_MELEE_SHIELD,
            [EquipmentSlotIdentityValidator.SLOT_OFF_HAND],
            [&"melee"],
            false,
            true
        ),
        _definition(
            StarterKitCatalog.WEAPON_RANGED_BOW,
            [EquipmentSlotIdentityValidator.SLOT_WEAPON],
            [&"ranged"],
            true,
            false
        ),
        _definition(
            StarterKitCatalog.WEAPON_MAGE_STAFF,
            [EquipmentSlotIdentityValidator.SLOT_WEAPON],
            [&"mage"],
            true,
            false
        ),
    ]
    return catalog


static func definition_ids_for_class(class_id: StringName) -> Array[StringName]:
    match class_id:
        &"melee":
            return [StarterKitCatalog.WEAPON_MELEE_SWORD, StarterKitCatalog.OFF_HAND_MELEE_SHIELD]
        &"ranged":
            return [StarterKitCatalog.WEAPON_RANGED_BOW]
        &"mage":
            return [StarterKitCatalog.WEAPON_MAGE_STAFF]
        _:
            return []


static func _definition(
    definition_id: StringName,
    slots: Array[StringName],
    classes: Array[StringName],
    two_handed: bool,
    off_hand_allowed: bool
) -> EquipmentItemDefinition:
    var definition := EquipmentItemDefinition.new()
    definition.definition_id = definition_id
    definition.allowed_slot_ids = slots.duplicate()
    definition.allowed_class_ids = classes.duplicate()
    definition.two_handed = two_handed
    definition.off_hand_allowed = off_hand_allowed
    return definition
