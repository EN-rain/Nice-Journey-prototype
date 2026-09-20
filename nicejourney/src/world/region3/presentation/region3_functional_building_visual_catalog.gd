class_name Region3FunctionalBuildingVisualCatalog
extends Resource

@export var profiles: Array[Region3FunctionalBuildingVisualProfile] = []

func get_profile(role_id: StringName) -> Region3FunctionalBuildingVisualProfile:
    for profile: Region3FunctionalBuildingVisualProfile in profiles:
        if profile != null and profile.role_id == role_id:
            return profile
    return null

func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    if profiles.size() != Region3TownStructureManifestValidator.FUNCTIONAL_STRUCTURES:
        errors.append("catalog must contain exactly eight functional building visuals")
    var seen: Dictionary = {}
    for index: int in range(profiles.size()):
        var profile: Region3FunctionalBuildingVisualProfile = profiles[index]
        if profile == null:
            errors.append("profiles[%d] is null" % index)
            continue
        for error: String in profile.validate_profile():
            errors.append("profiles[%d]: %s" % [index, error])
        if seen.has(profile.role_id):
            errors.append("duplicate role_id: %s" % String(profile.role_id))
        else:
            seen[profile.role_id] = true
    for role_id: StringName in Region3TownStructureManifestValidator.REQUIRED_FUNCTIONAL_ROLES:
        if not seen.has(role_id):
            errors.append("missing functional role visual: %s" % String(role_id))
    return errors
