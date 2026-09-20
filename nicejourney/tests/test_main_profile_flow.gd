extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://src/app/main.tscn")
const TEST_SAVE_ROOT: String = "user://tests/main_profile_flow"

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var service: SaveService = SaveService.new(TEST_SAVE_ROOT)
    _clear_test_slots(service)

    var main: Node = MAIN_SCENE.instantiate()
    main.set("save_root", TEST_SAVE_ROOT)
    root.add_child(main)
    await process_frame

    var front_end: Control = main.get_node("FrontEnd") as Control
    var slot_1: Button = main.get_node("FrontEnd/Panel/Scroller/Layout/Slot1") as Button
    var slot_2: Button = main.get_node("FrontEnd/Panel/Scroller/Layout/Slot2") as Button
    var slot_3: Button = main.get_node("FrontEnd/Panel/Scroller/Layout/Slot3") as Button
    var creation_panel: VBoxContainer = main.get_node("FrontEnd/Panel/Scroller/Layout/CreationPanel") as VBoxContainer
    var name_edit: LineEdit = main.get_node("FrontEnd/Panel/Scroller/Layout/CreationPanel/NameEdit") as LineEdit
    var class_option: OptionButton = main.get_node("FrontEnd/Panel/Scroller/Layout/CreationPanel/ClassOption") as OptionButton
    var create_button: Button = main.get_node("FrontEnd/Panel/Scroller/Layout/CreationPanel/CreateButton") as Button
    var gameplay_host: Node = main.get_node("GameplayHost")

    _expect(slot_1.text.contains("Empty") and slot_2.text.contains("Empty") and slot_3.text.contains("Empty"), "fresh main shell exposes exactly three empty save slots")
    _expect(String(main.call("_class_display_name", "future_class")) == "future_class", "unknown class IDs remain readable raw IDs instead of becoming implicit translation keys")
    _expect(not creation_panel.visible, "profile creation form starts hidden")

    slot_2.pressed.emit()
    _expect(creation_panel.visible, "selecting an empty slot opens profile creation")
    name_edit.text = "Journey Tester"
    class_option.select(2)
    create_button.pressed.emit()
    await process_frame

    var saved: ProfileSnapshot = service.load_profile(2)
    _expect(saved != null, "profile shell writes the selected slot through SaveService")
    if saved != null:
        _expect(saved.protagonist_name == "Journey Tester" and saved.class_id == "mage", "profile shell persists entered name and permanent class identity")
        _expect(StringName(String(saved.safe_state.get("map_id", &""))) == &"region:3" and int(saved.safe_state.get("floor_id", -1)) == 0, "new-profile gameplay startup durably commits Region 3 as the starting world")
        _expect(StringName(String(saved.safe_state.get("checkpoint_anchor_id", &""))) == &"checkpoint:region3_town", "new-profile gameplay startup uses the existing Region 3 town safe anchor")
    _expect(not front_end.visible, "successful profile creation leaves the front end")
    _expect(gameplay_host.get_child_count() == 1 and gameplay_host.get_child(0) is GameplayRoot, "successful profile creation enters the gameplay scene")
    if gameplay_host.get_child_count() == 1 and gameplay_host.get_child(0) is GameplayRoot:
        _expect((gameplay_host.get_child(0) as GameplayRoot).is_region3_active(), "successful profile creation enters the authored Region 3 starting runtime")

    main.queue_free()
    await process_frame

    var reloaded_main: Node = MAIN_SCENE.instantiate()
    reloaded_main.set("save_root", TEST_SAVE_ROOT)
    root.add_child(reloaded_main)
    await process_frame

    var reloaded_slot_2: Button = reloaded_main.get_node("FrontEnd/Panel/Scroller/Layout/Slot2") as Button
    var reloaded_front_end: Control = reloaded_main.get_node("FrontEnd") as Control
    var reloaded_gameplay_host: Node = reloaded_main.get_node("GameplayHost")
    _expect(reloaded_slot_2.text.contains("Journey Tester") and reloaded_slot_2.text.contains("Mage"), "fresh main instance discovers the existing saved slot")
    reloaded_slot_2.pressed.emit()
    await process_frame
    _expect(not reloaded_front_end.visible, "selecting an existing slot bypasses creation and enters gameplay")
    _expect(reloaded_gameplay_host.get_child_count() == 1 and reloaded_gameplay_host.get_child(0) is GameplayRoot, "existing profile loads into the gameplay scene")
    if reloaded_gameplay_host.get_child_count() == 1 and reloaded_gameplay_host.get_child(0) is GameplayRoot:
        _expect((reloaded_gameplay_host.get_child(0) as GameplayRoot).is_region3_active(), "existing Region 3 safe snapshot restores into the authored Region 3 runtime")

    reloaded_main.queue_free()
    await process_frame
    _clear_test_slots(service)

    if _failures == 0:
        print("MAIN PROFILE FLOW TEST PASS")
    else:
        push_error("MAIN PROFILE FLOW TEST FAILURES: %d" % _failures)
    quit(_failures)

func _clear_test_slots(service: SaveService) -> void:
    for slot_index: int in range(1, SaveService.SLOT_COUNT + 1):
        service.delete_slot(slot_index)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
