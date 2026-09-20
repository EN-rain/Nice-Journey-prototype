extends SceneTree

const TEXTURE: Texture2D = preload("res://assets/art/ui/application/application_icon_tower_sigil_v02.png")
const SCREEN := "res://docs/evidence/renderer/application-icon-tower-sigil-v02-native.png"
const REPORT := "res://docs/evidence/renderer/application-icon-tower-sigil-v02-native.json"


func _init() -> void:
    call_deferred("_capture")


func _capture() -> void:
    if ProjectSettings.get_setting("application/config/icon", "") != "res://assets/art/ui/application/application_icon_tower_sigil_v02.png":
        push_error("actual project application icon does not resolve to accepted-source derivative")
        quit(1)
        return
    if TEXTURE == null or TEXTURE.get_size() != Vector2(128, 128):
        push_error("production icon size or resource load failed")
        quit(1)
        return
    var viewport := SubViewport.new()
    viewport.size = Vector2i(128, 128)
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    root.add_child(viewport)
    var sprite := Sprite2D.new()
    sprite.name = "LiveProjectIconPreview"
    sprite.texture = TEXTURE
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = Vector2(64, 64)
    viewport.add_child(sprite)
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var shot := viewport.get_texture().get_image()
    if shot.get_size() != Vector2i(128, 128) or shot.save_png(ProjectSettings.globalize_path(SCREEN)) != OK:
        push_error("actual GL renderer failed to capture the icon at native project dimensions")
        quit(1)
        return
    var report := {
        "scope": "Native 128x128 actual Godot GL Compatibility preview of project config/icon; no release export or packaged OS icon claimed",
        "engine": Engine.get_version_info().get("string", ""),
        "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
        "project_config_icon": String(ProjectSettings.get_setting("application/config/icon")),
        "source_accepted_sigil": "res://assets/art/ui/markers/tower_sigil_icon_v01.png",
        "icon": TEXTURE.resource_path,
        "icon_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(TEXTURE.resource_path)),
        "capture": SCREEN,
        "native_dimensions": [128, 128],
        "render_transform": "native Sprite2D centered (64,64); scale 1; nearest; transparent SubViewport",
        "release_export_performed": false,
    }
    var file := FileAccess.open(REPORT, FileAccess.WRITE)
    if file == null:
        push_error("unable to save icon capture evidence")
        quit(1)
        return
    file.store_string(JSON.stringify(report, "  ") + "\n")
    file.close()
    print("APPLICATION ICON NATIVE CAPTURE: production 128x128 source-backed project icon; no export")
    quit(0)
