extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Ownership Gate", "melee")
    _expect(profile != null, "exclusive-ownership fixture creates profile")
    if profile == null:
        quit(1)
        return
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "new profile remains valid with empty world ownership")

    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "portable inventory initializes")
    for item_id: StringName in [&"item:portable", &"item:stored", &"item:region", &"item:tower", &"item:tower_two"]:
        _expect(bool(inventory.try_add_normal(item_id, &"material_ownership", 1, false).get("accepted", false)), "normal item identity %s is authored as a valid test stack" % String(item_id))
    var stack_by_id: Dictionary = {}
    for stack: Dictionary in inventory.to_dictionary().get("normal_slots", []) as Array:
        stack_by_id[String(stack["item_instance_id"])] = stack.duplicate(true)

    # No owner may duplicate an existing item, even when every individual
    # InventoryState/StorageState/PlayerDropStateValidator record is valid.
    var baseline := profile.to_dictionary()
    var portable := baseline.get("item_state", {}) as Dictionary
    portable["normal_slots"] = [stack_by_id["item:portable"].duplicate(true)]
    var storage := StorageState.new()
    _expect(bool(storage.try_add_normal(&"item:stored", &"material_ownership", 1, false).get("accepted", false)), "storage fixture contains a distinct normal item")
    baseline["storage_state"] = storage.to_dictionary()
    baseline["region_state"] = {
        "region_id": 3,
        "map_revision_id": String(Region3AuthoredTownLayout.MAP_REVISION_ID),
        "explored_zone_ids": [],
        "loose_items": {
            "player_drop:region": _entry("player_drop:region", stack_by_id["item:region"])
        },
    }
    var floor_one := _floor(1)
    floor_one.loose_items["player_drop:tower_one"] = _entry("player_drop:tower_one", stack_by_id["item:tower"])
    var floor_two := _floor(2)
    floor_two.loose_items["player_drop:tower_two"] = _entry("player_drop:tower_two", stack_by_id["item:tower_two"])
    baseline["tower_floor_states"] = {"1": floor_one.to_dictionary(), "2": floor_two.to_dictionary()}
    _expect(ProfileSnapshot.validate_dictionary(baseline).is_empty(), "distinct normal identities in inventory/storage/Region/two Tower floors all validate")

    var inventory_storage := baseline.duplicate(true)
    (inventory_storage["storage_state"] as Dictionary)["normal_slots"] = [stack_by_id["item:portable"].duplicate(true)]
    _expect(_duplicate_at(inventory_storage, "storage_state"), "duplicate portable/storage identity fails whole-profile validation")

    var inventory_region := baseline.duplicate(true)
    _change_drop_item(inventory_region, "region_state", "", "player_drop:region", stack_by_id["item:portable"])
    _expect(_duplicate_at(inventory_region, "region_state"), "duplicate portable/Region-drop identity fails whole-profile validation")

    var storage_region := baseline.duplicate(true)
    _change_drop_item(storage_region, "region_state", "", "player_drop:region", stack_by_id["item:stored"])
    _expect(_duplicate_at(storage_region, "region_state"), "duplicate storage/Region-drop identity fails whole-profile validation")

    var region_tower := baseline.duplicate(true)
    _change_drop_item(region_tower, "tower_floor_states", "1", "player_drop:tower_one", stack_by_id["item:region"])
    _expect(_duplicate_at(region_tower, "tower_floor_states[1]"), "duplicate Region/Tower-drop identity fails whole-profile validation")

    var floor_to_floor := baseline.duplicate(true)
    _change_drop_item(floor_to_floor, "tower_floor_states", "2", "player_drop:tower_two", stack_by_id["item:tower"])
    _expect(_duplicate_at(floor_to_floor, "tower_floor_states[2]"), "duplicate across separate Tower floors fails whole-profile validation")

    var portable_tower := baseline.duplicate(true)
    _change_drop_item(portable_tower, "tower_floor_states", "1", "player_drop:tower_one", stack_by_id["item:portable"])
    _expect(_duplicate_at(portable_tower, "tower_floor_states[1]"), "duplicate portable/Tower-drop identity fails whole-profile validation")

    var region_twice := baseline.duplicate(true)
    var region_loose := (region_twice["region_state"] as Dictionary)["loose_items"] as Dictionary
    region_loose["player_drop:region_again"] = _entry("player_drop:region_again", stack_by_id["item:region"])
    _expect(_duplicate_at(region_twice, "region_state"), "two distinct Region sources cannot own one item instance")

    var ordinary_loot := baseline.duplicate(true)
    var ordinary_floor := (ordinary_loot["tower_floor_states"] as Dictionary)["1"] as Dictionary
    var ordinary_loose := ordinary_floor["loose_items"] as Dictionary
    ordinary_loose["source:ordinary_loot"] = {
        "source_id": "source:ordinary_loot",
        "claim_id": "claim:ordinary_loot",
        "rewards": [],
    }
    _expect(ProfileSnapshot.validate_dictionary(ordinary_loot).is_empty(), "ordinary resolved-loot entries remain compatible and do not fabricate owned item instances")

    _expect(ProfileSnapshot.validate_dictionary(baseline).is_empty(), "rejected duplicate candidates never mutate valid base state")
    if _failures == 0:
        print("NORMAL ITEM OWNERSHIP VALIDATION TEST PASS")
    else:
        push_error("NORMAL ITEM OWNERSHIP VALIDATION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _entry(source_id: String, item: Dictionary) -> Dictionary:
    return {
        "entry_kind": "player_drop",
        "source_id": source_id,
        "item": item.duplicate(true),
        "world_position": {"x": 128.0, "y": 128.0},
    }


func _floor(floor_id: int) -> FloorInstanceState:
    var floor := FloorInstanceState.new()
    floor.floor_id = floor_id
    floor.instance_id = StringName("floor_instance:ownership_%d" % floor_id)
    floor.seed = 100 + floor_id
    floor.layout_revision_id = &"layout:ownership_test"
    return floor


func _change_drop_item(data: Dictionary, state_name: String, floor_id: String, source_id: String, item: Dictionary) -> void:
    var state := data[state_name] as Dictionary
    var loose := state.get("loose_items", {}) as Dictionary
    if state_name == "tower_floor_states":
        loose = (state[floor_id] as Dictionary).get("loose_items", {}) as Dictionary
    var entry := loose[source_id] as Dictionary
    entry["item"] = item.duplicate(true)


func _duplicate_at(candidate: Dictionary, owner: String) -> bool:
    var errors := ProfileSnapshot.validate_dictionary(candidate)
    for error: String in errors:
        if error.contains("multiple normal owners") and error.contains(owner):
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
