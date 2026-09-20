class_name EnemyArchetypePlaytestStats
extends Resource

# Per-role Inspector overrides of the existing floor-scaled PLAYTEST baseline.
# Neutral defaults preserve legacy encounters until role-specific tuning exists.
@export var archetype_id: StringName = &""
@export_range(0.1, 10.0, 0.05) var hp_multiplier: float = 1.0
@export_range(0.0, 10000.0, 0.1) var stamina_bonus: float = 0.0
@export_range(0.0, 10000.0, 0.1) var physical_defense_bonus: float = 0.0
@export_range(0.0, 10000.0, 0.1) var arcane_defense_bonus: float = 0.0
@export_range(0.1, 10.0, 0.05) var poise_multiplier: float = 1.0

# -1 means not authorized. These do not grant rewards or change threat routing.
@export_range(-1, 100, 1) var difficulty_rating: int = -1
@export_range(-1, 1000000, 1) var xp_reward: int = -1
@export_range(-1, 1000000, 1) var gold_reward: int = -1


func validate_authoring() -> PackedStringArray:
    var errors := PackedStringArray()
    if not EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS.has(archetype_id):
        errors.append("unapproved archetype stats identity: %s" % String(archetype_id))
    if not is_finite(hp_multiplier) or hp_multiplier <= 0.0 or hp_multiplier > 10.0:
        errors.append("role HP multiplier must be finite, positive and at most 10")
    if not is_finite(poise_multiplier) or poise_multiplier <= 0.0 or poise_multiplier > 10.0:
        errors.append("role poise multiplier must be finite, positive and at most 10")
    for value: float in [stamina_bonus, physical_defense_bonus, arcane_defense_bonus]:
        if not is_finite(value) or value < 0.0 or value > 10000.0:
            errors.append("role stamina/defense additions must be finite and within Inspector bounds")
            break
    if difficulty_rating != -1 and (difficulty_rating <= 0 or difficulty_rating > 100):
        errors.append("difficulty rating must be 1..100 or explicitly unauthored (-1)")
    if xp_reward < -1 or xp_reward > 1000000 or gold_reward < -1 or gold_reward > 1000000:
        errors.append("rewards must be 0..1000000 or explicitly unauthored (-1)")
    return errors
