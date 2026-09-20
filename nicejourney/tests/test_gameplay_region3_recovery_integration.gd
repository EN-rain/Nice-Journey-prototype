extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TEST_SAVE_ROOT: String = "user://tests/gameplay_region3_recovery_integration"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service := SaveService.new(TEST_SAVE_ROOT)
    save_service.delete_slot(1)

    var profile := ProfileCreationService.create_profile(1, "Recovery Integration", "melee")
    _expect(profile != null, "recovery integration fixture creates a profile")
    if profile == null:
        quit(1)
        return

    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "recovery integration fixture loads inventory")
    _expect(inventory.add_gold(30), "recovery integration fixture owns explicit Gold")
    profile.item_state = inventory.to_dictionary()
    _expect(save_service.save_profile(1, profile) == OK, "recovery integration fixture persists pre-gameplay profile")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.region3_playtest_content = null # Missing-content negative fixture, not the shipped playtest scene.
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save_service, 1), "recovery integration fixture supplies save ownership")
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.ensure_starting_world(), "recovery integration fixture enters authored Region 3")

    var unavailable := gameplay.get_region3_recovery_integration_status(Region3RecoveryServiceDefinition.ROLE_INN_REST_HOUSE)
    _expect(
        not bool(unavailable.get("available", true))
        and StringName(String(unavailable.get("reason_id", &""))) == &"recovery_definition_unavailable",
        "Inn fails closed with a precise reason when production recovery content is absent"
    )

    gameplay.region3_inn_recovery_definition = _inn_definition()
    gameplay.region3_recovery_resource_mapping = {
        "resource:region3_inn_health": GameplayRoot.RECOVERY_TARGET_HEALTH,
        "resource:region3_inn_stamina": GameplayRoot.RECOVERY_TARGET_STAMINA,
    }
    var ready := gameplay.get_region3_recovery_integration_status(Region3RecoveryServiceDefinition.ROLE_INN_REST_HOUSE)
    _expect(bool(ready.get("available", false)), "fully explicit Inn definition plus runtime resource mapping becomes integration-ready")

    var max_hp := gameplay.player.health.get_max_hp()
    var max_stamina := gameplay.player.stamina.get_max_stamina()
    var starting_hp := maxi(1, max_hp - 40)
    var starting_stamina := maxf(0.0, max_stamina - 30.0)
    _expect(gameplay.player.health.set_current_hp(starting_hp), "recovery fixture lowers live HP")
    _expect(gameplay.player.stamina.apply_combat_value(starting_stamina, false), "recovery fixture lowers live stamina")

    var inn := gameplay.region3_town_session_host.active_runtime_root.get_node("InnRestHouse/ServiceInteraction") as Region3FunctionalServiceInteraction
    _expect(inn != null, "authored Inn owns a physical service interaction")
    if inn != null:
        inn.call("_on_body_entered", gameplay.player)
        var admission := inn.request_service(&"interaction:test_inn_recovery")
        _expect(bool(admission.get("admitted", false)), "physical Inn request passes shared interaction admission")

    var result := gameplay.last_region3_recovery_result
    _expect(bool(result.get("accepted", false)) and bool(result.get("durable", false)), "live Inn request atomically commits recovery and durable profile state")
    _expect(gameplay.player.health.current_hp == mini(max_hp, starting_hp + 25), "live Inn recovery applies the exact authored HP amount")
    _expect(is_equal_approx(gameplay.player.stamina.current_stamina, minf(max_stamina, starting_stamina + 10.0)), "live Inn recovery applies the exact authored stamina amount")

    var live_inventory := InventoryState.new()
    _expect(live_inventory.load_dictionary(profile.item_state).is_empty() and live_inventory.gold == 18, "successful Inn recovery deducts the exact authored Gold price once")
    var transaction_id := StringName(String(result.get("transaction_id", &"")))
    _expect(transaction_id != &"" and profile.claimed_transactions.has(String(transaction_id)), "successful Inn recovery records its duplicate-resistant transaction identity")
    _expect(
        StringName(String(profile.safe_state.get("map_id", &""))) == GameplayRoot.REGION3_MAP_ID
        and int(profile.safe_state.get("floor_id", -1)) == 0,
        "recovery commit advances the live safe snapshot in Region 3"
    )

    var durable := save_service.load_profile(1)
    _expect(durable != null, "recovery commit reloads from SaveService")
    if durable != null:
        var durable_inventory := InventoryState.new()
        _expect(durable_inventory.load_dictionary(durable.item_state).is_empty() and durable_inventory.gold == 18, "durable recovery save contains the charged Gold state")
        _expect(durable.claimed_transactions.has(String(transaction_id)), "durable recovery save contains the recovery transaction claim")
        var durable_player := durable.safe_state.get("player_state", {}) as Dictionary
        _expect(int(durable_player.get("hp", -1)) == gameplay.player.health.current_hp, "durable recovery safe state stores recovered HP")
        _expect(is_equal_approx(float(durable_player.get("stamina", -1.0)), gameplay.player.stamina.current_stamina), "durable recovery safe state stores recovered stamina")

    var before_blocked := profile.to_dictionary()
    var before_blocked_hp := gameplay.player.health.current_hp
    _expect(gameplay.shared_active_combat.acquire(&"test:region3_recovery_block", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER), "fixture enters shared Active Combat")
    var blocked := gameplay.request_region3_recovery_service(Region3RecoveryServiceDefinition.ROLE_INN_REST_HOUSE)
    _expect(
        not bool(blocked.get("accepted", true))
        and StringName(String(blocked.get("reason_id", &""))) == GameplayOperationGuard.REASON_ACTIVE_COMBAT,
        "live recovery request is rejected by the shared Active Combat service guard"
    )
    _expect(profile.to_dictionary() == before_blocked and gameplay.player.health.current_hp == before_blocked_hp, "combat-blocked recovery is non-mutating")
    gameplay.shared_active_combat.release_source(&"test:region3_recovery_block")
    await process_frame

    gameplay.region3_clinic_recovery_definition = _stock_only_clinic_definition()
    var clinic_status := gameplay.get_region3_recovery_integration_status(Region3RecoveryServiceDefinition.ROLE_CLINIC_APOTHECARY)
    _expect(
        not bool(clinic_status.get("available", true))
        and StringName(String(clinic_status.get("reason_id", &""))) == Region3RecoveryTransactionService.REASON_RECOVERY_PAYLOAD_UNAVAILABLE,
        "stock-only Clinic remains outside direct recovery ownership instead of fabricating healing"
    )

    var clinic_vendor := VendorStockDefinition.new()
    clinic_vendor.vendor_id = &"vendor:clinic_apothecary"
    clinic_vendor.restock_rule_id = &"restock:test_clinic_none"
    clinic_vendor.restock_policy = VendorStockDefinition.RESTOCK_POLICY_FIXED_NO_RESTOCK
    clinic_vendor.availability_conditions_declared = true
    clinic_vendor.stock = {
        "itemdef:test_clinic_tonic": {
            "buy_price": 4,
            "sell_price": 2,
            "quantity": 3,
            "stackable": true,
        },
    }
    var clinic_catalog := VendorStockCatalog.new()
    clinic_catalog.definitions = [clinic_vendor]
    var clinic_categories := ItemCategoryCatalog.new()
    clinic_categories.definition_categories = {"itemdef:test_clinic_tonic": ItemCategoryCatalog.CATEGORY_CONSUMABLE}
    gameplay.vendor_stock_catalog = clinic_catalog
    gameplay.item_category_catalog = clinic_categories

    var clinic := gameplay.region3_town_session_host.active_runtime_root.get_node("ClinicApothecary/ServiceInteraction") as Region3FunctionalServiceInteraction
    _expect(clinic != null, "authored Clinic owns a physical service interaction")
    if clinic != null:
        clinic.call("_on_body_entered", gameplay.player)
        var clinic_admission := clinic.request_service(&"interaction:test_clinic_stock")
        _expect(bool(clinic_admission.get("admitted", false)), "stock-only Clinic passes the shared physical service admission")
    _expect(
        bool(gameplay.last_region3_service_request.get("service_opened", false))
        and gameplay.merchant_menu.is_open()
        and gameplay.merchant_menu.active_vendor_id() == &"vendor:clinic_apothecary",
        "stock-only Clinic reuses the persisted vendor surface instead of fabricating direct healing"
    )
    var clinic_buy := gameplay.request_region3_merchant_buy(&"itemdef:test_clinic_tonic", 1)
    _expect(bool(clinic_buy.get("accepted", false)), "Clinic stock purchase commits through the shared profile economy transaction owner")
    var clinic_inventory := InventoryState.new()
    _expect(clinic_inventory.load_dictionary(profile.item_state).is_empty() and clinic_inventory.gold == 14, "Clinic purchase charges the exact authored fixture price after Inn recovery")
    var clinic_economy := EconomyState.new()
    _expect(clinic_economy.load_dictionary(profile.economy_state).is_empty(), "Clinic stock transaction preserves persisted economy validity")
    var clinic_vendor_state := clinic_economy.get_vendor(&"vendor:clinic_apothecary")
    _expect(clinic_vendor_state != null and int(clinic_vendor_state.get_entry(&"itemdef:test_clinic_tonic").get("quantity", -1)) == 2, "Clinic purchase decrements persisted authored stock exactly once")
    gameplay.merchant_menu.close_menu()
    if clinic != null:
        clinic.call("_on_body_exited", gameplay.player)

    gameplay.queue_free()
    await process_frame
    save_service.delete_slot(1)
    if _failures == 0:
        print("GAMEPLAY REGION 3 RECOVERY INTEGRATION TEST PASS")
    else:
        push_error("GAMEPLAY REGION 3 RECOVERY INTEGRATION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _inn_definition() -> Dictionary:
    return {
        "service_id": &"service:region3_inn_rest",
        "structure_id": &"r3:functional:05",
        "role_id": Region3RecoveryServiceDefinition.ROLE_INN_REST_HOUSE,
        "available": true,
        "combat_restricted": true,
        "price_gold": 12,
        "recovery_amounts": {
            "resource:region3_inn_health": 25,
            "resource:region3_inn_stamina": 10.0,
        },
        "stock_reference_id": null,
        "save_event_id": &"save_event:region3_inn_rest",
    }


func _stock_only_clinic_definition() -> Dictionary:
    return {
        "service_id": &"service:region3_clinic",
        "structure_id": &"r3:functional:08",
        "role_id": Region3RecoveryServiceDefinition.ROLE_CLINIC_APOTHECARY,
        "available": true,
        "combat_restricted": true,
        "price_gold": null,
        "recovery_amounts": null,
        "stock_reference_id": &"vendor:clinic_apothecary",
        "save_event_id": null,
    }


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
