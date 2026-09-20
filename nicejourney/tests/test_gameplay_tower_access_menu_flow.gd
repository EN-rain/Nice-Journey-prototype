extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_ROOT := "user://test_gameplay_tower_access_menu_flow"

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var service := SaveService.new(SAVE_ROOT)
    for slot: int in range(1, SaveService.SLOT_COUNT + 1):
        service.delete_slot(slot)
    await _test_normal_menu_travel(service)
    await _test_high_danger_confirmation_flow(service)
    await _test_leave_rule_feedback(service)
    for slot: int in range(1, SaveService.SLOT_COUNT + 1):
        service.delete_slot(slot)
    if _failures == 0:
        print("GAMEPLAY TOWER ACCESS MENU FLOW TEST PASS")
    else:
        push_error("GAMEPLAY TOWER ACCESS MENU FLOW TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_normal_menu_travel(service: SaveService) -> void:
    var profile := _travel_profile(1, "Menu Normal", 1)
    _expect(service.save_profile(1, profile) == OK, "normal menu-travel source persists")
    var gameplay := await _spawn_gameplay(profile, service, 1)
    _expect(gameplay.tower_access_menu.open_menu(), "live GameplayRoot opens configured Tower Access Menu")
    var button := gameplay.tower_access_menu.floor_list.get_node_or_null("Floor1") as Button
    _expect(button != null, "live Tower Access Menu renders Floor 1 button")
    if button != null:
        button.pressed.emit()
    _expect(gameplay.is_tower_floor_active() and gameplay.tower_floor_session_host.active_floor_id == 1, "Floor 1 menu selection completes durable travel and activates live tower floor")
    _expect(not gameplay.tower_access_menu.is_open(), "successful Tower Access Menu travel closes the modal")
    gameplay.queue_free()
    await process_frame

func _test_high_danger_confirmation_flow(service: SaveService) -> void:
    var profile := _travel_profile(2, "Menu Danger", 4)
    profile.level = 1
    _expect(service.save_profile(2, profile) == OK, "danger menu-travel source persists")
    var gameplay := await _spawn_gameplay(profile, service, 2)
    _expect(gameplay.tower_access_menu.open_menu(), "danger menu opens")
    var button := gameplay.tower_access_menu.floor_list.get_node_or_null("Floor4") as Button
    _expect(button != null, "danger menu renders unlocked Floor 4")
    if button != null:
        button.pressed.emit()
    _expect(gameplay.tower_access_menu.confirmation_panel.visible and not gameplay.is_tower_floor_active(), "high-danger menu selection waits for confirmation without committing")
    gameplay.tower_access_menu.confirm_button.pressed.emit()
    _expect(gameplay.is_tower_floor_active() and gameplay.tower_floor_session_host.active_floor_id == 4, "confirmed high-danger menu selection commits and activates Floor 4")
    _expect(not gameplay.tower_access_menu.is_open(), "confirmed high-danger travel closes the modal")
    gameplay.queue_free()
    await process_frame

func _test_leave_rule_feedback(service: SaveService) -> void:
    var profile := _travel_profile(3, "Menu Leave", 1)
    profile.quest_progress["side_region3_escort"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"escort_objective",
        "attempt_id": &"attempt:menu_leave_guard",
        "objective_state": {"actor_id": "npc:escort_menu", "route_progress": 1},
    }
    _expect(service.save_profile(3, profile) == OK, "leave-rule menu source persists")
    var gameplay := await _spawn_gameplay(profile, service, 3)
    _expect(gameplay.tower_access_menu.open_menu(), "leave-rule menu opens before travel attempt")
    var button := gameplay.tower_access_menu.floor_list.get_node_or_null("Floor1") as Button
    if button != null:
        button.pressed.emit()
    _expect(not gameplay.is_tower_floor_active(), "menu cannot bypass active quest leave policy")
    _expect(gameplay.tower_access_menu.is_open(), "rejected leave-policy travel keeps Tower Access Menu open for recovery")
    _expect(gameplay.tower_access_menu.status_label.text.contains("side_region3_escort"), "rejected leave-policy travel shows the exact quest requiring an authored leave decision")
    gameplay.queue_free()
    await process_frame

func _travel_profile(slot_index: int, name: String, floor_id: int) -> ProfileSnapshot:
    var profile := ProfileCreationService.create_profile(slot_index, name, "ranged")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_%d_unlocked" % floor_id] = true
    return profile

func _spawn_gameplay(profile: ProfileSnapshot, service: SaveService, slot_index: int) -> GameplayRoot:
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(service, slot_index), "live menu flow receives explicit save context")
    get_root().add_child(gameplay)
    await process_frame
    return gameplay

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
