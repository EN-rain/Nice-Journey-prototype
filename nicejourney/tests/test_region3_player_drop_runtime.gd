extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const REGION3_LAYOUT_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const REGION3_DROP_SERVICE: Script = preload("res://src/world/region3/items/region3_inventory_drop_transaction_service.gd")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    await _test_fresh_region_drop_round_trip()
    await _test_restored_region_drop_and_full_inventory_retry()
    await _test_off_map_restored_drop_rejected()
    if _failures == 0:
        print("REGION 3 PLAYER DROP RUNTIME TEST PASS")
    else:
        push_error("REGION 3 PLAYER DROP RUNTIME TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_fresh_region_drop_round_trip() -> void:
    var profile := ProfileCreationService.create_profile(1, "Region Live Drop", "melee")
    _expect(profile != null, "fresh Region-drop fixture creates a profile")
    if profile == null:
        return

    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "fresh Region-drop fixture loads starter inventory")
    _expect(bool(inventory.try_add_normal(&"item:region_live_drop", &"material_region_live_drop", 3, true).get("accepted", false)), "fresh Region-drop fixture owns a normal stack")
    profile.item_state = inventory.to_dictionary()

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame
    _expect(_activate_region(gameplay), "fresh Region-drop fixture activates the authored Region 3 runtime")
    if not gameplay.is_region3_active():
        gameplay.queue_free()
        await process_frame
        return

    var status := gameplay.get_inventory_drop_status()
    _expect(bool(status.get("allowed", false)) and StringName(String(status.get("world_kind", &""))) == &"region3", "Inventory Drop is admitted in live Region 3 without requiring a Tower floor")
    var drop_local_position := gameplay.region3_town_session_host.to_local(gameplay.player.global_position)
    var dropped := gameplay.request_inventory_drop(&"item:region_live_drop")
    _expect(bool(dropped.get("accepted", false)), "Region Inventory Drop moves the selected full stack into Region loose-item persistence")
    _expect(StringName(String(dropped.get("world_kind", &""))) == &"region3", "Region Inventory Drop reports its Region world owner")
    _expect(not bool(dropped.get("durable", true)) and StringName(String(dropped.get("durability_boundary", &""))) == &"next_safe_snapshot", "Region Drop follows DR-02 live-unbanked semantics")
    _expect(bool(dropped.get("runtime_pickup_ready", false)), "accepted Region Drop materializes a live Region pickup")
    _expect((dropped.get("world_position", Vector2.ZERO) as Vector2).is_equal_approx(drop_local_position), "Region Drop saves exact Region-local player coordinates")
    _expect(profile.tower_floor_states.is_empty(), "Region Drop creates no Tower floor persistence")

    var source_id := StringName(String(dropped.get("source_id", &"")))
    var loose_items := profile.region_state.get("loose_items", {}) as Dictionary
    _expect(loose_items.has(String(source_id)), "Region state owns the exact persisted player_drop source")

    var after_drop_inventory := InventoryState.new()
    _expect(after_drop_inventory.load_dictionary(profile.item_state).is_empty() and after_drop_inventory.get_normal_slot(&"item:region_live_drop").is_empty(), "portable ownership leaves inventory after accepted Region Drop")

    var pickup := _single_region_pickup(gameplay)
    _expect(pickup != null, "fresh Region player_drop record has one live pickup node")
    if pickup != null:
        _expect(bool(pickup.call("requires_player_exit")), "fresh Region Drop cannot immediately auto-pick itself up")
        pickup.call("_on_body_entered", gameplay.player)
        var still_missing := InventoryState.new()
        still_missing.load_dictionary(profile.item_state)
        _expect(still_missing.get_normal_slot(&"item:region_live_drop").is_empty(), "fresh overlap does not undo Region Drop before the player exits")
        pickup.call("_on_body_exited", gameplay.player)
        pickup.call("_on_body_entered", gameplay.player)
        await process_frame

        var collected_inventory := InventoryState.new()
        _expect(collected_inventory.load_dictionary(profile.item_state).is_empty(), "Region live pickup restores a valid inventory")
        _expect(int(collected_inventory.get_normal_slot(&"item:region_live_drop").get("quantity", 0)) == 3, "Region live pickup restores exact dropped stack identity and quantity")
        _expect(bool(gameplay.last_region3_player_drop_result.get("accepted", false)), "GameplayRoot records the accepted Region reverse-pickup transaction")
        loose_items = profile.region_state.get("loose_items", {}) as Dictionary
        _expect(not loose_items.has(String(source_id)), "accepted Region pickup removes the exact persisted player_drop source")

    gameplay.queue_free()
    await process_frame


func _test_restored_region_drop_and_full_inventory_retry() -> void:
    var profile := ProfileCreationService.create_profile(2, "Region Restored Drop", "ranged")
    var seed_layout := REGION3_LAYOUT_SCENE.instantiate() as Region3AuthoredTownLayout
    _expect(profile != null and seed_layout != null, "restored Region-drop fixture creates profile and authored layout")
    if profile == null or seed_layout == null:
        if seed_layout != null:
            seed_layout.free()
        return

    _expect(bool(Region3SubzoneDiscoveryService.ensure_initialized(profile, seed_layout).get("accepted", false)), "restored Region-drop fixture initializes map-revision-bound Region state")
    var inventory := InventoryState.new()
    inventory.load_dictionary(profile.item_state)
    _expect(bool(inventory.try_add_normal(&"item:region_restored_drop", &"material_region_restored_drop", 1, false).get("accepted", false)), "restored Region-drop fixture owns source item")
    profile.item_state = inventory.to_dictionary()

    var seeded_drop: Dictionary = REGION3_DROP_SERVICE.drop_full_stack(
        profile,
        seed_layout,
        &"transaction:seed_region_restored_drop",
        &"item:region_restored_drop",
        Vector2(96.0, 96.0)
    )
    _expect(bool(seeded_drop.get("accepted", false)), "restored Region-drop fixture seeds exact Region player_drop persistence")
    var serialized_with_drop := profile.to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(serialized_with_drop).is_empty(), "Region player_drop state validates as part of the whole profile")
    var restored_profile := ProfileSnapshot.from_dictionary(serialized_with_drop)
    _expect(restored_profile.region_state == profile.region_state, "Region loose-item state round-trips through ProfileSnapshot serialization")
    seed_layout.free()

    var full := InventoryState.new()
    full.load_dictionary(profile.item_state)
    for index: int in range(16):
        _expect(bool(full.try_add_normal(StringName("item:region_runtime_full_%02d" % index), &"filler", 1, false).get("accepted", false)), "restored Region-drop fixture fills slot %02d" % index)
    profile.item_state = full.to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "restored Region-drop fixture remains a valid serializable profile")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame
    _expect(_activate_region(gameplay), "persisted Region player_drop runtime activates from Region state")
    if not gameplay.is_region3_active():
        gameplay.queue_free()
        await process_frame
        return

    var pickup := _single_region_pickup(gameplay)
    _expect(pickup != null, "persisted Region player_drop reconstructs as a live pickup when Region 3 loads")
    if pickup != null:
        _expect(not bool(pickup.call("requires_player_exit")), "restored Region pickup is immediately collectable on legitimate contact")
        pickup.call("_on_body_entered", gameplay.player)
        _expect(StringName(String(gameplay.last_region3_player_drop_result.get("reason_id", &""))) == Region3InventoryDropTransactionService.REASON_INVENTORY_FULL, "full inventory Region pickup surfaces exact capacity rejection")
        _expect(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(), "capacity rejection leaves the Region world pickup intact")
        var source_id := StringName(String(seeded_drop.get("source_id", &"")))
        var loose_items := profile.region_state.get("loose_items", {}) as Dictionary
        _expect(loose_items.has(String(source_id)), "capacity rejection preserves the Region player_drop source")

        var reduced := InventoryState.new()
        reduced.load_dictionary(profile.item_state)
        _expect(bool(reduced.try_remove_normal(&"item:region_runtime_full_00", 1).get("accepted", false)), "Region retry fixture frees one normal inventory slot")
        profile.item_state = reduced.to_dictionary()
        pickup.call("_on_body_exited", gameplay.player)
        pickup.call("_on_body_entered", gameplay.player)
        await process_frame

        var restored_inventory := InventoryState.new()
        restored_inventory.load_dictionary(profile.item_state)
        _expect(not restored_inventory.get_normal_slot(&"item:region_restored_drop").is_empty(), "Region pickup succeeds after inventory capacity becomes available")
        loose_items = profile.region_state.get("loose_items", {}) as Dictionary
        _expect(not loose_items.has(String(source_id)), "successful Region retry removes the persisted player_drop source")
        _expect(profile.tower_floor_states.is_empty(), "restored Region Drop path remains isolated from Tower persistence")

    gameplay.queue_free()
    await process_frame


func _test_off_map_restored_drop_rejected() -> void:
    var profile := ProfileCreationService.create_profile(3, "Off Map Region Drop", "mage")
    var seed_layout := REGION3_LAYOUT_SCENE.instantiate() as Region3AuthoredTownLayout
    _expect(profile != null and seed_layout != null, "off-map Region runtime fixture creates profile and layout")
    if profile == null or seed_layout == null:
        if seed_layout != null:
            seed_layout.free()
        return
    _expect(bool(Region3SubzoneDiscoveryService.ensure_initialized(profile, seed_layout).get("accepted", false)), "off-map Region runtime fixture initializes revision-bound Region state")
    var inventory := InventoryState.new()
    inventory.load_dictionary(profile.item_state)
    _expect(bool(inventory.try_add_normal(&"item:off_map_drop", &"material_off_map_drop", 1, false).get("accepted", false)), "off-map Region runtime fixture owns item")
    profile.item_state = inventory.to_dictionary()
    var seeded: Dictionary = REGION3_DROP_SERVICE.drop_full_stack(profile, seed_layout, &"drop:off_map_runtime", &"item:off_map_drop", Vector2(1920.0, 2048.0))
    _expect(bool(seeded.get("accepted", false)), "off-map Region runtime fixture seeds legitimate drop before position corruption")
    var source_id := StringName(String(seeded.get("source_id", &"")))
    var loose := profile.region_state.get("loose_items", {}) as Dictionary
    var entry := loose.get(String(source_id), {}) as Dictionary
    entry["world_position"] = {"x": float(seed_layout.map_size_tiles.x * seed_layout.tile_size), "y": 2048.0}
    seed_layout.free()
    var before_rejected := profile.to_dictionary()
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame
    var live_layout := REGION3_LAYOUT_SCENE.instantiate() as Region3AuthoredTownLayout
    var arrival := gameplay.region3_town_session_host.resolve_start_position(live_layout)
    _expect(not gameplay.activate_region3_runtime(live_layout, arrival), "Region activation refuses an off-map persisted drop before pickup reconstruction")
    _expect(not gameplay.is_region3_active(), "invalid Region loose-item state leaves Region runtime inactive")
    _expect(profile.to_dictionary() == before_rejected, "failed Region activation preserves exact corrupt saved state without silently discarding the item")
    if is_instance_valid(live_layout) and live_layout.get_parent() == null:
        live_layout.free()
    gameplay.queue_free()
    await process_frame


func _activate_region(gameplay: GameplayRoot) -> bool:
    var layout := REGION3_LAYOUT_SCENE.instantiate() as Region3AuthoredTownLayout
    if layout == null:
        return false
    var arrival := gameplay.region3_town_session_host.resolve_start_position(layout)
    if not is_finite(arrival.x) or not is_finite(arrival.y):
        layout.free()
        return false
    if gameplay.activate_region3_runtime(layout, arrival):
        return true
    if layout.get_parent() == null:
        layout.free()
    return false


func _single_region_pickup(gameplay: GameplayRoot) -> Area2D:
    if not gameplay.is_region3_active():
        return null
    var runtime_root := gameplay.region3_town_session_host.active_runtime_root
    if runtime_root == null:
        return null
    var container := runtime_root.get_node_or_null("PlayerDrops") as Node2D
    if container == null:
        return null
    for child: Node in container.get_children():
        if child is Area2D:
            return child as Area2D
    return null


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
