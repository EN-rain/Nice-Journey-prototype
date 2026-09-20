extends SceneTree

const VIEW_SERVICE: Script = preload("res://src/ui/inventory_view_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Inventory View", "melee")
    _expect(profile != null, "inventory view fixture profile creates")
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "starter inventory state loads for view fixture")
    _expect(bool(inventory.try_add_normal(&"item:potion_stack", &"potion_basic", 5, true).get("accepted", false)), "view fixture owns a stackable normal item")
    _expect(bool(inventory.try_add_normal(
        &"item:rare_blade",
        &"iron_blade",
        1,
        false,
        {"rarity": "rare", "affixes": ["sharp"], "upgrade_rank": 2, "source_claim_id": "reward:test_inventory"}
    ).get("accepted", false)), "view fixture owns a metadata-bearing normal item")
    _expect(inventory.bind_quick_slot(0, &"item:potion_stack"), "view fixture binds a real consumable quick reference")
    _expect(inventory.grant_protected(InventoryState.TOWER_SIGIL_ID, true), "view fixture owns protected Tower Sigil")
    _expect(inventory.add_gold(37), "view fixture owns Gold")
    profile.item_state = inventory.to_dictionary()
    var category_catalog := ItemCategoryCatalog.new()
    category_catalog.definition_categories = {
        "potion_basic": ItemCategoryCatalog.CATEGORY_CONSUMABLE,
        "iron_blade": ItemCategoryCatalog.CATEGORY_WEAPON,
    }
    _expect(category_catalog.validate_catalog().is_empty(), "inventory view category fixture validates")

    var before := profile.to_dictionary()
    var view: Dictionary = VIEW_SERVICE.build_view(profile, "", VIEW_SERVICE.SORT_DEFINITION, category_catalog)
    _expect(bool(view.get("accepted", false)), "inventory view accepts valid persisted state")
    _expect(bool(view.get("inventory_state_available", false)) and bool(view.get("equipment_state_available", false)), "inventory view reports both persisted owners available")
    _expect(int(view.get("capacity", 0)) == 16 and (view.get("grid_slots", []) as Array).size() == 16, "inventory view always exposes exactly the locked 16 normal slots")
    _expect(int(view.get("occupied_normal_slots", -1)) == 2 and int(view.get("gold", -1)) == 37, "inventory view preserves exact normal-slot occupancy and Gold")
    _expect((view.get("equipment_slots", []) as Array).size() == 5, "inventory view exposes exactly five equipment slots")
    _expect(_equipment_definition(view, &"weapon") == &"starter_sword", "inventory view exposes the locked Melee starter sword from persistent equipment ownership")
    _expect(_equipment_definition(view, &"off_hand") == &"starter_shield", "inventory view exposes the locked Melee starter shield from persistent equipment ownership")
    _expect((view.get("protected_items", []) as Array).size() == 1 and StringName(((view.get("protected_items", []) as Array)[0] as Dictionary).get("item_id", &"")) == InventoryState.TOWER_SIGIL_ID, "inventory view keeps protected quest/key items outside normal capacity")
    _expect(StringName(((view.get("quick_slots", []) as Array)[0] as Dictionary).get("item_instance_id", &"")) == &"item:potion_stack", "inventory view exposes exact consumable quick-slot reference")
    _expect(bool(((view.get("quick_slots", []) as Array)[0] as Dictionary).get("consumable_category_validated", false)), "inventory view marks authored consumable quick reference as category-validated")
    _expect(bool(_grid_item(view, &"item:potion_stack").get("quick_slot_eligible", false)), "inventory view exposes authored consumable as quick-slot eligible")
    _expect(not bool(_grid_item(view, &"item:rare_blade").get("quick_slot_eligible", true)), "inventory view keeps authored weapon ineligible for consumable quick slots")
    _expect(not bool(view.get("mutation_actions_available", true)) and bool(view.get("sort_is_presentation_only", false)), "inventory view exposes no ownership mutation actions and marks sorting presentation-only")

    var quantity_sorted: Dictionary = VIEW_SERVICE.build_view(profile, "", VIEW_SERVICE.SORT_QUANTITY_DESC)
    var first_sorted := (quantity_sorted.get("grid_slots", []) as Array)[0] as Dictionary
    _expect(StringName(first_sorted.get("item_instance_id", &"")) == &"item:potion_stack" and int(first_sorted.get("quantity", 0)) == 5, "quantity sort changes only presentation order")

    var search_view: Dictionary = VIEW_SERVICE.build_view(profile, "sharp", VIEW_SERVICE.SORT_DEFINITION)
    _expect(int(search_view.get("matching_item_count", -1)) == 1, "inventory search matches persisted affix IDs without inventing display metadata")
    var search_first := (search_view.get("grid_slots", []) as Array)[0] as Dictionary
    _expect(StringName(search_first.get("item_instance_id", &"")) == &"item:rare_blade", "inventory search returns the matching persisted item")
    _expect(bool(search_first.get("rarity_available", false)) and StringName(search_first.get("rarity", &"")) == &"rare", "inventory view distinguishes persisted rarity metadata from unavailable metadata")
    _expect(bool(search_first.get("upgrade_rank_available", false)) and int(search_first.get("upgrade_rank", -1)) == 2, "inventory view preserves exact persisted upgrade rank")

    var starter_weapon := _equipment_item(view, &"weapon")
    _expect(not bool(starter_weapon.get("rarity_available", true)) and not bool(starter_weapon.get("affixes_available", true)) and not bool(starter_weapon.get("upgrade_rank_available", true)), "starter gear does not fabricate rarity, affix, or upgrade metadata")
    _expect(profile.to_dictionary() == before, "search and sort mutate no profile ownership or metadata")

    var invalid_sort: Dictionary = VIEW_SERVICE.build_view(profile, "", &"unsupported_sort")
    _expect(not bool(invalid_sort.get("accepted", true)) and StringName(invalid_sort.get("reason_id", &"")) == &"invalid_sort_mode", "inventory view fails closed on unsupported sort modes")

    var legacy := ProfileCreationService.create_profile(2, "Legacy Inventory", "ranged")
    legacy.item_state = {}
    legacy.equipment_state = {}
    var legacy_view: Dictionary = VIEW_SERVICE.build_view(legacy)
    _expect(bool(legacy_view.get("accepted", false)) and not bool(legacy_view.get("inventory_state_available", true)) and not bool(legacy_view.get("equipment_state_available", true)), "legacy empty item/equipment ownership remains readable without fabricated state")
    _expect((legacy_view.get("grid_slots", []) as Array).size() == 16 and int(legacy_view.get("occupied_normal_slots", -1)) == 0, "legacy view still exposes an honest empty 16-slot presentation")

    var legacy_quick_view: Dictionary = VIEW_SERVICE.build_view(profile)
    _expect(bool(legacy_quick_view.get("accepted", false)), "inventory view remains load-compatible when no category authority is supplied")
    _expect(bool(((legacy_quick_view.get("quick_slots", []) as Array)[0] as Dictionary).get("legacy_unvalidated_reference", false)), "existing quick reference is surfaced as legacy/unvalidated rather than silently reclassified")
    _expect(not bool(_grid_item(legacy_quick_view, &"item:potion_stack").get("quick_slot_eligible", true)), "without category authority the view fails closed for new quick binding")

    if _failures == 0:
        print("INVENTORY VIEW SERVICE TEST PASS")
    else:
        push_error("INVENTORY VIEW SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _equipment_definition(view: Dictionary, slot_id: StringName) -> StringName:
    var item := _equipment_item(view, slot_id)
    return StringName(String(item.get("definition_id", &"")))


func _equipment_item(view: Dictionary, slot_id: StringName) -> Dictionary:
    for raw_entry: Variant in view.get("equipment_slots", []) as Array:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        if StringName(String(entry.get("slot_id", &""))) == slot_id:
            return (entry.get("item", {}) as Dictionary).duplicate(true)
    return {}


func _grid_item(view: Dictionary, item_instance_id: StringName) -> Dictionary:
    for raw_entry: Variant in view.get("grid_slots", []) as Array:
        if raw_entry is Dictionary and StringName(String((raw_entry as Dictionary).get("item_instance_id", &""))) == item_instance_id:
            return (raw_entry as Dictionary).duplicate(true)
    return {}


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
