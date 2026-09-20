extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var valid_entries: Array = _valid_entries()
    var before_validation: Array = valid_entries.duplicate(true)
    _expect(PrototypeTowerFloorCatalogValidator.validate_entries(valid_entries).is_empty(), "valid shuffled floor catalog satisfies the locked 1..10 identity contract")
    _expect(valid_entries == before_validation, "floor catalog validation does not mutate caller-supplied entries")

    _expect(_contains(PrototypeTowerFloorCatalogValidator.validate_entries("bad"), "entries must be an array"), "top-level non-array input is rejected")

    var wrong_entry_type: Array = _valid_entries()
    wrong_entry_type[9] = "not-a-dictionary"
    var wrong_entry_errors: PackedStringArray = PrototypeTowerFloorCatalogValidator.validate_entries(wrong_entry_type)
    _expect(_contains(wrong_entry_errors, "entries[9] must be a dictionary"), "wrong-type floor entries are rejected")
    _expect(_contains(wrong_entry_errors, "missing floor_id 10"), "wrong-type replacement reports the missing floor identity")

    var nine_entries: Array = _valid_entries()
    nine_entries.pop_back()
    var nine_errors: PackedStringArray = PrototypeTowerFloorCatalogValidator.validate_entries(nine_entries)
    _expect(_contains(nine_errors, "entries must contain exactly 10 tower floors"), "nine-entry catalog is rejected")
    _expect(_contains(nine_errors, "missing floor_id 10"), "nine-entry catalog reports its missing floor")

    var eleven_entries: Array = _valid_entries()
    eleven_entries.append({"floor_id": 10})
    _expect(_contains(PrototypeTowerFloorCatalogValidator.validate_entries(eleven_entries), "entries must contain exactly 10 tower floors"), "eleven-entry catalog is rejected")

    var missing_id: Array = _valid_entries()
    (missing_id[0] as Dictionary).erase("floor_id")
    var missing_id_errors: PackedStringArray = PrototypeTowerFloorCatalogValidator.validate_entries(missing_id)
    _expect(_contains(missing_id_errors, "entries[0]: missing floor_id"), "missing floor IDs are rejected")
    _expect(_contains(missing_id_errors, "missing floor_id 4"), "missing ID field cannot silently satisfy required floor coverage")

    var non_int_id: Array = _valid_entries()
    (non_int_id[1] as Dictionary)["floor_id"] = 1.0
    var non_int_errors: PackedStringArray = PrototypeTowerFloorCatalogValidator.validate_entries(non_int_id)
    _expect(_contains(non_int_errors, "entries[1]: floor_id must be an integer"), "non-integer floor IDs are rejected")
    _expect(_contains(non_int_errors, "missing floor_id 1"), "non-integer replacement reports the missing stable floor identity")

    var out_of_range: Array = _valid_entries()
    (out_of_range[2] as Dictionary)["floor_id"] = 11
    var range_errors: PackedStringArray = PrototypeTowerFloorCatalogValidator.validate_entries(out_of_range)
    _expect(_contains(range_errors, "entries[2]: floor_id must be between 1 and 10"), "out-of-range floor IDs are rejected")
    _expect(_contains(range_errors, "missing floor_id 7"), "out-of-range replacement reports the missing prototype floor")

    var duplicate_id: Array = _valid_entries()
    (duplicate_id[9] as Dictionary)["floor_id"] = 9
    var duplicate_errors: PackedStringArray = PrototypeTowerFloorCatalogValidator.validate_entries(duplicate_id)
    _expect(_contains(duplicate_errors, "entries[9]: duplicate floor_id 9"), "duplicate floor IDs are rejected")
    _expect(_contains(duplicate_errors, "missing floor_id 10"), "duplicate replacement reports the now-missing floor")

    var omitted_names: Array = _valid_entries(false)
    _expect(PrototypeTowerFloorCatalogValidator.validate_entries(omitted_names).is_empty(), "presentation names may be omitted")

    var renamed_names: Array = _valid_entries()
    (renamed_names[0] as Dictionary)["name"] = &"Any Floor Label"
    (renamed_names[1] as Dictionary)["name"] = "Renamed"
    (renamed_names[2] as Dictionary)["name"] = ""
    _expect(PrototypeTowerFloorCatalogValidator.validate_entries(renamed_names).is_empty(), "presentation names are non-authoritative")

    var wrong_name_type: Array = _valid_entries()
    (wrong_name_type[0] as Dictionary)["name"] = 4
    _expect(_contains(PrototypeTowerFloorCatalogValidator.validate_entries(wrong_name_type), "entries[0]: name must be a string when present"), "malformed optional presentation names are rejected")

    var deterministic_fixture: Array = _valid_entries()
    (deterministic_fixture[0] as Dictionary)["floor_id"] = 11
    (deterministic_fixture[9] as Dictionary)["floor_id"] = 9
    var first_errors: PackedStringArray = PrototypeTowerFloorCatalogValidator.validate_entries(deterministic_fixture)
    var second_errors: PackedStringArray = PrototypeTowerFloorCatalogValidator.validate_entries(deterministic_fixture)
    _expect(first_errors == second_errors, "validation errors are deterministic for identical caller input")

    if _failures == 0:
        print("PROTOTYPE TOWER FLOOR CATALOG TEST PASS")
    else:
        push_error("PROTOTYPE TOWER FLOOR CATALOG TEST FAILURES: %d" % _failures)
    quit(_failures)

func _valid_entries(include_names: bool = true) -> Array:
    var ordered_floor_ids: Array[int] = [4, 1, 7, 2, 9, 3, 6, 5, 8, 10]
    var entries: Array = []
    for floor_id: int in ordered_floor_ids:
        var entry: Dictionary = {"floor_id": floor_id}
        if include_names:
            entry["name"] = "Floor %d" % floor_id
        entries.append(entry)
    return entries

func _contains(errors: PackedStringArray, expected: String) -> bool:
    return errors.has(expected)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
