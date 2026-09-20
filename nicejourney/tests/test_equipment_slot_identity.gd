extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var valid_entries: Array = _valid_entries()
    var before_validation: Array = valid_entries.duplicate(true)
    _expect(EquipmentSlotIdentityValidator.validate_entries(valid_entries).is_empty(), "valid equipment slots pass regardless of descriptor order")
    _expect(valid_entries == before_validation, "equipment-slot validation does not mutate caller-supplied entries")

    _expect(_contains(EquipmentSlotIdentityValidator.validate_entries("bad"), "entries must be an array"), "top-level non-array input is rejected")

    var wrong_entry_type: Array = _valid_entries()
    wrong_entry_type[4] = "not-a-dictionary"
    var wrong_entry_errors: PackedStringArray = EquipmentSlotIdentityValidator.validate_entries(wrong_entry_type)
    _expect(_contains(wrong_entry_errors, "entries[4] must be a dictionary"), "wrong-type descriptors are rejected")
    _expect(_contains(wrong_entry_errors, "missing slot_id armor"), "wrong-type replacement reports its missing slot identity")

    var four_entries: Array = _valid_entries()
    four_entries.pop_back()
    var four_errors: PackedStringArray = EquipmentSlotIdentityValidator.validate_entries(four_entries)
    _expect(_contains(four_errors, "entries must contain exactly 5 equipment slots"), "four descriptors are rejected")
    _expect(_contains(four_errors, "missing slot_id armor"), "four-descriptor set reports its missing slot")

    var six_entries: Array = _valid_entries()
    six_entries.append({"slot_id": EquipmentSlotIdentityValidator.SLOT_WEAPON})
    _expect(_contains(EquipmentSlotIdentityValidator.validate_entries(six_entries), "entries must contain exactly 5 equipment slots"), "six descriptors are rejected")

    var missing_id: Array = _valid_entries()
    (missing_id[0] as Dictionary).erase("slot_id")
    var missing_id_errors: PackedStringArray = EquipmentSlotIdentityValidator.validate_entries(missing_id)
    _expect(_contains(missing_id_errors, "entries[0]: missing slot_id"), "missing slot IDs are rejected")
    _expect(_contains(missing_id_errors, "missing slot_id accessory_2"), "missing ID field cannot silently satisfy required slot coverage")

    var wrong_id_type: Array = _valid_entries()
    (wrong_id_type[0] as Dictionary)["slot_id"] = 5
    _expect(_contains(EquipmentSlotIdentityValidator.validate_entries(wrong_id_type), "entries[0]: slot_id must be a string"), "wrong-type slot IDs are rejected")

    var unknown_id: Array = _valid_entries()
    (unknown_id[0] as Dictionary)["slot_id"] = &"helmet"
    var unknown_errors: PackedStringArray = EquipmentSlotIdentityValidator.validate_entries(unknown_id)
    _expect(_contains(unknown_errors, "entries[0]: unknown slot_id helmet"), "unknown slot IDs are rejected")
    _expect(_contains(unknown_errors, "missing slot_id accessory_2"), "unknown replacement reports the required missing slot")

    var duplicate_accessory: Array = _valid_entries()
    (duplicate_accessory[0] as Dictionary)["slot_id"] = EquipmentSlotIdentityValidator.SLOT_ACCESSORY_1
    var duplicate_errors: PackedStringArray = EquipmentSlotIdentityValidator.validate_entries(duplicate_accessory)
    _expect(_contains(duplicate_errors, "entries[2]: duplicate slot_id accessory_1"), "duplicate accessory_1 is rejected")
    _expect(_contains(duplicate_errors, "missing slot_id accessory_2"), "duplicate accessory_1 replacement reports missing accessory_2")

    var omitted_names: Array = _valid_entries(false)
    _expect(EquipmentSlotIdentityValidator.validate_entries(omitted_names).is_empty(), "presentation names may be omitted")

    var renamed_names: Array = _valid_entries()
    (renamed_names[0] as Dictionary)["name"] = &"Any Second Accessory Label"
    (renamed_names[1] as Dictionary)["name"] = "Primary Hand Label"
    (renamed_names[2] as Dictionary)["name"] = ""
    _expect(EquipmentSlotIdentityValidator.validate_entries(renamed_names).is_empty(), "presentation names are non-authoritative strings")

    var wrong_name_type: Array = _valid_entries()
    (wrong_name_type[1] as Dictionary)["name"] = 1
    _expect(_contains(EquipmentSlotIdentityValidator.validate_entries(wrong_name_type), "entries[1]: name must be a string when present"), "malformed optional presentation names are rejected")

    var deterministic_fixture: Array = _valid_entries()
    (deterministic_fixture[0] as Dictionary)["slot_id"] = &"unknown_slot"
    (deterministic_fixture[4] as Dictionary)["slot_id"] = EquipmentSlotIdentityValidator.SLOT_WEAPON
    var first_errors: PackedStringArray = EquipmentSlotIdentityValidator.validate_entries(deterministic_fixture)
    var second_errors: PackedStringArray = EquipmentSlotIdentityValidator.validate_entries(deterministic_fixture)
    _expect(first_errors == second_errors, "validation errors are deterministic for identical caller input")

    if _failures == 0:
        print("EQUIPMENT SLOT IDENTITY TEST PASS")
    else:
        push_error("EQUIPMENT SLOT IDENTITY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _valid_entries(include_names: bool = true) -> Array:
    var entries: Array = [
        {"slot_id": EquipmentSlotIdentityValidator.SLOT_ACCESSORY_2},
        {"slot_id": EquipmentSlotIdentityValidator.SLOT_WEAPON},
        {"slot_id": EquipmentSlotIdentityValidator.SLOT_ACCESSORY_1},
        {"slot_id": EquipmentSlotIdentityValidator.SLOT_OFF_HAND},
        {"slot_id": EquipmentSlotIdentityValidator.SLOT_ARMOR},
    ]
    if include_names:
        (entries[0] as Dictionary)["name"] = "Accessory 2"
        (entries[1] as Dictionary)["name"] = &"Weapon"
        (entries[2] as Dictionary)["name"] = "Accessory 1"
        (entries[3] as Dictionary)["name"] = "Off-hand"
        (entries[4] as Dictionary)["name"] = "Armor"
    return entries

func _contains(errors: PackedStringArray, expected: String) -> bool:
    return errors.has(expected)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
