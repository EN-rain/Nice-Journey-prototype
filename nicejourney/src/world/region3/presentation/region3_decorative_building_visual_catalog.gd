class_name Region3DecorativeBuildingVisualCatalog
extends Resource

const REQUIRED_STRUCTURE_IDS: Array[StringName] = [
    &"r3:decorative:01",
    &"r3:decorative:02",
    &"r3:decorative:03",
    &"r3:decorative:04",
    &"r3:decorative:05",
    &"r3:decorative:06",
    &"r3:decorative:07",
    &"r3:decorative:08",
    &"r3:decorative:09",
    &"r3:decorative:10",
    &"r3:decorative:11",
    &"r3:decorative:12",
]

@export var profiles: Array[Region3DecorativeBuildingVisualProfile] = []

func get_profile(structure_id: StringName) -> Region3DecorativeBuildingVisualProfile:
    for profile: Region3DecorativeBuildingVisualProfile in profiles:
        if profile != null and profile.structure_id == structure_id:
            return profile
    return null

func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    if profiles.size() != Region3TownStructureManifestValidator.DECORATIVE_STRUCTURES:
        errors.append("catalog must contain exactly twelve decorative building visuals")
    var seen: Dictionary = {}
    for index: int in range(profiles.size()):
        var profile: Region3DecorativeBuildingVisualProfile = profiles[index]
        if profile == null:
            errors.append("profiles[%d] is null" % index)
            continue
        for error: String in profile.validate_profile():
            errors.append("profiles[%d]: %s" % [index, error])
        if not REQUIRED_STRUCTURE_IDS.has(profile.structure_id):
            errors.append("profiles[%d]: unknown decorative structure_id %s" % [index, String(profile.structure_id)])
        if seen.has(profile.structure_id):
            errors.append("duplicate structure_id: %s" % String(profile.structure_id))
        else:
            seen[profile.structure_id] = true
    for structure_id: StringName in REQUIRED_STRUCTURE_IDS:
        if not seen.has(structure_id):
            errors.append("missing decorative structure visual: %s" % String(structure_id))
    return errors
