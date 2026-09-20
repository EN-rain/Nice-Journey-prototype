class_name TowerRoomVisualCatalog
extends Resource

@export var profiles: Array[TowerRoomVisualProfile] = []
@export var floor_tileset: TileSet
@export_range(0, 1024, 1) var floor_tile_source_id: int = 0

func get_profile(room_type: StringName) -> TowerRoomVisualProfile:
    for profile: TowerRoomVisualProfile in profiles:
        if profile != null and profile.room_type == room_type:
            return profile
    return null

func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    if floor_tileset == null:
        errors.append("tower floor tileset is required")
    elif floor_tileset.tile_size != Vector2i(32, 32):
        errors.append("tower floor tileset must use 32x32 cells")
    elif not floor_tileset.has_source(floor_tile_source_id):
        errors.append("tower floor atlas source is missing")
    else:
        var atlas := floor_tileset.get_source(floor_tile_source_id) as TileSetAtlasSource
        if atlas == null:
            errors.append("tower floor source must be an atlas")
        else:
            for variant: int in range(4):
                if not atlas.has_tile(Vector2i(variant, 0)):
                    errors.append("tower floor variant %d missing" % variant)
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
