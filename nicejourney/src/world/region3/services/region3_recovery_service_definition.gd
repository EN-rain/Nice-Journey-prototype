class_name Region3RecoveryServiceDefinition
extends RefCounted

const ROLE_INN_REST_HOUSE: StringName = &"inn_rest_house"
const ROLE_CLINIC_APOTHECARY: StringName = &"clinic_apothecary"

const MODE_UNRESOLVED: StringName = &"unresolved"
const MODE_RECOVERY_ONLY: StringName = &"recovery_only"
const MODE_STOCK_ONLY: StringName = &"stock_only"
const MODE_STOCK_AND_RECOVERY: StringName = &"stock_and_recovery"

const PRODUCTION_MODE_BY_ROLE: Dictionary = {
    ROLE_INN_REST_HOUSE: MODE_RECOVERY_ONLY,
    ROLE_CLINIC_APOTHECARY: MODE_STOCK_AND_RECOVERY,
}

const STRUCTURE_BY_ROLE: Dictionary = {
    ROLE_INN_REST_HOUSE: &"r3:functional:05",
    ROLE_CLINIC_APOTHECARY: &"r3:functional:08",
}


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    _require_stable_id(data, "service_id", errors)
    _require_stable_id(data, "structure_id", errors)
    _require_stable_id(data, "role_id", errors)

    var role_id := StringName(String(data.get("role_id", &"")))
    if not STRUCTURE_BY_ROLE.has(role_id):
        errors.append("role_id must identify the Inn / Rest House or Clinic / Apothecary")
    elif StringName(String(data.get("structure_id", &""))) != StringName(STRUCTURE_BY_ROLE[role_id]):
        errors.append("structure_id must match the authored Region 3 recovery-service role")

    if typeof(data.get("available", null)) != TYPE_BOOL:
        errors.append("available must be an explicitly authored boolean")
    if typeof(data.get("combat_restricted", null)) != TYPE_BOOL:
        errors.append("combat_restricted must be an explicitly authored boolean")

    if not data.has("price_gold"):
        errors.append("price_gold must be explicitly present (null for no price)")
    else:
        var price: Variant = data.get("price_gold", null)
        if price != null and (typeof(price) != TYPE_INT or int(price) < 0):
            errors.append("price_gold must be null or a non-negative integer")

    if not data.has("recovery_amounts"):
        errors.append("recovery_amounts must be explicitly present (null for no recovery)")
    else:
        var recovery: Variant = data.get("recovery_amounts", null)
        if recovery != null:
            if not recovery is Dictionary:
                errors.append("recovery_amounts must be null or a dictionary")
            else:
                _validate_recovery_amounts(recovery as Dictionary, errors)

    if not data.has("stock_reference_id"):
        errors.append("stock_reference_id must be explicitly present (null for no stock)")
    else:
        var stock_reference: Variant = data.get("stock_reference_id", null)
        if stock_reference != null and not _is_stable_id_variant(stock_reference):
            errors.append("stock_reference_id must be null or a stable ID")

    if not data.has("save_event_id"):
        errors.append("save_event_id must be explicitly present (null for no save event)")
    else:
        var save_event: Variant = data.get("save_event_id", null)
        if save_event != null and not _is_stable_id_variant(save_event):
            errors.append("save_event_id must be null or a stable ID")

    if role_id == ROLE_INN_REST_HOUSE:
        var inn_recovery: Variant = data.get("recovery_amounts", null)
        if not inn_recovery is Dictionary or (inn_recovery as Dictionary).is_empty():
            errors.append("Inn / Rest House requires authored recovery_amounts before it can become functional")
    elif role_id == ROLE_CLINIC_APOTHECARY:
        var clinic_recovery: Variant = data.get("recovery_amounts", null)
        var clinic_stock: Variant = data.get("stock_reference_id", null)
        var has_recovery := clinic_recovery is Dictionary and not (clinic_recovery as Dictionary).is_empty()
        var has_stock := clinic_stock != null and _is_stable_id_variant(clinic_stock)
        if not has_recovery and not has_stock:
            errors.append("Clinic / Apothecary requires an authored recovery amount or stock reference before it can become functional")

    return errors


static func is_ready(data: Dictionary) -> bool:
    return validate_dictionary(data).is_empty() and bool(data.get("available", false))


static func service_mode(data: Dictionary) -> StringName:
    var recovery: Variant = data.get("recovery_amounts", null)
    var stock: Variant = data.get("stock_reference_id", null)
    var has_recovery := recovery is Dictionary and not (recovery as Dictionary).is_empty()
    var has_stock := stock != null and _is_stable_id_variant(stock)
    if has_recovery and has_stock:
        return MODE_STOCK_AND_RECOVERY
    if has_recovery:
        return MODE_RECOVERY_ONLY
    if has_stock:
        return MODE_STOCK_ONLY
    return MODE_UNRESOLVED


static func validate_production_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := validate_dictionary(data)
    var role_id := StringName(String(data.get("role_id", &"")))
    if not PRODUCTION_MODE_BY_ROLE.has(role_id):
        return errors
    if typeof(data.get("combat_restricted", null)) == TYPE_BOOL and not bool(data.get("combat_restricted", false)):
        errors.append("Region 3 recovery/consumable services must remain restricted during Active Combat")
    var expected_mode := StringName(PRODUCTION_MODE_BY_ROLE[role_id])
    var authored_mode := service_mode(data)
    if authored_mode != expected_mode:
        errors.append("production %s service mode must be %s" % [String(role_id), String(expected_mode)])
    if role_id == ROLE_INN_REST_HOUSE:
        var save_event: Variant = data.get("save_event_id", null)
        if not _is_stable_id_variant(save_event):
            errors.append("production Inn / Rest House requires an authored save_event_id")
    return errors


static func production_readiness(data: Dictionary) -> Dictionary:
    var role_id := StringName(String(data.get("role_id", &"")))
    return production_readiness_for_role(role_id, data)


static func production_readiness_for_role(role_id: StringName, data: Dictionary = {}) -> Dictionary:
    if not PRODUCTION_MODE_BY_ROLE.has(role_id):
        return {
            "available": false,
            "reason_id": &"content_unavailable",
            "role_id": role_id,
            "expected_structure_id": &"",
            "service_id": StringName(String(data.get("service_id", &""))),
            "service_mode": service_mode(data),
            "expected_mode": MODE_UNRESOLVED,
            "missing_fields": PackedStringArray(["role_id"]),
            "validation_errors": PackedStringArray(["role_id must identify an authored Region 3 recovery-service role"]),
        }

    var missing := _missing_production_fields(role_id, data)
    var errors := PackedStringArray()
    if data.is_empty():
        errors.append("production service definition is not assigned")
    else:
        errors = validate_production_dictionary(data)

    var available := (
        missing.is_empty()
        and errors.is_empty()
        and bool(data.get("available", false))
    )
    return {
        "available": available,
        "reason_id": &"" if available else &"content_unavailable",
        "role_id": role_id,
        "expected_structure_id": StringName(STRUCTURE_BY_ROLE[role_id]),
        "service_id": StringName(String(data.get("service_id", &""))),
        "service_mode": service_mode(data),
        "expected_mode": StringName(PRODUCTION_MODE_BY_ROLE[role_id]),
        "missing_fields": missing.duplicate(),
        "validation_errors": errors.duplicate(),
    }


static func _missing_production_fields(role_id: StringName, data: Dictionary) -> PackedStringArray:
    var missing := PackedStringArray()
    if not _is_stable_id_variant(data.get("service_id", null)):
        missing.append("service_id")
    if not _is_stable_id_variant(data.get("structure_id", null)):
        missing.append("structure_id")
    if StringName(String(data.get("role_id", &""))) != role_id:
        missing.append("role_id")
    if typeof(data.get("available", null)) != TYPE_BOOL:
        missing.append("available")
    if typeof(data.get("combat_restricted", null)) != TYPE_BOOL:
        missing.append("combat_restricted")
    if not data.has("price_gold"):
        missing.append("price_gold")
    if not data.has("recovery_amounts"):
        missing.append("recovery_amounts")
    if not data.has("stock_reference_id"):
        missing.append("stock_reference_id")
    if not data.has("save_event_id"):
        missing.append("save_event_id")

    var recovery: Variant = data.get("recovery_amounts", null)
    var has_recovery := recovery is Dictionary and not (recovery as Dictionary).is_empty()
    if role_id in [ROLE_INN_REST_HOUSE, ROLE_CLINIC_APOTHECARY] and not has_recovery and not missing.has("recovery_amounts"):
        missing.append("recovery_amounts")

    var stock_reference: Variant = data.get("stock_reference_id", null)
    var has_stock := stock_reference != null and _is_stable_id_variant(stock_reference)
    if role_id == ROLE_CLINIC_APOTHECARY and not has_stock and not missing.has("stock_reference_id"):
        missing.append("stock_reference_id")

    var save_event: Variant = data.get("save_event_id", null)
    if role_id == ROLE_INN_REST_HOUSE and not _is_stable_id_variant(save_event) and not missing.has("save_event_id"):
        missing.append("save_event_id")
    return missing


static func _validate_recovery_amounts(recovery: Dictionary, errors: PackedStringArray) -> void:
    for raw_key: Variant in recovery.keys():
        var resource_id := String(raw_key)
        if not StableId.is_valid(resource_id):
            errors.append("recovery_amounts keys must be stable resource IDs")
            continue
        var amount: Variant = recovery[raw_key]
        if typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT:
            errors.append("recovery_amounts values must be finite non-negative numbers")
            continue
        var number := float(amount)
        if not is_finite(number) or number < 0.0:
            errors.append("recovery_amounts values must be finite non-negative numbers")


static func _require_stable_id(data: Dictionary, key: String, errors: PackedStringArray) -> void:
    if not _is_stable_id_variant(data.get(key, null)):
        errors.append("%s must be a stable ID" % key)


static func _is_stable_id_variant(value: Variant) -> bool:
    return (
        (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME)
        and StableId.is_valid(String(value))
    )
