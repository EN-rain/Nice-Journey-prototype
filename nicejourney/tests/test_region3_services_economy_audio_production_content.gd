extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_item_category_production_readiness()
    _test_general_merchant_production_readiness()
    _test_blacksmith_production_readiness()
    _test_recovery_production_readiness()
    _test_music_production_readiness()

    if _failures == 0:
        print("REGION 3 SERVICES ECONOMY AUDIO PRODUCTION CONTENT TEST PASS")
    else:
        push_error("REGION 3 SERVICES ECONOMY AUDIO PRODUCTION CONTENT TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_item_category_production_readiness() -> void:
    var catalog := ItemCategoryCatalog.new()
    var required: Array[StringName] = [&"itemdef:test_consumable", &"itemdef:test_material"]
    var readiness := catalog.production_readiness(required)
    _expect(not bool(readiness.get("available", true)), "empty category catalog remains production-unavailable")
    var missing := readiness.get("missing_definition_ids", []) as Array
    _expect(
        missing.size() == 2
        and missing.has(&"itemdef:test_consumable")
        and missing.has(&"itemdef:test_material"),
        "category production readiness reports exact required definitions without classifying by name"
    )

    catalog.definition_categories = {
        "itemdef:test_consumable": ItemCategoryCatalog.CATEGORY_CONSUMABLE,
        "itemdef:test_material": ItemCategoryCatalog.CATEGORY_MATERIAL,
    }
    readiness = catalog.production_readiness(required)
    _expect(bool(readiness.get("available", false)), "explicit categories satisfy category production readiness")


func _test_general_merchant_production_readiness() -> void:
    var catalog := VendorStockCatalog.new()
    var readiness := catalog.general_merchant_readiness(ItemCategoryCatalog.new(), true)
    var missing := readiness.get("missing_fields", PackedStringArray()) as PackedStringArray
    _expect(not bool(readiness.get("available", true)), "missing General Merchant content remains fail-closed")
    for field: String in [
        "stock_manifest",
        "buy_prices",
        "sell_prices",
        "quantities",
        "stackability",
        "restock_rule_id",
        "restock_policy",
        "availability_conditions",
        "item_category_catalog",
    ]:
        _expect(missing.has(field), "General Merchant readiness reports missing %s" % field)


func _test_blacksmith_production_readiness() -> void:
    var catalog := UpgradeRecipeCatalog.new()
    var readiness := catalog.readiness(ItemCategoryCatalog.new(), true)
    var missing := readiness.get("missing_fields", PackedStringArray()) as PackedStringArray
    _expect(not bool(readiness.get("available", true)), "missing Blacksmith recipes remain fail-closed")
    for field: String in [
        "recipe_id",
        "compatible_definition_ids",
        "compatible_rarities",
        "source_rank",
        "result_rank",
        "maximum_rank",
        "gold_cost",
        "material_costs",
        "stat_changes",
        "prerequisites",
        "item_category_catalog",
    ]:
        _expect(missing.has(field), "Blacksmith readiness reports missing %s" % field)


func _test_recovery_production_readiness() -> void:
    var inn := Region3RecoveryServiceDefinition.production_readiness_for_role(
        Region3RecoveryServiceDefinition.ROLE_INN_REST_HOUSE
    )
    _expect(not bool(inn.get("available", true)), "missing production Inn definition remains fail-closed")
    _expect(
        StringName(inn.get("expected_structure_id", &"")) == &"r3:functional:05"
        and StringName(inn.get("expected_mode", &"")) == Region3RecoveryServiceDefinition.MODE_RECOVERY_ONLY,
        "Inn readiness preserves exact authored structure and production mode"
    )
    var inn_missing := inn.get("missing_fields", PackedStringArray()) as PackedStringArray
    for field: String in [
        "service_id",
        "structure_id",
        "role_id",
        "available",
        "combat_restricted",
        "price_gold",
        "recovery_amounts",
        "stock_reference_id",
        "save_event_id",
    ]:
        _expect(inn_missing.has(field), "Inn readiness reports missing %s" % field)

    var clinic := Region3RecoveryServiceDefinition.production_readiness_for_role(
        Region3RecoveryServiceDefinition.ROLE_CLINIC_APOTHECARY
    )
    _expect(not bool(clinic.get("available", true)), "missing production Clinic definition remains fail-closed")
    _expect(
        StringName(clinic.get("expected_structure_id", &"")) == &"r3:functional:08"
        and StringName(clinic.get("expected_mode", &"")) == Region3RecoveryServiceDefinition.MODE_STOCK_AND_RECOVERY,
        "Clinic readiness preserves exact authored structure and combined production mode"
    )
    var clinic_missing := clinic.get("missing_fields", PackedStringArray()) as PackedStringArray
    _expect(
        clinic_missing.has("recovery_amounts") and clinic_missing.has("stock_reference_id"),
        "Clinic readiness requires both authored healing and consumable-stock ownership"
    )


func _test_music_production_readiness() -> void:
    var routing := AudioMusicRoutingDefinition.new()
    var readiness := routing.production_readiness()
    var missing := readiness.get("missing_fields", PackedStringArray()) as PackedStringArray
    _expect(not bool(readiness.get("available", true)), "missing production music routing remains fail-closed")
    for field: String in [
        "authored",
        "fade_seconds",
        "debounce_seconds",
        "exploration_event",
        "exploration_stream",
        "combat_event",
        "combat_stream",
        "boss_event",
        "boss_stream",
        "recovery_event",
        "recovery_stream",
    ]:
        _expect(missing.has(field), "music readiness reports missing %s" % field)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
