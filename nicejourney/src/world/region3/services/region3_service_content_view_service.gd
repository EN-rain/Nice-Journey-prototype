class_name Region3ServiceContentViewService
extends RefCounted

const TRAINING_DEFINITION_SCRIPT: Script = preload("res://src/world/region3/services/region3_training_service_definition.gd")
const RECOVERY_DEFINITION_SCRIPT: Script = preload("res://src/world/region3/services/region3_recovery_service_definition.gd")


static func build_training_view(
    definition: Dictionary,
    instruction_content_resolved: bool = false,
    practice_interaction_resolved: bool = false
) -> Dictionary:
    return TRAINING_DEFINITION_SCRIPT.readiness_view(
        definition,
        instruction_content_resolved,
        practice_interaction_resolved
    )


static func build_recovery_view(
    definition: Dictionary,
    economy_state: EconomyState = null,
    category_catalog: ItemCategoryCatalog = null,
    interaction_content_resolved: bool = false,
    save_feedback_resolved: bool = false,
    recovery_commit_owner_resolved: bool = false
) -> Dictionary:
    var validation_errors: PackedStringArray = RECOVERY_DEFINITION_SCRIPT.validate_dictionary(definition)
    var role_id: StringName = StringName(String(definition.get("role_id", &"")))
    var recovery: Variant = definition.get("recovery_amounts", null)
    var recovery_authored: bool = recovery is Dictionary and not (recovery as Dictionary).is_empty()
    var stock_reference: Variant = definition.get("stock_reference_id", null)
    var stock_reference_id: StringName = StringName(String(stock_reference)) if stock_reference != null else &""
    var stock_reference_authored: bool = stock_reference_id != &"" and StableId.is_valid(String(stock_reference_id))
    var save_event: Variant = definition.get("save_event_id", null)
    var save_event_authored: bool = save_event != null and StableId.is_valid(String(save_event))

    var consumable_stock: Dictionary = _resolve_consumable_stock(stock_reference_id, economy_state, category_catalog)
    var blockers: Array[StringName] = []
    if not validation_errors.is_empty():
        blockers.append(&"definition_invalid")
    if not bool(definition.get("available", false)):
        blockers.append(&"service_unavailable")
    if not interaction_content_resolved:
        blockers.append(&"interaction_content_unresolved")

    if role_id == StringName(RECOVERY_DEFINITION_SCRIPT.ROLE_INN_REST_HOUSE):
        if not recovery_authored:
            blockers.append(&"inn_recovery_unauthored")
        elif not recovery_commit_owner_resolved:
            blockers.append(&"inn_recovery_commit_owner_unresolved")
        if not save_event_authored:
            blockers.append(&"inn_save_event_unauthored")
        if not save_feedback_resolved:
            blockers.append(&"inn_save_feedback_unresolved")
    elif role_id == StringName(RECOVERY_DEFINITION_SCRIPT.ROLE_CLINIC_APOTHECARY):
        var healing_ready: bool = recovery_authored and recovery_commit_owner_resolved
        var consumable_ready: bool = bool(consumable_stock.get("ready", false))
        if recovery_authored and not recovery_commit_owner_resolved:
            blockers.append(&"clinic_recovery_commit_owner_unresolved")
        if stock_reference_authored and not consumable_ready:
            blockers.append(StringName(consumable_stock.get("reason_id", &"clinic_consumable_stock_unresolved")))
        if not healing_ready and not consumable_ready:
            if not recovery_authored:
                blockers.append(&"clinic_healing_unauthored")
            if not stock_reference_authored:
                blockers.append(&"clinic_stock_reference_unauthored")
            blockers.append(&"clinic_service_output_unresolved")

    return {
        "accepted": validation_errors.is_empty(),
        "service_id": StringName(String(definition.get("service_id", &""))),
        "structure_id": StringName(String(definition.get("structure_id", &""))),
        "role_id": role_id,
        "validation_errors": validation_errors.duplicate(),
        "interaction_content_resolved": interaction_content_resolved,
        "recovery_authored": recovery_authored,
        "recovery_commit_owner_resolved": recovery_commit_owner_resolved,
        "price_authored": definition.get("price_gold", null) != null,
        "stock_reference_authored": stock_reference_authored,
        "stock_reference_id": stock_reference_id,
        "consumable_stock_ready": bool(consumable_stock.get("ready", false)),
        "consumable_stock_reason_id": StringName(consumable_stock.get("reason_id", &"")),
        "save_event_authored": save_event_authored,
        "save_feedback_resolved": save_feedback_resolved,
        "content_ready": blockers.is_empty(),
        "blockers": blockers.duplicate(),
    }


static func _resolve_consumable_stock(
    stock_reference_id: StringName,
    economy_state: EconomyState,
    category_catalog: ItemCategoryCatalog
) -> Dictionary:
    if stock_reference_id == &"":
        return {"ready": false, "reason_id": &"clinic_stock_reference_unauthored"}
    if economy_state == null:
        return {"ready": false, "reason_id": &"clinic_economy_authority_missing"}
    var vendor: VendorStockState = economy_state.get_vendor(stock_reference_id)
    if vendor == null:
        return {"ready": false, "reason_id": &"clinic_stock_state_missing"}
    if category_catalog == null:
        return {"ready": false, "reason_id": &"clinic_category_authority_missing"}
    if not category_catalog.validate_catalog().is_empty():
        return {"ready": false, "reason_id": &"clinic_category_authority_invalid"}
    if vendor.stock.is_empty():
        return {"ready": false, "reason_id": &"clinic_consumable_stock_empty"}

    var has_consumable: bool = false
    for raw_definition_id: Variant in vendor.stock.keys():
        var definition_id: StringName = StringName(String(raw_definition_id))
        var category: StringName = category_catalog.category_for(definition_id)
        if category == &"":
            return {"ready": false, "reason_id": &"clinic_stock_item_category_unauthored"}
        if category != ItemCategoryCatalog.CATEGORY_CONSUMABLE:
            return {"ready": false, "reason_id": &"clinic_stock_contains_non_consumable"}
        has_consumable = true
    return {
        "ready": has_consumable,
        "reason_id": &"" if has_consumable else &"clinic_consumable_stock_empty",
    }
