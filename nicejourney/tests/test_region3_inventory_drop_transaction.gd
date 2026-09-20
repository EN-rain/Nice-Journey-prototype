extends SceneTree

const SERVICE: Script = preload("res://src/world/region3/items/region3_inventory_drop_transaction_service.gd")
const LAYOUT_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var layout := LAYOUT_SCENE.instantiate() as Region3AuthoredTownLayout
    var profile := ProfileCreationService.create_profile(1, "Region Transaction", "melee")
    _expect(layout != null and profile != null, "Region transaction fixture has authored layout and profile")
    if layout == null or profile == null:
        quit(1)
        return

    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "Region fixture loads starter inventory")
    _expect(bool(inventory.try_add_normal(
        &"item:region_stack", &"material_region_stack", 5, true,
        {"rarity": "rare", "affixes": ["charged"], "upgrade_rank": 2, "source_claim_id": "loot:region_fixture"}
    ).get("accepted", false)), "Region fixture owns a metadata-bearing full stack")
    _expect(inventory.bind_quick_slot(0, &"item:region_stack"), "Region fixture binds a quick reference")
    _expect(inventory.grant_protected(InventoryState.TOWER_SIGIL_ID, true), "Region fixture grants protected Tower Sigil")
    profile.item_state = inventory.to_dictionary()

    var before_missing_state := profile.to_dictionary()
    var missing_state: Dictionary = SERVICE.drop_full_stack(profile, layout, &"drop:missing_region", &"item:region_stack", Vector2(1800.5, 1900.25))
    _expect(_reason(missing_state) == SERVICE.REASON_REGION_STATE_UNAVAILABLE, "Region Drop requires initialized Region state")
    _expect(profile.to_dictionary() == before_missing_state, "missing Region state rejects without mutation")

    _expect(bool(Region3SubzoneDiscoveryService.ensure_initialized(profile, layout).get("accepted", false)), "Region state initializes only from authored layout")

    for invalid_pos: Vector2 in [
        Vector2(NAN, 1800.0),
        Vector2(-1.0, 1800.0),
        Vector2(1800.0, -1.0),
        Vector2(float(layout.map_size_tiles.x * layout.tile_size), 1800.0),
        Vector2(1800.0, float(layout.map_size_tiles.y * layout.tile_size)),
    ]:
        var before_invalid := profile.to_dictionary()
        var rejected: Dictionary = SERVICE.drop_full_stack(profile, layout, &"drop:invalid_pos", &"item:region_stack", invalid_pos)
        _expect(_reason(rejected) == SERVICE.REASON_INVALID_INPUT, "Region Drop rejects nonfinite or out-of-map coordinates: %s" % str(invalid_pos))
        _expect(profile.to_dictionary() == before_invalid, "invalid Region Drop coordinates mutate no owner")

    var before_protected := profile.to_dictionary()
    var protected_result: Dictionary = SERVICE.drop_full_stack(profile, layout, &"drop:protected", InventoryState.TOWER_SIGIL_ID, Vector2(1800.0, 1900.0))
    _expect(_reason(protected_result) == SERVICE.REASON_PROTECTED_ITEM, "Region Drop rejects protected Tower Sigil")
    _expect(StringName(String(protected_result.get("policy_reason_id", &""))) == ProtectedItemOperationPolicy.REASON_PERMANENT_TOWER_SIGIL, "Region protected-item rejection preserves permanent-item reason")
    _expect(profile.to_dictionary() == before_protected, "protected Region Drop mutates nothing")

    var wrong_layout := LAYOUT_SCENE.instantiate() as Region3AuthoredTownLayout
    wrong_layout.map_revision_id = &"region3_town_layout_v99"
    var before_revision := profile.to_dictionary()
    var wrong_revision: Dictionary = SERVICE.drop_full_stack(profile, wrong_layout, &"drop:wrong_revision", &"item:region_stack", Vector2(1800.0, 1900.0))
    _expect(_reason(wrong_revision) == Region3SubzoneDiscoveryService.REASON_MAP_REVISION_MISMATCH, "Region Drop fails closed on a different authored map revision")
    _expect(profile.to_dictionary() == before_revision, "mismatched Region map revision mutates nothing")
    wrong_layout.free()

    var location := Vector2(1800.5, 1900.25)
    var dropped: Dictionary = SERVICE.drop_full_stack(profile, layout, &"drop:region_stack", &"item:region_stack", location)
    _expect(bool(dropped.get("accepted", false)), "Region Drop accepts a full owned stack inside authored bounds")
    _expect(int(dropped.get("quantity", 0)) == 5 and (dropped.get("world_position", Vector2.ZERO) as Vector2).is_equal_approx(location), "Region Drop retains exact full quantity and coordinates")
    _expect(profile.tower_floor_states.is_empty(), "Region Drop creates no Tower floor state")
    var source_id := StringName(String(dropped.get("source_id", &"")))
    var record := ((profile.region_state.get("loose_items", {}) as Dictionary).get(String(source_id), {}) as Dictionary)
    _expect(StringName(String(record.get("entry_kind", &""))) == SERVICE.ENTRY_KIND, "Region loose-item record is a dedicated player_drop")
    _expect((record.get("item", {}) as Dictionary).get("affixes", []) == ["charged"], "Region Drop preserves exact realized item metadata")
    var portable := InventoryState.new()
    portable.load_dictionary(profile.item_state)
    _expect(portable.get_normal_slot(&"item:region_stack").is_empty() and portable.quick_slots[0] == &"", "Region Drop removes item and clears invalid quick reference")
    var ledger := ClaimLedger.new()
    _expect(ledger.load_dictionary(profile.claimed_transactions).is_empty() and ledger.is_claimed(&"drop:region_stack"), "Region Drop claims its exact transaction identity")

    var before_duplicate := profile.to_dictionary()
    var duplicate: Dictionary = SERVICE.drop_full_stack(profile, layout, &"drop:region_stack", &"item:region_stack", location)
    _expect(_reason(duplicate) == SERVICE.REASON_DUPLICATE_TRANSACTION, "repeated Region Drop transaction is rejected")
    _expect(profile.to_dictionary() == before_duplicate, "repeated Region Drop does not move ownership twice")

    var before_missing := profile.to_dictionary()
    var missing: Dictionary = SERVICE.collect_player_drop(profile, layout, &"player_drop:nonexistent", &"pickup:missing")
    _expect(_reason(missing) == SERVICE.REASON_SOURCE_NOT_FOUND and profile.to_dictionary() == before_missing, "missing Region source rejects without profile mutation")

    var valid_region_state := profile.region_state.duplicate(true)
    for invalid_position: Vector2 in [
        Vector2(-0.5, location.y),
        Vector2(float(layout.map_size_tiles.x * layout.tile_size), location.y),
        Vector2(location.x, float(layout.map_size_tiles.y * layout.tile_size)),
    ]:
        var invalid_region := valid_region_state.duplicate(true)
        var loose := invalid_region.get("loose_items", {}) as Dictionary
        var invalid_entry := loose.get(String(source_id), {}) as Dictionary
        invalid_entry["world_position"] = {"x": invalid_position.x, "y": invalid_position.y}
        profile.region_state = invalid_region
        var before_rejected := profile.to_dictionary()
        _expect(Region3SubzoneDiscoveryService.validate_state_dictionary(profile.region_state).is_empty(), "finite off-map record remains structurally valid without an active layout")
        _expect(_contains(Region3SubzoneDiscoveryService.validate_loose_positions_for_layout(profile.region_state, layout), "outside the authored Region 3 map"), "authored layout rejects restored off-map pickup coordinates")
        _expect(_reason(Region3SubzoneDiscoveryService.ensure_initialized(profile, layout)) == Region3SubzoneDiscoveryService.REASON_STATE_INVALID, "Region initialization refuses an off-map persisted pickup")
        _expect(_reason(Region3SubzoneDiscoveryService.explored_zone_entries(profile, layout)) == Region3SubzoneDiscoveryService.REASON_STATE_INVALID, "Region map read-only query fails closed on an off-map persisted pickup")
        _expect(_reason(SERVICE.collect_player_drop(profile, layout, source_id, &"pickup:off_map")) == SERVICE.REASON_REGION_STATE_UNAVAILABLE, "Region pickup refuses off-map persisted source")
        _expect(_reason(SERVICE.drop_full_stack(profile, layout, &"drop:off_map", &"item:unowned", location)) == SERVICE.REASON_REGION_STATE_UNAVAILABLE, "Region drop refuses to mutate already-invalid loose-item state")
        _expect(profile.to_dictionary() == before_rejected, "off-map state rejection never mutates player ownership or location")
    profile.region_state = valid_region_state
    _expect(Region3SubzoneDiscoveryService.validate_loose_positions_for_layout(profile.region_state, layout).is_empty(), "valid persisted Region-local pickup passes authored-layout validation")

    var save_root := "user://region_drop_transaction_%d" % Time.get_ticks_usec()
    var save := SaveService.new(save_root)
    _expect(save.save_profile(1, profile) == OK, "Region drop state commits through ordinary atomic SaveService")
    var restored := save.load_profile(1)
    _expect(restored != null, "Region drop state loads from an actual JSON save")
    if restored != null:
        var loaded_record := ((restored.region_state.get("loose_items", {}) as Dictionary).get(String(source_id), {}) as Dictionary)
        var saved_pos := loaded_record.get("world_position", {}) as Dictionary
        _expect(is_equal_approx(float(saved_pos.get("x", 0)), location.x) and is_equal_approx(float(saved_pos.get("y", 0)), location.y), "Region-local coordinates survive JSON normalization")
        _expect((loaded_record.get("item", {}) as Dictionary).get("affixes", []) == ["charged"], "Region item metadata survives atomic save/load")
        var collected: Dictionary = SERVICE.collect_player_drop(restored, layout, source_id, &"pickup:region_stack")
        _expect(bool(collected.get("accepted", false)), "Region pickup reverses a persisted drop transaction")
        var returned := InventoryState.new()
        _expect(returned.load_dictionary(restored.item_state).is_empty(), "collected Region item leaves inventory valid")
        var item := returned.get_normal_slot(&"item:region_stack")
        _expect(int(item.get("quantity", 0)) == 5 and (item.get("affixes", []) as Array) == ["charged"], "Region pickup preserves instance quantity and affixes")
        _expect(int(item.get("upgrade_rank", 0)) == 2, "Region pickup preserves item upgrade rank")
        _expect(not (restored.region_state.get("loose_items", {}) as Dictionary).has(String(source_id)), "Region pickup consumes only its source")
        _expect(returned.quick_slots[0] == &"", "Region pickup does not invent a quick-reference rebind")
        _expect(restored.tower_floor_states.is_empty(), "Region round trip remains isolated from Tower state")
        _expect(ProfileSnapshot.validate_dictionary(restored.to_dictionary()).is_empty(), "Region drop/pickup round trip remains profile-valid")
        var before_repeat_pickup := restored.to_dictionary()
        var repeat_pickup: Dictionary = SERVICE.collect_player_drop(restored, layout, source_id, &"pickup:region_again")
        _expect(_reason(repeat_pickup) == SERVICE.REASON_SOURCE_NOT_FOUND and restored.to_dictionary() == before_repeat_pickup, "Region source cannot be collected twice")
    save.delete_slot(1)
    layout.free()

    if _failures == 0:
        print("REGION 3 INVENTORY DROP TRANSACTION TEST PASS")
    else:
        push_error("REGION 3 INVENTORY DROP TRANSACTION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _contains(errors: PackedStringArray, fragment: String) -> bool:
    for error: String in errors:
        if error.contains(fragment):
            return true
    return false


func _reason(result: Dictionary) -> StringName:
    return StringName(String(result.get("reason_id", &"")))


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
