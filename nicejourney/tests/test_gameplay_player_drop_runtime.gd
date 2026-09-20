extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const DROP_SERVICE: Script = preload("res://src/items/inventory_drop_transaction_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    await _test_fresh_drop_runtime_round_trip()
    await _test_restored_drop_runtime_and_full_inventory_retry()
    if _failures == 0:
        print("GAMEPLAY PLAYER DROP RUNTIME TEST PASS")
    else:
        push_error("GAMEPLAY PLAYER DROP RUNTIME TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_fresh_drop_runtime_round_trip() -> void:
    var profile := ProfileCreationService.create_profile(1, "Live Drop", "melee")
    var floor := _build_floor_state(1, 91001)
    _expect(profile != null and floor != null, "fresh-drop runtime fixture creates profile and floor")
    if profile == null or floor == null:
        return
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "fresh-drop runtime fixture loads starter inventory")
    _expect(bool(inventory.try_add_normal(&"item:live_drop", &"material_live_drop", 3, true).get("accepted", false)), "fresh-drop runtime fixture owns a normal stack")
    profile.item_state = inventory.to_dictionary()
    profile.tower_floor_states["1"] = floor.to_dictionary()

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame
    _expect(_activate_floor(gameplay, floor), "fresh-drop runtime fixture activates authored Floor 1 runtime")
    if not gameplay.is_tower_floor_active():
        gameplay.queue_free()
        await process_frame
        return

    var drop_local_position := gameplay.tower_floor_session_host.to_local(gameplay.player.global_position)
    var dropped: Dictionary = gameplay.request_inventory_drop(&"item:live_drop")
    _expect(bool(dropped.get("accepted", false)), "Inventory Drop moves a selected full stack into the active Tower floor")
    _expect(not bool(dropped.get("durable", true)) and StringName(dropped.get("durability_boundary", &"")) == &"next_safe_snapshot", "Tower Drop follows DR-02 live-unbanked semantics")
    _expect(bool(dropped.get("runtime_pickup_ready", false)), "accepted Tower Drop materializes a live pickup from its saved player_drop record")
    _expect((dropped.get("world_position", Vector2.ZERO) as Vector2).is_equal_approx(drop_local_position), "Tower Drop saves exact floor-local player position instead of global/fabricated coordinates")

    var after_drop_inventory := InventoryState.new()
    _expect(after_drop_inventory.load_dictionary(profile.item_state).is_empty() and after_drop_inventory.get_normal_slot(&"item:live_drop").is_empty(), "portable ownership leaves inventory after the accepted drop")
    var pickup := _single_pickup(gameplay)
    _expect(pickup != null, "fresh player_drop record has one live pickup node")
    if pickup != null:
        _expect(bool(pickup.call("requires_player_exit")), "fresh drop cannot immediately auto-pick itself up while the player still overlaps it")
        pickup.call("_on_body_entered", gameplay.player)
        _expect(InventoryState.new().load_dictionary(profile.item_state).is_empty(), "blocked immediate re-entry leaves inventory state valid")
        var still_missing := InventoryState.new()
        still_missing.load_dictionary(profile.item_state)
        _expect(still_missing.get_normal_slot(&"item:live_drop").is_empty(), "fresh overlap does not undo the drop before player exits")
        pickup.call("_on_body_exited", gameplay.player)
        pickup.call("_on_body_entered", gameplay.player)
        await process_frame
        var collected_inventory := InventoryState.new()
        _expect(collected_inventory.load_dictionary(profile.item_state).is_empty(), "live pickup restores a valid inventory")
        _expect(int(collected_inventory.get_normal_slot(&"item:live_drop").get("quantity", 0)) == 3, "live pickup restores exact dropped stack identity and quantity")
        _expect(bool(gameplay.last_tower_player_drop_result.get("accepted", false)), "GameplayRoot records the accepted reverse pickup transaction")
        var floor_after := _load_floor(profile, 1)
        var source_id := StringName(String(dropped.get("source_id", &"")))
        _expect(floor_after != null and not floor_after.loose_items.has(String(source_id)), "accepted live pickup removes the exact persisted player_drop source")

    gameplay.queue_free()
    await process_frame


func _test_restored_drop_runtime_and_full_inventory_retry() -> void:
    var profile := ProfileCreationService.create_profile(2, "Restored Drop", "ranged")
    var floor := _build_floor_state(1, 91002)
    _expect(profile != null and floor != null, "restored-drop runtime fixture creates profile and floor")
    if profile == null or floor == null:
        return
    var inventory := InventoryState.new()
    inventory.load_dictionary(profile.item_state)
    _expect(bool(inventory.try_add_normal(&"item:restored_drop", &"material_restored_drop", 1, false).get("accepted", false)), "restored-drop fixture owns source item before saving it to floor state")
    profile.item_state = inventory.to_dictionary()
    profile.tower_floor_states["1"] = floor.to_dictionary()
    var seeded_drop: Dictionary = DROP_SERVICE.drop_full_stack(profile, 1, &"transaction:seed_restored_drop", &"item:restored_drop", Vector2(96.0, 96.0))
    _expect(bool(seeded_drop.get("accepted", false)), "restored-drop fixture seeds exact player_drop persistence before runtime activation")

    var full := InventoryState.new()
    full.load_dictionary(profile.item_state)
    for index: int in range(16):
        _expect(bool(full.try_add_normal(StringName("item:runtime_full_%02d" % index), &"filler", 1, false).get("accepted", false)), "restored-drop full-grid fixture fills slot %02d" % index)
    profile.item_state = full.to_dictionary()
    var persisted_floor := _load_floor(profile, 1)
    if persisted_floor == null:
        return

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame
    _expect(_activate_floor(gameplay, persisted_floor), "restored player_drop runtime activates from persisted floor state")
    var pickup := _single_pickup(gameplay)
    _expect(pickup != null, "persisted player_drop is reconstructed as a live pickup when the floor loads")
    if pickup != null:
        _expect(not bool(pickup.call("requires_player_exit")), "restored pickup is immediately collectable on legitimate contact")
        pickup.call("_on_body_entered", gameplay.player)
        _expect(StringName(gameplay.last_tower_player_drop_result.get("reason_id", &"")) == DROP_SERVICE.REASON_INVENTORY_FULL, "full inventory live pickup surfaces exact capacity rejection")
        _expect(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(), "capacity rejection leaves the live world pickup intact")
        var floor_after_reject := _load_floor(profile, 1)
        var source_id := StringName(String(seeded_drop.get("source_id", &"")))
        _expect(floor_after_reject != null and floor_after_reject.loose_items.has(String(source_id)), "capacity rejection preserves the persisted player_drop source")

        var reduced := InventoryState.new()
        reduced.load_dictionary(profile.item_state)
        var filler := reduced.get_normal_slot(&"item:runtime_full_00")
        _expect(not filler.is_empty() and bool(reduced.try_remove_normal(&"item:runtime_full_00", 1).get("accepted", false)), "runtime retry fixture frees one normal slot")
        profile.item_state = reduced.to_dictionary()
        pickup.call("_on_body_exited", gameplay.player)
        pickup.call("_on_body_entered", gameplay.player)
        await process_frame
        var restored_inventory := InventoryState.new()
        restored_inventory.load_dictionary(profile.item_state)
        _expect(not restored_inventory.get_normal_slot(&"item:restored_drop").is_empty(), "live pickup succeeds after capacity becomes available")
        _expect(not _load_floor(profile, 1).loose_items.has(String(source_id)), "successful retry removes the persisted player_drop source")

    gameplay.queue_free()
    await process_frame


func _build_floor_state(floor_id: int, seed: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        seed,
        &"generator:player_drop_runtime_v01",
        &"modules:prototype_v01",
        &"encounters:prototype_v01",
        &"questflags:player_drop_runtime_v01"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return null
    return TowerFloorGenerationCommitService.floor_state_from_manifest(StringName("floor_instance:player_drop_runtime_%d_%d" % [floor_id, seed]), manifest)


func _activate_floor(gameplay: GameplayRoot, floor: FloorInstanceState) -> bool:
    var compose := TowerFloorRuntimeComposer.build(floor.layout_manifest, VISUAL_CATALOG)
    if not bool(compose.get("accepted", false)):
        return false
    var arrival := TowerArrivalResolver.resolve_entrance(floor)
    if not bool(arrival.get("accepted", false)):
        (compose.get("root") as Node2D).free()
        return false
    return gameplay.activate_committed_tower_travel({
        "accepted": true,
        "runtime_root": compose.get("root"),
        "arrival": arrival,
    })


func _single_pickup(gameplay: GameplayRoot) -> Area2D:
    if not gameplay.is_tower_floor_active():
        return null
    var runtime_root := gameplay.tower_floor_session_host.active_runtime_root
    var container := runtime_root.get_node_or_null("PlayerDrops") as Node2D
    if container == null:
        return null
    for child: Node in container.get_children():
        if child is Area2D:
            return child as Area2D
    return null


func _load_floor(profile: ProfileSnapshot, floor_id: int) -> FloorInstanceState:
    var raw: Variant = profile.tower_floor_states.get(str(floor_id), null)
    if not raw is Dictionary:
        return null
    var floor := FloorInstanceState.new()
    if not floor.load_dictionary(raw as Dictionary).is_empty():
        return null
    return floor


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
