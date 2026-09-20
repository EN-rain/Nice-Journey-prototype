extends SceneTree

const PLAYTEST: Region3PlaytestContent = preload("res://src/data/tuning/region3_services_playtest_v01.tres")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _expect(PLAYTEST.validate_content().is_empty(), "shipped provisional economy bundle is internally consistent")

    var missing_upgrade := _copy()
    missing_upgrade.blacksmith_recipes.recipes.remove_at(1)
    _expect(_has_error(missing_upgrade, "no starter weapon upgrade for starter_bow"), "missing Ranged starter upgrade invalidates the shipped three-class bundle")

    var missing_ore := _copy()
    var merchant := missing_ore.merchant_stock.get_definition(&"vendor:general_merchant")
    merchant.stock.erase("itemdef:region3_playtest_ore")
    _expect(_has_error(missing_ore, "no General Merchant source for upgrade material"), "shipped upgrade recipes cannot lose their only authored material source")

    var insufficient_ore := _copy()
    var limited_merchant := insufficient_ore.merchant_stock.get_definition(&"vendor:general_merchant")
    var limited_entry := (limited_merchant.stock["itemdef:region3_playtest_ore"] as Dictionary).duplicate(true)
    limited_entry["quantity"] = 1
    limited_merchant.stock["itemdef:region3_playtest_ore"] = limited_entry
    _expect(_has_error(insufficient_ore, "insufficient authored upgrade material stock"), "shipped starting stock must cover at least one eligible upgrade")

    var wrong_clinic := _copy()
    wrong_clinic.clinic_recovery["stock_reference_id"] = &"vendor:general_merchant"
    _expect(_has_error(wrong_clinic, "Clinic recovery must reference its authored Clinic stock"), "Clinic cannot silently use General Merchant inventory")

    var nonconsumable := _copy()
    var clinic := nonconsumable.merchant_stock.get_definition(&"vendor:clinic_apothecary")
    var changed_stock := clinic.stock.duplicate(true)
    changed_stock["itemdef:region3_playtest_ore"] = {
        "buy_price": 8, "sell_price": 2, "quantity": 2, "stackable": true,
    }
    clinic.stock = changed_stock
    _expect(_has_error(nonconsumable, "Clinic stock must contain only authored consumables"), "Clinic cannot sell a material under its consumable role")

    var unsupported_mapping := _copy()
    unsupported_mapping.recovery_mapping["resource:region3_playtest_hp"] = &"runtime:invented_target"
    _expect(_has_error(unsupported_mapping, "unsupported live recovery target"), "unsupported Inspector recovery target blocks the entire bundle")

    var duplicate_target := _copy()
    duplicate_target.recovery_mapping["resource:region3_playtest_stamina"] = &"runtime:player_health"
    _expect(_has_error(duplicate_target, "multiple recovery sources target"), "two authored recovery IDs cannot claim one runtime resource")

    var missing_mapping := _copy()
    missing_mapping.recovery_mapping.erase("resource:region3_playtest_hp")
    _expect(_has_error(missing_mapping, "no live recovery mapping"), "missing recovery mapping fails closed")

    var fractional_health := _copy()
    var clinic_amounts := (fractional_health.clinic_recovery["recovery_amounts"] as Dictionary).duplicate(true)
    clinic_amounts["resource:region3_playtest_hp"] = 60.5
    fractional_health.clinic_recovery["recovery_amounts"] = clinic_amounts
    _expect(_has_error(fractional_health, "health recovery must be integral"), "fractional HP recovery cannot reach an integer HP owner")

    _expect(PLAYTEST.validate_content().is_empty(), "negative fixtures leave the shipped resource unchanged")

    if _failures == 0:
        print("REGION 3 PLAYTEST ECONOMY CONTENT TEST PASS")
    else:
        push_error("REGION 3 PLAYTEST ECONOMY CONTENT TEST FAILURES: %d" % _failures)
    quit(_failures)


func _copy() -> Region3PlaytestContent:
    return PLAYTEST.duplicate(true) as Region3PlaytestContent


func _has_error(content: Region3PlaytestContent, fragment: String) -> bool:
    for message: String in content.validate_content():
        if message.contains(fragment):
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
