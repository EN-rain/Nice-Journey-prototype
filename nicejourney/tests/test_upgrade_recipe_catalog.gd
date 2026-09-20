extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_absent_recipes_are_unavailable()
    _test_invalid_recipe_is_rejected()
    _test_exact_recipe_lookup_and_compatibility()
    _test_duplicate_recipe_ids_fail_closed()
    if _failures == 0:
        print("UPGRADE RECIPE CATALOG TEST PASS")
    else:
        push_error("UPGRADE RECIPE CATALOG TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_absent_recipes_are_unavailable() -> void:
    var catalog := UpgradeRecipeCatalog.new()
    _expect(catalog.validate_catalog().is_empty(), "empty recipe catalog is structurally valid")
    _expect(not catalog.has_authored_recipes(), "empty recipe catalog reports no authored Blacksmith content")
    _expect(catalog.get_recipe(&"upgrade:missing") == null, "missing recipe identity cannot fabricate upgrade requirements")
    _expect(catalog.compatible_recipes(&"itemdef:test_blade", &"rare", 0).is_empty(), "missing recipe catalog exposes no compatible upgrades")


func _test_invalid_recipe_is_rejected() -> void:
    var catalog := UpgradeRecipeCatalog.new()
    catalog.recipes = [UpgradeRecipeDefinition.new()]
    _expect(not catalog.validate_catalog().is_empty(), "default recipe without exact content is invalid")
    _expect(not catalog.has_authored_recipes(), "invalid recipe catalog is unavailable")


func _test_exact_recipe_lookup_and_compatibility() -> void:
    var recipe := _recipe(&"upgrade:test_blade:0_to_1")
    var catalog := UpgradeRecipeCatalog.new()
    catalog.recipes = [recipe]
    _expect(catalog.validate_catalog().is_empty(), "complete deterministic upgrade recipe validates")
    _expect(catalog.has_authored_recipes(), "catalog reports authored recipes only when all definitions validate")

    var fetched := catalog.get_recipe(recipe.recipe_id)
    _expect(fetched != null, "recipe can be resolved by exact authored stable ID")
    if fetched != null:
        _expect(
            fetched.gold_cost == 75
            and int(fetched.material_costs.get("itemdef:test_ore", 0)) == 3
            and float(fetched.stat_changes.get("stat:attack_power", 0.0)) == 2.0,
            "recipe lookup preserves exact authored Gold, material and stat changes"
        )
        fetched.gold_cost = 1
        var fresh := catalog.get_recipe(recipe.recipe_id)
        _expect(fresh != null and fresh.gold_cost == 75, "catalog lookup returns an isolated recipe copy")

    var compatible := catalog.compatible_recipes(&"itemdef:test_blade", &"rare", 0)
    _expect(compatible.size() == 1 and compatible[0].recipe_id == recipe.recipe_id, "compatibility query returns the exact authored recipe")
    _expect(catalog.compatible_recipes(&"itemdef:test_blade", &"rare", 1).is_empty(), "wrong source rank exposes no upgrade")
    _expect(catalog.compatible_recipes(&"itemdef:test_blade", &"common", 0).is_empty(), "unauthorized rarity exposes no upgrade")


func _test_duplicate_recipe_ids_fail_closed() -> void:
    var catalog := UpgradeRecipeCatalog.new()
    catalog.recipes = [
        _recipe(&"upgrade:duplicate"),
        _recipe(&"upgrade:duplicate"),
    ]
    _expect(not catalog.validate_catalog().is_empty(), "duplicate recipe IDs invalidate the catalog")
    _expect(catalog.get_recipe(&"upgrade:duplicate") == null, "invalid catalog cannot resolve an ambiguous recipe")
    _expect(catalog.compatible_recipes(&"itemdef:test_blade", &"rare", 0).is_empty(), "invalid catalog cannot expose compatible upgrade choices")


func _recipe(recipe_id: StringName) -> UpgradeRecipeDefinition:
    var recipe := UpgradeRecipeDefinition.new()
    recipe.recipe_id = recipe_id
    recipe.compatible_definition_ids = [&"itemdef:test_blade"]
    recipe.compatible_rarities = [&"rare"]
    recipe.source_rank = 0
    recipe.result_rank = 1
    recipe.maximum_rank = 3
    recipe.gold_cost = 75
    recipe.source_rank_declared = true
    recipe.result_rank_declared = true
    recipe.maximum_rank_declared = true
    recipe.gold_cost_declared = true
    recipe.prerequisites_declared = true
    recipe.material_costs = {"itemdef:test_ore": 3}
    recipe.stat_changes = {"stat:attack_power": 2}
    return recipe


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
