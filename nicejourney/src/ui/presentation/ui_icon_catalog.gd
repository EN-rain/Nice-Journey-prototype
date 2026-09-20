class_name UiIconCatalog
extends Resource

@export var profiles: Array[UiIconProfile] = []

func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    var seen: Dictionary = {}
    for profile: UiIconProfile in profiles:
        if profile == null:
            errors.append("profiles cannot contain null entries")
            continue
        for error: String in profile.validate_profile():
            errors.append("%s: %s" % [String(profile.icon_id), error])
        if seen.has(profile.icon_id):
            errors.append("duplicate icon_id: %s" % String(profile.icon_id))
        seen[profile.icon_id] = true
    return errors

func get_profile(icon_id: StringName) -> UiIconProfile:
    for profile: UiIconProfile in profiles:
        if profile != null and profile.icon_id == icon_id:
            return profile
    return null
