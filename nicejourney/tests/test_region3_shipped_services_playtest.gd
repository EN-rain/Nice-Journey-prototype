extends SceneTree

const SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVES := "user://tests/region3_shipped_services_playtest"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var gameplay := SCENE.instantiate() as GameplayRoot
    _expect(gameplay.region3_playtest_content != null and gameplay.region3_playtest_content.playtest_placeholder, "shipped Gameplay scene owns an explicitly provisional Region 3 services resource")
    var profile := ProfileCreationService.create_profile(1, "Shipped Region Services", "melee")
    var inventory := InventoryState.new()
    inventory.load_dictionary(profile.item_state)
    inventory.add_gold(100)
    profile.item_state = inventory.to_dictionary()
    var save := SaveService.new(SAVES)
    save.delete_slot(1)
    _expect(save.save_profile(1, profile) == OK, "fixture establishes a real prior save")
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save, 1), "fixture supplies a durable service save owner")
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.ensure_starting_world(), "shipped playtest services enter Region 3")
    var bundle := gameplay.region3_playtest_content
    _expect(bundle.validate_content().is_empty(), "shipped playtest merchant/Blacksmith/Inn/Clinic resources validate as one bundle")
    _expect(gameplay.vendor_stock_catalog == bundle.merchant_stock and gameplay.blacksmith_recipe_catalog == bundle.blacksmith_recipes, "shipped scene applies assigned catalog resources")
    _expect(bool(gameplay.vendor_stock_catalog.general_merchant_readiness(gameplay.item_category_catalog, true).get("available", false)), "General Merchant has exact playable stock and prices")
    _expect(bool(gameplay.blacksmith_recipe_catalog.readiness(gameplay.item_category_catalog, true).get("available", false)) and gameplay.blacksmith_recipe_catalog.recipes.size() == 3, "Blacksmith has three explicit provisional starter-weapon recipes")

    var town := gameplay.region3_town_session_host.active_runtime_root
    var merchant := town.get_node("GeneralMerchant/ServiceInteraction") as Region3FunctionalServiceInteraction
    merchant.call("_on_body_entered", gameplay.player)
    merchant.request_service(&"interaction:shipped_general_merchant")
    _expect(gameplay.merchant_menu.is_open(), "shipped merchant opens on physical interaction")
    var buy := gameplay.request_region3_merchant_buy(&"itemdef:region3_playtest_tonic", 1)
    _expect(bool(buy.get("accepted", false)), "shipped General Merchant actually sells its provisional tonic")
    gameplay.merchant_menu.close_menu()
    merchant.call("_on_body_exited", gameplay.player)

    var inn_status := gameplay.get_region3_recovery_integration_status(Region3RecoveryServiceDefinition.ROLE_INN_REST_HOUSE)
    _expect(bool(inn_status.get("available", false)), "shipped Inn has explicit recovery cost and runtime mapping")

    var clinic := town.get_node("ClinicApothecary/ServiceInteraction") as Region3FunctionalServiceInteraction
    clinic.call("_on_body_entered", gameplay.player)
    clinic.request_service(&"interaction:shipped_clinic")
    _expect(gameplay.merchant_menu.is_open() and gameplay.merchant_menu.active_vendor_id() == &"vendor:clinic_apothecary", "Clinic exposes its own persisted stock in the combined service")
    _expect(gameplay.merchant_menu.clinic_recovery_button.visible, "Clinic combined surface includes a user-visible Recover button")
    _expect(bool(gameplay.get_region3_recovery_integration_status(Region3RecoveryServiceDefinition.ROLE_CLINIC_APOTHECARY).get("available", false)), "shipped Clinic direct recovery has valid Gold, healing and save owner")

    gameplay.player.health.set_current_hp(maxi(1, gameplay.player.health.get_max_hp() - 40))
    var gold_before := InventoryState.new()
    gold_before.load_dictionary(profile.item_state)
    gameplay.merchant_menu.clinic_recovery_button.pressed.emit()
    var recovered := gameplay.last_region3_recovery_result
    _expect(bool(recovered.get("accepted", false)) and bool(recovered.get("durable", false)), "Clinic Recover button commits durable recovery")
    var gold_after := InventoryState.new()
    gold_after.load_dictionary(profile.item_state)
    _expect(gold_after.gold == gold_before.gold - 15, "Clinic button deducts exact provisional price")
    _expect(save.load_profile(1) != null, "Clinic recovery remains reloadable via SaveService")
    gameplay.merchant_menu.close_menu()
    gameplay.queue_free()
    await process_frame
    save.delete_slot(1)
    if _failures == 0:
        print("REGION 3 SHIPPED SERVICES PLAYTEST TEST PASS")
    else:
        push_error("REGION 3 SHIPPED SERVICES PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, name: String) -> void:
    if ok:
        print("PASS: %s" % name)
        return
    _failures += 1
    push_error("FAIL: %s" % name)
