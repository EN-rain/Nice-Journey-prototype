extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TEST_SAVE_ROOT: String = "user://tests/gameplay_training_hall_skills_flow"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service := SaveService.new(TEST_SAVE_ROOT)
    save_service.delete_slot(1)

    var profile := ProfileCreationService.create_profile(1, "Training Skills", "mage")
    _expect(profile != null, "Training Hall skill fixture creates a Mage profile")
    if profile == null:
        quit(1)
        return
    profile.skill_points = 4
    _expect(save_service.save_profile(1, profile) == OK, "Training Hall fixture persists the pre-gameplay profile")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save_service, 1), "Training Hall fixture supplies the current save service and slot")
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.ensure_starting_world(), "Training Hall fixture enters authored Region 3")

    var host := gameplay.region3_town_session_host
    var training := host.active_runtime_root.get_node("TrainingHall/ServiceInteraction") as Region3FunctionalServiceInteraction
    _expect(training != null, "authored Training Hall exposes its guarded service interaction")
    if training == null:
        _finish(gameplay, save_service)
        return

    training.call("_on_body_entered", gameplay.player)
    var service_result := training.request_service(&"interaction:test_training_hall_skills")
    _expect(bool(service_result.get("admitted", false)), "Training Hall service request passes authored proximity/modal/combat admission")
    _expect(bool(gameplay.last_region3_service_request.get("service_opened", false)), "GameplayRoot opens SkillsMenu for the admitted Training Hall service")
    _expect(bool(gameplay.skills_menu.call("is_open")), "Training Hall owns one live SkillsMenu mutation session")
    _expect(gameplay.input_ownership.current_modal() == SkillsMenu.MODAL_ID, "Training Hall SkillsMenu owns modal input while the service session is open")

    var menu := gameplay.skills_menu
    var skill_list := menu.get_node("Overlay/Panel/Layout/Body/SkillList") as ItemList
    var purchase_button := menu.get_node("Overlay/Panel/Layout/Actions/PurchaseRank") as Button
    var equip_slot_1 := menu.get_node("Overlay/Panel/Layout/Actions/EquipSlot1") as Button
    var equip_slot_2 := menu.get_node("Overlay/Panel/Layout/Actions/EquipSlot2") as Button
    var confirmation_row := menu.get_node("Overlay/Panel/Layout/RankConfirmation") as HBoxContainer
    var confirm_button := menu.get_node("Overlay/Panel/Layout/RankConfirmation/Confirm") as Button
    var status_label := menu.get_node("Overlay/Panel/Layout/Status") as Label

    var service_snapshot := menu.call("current_snapshot") as Dictionary
    _expect(bool(service_snapshot.get("rank_purchase_action_available", false)), "Training Hall session enables durable rank-purchase ownership")
    _expect(bool(service_snapshot.get("loadout_swap_action_available", false)), "Training Hall session enables safe non-combat loadout ownership")
    _expect(bool(service_snapshot.get("safe_interaction", false)) and not bool(service_snapshot.get("active_combat", true)), "Training Hall exposes safe-town state and live non-combat state to SkillsMenu")

    _expect(_select_skill(menu, skill_list, &"aegis_ward"), "Training Hall SkillsMenu selects the unlearned Aegis Ward")
    _expect(_rank(profile, &"aegis_ward") == 0 and not purchase_button.disabled, "unlearned Aegis Ward is eligible for one-point durable rank purchase")
    purchase_button.pressed.emit()
    _expect(confirmation_row.visible and _rank(profile, &"aegis_ward") == 0 and profile.skill_points == 4, "Training Hall preserves explicit irreversible rank confirmation before mutation")
    confirm_button.pressed.emit()
    _expect(_rank(profile, &"aegis_ward") == 1 and profile.skill_points == 3, "confirmed Training Hall rank purchase mutates live skill state exactly once")
    var rank_transaction := StringName(gameplay.last_region3_training_skill_result.get("transaction_id", &""))
    _expect(
        bool(gameplay.last_region3_training_skill_result.get("accepted", false))
        and bool(gameplay.last_region3_training_skill_result.get("durable", false))
        and StableId.is_valid(String(rank_transaction)),
        "Training Hall rank purchase uses one durable stable transaction identity"
    )

    _expect(not equip_slot_1.disabled, "newly learned Aegis Ward becomes eligible for Training Hall active-slot swap")
    _expect(
        gameplay.shared_active_combat.acquire(&"test:training_hall_live_combat", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER),
        "Training Hall fixture starts Active Combat after the SkillsMenu was already opened"
    )
    equip_slot_1.pressed.emit()
    _expect(
        not bool(gameplay.last_region3_training_skill_result.get("accepted", true))
        and StringName(gameplay.last_region3_training_skill_result.get("reason_id", &"")) == SkillProgressionService.REASON_ACTIVE_COMBAT
        and _active_slot(profile, 0) == &"arcane_lance",
        "Training Hall active swap re-reads live ActiveCombat and rejects without mutating the loadout"
    )
    _expect(
        gameplay.shared_active_combat.release(&"test:training_hall_live_combat", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER),
        "Training Hall fixture ends the live combat blocker"
    )
    equip_slot_1.pressed.emit()
    _expect(_active_slot(profile, 0) == &"aegis_ward", "Training Hall commits active Slot 1 swap after live combat clears")
    var active_swap_transaction := StringName(gameplay.last_region3_training_skill_result.get("transaction_id", &""))
    _expect(bool(gameplay.last_region3_training_skill_result.get("durable", false)), "Training Hall active swap is durable before live slot ownership changes")

    _expect(_select_skill(menu, skill_list, &"stable_casting"), "Training Hall SkillsMenu selects the unlearned Stable Casting passive")
    purchase_button.pressed.emit()
    _expect(confirmation_row.visible and _rank(profile, &"stable_casting") == 0, "passive rank purchase also requires explicit confirmation")
    confirm_button.pressed.emit()
    _expect(_rank(profile, &"stable_casting") == 1 and profile.skill_points == 2, "confirmed Training Hall passive rank purchase commits durably")
    var passive_rank_transaction := StringName(gameplay.last_region3_training_skill_result.get("transaction_id", &""))
    _expect(not equip_slot_2.disabled, "newly learned Stable Casting becomes eligible for Training Hall passive-slot swap")
    equip_slot_2.pressed.emit()
    _expect(_passive_slot(profile, 1) == &"stable_casting", "Training Hall commits passive Slot 2 swap through the passive durable owner")
    var passive_swap_transaction := StringName(gameplay.last_region3_training_skill_result.get("transaction_id", &""))

    var accepted_transactions: Array[StringName] = [
        rank_transaction,
        active_swap_transaction,
        passive_rank_transaction,
        passive_swap_transaction,
    ]
    var unique_transactions := {}
    var all_claimed := true
    for transaction_id: StringName in accepted_transactions:
        unique_transactions[String(transaction_id)] = true
        if transaction_id == &"" or not profile.claimed_transactions.has(String(transaction_id)):
            all_claimed = false
    _expect(unique_transactions.size() == accepted_transactions.size() and all_claimed, "Training Hall allocates distinct repeat-resistant stable transaction IDs for each accepted skill mutation")

    var durable := save_service.load_profile(1)
    _expect(
        durable != null
        and _rank(durable, &"aegis_ward") == 1
        and _rank(durable, &"stable_casting") == 1
        and _active_slot(durable, 0) == &"aegis_ward"
        and _passive_slot(durable, 1) == &"stable_casting"
        and durable.skill_points == 2,
        "Training Hall rank purchases and active/passive swaps all survive immediate durable reload"
    )

    var state_after_service := profile.to_dictionary()
    menu.call("_unhandled_input", _skills_event(true))
    _expect(not bool(menu.call("is_open")) and not gameplay.input_ownership.is_modal_open(), "K closes the Training Hall SkillsMenu and clears its progression hooks")
    gameplay.input_ownership._input(_skills_event(false))
    await process_frame

    menu.call("_unhandled_input", _skills_event(true))
    _expect(bool(menu.call("is_open")), "ordinary K reopens SkillsMenu outside the Training Hall service request")
    var ordinary_snapshot := menu.call("current_snapshot") as Dictionary
    _expect(
        not bool(ordinary_snapshot.get("rank_purchase_action_available", true))
        and not bool(ordinary_snapshot.get("loadout_swap_action_available", true))
        and not bool(ordinary_snapshot.get("safe_swap_state_available", true)),
        "ordinary K SkillsMenu is read-only after the Training Hall session closes"
    )
    _expect(status_label.text.contains("Read-only"), "ordinary K view explicitly reports read-only skill progression ownership")
    _expect(_select_skill(menu, skill_list, &"aegis_ward"), "ordinary K view can still inspect the learned skill")
    _expect(purchase_button.disabled and equip_slot_1.disabled and equip_slot_2.disabled, "ordinary K cannot purchase ranks or swap either loadout slot")
    _expect(profile.to_dictionary() == state_after_service, "ordinary K inspection performs no skill mutation")

    menu.call("close_menu")
    training.call("_on_body_exited", gameplay.player)
    _finish(gameplay, save_service)


func _select_skill(menu: Node, skill_list: ItemList, skill_id: StringName) -> bool:
    for index: int in range(skill_list.item_count):
        if StringName(String(skill_list.get_item_metadata(index))) != skill_id:
            continue
        skill_list.select(index)
        menu.call("_on_item_selected", index)
        return true
    return false


func _rank(profile: ProfileSnapshot, skill_id: StringName) -> int:
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


func _passive_slot(profile: ProfileSnapshot, slot_index: int) -> StringName:
    if profile == null:
        return &""
    var state := SkillLoadoutState.new()
    if not state.load_dictionary(profile.skill_state).is_empty() or slot_index < 0 or slot_index >= state.passive_slots.size():
        return &""
    return state.passive_slots[slot_index]


func _skills_event(pressed: bool) -> InputEventAction:
    var event := InputEventAction.new()
    event.action = &"skills"
    event.pressed = pressed
    return event


func _finish(gameplay: Node, save_service: SaveService) -> void:
    gameplay.queue_free()
    await process_frame
    save_service.delete_slot(1)
    if _failures == 0:
        print("GAMEPLAY TRAINING HALL SKILLS FLOW TEST PASS")
    else:
        push_error("GAMEPLAY TRAINING HALL SKILLS FLOW TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
