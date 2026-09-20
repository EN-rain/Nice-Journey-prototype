extends SceneTree

const CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const VISUAL_SCENE: PackedScene = preload("res://src/world/tower/presentation/tower_room_visual.tscn")

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _expect(CATALOG != null, "tower room visual catalog loads")
    if CATALOG != null:
        _expect(CATALOG.floor_tileset != null and CATALOG.floor_tileset.tile_size == Vector2i(32, 32), "tower floor TileSet is inspector assigned at the authored 32px cell size")
        if CATALOG.floor_tileset != null and CATALOG.floor_tileset.has_source(CATALOG.floor_tile_source_id):
            var floor_atlas := CATALOG.floor_tileset.get_source(CATALOG.floor_tile_source_id) as TileSetAtlasSource
            _expect(floor_atlas != null and floor_atlas.texture != null and floor_atlas.texture.get_size() == Vector2(128, 128), "tower floor TileSet consumes the preserved 4x4 source atlas")
        _expect(CATALOG.profiles.size() == 8, "catalog exposes all eight current tower room visual categories")
        _expect(CATALOG.validate_catalog().is_empty(), "tower room visual profiles validate")
        for room_type: StringName in TowerRoomVisualProfile.ROOM_TYPES:
            var profile: TowerRoomVisualProfile = CATALOG.get_profile(room_type)
            _expect(profile != null, "tower visual catalog resolves %s" % String(room_type))
            if profile != null:
                _expect(profile.texture != null, "%s texture is inspector assigned" % String(room_type))

    var visual: TowerRoomVisual = VISUAL_SCENE.instantiate() as TowerRoomVisual
    root.add_child(visual)
    await process_frame
    _expect(visual != null, "generic tower room Sprite2D presenter instantiates")
    if visual != null and CATALOG != null:
        visual.profile = CATALOG.get_profile(&"combat")
        _expect(visual.apply_profile(), "tower room presenter applies inspector-authored profile")
        _expect(visual.sprite != null and visual.sprite.texture == visual.profile.texture, "tower room Sprite2D uses profile texture")
        _expect(visual.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "tower room presenter preserves nearest filtering")
        visual.queue_free()

    var controller_source: String = FileAccess.get_file_as_string("res://src/world/tower/presentation/tower_room_visual.gd")
    _expect(not controller_source.contains("res://assets/art/"), "tower room runtime contains no hardcoded art paths")

    if _failures == 0:
        print("TOWER ROOM VISUAL TEST PASS")
    else:
        push_error("TOWER ROOM VISUAL TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
