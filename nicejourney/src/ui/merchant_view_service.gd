class_name MerchantViewService
extends RefCounted

const REASON_PROFILE_MISSING: StringName = &"profile_missing"
const REASON_INVALID_VENDOR_ID: StringName = &"invalid_vendor_id"
const REASON_INVENTORY_STATE_INVALID: StringName = &"inventory_state_invalid"
const REASON_ECONOMY_STATE_INVALID: StringName = &"economy_state_invalid"
const REASON_VENDOR_NOT_FOUND: StringName = &"vendor_not_found"


static func build_view(profile: ProfileSnapshot, vendor_id: StringName) -> Dictionary:
    if profile == null:
        return _reject(REASON_PROFILE_MISSING)
    if not StableId.is_valid(String(vendor_id)):
        return _reject(REASON_INVALID_VENDOR_ID)
    var inventory := InventoryState.new()
    if not profile.item_state.is_empty() and not inventory.load_dictionary(profile.item_state).is_empty():
        return _reject(REASON_INVENTORY_STATE_INVALID)
    var economy := EconomyState.new()
    if profile.economy_state.is_empty() or not economy.load_dictionary(profile.economy_state).is_empty():
        return _reject(REASON_ECONOMY_STATE_INVALID)
    var vendor := economy.get_vendor(vendor_id)
    if vendor == null:
        return _reject(REASON_VENDOR_NOT_FOUND)

    var stock_entries: Array[Dictionary] = []
    var definition_ids: Array[String] = []
    for raw_id: Variant in vendor.stock.keys():
        definition_ids.append(String(raw_id))
    definition_ids.sort()
    for definition_text: String in definition_ids:
        var definition_id := StringName(definition_text)
        var stock: Dictionary = vendor.get_entry(definition_id)
        stock_entries.append({
            "definition_id": definition_id,
            "buy_price": int(stock.get("buy_price", 0)),
            "sell_price": int(stock.get("sell_price", 0)),
            "quantity": int(stock.get("quantity", 0)),
            "stackable": bool(stock.get("stackable", false)),
            "buy_available": int(stock.get("quantity", 0)) > 0,
        })

    var sell_entries: Array[Dictionary] = []
    for slot: Dictionary in inventory.normal_slots:
        var definition_id := StringName(String(slot.get("definition_id", &"")))
        var stock: Dictionary = vendor.get_entry(definition_id)
        if stock.is_empty() or int(stock.get("sell_price", 0)) <= 0:
            continue
        var entry := _item_entry(slot)
        entry["sell_price"] = int(stock.get("sell_price", 0))
        entry["sell_available"] = true
        sell_entries.append(entry)
    sell_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var da := String(a.get("definition_id", &""))
        var db := String(b.get("definition_id", &""))
        if da != db:
            return da.naturalnocasecmp_to(db) < 0
        return String(a.get("item_instance_id", &"")).naturalnocasecmp_to(String(b.get("item_instance_id", &""))) < 0
    )

    return {
        "accepted": true,
        "vendor_id": vendor_id,
        "gold": inventory.gold,
        "stock_entries": stock_entries,
        "sell_entries": sell_entries,
        "stock_is_persisted_authority": true,
        "prices_are_authored": true,
    }


static func _item_entry(item: Dictionary) -> Dictionary:
    return {
        "item_instance_id": StringName(String(item.get("item_instance_id", &""))),
        "definition_id": StringName(String(item.get("definition_id", &""))),
        "quantity": int(item.get("quantity", 1)),
        "stackable": bool(item.get("stackable", false)),
        "rarity_available": item.has("rarity"),
        "rarity": StringName(String(item.get("rarity", &""))) if item.has("rarity") else &"",
        "upgrade_rank_available": item.has("upgrade_rank"),
        "upgrade_rank": int(item.get("upgrade_rank", 0)),
    }


static func _reject(reason_id: StringName) -> Dictionary:
    return {"accepted": false, "reason_id": reason_id}
