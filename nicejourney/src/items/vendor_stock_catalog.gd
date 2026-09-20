class_name VendorStockCatalog
extends Resource

const REGION3_GENERAL_MERCHANT_VENDOR_ID: StringName = &"vendor:general_merchant"
const REASON_CONTENT_UNAVAILABLE: StringName = &"content_unavailable"

@export var definitions: Array[VendorStockDefinition] = []


func validate_catalog(require_general_merchant: bool = false, require_authored_fields: bool = false) -> PackedStringArray:
    var errors := PackedStringArray()
    var seen: Dictionary = {}
    var lowest_buy: Dictionary = {}
    var highest_sell: Dictionary = {}
    for index: int in range(definitions.size()):
        var definition: VendorStockDefinition = definitions[index]
        if definition == null:
            errors.append("vendor %d must be a VendorStockDefinition" % index)
            continue
        var definition_errors := (
            definition.validate_authored_definition()
            if require_authored_fields
            else definition.validate_definition()
        )
        for definition_error: String in definition_errors:
            errors.append("vendor %d: %s" % [index, definition_error])
        if StableId.is_valid(String(definition.vendor_id)):
            if seen.has(definition.vendor_id):
                errors.append("vendor_id must be unique: %s" % String(definition.vendor_id))
            seen[definition.vendor_id] = true
        # A buy/sell cycle can cross vendors even when each individual
        # vendor's sell_price does not exceed its own buy_price.
        if definition_errors.is_empty():
            for raw_item_id: Variant in definition.stock.keys():
                var item_id := StringName(String(raw_item_id))
                var entry := definition.stock[raw_item_id] as Dictionary
                var buy_price := int(entry["buy_price"])
                var sell_price := int(entry["sell_price"])
                if not lowest_buy.has(item_id) or buy_price < int(lowest_buy[item_id]):
                    lowest_buy[item_id] = buy_price
                if not highest_sell.has(item_id) or sell_price > int(highest_sell[item_id]):
                    highest_sell[item_id] = sell_price
    for item_id: StringName in lowest_buy.keys():
        if int(highest_sell[item_id]) > int(lowest_buy[item_id]):
            errors.append("cross-vendor buy/sell profit loop for %s" % String(item_id))
    if require_general_merchant and _find_definition_unchecked(REGION3_GENERAL_MERCHANT_VENDOR_ID) == null:
        errors.append("General Merchant stock definition is not authored")
    return errors


func general_merchant_readiness(
    category_catalog: ItemCategoryCatalog = null,
    require_category_authority: bool = false
) -> Dictionary:
    return vendor_readiness(REGION3_GENERAL_MERCHANT_VENDOR_ID, category_catalog, require_category_authority)


func vendor_readiness(
    vendor_id: StringName,
    category_catalog: ItemCategoryCatalog = null,
    require_category_authority: bool = false
) -> Dictionary:
    if not StableId.is_valid(String(vendor_id)):
        return {
            "available": false,
            "reason_id": REASON_CONTENT_UNAVAILABLE,
            "vendor_id": vendor_id,
            "missing_fields": PackedStringArray(["vendor_id"]),
        }
    var definition: VendorStockDefinition = _find_definition_unchecked(vendor_id)
    if definition == null:
        var missing_fields := PackedStringArray([
            "stock_manifest",
            "buy_prices",
            "sell_prices",
            "quantities",
            "stackability",
            "restock_rule_id",
            "restock_policy",
            "availability_conditions",
        ])
        if require_category_authority:
            missing_fields.append("item_category_catalog")
        return {
            "available": false,
            "reason_id": REASON_CONTENT_UNAVAILABLE,
            "vendor_id": vendor_id,
            "missing_fields": missing_fields,
        }
    var errors := PackedStringArray()
    for catalog_error: String in validate_catalog(false, false):
        errors.append(catalog_error)
    for authored_error: String in definition.validate_authored_definition():
        errors.append(authored_error)
    if require_category_authority:
        if category_catalog == null:
            errors.append("item category catalog is required for production vendor content")
        else:
            for category_error: String in category_catalog.validate_vendor_stock_definition(definition):
                errors.append(category_error)
    if not errors.is_empty():
        return {
            "available": false,
            "reason_id": REASON_CONTENT_UNAVAILABLE,
            "vendor_id": vendor_id,
            "missing_fields": definition.unauthored_fields(),
            "validation_errors": errors,
        }
    return {
        "available": true,
        "reason_id": &"",
        "vendor_id": vendor_id,
        "missing_fields": PackedStringArray(),
        "restock_rule_id": definition.restock_rule_id,
        "restock_policy": definition.restock_policy,
        "restock_event_id": definition.restock_event_id,
        "availability_condition_ids": definition.availability_condition_ids.duplicate(),
    }


func get_definition(vendor_id: StringName) -> VendorStockDefinition:
    if not StableId.is_valid(String(vendor_id)) or not validate_catalog(false).is_empty():
        return null
    return _find_definition_unchecked(vendor_id)


func instantiate_vendor(vendor_id: StringName) -> VendorStockState:
    var definition: VendorStockDefinition = get_definition(vendor_id)
    if definition == null:
        return null
    return definition.instantiate_state()


func has_authored_vendor(vendor_id: StringName) -> bool:
    return get_definition(vendor_id) != null


func build_vendor_state(vendor_id: StringName) -> VendorStockState:
    return instantiate_vendor(vendor_id)


func _find_definition_unchecked(vendor_id: StringName) -> VendorStockDefinition:
    for definition: VendorStockDefinition in definitions:
        if definition != null and definition.vendor_id == vendor_id:
            return definition
    return null
