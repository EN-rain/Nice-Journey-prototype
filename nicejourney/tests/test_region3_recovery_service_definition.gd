extends SceneTree

var _failures: int = 0


func _init() -> void:
    _test_inn_definition()
    _test_clinic_definition()
    _test_fail_closed_missing_tuning()
    if _failures == 0:
        print("REGION 3 RECOVERY SERVICE DEFINITION TEST PASS")
        quit(0)
        return
    push_error("REGION 3 RECOVERY SERVICE DEFINITION TEST FAIL: %d failure(s)" % _failures)
    quit(1)


func _test_inn_definition() -> void:
    var definition := _base_definition(
        &"service:region3_inn_rest",
        &"r3:functional:05",
        &"inn_rest_house"
    )
    definition["price_gold"] = 12
    definition["recovery_amounts"] = {"resource:health": 25}
    definition["save_event_id"] = &"save_event:region3_inn_rest"
    _expect(Region3RecoveryServiceDefinition.validate_dictionary(definition).is_empty(), "Inn accepts explicit authored availability/combat/price/recovery/save data")
    _expect(Region3RecoveryServiceDefinition.is_ready(definition), "available valid Inn definition is ready")
    _expect(Region3RecoveryServiceDefinition.service_mode(definition) == Region3RecoveryServiceDefinition.MODE_RECOVERY_ONLY, "Inn authoring resolves to recovery-only service mode")
    _expect(Region3RecoveryServiceDefinition.validate_production_dictionary(definition).is_empty(), "Inn fixture satisfies the production mode/save-event boundary when all content is explicit")

    var unavailable := definition.duplicate(true)
    unavailable["available"] = false
    _expect(Region3RecoveryServiceDefinition.validate_dictionary(unavailable).is_empty(), "unavailable remains a valid authored Inn definition")
    _expect(not Region3RecoveryServiceDefinition.is_ready(unavailable), "explicitly unavailable Inn definition fails closed at runtime readiness")


func _test_clinic_definition() -> void:
    var stock_service := _base_definition(
        &"service:region3_clinic_stock",
        &"r3:functional:08",
        &"clinic_apothecary"
    )
    stock_service["stock_reference_id"] = &"vendor:clinic_apothecary"
    _expect(Region3RecoveryServiceDefinition.validate_dictionary(stock_service).is_empty(), "Clinic may be authored as an explicit stock-backed consumable service without inventing recovery")
    _expect(Region3RecoveryServiceDefinition.service_mode(stock_service) == Region3RecoveryServiceDefinition.MODE_STOCK_ONLY, "stock-backed Clinic mode is explicit")
    _expect(not Region3RecoveryServiceDefinition.validate_production_dictionary(stock_service).is_empty(), "production Clinic remains blocked when only stock is authored because the master requires a consumable/healing service")

    var recovery_service := _base_definition(
        &"service:region3_clinic_recovery",
        &"r3:functional:08",
        &"clinic_apothecary"
    )
    recovery_service["recovery_amounts"] = {"resource:health": 10.0}
    _expect(Region3RecoveryServiceDefinition.validate_dictionary(recovery_service).is_empty(), "Clinic may be authored with explicit recovery data without inventing stock")
    _expect(Region3RecoveryServiceDefinition.service_mode(recovery_service) == Region3RecoveryServiceDefinition.MODE_RECOVERY_ONLY, "recovery-only Clinic mode is explicit")

    var combined := recovery_service.duplicate(true)
    combined["stock_reference_id"] = &"vendor:clinic_apothecary"
    _expect(Region3RecoveryServiceDefinition.service_mode(combined) == Region3RecoveryServiceDefinition.MODE_STOCK_AND_RECOVERY, "Clinic with explicit stock and healing resolves to the master-required combined production mode")
    _expect(Region3RecoveryServiceDefinition.validate_production_dictionary(combined).is_empty(), "combined Clinic definition satisfies production service-mode authority without inventing amounts or stock")


func _test_fail_closed_missing_tuning() -> void:
    var missing := {
        "service_id": &"service:missing",
        "structure_id": &"r3:functional:05",
        "role_id": &"inn_rest_house",
    }
    var missing_errors := Region3RecoveryServiceDefinition.validate_dictionary(missing)
    _expect(not missing_errors.is_empty(), "missing service tuning fails closed instead of selecting defaults")
    _expect(not Region3RecoveryServiceDefinition.is_ready(missing), "missing service tuning is not runtime-ready")

    var wrong_structure := _base_definition(
        &"service:wrong_structure",
        &"r3:functional:08",
        &"inn_rest_house"
    )
    wrong_structure["recovery_amounts"] = {"resource:health": 1}
    _expect(not Region3RecoveryServiceDefinition.validate_dictionary(wrong_structure).is_empty(), "service role cannot bind a different authored Region 3 structure")

    var no_inn_recovery := _base_definition(
        &"service:no_inn_recovery",
        &"r3:functional:05",
        &"inn_rest_house"
    )
    _expect(not Region3RecoveryServiceDefinition.validate_dictionary(no_inn_recovery).is_empty(), "Inn stays nonfunctional until an authored recovery amount exists")

    var no_clinic_output := _base_definition(
        &"service:no_clinic_output",
        &"r3:functional:08",
        &"clinic_apothecary"
    )
    _expect(not Region3RecoveryServiceDefinition.validate_dictionary(no_clinic_output).is_empty(), "Clinic stays nonfunctional until authored recovery or stock exists")

    var malformed := _base_definition(
        &"service:malformed",
        &"r3:functional:08",
        &"clinic_apothecary"
    )
    malformed["recovery_amounts"] = {"not stable": NAN}
    _expect(not Region3RecoveryServiceDefinition.validate_dictionary(malformed).is_empty(), "malformed recovery identity/magnitude is rejected")


func _base_definition(service_id: StringName, structure_id: StringName, role_id: StringName) -> Dictionary:
    return {
        "service_id": service_id,
        "structure_id": structure_id,
        "role_id": role_id,
        "available": true,
        "combat_restricted": true,
        "price_gold": null,
        "recovery_amounts": null,
        "stock_reference_id": null,
        "save_event_id": null,
    }


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
