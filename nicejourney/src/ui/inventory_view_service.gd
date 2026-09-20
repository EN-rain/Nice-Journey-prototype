class_name InventoryViewService
extends RefCounted

const SORT_DEFINITION: StringName = &"definition"
const SORT_QUANTITY_DESC: StringName = &"quantity_desc"

static func build_view(
    profile: ProfileSnapshot,
    search_text: String = "",
    sort_mode: StringName = SORT_DEFINITION,
    category_catalog: ItemCategoryCatalog = null
) -> Dictionary:
    if profile == null:
        return {"accepted": false, "reason_id": &"profile_missing"}
    if sort_mode != SORT_DEFINITION and sort_mode != SORT_QUANTITY_DESC:
        return {"accepted": false, "reason_id": &"invalid_sort_mode"}
    if category_catalog != null and not category_catalog.validate_catalog().is_empty():
        return {"accepted": false, "reason_id": &"item_category_catalog_invalid"}

    var inventory_available := not profile.item_state.is_empty()
    var equipment_available := not profile.equipment_state.is_empty()
    var inventory := InventoryState.new()
    var equipment := EquipmentState.new()
    if inventory_available and not inventory.load_dictionary(profile.item_state).is_empty():
        return {"accepted": false, "reason_id": &"inventory_state_invalid"}
    if equipment_available and not equipment.load_dictionary(profile.equipment_state).is_empty():
        return {"accepted": false, "reason_id": &"equipment_state_invalid"}

    var normal_entries: Array[Dictionary] = []
    if inventory_available:
        for slot: Dictionary in inventory.normal_slots:
            normal_entries.append(_item_entry(slot, category_catalog))
    _sort_entries(normal_entries, sort_mode)

    var query := search_text.strip_edges().to_lower()
    var visible_entries: Array[Dictionary] = []
    for entry: Dictionary in normal_entries:
        if query.is_empty() or _matches(entry, query):
            visible_entries.append(entry)

    var grid_slots: Array[Dictionary] = []
    for index: int in range(NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY):
        if index < visible_entries.size():
            var occupied := visible_entries[index].duplicate(true)
            occupied["occupied"] = true
            occupied["view_slot_index"] = index
            grid_slots.append(occupied)
        else:
            grid_slots.append({"occupied": false, "view_slot_index": index})

    var equipment_entries: Array[Dictionary] = []
    for slot_id: StringName in EquipmentSlotIdentityValidator.REQUIRED_SLOT_IDS:
        var item: Dictionary = equipment.get_item(slot_id) if equipment_available else {}
        equipment_entries.append({
            "slot_id": slot_id,
            "occupied": not item.is_empty(),
            "item": _item_entry(item, category_catalog) if not item.is_empty() else {},
        })

    var protected_entries: Array[Dictionary] = []
    if inventory_available:
        var protected_ids: Array = inventory.protected_items.keys()
        protected_ids.sort()
        for raw_id: Variant in protected_ids:
            var item_id := StringName(String(raw_id))
            var raw_state := inventory.protected_items[String(item_id)] as Dictionary
            protected_entries.append({
                "item_id": item_id,
                "protected_quest_key": bool(raw_state.get("protected_quest_key", false)),
                "tower_sigil": bool(raw_state.get("tower_sigil", false)),
            })

    var quick_entries: Array[Dictionary] = []
    for index: int in range(InventoryState.QUICK_SLOT_COUNT):
        var reference: StringName = inventory.quick_slots[index] if inventory_available else &""
        var definition_id := &""
        if reference != &"" and inventory_available:
            definition_id = StringName(String(inventory.get_normal_slot(reference).get("definition_id", &"")))
        var category := category_catalog.category_for(definition_id) if category_catalog != null and definition_id != &"" else &""
        quick_entries.append({
            "slot_index": index,
            "item_instance_id": reference,
            "definition_id": definition_id,
            "item_category": category,
            "consumable_category_validated": reference == &"" or category == ItemCategoryCatalog.CATEGORY_CONSUMABLE,
            "legacy_unvalidated_reference": reference != &"" and category == &"",
        })

    return {
        "accepted": true,
        "inventory_state_available": inventory_available,
        "equipment_state_available": equipment_available,
        "gold": inventory.gold if inventory_available else 0,
        "capacity": NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY,
        "occupied_normal_slots": normal_entries.size(),
        "search_text": search_text,
        "sort_mode": sort_mode,
        "matching_item_count": visible_entries.size(),
        "grid_slots": grid_slots,
        "equipment_slots": equipment_entries,
        "protected_items": protected_entries,
        "quick_slots": quick_entries,
        "item_category_authority_available": category_catalog != null,
        "mutation_actions_available": false,
        "sort_is_presentation_only": true,
    }


static func _item_entry(item: Dictionary, category_catalog: ItemCategoryCatalog = null) -> Dictionary:
    if item.is_empty():
        return {}
    var definition_id := StringName(String(item.get("definition_id", &"")))
    var category := category_catalog.category_for(definition_id) if category_catalog != null else &""
    return {
        "item_instance_id": StringName(String(item.get("item_instance_id", &""))),
        "definition_id": definition_id,
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
        "item_category_authored": category != &"",
        "item_category": category,
        "quick_slot_eligible": category == ItemCategoryCatalog.CATEGORY_CONSUMABLE,
    }


static func _sort_entries(entries: Array[Dictionary], sort_mode: StringName) -> void:
    if sort_mode == SORT_QUANTITY_DESC:
        entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            var qa := int(a.get("quantity", 0))
            var qb := int(b.get("quantity", 0))
            if qa != qb:
                return qa > qb
            return String(a.get("definition_id", &"")).naturalnocasecmp_to(String(b.get("definition_id", &""))) < 0
        )
        return
    entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var da := String(a.get("definition_id", &""))
        var db := String(b.get("definition_id", &""))
        if da != db:
            return da.naturalnocasecmp_to(db) < 0
        return String(a.get("item_instance_id", &"")).naturalnocasecmp_to(String(b.get("item_instance_id", &""))) < 0
    )


static func _matches(entry: Dictionary, query: String) -> bool:
    if String(entry.get("definition_id", &"")).to_lower().contains(query):
        return true
    if String(entry.get("item_instance_id", &"")).to_lower().contains(query):
        return true
    if String(entry.get("rarity", &"")).to_lower().contains(query):
        return true
    for raw_affix: Variant in entry.get("affixes", []) as Array:
        if String(raw_affix).to_lower().contains(query):
            return true
    return false
