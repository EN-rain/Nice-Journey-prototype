extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TEST_SAVE_ROOT: String = "user://tests/gameplay_region3_service_integration"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service := SaveService.new(TEST_SAVE_ROOT)
    save_service.delete_slot(1)

    var profile := ProfileCreationService.create_profile(1, "Region Services", "melee")
    _expect(profile != null, "Region 3 service fixture creates a profile")
    if profile == null:
        quit(1)
        return
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "service fixture loads starter inventory")
    _expect(
        bool(inventory.try_add_normal(&"item:region3_storage_test", &"potion_basic", 3, true).get("accepted", false)),
        "service fixture adds one portable full stack"
    )
    profile.item_state = inventory.to_dictionary()
    _expect(save_service.save_profile(1, profile) == OK, "service fixture persists pre-gameplay profile")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.region3_playtest_content = null # This fixture deliberately validates unassigned-service behavior.
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save_service, 1), "service fixture supplies save context")
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.ensure_starting_world(), "service fixture enters authored Region 3")
    _expect(gameplay.is_region3_active(), "Region 3 is active before service interactions")

    var host := gameplay.region3_town_session_host
    var initial_map := Region3MapSnapshotService.build_from_layout(host.active_runtime_root, profile)
    _expect(
        bool(initial_map.get("accepted", false))
        and (initial_map.get("discovered_services", []) as Array).is_empty()
        and (initial_map.get("public_landmarks", []) as Array).size() == 1,
        "fresh Region 3 profile exposes only the public Central Tower before any service interaction"
    )
    var generic_interactions := host.get_functional_service_interactions()
    _expect(
        generic_interactions.size() == Region3FunctionalServiceInteraction.SUPPORTED_ROLE_IDS.size(),
        "Region 3 runtime exposes exactly the six safe generic functional service interactions"
    )
    for interaction: Region3FunctionalServiceInteraction in generic_interactions:
        _expect(
            (interaction.validate_authored_binding() as PackedStringArray).is_empty(),
            "%s generic service interaction validates against its authored anchor" % String(interaction.expected_role_id)
        )

    var storage := host.get_storage_interaction()
    _expect(storage != null, "Storage House runtime exposes its dedicated interaction")
    if storage != null:
        storage.call("_on_body_entered", gameplay.player)
        var open_result := storage.request_service(&"interaction:test_storage_open")
        _expect(bool(open_result.get("admitted", false)), "Storage House service request is admitted at the authored approach")
        _expect(gameplay.storage_house_menu.is_open(), "admitted Storage House request opens the live StorageHouseMenu")
        _expect(
            gameplay.input_ownership.current_modal() == StorageHouseMenu.MODAL_ID,
            "StorageHouseMenu owns modal input while open"
        )
        _expect(
            bool(gameplay.last_region3_storage_service_request.get("service_opened", false)),
            "GameplayRoot records successful Storage House UI opening"
        )
        _expect(
            Region3ServiceDiscoveryService.is_discovered(profile, &"r3:functional:06"),
            "admitted live Storage House service marks the exact service discovered"
        )
        var storage_map := Region3MapSnapshotService.build_from_layout(host.active_runtime_root, profile)
        var storage_discovered := storage_map.get("discovered_services", []) as Array
        _expect(
            storage_discovered.size() == 1
            and StringName((storage_discovered[0] as Dictionary).get("landmark_id", &"")) == &"r3:functional:06"
            and StringName((storage_discovered[0] as Dictionary).get("landmark_kind", &"")) == &"storage_house",
            "Region map reveals the used Storage House with its exact authored service identity"
        )
        _expect(
            not str(storage_map).contains("general_merchant")
            and not str(storage_map).contains("training_hall")
            and not str(storage_map).contains("blacksmith"),
            "Region map continues withholding unused functional services after Storage discovery"
        )
        var disk_before_legitimate_safe := save_service.load_profile(1)
        _expect(
            disk_before_legitimate_safe != null
            and not Region3ServiceDiscoveryService.is_discovered(disk_before_legitimate_safe, &"r3:functional:06"),
            "service discovery remains live/unbanked until a later legitimate safe snapshot"
        )

        var menu := gameplay.storage_house_menu
        _expect(menu.inventory_list.item_count == 1 and menu.storage_list.item_count == 0, "Storage menu reflects live portable/storage ownership")
        menu.inventory_list.select(0)
        menu.call("_on_inventory_selected", 0)
        menu.deposit_button.pressed.emit()
        _expect(bool(gameplay.last_region3_storage_transfer_result.get("accepted", false)), "Storage menu Deposit routes through the live profile transaction owner")
        _expect(StringName(gameplay.last_region3_storage_transfer_result.get("direction", &"")) == &"deposit", "accepted Storage deposit records exact direction")
        var deposited_inventory := InventoryState.new()
        var deposited_storage := StorageState.new()
        _expect(deposited_inventory.load_dictionary(profile.item_state).is_empty(), "accepted Storage deposit leaves valid inventory state")
        _expect(deposited_storage.load_dictionary(profile.storage_state).is_empty(), "accepted Storage deposit leaves valid storage state")
        _expect(deposited_inventory.get_normal_slot(&"item:region3_storage_test").is_empty(), "accepted Storage deposit removes the exact portable instance")
        _expect(int(deposited_storage.get_normal_slot(&"item:region3_storage_test").get("quantity", 0)) == 3, "accepted Storage deposit preserves the full stack in hub storage")
        _expect(menu.inventory_list.item_count == 0 and menu.storage_list.item_count == 1, "Storage menu refreshes immediately after Deposit")

        menu.storage_list.select(0)
        menu.call("_on_storage_selected", 0)
        menu.withdraw_button.pressed.emit()
        _expect(bool(gameplay.last_region3_storage_transfer_result.get("accepted", false)), "Storage menu Withdraw routes through the live profile transaction owner")
        _expect(StringName(gameplay.last_region3_storage_transfer_result.get("direction", &"")) == &"withdraw", "accepted Storage withdraw records exact direction")
        var withdrawn_inventory := InventoryState.new()
        var withdrawn_storage := StorageState.new()
        _expect(withdrawn_inventory.load_dictionary(profile.item_state).is_empty(), "accepted Storage withdraw leaves valid inventory state")
        _expect(withdrawn_storage.load_dictionary(profile.storage_state).is_empty(), "accepted Storage withdraw leaves valid storage state")
        _expect(int(withdrawn_inventory.get_normal_slot(&"item:region3_storage_test").get("quantity", 0)) == 3, "accepted Storage withdraw restores the exact portable full stack")
        _expect(withdrawn_storage.get_normal_slot(&"item:region3_storage_test").is_empty(), "accepted Storage withdraw clears the stored instance")

        var combat_blocker := gameplay.operation_guard.acquire_blocker(
            &"combat:region3_storage_ui_test",
            GameplayOperationGuard.REASON_ACTIVE_COMBAT,
            "Storage blocked during active combat.",
            [GameplayOperationGuard.OP_SERVICE]
        )
        _expect(combat_blocker != 0, "Storage UI fixture acquires the shared service blocker")
        menu.inventory_list.select(0)
        menu.call("_on_inventory_selected", 0)
        menu.deposit_button.pressed.emit()
        _expect(
            not bool(gameplay.last_region3_storage_transfer_result.get("accepted", true))
            and StringName(gameplay.last_region3_storage_transfer_result.get("reason_id", &"")) == GameplayOperationGuard.REASON_ACTIVE_COMBAT,
            "open StorageHouseMenu cannot bypass the shared Active Combat service guard"
        )
        gameplay.operation_guard.release_blocker(combat_blocker)
        menu.close_menu()
        _expect(not gameplay.input_ownership.is_modal_open(), "closing StorageHouseMenu releases modal ownership")
        storage.call("_on_body_exited", gameplay.player)

    var quest_hall := host.active_runtime_root.get_node("QuestHall/ServiceInteraction") as Region3FunctionalServiceInteraction
    _expect(quest_hall != null, "Quest Hall owns the generic service interaction")
    if quest_hall != null:
        quest_hall.call("_on_body_entered", gameplay.player)
        var quest_result := quest_hall.request_service(&"interaction:test_quest_hall_prepare")
        _expect(bool(quest_result.get("admitted", false)), "Quest Hall request passes shared proximity/modal/combat admission")
        _expect(
            bool(gameplay.last_region3_quest_hall_preparation_result.get("accepted", false)),
            "Quest Hall request commits the existing Region 3 preparation transaction"
        )
        var availability_result := gameplay.last_region3_quest_hall_preparation_result.get("availability_result", {}) as Dictionary
        var acceptance_result := gameplay.last_region3_quest_hall_preparation_result.get("acceptance_result", {}) as Dictionary
        _expect(
            bool(availability_result.get("accepted", false))
            and StringName(availability_result.get("after_state", &"")) == QuestProgressState.STATE_AVAILABLE,
            "Quest Hall first exposes Floor 1 through QuestActivationService availability"
        )
        _expect(
            bool(acceptance_result.get("accepted", false))
            and StringName(acceptance_result.get("after_state", &"")) == QuestProgressState.STATE_ACTIVE
            and StringName(acceptance_result.get("stage_id", &"")) == &"region3_preparation",
            "Quest Hall accepts Floor 1 through QuestActivationService before the durable preparation commit"
        )
        _expect(
            Region3PreparationCommitService.has_tower_sigil(profile)
            and Region3PreparationCommitService.is_floor_1_unlocked(profile),
            "Quest Hall preparation grants permanent Tower Sigil and Floor 1 unlock atomically"
        )
        var durable := save_service.load_profile(1)
        _expect(
            durable != null
            and Region3PreparationCommitService.has_tower_sigil(durable)
            and Region3PreparationCommitService.is_floor_1_unlocked(durable),
            "Quest Hall preparation survives immediate durable reload"
        )
        _expect(
            durable != null
            and Region3ServiceDiscoveryService.is_discovered(durable, &"r3:functional:06"),
            "earlier live Storage discovery banks through the later legitimate Quest Hall safe commit"
        )
        quest_hall.call("_on_body_exited", gameplay.player)

    var passive_service_cases: Array[Dictionary] = [
        {"path": NodePath("Blacksmith/ServiceInteraction"), "structure_id": &"r3:functional:03", "role_id": &"blacksmith"},
        {"path": NodePath("GeneralMerchant/ServiceInteraction"), "structure_id": &"r3:functional:04", "role_id": &"general_merchant"},
        {"path": NodePath("InnRestHouse/ServiceInteraction"), "structure_id": &"r3:functional:05", "role_id": &"inn_rest_house"},
        {"path": NodePath("TrainingHall/ServiceInteraction"), "structure_id": &"r3:functional:07", "role_id": &"training_hall"},
        {"path": NodePath("ClinicApothecary/ServiceInteraction"), "structure_id": &"r3:functional:08", "role_id": &"clinic_apothecary"},
    ]
    for case: Dictionary in passive_service_cases:
        var interaction := host.active_runtime_root.get_node(case["path"] as NodePath) as Region3FunctionalServiceInteraction
        _expect(interaction != null, "%s owns an authored service interaction" % String(case["role_id"]))
        if interaction == null:
            continue
        var before := _without_permanent_flags(profile.to_dictionary())
        interaction.call("_on_body_entered", gameplay.player)
        var service_result := interaction.request_service(StringName("interaction:test_%s" % String(case["role_id"])))
        _expect(bool(service_result.get("admitted", false)), "%s service request is admitted through shared guards" % String(case["role_id"]))
        _expect(
            StringName(gameplay.last_region3_service_request.get("structure_id", &"")) == StringName(case["structure_id"])
            and StringName(gameplay.last_region3_service_request.get("role_id", &"")) == StringName(case["role_id"]),
            "%s request exposes exact authored structure/role identity through GameplayRoot" % String(case["role_id"])
        )
        _expect(
            Region3ServiceDiscoveryService.is_discovered(profile, StringName(case["structure_id"])),
            "%s admitted request marks only its authored service identity discoverable" % String(case["role_id"])
        )
        _expect(
            _without_permanent_flags(profile.to_dictionary()) == before,
            "%s request adds service discovery without inventing unrelated gameplay mutation" % String(case["role_id"])
        )
        if StringName(case["role_id"]) == Region3TownStructureManifestValidator.ROLE_BLACKSMITH:
            _expect(
                not gameplay.input_ownership.is_modal_open(),
                "Blacksmith remains request-only when GameplayRoot has no caller-authored production recipes"
            )
        if StringName(case["role_id"]) == Region3TownStructureManifestValidator.ROLE_GENERAL_MERCHANT:
            _expect(
                not bool(gameplay.last_region3_service_request.get("service_opened", true))
                and not gameplay.input_ownership.is_modal_open(),
                "General Merchant remains honestly unavailable when persisted vendor stock is absent"
            )
        if StringName(case["role_id"]) == Region3TownStructureManifestValidator.ROLE_TRAINING_HALL and bool(gameplay.skills_menu.call("is_open")):
            gameplay.skills_menu.call("close_menu")
        interaction.call("_on_body_exited", gameplay.player)

    gameplay.queue_free()
    await process_frame
    save_service.delete_slot(1)
    if _failures == 0:
        print("GAMEPLAY REGION 3 SERVICE INTEGRATION TEST PASS")
    else:
        push_error("GAMEPLAY REGION 3 SERVICE INTEGRATION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)


func _without_permanent_flags(data: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    result.erase("permanent_flags")
    return result
