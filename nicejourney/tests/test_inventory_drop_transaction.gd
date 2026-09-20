extends SceneTree

const DROP_SERVICE: Script = preload("res://src/items/inventory_drop_transaction_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Drop Test", "melee")
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "drop fixture loads initialized inventory")
    _expect(bool(inventory.try_add_normal(
        &"item:drop_stack",
        &"material_crystal",
        5,
        true,
        {"rarity": "rare", "affixes": ["charged"], "upgrade_rank": 2, "source_claim_id": "loot:drop_fixture"}
    ).get("accepted", false)), "drop fixture owns metadata-bearing stack")
    _expect(inventory.bind_quick_slot(0, &"item:drop_stack"), "drop fixture binds a quick reference to the owned stack")
    _expect(inventory.grant_protected(InventoryState.TOWER_SIGIL_ID, true), "drop fixture owns protected Tower Sigil")
    profile.item_state = inventory.to_dictionary()
    profile.tower_floor_states["1"] = _floor_state().to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "drop fixture profile validates before transaction")

    var before_invalid_position := profile.to_dictionary()
    var invalid_position: Dictionary = DROP_SERVICE.drop_full_stack(profile, 1, &"drop:invalid_position", &"item:drop_stack", Vector2(NAN, 64.0))
    _expect(not bool(invalid_position.get("accepted", true)) and StringName(invalid_position.get("reason_id", &"")) == DROP_SERVICE.REASON_INVALID_INPUT, "drop rejects nonfinite caller position")
    _expect(profile.to_dictionary() == before_invalid_position, "invalid drop position mutates nothing")

    var before_protected := profile.to_dictionary()
    var protected_result: Dictionary = DROP_SERVICE.drop_full_stack(profile, 1, &"drop:sigil", InventoryState.TOWER_SIGIL_ID, Vector2(64.0, 64.0))
    _expect(not bool(protected_result.get("accepted", true)) and StringName(protected_result.get("reason_id", &"")) == DROP_SERVICE.REASON_PROTECTED_ITEM, "protected quest/key item cannot be dropped")
    _expect(StringName(protected_result.get("policy_reason_id", &"")) == ProtectedItemOperationPolicy.REASON_PERMANENT_TOWER_SIGIL, "Tower Sigil drop rejection preserves permanent-item policy reason")
    _expect(profile.to_dictionary() == before_protected, "protected drop rejection mutates nothing")

    var drop_position := Vector2(96.5, 128.25)
    var dropped: Dictionary = DROP_SERVICE.drop_full_stack(profile, 1, &"drop:stack_1", &"item:drop_stack", drop_position)
    _expect(bool(dropped.get("accepted", false)), "full owned stack drops into persistent floor state")
    _expect(int(dropped.get("quantity", 0)) == 5 and (dropped.get("world_position", Vector2.ZERO) as Vector2).is_equal_approx(drop_position), "drop result preserves full quantity and exact caller-owned world position")
    var post_drop_inventory := InventoryState.new()
    _expect(post_drop_inventory.load_dictionary(profile.item_state).is_empty(), "post-drop inventory remains valid")
    _expect(post_drop_inventory.get_normal_slot(&"item:drop_stack").is_empty(), "drop moves the exact item instance out of portable inventory")
    _expect(post_drop_inventory.quick_slots[0] == &"", "full-stack drop clears the now-invalid quick reference")

    var source_id := StringName(String(dropped.get("source_id", &"")))
    var post_drop_floor := _load_floor(profile)
    var entry := post_drop_floor.loose_items.get(String(source_id), {}) as Dictionary
    _expect(StringName(String(entry.get("entry_kind", &""))) == DROP_SERVICE.ENTRY_KIND, "player drop uses a dedicated loose-item entry kind instead of random-loot claims")
    _expect(StringName(String((entry.get("item", {}) as Dictionary).get("item_instance_id", &""))) == &"item:drop_stack", "drop record preserves exact item instance identity")
    _expect(StringName(String((entry.get("item", {}) as Dictionary).get("rarity", &""))) == &"rare" and int((entry.get("item", {}) as Dictionary).get("upgrade_rank", -1)) == 2, "drop record preserves realized metadata without rerolling")
    var saved_position := entry.get("world_position", {}) as Dictionary
    _expect(is_equal_approx(float(saved_position.get("x", 0.0)), drop_position.x) and is_equal_approx(float(saved_position.get("y", 0.0)), drop_position.y), "drop record persists exact source location")

    var ledger := ClaimLedger.new()
    _expect(ledger.load_dictionary(profile.claimed_transactions).is_empty() and ledger.is_claimed(&"drop:stack_1"), "drop transaction identity commits exactly once")
    var before_duplicate := profile.to_dictionary()
    var duplicate: Dictionary = DROP_SERVICE.drop_full_stack(profile, 1, &"drop:stack_1", &"item:drop_stack", drop_position)
    _expect(not bool(duplicate.get("accepted", true)) and StringName(duplicate.get("reason_id", &"")) == DROP_SERVICE.REASON_DUPLICATE_TRANSACTION, "duplicate drop transaction cannot move ownership twice")
    _expect(profile.to_dictionary() == before_duplicate, "duplicate drop leaves persistent ownership unchanged")

    var save_root := "user://inventory_drop_transaction_%d" % Time.get_ticks_msec()
    var save_service := SaveService.new(save_root)
    _expect(save_service.save_profile(1, profile) == OK, "player-drop state survives the ordinary profile save boundary")
    var loaded := save_service.load_profile(1)
    _expect(loaded != null, "player-drop profile reloads from JSON")
    if loaded != null:
        var loaded_floor := _load_floor(loaded)
        var loaded_entry := loaded_floor.loose_items.get(String(source_id), {}) as Dictionary
        var loaded_position := loaded_entry.get("world_position", {}) as Dictionary
        _expect(is_equal_approx(float(loaded_position.get("x", 0.0)), drop_position.x) and is_equal_approx(float(loaded_position.get("y", 0.0)), drop_position.y), "drop location survives JSON numeric normalization")
        _expect(StringName(String((loaded_entry.get("item", {}) as Dictionary).get("item_instance_id", &""))) == &"item:drop_stack", "dropped item identity survives save/load")

        var collected: Dictionary = DROP_SERVICE.collect_player_drop(loaded, 1, source_id, &"pickup:stack_1")
        _expect(bool(collected.get("accepted", false)), "persisted player drop can be picked up through its dedicated reverse transaction")
        _expect((collected.get("world_position", Vector2.ZERO) as Vector2).is_equal_approx(drop_position), "pickup returns the persisted source location")
        var restored_inventory := InventoryState.new()
        _expect(restored_inventory.load_dictionary(loaded.item_state).is_empty(), "pickup restores a valid inventory")
        var restored_item := restored_inventory.get_normal_slot(&"item:drop_stack")
        _expect(not restored_item.is_empty() and int(restored_item.get("quantity", 0)) == 5, "pickup restores the exact dropped stack identity and quantity")
        _expect(StringName(String(restored_item.get("rarity", &""))) == &"rare" and (restored_item.get("affixes", []) as Array) == ["charged"] and int(restored_item.get("upgrade_rank", -1)) == 2, "pickup restores exact dropped metadata without rerolling or merging it away")
        _expect(_load_floor(loaded).loose_items.get(String(source_id), null) == null, "successful pickup removes the saved player-drop source exactly once")
        _expect(restored_inventory.quick_slots[0] == &"", "pickup does not fabricate a quick-slot rebind")
        _expect(ProfileSnapshot.validate_dictionary(loaded.to_dictionary()).is_empty(), "drop/pickup round trip leaves a persistence-valid profile")

        var missing_again: Dictionary = DROP_SERVICE.collect_player_drop(loaded, 1, source_id, &"pickup:stack_2")
        _expect(not bool(missing_again.get("accepted", true)) and StringName(missing_again.get("reason_id", &"")) == DROP_SERVICE.REASON_SOURCE_NOT_FOUND, "collected player drop cannot be collected again under a new transaction")

    save_service.delete_slot(1)

    _test_full_inventory_rejection()
    _test_random_loot_is_not_player_drop()

    if _failures == 0:
        print("INVENTORY DROP TRANSACTION TEST PASS")
    else:
        push_error("INVENTORY DROP TRANSACTION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_full_inventory_rejection() -> void:
    var profile := ProfileCreationService.create_profile(2, "Drop Full", "ranged")
    var inventory := InventoryState.new()
    inventory.load_dictionary(profile.item_state)
    inventory.try_add_normal(&"item:held_drop", &"material_drop", 1, false)
    profile.item_state = inventory.to_dictionary()
    profile.tower_floor_states["1"] = _floor_state().to_dictionary()
    var dropped: Dictionary = DROP_SERVICE.drop_full_stack(profile, 1, &"drop:full_grid", &"item:held_drop", Vector2(32.0, 32.0))
    var source_id := StringName(String(dropped.get("source_id", &"")))

    var filled := InventoryState.new()
    filled.load_dictionary(profile.item_state)
    for index: int in range(16):
        _expect(bool(filled.try_add_normal(StringName("item:filler_%02d" % index), &"filler", 1, false).get("accepted", false)), "pickup-full fixture fills normal slot %02d" % index)
    profile.item_state = filled.to_dictionary()
    var floor_before := profile.tower_floor_states["1"] as Dictionary
    var rejected: Dictionary = DROP_SERVICE.collect_player_drop(profile, 1, source_id, &"pickup:full_grid")
    _expect(not bool(rejected.get("accepted", true)) and StringName(rejected.get("reason_id", &"")) == DROP_SERVICE.REASON_INVENTORY_FULL, "player-drop pickup rejects when all 16 normal slots are occupied")
    _expect((profile.tower_floor_states["1"] as Dictionary) == floor_before, "full-grid rejection preserves the saved player-drop source")


func _test_random_loot_is_not_player_drop() -> void:
    var profile := ProfileCreationService.create_profile(3, "Drop Kind", "mage")
    profile.tower_floor_states["1"] = _floor_state().to_dictionary()
    var floor := _load_floor(profile)
    floor.loose_items["source:ordinary_loot"] = {
        "source_id": "source:ordinary_loot",
        "claim_id": "claim:ordinary_loot",
        "rewards": [],
    }
    profile.tower_floor_states["1"] = floor.to_dictionary()
    var before := profile.to_dictionary()
    var rejected: Dictionary = DROP_SERVICE.collect_player_drop(profile, 1, &"source:ordinary_loot", &"pickup:not_player_drop")
    _expect(not bool(rejected.get("accepted", true)) and StringName(rejected.get("reason_id", &"")) == DROP_SERVICE.REASON_NOT_PLAYER_DROP, "player-drop pickup cannot consume ordinary resolved loot entries")
    _expect(profile.to_dictionary() == before, "wrong loose-item kind rejection mutates nothing")


func _floor_state() -> FloorInstanceState:
    var floor := FloorInstanceState.new()
    floor.floor_id = 1
    floor.instance_id = &"floor_instance:drop_test"
    floor.seed = 101
    floor.layout_revision_id = &"layout:drop_test"
    return floor


func _load_floor(profile: ProfileSnapshot) -> FloorInstanceState:
    var floor := FloorInstanceState.new()
    var raw := profile.tower_floor_states.get("1", {}) as Dictionary
    var errors := floor.load_dictionary(raw)
    _expect(errors.is_empty(), "drop fixture floor state loads")
    return floor


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
