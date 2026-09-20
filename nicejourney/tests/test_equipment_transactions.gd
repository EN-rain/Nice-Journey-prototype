extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_basic_equip_replace_and_persistence()
    _test_two_handed_offhand_rules_and_atomic_capacity_rejection()
    _test_class_slot_and_unique_group_rules()
    if _failures == 0:
        print("EQUIPMENT TRANSACTIONS TEST PASS")
    else:
        push_error("EQUIPMENT TRANSACTIONS TEST FAILURES: %d" % _failures)
    quit(_failures)

func _definition(definition_id: StringName, slots: Array[StringName], classes: Array[StringName], two_handed: bool = false, off_hand_allowed: bool = true, unique_group: StringName = &"") -> EquipmentItemDefinition:
    var definition := EquipmentItemDefinition.new()
    definition.definition_id = definition_id
    definition.allowed_slot_ids = slots
    definition.allowed_class_ids = classes
    definition.two_handed = two_handed
    definition.off_hand_allowed = off_hand_allowed
    definition.unique_equip_group = unique_group
    return definition

func _catalog() -> EquipmentItemCatalog:
    var catalog := EquipmentItemCatalog.new()
    catalog.definitions = [
        _definition(&"itemdef:sword", [EquipmentSlotIdentityValidator.SLOT_WEAPON], [&"melee"]),
        _definition(&"itemdef:greatsword", [EquipmentSlotIdentityValidator.SLOT_WEAPON], [&"melee"], true, false),
        _definition(&"itemdef:shield", [EquipmentSlotIdentityValidator.SLOT_OFF_HAND], [&"melee"]),
        _definition(&"itemdef:armor", [EquipmentSlotIdentityValidator.SLOT_ARMOR], [&"melee", &"ranged", &"mage"]),
        _definition(&"itemdef:ring_a", [EquipmentSlotIdentityValidator.SLOT_ACCESSORY_1, EquipmentSlotIdentityValidator.SLOT_ACCESSORY_2], [&"melee", &"ranged", &"mage"], false, true, &"unique:ring_family"),
        _definition(&"itemdef:ring_b", [EquipmentSlotIdentityValidator.SLOT_ACCESSORY_1, EquipmentSlotIdentityValidator.SLOT_ACCESSORY_2], [&"melee", &"ranged", &"mage"], false, true, &"unique:ring_family"),
    ]
    return catalog

func _gear_meta(source: String) -> Dictionary:
    return {"rarity": "common", "affixes": [], "upgrade_rank": 0, "source_claim_id": source}

func _add_gear(inventory: InventoryState, instance_id: StringName, definition_id: StringName) -> bool:
    return bool(inventory.try_add_normal(instance_id, definition_id, 1, false, _gear_meta("loot:%s" % String(instance_id).replace(":", "_"))).get("accepted", false))

func _test_basic_equip_replace_and_persistence() -> void:
    var inventory := InventoryState.new()
    var equipment := EquipmentState.new()
    var ledger := ClaimLedger.new()
    var catalog := _catalog()
    _expect(catalog.validate_catalog().is_empty(), "equipment definition catalog validates")
    _expect(_add_gear(inventory, &"item:sword_a", &"itemdef:sword"), "fixture owns first sword")
    _expect(_add_gear(inventory, &"item:sword_b", &"itemdef:sword"), "fixture owns replacement sword")

    var first := EquipmentTransactionService.equip_from_inventory(inventory, equipment, catalog, ledger, &"equip_tx:first", &"item:sword_a", EquipmentSlotIdentityValidator.SLOT_WEAPON, &"melee")
    _expect(bool(first["accepted"]), "weapon equips from normal inventory")
    _expect(inventory.get_normal_slot(&"item:sword_a").is_empty(), "equipped item leaves portable inventory ownership")
    _expect(String(equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON).get("item_instance_id", "")) == "item:sword_a", "weapon slot owns exact item instance")

    var replace := EquipmentTransactionService.equip_from_inventory(inventory, equipment, catalog, ledger, &"equip_tx:replace", &"item:sword_b", EquipmentSlotIdentityValidator.SLOT_WEAPON, &"melee")
    _expect(bool(replace["accepted"]) and int(replace["displaced_count"]) == 1, "equipping replacement atomically displaces prior occupant")
    _expect(not inventory.get_normal_slot(&"item:sword_a").is_empty(), "replaced weapon returns to portable inventory")
    _expect(String(equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON).get("item_instance_id", "")) == "item:sword_b", "replacement becomes authoritative weapon occupant")

    var duplicate_before := equipment.to_dictionary()
    var duplicate := EquipmentTransactionService.equip_from_inventory(inventory, equipment, catalog, ledger, &"equip_tx:replace", &"item:sword_a", EquipmentSlotIdentityValidator.SLOT_WEAPON, &"melee")
    _expect(not bool(duplicate["accepted"]) and duplicate["reason_id"] == EquipmentTransactionService.REASON_DUPLICATE_TRANSACTION, "duplicate equip transaction cannot repeat")
    _expect(equipment.to_dictionary() == duplicate_before, "duplicate equip leaves equipment unchanged")

    var profile := ProfileSnapshot.new()
    profile.profile_id = "profile:equipment_fixture"
    profile.protagonist_name = "Equipment Fixture"
    profile.class_id = "melee"
    profile.item_state = inventory.to_dictionary()
    profile.equipment_state = equipment.to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "profile accepts persistent equipment ownership")
    var restored := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    _expect(restored.equipment_state == profile.equipment_state, "profile round-trips equipment identity and metadata")
    var legacy := profile.to_dictionary()
    legacy.erase("equipment_state")
    _expect(ProfileSnapshot.validate_dictionary(legacy).is_empty(), "older schema-v1 snapshots without equipment_state remain backward-compatible")

func _test_two_handed_offhand_rules_and_atomic_capacity_rejection() -> void:
    var catalog := _catalog()
    var inventory := InventoryState.new()
    var equipment := EquipmentState.new()
    var ledger := ClaimLedger.new()
    _expect(_add_gear(inventory, &"item:sword", &"itemdef:sword"), "two-hand fixture owns one-handed weapon")
    _expect(_add_gear(inventory, &"item:shield", &"itemdef:shield"), "two-hand fixture owns off-hand shield")
    _expect(_add_gear(inventory, &"item:greatsword", &"itemdef:greatsword"), "two-hand fixture owns two-handed weapon")
    _expect(EquipmentTransactionService.equip_from_inventory(inventory, equipment, catalog, ledger, &"equip_tx:onehand", &"item:sword", EquipmentSlotIdentityValidator.SLOT_WEAPON, &"melee")["accepted"], "one-handed weapon equips")
    _expect(EquipmentTransactionService.equip_from_inventory(inventory, equipment, catalog, ledger, &"equip_tx:shield", &"item:shield", EquipmentSlotIdentityValidator.SLOT_OFF_HAND, &"melee")["accepted"], "off-hand equips beside compatible one-handed weapon")

    var two_hand := EquipmentTransactionService.equip_from_inventory(inventory, equipment, catalog, ledger, &"equip_tx:twohand", &"item:greatsword", EquipmentSlotIdentityValidator.SLOT_WEAPON, &"melee")
    _expect(bool(two_hand["accepted"]) and int(two_hand["displaced_count"]) == 2, "two-handed weapon atomically displaces weapon and incompatible off-hand")
    _expect(equipment.get_item(EquipmentSlotIdentityValidator.SLOT_OFF_HAND).is_empty(), "two-handed weapon clears incompatible off-hand slot")
    _expect(not inventory.get_normal_slot(&"item:sword").is_empty() and not inventory.get_normal_slot(&"item:shield").is_empty(), "both displaced items return to valid inventory disposition")

    var blocked_offhand := EquipmentTransactionService.equip_from_inventory(inventory, equipment, catalog, ledger, &"equip_tx:blocked_offhand", &"item:shield", EquipmentSlotIdentityValidator.SLOT_OFF_HAND, &"melee")
    _expect(not bool(blocked_offhand["accepted"]) and blocked_offhand["reason_id"] == EquipmentTransactionService.REASON_INCOMPATIBLE, "off-hand cannot equip beside a two-handed weapon that forbids it")

    var full_inventory := InventoryState.new()
    var full_equipment := EquipmentState.new()
    var full_ledger := ClaimLedger.new()
    _expect(_add_gear(full_inventory, &"item:full_sword", &"itemdef:sword"), "full-capacity fixture owns one-handed weapon")
    _expect(_add_gear(full_inventory, &"item:full_shield", &"itemdef:shield"), "full-capacity fixture owns shield")
    _expect(EquipmentTransactionService.equip_from_inventory(full_inventory, full_equipment, catalog, full_ledger, &"equip_tx:full_sword", &"item:full_sword", EquipmentSlotIdentityValidator.SLOT_WEAPON, &"melee")["accepted"], "full-capacity fixture equips weapon")
    _expect(EquipmentTransactionService.equip_from_inventory(full_inventory, full_equipment, catalog, full_ledger, &"equip_tx:full_shield", &"item:full_shield", EquipmentSlotIdentityValidator.SLOT_OFF_HAND, &"melee")["accepted"], "full-capacity fixture equips shield")
    _expect(_add_gear(full_inventory, &"item:full_greatsword", &"itemdef:greatsword"), "full-capacity fixture owns incoming two-handed weapon")
    for index: int in range(15):
        _expect(full_inventory.try_add_normal(StringName("item:filler_%02d" % index), StringName("itemdef:filler_%02d" % index), 1, false)["accepted"], "fills capacity fixture slot %02d" % index)
    _expect(full_inventory.normal_slots.size() == 16, "two-handed rejection fixture reaches full portable capacity")
    var inventory_before := full_inventory.to_dictionary()
    var equipment_before := full_equipment.to_dictionary()
    var rejected := EquipmentTransactionService.equip_from_inventory(full_inventory, full_equipment, catalog, full_ledger, &"equip_tx:full_twohand", &"item:full_greatsword", EquipmentSlotIdentityValidator.SLOT_WEAPON, &"melee")
    _expect(not bool(rejected["accepted"]) and rejected["reason_id"] == EquipmentTransactionService.REASON_INVENTORY_REJECTED, "two-handed replacement rejects when both displaced items cannot fit")
    _expect(full_inventory.to_dictionary() == inventory_before and full_equipment.to_dictionary() == equipment_before, "failed replacement is atomic and loses no equipment")

func _test_class_slot_and_unique_group_rules() -> void:
    var catalog := _catalog()
    var inventory := InventoryState.new()
    var equipment := EquipmentState.new()
    var ledger := ClaimLedger.new()
    _expect(_add_gear(inventory, &"item:class_sword", &"itemdef:sword"), "class fixture owns melee sword")
    var wrong_class := EquipmentTransactionService.equip_from_inventory(inventory, equipment, catalog, ledger, &"equip_tx:wrong_class", &"item:class_sword", EquipmentSlotIdentityValidator.SLOT_WEAPON, &"mage")
    _expect(not bool(wrong_class["accepted"]) and wrong_class["reason_id"] == EquipmentTransactionService.REASON_INCOMPATIBLE, "explicit class compatibility rejects wrong class")
    var wrong_slot := EquipmentTransactionService.equip_from_inventory(inventory, equipment, catalog, ledger, &"equip_tx:wrong_slot", &"item:class_sword", EquipmentSlotIdentityValidator.SLOT_ARMOR, &"melee")
    _expect(not bool(wrong_slot["accepted"]) and wrong_slot["reason_id"] == EquipmentTransactionService.REASON_INCOMPATIBLE, "explicit slot compatibility rejects wrong slot")

    _expect(_add_gear(inventory, &"item:ring_a", &"itemdef:ring_a"), "unique-group fixture owns first accessory")
    _expect(_add_gear(inventory, &"item:ring_b", &"itemdef:ring_b"), "unique-group fixture owns second accessory")
    _expect(EquipmentTransactionService.equip_from_inventory(inventory, equipment, catalog, ledger, &"equip_tx:ring_a", &"item:ring_a", EquipmentSlotIdentityValidator.SLOT_ACCESSORY_1, &"mage")["accepted"], "first declared unique accessory equips")
    var conflict := EquipmentTransactionService.equip_from_inventory(inventory, equipment, catalog, ledger, &"equip_tx:ring_b", &"item:ring_b", EquipmentSlotIdentityValidator.SLOT_ACCESSORY_2, &"mage")
    _expect(not bool(conflict["accepted"]) and conflict["reason_id"] == EquipmentTransactionService.REASON_UNIQUE_CONFLICT, "item-definition unique group prevents prohibited duplicate accessory family")

    var unequip := EquipmentTransactionService.unequip_to_inventory(inventory, equipment, ledger, &"equip_tx:unequip_ring", EquipmentSlotIdentityValidator.SLOT_ACCESSORY_1)
    _expect(bool(unequip["accepted"]), "equipped item can unequip to normal inventory when capacity exists")
    _expect(equipment.get_item(EquipmentSlotIdentityValidator.SLOT_ACCESSORY_1).is_empty() and not inventory.get_normal_slot(&"item:ring_a").is_empty(), "unequip preserves exact item identity")

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
