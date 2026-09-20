extends SceneTree

const TOWN_LAYOUT: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const TRAINING_DEFINITION_SCRIPT: Script = preload("res://src/world/region3/services/region3_training_service_definition.gd")
const SERVICE_CONTENT_VIEW_SCRIPT: Script = preload("res://src/world/region3/services/region3_service_content_view_service.gd")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_authored_service_anchors()
    _test_training_content_boundary()
    _test_inn_content_boundary()
    _test_clinic_consumable_authority_boundary()

    if _failures == 0:
        print("REGION 3 SERVICE CONTENT BOUNDARIES TEST PASS")
    else:
        push_error("REGION 3 SERVICE CONTENT BOUNDARIES TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_authored_service_anchors() -> void:
    var layout := TOWN_LAYOUT.instantiate() as Region3AuthoredTownLayout
    root.add_child(layout)
    for node_name: String in ["InnRestHouse", "TrainingHall", "ClinicApothecary"]:
        var anchor := layout.get_node_or_null(node_name) as Region3TownStructureAnchor
        _expect(anchor != null, "%s authored structure anchor exists" % node_name)
        if anchor != null:
            var interaction := anchor.get_node_or_null("ServiceInteraction") as Region3FunctionalServiceInteraction
            _expect(interaction != null and interaction.validate_authored_binding().is_empty(), "%s exposes a valid generic guarded service interaction" % node_name)
    layout.queue_free()


func _test_training_content_boundary() -> void:
    var missing := _training_definition()
    var missing_view: Dictionary = SERVICE_CONTENT_VIEW_SCRIPT.build_training_view(missing)
    _expect(bool(missing_view.get("accepted", false)), "Training Hall definition can explicitly represent currently unauthored instruction/practice references")
    _expect(not bool(missing_view.get("content_ready", true)), "Training Hall remains fail-closed while instruction and practice content are unauthored")
    _expect(_has_blocker(missing_view, &"instruction_content_unauthored") and _has_blocker(missing_view, &"practice_interaction_unauthored"), "Training Hall readiness reports the exact missing instruction and practice authoring")
    _expect(bool(missing_view.get("skill_surface_resolved", false)) and StringName(missing_view.get("skill_surface_id", &"")) == SkillsMenu.MODAL_ID, "Training Hall reuses the existing SkillsMenu as its exact skill-system surface")

    var declared := _training_definition()
    declared["instruction_content_id"] = &"training_instruction:test"
    declared["practice_interaction_id"] = &"training_practice:test"
    var unresolved: Dictionary = SERVICE_CONTENT_VIEW_SCRIPT.build_training_view(declared, false, false)
    _expect(_has_blocker(unresolved, &"instruction_content_unresolved") and _has_blocker(unresolved, &"practice_interaction_unresolved"), "declaring stable references does not pretend their production content exists")
    var resolved: Dictionary = SERVICE_CONTENT_VIEW_SCRIPT.build_training_view(declared, true, true)
    _expect(bool(resolved.get("content_ready", false)), "Training Hall boundary becomes ready only when both externally owned content references resolve")

    var wrong_surface := declared.duplicate(true)
    wrong_surface["skill_surface_id"] = &"ui:invented_skill_surface"
    _expect(not (TRAINING_DEFINITION_SCRIPT.validate_dictionary(wrong_surface) as PackedStringArray).is_empty(), "Training Hall cannot silently replace the existing SkillsMenu with an invented skill surface")


func _test_inn_content_boundary() -> void:
    var inn := _recovery_definition(
        &"service:test_inn",
        &"r3:functional:05",
        &"inn_rest_house"
    )
    inn["recovery_amounts"] = {"resource:health": 10.0}
    var unresolved: Dictionary = SERVICE_CONTENT_VIEW_SCRIPT.build_recovery_view(inn)
    _expect(not bool(unresolved.get("content_ready", true)), "Inn recovery data alone does not fabricate bed/rest execution or save feedback")
    _expect(_has_blocker(unresolved, &"interaction_content_unresolved"), "Inn reports missing bed/rest interaction content ownership")
    _expect(_has_blocker(unresolved, &"inn_recovery_commit_owner_unresolved"), "Inn reports missing recovery commit ownership")
    _expect(_has_blocker(unresolved, &"inn_save_event_unauthored") and _has_blocker(unresolved, &"inn_save_feedback_unresolved"), "Inn reports missing save-event authoring and feedback ownership independently")

    inn["save_event_id"] = &"save_event:test_inn_rest"
    var resolved: Dictionary = SERVICE_CONTENT_VIEW_SCRIPT.build_recovery_view(inn, null, null, true, true, true)
    _expect(bool(resolved.get("content_ready", false)), "Inn content boundary accepts exact authored recovery plus externally resolved rest/recovery/save owners without choosing amounts or prices")


func _test_clinic_consumable_authority_boundary() -> void:
    var clinic := _recovery_definition(
        &"service:test_clinic",
        &"r3:functional:08",
        &"clinic_apothecary"
    )
    clinic["stock_reference_id"] = &"vendor:test_clinic"
    var no_authority: Dictionary = SERVICE_CONTENT_VIEW_SCRIPT.build_recovery_view(clinic, null, null, true)
    _expect(_has_blocker(no_authority, &"clinic_economy_authority_missing"), "Clinic stable stock reference is not treated as real stock without an EconomyState owner")

    var vendor := VendorStockState.new()
    _expect(vendor.configure(&"vendor:test_clinic", {
        "itemdef:test_tonic": {"buy_price": 4, "sell_price": 2, "quantity": 3, "stackable": true},
    }), "Clinic test fixture creates explicit vendor state")
    var economy := EconomyState.new()
    _expect(economy.set_vendor(vendor), "Clinic test fixture installs vendor state into economy authority")
    var no_categories: Dictionary = SERVICE_CONTENT_VIEW_SCRIPT.build_recovery_view(clinic, economy, null, true)
    _expect(_has_blocker(no_categories, &"clinic_category_authority_missing"), "Clinic stock cannot claim consumable service without item-category authority")

    var categories := ItemCategoryCatalog.new()
    categories.definition_categories = {"itemdef:test_tonic": ItemCategoryCatalog.CATEGORY_CONSUMABLE}
    var stocked: Dictionary = SERVICE_CONTENT_VIEW_SCRIPT.build_recovery_view(clinic, economy, categories, true)
    _expect(bool(stocked.get("consumable_stock_ready", false)), "Clinic consumable capability resolves only when persisted stock and authored consumable category agree")
    _expect(bool(stocked.get("content_ready", false)), "Clinic stock-backed service can become content-ready without inventing healing amounts")

    var wrong_categories := ItemCategoryCatalog.new()
    wrong_categories.definition_categories = {"itemdef:test_tonic": ItemCategoryCatalog.CATEGORY_MATERIAL}
    var wrong_stock: Dictionary = SERVICE_CONTENT_VIEW_SCRIPT.build_recovery_view(clinic, economy, wrong_categories, true)
    _expect(not bool(wrong_stock.get("consumable_stock_ready", true)) and _has_blocker(wrong_stock, &"clinic_stock_contains_non_consumable"), "Clinic rejects stock that is authored as a non-consumable category")

    var healing_only := _recovery_definition(
        &"service:test_clinic_healing",
        &"r3:functional:08",
        &"clinic_apothecary"
    )
    healing_only["recovery_amounts"] = {"resource:health": 7.0}
    var healing_ready: Dictionary = SERVICE_CONTENT_VIEW_SCRIPT.build_recovery_view(healing_only, null, null, true, false, true)
    _expect(bool(healing_ready.get("content_ready", false)), "Clinic healing-only path can become content-ready with explicit recovery data and a resolved commit owner without inventing stock")


func _training_definition() -> Dictionary:
    return {
        "service_id": &"service:test_training_hall",
        "structure_id": &"r3:functional:07",
        "role_id": &"training_hall",
        "available": true,
        "combat_restricted": true,
        "instruction_content_id": null,
        "practice_interaction_id": null,
        "skill_surface_id": SkillsMenu.MODAL_ID,
    }


func _recovery_definition(service_id: StringName, structure_id: StringName, role_id: StringName) -> Dictionary:
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


func _has_blocker(view: Dictionary, blocker: StringName) -> bool:
    return (view.get("blockers", []) as Array).has(blocker)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
