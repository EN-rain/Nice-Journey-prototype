extends SceneTree

const MENU_SCENE: PackedScene = preload("res://src/ui/tower_access_menu.tscn")

var _failures := 0
var _selected_floor: int = 0
var _selected_confirmed: bool = false

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Tower UI", "mage")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    profile.permanent_flags["tower_floor_4_unlocked"] = true
    var ownership := InputOwnership.new()
    get_root().add_child(ownership)
    var guard := GameplayOperationGuard.new()
    get_root().add_child(guard)
    var menu := MENU_SCENE.instantiate() as TowerAccessMenu
    get_root().add_child(menu)
    await process_frame
    _expect(menu.configure(profile, ownership, guard), "tower access menu configures from profile/input/guard owners")
    menu.floor_selected.connect(_on_floor_selected)
    _expect(menu.open_menu(), "owned Tower Sigil opens the tower access menu")
    _expect(menu.is_open() and ownership.current_modal() == TowerAccessMenu.MODAL_ID, "tower menu owns modal input while open")
    _expect(menu.floor_list.get_child_count() == 2, "tower menu lists only cleared/currently unlocked floors")
    var floor_template := menu.floor_button_scene.instantiate() as Button
    _expect(floor_template != null and floor_template.alignment == HORIZONTAL_ALIGNMENT_LEFT, "tower floor button alignment comes from an Inspector-assigned PackedScene")
    floor_template.free()

    var floor1_button := menu.floor_list.get_node_or_null("Floor1") as Button
    var floor4_button := menu.floor_list.get_node_or_null("Floor4") as Button
    _expect(floor1_button != null and floor1_button.text.contains("DANGER I"), "floor button exposes recommended danger information")
    _expect(floor4_button != null and floor4_button.text.contains("DANGER IV"), "underleveled unlocked floor remains visible with severe danger rank")

    if floor1_button != null:
        floor1_button.pressed.emit()
        _expect(_selected_floor == 1 and not _selected_confirmed, "DANGER I floor emits selection without unnecessary confirmation")
    _selected_floor = 0
    _selected_confirmed = false
    if floor4_button != null:
        floor4_button.pressed.emit()
        _expect(menu.confirmation_panel.visible and _selected_floor == 0, "DANGER III-V floor requires explicit confirmation before selection")
        menu.confirm_button.pressed.emit()
        _expect(_selected_floor == 4 and _selected_confirmed, "confirmed high-danger selection emits exact floor identity")

    menu.close_menu(&"sigil_menu")
    _expect(not menu.is_open() and not ownership.is_modal_open(), "closing tower access menu releases modal ownership")
    _expect(not ownership.can_route_gameplay_action(&"sigil_menu"), "closing action is suppressed until release to prevent click/key-through")
    ownership.notify_action_released(&"sigil_menu")
    _expect(ownership.can_route_gameplay_action(&"sigil_menu"), "sigil-menu suppression clears after action release")

    var blocker := guard.acquire_blocker(&"test:combat", GameplayOperationGuard.REASON_ACTIVE_COMBAT, "Combat active", [GameplayOperationGuard.OP_SIGIL_TRAVEL])
    _expect(blocker > 0 and not menu.open_menu(), "shared operation guard blocks tower menu while active combat owns Sigil travel")
    guard.release_blocker(blocker)

    profile.permanent_flags.erase(Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED)
    _expect(not menu.open_menu(), "Tower Access Menu cannot open without permanent Sigil ownership")

    menu.queue_free()
    guard.queue_free()
    ownership.queue_free()
    await process_frame
    if _failures == 0:
        print("TOWER ACCESS MENU UI TEST PASS")
    else:
        push_error("TOWER ACCESS MENU UI TEST FAILURES: %d" % _failures)
    quit(_failures)

func _on_floor_selected(floor_id: int, confirmed: bool) -> void:
    _selected_floor = floor_id
    _selected_confirmed = confirmed

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
