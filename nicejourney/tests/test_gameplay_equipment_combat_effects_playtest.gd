extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    for class_id: String in ["melee", "ranged", "mage"]:
        await _check_class(class_id)
    if _failures == 0:
        print("GAMEPLAY EQUIPMENT COMBAT EFFECTS PLAYTEST TEST PASS")
    else:
        push_error("GAMEPLAY EQUIPMENT COMBAT EFFECTS PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _check_class(class_id: String) -> void:
    var profile := ProfileCreationService.create_profile(1, "Equipment Combat " + class_id, class_id)
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    root.add_child(game)
    await process_frame
    var runtime := game.combat_runtime
    var equipment := EquipmentState.new()
    _expect(equipment.load_dictionary(profile.equipment_state).is_empty(), "%s has valid persisted starter equipment" % class_id)
    var equipped_weapon := equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON)
    var weapon_id := StringName(String(equipped_weapon.get("item_instance_id", &"")))
    _expect(runtime.has_usable_starter_weapon() and runtime.request_basic_attack(Vector2.RIGHT), "%s can attack with its equipped starter weapon" % class_id)
    runtime.action_state_machine.force_interrupt(&"test:equipment_swap")
    var removed := game.request_inventory_unequip(EquipmentSlotIdentityValidator.SLOT_WEAPON)
    _expect(bool(removed.get("accepted", false)), "%s unequips the real weapon through the existing inventory transaction" % class_id)
    _expect(not runtime.has_usable_starter_weapon() and not runtime.request_basic_attack(Vector2.RIGHT), "%s cannot attack without its equipped weapon" % class_id)
    _expect(runtime.make_basic_attack_payload().is_empty() and not bool(game.request_active_skill_slot(0).get("accepted", true)), "%s cannot fabricate weapon contact or active skill attacks after unequipping" % class_id)
    _expect(equipment.load_dictionary(profile.equipment_state).is_empty() and equipment.get_item(EquipmentSlotIdentityValidator.SLOT_WEAPON).is_empty(), "%s persistent weapon slot was actually emptied" % class_id)
    var replaced := game.request_inventory_equip(weapon_id, EquipmentSlotIdentityValidator.SLOT_WEAPON)
    _expect(bool(replaced.get("accepted", false)) and runtime.has_usable_starter_weapon(), "%s reequipping the original weapon immediately restores attack admission" % class_id)
    _expect(runtime.request_basic_attack(Vector2.RIGHT), "%s can attack after the actual inventory transaction restores its weapon" % class_id)
    runtime.action_state_machine.force_interrupt(&"test:equipment_swap")
    if class_id == "melee":
        var off_hand := equipment.get_item(EquipmentSlotIdentityValidator.SLOT_OFF_HAND)
        var shield_id := StringName(String(off_hand.get("item_instance_id", &"")))
        _expect(runtime.supports_block() and runtime.supports_parry(), "Melee shield provides real block and parry admission")
        _expect(runtime.request_block(true), "Melee can enter block with the shield equipped")
        var unequipped := game.request_inventory_unequip(EquipmentSlotIdentityValidator.SLOT_OFF_HAND)
        _expect(bool(unequipped.get("accepted", false)), "real shield unequip transaction succeeds")
        _expect(not runtime.supports_block() and not runtime.supports_parry(), "shield removal disables both defenses")
        _expect(runtime.get_defense_mode() == DirectHitResolver.DEFENSE_NONE, "removing shield while blocking closes the active block immediately")
        _expect(not runtime.request_block(true) and not runtime.request_parry(), "shieldless character cannot block or parry")
        var reequipped := game.request_inventory_equip(shield_id, EquipmentSlotIdentityValidator.SLOT_OFF_HAND)
        _expect(bool(reequipped.get("accepted", false)) and runtime.supports_block() and runtime.supports_parry(), "restoring shield re-enables both defense actions")
    else:
        _expect(not runtime.supports_block() and not runtime.supports_parry(), "%s class does not gain a fabricated shield" % class_id)
    game.queue_free()
    await process_frame


func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
