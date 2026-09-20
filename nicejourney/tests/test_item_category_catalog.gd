extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var catalog := ItemCategoryCatalog.new()
    catalog.definition_categories = {
        "itemdef:potion": ItemCategoryCatalog.CATEGORY_CONSUMABLE,
        "itemdef:sword": ItemCategoryCatalog.CATEGORY_WEAPON,
        "itemdef:armor": ItemCategoryCatalog.CATEGORY_ARMOR,
        "itemdef:ore": ItemCategoryCatalog.CATEGORY_MATERIAL,
        "itemdef:key": ItemCategoryCatalog.CATEGORY_QUEST_KEY,
    }
    _expect(catalog.validate_catalog().is_empty(), "master item-category set validates without inferring content")
    _expect(catalog.category_for(&"itemdef:potion") == ItemCategoryCatalog.CATEGORY_CONSUMABLE, "catalog returns exact authored consumable category")
    _expect(catalog.is_consumable(&"itemdef:potion") and not catalog.is_consumable(&"itemdef:sword"), "consumable admission follows exact authored category only")
    _expect(catalog.category_for(&"itemdef:unknown") == &"", "unauthored definition remains unknown")

    var invalid_category := ItemCategoryCatalog.new()
    invalid_category.definition_categories = {"itemdef:mystery": "utility"}
    _expect(not invalid_category.validate_catalog().is_empty(), "catalog rejects categories outside the five master categories")

    var invalid_definition := ItemCategoryCatalog.new()
    invalid_definition.definition_categories = {"bad id": ItemCategoryCatalog.CATEGORY_CONSUMABLE}
    _expect(not invalid_definition.validate_catalog().is_empty(), "catalog rejects unstable item definition IDs")

    if _failures == 0:
        print("ITEM CATEGORY CATALOG TEST PASS")
    else:
        push_error("ITEM CATEGORY CATALOG TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
