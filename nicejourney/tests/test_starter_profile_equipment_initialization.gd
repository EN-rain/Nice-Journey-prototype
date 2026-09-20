extends SceneTree

const STARTER_EQUIPMENT_CATALOG_SCRIPT: Script = preload("res://src/items/starter_equipment_catalog.gd")
const STARTER_INITIALIZER_SCRIPT: Script = preload("res://src/items/starter_inventory_initialization_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _expect(STARTER_EQUIPMENT_CATALOG_SCRIPT.build().validate_catalog().is_empty(), "locked starter equipment catalog validates")
    _test_class("melee", StarterKitCatalog.WEAPON_MELEE_SWORD, StarterKitCatalog.OFF_HAND_MELEE_SHIELD)
    _test_class("ranged", StarterKitCatalog.WEAPON_RANGED_BOW, &"")
    _test_class("mage", StarterKitCatalog.WEAPON_MAGE_STAFF, &"")
    _test_creation_only_boundary()

    if _failures == 0:
        print("STARTER PROFILE EQUIPMENT INITIALIZATION TEST PASS")
    else:
        push_error("STARTER PROFILE EQUIPMENT INITIALIZATION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_class(class_id: String, expected_weapon: StringName, expected_off_hand: StringName) -> void:
    var profile := ProfileCreationService.create_profile(1, "Starter %s" % class_id, class_id)
    _expect(profile != null, "%s new profile initializes starter ownership" % class_id)
    if profile == null:
        return
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "%s initialized profile remains persistence-valid" % class_id)

    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "%s starter inventory state loads" % class_id)
    _expect(inventory.normal_slots.is_empty(), "%s starts with no fabricated normal inventory stacks" % class_id)
    _expect(inventory.gold == 0, "%s starter ownership invents no Gold" % class_id)
    _expect(inventory.protected_items.is_empty(), "%s starter ownership invents no quest/key items" % class_id)
    _expect(inventory.quick_slots == [&"", &"", &"", &""], "%s starter ownership keeps all four consumable references empty" % class_id)

    var equipment := EquipmentState.new()
    _expect(equipment.load_dictionary(profile.equipment_state).is_empty(), "%s starter equipment state loads" % class_id)
    var weapon := equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON)
    _expect(StringName(weapon.get("definition_id", &"")) == expected_weapon, "%s weapon slot preserves the locked DR-04 starter definition" % class_id)
    _expect(StringName(weapon.get("item_instance_id", &"")) == StringName("%s:item:%s" % [profile.profile_id, String(expected_weapon)]), "%s starter weapon instance identity is deterministic per profile" % class_id)
    _expect(int(weapon.get("quantity", 0)) == 1 and not bool(weapon.get("stackable", true)), "%s starter weapon is one nonstackable owned item" % class_id)
    _expect(not weapon.has("rarity") and not weapon.has("affixes") and not weapon.has("upgrade_rank"), "%s starter persistence invents no rarity/affix/upgrade metadata" % class_id)

    var off_hand := equipment.get_item(EquipmentSlotIdentityValidator.SLOT_OFF_HAND)
    if expected_off_hand == &"":
        _expect(off_hand.is_empty(), "%s starter kit keeps the locked empty off-hand" % class_id)
    else:
        _expect(StringName(off_hand.get("definition_id", &"")) == expected_off_hand, "%s off-hand preserves the locked DR-04 starter definition" % class_id)
    _expect(equipment.get_item(EquipmentSlotIdentityValidator.SLOT_ARMOR).is_empty(), "%s starter ownership invents no armor item" % class_id)
    _expect(equipment.get_item(EquipmentSlotIdentityValidator.SLOT_ACCESSORY_1).is_empty(), "%s starter ownership invents no accessory 1 item" % class_id)
    _expect(equipment.get_item(EquipmentSlotIdentityValidator.SLOT_ACCESSORY_2).is_empty(), "%s starter ownership invents no accessory 2 item" % class_id)

    var restored := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    _expect(restored.item_state == profile.item_state and restored.equipment_state == profile.equipment_state, "%s starter inventory/equipment ownership round-trips exactly" % class_id)


func _test_creation_only_boundary() -> void:
    var profile := ProfileSnapshot.new()
    profile.profile_id = "profile:legacy_fixture"
    profile.protagonist_name = "Legacy"
    profile.class_id = "melee"
    var existing_inventory := InventoryState.new()
    _expect(bool(existing_inventory.try_add_normal(&"item:existing", &"definition:existing", 1, false).get("accepted", false)), "creation-only fixture owns an existing normal item")
    profile.item_state = existing_inventory.to_dictionary()
    _expect(not bool(STARTER_INITIALIZER_SCRIPT.initialize_new_profile(profile)), "starter initializer refuses to rewrite a nonempty legacy/existing item state")
    _expect(profile.equipment_state.is_empty(), "rejected initialization does not partially create equipment state")
    var restored := InventoryState.new()
    _expect(restored.load_dictionary(profile.item_state).is_empty() and restored.get_normal_slot(&"item:existing").get("definition_id", &"") == &"definition:existing", "rejected initialization preserves existing item ownership exactly")


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
