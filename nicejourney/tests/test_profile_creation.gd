extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    for class_id: String in ["melee", "ranged", "mage"]:
        var profile: ProfileSnapshot = ProfileCreationService.create_profile(1, "Astra", class_id)
        _expect(profile != null, "approved class %s can create a profile" % class_id)
        if profile != null:
            _expect(profile.class_id == class_id, "class identity is stored exactly for %s" % class_id)
            _expect(profile.level == 1 and profile.xp == 0, "new profile starts at the locked progression baseline")
            var storage := StorageState.new()
            _expect(storage.load_dictionary(profile.storage_state).is_empty(), "new %s profile owns a valid explicit hub-storage state" % class_id)
            _expect(storage.capacity == StorageState.DEFAULT_CAPACITY and storage.normal_slots.is_empty(), "new %s profile starts with empty 64-slot hub storage" % class_id)

    _expect(ProfileCreationService.create_profile(0, "Astra", "melee") == null, "slot zero is rejected")
    _expect(ProfileCreationService.create_profile(4, "Astra", "melee") == null, "slot above the three-slot limit is rejected")
    _expect(ProfileCreationService.create_profile(1, "   ", "melee") == null, "blank protagonist names are rejected")
    _expect(ProfileCreationService.create_profile(1, "Astra", "unknown") == null, "unapproved class IDs are rejected")

    var trimmed: ProfileSnapshot = ProfileCreationService.create_profile(2, "  Nova  ", "Mage")
    _expect(trimmed != null and trimmed.protagonist_name == "Nova", "profile creation normalizes edge whitespace")
    _expect(trimmed != null and trimmed.class_id == "mage", "profile creation normalizes class ID casing")
    _expect(trimmed != null and trimmed.profile_id == "profile:slot_2", "profile ID is stable and slot-bound")

    if _failures == 0:
        print("PROFILE CREATION TEST PASS")
    else:
        push_error("PROFILE CREATION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
