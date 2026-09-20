extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var valid_entries: Array = _valid_entries()
    var before_validation: Array = valid_entries.duplicate(true)
    _expect(WorldRegionCatalogValidator.validate_entries(valid_entries).is_empty(), "valid 12-region catalog satisfies the locked prototype region-state contract")
    _expect(valid_entries == before_validation, "catalog validation does not mutate caller-supplied entries")

    _expect(_contains(WorldRegionCatalogValidator.validate_entries("bad"), "entries must be an array"), "top-level non-array input is rejected")

    var wrong_entry_type: Array = _valid_entries()
    wrong_entry_type[11] = "not-a-dictionary"
    var wrong_entry_errors: PackedStringArray = WorldRegionCatalogValidator.validate_entries(wrong_entry_type)
    _expect(_contains(wrong_entry_errors, "entries[11] must be a dictionary"), "wrong-type catalog entries are rejected")
    _expect(_contains(wrong_entry_errors, "missing region_id 12"), "wrong-type entry cannot silently satisfy required region coverage")

    var wrong_id_type: Array = _valid_entries()
    (wrong_id_type[0] as Dictionary)["region_id"] = 1.0
    var wrong_id_type_errors: PackedStringArray = WorldRegionCatalogValidator.validate_entries(wrong_id_type)
    _expect(_contains(wrong_id_type_errors, "entries[0]: region_id must be an integer"), "non-integer region IDs are rejected")
    _expect(_contains(wrong_id_type_errors, "missing region_id 1"), "wrong-type region ID reports the missing stable numeric identity")

    var missing_id_field: Array = _valid_entries()
    (missing_id_field[0] as Dictionary).erase("region_id")
    _expect(_contains(WorldRegionCatalogValidator.validate_entries(missing_id_field), "entries[0]: missing region_id"), "missing region ID fields are rejected")

    var out_of_range: Array = _valid_entries()
    (out_of_range[11] as Dictionary)["region_id"] = 13
    var range_errors: PackedStringArray = WorldRegionCatalogValidator.validate_entries(out_of_range)
    _expect(_contains(range_errors, "entries[11]: region_id must be between 1 and 12"), "out-of-range region IDs are rejected")
    _expect(_contains(range_errors, "missing region_id 12"), "out-of-range replacement reports missing locked region identity")

    var duplicate_id: Array = _valid_entries()
    (duplicate_id[11] as Dictionary)["region_id"] = 11
    var duplicate_errors: PackedStringArray = WorldRegionCatalogValidator.validate_entries(duplicate_id)
    _expect(_contains(duplicate_errors, "entries[11]: duplicate region_id 11"), "duplicate region IDs are rejected")
    _expect(_contains(duplicate_errors, "missing region_id 12"), "duplicate replacement reports missing locked region identity")

    var missing_entry: Array = _valid_entries()
    missing_entry.pop_back()
    var missing_entry_errors: PackedStringArray = WorldRegionCatalogValidator.validate_entries(missing_entry)
    _expect(_contains(missing_entry_errors, "entries must contain exactly 12 regions"), "11-entry catalog is rejected")
    _expect(_contains(missing_entry_errors, "missing region_id 12"), "11-entry catalog reports the missing region identity")

    var extra_entry: Array = _valid_entries()
    extra_entry.append({"region_id": 12, "state": WorldRegionCatalogValidator.STATE_FUTURE_LOCKED})
    _expect(_contains(WorldRegionCatalogValidator.validate_entries(extra_entry), "entries must contain exactly 12 regions"), "13-entry catalog is rejected")

    var wrong_region3_state: Array = _valid_entries()
    (wrong_region3_state[2] as Dictionary)["state"] = WorldRegionCatalogValidator.STATE_FUTURE_LOCKED
    _expect(_contains(WorldRegionCatalogValidator.validate_entries(wrong_region3_state), "entries[2]: region 3 state must be prototype_starting_region"), "Region 3 must retain the locked prototype-starting state")

    var non3_starting: Array = _valid_entries()
    (non3_starting[0] as Dictionary)["state"] = WorldRegionCatalogValidator.STATE_PROTOTYPE_STARTING_REGION
    _expect(_contains(WorldRegionCatalogValidator.validate_entries(non3_starting), "entries[0]: region 1 state must be future_locked"), "non-3 region cannot be marked prototype-starting")

    var non3_playable: Array = _valid_entries()
    (non3_playable[3] as Dictionary)["state"] = &"playable"
    _expect(_contains(WorldRegionCatalogValidator.validate_entries(non3_playable), "entries[3]: region 4 state must be future_locked"), "non-3 region cannot be marked playable")

    var non3_unlocked: Array = _valid_entries()
    (non3_unlocked[4] as Dictionary)["state"] = &"unlocked"
    _expect(_contains(WorldRegionCatalogValidator.validate_entries(non3_unlocked), "entries[4]: region 5 state must be future_locked"), "non-3 region cannot be marked unlocked")

    var missing_state: Array = _valid_entries()
    (missing_state[2] as Dictionary).erase("state")
    _expect(_contains(WorldRegionCatalogValidator.validate_entries(missing_state), "entries[2]: missing state"), "region state is required")

    var wrong_state_type: Array = _valid_entries()
    (wrong_state_type[2] as Dictionary)["state"] = 3
    _expect(_contains(WorldRegionCatalogValidator.validate_entries(wrong_state_type), "entries[2]: state must be a string"), "wrong-type region state is rejected")

    var empty_state: Array = _valid_entries()
    (empty_state[2] as Dictionary)["state"] = ""
    _expect(_contains(WorldRegionCatalogValidator.validate_entries(empty_state), "entries[2]: state must not be empty"), "empty region state is rejected instead of bypassing the exact prototype-state contract")

    var omitted_names: Array = _valid_entries(false)
    _expect(WorldRegionCatalogValidator.validate_entries(omitted_names).is_empty(), "presentation names may be omitted")

    var renamed_names: Array = _valid_entries()
    (renamed_names[0] as Dictionary)["name"] = &"Renamed Placeholder"
    (renamed_names[2] as Dictionary)["name"] = "Anything"
    _expect(WorldRegionCatalogValidator.validate_entries(renamed_names).is_empty(), "presentation names do not define region identity or require placeholder spellings")

    var wrong_name_type: Array = _valid_entries()
    (wrong_name_type[0] as Dictionary)["name"] = 1
    _expect(_contains(WorldRegionCatalogValidator.validate_entries(wrong_name_type), "entries[0]: name must be a string when present"), "optional presentation name still rejects malformed field type")

    var deterministic_fixture: Array = _valid_entries()
    (deterministic_fixture[0] as Dictionary)["region_id"] = 12
    (deterministic_fixture[2] as Dictionary)["state"] = &"future_locked"
    var first_errors: PackedStringArray = WorldRegionCatalogValidator.validate_entries(deterministic_fixture)
    var second_errors: PackedStringArray = WorldRegionCatalogValidator.validate_entries(deterministic_fixture)
    _expect(first_errors == second_errors, "validation errors are deterministic for identical caller input")

    if _failures == 0:
        print("WORLD REGION CATALOG TEST PASS")
    else:
        push_error("WORLD REGION CATALOG TEST FAILURES: %d" % _failures)
    quit(_failures)

func _valid_entries(include_names: bool = true) -> Array:
    var entries: Array = []
    for region_id: int in range(1, WorldRegionCatalogValidator.REGION_COUNT + 1):
        var entry: Dictionary = {
            "region_id": region_id,
            "state": WorldRegionCatalogValidator.STATE_PROTOTYPE_STARTING_REGION if region_id == WorldRegionCatalogValidator.PROTOTYPE_REGION_ID else WorldRegionCatalogValidator.STATE_FUTURE_LOCKED,
        }
        if include_names:
            entry["name"] = "Placeholder %d" % region_id
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
