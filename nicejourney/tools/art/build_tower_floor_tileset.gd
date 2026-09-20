extends SceneTree

# Build an editor resource from the existing 4x4 placeholder atlas. Source art
# remains immutable. The resource can later point to an accepted 4x4 successor.
const SOURCE := "res://assets/art/environments/tower/tiles/tower_common_tileset_v01.png"
const DESTINATION := "res://src/world/tower/presentation/tower_common_floor_tileset_v01.tres"
const EXPECTED_SHA256 := "b4851c0ba3a7b674c730fcdd756c8e21f256094b651a3958f6130dc525193129"

func _init() -> void:
    var path := ProjectSettings.globalize_path(SOURCE)
    if FileAccess.get_sha256(path) != EXPECTED_SHA256:
        push_error("source atlas changed; inspect before rebuilding")
        quit(1)
        return
    var texture := load(SOURCE) as Texture2D
    if texture == null or texture.get_size() != Vector2(128, 128):
        push_error("expected preserved 128x128 atlas")
        quit(1)
        return
    var tileset := TileSet.new()
    tileset.tile_size = Vector2i(32, 32)
    var atlas := TileSetAtlasSource.new()
    atlas.texture = texture
    atlas.texture_region_size = Vector2i(32, 32)
    for y: int in range(4):
        for x: int in range(4):
            atlas.create_tile(Vector2i(x, y))
    tileset.add_source(atlas, 0)
    if ResourceSaver.save(tileset, DESTINATION) != OK:
        push_error("could not preserve tower floor tileset resource")
        quit(1)
        return
    print("TOWER FLOOR TILESET BUILT: 4x4 source atlas / 32x32 TileMapLayer cells")
    quit()
