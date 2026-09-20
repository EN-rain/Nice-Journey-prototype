extends SceneTree

const PLAYER_DROP_VALIDATOR: Script = preload("res://src/items/player_drop_state_validator.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var source_id := StringName("player_drop:tx_validation")
    var valid_entry := _entry(source_id)
    _expect((PLAYER_DROP_VALIDATOR.validate_entry(valid_entry, source_id) as PackedStringArray).is_empty(), "standalone player-drop schema accepts a valid exact item/position record")

    var floor := _floor_state()
    floor.loose_items[String(source_id)] = valid_entry.duplicate(true)
    _expect(FloorInstanceState.validate_dictionary(floor.to_dictionary()).is_empty(), "FloorInstanceState accepts a valid persisted player drop")

    var random_loot_floor := _floor_state()
    random_loot_floor.loose_items["source:ordinary_loot"] = {
        "source_id": "source:ordinary_loot",
        "claim_id": "claim:ordinary_loot",
        "rewards": [],
    }
    _expect(FloorInstanceState.validate_dictionary(random_loot_floor.to_dictionary()).is_empty(), "player-drop validation does not reinterpret existing random-loot entries")

    var source_mismatch := _floor_state()
    var mismatch_entry := valid_entry.duplicate(true)
    mismatch_entry["source_id"] = "player_drop:other"
    source_mismatch.loose_items[String(source_id)] = mismatch_entry
    _expect(not FloorInstanceState.validate_dictionary(source_mismatch.to_dictionary()).is_empty(), "floor validation rejects player-drop source/key identity mismatch")

    var bad_position := _floor_state()
    var bad_position_entry := valid_entry.duplicate(true)
    bad_position_entry["world_position"] = {"x": INF, "y": 20.0}
    bad_position.loose_items[String(source_id)] = bad_position_entry
    _expect(not FloorInstanceState.validate_dictionary(bad_position.to_dictionary()).is_empty(), "floor validation rejects nonfinite player-drop positions")

    var bad_item := _floor_state()
    var bad_item_entry := valid_entry.duplicate(true)
    var invalid_item := (bad_item_entry["item"] as Dictionary).duplicate(true)
    invalid_item["quantity"] = 0
    bad_item_entry["item"] = invalid_item
    bad_item.loose_items[String(source_id)] = bad_item_entry
    _expect(not FloorInstanceState.validate_dictionary(bad_item.to_dictionary()).is_empty(), "floor validation rejects invalid dropped-item quantity/state")

    var prefix_non_dictionary := _floor_state()
    prefix_non_dictionary.loose_items[String(source_id)] = "corrupt"
    _expect(not FloorInstanceState.validate_dictionary(prefix_non_dictionary.to_dictionary()).is_empty(), "player_drop:* keys cannot hide non-dictionary corruption")

    var disguised := _floor_state()
    var disguised_entry := valid_entry.duplicate(true)
    disguised_entry["source_id"] = "source:disguised"
    disguised.loose_items["source:disguised"] = disguised_entry
    _expect(not FloorInstanceState.validate_dictionary(disguised.to_dictionary()).is_empty(), "entry_kind player_drop cannot bypass player-drop source namespace validation")

    var json_integral := _floor_state()
    var json_entry := valid_entry.duplicate(true)
    var json_item := (json_entry["item"] as Dictionary).duplicate(true)
    json_item["quantity"] = 1.0
    json_entry["item"] = json_item
    json_entry["world_position"] = {"x": 128.0, "y": 64.0}
    json_integral.loose_items[String(source_id)] = json_entry
    _expect(FloorInstanceState.validate_dictionary(json_integral.to_dictionary()).is_empty(), "player-drop persistence accepts finite integral JSON quantity representation")

    var profile := ProfileCreationService.create_profile(1, "Drop Validation", "melee")
    profile.tower_floor_states["1"] = floor.to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "valid player-drop floor state passes whole-profile persistence validation")
    profile.tower_floor_states["1"] = bad_position.to_dictionary()
    _expect(not ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "malformed player-drop state is rejected at whole-profile save validation")

    if _failures == 0:
        print("PLAYER DROP STATE VALIDATION TEST PASS")
    else:
        push_error("PLAYER DROP STATE VALIDATION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _entry(source_id: StringName) -> Dictionary:
    return {
        "entry_kind": "player_drop",
        "source_id": String(source_id),
        "item": {
            "item_instance_id": "item:drop_validation",
            "definition_id": "item_def:drop_validation",
            "quantity": 1,
            "stackable": false,
            "rarity": "rare",
            "affixes": ["affix:validation"],
            "upgrade_rank": 2,
            "source_claim_id": "claim:drop_validation",
        },
        "world_position": {"x": 128.0, "y": 64.0},
    }


func _floor_state() -> FloorInstanceState:
    var floor := FloorInstanceState.new()
    floor.floor_id = 1
    floor.instance_id = &"floor_instance:drop_validation"
    floor.seed = 7
    floor.layout_revision_id = &"layout:drop_validation"
    return floor


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
