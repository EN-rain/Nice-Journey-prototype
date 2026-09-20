extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    for class_id: String in ["melee", "ranged", "mage"]:
        await _check_class(class_id)
    if _failures == 0:
        print("GAMEPLAY EQUIPMENT ATTACK PLAYTEST TEST PASS")
    else:
        push_error("GAMEPLAY EQUIPMENT ATTACK PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _check_class(class_id: String) -> void:
    var profile := ProfileCreationService.create_profile(1, "Equipment " + class_id, class_id)
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    root.add_child(game)
    await process_frame
    var runtime := game.combat_runtime
    var tuning := runtime.equipment_playtest_tuning
    _expect(tuning != null and tuning.playtest_placeholder and tuning.validate_tuning().is_empty(), "%s uses the Inspector-assigned playtest weapon tuning" % class_id)
    var base_payload := runtime.make_basic_attack_payload()
    var base_damage := float(base_payload.get("raw_damage", -1.0))
    _expect(base_damage >= 0.0 and is_zero_approx(runtime.get_playtest_weapon_attack_bonus()), "%s unupgraded starter weapon has no artificial bonus" % class_id)
    var upgraded := profile.equipment_state.duplicate(true)
    var slots := upgraded["slots"] as Dictionary
    var weapon := slots[String(EquipmentSlotIdentityValidator.SLOT_WEAPON)] as Dictionary
    weapon["upgrade_rank"] = 1
    _expect(EquipmentState.validate_dictionary(upgraded).is_empty() and runtime.bind_equipment_state(upgraded), "%s upgraded weapon remains a valid profile equipment record" % class_id)
    _expect(is_equal_approx(runtime.get_playtest_weapon_attack_bonus(), 1.0), "%s one Blacksmith attack_power rank grants the Inspector-authored +1 bonus" % class_id)
    _expect(is_equal_approx(float(runtime.make_basic_attack_payload().get("raw_damage", -1.0)), base_damage + 1.0), "%s equipped upgrade changes actual basic-hit resolver payload" % class_id)
    weapon["upgrade_rank"] = 2
    _expect(runtime.bind_equipment_state(upgraded), "%s persisted higher-rank equipment shape remains compatible" % class_id)
    _expect(is_zero_approx(runtime.get_playtest_weapon_attack_bonus()), "%s unavailable rank-two recipe cannot manufacture an unapproved live attack bonus" % class_id)
    _expect(runtime.bind_equipment_state(profile.equipment_state), "%s original equipped item can be restored without changes" % class_id)
    _expect(is_equal_approx(float(runtime.make_basic_attack_payload().get("raw_damage", -1.0)), base_damage), "%s unupgraded equipment restores the exact original damage" % class_id)
    var empty := EquipmentState.new().to_dictionary()
    _expect(runtime.bind_equipment_state(empty) and runtime.make_basic_attack_payload().is_empty(), "%s no equipped starter weapon cannot attack for free" % class_id)
    _expect(is_zero_approx(runtime.get_playtest_weapon_attack_bonus()), "%s unequipping removes upgrade attack power immediately" % class_id)
    game.queue_free()
    await process_frame


func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
