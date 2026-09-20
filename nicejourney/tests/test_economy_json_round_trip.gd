extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var vendor := VendorStockState.new()
    _expect(vendor.configure(&"vendor:json_roundtrip", {
        "itemdef:potion": {
            "buy_price": 10,
            "sell_price": 5,
            "quantity": 7,
            "stackable": true,
        },
    }), "economy JSON fixture accepts integer-authored vendor stock")

    var economy := EconomyState.new()
    _expect(economy.set_vendor(vendor), "economy JSON fixture stores authored vendor state")
    _expect(economy.add_pending_reward(
        &"claim:json_pending",
        &"quest:json_source",
        [{
            "item_instance_id": "item:json_pending",
            "definition_id": "itemdef:json_pending",
            "quantity": 2,
            "stackable": true,
        }]
    ), "economy JSON fixture stores an integer-authored pending reward")

    var profile := ProfileCreationService.create_profile(1, "Economy JSON", "ranged")
    profile.economy_state = economy.to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "non-empty economy state validates before JSON serialization")

    var encoded := JSON.stringify(profile.to_dictionary())
    var parsed_variant: Variant = JSON.parse_string(encoded)
    _expect(parsed_variant is Dictionary, "economy profile parses back from JSON")
    var parsed := parsed_variant as Dictionary
    _expect(typeof(((parsed["economy_state"] as Dictionary)["vendor_states"] as Dictionary)["vendor:json_roundtrip"]["stock"]["itemdef:potion"]["buy_price"]) == TYPE_FLOAT, "test fixture confirms JSON converted persisted vendor integers to numeric floats")
    _expect(typeof((((parsed["economy_state"] as Dictionary)["pending_reward_claims"] as Dictionary)["claim:json_pending"] as Dictionary)["normal_rewards"][0]["quantity"]) == TYPE_FLOAT, "test fixture confirms JSON converted pending reward quantity to numeric float")
    _expect(ProfileSnapshot.validate_dictionary(parsed).is_empty(), "whole-profile validation accepts only integral JSON numeric representations in economy state")

    var restored := ProfileSnapshot.from_dictionary(parsed)
    var restored_economy := EconomyState.new()
    _expect(restored_economy.load_dictionary(restored.economy_state).is_empty(), "EconomyState loads the JSON-normalized vendor and pending reward data")
    var restored_vendor := restored_economy.get_vendor(&"vendor:json_roundtrip")
    _expect(restored_vendor != null, "restored economy resolves persisted vendor")
    if restored_vendor != null:
        var restored_stock := restored_vendor.get_entry(&"itemdef:potion")
        _expect(typeof(restored_stock.get("buy_price", null)) == TYPE_INT and typeof(restored_stock.get("sell_price", null)) == TYPE_INT and typeof(restored_stock.get("quantity", null)) == TYPE_INT, "loaded vendor state canonicalizes integral JSON numbers back to integers")
        _expect(int(restored_stock.get("quantity", -1)) == 7, "loaded vendor state preserves exact stock quantity")
    var restored_pending := restored_economy.get_pending_reward(&"claim:json_pending")
    var restored_rewards := restored_pending.get("normal_rewards", []) as Array
    _expect(restored_rewards.size() == 1 and typeof((restored_rewards[0] as Dictionary).get("quantity", null)) == TYPE_INT and int((restored_rewards[0] as Dictionary).get("quantity", -1)) == 2, "loaded pending reward canonicalizes and preserves exact quantity")

    var live_float_vendor := VendorStockState.new()
    _expect(not live_float_vendor.configure(&"vendor:float_live", {
        "itemdef:float_live": {
            "buy_price": 10.0,
            "sell_price": 5,
            "quantity": 1,
            "stackable": true,
        },
    }), "live vendor authoring still rejects float values instead of weakening the caller contract")
    var live_pending := EconomyState.new()
    _expect(not live_pending.add_pending_reward(
        &"claim:float_live",
        &"quest:float_live",
        [{
            "item_instance_id": "item:float_live",
            "definition_id": "itemdef:float_live",
            "quantity": 1.0,
            "stackable": true,
        }]
    ), "live pending-reward creation still requires strict integer quantity")

    var fractional := restored_economy.to_dictionary()
    (((fractional["vendor_states"] as Dictionary)["vendor:json_roundtrip"] as Dictionary)["stock"] as Dictionary)["itemdef:potion"]["quantity"] = 7.5
    _expect(not EconomyState.validate_dictionary(fractional).is_empty(), "persisted economy validation rejects fractional vendor numbers")
    fractional = restored_economy.to_dictionary()
    (((fractional["pending_reward_claims"] as Dictionary)["claim:json_pending"] as Dictionary)["normal_rewards"] as Array)[0]["quantity"] = 2.5
    _expect(not EconomyState.validate_dictionary(fractional).is_empty(), "persisted economy validation rejects fractional pending-reward quantities")

    var near_integral := restored_economy.to_dictionary()
    (((near_integral["vendor_states"] as Dictionary)["vendor:json_roundtrip"] as Dictionary)["stock"] as Dictionary)["itemdef:potion"]["buy_price"] = 10.00001
    _expect(not EconomyState.validate_dictionary(near_integral).is_empty(), "persisted vendor prices reject near-integer fractional values instead of truncating them")
    near_integral = restored_economy.to_dictionary()
    (((near_integral["vendor_states"] as Dictionary)["vendor:json_roundtrip"] as Dictionary)["stock"] as Dictionary)["itemdef:potion"]["quantity"] = 7.00001
    _expect(not EconomyState.validate_dictionary(near_integral).is_empty(), "persisted vendor stock rejects near-integer fractional quantities instead of truncating them")
    near_integral = restored_economy.to_dictionary()
    (((near_integral["vendor_states"] as Dictionary)["vendor:json_roundtrip"] as Dictionary)["stock"] as Dictionary)["itemdef:potion"]["quantity"] = 2147483648
    _expect(not EconomyState.validate_dictionary(near_integral).is_empty(), "persisted vendor stock rejects quantities above the live runtime limit")

    if _failures == 0:
        print("ECONOMY JSON ROUND TRIP TEST PASS")
    else:
        push_error("ECONOMY JSON ROUND TRIP TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
