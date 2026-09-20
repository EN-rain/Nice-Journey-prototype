class_name TowerRoomVisualCatalog
extends Resource

@export var profiles: Array[TowerRoomVisualProfile] = []

func get_profile(room_type: StringName) -> TowerRoomVisualProfile:
    for profile: TowerRoomVisualProfile in profiles:
        if profile != null and profile.room_type == room_type:
            return profile
    return null

func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    if profiles.size() != TowerRoomVisualProfile.ROOM_TYPES.size():
        errors.append("catalog must contain exactly eight tower room visual categories")
    var seen: Dictionary = {}
    for index: int in range(profiles.size()):
        var profile: TowerRoomVisualProfile = profiles[index]
        if profile == null:
            errors.append("profiles[%d] is null" % index)
            continue
        for error: String in profile.validate_profile():
            errors.append("profiles[%d]: %s" % [index, error])
        if seen.has(profile.room_type):
            errors.append("duplicate room_type: %s" % String(profile.room_type))
        else:
            seen[profile.room_type] = true
    for room_type: StringName in TowerRoomVisualProfile.ROOM_TYPES:
        if not seen.has(room_type):
            errors.append("missing tower room visual: %s" % String(room_type))
    return errors
