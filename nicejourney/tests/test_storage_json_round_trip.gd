extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Storage JSON", "melee")
    _expect(profile != null, "storage JSON fixture creates a valid profile")
    if profile == null:
        quit(1)
        return

    var storage := StorageState.new()
    _expect(storage.capacity == StorageState.DEFAULT_CAPACITY, "storage JSON fixture starts from the 64-slot tuning hypothesis")
    _expect(bool(storage.try_add_normal(
        &"item:storage_json_stack",
        &"itemdef:storage_json_stack",
        17,
        true
    ).get("accepted", false)), "storage JSON fixture owns a stackable stored item")
    _expect(bool(storage.try_add_normal(
        &"item:storage_json_gear",
        &"itemdef:storage_json_gear",
        1,
        false,
        {
            "rarity": "rare",
            "affixes": ["guarded"],
            "upgrade_rank": 2,
            "source_claim_id": "loot:storage_json",
        }
    ).get("accepted", false)), "storage JSON fixture owns metadata-bearing stored gear")
    profile.storage_state = storage.to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "non-empty storage validates before serialization")

    var save_root := "user://storage_json_round_trip_%d" % Time.get_ticks_msec()
    var save_service := SaveService.new(save_root)
    _expect(save_service.save_profile(1, profile) == OK, "SaveService accepts non-empty storage through JSON temp-file verification")
    var loaded := save_service.load_profile(1)
    _expect(loaded != null, "profile with non-empty storage reloads from JSON")
    if loaded != null:
        _expect(ProfileSnapshot.validate_dictionary(loaded.to_dictionary()).is_empty(), "JSON-loaded profile with storage remains persistence-valid")
        var raw_storage := loaded.storage_state
        _expect(typeof(raw_storage.get("capacity", null)) == TYPE_FLOAT, "fixture confirms Godot JSON represents persisted storage capacity as a numeric float")
        var raw_slots := raw_storage.get("normal_slots", []) as Array
        _expect(raw_slots.size() == 2 and typeof((raw_slots[0] as Dictionary).get("quantity", null)) == TYPE_FLOAT, "fixture confirms JSON represents stored quantities as numeric floats")

        var restored := StorageState.new()
        _expect(restored.load_dictionary(raw_storage).is_empty(), "StorageState accepts finite integral JSON numeric representations")
        _expect(typeof(restored.capacity) == TYPE_INT and restored.capacity == 64, "StorageState canonicalizes persisted capacity back to int")
        var restored_stack := restored.get_normal_slot(&"item:storage_json_stack")
        _expect(typeof(restored_stack.get("quantity", null)) == TYPE_INT and int(restored_stack.get("quantity", 0)) == 17, "StorageState canonicalizes stored quantity back to int")
        var restored_gear := restored.get_normal_slot(&"item:storage_json_gear")
        _expect(typeof(restored_gear.get("upgrade_rank", null)) == TYPE_INT and int(restored_gear.get("upgrade_rank", -1)) == 2, "StorageState canonicalizes persisted upgrade rank back to int")
        _expect(String(restored_gear.get("rarity", "")) == "rare" and (restored_gear.get("affixes", []) as Array) == ["guarded"] and String(restored_gear.get("source_claim_id", "")) == "loot:storage_json", "storage JSON round trip preserves exact realized metadata and provenance")

    var fractional_capacity := storage.to_dictionary()
    fractional_capacity["capacity"] = 64.5
    _expect(not StorageState.validate_dictionary(fractional_capacity).is_empty(), "persisted storage rejects fractional capacity")

    var fractional_quantity := storage.to_dictionary()
    ((fractional_quantity.get("normal_slots", []) as Array)[0] as Dictionary)["quantity"] = 17.5
    _expect(not StorageState.validate_dictionary(fractional_quantity).is_empty(), "persisted storage rejects fractional stack quantity")

    _expect(not NormalStackQuantityValidator.is_valid(17.0), "live normal-stack quantity API remains strict integer-only")

    save_service.delete_slot(1)
    if _failures == 0:
        print("STORAGE JSON ROUND TRIP TEST PASS")
    else:
        push_error("STORAGE JSON ROUND TRIP TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
