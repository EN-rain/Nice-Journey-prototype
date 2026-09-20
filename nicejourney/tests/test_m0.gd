extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _expect(StableId.is_valid("profile:slot_1"), "stable IDs accept the project ID alphabet")
    _expect(not StableId.is_valid("bad id"), "stable IDs reject spaces")

    var profile: ProfileSnapshot = ProfileSnapshot.new()
    profile.profile_id = "profile:slot_1"
    profile.protagonist_name = "M0 Tester"
    profile.class_id = "melee"
    profile.level = 3
    profile.xp = 225
    profile.skill_points = 2
    profile.permanent_flags = {"foundation_round_trip": true}
    profile.claimed_transactions = {"reward:test_001": {"source_id": "quest:test"}}

    var validation_errors: PackedStringArray = ProfileSnapshot.validate_dictionary(profile.to_dictionary())
    _expect(validation_errors.is_empty(), "valid minimal profile passes schema validation")

    var service: SaveService = SaveService.new("user://tests/m0")
    service.delete_slot(1)
    var first_save_error: int = service.save_profile(1, profile)
    _expect(first_save_error == OK, "slot 1 saves atomically")

    var loaded: ProfileSnapshot = service.load_profile(1)
    _expect(loaded != null, "slot 1 loads after save")
    if loaded != null:
        _expect(loaded.profile_id == profile.profile_id, "profile_id round-trips")
        _expect(loaded.protagonist_name == profile.protagonist_name, "protagonist name round-trips")
        _expect(loaded.class_id == profile.class_id, "class_id round-trips")
        _expect(loaded.level == profile.level, "level round-trips")
        _expect(loaded.xp == profile.xp, "xp round-trips")
        _expect(bool(loaded.permanent_flags.get("foundation_round_trip", false)), "permanent flags round-trip")
        _expect(loaded.claimed_transactions.has("reward:test_001"), "claim ledger state round-trips")

    profile.level = 4
    var second_save_error: int = service.save_profile(1, profile)
    _expect(second_save_error == OK, "second save creates a recoverable prior generation")

    var current_path: String = "user://tests/m0/slot_1.json"
    var corrupt_file: FileAccess = FileAccess.open(current_path, FileAccess.WRITE)
    if corrupt_file != null:
        corrupt_file.store_string("{corrupt")
        corrupt_file.close()
    var recovered: ProfileSnapshot = service.load_profile(1)
    _expect(recovered != null, "corrupt newest generation falls back to prior valid generation")
    if recovered != null:
        _expect(recovered.level == 3, "backup recovery returns the previous coherent snapshot")

    service.delete_slot(1)
    if _failures == 0:
        print("M0 TEST PASS")
    else:
        push_error("M0 TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
