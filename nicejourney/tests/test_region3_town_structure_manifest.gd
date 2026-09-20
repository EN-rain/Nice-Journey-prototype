extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var valid_entries: Array = _valid_entries()
    var before_validation: Array = valid_entries.duplicate(true)
    _expect(Region3TownStructureManifestValidator.validate_entries(valid_entries).is_empty(), "valid Region 3 structure manifest satisfies the locked 20/8/12 contract")
    _expect(valid_entries == before_validation, "manifest validation does not mutate caller-supplied entries")

    _expect(_contains(Region3TownStructureManifestValidator.validate_entries("bad"), "entries must be an array"), "top-level non-array input is rejected")

    var wrong_entry_type: Array = _valid_entries()
    wrong_entry_type[19] = "not-a-dictionary"
    var wrong_entry_errors: PackedStringArray = Region3TownStructureManifestValidator.validate_entries(wrong_entry_type)
    _expect(_contains(wrong_entry_errors, "entries[19] must be a dictionary"), "wrong-type structure entries are rejected")
    _expect(_contains(wrong_entry_errors, "manifest must contain exactly 12 decorative structures"), "wrong-type entries cannot silently satisfy the decorative split")

    var malformed_id: Array = _valid_entries()
    (malformed_id[0] as Dictionary)["structure_id"] = "bad structure id"
    _expect(_contains(Region3TownStructureManifestValidator.validate_entries(malformed_id), "entries[0]: structure_id must be a stable ID"), "malformed structure IDs are rejected")

    var wrong_id_type: Array = _valid_entries()
    (wrong_id_type[0] as Dictionary)["structure_id"] = 7
    _expect(_contains(Region3TownStructureManifestValidator.validate_entries(wrong_id_type), "entries[0]: structure_id must be a string"), "wrong-type structure IDs are rejected")

    var duplicate_id: Array = _valid_entries()
    (duplicate_id[19] as Dictionary)["structure_id"] = (duplicate_id[18] as Dictionary)["structure_id"]
    _expect(_contains(Region3TownStructureManifestValidator.validate_entries(duplicate_id), "entries[19]: duplicate structure_id r3:decorative:11"), "duplicate stable structure IDs are rejected")

    var wrong_category_type: Array = _valid_entries()
    (wrong_category_type[19] as Dictionary)["category"] = 12
    _expect(_contains(Region3TownStructureManifestValidator.validate_entries(wrong_category_type), "entries[19]: category must be a string"), "wrong-type categories are rejected")

    var unknown_category: Array = _valid_entries()
    (unknown_category[19] as Dictionary)["category"] = &"residential"
    _expect(_contains(Region3TownStructureManifestValidator.validate_entries(unknown_category), "entries[19]: category must be functional or decorative"), "unknown structure categories are rejected")

    var wrong_role_type: Array = _valid_entries()
    (wrong_role_type[0] as Dictionary)["role_id"] = 1
    _expect(_contains(Region3TownStructureManifestValidator.validate_entries(wrong_role_type), "entries[0]: role_id must be a string"), "wrong-type functional role IDs are rejected")

    var unknown_role: Array = _valid_entries()
    (unknown_role[0] as Dictionary)["role_id"] = &"tower_service"
    var unknown_role_errors: PackedStringArray = Region3TownStructureManifestValidator.validate_entries(unknown_role)
    _expect(_contains(unknown_role_errors, "entries[0]: unknown functional role_id tower_service"), "unknown functional roles are rejected")
    _expect(_contains(unknown_role_errors, "missing functional role_id central_tower"), "replacing a locked functional role reports the now-missing role")

    var duplicate_role: Array = _valid_entries()
    (duplicate_role[1] as Dictionary)["role_id"] = Region3TownStructureManifestValidator.ROLE_CENTRAL_TOWER
    var duplicate_role_errors: PackedStringArray = Region3TownStructureManifestValidator.validate_entries(duplicate_role)
    _expect(_contains(duplicate_role_errors, "entries[1]: duplicate functional role_id central_tower"), "duplicate functional roles are rejected")
    _expect(_contains(duplicate_role_errors, "missing functional role_id quest_hall"), "duplicate role replacement also reports the missing locked role")

    var missing_role: Array = _valid_entries()
    (missing_role[7] as Dictionary).erase("role_id")
    var missing_role_errors: PackedStringArray = Region3TownStructureManifestValidator.validate_entries(missing_role)
    _expect(_contains(missing_role_errors, "entries[7]: missing role_id"), "functional entries require an explicit locked role ID")
    _expect(_contains(missing_role_errors, "missing functional role_id clinic_apothecary"), "missing functional role coverage is reported deterministically")

    var wrong_split: Array = _valid_entries()
    (wrong_split[7] as Dictionary)["category"] = Region3TownStructureManifestValidator.CATEGORY_DECORATIVE
    var wrong_split_errors: PackedStringArray = Region3TownStructureManifestValidator.validate_entries(wrong_split)
    _expect(_contains(wrong_split_errors, "manifest must contain exactly 8 functional structures"), "7-functional split is rejected")
    _expect(_contains(wrong_split_errors, "manifest must contain exactly 12 decorative structures"), "13-decorative split is rejected")

    var inverse_wrong_split: Array = _valid_entries()
    (inverse_wrong_split[8] as Dictionary)["category"] = Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL
    (inverse_wrong_split[8] as Dictionary)["role_id"] = Region3TownStructureManifestValidator.ROLE_CENTRAL_TOWER
    var inverse_wrong_split_errors: PackedStringArray = Region3TownStructureManifestValidator.validate_entries(inverse_wrong_split)
    _expect(_contains(inverse_wrong_split_errors, "manifest must contain exactly 8 functional structures"), "9-functional split is rejected")
    _expect(_contains(inverse_wrong_split_errors, "manifest must contain exactly 12 decorative structures"), "11-decorative split is rejected")

    var wrong_total: Array = _valid_entries()
    wrong_total.pop_back()
    var wrong_total_errors: PackedStringArray = Region3TownStructureManifestValidator.validate_entries(wrong_total)
    _expect(_contains(wrong_total_errors, "entries must contain exactly 20 structures"), "wrong total structure count is rejected")
    _expect(_contains(wrong_total_errors, "manifest must contain exactly 12 decorative structures"), "wrong total cannot hide the required 12-decorative count")

    var too_many: Array = _valid_entries()
    too_many.append({
        "structure_id": &"r3:decorative:13",
        "category": Region3TownStructureManifestValidator.CATEGORY_DECORATIVE,
    })
    var too_many_errors: PackedStringArray = Region3TownStructureManifestValidator.validate_entries(too_many)
    _expect(_contains(too_many_errors, "entries must contain exactly 20 structures"), "21 total structures are rejected")
    _expect(_contains(too_many_errors, "manifest must contain exactly 12 decorative structures"), "21-entry manifest cannot hide a 13-decorative split")

    var deterministic_fixture: Array = _valid_entries()
    (deterministic_fixture[0] as Dictionary)["role_id"] = &"unknown_role"
    (deterministic_fixture[19] as Dictionary)["structure_id"] = (deterministic_fixture[18] as Dictionary)["structure_id"]
    var first_errors: PackedStringArray = Region3TownStructureManifestValidator.validate_entries(deterministic_fixture)
    var second_errors: PackedStringArray = Region3TownStructureManifestValidator.validate_entries(deterministic_fixture)
    _expect(first_errors == second_errors, "validation errors are deterministic for identical caller input")

    var decorative_minimal: Array = _valid_entries()
    for index: int in range(8, decorative_minimal.size()):
        _expect((decorative_minimal[index] as Dictionary).keys().size() == 2, "decorative entry %d requires only structure_id and decorative category" % (index - 7))

    if _failures == 0:
        print("REGION 3 TOWN STRUCTURE MANIFEST TEST PASS")
    else:
        push_error("REGION 3 TOWN STRUCTURE MANIFEST TEST FAILURES: %d" % _failures)
    quit(_failures)

func _valid_entries() -> Array:
    var functional_roles: Array[StringName] = Region3TownStructureManifestValidator.REQUIRED_FUNCTIONAL_ROLES
    var entries: Array = []
    for index: int in range(functional_roles.size()):
        entries.append({
            "structure_id": StringName("r3:functional:%02d" % (index + 1)),
            "category": Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL,
            "role_id": functional_roles[index],
        })
    for index: int in range(Region3TownStructureManifestValidator.DECORATIVE_STRUCTURES):
        entries.append({
            "structure_id": StringName("r3:decorative:%02d" % (index + 1)),
            "category": Region3TownStructureManifestValidator.CATEGORY_DECORATIVE,
        })
    return entries

func _contains(errors: PackedStringArray, expected: String) -> bool:
    return errors.has(expected)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
