extends SceneTree
const OUTPUT = "res://docs/evidence/art/region3_support_v02/renderer/region3_support_catalog_complete.png"
const SHEETS = [
    ["Town props: 16 cells at 1x", "res://assets/art/environments/region3/props/region3_prop_sheet_v02.png", 4, 16, 64, 1],
    ["Ground / roads: 8 atlas cells at 2x", "res://assets/art/environments/region3/roads/region3_ground_road_tileset_v02.png", 4, 8, 32, 2],
    ["Ruins: 8 atlas cells at 1x (inspect empty / filler cell)", "res://assets/art/environments/region3/ruins/region3_ruins_module_sheet_v02.png", 4, 8, 64, 1],
    ["Outskirts: 6 cells at 1x", "res://assets/art/environments/region3/outskirts/region3_outskirts_support_sheet_v02.png", 3, 6, 64, 1],
    ["Risk zone: 6 cells at 1x", "res://assets/art/environments/region3/risk_zone/region3_risk_zone_support_sheet_v02.png", 3, 6, 64, 1]
]
func _init() -> void:
    call_deferred("_capture")
func _capture() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(1280, 720)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var bg := ColorRect.new()
    bg.size = Vector2(1280,720)
    bg.color = Color("#20262d")
    viewport.add_child(bg)
    for row: int in range(SHEETS.size()):
        var spec: Array = SHEETS[row]
        var title := Label.new()
        title.text = spec[0]
        title.position = Vector2(20,20 + row * 132)
        title.add_theme_font_size_override("font_size",18)
        viewport.add_child(title)
        var tex := load(String(spec[1])) as Texture2D
        var source_cols: int = spec[2]
        var count: int = spec[3]
        var cell: int = spec[4]
        var zoom: int = spec[5]
        for index: int in range(count):
            var sprite := Sprite2D.new()
            sprite.texture = tex
            sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            sprite.region_enabled = true
            sprite.region_rect = Rect2((index % source_cols) * cell, int(index / source_cols) * cell,cell,cell)
            sprite.position = Vector2(54 + index * 77, 84 + row * 132)
            sprite.scale = Vector2(zoom,zoom)
            viewport.add_child(sprite)
            var label := Label.new()
            label.text = str(index)
            label.position = Vector2(48 + index * 77,116 + row *132)
            label.add_theme_font_size_override("font_size",12)
            viewport.add_child(label)
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var result := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
    print("REGION3_SUPPORT_CATALOG_CAPTURE=",result)
    quit(result)
