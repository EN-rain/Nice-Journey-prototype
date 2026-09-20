extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Drop Menu", "melee")
    var floor := _build_floor_state(1, 92001)
    _expect(profile != null and floor != null, "Inventory Drop UI fixture creates profile and authored floor")
    if profile == null or floor == null:
        quit(1)
        return

    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "Inventory Drop UI fixture loads starter inventory")
    _expect(bool(inventory.try_add_normal(&"item:drop_menu_stack", &"material_drop_menu", 4, true).get("accepted", false)), "Inventory Drop UI fixture owns one normal stack")
    profile.item_state = inventory.to_dictionary()
    profile.tower_floor_states["1"] = floor.to_dictionary()

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame

    var menu: Node = gameplay.get_node("InventoryMenu")
    var grid := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/Body/Left/Grid") as GridContainer
    var equipment := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/Body/Right/Equipment") as ItemList
    var drop_button := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/ActionRow/Drop") as Button
    var status := gameplay.get_node("InventoryMenu/Overlay/Panel/Scroller/Layout/Status") as Label

    _expect(bool(menu.call("open_menu")), "Inventory Drop UI opens before Tower entry")
    var normal_button := grid.get_child(0) as Button
    normal_button.emit_signal("pressed")
    _expect(drop_button.disabled, "Drop stays disabled outside an active Tower floor because Region/world loose-item persistence is unavailable")
    menu.call("close_menu")

    _expect(_activate_floor(gameplay, floor), "Inventory Drop UI fixture activates the authored Tower floor")
    _expect(bool(menu.call("open_menu")), "Inventory Drop UI reopens on active Tower floor")
    normal_button = grid.get_child(0) as Button
    normal_button.emit_signal("pressed")
    _expect(not drop_button.disabled, "selected normal ownership enables Drop on an active Tower floor")

    equipment.select(0)
    menu.call("_on_equipment_selected", 0)
    _expect(drop_button.disabled, "equipped ownership never enables the normal-item Drop control")
    normal_button.emit_signal("pressed")
    _expect(not drop_button.disabled, "returning to selected normal ownership restores Tower Drop availability")

    var before_position := gameplay.tower_floor_session_host.to_local(gameplay.player.global_position)
    drop_button.emit_signal("pressed")
    await process_frame

    var after_inventory := InventoryState.new()
    _expect(after_inventory.load_dictionary(profile.item_state).is_empty(), "Inventory Drop UI leaves a valid portable inventory")
    _expect(after_inventory.get_normal_slot(&"item:drop_menu_stack").is_empty(), "Inventory Drop UI moves the exact selected stack out of portable ownership")
    _expect(status.text.contains("Tower floor") and status.text.contains("unbanked"), "Inventory Drop UI reports floor-local live pickup plus DR-02 unbanked durability")

    var pickup := _single_pickup(gameplay)
    _expect(pickup != null, "Inventory Drop UI materializes exactly one live Tower pickup")
    if pickup != null:
        _expect(bool(pickup.call("requires_player_exit")), "newly dropped UI pickup cannot auto-recollect while the player still overlaps it")
        _expect((pickup.position as Vector2).is_equal_approx(before_position), "Inventory Drop UI live pickup uses the exact persisted floor-local player position")

    var floor_after := _load_floor(profile, 1)
    _expect(floor_after != null, "Inventory Drop UI preserves a valid Tower floor state")
    if floor_after != null:
        var player_drop_count := 0
        for raw_entry: Variant in floor_after.loose_items.values():
            if raw_entry is Dictionary and StringName(String((raw_entry as Dictionary).get("entry_kind", &""))) == &"player_drop":
                player_drop_count += 1
        _expect(player_drop_count == 1, "Inventory Drop UI persists exactly one player_drop source")

    _expect(int((menu.call("current_snapshot") as Dictionary).get("occupied_normal_slots", -1)) == 0, "Inventory Drop UI refreshes immediately after the accepted drop")

    menu.call("close_menu")
    gameplay.queue_free()
    await process_frame

    if _failures == 0:
        print("INVENTORY DROP MENU UI TEST PASS")
    else:
        push_error("INVENTORY DROP MENU UI TEST FAILURES: %d" % _failures)
    quit(_failures)


func _build_floor_state(floor_id: int, seed: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        seed,
        &"generator:inventory_drop_menu_v01",
        &"modules:prototype_v01",
        &"encounters:prototype_v01",
        &"questflags:inventory_drop_menu_v01"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return null
    return TowerFloorGenerationCommitService.floor_state_from_manifest(StringName("floor_instance:inventory_drop_menu_%d_%d" % [floor_id, seed]), manifest)


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
    var pickups: Array[Node] = container.get_children()
    if pickups.size() != 1 or not pickups[0] is Area2D:
        return null
    return pickups[0] as Area2D


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
