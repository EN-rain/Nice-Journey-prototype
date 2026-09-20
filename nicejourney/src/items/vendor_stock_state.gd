class_name VendorStockState
extends RefCounted

const MAX_STOCK_NUMBER: int = 2147483647

var vendor_id: StringName = &""
var stock: Dictionary = {}


func configure(new_vendor_id: StringName, authored_stock: Dictionary) -> bool:
    var candidate := {
        "vendor_id": new_vendor_id,
        "stock": authored_stock.duplicate(true),
    }
    if not _validate_live_dictionary(candidate).is_empty():
        return false
    vendor_id = new_vendor_id
    stock = authored_stock.duplicate(true)
    return true


func get_entry(definition_id: StringName) -> Dictionary:
    var raw: Variant = stock.get(String(definition_id), null)
    if not raw is Dictionary:
        return {}
    return (raw as Dictionary).duplicate(true)


func adjust_quantity(definition_id: StringName, delta: int) -> bool:
    if not stock.has(String(definition_id)):
        return false
    var entry: Dictionary = (stock[String(definition_id)] as Dictionary).duplicate(true)
    var current: int = int(entry["quantity"])
    if delta < 0 and -delta > current:
        return false
    var next: int = current + delta
    if next < 0 or next > MAX_STOCK_NUMBER:
        return false
    entry["quantity"] = next
    stock[String(definition_id)] = entry
    return true


func to_dictionary() -> Dictionary:
    return {
        "vendor_id": String(vendor_id),
        "stock": stock.duplicate(true),
    }


func load_dictionary(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = validate_dictionary(data)
    if not errors.is_empty():
        return errors
    vendor_id = StringName(String(data["vendor_id"]))
    stock = _normalize_persisted_stock(data["stock"] as Dictionary)
    return errors


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    var raw_vendor: Variant = data.get("vendor_id", null)
    if not (typeof(raw_vendor) == TYPE_STRING or typeof(raw_vendor) == TYPE_STRING_NAME) or not StableId.is_valid(String(raw_vendor)):
        errors.append("vendor_id must be a stable ID")
    if not data.get("stock", null) is Dictionary:
        errors.append("stock must be a dictionary")
        return errors
    for definition_variant: Variant in (data["stock"] as Dictionary).keys():
        var definition_id := String(definition_variant)
        if not StableId.is_valid(definition_id):
            errors.append("stock definition ID must be stable: %s" % definition_id)
            continue
        var raw_entry: Variant = (data["stock"] as Dictionary)[definition_variant]
        if not raw_entry is Dictionary:
            errors.append("stock entry must be a dictionary: %s" % definition_id)
            continue
        var entry: Dictionary = raw_entry as Dictionary
        for key: String in ["buy_price", "sell_price", "quantity"]:
            if not _is_nonnegative_integral(entry.get(key, null)):
                errors.append("%s %s must be a nonnegative integer" % [definition_id, key])
        if typeof(entry.get("stackable", null)) != TYPE_BOOL:
            errors.append("%s stackable must be boolean" % definition_id)
        if _is_nonnegative_integral(entry.get("buy_price", null)) and _is_nonnegative_integral(entry.get("sell_price", null)):
            if int(entry["sell_price"]) > int(entry["buy_price"]):
                errors.append("%s sell_price cannot exceed buy_price" % definition_id)
    return errors


static func _validate_live_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := validate_dictionary(data)
    if not errors.is_empty() or not data.get("stock", null) is Dictionary:
        return errors
    for raw_entry: Variant in (data["stock"] as Dictionary).values():
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        for key: String in ["buy_price", "sell_price", "quantity"]:
            if typeof(entry.get(key, null)) != TYPE_INT:
                errors.append("live authored %s must be TYPE_INT" % key)
    return errors


static func _normalize_persisted_stock(source: Dictionary) -> Dictionary:
    var result := source.duplicate(true)
    for raw_key: Variant in result.keys():
        var raw_entry: Variant = result[raw_key]
        if not raw_entry is Dictionary:
            continue
        var entry := (raw_entry as Dictionary).duplicate(true)
        for key: String in ["buy_price", "sell_price", "quantity"]:
            if _is_nonnegative_integral(entry.get(key, null)):
                entry[key] = int(entry[key])
        result[raw_key] = entry
    return result


static func _is_nonnegative_integral(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return int(value) >= 0 and int(value) <= MAX_STOCK_NUMBER
    if typeof(value) != TYPE_FLOAT:
        return false
    var number := float(value)
    return is_finite(number) and number >= 0.0 and number <= float(MAX_STOCK_NUMBER) and number == floor(number)
