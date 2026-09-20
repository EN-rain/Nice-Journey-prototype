class_name PlayerEquipmentPlaytestTuning
extends Resource

# Inspector-authored provisional interpretation of Blacksmith attack_power
# deltas. Other equipment benefits stay unimplemented until authoring exists.
@export var playtest_placeholder: bool = true
@export var attack_power_per_upgrade_rank: Dictionary = {}
@export_range(1, 99, 1) var maximum_authored_upgrade_rank: int = 1


func validate_tuning() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("equipment stat bonuses must retain their playtest flag")
    if maximum_authored_upgrade_rank < 1 or maximum_authored_upgrade_rank > 99:
        errors.append("maximum authored weapon upgrade rank must be within 1..99")
    var expected := [
        StarterKitCatalog.WEAPON_MELEE_SWORD,
        StarterKitCatalog.WEAPON_RANGED_BOW,
        StarterKitCatalog.WEAPON_MAGE_STAFF,
    ]
    if attack_power_per_upgrade_rank.size() != expected.size():
        errors.append("only the three approved starter weapons have playtest attack-power growth")
    for weapon_id: StringName in expected:
        var value: Variant = attack_power_per_upgrade_rank.get(String(weapon_id), null)
        if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT):
            errors.append("%s requires an Inspector-authored attack-power delta" % String(weapon_id))
            continue
        if not is_finite(float(value)) or float(value) < 0.0 or float(value) > 100.0:
            errors.append("%s playtest delta must be finite and bounded" % String(weapon_id))
    return errors


func attack_bonus_for(weapon_id: StringName, upgrade_rank: int) -> float:
    if upgrade_rank <= 0 or upgrade_rank > maximum_authored_upgrade_rank or not validate_tuning().is_empty():
        return 0.0
    var value: Variant = attack_power_per_upgrade_rank.get(String(weapon_id), null)
    if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT):
        return 0.0
    return float(value) * float(upgrade_rank)


func validate_starter_upgrade_recipes(catalog: UpgradeRecipeCatalog) -> PackedStringArray:
    # The Blacksmith preview promises stat_changes, while live combat derives
    # attack power from this separate Inspector resource. Check both authoring
    # sources together before treating the upgrade data as ready for approval.
    var errors := validate_tuning()
    if catalog == null:
        errors.append("starter weapon upgrade recipe catalog must be assigned")
        return errors
    errors.append_array(catalog.validate_catalog(true))
    if not errors.is_empty():
        return errors

    for weapon_id: StringName in [
        StarterKitCatalog.WEAPON_MELEE_SWORD,
        StarterKitCatalog.WEAPON_RANGED_BOW,
        StarterKitCatalog.WEAPON_MAGE_STAFF,
    ]:
        var rank_recipes: Dictionary = {}
        for recipe: UpgradeRecipeDefinition in catalog.recipes:
            if recipe == null or not recipe.compatible_definition_ids.has(weapon_id):
                continue
            if recipe.compatible_definition_ids.size() != 1:
                errors.append("starter weapon recipe must identify exactly one starter weapon: %s" % String(weapon_id))
            if recipe.stat_changes.size() != 1 or not recipe.stat_changes.has("attack_power"):
                errors.append("starter weapon recipe must author only the live attack_power effect: %s" % String(weapon_id))
                continue
            var delta: Variant = recipe.stat_changes["attack_power"]
            if not (typeof(delta) == TYPE_INT or typeof(delta) == TYPE_FLOAT) or not is_finite(float(delta)):
                errors.append("starter weapon recipe attack_power must be a finite number: %s" % String(weapon_id))
                continue
            if not is_equal_approx(float(delta), float(attack_power_per_upgrade_rank[String(weapon_id)])):
                errors.append("starter weapon recipe attack_power differs from live equipped upgrade effect: %s" % String(weapon_id))
            if recipe.maximum_rank != maximum_authored_upgrade_rank:
                errors.append("starter weapon recipe maximum rank differs from live equipped tuning: %s" % String(weapon_id))
            rank_recipes[recipe.source_rank] = int(rank_recipes.get(recipe.source_rank, 0)) + 1
        for source_rank: int in range(maximum_authored_upgrade_rank):
            if int(rank_recipes.get(source_rank, 0)) != 1:
                errors.append("starter weapon requires exactly one authored rank %d-to-%d recipe: %s" % [source_rank, source_rank + 1, String(weapon_id)])
    return errors
