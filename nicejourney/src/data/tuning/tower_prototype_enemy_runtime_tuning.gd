class_name TowerPrototypeEnemyRuntimeTuning
extends Resource

# Initial playtest tuning for reusable tower residents. These are authored floor-data
# values, not hidden dynamic scaling, and remain replaceable during balance passes.
@export_range(1, 100000, 1) var base_hp: int = 40
@export_range(0, 10000, 1) var hp_per_floor: int = 8
@export_range(0.0, 10000.0, 0.1) var base_stamina: float = 0.0
@export_range(0.0, 10000.0, 0.1) var defender_stamina: float = 60.0
@export_range(0.0, 10000.0, 0.1) var base_physical_defense: float = 0.0
@export_range(0.0, 10000.0, 0.1) var base_arcane_defense: float = 0.0
@export_range(0.1, 10000.0, 0.1) var base_poise_threshold: float = 20.0
@export_range(0.0, 1000.0, 0.1) var poise_per_floor: float = 2.0
@export_range(1.0, 10.0, 0.05) var elite_hp_multiplier: float = 1.5
@export_range(0.0, 10000.0, 0.1) var elite_defense_bonus: float = 5.0
@export_range(1.0, 10.0, 0.05) var elite_poise_multiplier: float = 1.5
@export var archetype_stats: EnemyArchetypePlaytestStatsCatalog

func validate_tuning() -> PackedStringArray:
    var errors := PackedStringArray()
    if base_hp <= 0 or hp_per_floor < 0:
        errors.append("HP tuning must be positive/nonnegative")
    for value: float in [base_stamina, defender_stamina, base_physical_defense, base_arcane_defense, base_poise_threshold, poise_per_floor, elite_hp_multiplier, elite_defense_bonus, elite_poise_multiplier]:
        if not is_finite(value) or value < 0.0:
            errors.append("enemy runtime tuning values must be finite and nonnegative")
            break
    if base_poise_threshold <= 0.0 or elite_hp_multiplier < 1.0 or elite_poise_multiplier < 1.0:
        errors.append("poise threshold and elite multipliers must preserve positive/nondecreasing values")
    if archetype_stats != null:
        for error: String in archetype_stats.validate_catalog():
            errors.append("archetype stats: %s" % error)
    return errors
