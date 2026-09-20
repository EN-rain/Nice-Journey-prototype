extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_absent_content_is_unavailable()
    _test_definition_requires_complete_authored_manifest()
    _test_catalog_builds_exact_isolated_runtime_state()
    _test_duplicate_vendor_ids_fail_closed()
    _test_cross_vendor_buy_sell_arbitrage()
    if _failures == 0:
        print("ECONOMY VENDOR STOCK CATALOG TEST PASS")
    else:
        push_error("ECONOMY VENDOR STOCK CATALOG TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_absent_content_is_unavailable() -> void:
    var catalog := VendorStockCatalog.new()
    _expect(catalog.validate_catalog().is_empty(), "empty vendor catalog is structurally valid")
    _expect(not catalog.has_authored_vendor(&"vendor:general_merchant"), "missing General Merchant content is reported unavailable")
    _expect(catalog.build_vendor_state(&"vendor:general_merchant") == null, "missing General Merchant content cannot fabricate runtime stock")


func _test_definition_requires_complete_authored_manifest() -> void:
    var missing_rule := VendorStockDefinition.new()
    missing_rule.vendor_id = &"vendor:test_missing_rule"
    missing_rule.stock = _stock()
    _expect(not missing_rule.validate_definition().is_empty(), "vendor definition requires an explicit restock rule identity")

    var missing_stock := VendorStockDefinition.new()
    missing_stock.vendor_id = &"vendor:test_missing_stock"
    missing_stock.restock_rule_id = &"restock:none"
    _expect(not missing_stock.validate_definition().is_empty(), "vendor definition requires at least one exact authored stock entry")

    var invalid_prices := VendorStockDefinition.new()
    invalid_prices.vendor_id = &"vendor:test_bad_prices"
    invalid_prices.restock_rule_id = &"restock:none"
    invalid_prices.stock = {
        "itemdef:test_tonic": {
            "buy_price": 5,
            "sell_price": 6,
            "quantity": 2,
            "stackable": true,
        },
    }
    _expect(not invalid_prices.validate_definition().is_empty(), "vendor definition rejects a buy-to-sell profit loop")


func _test_catalog_builds_exact_isolated_runtime_state() -> void:
    var definition := _definition(&"vendor:test_merchant")
    var catalog := VendorStockCatalog.new()
    catalog.definitions = [definition]
    _expect(catalog.validate_catalog().is_empty(), "complete authored vendor definition validates")
    _expect(catalog.has_authored_vendor(&"vendor:test_merchant"), "catalog exposes only explicitly authored vendor identity")

    var runtime := catalog.build_vendor_state(&"vendor:test_merchant")
    _expect(runtime != null, "catalog builds runtime stock only from a complete authored definition")
    if runtime != null:
        var entry := runtime.get_entry(&"itemdef:test_tonic")
        _expect(
            int(entry.get("buy_price", -1)) == 10
            and int(entry.get("sell_price", -1)) == 4
            and int(entry.get("quantity", -1)) == 3
            and bool(entry.get("stackable", false)),
            "runtime state preserves exact authored price, quantity and stackability"
        )
        _expect(runtime.adjust_quantity(&"itemdef:test_tonic", -1), "runtime stock can mutate independently after creation")
        var fresh := catalog.build_vendor_state(&"vendor:test_merchant")
        _expect(
            fresh != null and int(fresh.get_entry(&"itemdef:test_tonic").get("quantity", -1)) == 3,
            "runtime stock mutation cannot alter the catalog source of truth"
        )


func _test_duplicate_vendor_ids_fail_closed() -> void:
    var catalog := VendorStockCatalog.new()
    catalog.definitions = [
        _definition(&"vendor:duplicate"),
        _definition(&"vendor:duplicate"),
    ]
    _expect(not catalog.validate_catalog().is_empty(), "duplicate vendor IDs invalidate the catalog")
    _expect(catalog.build_vendor_state(&"vendor:duplicate") == null, "invalid catalog cannot produce ambiguous runtime stock")


func _test_cross_vendor_buy_sell_arbitrage() -> void:
    var cheap := _definition(&"vendor:cheap")
    var expensive := _definition(&"vendor:expensive")
    expensive.stock = {
        "itemdef:test_tonic": {
            "buy_price": 15,
            "sell_price": 11,
            "quantity": 3,
            "stackable": true,
        },
    }
    var catalog := VendorStockCatalog.new()
    catalog.definitions = [cheap, expensive]
    _expect(
        cheap.validate_definition().is_empty() and expensive.validate_definition().is_empty(),
        "both individual vendor definitions satisfy local no-profit rules"
    )
    _expect(
        not catalog.validate_catalog().is_empty(),
        "the catalog rejects buying for 10 at one vendor and selling for 11 at another"
    )
    _expect(
        catalog.instantiate_vendor(&"vendor:cheap") == null,
        "cross-vendor arbitrage cannot initialize a vendor even when its own stock is valid"
    )
    expensive.stock["itemdef:test_tonic"]["sell_price"] = 10
    _expect(catalog.validate_catalog().is_empty(), "matching cross-vendor buy/sell limits remain permitted")


func _definition(vendor_id: StringName) -> VendorStockDefinition:
    var definition := VendorStockDefinition.new()
    definition.vendor_id = vendor_id
    definition.restock_rule_id = &"restock:none"
    definition.stock = _stock()
    return definition


func _stock() -> Dictionary:
    return {
        "itemdef:test_tonic": {
            "buy_price": 10,
            "sell_price": 4,
            "quantity": 3,
            "stackable": true,
        },
    }


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
