extends SceneTree

const MENU: PackedScene = preload("res://src/ui/quest_log_menu.tscn")
var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Pending selector", "melee")
    var economy := EconomyState.new()
    _expect(economy.add_pending_reward(&"claim:pending_first", &"source:pending_first",
        [{"item_instance_id": "item:pending_first", "definition_id": "itemdef:pending_first", "quantity": 1, "stackable": true}]), "first pending claim fixture is valid")
    _expect(economy.add_pending_reward(&"claim:pending_second", &"source:pending_second",
        [{"item_instance_id": "item:pending_second", "definition_id": "itemdef:pending_second", "quantity": 1, "stackable": true}]), "second pending claim fixture is valid")
    profile.economy_state = economy.to_dictionary()
    var ownership := InputOwnership.new()
    root.add_child(ownership)
    var menu := MENU.instantiate() as QuestLogMenu
    root.add_child(menu)
    await process_frame
    _expect(menu.configure(profile, ownership), "pending reward selector configures")
    _expect(menu.open_menu(), "pending reward selector opens with two claims")
    var selector := menu.pending_selector
    _expect(selector.item_count == 2, "both persisted claims are displayed")
    selector.select(1)
    var chosen := StringName(String(selector.get_item_metadata(selector.selected)))
    _expect(menu.set_profile(profile), "profile refresh succeeds while the second claim is selected")
    _expect(selector.item_count == 2 and StringName(String(selector.get_item_metadata(selector.selected))) == chosen,
        "refresh preserves the selected pending claim instead of resetting to first")
    var only_first := EconomyState.new()
    _expect(only_first.add_pending_reward(&"claim:pending_first", &"source:pending_first",
        [{"item_instance_id": "item:pending_first", "definition_id": "itemdef:pending_first", "quantity": 1, "stackable": true}]), "remaining pending claim fixture is valid")
    profile.economy_state = only_first.to_dictionary()
    _expect(menu.set_profile(profile), "refresh after selected claim removal succeeds")
    _expect(selector.item_count == 1 and selector.selected == 0
        and StringName(String(selector.get_item_metadata(0))) == &"claim:pending_first",
        "removed pending claim falls back to remaining valid selection")
    menu.close_menu()
    menu.queue_free()
    ownership.queue_free()
    await process_frame
    if _failures == 0:
        print("QUEST LOG PENDING SELECTION UI TEST PASS")
    else:
        push_error("QUEST LOG PENDING SELECTION UI TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
