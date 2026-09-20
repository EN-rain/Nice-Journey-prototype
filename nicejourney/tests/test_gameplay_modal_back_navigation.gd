extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Modal Back", "melee")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame

    var coordinator := gameplay.pause_coordinator
    var ownership := gameplay.input_ownership

    _expect(gameplay.map_menu.open_menu(), "GameplayRoot Map menu opens for modal-back integration")
    _expect(ownership.current_modal() == MapMenu.MODAL_ID, "Map owns modal input before Escape")
    coordinator._input(_pause_event(true))
    _expect(not paused, "Escape backs out of Map without stacking Pause")
    _expect(not gameplay.map_menu.is_open() and not ownership.is_modal_open(), "GameplayRoot closes Map through PauseCoordinator modal-back routing")
    _expect(not ownership.can_route_gameplay_action(&"pause"), "Map modal-back suppresses the triggering Escape until release")
    coordinator._input(_pause_event(false))
    _expect(ownership.can_route_gameplay_action(&"pause"), "Map modal-back Escape suppression clears on release")

    _expect(gameplay.tower_access_menu.open_menu(), "GameplayRoot Tower Access menu opens for modal-back integration")
    _expect(ownership.current_modal() == TowerAccessMenu.MODAL_ID, "Tower Access owns modal input before Escape")
    coordinator._input(_pause_event(true))
    _expect(not paused, "Escape backs out of Tower Access without stacking Pause")
    _expect(not gameplay.tower_access_menu.is_open() and not ownership.is_modal_open(), "GameplayRoot closes Tower Access through PauseCoordinator modal-back routing")
    _expect(not ownership.can_route_gameplay_action(&"pause"), "Tower Access modal-back suppresses the triggering Escape until release")
    coordinator._input(_pause_event(false))
    _expect(ownership.can_route_gameplay_action(&"pause"), "Tower Access modal-back Escape suppression clears on release")

    _expect(
        gameplay.storage_house_menu.open_service(StorageHouseMenu.STORAGE_STRUCTURE_ID, StorageHouseMenu.STORAGE_ROLE_ID),
        "GameplayRoot Storage House menu opens for modal-back integration"
    )
    _expect(ownership.current_modal() == StorageHouseMenu.MODAL_ID, "Storage House owns modal input before Escape")
    coordinator._input(_pause_event(true))
    _expect(not paused, "Escape backs out of Storage House without stacking Pause")
    _expect(
        not gameplay.storage_house_menu.is_open() and not ownership.is_modal_open(),
        "GameplayRoot closes Storage House through PauseCoordinator modal-back routing"
    )
    _expect(not ownership.can_route_gameplay_action(&"pause"), "Storage House modal-back suppresses the triggering Escape until release")
    coordinator._input(_pause_event(false))
    _expect(ownership.can_route_gameplay_action(&"pause"), "Storage House modal-back Escape suppression clears on release")

    coordinator._input(_pause_event(true))
    _expect(paused and ownership.current_modal() == &"pause_menu", "Escape with no other modal retains ordinary Pause behavior")
    coordinator.resume()
    _expect(not paused, "modal-back integration test restores unpaused state")

    gameplay.queue_free()
    await process_frame
    if _failures == 0:
        print("GAMEPLAY MODAL BACK NAVIGATION TEST PASS")
    else:
        push_error("GAMEPLAY MODAL BACK NAVIGATION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _pause_event(pressed: bool) -> InputEventAction:
    var event := InputEventAction.new()
    event.action = &"pause"
    event.pressed = pressed
    return event


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
