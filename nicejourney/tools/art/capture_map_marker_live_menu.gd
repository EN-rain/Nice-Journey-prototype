extends SceneTree

const MENU_SCENE: PackedScene = preload("res://src/ui/map_menu.tscn")
const SHEET := "res://assets/art/ui/markers/map_marker_quest_sigil_v02.png"
const SCREENSHOT := "res://docs/evidence/renderer/map-marker-live-menu-native.png"
const EVIDENCE := "res://docs/evidence/renderer/map-marker-live-menu-native.json"
const NAMES := ["Escort", "Defense", "Annihilation", "Sigil"]

func _init() -> void:
    call_deferred("_capture")


func _capture() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(640, 360)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    root.add_child(viewport)
    var background := ColorRect.new()
    background.size = Vector2(640, 360)
    background.color = Color("#202330")
    viewport.add_child(background)
    var input := InputOwnership.new()
    viewport.add_child(input)
    var menu := MENU_SCENE.instantiate() as MapMenu
    viewport.add_child(menu)
    await process_frame
    var profile := ProfileCreationService.create_profile(1, "Map marker renderer", "melee")
    if not menu.configure(profile, input) or not menu.open_menu() or not menu.select_layer(MapLayerIdentityValidator.LAYER_REGION_MAP):
        push_error("could not open actual Region map menu")
        quit(1)
        return
    var legend := menu.get_node("Overlay/Panel/Layout/Scroll/ScrollContent/MarkerLegend") as HBoxContainer
    var notice := menu.get_node("Overlay/Panel/Layout/Scroll/ScrollContent/MarkerNotice") as Label
    var cells: Array[Dictionary] = []
    for i: int in range(4):
        var icon := legend.get_node(NAMES[i] + "/Glyph") as TextureRect
        var label := legend.get_node(NAMES[i] + "/Text") as Label
        var atlas := icon.texture as AtlasTexture
        if not icon.is_visible_in_tree() or atlas == null or atlas.region != Rect2(i * 32, 0, 32, 32) or label.text != NAMES[i]:
            push_error("live map legend lost exact semantic glyph ownership")
            quit(1)
            return
        cells.append({"name": NAMES[i], "source_xyxy": [i * 32, 0, (i + 1) * 32, 32],
            "screen_xyxy": []})
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var seen_rects: Dictionary = {}
    for i: int in range(4):
        var icon := legend.get_node(NAMES[i] + "/Glyph") as TextureRect
        var rect := icon.get_global_rect()
        var screen_rect := [rect.position.x, rect.position.y, rect.end.x, rect.end.y]
        if seen_rects.has(str(screen_rect)) or rect.size != Vector2(32, 32) or rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > 640.0 or rect.end.y > 360.0:
            push_error("glyph is overlapped, clipped, or not native 32px on the actual 640x360 map menu")
            quit(1)
            return
        seen_rects[str(screen_rect)] = true
        cells[i]["screen_xyxy"] = screen_rect
    if not notice.is_visible_in_tree() or not notice.text.contains("locations unauthored"):
        push_error("read-only map legend notice is not visible")
        quit(1)
        return
    var screenshot := viewport.get_texture().get_image()
    if screenshot.get_size() != Vector2i(640, 360) or screenshot.save_png(ProjectSettings.globalize_path(SCREENSHOT)) != OK:
        push_error("failed to capture real 640x360 map menu")
        quit(1)
        return
    var evidence := {
        "scope": "Actual live MapMenu Region layer; four read-only glyphs and explicit unavailable-location/travel text, no authored marker positions",
        "engine": Engine.get_version_info().get("string", ""),
        "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
        "production_sheet": SHEET,
        "production_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(SHEET)),
        "screen": SCREENSHOT,
        "screen_size": [640, 360],
        "notice": notice.text,
        "source_cells": cells,
        "actual_quest_marker_count": (menu.current_layer_data().get("quest_markers", []) as Array).size(),
        "travel_action_in_map": false,
    }
    var file := FileAccess.open(EVIDENCE, FileAccess.WRITE)
    if file == null:
        push_error("could not save live map screenshot provenance")
        quit(1)
        return
    file.store_string(JSON.stringify(evidence, "  ") + "\n")
    file.close()
    print("MAP MARKER LIVE MENU CAPTURE: four source-linked glyphs / 640x360 / no map travel")
    quit(0)
