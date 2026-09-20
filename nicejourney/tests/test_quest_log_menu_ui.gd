extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const QUEST_LOG_MENU_SCRIPT: Script = preload("res://src/ui/quest_log_menu.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Quest Log UI", "melee")
    var objective := AnnihilationObjectiveState.new()
    _expect(objective.configure([&"enemy:ui_log_a", &"enemy:ui_log_b"]), "Quest Log UI fixture configures valid primary objective state")
    _expect(bool(objective.record_actor_defeated(&"enemy:ui_log_a").get("accepted", false)), "Quest Log UI fixture records persisted objective progress")
    profile.quest_progress["primary_floor_1"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:quest_log_ui",
        "objective_state": objective.to_dictionary(),
    }
    profile.quest_progress["side_region3_annihilation"] = {
        "state": QuestProgressState.STATE_COMPLETED,
        "stage_id": &"annihilation_objective",
        "attempt_id": &"attempt:quest_log_ui_side",
        "objective_state": {
            "required_actor_ids": ["enemy:side_done"],
            "defeated_actor_ids": ["enemy:side_done"],
        },
    }
    var economy := EconomyState.new()
    _expect(economy.add_pending_reward(
        &"claim:quest_log_ui_waiting",
        &"source:quest_log_ui_closed",
        [{
            "item_instance_id": "item:quest_log_ui_waiting",
            "definition_id": "itemdef:quest_log_ui_waiting",
            "quantity": 2,
            "stackable": true,
        }]
    ), "Quest Log UI fixture owns a persistent pending normal reward after source closure")
    profile.economy_state = economy.to_dictionary()

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame

    var menu: Node = gameplay.get_node("QuestLogMenu")
    var overlay := gameplay.get_node("QuestLogMenu/Overlay") as Control
    var panel := gameplay.get_node("QuestLogMenu/Overlay/Panel") as Control
    var status := gameplay.get_node("QuestLogMenu/Overlay/Panel/Layout/Status") as Label
    var quest_list := gameplay.get_node("QuestLogMenu/Overlay/Panel/Layout/Body/QuestList") as ItemList
    var detail := gameplay.get_node("QuestLogMenu/Overlay/Panel/Layout/Body/DetailScroll/Detail") as Label
    var pending_row := gameplay.get_node("QuestLogMenu/Overlay/Panel/Layout/PendingRow") as HBoxContainer
    var pending_selector := gameplay.get_node("QuestLogMenu/Overlay/Panel/Layout/PendingRow/PendingSelector") as OptionButton
    var claim_button := gameplay.get_node("QuestLogMenu/Overlay/Panel/Layout/PendingRow/ClaimPending") as Button
    var ownership := gameplay.input_ownership
    var coordinator := gameplay.pause_coordinator

    _expect(bool(menu.call("open_menu")), "J Quest Log modal opens from configured persistent quest state")
    _expect(overlay.visible and ownership.current_modal() == QUEST_LOG_MENU_SCRIPT.MODAL_ID, "Quest Log exclusively owns modal input while open")
    _expect(quest_list.item_count == 2, "Quest Log shows exactly persisted quests and not unaccepted catalog definitions")
    _expect(quest_list.has_focus(), "Quest Log establishes keyboard focus on its persisted quest list")
    _expect(detail.text.contains("primary_floor_1") and detail.text.contains("Defeated 1/2"), "Quest Log details show exact current required step and objective progress")
    _expect(detail.text.contains("tower:floor_1") and detail.text.contains("Tower Floor 1"), "Quest Log details expose exact authored map location")
    _expect(detail.text.contains("Acceptance anchor: r3:functional:02"), "Quest Log renders the source-backed Floor 1 Quest Hall acceptance anchor")
    _expect(detail.text.contains("Turn-in anchor: r3:functional:02") and detail.text.contains("Prerequisites: authoring unavailable"), "Quest Log renders the authoritative Quest Hall turn-in while still withholding undeclared prerequisite values")
    _expect(detail.text.contains("Leave rule: authoring unavailable") and detail.text.contains("Failure rule: authoring unavailable") and detail.text.contains("Retry reset: authoring unavailable"), "Quest Log explicitly withholds undeclared leave/failure/retry policy values")
    _expect(detail.text.contains("Rewards: authoring unavailable") and detail.text.contains("Branch effects: authoring unavailable") and detail.text.contains("Completion conditions: authoring unavailable"), "Quest Log explicitly withholds undeclared reward/branch/completion values")
    _expect(status.text.contains("Reward waiting") and status.text.contains("inventory full") and status.text.contains("1 pending"), "Quest Log visibly surfaces persistent reward overflow instead of requiring the original NPC/source")
    _expect(detail.text.contains("claim:quest_log_ui_waiting") and detail.text.contains("source:quest_log_ui_closed"), "Quest Log detail exposes exact pending claim/source identities")
    _expect(detail.text.contains("itemdef:quest_log_ui_waiting") and detail.text.contains("item:quest_log_ui_waiting") and detail.text.contains("qty 2"), "Quest Log detail exposes exact pending item identity and quantity")
    _expect(detail.text.contains("Claim action: outside Active Combat") and detail.text.contains("unbanked"), "Quest Log states the live-but-unbanked pending-reward claim boundary")
    _expect(pending_row.visible and pending_selector.item_count == 1 and not claim_button.disabled, "Quest Log exposes one selectable pending claim outside Active Combat")
    _expect(StringName(String(pending_selector.get_item_metadata(0))) == &"claim:quest_log_ui_waiting", "Quest Log claim selector preserves exact pending claim identity")
    _expect(not gameplay.map_menu.open_menu(), "another modal cannot stack over the open Quest Log")

    quest_list.select(1)
    menu.call("_on_item_selected", 1)
    _expect(detail.text.contains("side_region3_annihilation") and detail.text.contains("Completed outcome: completed"), "Quest Log exposes exact completed outcome for persisted completed quests")

    var settings: Node = root.get_node_or_null("AccessibilitySettings")
    if settings != null:
        settings.call("set_ui_scale", 1.25)
        settings.call("set_text_scale", 1.25)
        await process_frame
        _expect(overlay.theme != null and is_equal_approx(overlay.theme.default_base_scale, 1.25) and overlay.theme.default_font_size == 20, "Quest Log consumes the global UI/text accessibility scale")
        var panel_rect := panel.get_global_rect()
        _expect(panel_rect.position.x >= 0.0 and panel_rect.position.y >= 0.0 and panel_rect.end.x <= 640.0 and panel_rect.end.y <= 360.0, "largest supported UI/text scale keeps the Quest Log panel inside the minimum 640x360 canvas")
        settings.call("set_ui_scale", 1.0)
        settings.call("set_text_scale", 1.0)

    menu.call("_unhandled_input", _quest_log_event(true))
    _expect(not bool(menu.call("is_open")) and not ownership.is_modal_open(), "pressing J again closes only the Quest Log modal")
    _expect(not ownership.can_route_gameplay_action(&"quest_log"), "Quest Log close suppresses the triggering J action until release")
    ownership._input(_quest_log_event(false))
    _expect(ownership.can_route_gameplay_action(&"quest_log"), "Quest Log J suppression clears on release")

    _expect(bool(menu.call("open_menu")), "Quest Log can reopen after J release")
    coordinator._input(_pause_event(true))
    _expect(not paused, "Escape backs out of Quest Log without stacking Pause")
    _expect(not bool(menu.call("is_open")) and not ownership.is_modal_open(), "GameplayRoot closes Quest Log through shared PauseCoordinator modal-back routing")
    _expect(not ownership.can_route_gameplay_action(&"pause"), "Quest Log modal-back suppresses the triggering Escape until release")
    coordinator._input(_pause_event(false))
    _expect(ownership.can_route_gameplay_action(&"pause"), "Quest Log Escape suppression clears on release")

    var detached: Dictionary = menu.call("current_snapshot") as Dictionary
    ((detached.get("entries", []) as Array)[0] as Dictionary)["quest_id"] = &"quest:ui_mutated"
    (((detached.get("pending_reward_claims", []) as Array)[0] as Dictionary).get("normal_rewards", []) as Array)[0]["quantity"] = 99
    var fresh: Dictionary = menu.call("current_snapshot") as Dictionary
    _expect(StringName(((fresh.get("entries", []) as Array)[0] as Dictionary).get("quest_id", &"")) == &"primary_floor_1", "Quest Log UI returns detached read-only quest snapshots")
    _expect(int(((((fresh.get("pending_reward_claims", []) as Array)[0] as Dictionary).get("normal_rewards", []) as Array)[0] as Dictionary).get("quantity", 0)) == 2, "Quest Log UI returns detached read-only pending reward snapshots")

    _expect(bool(menu.call("open_menu")), "Quest Log reopens for live pending-claim action proof")
    _expect(gameplay.shared_active_combat.acquire(&"encounter:quest_log_claim_test", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER), "Quest Log claim fixture enters authoritative Active Combat")
    await process_frame
    _expect(claim_button.disabled and claim_button.text.contains("blocked"), "Quest Log disables pending reward Claim while Active Combat is authoritative")
    _expect(gameplay.shared_active_combat.release_source(&"encounter:quest_log_claim_test") == 1, "Quest Log claim fixture leaves Active Combat")
    await process_frame
    _expect(not claim_button.disabled and claim_button.text == "Claim", "Quest Log re-enables pending reward Claim after Active Combat ends")
    claim_button.pressed.emit()
    await process_frame
    _expect(not pending_row.visible and status.text.contains("Reward claimed") and status.text.contains("unbanked"), "Quest Log claim action consumes waiting entry and explains safe-snapshot durability")
    var claimed_inventory := InventoryState.new()
    var claimed_economy := EconomyState.new()
    _expect(claimed_inventory.load_dictionary(profile.item_state).is_empty() and not claimed_inventory.get_normal_slot(&"item:quest_log_ui_waiting").is_empty(), "Quest Log Claim grants exact pending item into live inventory")
    _expect(claimed_economy.load_dictionary(profile.economy_state).is_empty() and claimed_economy.get_pending_reward(&"claim:quest_log_ui_waiting").is_empty(), "Quest Log Claim removes exact pending source from live economy")
    var claimed_snapshot: Dictionary = menu.call("current_snapshot") as Dictionary
    _expect(int(claimed_snapshot.get("pending_reward_claim_count", -1)) == 0, "Quest Log refreshes its detached snapshot after successful Claim")

    gameplay.queue_free()
    await process_frame
    if _failures == 0:
        print("QUEST LOG MENU UI TEST PASS")
    else:
        push_error("QUEST LOG MENU UI TEST FAILURES: %d" % _failures)
    quit(_failures)


func _quest_log_event(pressed: bool) -> InputEventAction:
    var event := InputEventAction.new()
    event.action = &"quest_log"
    event.pressed = pressed
    return event


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
