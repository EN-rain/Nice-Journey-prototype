extends SceneTree

const SOURCE := "res://assets/art/ui/markers/review/map_marker_quest_sigil_v02_candidate.png"
const OUTPUT := "res://docs/evidence/renderer/map-marker-quest-sigil-candidate-native.png"
const EVIDENCE := "res://docs/evidence/renderer/map-marker-quest-sigil-candidate-native.json"
const LABELS := ["Escort", "Tower Defense", "Annihilation", "Tower Sigil"]
const CENTER_X := [96, 240, 384, 528]
const CENTER_Y := 144


func _init() -> void:
    call_deferred(&"_capture")


func _capture() -> void:
    var sheet := load(SOURCE) as Texture2D
    if sheet == null or sheet.get_size() != Vector2(128, 32):
        push_error("source-linked map candidate is not the expected 128x32 RGBA sheet")
        quit(1)
        return
    var viewport := SubViewport.new()
    viewport.size = Vector2i(640, 360)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    root.add_child(viewport)
    var background := ColorRect.new()
    background.size = Vector2(640, 360)
    background.color = Color("#202330")
    viewport.add_child(background)

    var native_rectangles: Array[Dictionary] = []
    for i: int in range(4):
        var icon := Sprite2D.new()
        icon.texture = sheet
        icon.region_enabled = true
        icon.region_rect = Rect2(i * 32, 0, 32, 32)
        icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        icon.position = Vector2(CENTER_X[i], CENTER_Y)
        viewport.add_child(icon)
        var label := Label.new()
        label.text = LABELS[i]
        label.position = Vector2(CENTER_X[i] - 54, 186)
        label.custom_minimum_size = Vector2(108, 24)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        viewport.add_child(label)
        native_rectangles.append({
            "semantic": LABELS[i],
            "source_xyxy": [i * 32, 0, (i + 1) * 32, 32],
            "native_screen_xyxy": [CENTER_X[i] - 16, CENTER_Y - 16, CENTER_X[i] + 16, CENTER_Y + 16],
        })
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var screenshot := viewport.get_texture().get_image()
    if screenshot.get_size() != Vector2i(640, 360) or screenshot.save_png(ProjectSettings.globalize_path(OUTPUT)) != OK:
        push_error("failed to write native 640x360 map candidate capture")
        quit(1)
        return
    var evidence := {
        "status": "REVIEW_ONLY_NOT_ACCEPTED",
        "scope": "Four 32x32 glyphs from 128x32 candidate sampled on real GL Compatibility 640x360 renderer; no live map semantics or quest-marker coordinates implied",
        "godot_version": Engine.get_version_info().get("string", ""),
        "candidate": SOURCE,
        "candidate_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(SOURCE)),
        "image": OUTPUT,
        "size": [640, 360],
        "cells": native_rectangles,
    }
    var file := FileAccess.open(EVIDENCE, FileAccess.WRITE)
    if file == null:
        push_error("failed to write map review capture metadata")
        quit(1)
        return
    file.store_string(JSON.stringify(evidence, "  ") + "\n")
    file.close()
    print("MAP MARKER CANDIDATE NATIVE REVIEW CAPTURE: 4 cells, 640x360")
    quit(0)
