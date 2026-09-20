class_name PlayerEquipmentPlaytestTuning
extends Resource

# Inspector-authored provisional interpretation of Blacksmith attack_power
# deltas. Other equipment benefits stay unimplemented until authoring exists.
@export var playtest_placeholder: bool = true
@export var attack_power_per_upgrade_rank: Dictionary = {}


func validate_tuning() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("equipment stat bonuses must retain their playtest flag")
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
    if upgrade_rank <= 0 or upgrade_rank > 99 or not validate_tuning().is_empty():
        return 0.0
    var value: Variant = attack_power_per_upgrade_rank.get(String(weapon_id), null)
    if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT):
        return 0.0
    return float(value) * float(upgrade_rank)
