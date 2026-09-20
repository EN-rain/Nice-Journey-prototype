class_name EffectVisualCatalog
extends Resource

@export var profiles: Array[EffectVisualProfile] = []

func get_profile(effect_id: StringName) -> EffectVisualProfile:
    for profile: EffectVisualProfile in profiles:
        if profile != null and profile.effect_id == effect_id:
            return profile
    return null

func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    var seen: Dictionary = {}
    for index: int in range(profiles.size()):
        var profile: EffectVisualProfile = profiles[index]
        if profile == null:
            errors.append("profiles[%d] is null" % index)
            continue
        for error: String in profile.validate_profile():
            errors.append("profiles[%d]: %s" % [index, error])
        if seen.has(profile.effect_id):
            errors.append("duplicate effect_id: %s" % String(profile.effect_id))
        else:
            seen[profile.effect_id] = true
    return errors
