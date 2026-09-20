extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Merchant Boundary", "ranged")
    var missing_vendor_profile := ProfileCreationService.create_profile(2, "Merchant Missing", "melee")
    var missing_before := missing_vendor_profile.to_dictionary()
    var missing_vendor := ProfileEconomyTransactionService.buy(
        missing_vendor_profile,
        VendorStockCatalog.REGION3_GENERAL_MERCHANT_VENDOR_ID,
        &"transaction:merchant:missing_content",
        &"itemdef:unknown",
        &"item:unknown",
        1
    )
    _expect(not bool(missing_vendor.get("accepted", true)) and StringName(missing_vendor.get("reason_id", &"")) == ProfileEconomyTransactionService.REASON_VENDOR_NOT_FOUND, "profile merchant transaction fails closed when production vendor content has not been loaded")
    _expect(missing_vendor_profile.to_dictionary() == missing_before, "missing merchant content rejection is non-mutating")

    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "merchant fixture loads profile inventory")
    _expect(inventory.add_gold(100), "merchant fixture owns Gold")
    _expect(inventory.try_add_normal(&"item:owned_potion", &"itemdef:potion", 2, true).get("accepted", false), "merchant fixture owns sellable normal stack")
    profile.item_state = inventory.to_dictionary()
    var vendor := VendorStockState.new()
    _expect(vendor.configure(&"vendor:test_merchant", {
        "itemdef:potion": {"buy_price": 10, "sell_price": 4, "quantity": 8, "stackable": true},
        "itemdef:gear": {"buy_price": 45, "sell_price": 20, "quantity": 1, "stackable": false},
    }), "merchant fixture authors explicit stock and prices")
    var economy := EconomyState.new()
    _expect(economy.set_vendor(vendor), "merchant fixture persists authored vendor state")
    profile.economy_state = economy.to_dictionary()

    var view := MerchantViewService.build_view(profile, &"vendor:test_merchant")
    _expect(bool(view.get("accepted", false)), "merchant view reads persisted vendor authority")
    _expect(int(view.get("gold", -1)) == 100 and (view.get("stock_entries", []) as Array).size() == 2, "merchant view exposes exact Gold and stock entries")
    var potion_stock := _find_definition(view.get("stock_entries", []) as Array, &"itemdef:potion")
    _expect(int(potion_stock.get("buy_price", -1)) == 10 and int(potion_stock.get("sell_price", -1)) == 4 and int(potion_stock.get("quantity", -1)) == 8, "merchant view preserves exact authored potion prices/quantity")
    _expect((view.get("sell_entries", []) as Array).size() == 1, "merchant view exposes only owned items sellable by this vendor")
    _expect(not bool(MerchantViewService.build_view(profile, &"vendor:missing").get("accepted", true)), "merchant view does not fabricate missing vendor stock")

    var bought := ProfileEconomyTransactionService.buy(
        profile,
        &"vendor:test_merchant",
        &"transaction:merchant:buy",
        &"itemdef:potion",
        &"item:bought_potion",
        3
    )
    _expect(bool(bought.get("accepted", false)) and not bool(bought.get("durable", true)), "profile merchant buy commits through authoritative economy transaction as live unbanked state")
    inventory = InventoryState.new()
    economy = EconomyState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty() and economy.load_dictionary(profile.economy_state).is_empty(), "merchant buy preserves valid persisted states")
    _expect(inventory.gold == 70 and inventory.get_total_quantity(&"itemdef:potion") == 5, "merchant buy deducts exact authored price and grants exact quantity")
    _expect(int(inventory.get_normal_slot(&"item:owned_potion").get("quantity", 0)) == 5 and inventory.get_normal_slot(&"item:bought_potion").is_empty(), "compatible merchant purchase merges into existing stack without fabricating duplicate ownership")
    vendor = economy.get_vendor(&"vendor:test_merchant")
    _expect(vendor != null and int(vendor.get_entry(&"itemdef:potion").get("quantity", -1)) == 5, "merchant buy persists decremented authored stock")

    var sold := ProfileEconomyTransactionService.sell(
        profile,
        &"vendor:test_merchant",
        &"transaction:merchant:sell",
        &"item:owned_potion",
        2
    )
    _expect(bool(sold.get("accepted", false)), "profile merchant sell commits through authoritative economy transaction")
    inventory = InventoryState.new()
    economy = EconomyState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty() and economy.load_dictionary(profile.economy_state).is_empty(), "merchant sell preserves valid persisted states")
    _expect(inventory.gold == 78 and int(inventory.get_normal_slot(&"item:owned_potion").get("quantity", 0)) == 3, "merchant sell credits exact authored sell value and preserves remainder")
    vendor = economy.get_vendor(&"vendor:test_merchant")
    _expect(vendor != null and int(vendor.get_entry(&"itemdef:potion").get("quantity", -1)) == 7, "merchant sell returns exact quantity to persisted vendor stock")
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "merchant profile wrapper preserves whole-profile validity")

    if _failures == 0:
        print("PROFILE ECONOMY UI BOUNDARY TEST PASS")
    else:
        push_error("PROFILE ECONOMY UI BOUNDARY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _find_definition(entries: Array, definition_id: StringName) -> Dictionary:
    for raw_entry: Variant in entries:
        if raw_entry is Dictionary and StringName(String((raw_entry as Dictionary).get("definition_id", &""))) == definition_id:
            return (raw_entry as Dictionary).duplicate(true)
    return {}


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
