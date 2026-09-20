extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var root_path: String = "user://tests/save_compatibility"
    var service: SaveService = SaveService.new(root_path)
    service.delete_slot(1)
    service.delete_slot(2)

    var profile: ProfileSnapshot = _make_profile("profile:compat_1", "Compatibility Tester", "melee", 3)
    _expect(service.save_profile(1, profile) == OK, "valid profile seeds the compatibility fixture")

    var current_result: Dictionary = service.load_profile_with_status(1)
    _expect(StringName(current_result.get("state", &"")) == &"loaded", "valid current generation reports loaded")
    _expect(StringName(current_result.get("loaded_from", &"")) == &"current", "valid current generation identifies current as the selected generation")
    _expect(_profile_level(current_result) == 3, "detailed load returns the selected profile snapshot")
    _expect(StringName((current_result.get("current", {}) as Dictionary).get("state", &"")) == &"valid", "current generation validity is observable")

    profile.level = 4
    _expect(service.save_profile(1, profile) == OK, "second save creates a prior valid backup generation")
    var healthy_with_backup: Dictionary = service.load_profile_with_status(1)
    _expect(StringName(healthy_with_backup.get("loaded_from", &"")) == &"current" and _profile_level(healthy_with_backup) == 4, "valid current generation remains selected when a prior valid backup exists")
    _expect(StringName((healthy_with_backup.get("backup", {}) as Dictionary).get("state", &"")) == &"valid", "detailed load reports the actual prior-valid backup instead of fabricating a missing generation")
    _rewrite_schema_version("%s/slot_1.json" % root_path, 999)

    var incompatible_result: Dictionary = service.load_profile_with_status(1)
    var incompatible_current: Dictionary = incompatible_result.get("current", {}) as Dictionary
    _expect(StringName(incompatible_result.get("state", &"")) == &"loaded" and StringName(incompatible_result.get("loaded_from", &"")) == &"backup", "unsupported current schema falls back to the prior valid generation")
    _expect(StringName(incompatible_current.get("state", &"")) == &"incompatible", "unsupported schema is distinguished from corrupt JSON")
    _expect(_packed_strings_contain(incompatible_current.get("validation_errors", PackedStringArray()) as PackedStringArray, "unsupported schema_version"), "unsupported schema reason remains inspectable")
    _expect(_profile_level(incompatible_result) == 3, "schema fallback returns the previous coherent snapshot")

    _write_text("%s/slot_1.json" % root_path, "{corrupt")
    var corrupt_result: Dictionary = service.load_profile_with_status(1)
    var corrupt_current: Dictionary = corrupt_result.get("current", {}) as Dictionary
    _expect(StringName(corrupt_result.get("loaded_from", &"")) == &"backup", "corrupt newest generation also falls back to prior valid data")
    _expect(StringName(corrupt_current.get("state", &"")) == &"corrupt" and StringName(corrupt_current.get("reason_id", &"")) == &"json_parse_failed", "JSON corruption has an explicit observable reason")

    _remove_if_exists("%s/slot_1.json.bak" % root_path)
    _rewrite_from_profile_with_schema("%s/slot_1.json" % root_path, profile, 999)
    var unavailable_result: Dictionary = service.load_profile_with_status(1)
    _expect(StringName(unavailable_result.get("state", &"")) == &"unavailable" and StringName(unavailable_result.get("reason_id", &"")) == &"no_valid_generation", "no valid current or backup generation is reported truthfully")
    _expect(unavailable_result.get("profile") == null, "unavailable load never fabricates a profile")
    _expect(StringName((unavailable_result.get("current", {}) as Dictionary).get("state", &"")) == &"incompatible", "failed load preserves current-generation compatibility evidence")
    _expect(StringName((unavailable_result.get("backup", {}) as Dictionary).get("state", &"")) == &"missing", "failed load preserves missing-backup evidence")
    _expect(service.load_profile(1) == null, "legacy load API remains null when no valid generation exists")

    var slot_two: ProfileSnapshot = _make_profile("profile:compat_2", "Independent Slot", "ranged", 2)
    _expect(service.save_profile(2, slot_two) == OK, "independent slot can still save while slot 1 is incompatible")
    var slot_two_result: Dictionary = service.load_profile_with_status(2)
    _expect(StringName(slot_two_result.get("loaded_from", &"")) == &"current" and _profile_level(slot_two_result) == 2, "slot compatibility failure cannot affect another slot")

    var invalid_slot: Dictionary = service.load_profile_with_status(0)
    _expect(StringName(invalid_slot.get("state", &"")) == &"failed" and StringName(invalid_slot.get("reason_id", &"")) == &"invalid_slot", "invalid slot reports a stable failure reason")

    service.delete_slot(1)
    service.delete_slot(2)
    if _failures == 0:
        print("SAVE COMPATIBILITY TEST PASS")
    else:
        push_error("SAVE COMPATIBILITY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _make_profile(profile_id: String, protagonist_name: String, class_id: String, level: int) -> ProfileSnapshot:
    var profile: ProfileSnapshot = ProfileSnapshot.new()
    profile.profile_id = profile_id
    profile.protagonist_name = protagonist_name
    profile.class_id = class_id
    profile.level = level
    profile.xp = 0
    profile.skill_points = 0
    return profile

func _profile_level(result: Dictionary) -> int:
    var profile: ProfileSnapshot = result.get("profile") as ProfileSnapshot
    return -1 if profile == null else profile.level

func _rewrite_schema_version(path: String, schema_version: int) -> void:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        _expect(false, "fixture current generation can be opened for schema rewrite")
        return
    var parser: JSON = JSON.new()
    var parse_error: int = parser.parse(file.get_as_text())
    file.close()
    if parse_error != OK or not parser.data is Dictionary:
        _expect(false, "fixture current generation parses before schema rewrite")
        return
    var payload: Dictionary = (parser.data as Dictionary).duplicate(true)
    payload["schema_version"] = schema_version
    _write_text(path, JSON.stringify(payload, "\t", true))

func _rewrite_from_profile_with_schema(path: String, profile: ProfileSnapshot, schema_version: int) -> void:
    var payload: Dictionary = profile.to_dictionary()
    payload["schema_version"] = schema_version
    _write_text(path, JSON.stringify(payload, "\t", true))

func _write_text(path: String, text: String) -> void:
    var absolute_parent: String = ProjectSettings.globalize_path(path.get_base_dir())
    DirAccess.make_dir_recursive_absolute(absolute_parent)
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        _expect(false, "test fixture path can be written: %s" % path)
        return
    file.store_string(text)
    file.close()

func _remove_if_exists(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _packed_strings_contain(values: PackedStringArray, expected: String) -> bool:
    for value: String in values:
        if value == expected:
            return true
    return false

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
