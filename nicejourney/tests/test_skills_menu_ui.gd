extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const SKILLS_MENU_SCRIPT: Script = preload("res://src/ui/skills_menu.gd")

var _failures := 0
var _action_profile: ProfileSnapshot = null
var _action_save_service: SaveService = null
var _transaction_counter: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Skills UI", "mage")
    profile.skill_points = 3
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame

    var menu: Node = gameplay.get_node("SkillsMenu")
    var overlay := gameplay.get_node("SkillsMenu/Overlay") as Control
    var panel := gameplay.get_node("SkillsMenu/Overlay/Panel") as Control
    var summary := gameplay.get_node("SkillsMenu/Overlay/Panel/Layout/Summary") as Label
    var status := gameplay.get_node("SkillsMenu/Overlay/Panel/Layout/Status") as Label
    var skill_list := gameplay.get_node("SkillsMenu/Overlay/Panel/Layout/Body/SkillList") as ItemList
    var detail := gameplay.get_node("SkillsMenu/Overlay/Panel/Layout/Body/DetailScroll/Detail") as Label
    var purchase_button := gameplay.get_node("SkillsMenu/Overlay/Panel/Layout/Actions/PurchaseRank") as Button
    var equip_slot_1_button := gameplay.get_node("SkillsMenu/Overlay/Panel/Layout/Actions/EquipSlot1") as Button
    var confirmation_row := gameplay.get_node("SkillsMenu/Overlay/Panel/Layout/RankConfirmation") as HBoxContainer
    var confirmation_label := gameplay.get_node("SkillsMenu/Overlay/Panel/Layout/RankConfirmation/Consequence") as Label
    var confirm_button := gameplay.get_node("SkillsMenu/Overlay/Panel/Layout/RankConfirmation/Confirm") as Button
    var cancel_button := gameplay.get_node("SkillsMenu/Overlay/Panel/Layout/RankConfirmation/Cancel") as Button
    var ownership := gameplay.input_ownership
    var coordinator := gameplay.pause_coordinator

    _expect(bool(menu.call("open_menu")), "K Skills modal opens from initialized persistent skill state")
    _expect(overlay.visible and ownership.current_modal() == SKILLS_MENU_SCRIPT.MODAL_ID, "Skills menu exclusively owns modal input while open")
    _expect(skill_list.item_count == 6, "Skills menu shows exactly six approved Mage skills")
    _expect(skill_list.has_focus(), "Skills menu establishes keyboard focus on the skill list")
    _expect(summary.text.contains("mage") and summary.text.contains("Skill Points: 3") and summary.text.contains("arcane_lance") and summary.text.contains("mana_weave"), "Skills summary exposes exact class, points and active/passive loadout IDs")
    _expect(status.text.contains("Read-only") and status.text.contains("safe town/rest"), "Skills menu states why irreversible spending and loadout swaps are unavailable")
    var all_icons_present := true
    for index: int in range(skill_list.item_count):
        if skill_list.get_item_icon(index) == null:
            all_icons_present = false
            break
    _expect(all_icons_present, "Skills menu resolves all six class skills through the existing UI icon catalog")
    var arcane_lance_index := -1
    for index: int in range(skill_list.item_count):
        if StringName(String(skill_list.get_item_metadata(index))) == &"arcane_lance":
            arcane_lance_index = index
            break
    _expect(arcane_lance_index >= 0, "Skills UI can select Arcane Lance by stable ID")
    if arcane_lance_index >= 0:
        skill_list.select(arcane_lance_index)
        menu.call("_on_item_selected", arcane_lance_index)
        _expect(detail.text.contains("Arcane Lance") and detail.text.contains("Rank: 1/3"), "Skills detail opens on a real authored learned skill entry")
        _expect(detail.text.contains("Mechanic: focused_arcane_projectile") and detail.text.contains("Action resource: mana"), "Skills detail exposes authored mechanic and resource identity without inventing amount")
        _expect(detail.text.contains("Rank cost: 1 skill point") and detail.text.contains("purchase action: unavailable"), "Skills detail previews permanent one-point rank cost without exposing unsaved mutation")
    _expect(not gameplay.map_menu.open_menu(), "another modal cannot stack over the open Skills menu")

    var riposte_index := -1
    for index: int in range(skill_list.item_count):
        if StringName(String(skill_list.get_item_metadata(index))) == &"aegis_ward":
            riposte_index = index
            break
    _expect(riposte_index >= 0, "Skills UI can select the Mage alternative active by stable ID")
    if riposte_index >= 0:
        skill_list.select(riposte_index)
        menu.call("_on_item_selected", riposte_index)
        _expect(detail.text.contains("Aegis Ward") and detail.text.contains("Learned: No"), "Skills UI honestly shows the unlearned alternative active")
        _expect(detail.text.contains("Loadout swap: unavailable until safe town/rest interaction ownership is wired"), "Skills UI preserves the locked safe-location swap rule")

    _action_profile = profile
    _action_save_service = SaveService.new("user://tests/skills_menu_actions")
    _action_save_service.delete_slot(1)
    _expect(_action_save_service.save_profile(1, profile) == OK, "Skills action fixture starts from a committed profile")
    _expect(bool(menu.call(
        "configure_progression_actions",
        Callable(self, &"_rank_purchase_request"),
        Callable(self, &"_loadout_swap_request"),
        Callable(self, &"_interaction_state"),
        Callable(self, &"_transaction_id")
    )), "Skills menu accepts explicit durable commit, interaction-state and transaction-identity owners")
    _expect(status.text.contains("Durable skill actions are connected"), "Skills menu surfaces that caller-owned durable actions are available")
    if riposte_index >= 0:
        skill_list.select(riposte_index)
        menu.call("_on_item_selected", riposte_index)
        _expect(not purchase_button.disabled and equip_slot_1_button.disabled, "unlearned alternative enables durable rank purchase but cannot be equipped yet")
        purchase_button.emit_signal("pressed")
        _expect(_load_skill_rank(profile, &"aegis_ward") == 0 and confirmation_row.visible, "irreversible rank purchase requires a distinct confirmation step before mutation")
        _expect(confirmation_label.text.contains("permanent") and confirmation_label.text.contains("no respec/refund"), "rank confirmation shows the irreversible consequence")
        cancel_button.emit_signal("pressed")
        _expect(_load_skill_rank(profile, &"aegis_ward") == 0 and not confirmation_row.visible, "canceling rank confirmation is non-mutating")
        purchase_button.emit_signal("pressed")
        confirm_button.emit_signal("pressed")
        _expect(_load_skill_rank(profile, &"aegis_ward") == 1 and profile.skill_points == 2, "Purchase Rank button commits the irreversible rank through the supplied durable hook")
        _expect(not equip_slot_1_button.disabled, "learned alternative becomes eligible for a safe loadout slot after the durable purchase refresh")
        equip_slot_1_button.emit_signal("pressed")
        _expect(_active_slot(profile, 0) == &"aegis_ward", "Equip Slot 1 button commits the learned active through the supplied safe-interaction hook")
        var saved_after_actions := _action_save_service.load_profile(1)
        _expect(saved_after_actions != null and _load_skill_rank(saved_after_actions, &"aegis_ward") == 1 and _active_slot(saved_after_actions, 0) == &"aegis_ward", "Skills menu rank purchase and loadout swap are both present in the durable save generation")

    var settings: Node = root.get_node_or_null("AccessibilitySettings")
    if settings != null:
        settings.call("set_ui_scale", 1.25)
        settings.call("set_text_scale", 1.25)
        await process_frame
        _expect(overlay.theme != null and is_equal_approx(overlay.theme.default_base_scale, 1.25) and overlay.theme.default_font_size == 20, "Skills menu consumes the global UI/text accessibility scale")
        var panel_rect := panel.get_global_rect()
        _expect(panel_rect.position.x >= 0.0 and panel_rect.position.y >= 0.0 and panel_rect.end.x <= 640.0 and panel_rect.end.y <= 360.0, "largest supported UI/text scale keeps the Skills panel inside the minimum 640x360 canvas")
        settings.call("set_ui_scale", 1.0)
        settings.call("set_text_scale", 1.0)

    menu.call("_unhandled_input", _skills_event(true))
    _expect(not bool(menu.call("is_open")) and not ownership.is_modal_open(), "pressing K again closes only the Skills modal")
    _expect(not ownership.can_route_gameplay_action(&"skills"), "Skills close suppresses the triggering K action until release")
    ownership._input(_skills_event(false))
    _expect(ownership.can_route_gameplay_action(&"skills"), "Skills K suppression clears on release")

    _expect(bool(menu.call("open_menu")), "Skills menu can reopen after K release")
    coordinator._input(_pause_event(true))
    _expect(not paused, "Escape backs out of Skills without stacking Pause")
    _expect(not bool(menu.call("is_open")) and not ownership.is_modal_open(), "GameplayRoot closes Skills through shared PauseCoordinator modal-back routing")
    _expect(not ownership.can_route_gameplay_action(&"pause"), "Skills modal-back suppresses the triggering Escape until release")
    coordinator._input(_pause_event(false))
    _expect(ownership.can_route_gameplay_action(&"pause"), "Skills Escape suppression clears on release")

    var detached: Dictionary = menu.call("current_snapshot") as Dictionary
    ((detached.get("entries", []) as Array)[0] as Dictionary)["skill_id"] = &"skill:ui_mutated"
    var fresh: Dictionary = menu.call("current_snapshot") as Dictionary
    _expect(StringName(((fresh.get("entries", []) as Array)[0] as Dictionary).get("skill_id", &"")) != &"skill:ui_mutated", "Skills UI returns detached read-only snapshots")

    gameplay.queue_free()
    await process_frame
    if _action_save_service != null:
        _action_save_service.delete_slot(1)
    if _failures == 0:
        print("SKILLS MENU UI TEST PASS")
    else:
        push_error("SKILLS MENU UI TEST FAILURES: %d" % _failures)
    quit(_failures)


func _skills_event(pressed: bool) -> InputEventAction:
    var event := InputEventAction.new()
    event.action = &"skills"
    event.pressed = pressed
    return event


func _pause_event(pressed: bool) -> InputEventAction:
    var event := InputEventAction.new()
    event.action = &"pause"
    event.pressed = pressed
    return event


func _rank_purchase_request(skill_id: StringName, transaction_id: StringName) -> Dictionary:
    return SkillProgressionService.commit_rank_purchase(_action_save_service, 1, _action_profile, skill_id, transaction_id)


func _loadout_swap_request(
    kind: StringName,
    slot_index: int,
    skill_id: StringName,
    transaction_id: StringName,
    safe_interaction: bool,
    active_combat: bool
) -> Dictionary:
    if kind == SkillDefinition.KIND_ACTIVE:
        return SkillProgressionService.commit_active_swap(
            _action_save_service,
            1,
            _action_profile,
            slot_index,
            skill_id,
            transaction_id,
            safe_interaction,
            active_combat
        )
    if kind == SkillDefinition.KIND_PASSIVE:
        return SkillProgressionService.commit_passive_swap(
            _action_save_service,
            1,
            _action_profile,
            slot_index,
            skill_id,
            transaction_id,
            safe_interaction,
            active_combat
        )
    return {"accepted": false, "reason_id": &"invalid_kind", "durable": false}


func _interaction_state() -> Dictionary:
    return {
        "safe_interaction": true,
        "active_combat": false,
    }


func _transaction_id(operation_id: StringName, skill_id: StringName, slot_index: int) -> StringName:
    _transaction_counter += 1
    return StringName("skill_ui:%s:%s:%d:%d" % [String(operation_id), String(skill_id), slot_index, _transaction_counter])


func _load_skill_rank(profile: ProfileSnapshot, skill_id: StringName) -> int:
    if profile == null:
        return -1
    var state := SkillLoadoutState.new()
    if not state.load_dictionary(profile.skill_state).is_empty():
        return -1
    return state.get_rank(skill_id)


func _active_slot(profile: ProfileSnapshot, slot_index: int) -> StringName:
    if profile == null:
        return &""
    var state := SkillLoadoutState.new()
    if not state.load_dictionary(profile.skill_state).is_empty() or slot_index < 0 or slot_index >= state.active_slots.size():
        return &""
    return state.active_slots[slot_index]


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
