extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Inventory Mutations", "melee")
    _expect(profile != null, "profile fixture creates")
    var catalog: EquipmentItemCatalog = StarterEquipmentCatalog.build()
    var equipment := EquipmentState.new()
    _expect(equipment.load_dictionary(profile.equipment_state).is_empty(), "starter equipment loads")
    var starter_weapon: Dictionary = equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON)
    var starter_instance := StringName(String(starter_weapon.get("item_instance_id", &"")))

    var unequip := ProfileInventoryMutationService.unequip(
        profile,
        &"transaction:profile_inventory:unequip",
        EquipmentSlotIdentityValidator.SLOT_WEAPON
    )
    _expect(bool(unequip.get("accepted", false)) and not bool(unequip.get("durable", true)), "profile-level unequip commits as live unbanked mutation")
    var inventory := InventoryState.new()
    equipment = EquipmentState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty() and equipment.load_dictionary(profile.equipment_state).is_empty(), "unequip leaves valid inventory/equipment state")
    _expect(not inventory.get_normal_slot(starter_instance).is_empty() and equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON).is_empty(), "unequip preserves exact starter item identity in inventory")

    var equip := ProfileInventoryMutationService.equip(
        profile,
        catalog,
        &"transaction:profile_inventory:equip",
        starter_instance,
        EquipmentSlotIdentityValidator.SLOT_WEAPON
    )
    _expect(bool(equip.get("accepted", false)), "profile-level equip delegates to authoritative equipment transaction")
    inventory = InventoryState.new()
    equipment = EquipmentState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty() and equipment.load_dictionary(profile.equipment_state).is_empty(), "equip leaves valid inventory/equipment state")
    _expect(inventory.get_normal_slot(starter_instance).is_empty() and StringName(String(equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON).get("item_instance_id", &""))) == starter_instance, "equip atomically moves exact instance into fixed equipment slot")

    _expect(inventory.try_add_normal(&"item:test_consumable", &"itemdef:test_consumable", 3, true).get("accepted", false), "quick-slot fixture owns a normal stack")
    _expect(inventory.try_add_normal(&"item:test_material", &"itemdef:test_material", 2, true).get("accepted", false), "quick-slot fixture owns a normal material stack")
    profile.item_state = inventory.to_dictionary()
    var category_catalog := ItemCategoryCatalog.new()
    category_catalog.definition_categories = {
        "itemdef:test_consumable": ItemCategoryCatalog.CATEGORY_CONSUMABLE,
        "itemdef:test_material": ItemCategoryCatalog.CATEGORY_MATERIAL,
    }
    _expect(category_catalog.validate_catalog().is_empty(), "quick-slot category fixture validates explicit authored categories")

    var missing_authority := ProfileInventoryMutationService.bind_quick_slot(
        profile,
        &"transaction:profile_inventory:quick_missing_authority",
        2,
        &"item:test_consumable"
    )
    _expect(
        not bool(missing_authority.get("accepted", true))
        and missing_authority.get("reason_id", &"") == ProfileInventoryMutationService.REASON_CATEGORY_AUTHORITY_MISSING,
        "new quick-slot binding fails closed without category authority even for consumable-looking IDs"
    )

    var material_reject := ProfileInventoryMutationService.bind_quick_slot(
        profile,
        &"transaction:profile_inventory:quick_material_reject",
        2,
        &"item:test_material",
        category_catalog
    )
    _expect(
        not bool(material_reject.get("accepted", true))
        and material_reject.get("reason_id", &"") == ProfileInventoryMutationService.REASON_ITEM_NOT_CONSUMABLE,
        "authored material ownership cannot be bound to a consumable quick slot"
    )

    var bind := ProfileInventoryMutationService.bind_quick_slot(
        profile,
        &"transaction:profile_inventory:quick_bind",
        2,
        &"item:test_consumable",
        category_catalog
    )
    _expect(bool(bind.get("accepted", false)) and bool(bind.get("reference_only", false)) and bool(bind.get("consumable_category_validated", false)), "quick-slot assignment persists only an authored consumable ownership reference")
    inventory = InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty() and inventory.quick_slots[2] == &"item:test_consumable", "quick-slot assignment persists exact referenced instance")

    var before_duplicate := profile.to_dictionary()
    var duplicate := ProfileInventoryMutationService.bind_quick_slot(
        profile,
        &"transaction:profile_inventory:quick_bind",
        2,
        &""
    )
    _expect(not bool(duplicate.get("accepted", true)) and duplicate.get("reason_id", &"") == ProfileInventoryMutationService.REASON_DUPLICATE_TRANSACTION, "repeated quick-slot transaction ID is rejected")
    _expect(profile.to_dictionary() == before_duplicate, "duplicate quick-slot assignment is non-mutating")

    var clear := ProfileInventoryMutationService.bind_quick_slot(
        profile,
        &"transaction:profile_inventory:quick_clear",
        2,
        &""
    )
    _expect(bool(clear.get("accepted", false)), "quick-slot reference can be cleared explicitly")
    inventory = InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty() and inventory.quick_slots[2] == &"", "quick-slot clear persists empty reference")

    var legacy := InventoryState.new()
    _expect(legacy.try_add_normal(&"item:legacy_material", &"itemdef:legacy_material", 1, true).get("accepted", false), "legacy quick-slot fixture owns arbitrary normal item")
    _expect(legacy.bind_quick_slot(0, &"item:legacy_material"), "legacy low-level state can represent a historical quick reference")
    var legacy_roundtrip := InventoryState.new()
    _expect(legacy_roundtrip.load_dictionary(legacy.to_dictionary()).is_empty() and legacy_roundtrip.quick_slots[0] == &"item:legacy_material", "legacy persisted owned quick references remain load-compatible without retroactive category inference")
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "all profile-level inventory mutations preserve whole-profile validity")

    if _failures == 0:
        print("PROFILE INVENTORY MUTATION SERVICE TEST PASS")
    else:
        push_error("PROFILE INVENTORY MUTATION SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
