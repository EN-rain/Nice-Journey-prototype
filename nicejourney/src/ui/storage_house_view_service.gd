class_name StorageHouseViewService
extends RefCounted


static func build_view(profile: ProfileSnapshot) -> Dictionary:
    if profile == null:
        return {"accepted": false, "reason_id": &"profile_missing"}

    var inventory := InventoryState.new()
    if not profile.item_state.is_empty() and not inventory.load_dictionary(profile.item_state).is_empty():
        return {"accepted": false, "reason_id": &"inventory_state_invalid"}

    var storage := StorageState.new()
    if not profile.storage_state.is_empty() and not storage.load_dictionary(profile.storage_state).is_empty():
        return {"accepted": false, "reason_id": &"storage_state_invalid"}

    var inventory_entries: Array[Dictionary] = []
    for slot: Dictionary in inventory.normal_slots:
        inventory_entries.append(_item_entry(slot))
    var storage_entries: Array[Dictionary] = []
    for slot: Dictionary in storage.normal_slots:
        storage_entries.append(_item_entry(slot))
    _sort_entries(inventory_entries)
    _sort_entries(storage_entries)

    return {
        "accepted": true,
        "inventory_capacity": NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY,
        "inventory_occupied": inventory.normal_slots.size(),
        "storage_capacity": storage.capacity,
        "storage_occupied": storage.normal_slots.size(),
        "inventory_entries": inventory_entries,
        "storage_entries": storage_entries,
        "transfer_mode": &"full_stack_only",
        "durability_boundary": &"next_safe_snapshot",
    }


static func _item_entry(item: Dictionary) -> Dictionary:
    return {
        "item_instance_id": StringName(String(item.get("item_instance_id", &""))),
        "definition_id": StringName(String(item.get("definition_id", &""))),
        "quantity": int(item.get("quantity", 1)),
        "stackable": bool(item.get("stackable", false)),
        "rarity_available": item.has("rarity"),
        "rarity": StringName(String(item.get("rarity", &""))) if item.has("rarity") else &"",
        "affixes_available": item.has("affixes"),
        "affixes": (item.get("affixes", []) as Array).duplicate(),
        "upgrade_rank_available": item.has("upgrade_rank"),
        "upgrade_rank": int(item.get("upgrade_rank", 0)),
        "source_claim_id_available": item.has("source_claim_id") and not String(item.get("source_claim_id", "")).is_empty(),
        "source_claim_id": StringName(String(item.get("source_claim_id", &""))),
    }


static func _sort_entries(entries: Array[Dictionary]) -> void:
    entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var definition_a := String(a.get("definition_id", &""))
        var definition_b := String(b.get("definition_id", &""))
        if definition_a != definition_b:
            return definition_a.naturalnocasecmp_to(definition_b) < 0
        return String(a.get("item_instance_id", &"")).naturalnocasecmp_to(String(b.get("item_instance_id", &""))) < 0
    )
