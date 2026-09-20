extends SceneTree

const EQUIPMENT = preload("res://src/data/tuning/player_equipment_playtest_v01.tres")
const SERVICES = preload("res://src/data/tuning/region3_services_playtest_v01.tres")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var tuning := EQUIPMENT as PlayerEquipmentPlaytestTuning
    var services := SERVICES as Region3PlaytestContent
    _expect(tuning != null and services != null and services.blacksmith_recipes != null, "shipped equipment and Blacksmith resources load")
    if tuning != null and services != null and services.blacksmith_recipes != null:
        _expect(tuning.validate_starter_upgrade_recipes(services.blacksmith_recipes).is_empty(), "shipped starter recipe previews match their live equipped attack bonuses")
        _expect(is_zero_approx(tuning.attack_bonus_for(StarterKitCatalog.WEAPON_MELEE_SWORD, 2)), "an unauthored higher upgrade rank cannot gain compounded attack power")

        var changed_tuning := tuning.duplicate(true) as PlayerEquipmentPlaytestTuning
        changed_tuning.attack_power_per_upgrade_rank = tuning.attack_power_per_upgrade_rank.duplicate(true)
        changed_tuning.attack_power_per_upgrade_rank["starter_bow"] = 2.0
        _expect(not changed_tuning.validate_starter_upgrade_recipes(services.blacksmith_recipes).is_empty(), "independent equipment stat edits cannot silently disagree with Blacksmith preview")

        var wrong_stat_catalog := _copy_recipes(services.blacksmith_recipes)
        var sword := wrong_stat_catalog.recipes[0]
        sword.stat_changes = {"physical_defense": 1}
        _expect(not tuning.validate_starter_upgrade_recipes(wrong_stat_catalog).is_empty(), "a recipe cannot advertise an unimplemented equipment combat stat")

        var missing_recipe_catalog := _copy_recipes(services.blacksmith_recipes)
        missing_recipe_catalog.recipes.remove_at(0)
        _expect(not tuning.validate_starter_upgrade_recipes(missing_recipe_catalog).is_empty(), "all three starter weapons require one independently authored rank-one recipe")

        _expect(not tuning.validate_starter_upgrade_recipes(null).is_empty(), "unassigned Blacksmith content does not pass upgrade-effect readiness")
        _expect(tuning.validate_starter_upgrade_recipes(services.blacksmith_recipes).is_empty(), "invalid candidate checks do not mutate the live shipped resources")

    if _failures == 0:
        print("EQUIPMENT UPGRADE EFFECT AUTHORING TEST PASS")
    else:
        push_error("EQUIPMENT UPGRADE EFFECT AUTHORING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _copy_recipes(source: UpgradeRecipeCatalog) -> UpgradeRecipeCatalog:
    var result := UpgradeRecipeCatalog.new()
    for recipe: UpgradeRecipeDefinition in source.recipes:
        result.recipes.append(recipe.duplicate(true) as UpgradeRecipeDefinition)
    return result


func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS: %s" % description)
    else:
        _failures += 1
        push_error("FAIL: %s" % description)
