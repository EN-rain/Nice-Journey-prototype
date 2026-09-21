extends SceneTree

# Review-only native rendering: compare the real Inspector-owned V01 floor
# TileSet with a temporary TileSet built from the deterministic review PNG.
# No production profile, atlas or TileMapLayer is changed.
const CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const SOURCE := "res://assets/art/environments/tower/tiles/tower_common_tileset_v01.png"
const CANDIDATE := "res://tools/art/tower_floor_review/tower_common_tileset_floor_rim_review_v01.png"
const OUTPUT := "res://tools/art/tower_floor_review/tower_floor_rim_native_comparison_v01.png"
const METADATA := "res://tools/art/tower_floor_review/tower_floor_rim_native_comparison_v01.json"
const SOURCE_SHA256 := "b4851c0ba3a7b674c730fcdd756c8e21f256094b651a3958f6130dc525193129"


func _init() -> void:
    call_deferred(&"_capture")


func _capture() -> void:
    if FileAccess.get_sha256(ProjectSettings.globalize_path(SOURCE)) != SOURCE_SHA256:
        push_error("original tower V01 atlas changed")
        quit(1)
        return
    if CATALOG == null or not CATALOG.validate_catalog().is_empty():
        push_error("production tower visual catalog invalid")
        quit(1)
        return
    var image := Image.load_from_file(ProjectSettings.globalize_path(CANDIDATE))
    if image == null or image.get_size() != Vector2i(128, 128):
        push_error("missing exact review-only 4x4 atlas")
        quit(1)
        return
    var preview_set := TileSet.new()
    preview_set.tile_size = Vector2i(32, 32)
    var preview_atlas := TileSetAtlasSource.new()
    preview_atlas.texture = ImageTexture.create_from_image(image)
    preview_atlas.texture_region_size = Vector2i(32, 32)
    for y: int in range(4):
        for x: int in range(4):
            preview_atlas.create_tile(Vector2i(x, y))
    preview_set.add_source(preview_atlas, 0)

    var viewport := SubViewport.new()
    viewport.size = Vector2i(640, 360)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.transparent_bg = false
    root.add_child(viewport)
    var background := ColorRect.new()
    background.color = Color("#16151f")
    background.size = Vector2(viewport.size)
    viewport.add_child(background)
    _add_label(viewport, "Production V01 / 2px rim", Vector2(12, 14))
    _add_label(viewport, "Review ONLY / 1px rim", Vector2(340, 14))
    _add_floor(viewport, CATALOG.floor_tileset, CATALOG.floor_tile_source_id, Vector2(12, 48))
    _add_floor(viewport, preview_set, 0, Vector2(340, 48))

    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var screenshot := viewport.get_texture().get_image()
    if screenshot.get_size() != Vector2i(640, 360) or screenshot.save_png(ProjectSettings.globalize_path(OUTPUT)) != OK:
        push_error("native tower rim review capture failed")
        quit(1)
        return
    var metadata := {
        "status": "REVIEW_ONLY_NOT_ACCEPTED_NOT_BOUND",
        "native_canvas": [640, 360],
        "engine": Engine.get_version_info().get("string", ""),
        "source": SOURCE,
        "source_sha256": SOURCE_SHA256,
        "review_atlas": CANDIDATE,
        "review_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(CANDIDATE)),
        "comparison_image": OUTPUT,
        "comparison_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(OUTPUT)),
        "left_rect": [12, 48, 288, 288],
        "right_rect": [340, 48, 288, 288],
        "tile_size": 32,
        "tiles_per_side": 9,
        "tile_variant_rule": "(floor_x + floor_y) % 4 in atlas row 0",
        "production_textures_rebound": false,
    }
    var writer := FileAccess.open(METADATA, FileAccess.WRITE)
    if writer == null:
        push_error("native tower rim review evidence write failed")
        quit(1)
        return
    writer.store_string(JSON.stringify(metadata, "  ") + "\n")
    writer.close()
    print("TOWER FLOOR RIM NATIVE REVIEW: 640x360 side-by-side, production left, review-only right")
    quit(0)


func _add_label(viewport: SubViewport, label_text: String, at: Vector2) -> void:
    var label := Label.new()
    label.text = label_text
    label.position = at
    label.add_theme_font_size_override("font_size", 14)
    viewport.add_child(label)


func _add_floor(viewport: SubViewport, tileset: TileSet, source_id: int, at: Vector2) -> void:
    var floor := TileMapLayer.new()
    floor.tile_set = tileset
    floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    floor.position = at
    for y: int in range(9):
        for x: int in range(9):
            floor.set_cell(Vector2i(x, y), source_id, Vector2i((x + y) % 4, 0))
    viewport.add_child(floor)
