class_name PassiveSkillsPlaytestContent
extends Resource

# All magnitudes and distances below are Inspector-authored PLAYTEST hypotheses.
# The master approves the nine identities and rank semantics, not these values.
@export var playtest_placeholder: bool = true

@export_group("Melee")
@export var efficient_footwork_stamina_cost_multiplier: PackedFloat32Array = PackedFloat32Array()
@export var breaker_poise_multiplier: PackedFloat32Array = PackedFloat32Array()
@export var parry_recovery_stamina_restore: PackedFloat32Array = PackedFloat32Array()

@export_group("Ranged")
@export var longshot_minimum_distance_px: PackedFloat32Array = PackedFloat32Array()
@export var longshot_damage_multiplier: PackedFloat32Array = PackedFloat32Array()
@export var fleet_recovery_movement_stamina_cost_multiplier: PackedFloat32Array = PackedFloat32Array()
@export var fleet_recovery_stamina_regeneration_multiplier: PackedFloat32Array = PackedFloat32Array()
@export var expose_visible_weak_point_multiplier: PackedFloat32Array = PackedFloat32Array()

@export_group("Mage")
@export var mana_weave_mana_cost_multiplier: PackedFloat32Array = PackedFloat32Array()
@export var flow_recovery_mana_regeneration_multiplier: PackedFloat32Array = PackedFloat32Array()
@export var stable_casting_recovery_ticks_multiplier: PackedFloat32Array = PackedFloat32Array()


func validate_content() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("passive skill values must remain explicitly PLAYTEST until approved")
    _check(efficient_footwork_stamina_cost_multiplier, "efficient_footwork", 0.0, 1.0, -1, errors)
    _check(breaker_poise_multiplier, "breaker", 1.0, INF, 1, errors)
    _check(parry_recovery_stamina_restore, "parry_recovery", 0.0, INF, 1, errors)
    _check(longshot_minimum_distance_px, "longshot_minimum_distance_px", 0.0, INF, -1, errors)
    _check(longshot_damage_multiplier, "longshot_damage_multiplier", 1.0, INF, 1, errors)
    _check(fleet_recovery_movement_stamina_cost_multiplier, "fleet_movement_cost", 0.0, 1.0, -1, errors)
    _check(fleet_recovery_stamina_regeneration_multiplier, "fleet_regeneration", 1.0, INF, 1, errors)
    _check(expose_visible_weak_point_multiplier, "expose", 1.0, INF, 1, errors)
    _check(mana_weave_mana_cost_multiplier, "mana_weave", 0.0, 1.0, -1, errors)
    _check(flow_recovery_mana_regeneration_multiplier, "flow_recovery", 1.0, INF, 1, errors)
    _check(stable_casting_recovery_ticks_multiplier, "stable_casting", 0.0, 1.0, -1, errors)
    return errors


func _check(values: PackedFloat32Array, label: String, minimum: float, maximum: float,
    direction: int, errors: PackedStringArray) -> void:
    if values.size() != 3:
        errors.append("%s requires three explicitly authored ranks" % label)
        return
    for index: int in 3:
        var value: float = values[index]
        if not is_finite(value) or value <= minimum or value > maximum:
            errors.append("%s rank %d is outside its valid nonzero range" % [label, index + 1])
            continue
        if index > 0 and (value - values[index - 1]) * float(direction) <= 0.0:
            errors.append("%s ranks must improve strictly without changing their effect" % label)
