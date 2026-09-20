class_name CombatOutcomeEffectBinding
extends Resource

@export var outcome_id: StringName = &""
@export var effect_profile: EffectVisualProfile


func validate_binding() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(outcome_id)):
        errors.append("outcome_id must be a stable ID")
    if effect_profile == null:
        errors.append("effect_profile is required")
    else:
        for error: String in effect_profile.validate_profile():
            errors.append("effect_profile: %s" % error)
    return errors
