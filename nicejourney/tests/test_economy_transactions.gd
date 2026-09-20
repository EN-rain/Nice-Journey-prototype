extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_atomic_buy_sell_and_duplicate_resistance()
    _test_full_inventory_purchase_rejection()
    _test_vendor_manifest_rejects_profit_loop()
    _test_vendor_stock_persists_without_reload_restock()
    if _failures == 0:
        print("ECONOMY TRANSACTION TEST PASS")
    else:
        push_error("ECONOMY TRANSACTION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_atomic_buy_sell_and_duplicate_resistance() -> void:
    var inventory := InventoryState.new()
    _expect(inventory.add_gold(100), "fixture starts with finite Gold")
    var vendor := _vendor()
    var ledger := ClaimLedger.new()

    var purchase: Dictionary = EconomyTransactionService.buy(
        inventory,
        vendor,
        ledger,
        &"transaction:buy_potion_01",
        &"itemdef:potion",
        &"item:purchased_potion_stack",
        3
    )
    _expect(purchase["accepted"], "buy transaction revalidates stock/funds/capacity then commits")
    _expect(inventory.gold == 70, "buy deducts exact Gold cost once")
    _expect(vendor.get_entry(&"itemdef:potion")["quantity"] == 7, "buy decrements fixed authored vendor stock")
    _expect(inventory.get_normal_slot(&"item:purchased_potion_stack")["quantity"] == 3, "purchased item enters normal inventory")
    _expect(ledger.is_claimed(&"transaction:buy_potion_01"), "committed transaction ID is recorded for repeat-click resistance")

    var before_duplicate_inventory: Dictionary = inventory.to_dictionary()
    var before_duplicate_vendor: Dictionary = vendor.to_dictionary()
    var duplicate: Dictionary = EconomyTransactionService.buy(
        inventory,
        vendor,
        ledger,
        &"transaction:buy_potion_01",
        &"itemdef:potion",
        &"item:duplicate_attempt",
        1
    )
    _expect(not duplicate["accepted"] and duplicate["reason_id"] == EconomyTransactionService.REASON_DUPLICATE_TRANSACTION, "duplicate committed transaction ID is rejected")
    _expect(inventory.to_dictionary() == before_duplicate_inventory and vendor.to_dictionary() == before_duplicate_vendor, "duplicate rejection mutates neither inventory nor stock")

    var sale: Dictionary = EconomyTransactionService.sell(
        inventory,
        vendor,
        ledger,
        &"transaction:sell_potion_01",
        &"item:purchased_potion_stack",
        2
    )
    _expect(sale["accepted"], "sell transaction commits against owned normal item")
    _expect(inventory.gold == 80, "sale credits exact authored sell value")
    _expect(vendor.get_entry(&"itemdef:potion")["quantity"] == 9, "sold stock returns to the merchant manifest without reload restock")
    _expect(inventory.get_normal_slot(&"item:purchased_potion_stack")["quantity"] == 1, "partial sale preserves remaining owned quantity")

    var round_trip_inventory := InventoryState.new()
    _expect(round_trip_inventory.add_gold(20), "round-trip fixture funds purchase")
    var round_trip_vendor := _vendor()
    var round_trip_ledger := ClaimLedger.new()
    _expect(EconomyTransactionService.buy(round_trip_inventory, round_trip_vendor, round_trip_ledger, &"transaction:round_buy", &"itemdef:potion", &"item:round_stack", 1)["accepted"], "round-trip fixture buys once")
    _expect(EconomyTransactionService.sell(round_trip_inventory, round_trip_vendor, round_trip_ledger, &"transaction:round_sell", &"item:round_stack", 1)["accepted"], "round-trip fixture sells once")
    _expect(round_trip_inventory.gold == 15, "buy then sell cannot create a Gold profit loop")


func _test_full_inventory_purchase_rejection() -> void:
    var inventory := InventoryState.new()
    _expect(inventory.add_gold(500), "full-inventory fixture has sufficient Gold")
    for index: int in range(NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY):
        _expect(inventory.try_add_normal(StringName("item:full_%02d" % index), StringName("itemdef:full_%02d" % index), 1, false)["accepted"], "fills normal slot %02d" % index)
    var vendor := _vendor()
    var ledger := ClaimLedger.new()
    var before_inventory: Dictionary = inventory.to_dictionary()
    var before_vendor: Dictionary = vendor.to_dictionary()

    var rejected: Dictionary = EconomyTransactionService.buy(
        inventory,
        vendor,
        ledger,
        &"transaction:full_reject",
        &"itemdef:potion",
        &"item:full_reject_potion",
        1
    )
    _expect(not rejected["accepted"] and rejected["reason_id"] == EconomyTransactionService.REASON_INVENTORY_REJECTED, "full inventory purchase rejects before real-state commit")
    _expect(rejected["inventory_reason_id"] == InventoryState.REASON_INVENTORY_FULL, "purchase surfaces the concrete capacity rejection")
    _expect(inventory.to_dictionary() == before_inventory, "rejected purchase does not deduct Gold")
    _expect(vendor.to_dictionary() == before_vendor, "rejected purchase does not consume stock")
    _expect(not ledger.is_claimed(&"transaction:full_reject"), "rejected purchase does not consume transaction identity")


func _test_vendor_manifest_rejects_profit_loop() -> void:
    var invalid := VendorStockState.new()
    _expect(not invalid.configure(&"vendor:invalid", {
        "itemdef:bad": {
            "buy_price": 5,
            "sell_price": 6,
            "quantity": 1,
            "stackable": true,
        },
    }), "vendor authoring rejects sell price greater than buy price")


func _test_vendor_stock_persists_without_reload_restock() -> void:
    var inventory := InventoryState.new()
    _expect(inventory.add_gold(100), "vendor persistence fixture starts with Gold")
    var vendor := _vendor()
    var ledger := ClaimLedger.new()
    _expect(EconomyTransactionService.buy(inventory, vendor, ledger, &"transaction:persist_buy", &"itemdef:potion", &"item:persist_stack", 4)["accepted"], "vendor persistence fixture consumes authored stock")
    var economy := EconomyState.new()
    _expect(economy.set_vendor(vendor), "mutated vendor stock enters persistent economy state")

    var profile := ProfileSnapshot.new()
    profile.profile_id = "profile:economy_fixture"
    profile.protagonist_name = "Economy Fixture"
    profile.class_id = "ranged"
    profile.item_state = inventory.to_dictionary()
    profile.economy_state = economy.to_dictionary()
    var data: Dictionary = profile.to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(data).is_empty(), "profile validates persisted merchant stock with item/economy state")
    var restored: ProfileSnapshot = ProfileSnapshot.from_dictionary(data)
    var restored_economy := EconomyState.new()
    _expect(restored_economy.load_dictionary(restored.economy_state).is_empty(), "economy state round-trips through profile persistence")
    var restored_vendor: VendorStockState = restored_economy.get_vendor(&"vendor:general_merchant")
    _expect(restored_vendor != null and restored_vendor.get_entry(&"itemdef:potion")["quantity"] == 6, "reload preserves consumed vendor quantity instead of regenerating authored stock")


func _vendor() -> VendorStockState:
    var vendor := VendorStockState.new()
    _expect(vendor.configure(&"vendor:general_merchant", {
        "itemdef:potion": {
            "buy_price": 10,
            "sell_price": 5,
            "quantity": 10,
            "stackable": true,
        },
        "itemdef:sword": {
            "buy_price": 50,
            "sell_price": 20,
            "quantity": 1,
            "stackable": false,
        },
    }), "authored merchant stock validates")
    return vendor


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
