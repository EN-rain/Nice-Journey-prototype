extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var valid_entries: Array = _valid_entries()
    var before_validation: Array = valid_entries.duplicate(true)
    _expect(MapLayerIdentityValidator.validate_entries(valid_entries).is_empty(), "valid map layers pass regardless of descriptor order")
    _expect(valid_entries == before_validation, "map-layer validation does not mutate caller-supplied entries")

    _expect(_contains(MapLayerIdentityValidator.validate_entries("bad"), "entries must be an array"), "top-level non-array input is rejected")

    var wrong_entry_type: Array = _valid_entries()
    wrong_entry_type[2] = "not-a-dictionary"
    var wrong_entry_errors: PackedStringArray = MapLayerIdentityValidator.validate_entries(wrong_entry_type)
    _expect(_contains(wrong_entry_errors, "entries[2] must be a dictionary"), "wrong-type descriptors are rejected")
    _expect(_contains(wrong_entry_errors, "missing layer_id region_map"), "wrong-type replacement reports missing layer identity")

    var two_entries: Array = _valid_entries()
    two_entries.pop_back()
    var two_errors: PackedStringArray = MapLayerIdentityValidator.validate_entries(two_entries)
    _expect(_contains(two_errors, "entries must contain exactly 3 map layers"), "two descriptors are rejected")
    _expect(_contains(two_errors, "missing layer_id region_map"), "two-descriptor catalog reports the missing layer")

    var four_entries: Array = _valid_entries()
    four_entries.append({"layer_id": MapLayerIdentityValidator.LAYER_WORLD_MAP})
    _expect(_contains(MapLayerIdentityValidator.validate_entries(four_entries), "entries must contain exactly 3 map layers"), "four descriptors are rejected")

    var missing_id: Array = _valid_entries()
    (missing_id[0] as Dictionary).erase("layer_id")
    var missing_id_errors: PackedStringArray = MapLayerIdentityValidator.validate_entries(missing_id)
    _expect(_contains(missing_id_errors, "entries[0]: missing layer_id"), "missing layer IDs are rejected")
    _expect(_contains(missing_id_errors, "missing layer_id tower_floor_map"), "missing ID field cannot silently satisfy required layer coverage")

    var wrong_id_type: Array = _valid_entries()
    (wrong_id_type[0] as Dictionary)["layer_id"] = 3
    _expect(_contains(MapLayerIdentityValidator.validate_entries(wrong_id_type), "entries[0]: layer_id must be a string"), "wrong-type layer IDs are rejected")

    var unknown_id: Array = _valid_entries()
    (unknown_id[0] as Dictionary)["layer_id"] = &"minimap"
    var unknown_id_errors: PackedStringArray = MapLayerIdentityValidator.validate_entries(unknown_id)
    _expect(_contains(unknown_id_errors, "entries[0]: unknown layer_id minimap"), "unknown layer IDs are rejected")
    _expect(_contains(unknown_id_errors, "missing layer_id tower_floor_map"), "unknown replacement reports the required missing layer")

    var duplicate_replacement: Array = _valid_entries()
    (duplicate_replacement[0] as Dictionary)["layer_id"] = MapLayerIdentityValidator.LAYER_REGION_MAP
    var duplicate_errors: PackedStringArray = MapLayerIdentityValidator.validate_entries(duplicate_replacement)
    _expect(_contains(duplicate_errors, "entries[2]: duplicate layer_id region_map"), "duplicate layer IDs are rejected")
    _expect(_contains(duplicate_errors, "missing layer_id tower_floor_map"), "duplicate replacement reports the missing tower-floor layer")

    var omitted_names: Array = _valid_entries(false)
    _expect(MapLayerIdentityValidator.validate_entries(omitted_names).is_empty(), "presentation names may be omitted")

    var renamed_names: Array = _valid_entries()
    (renamed_names[0] as Dictionary)["name"] = &"Any Tower Label"
    (renamed_names[1] as Dictionary)["name"] = "Any World Label"
    (renamed_names[2] as Dictionary)["name"] = ""
    _expect(MapLayerIdentityValidator.validate_entries(renamed_names).is_empty(), "presentation names are non-authoritative strings")

    var wrong_name_type: Array = _valid_entries()
    (wrong_name_type[1] as Dictionary)["name"] = 1
    _expect(_contains(MapLayerIdentityValidator.validate_entries(wrong_name_type), "entries[1]: name must be a string when present"), "malformed optional presentation names are rejected")

    var deterministic_fixture: Array = _valid_entries()
    (deterministic_fixture[0] as Dictionary)["layer_id"] = &"unknown_layer"
    (deterministic_fixture[2] as Dictionary)["layer_id"] = MapLayerIdentityValidator.LAYER_WORLD_MAP
    var first_errors: PackedStringArray = MapLayerIdentityValidator.validate_entries(deterministic_fixture)
    var second_errors: PackedStringArray = MapLayerIdentityValidator.validate_entries(deterministic_fixture)
    _expect(first_errors == second_errors, "validation errors are deterministic for identical caller input")

    if _failures == 0:
        print("MAP LAYER IDENTITY TEST PASS")
    else:
        push_error("MAP LAYER IDENTITY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _valid_entries(include_names: bool = true) -> Array:
    var entries: Array = [
        {"layer_id": MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP},
        {"layer_id": MapLayerIdentityValidator.LAYER_WORLD_MAP},
        {"layer_id": MapLayerIdentityValidator.LAYER_REGION_MAP},
    ]
    if include_names:
        (entries[0] as Dictionary)["name"] = "Tower Floor Map"
        (entries[1] as Dictionary)["name"] = &"World Map"
        (entries[2] as Dictionary)["name"] = "Region Map"
    return entries

func _contains(errors: PackedStringArray, expected: String) -> bool:
    return errors.has(expected)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
