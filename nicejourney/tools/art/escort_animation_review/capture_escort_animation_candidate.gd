extends SceneTree

# Isolated native playback of an EXTERNALLY transferred, source-reviewed
# 320x32 derivative. Does not modify production profiles, art or manifests.
# Non-headless Godot GL Compatibility:
# --path nicejourney --script res://tools/art/escort_animation_review/capture_escort_animation_candidate.gd -- --candidate=res://path/to/verified_review_320x32.png

const LIVE: NpcVisualProfile = preload("res://src/world/npc/presentation/profiles/temporary_escort.tres")
const LIVE_PATH := "res://src/world/npc/presentation/profiles/temporary_escort.tres"
const ANCHOR := "res://assets/art/npc/escort_anchor_v01.png"
const ANCHOR_SHA := "2cfa01c99e1716c168a69aff61cda8593c9ebac7e06e4ba39aa23d764aafd84e"
const OUT := "res://tools/art/escort_animation_review/engine/"
const CANVAS := Vector2i(640, 360)
const REVIEW_STEP := 0.125  # Screenshot preview only; not an approved runtime cadence.

var _candidate := ""
var _profile: NpcVisualProfile
var _pages: Array[Dictionary] = []


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--candidate=") and _candidate.is_empty():
            _candidate = argument.trim_prefix("--candidate=")
        else:
            _fail("Pass exactly one --candidate=res://...png")
            return
    if not _candidate.begins_with("res://") or not _candidate.ends_with(".png") or _candidate.contains("..") or _candidate.contains("\\"):
        _fail("Missing explicit res:// candidate PNG path")
        return
    if _candidate == ANCHOR or _candidate.begins_with("res://assets/art/npc/") and not _candidate.contains("/review/"):
        _fail("Do not use production textures as review candidates")
        return
    if FileAccess.get_sha256(ProjectSettings.globalize_path(ANCHOR)) != ANCHOR_SHA or LIVE == null or LIVE.animation_library != null or LIVE.texture == null or LIVE.texture.get_size() != Vector2(32, 32) or not LIVE.validate_presentation().is_empty():
        _fail("Accepted static identity/profile changed")
        return
    if not FileAccess.file_exists(_candidate):
        _fail("Transferred derivative not available: " + _candidate)
        return
    if DisplayServer.get_name() == "headless" or String(ProjectSettings.get_setting("rendering/renderer/rendering_method")) != "gl_compatibility":
        _fail("Native non-headless GL Compatibility capture required")
        return

    var image := Image.load_from_file(ProjectSettings.globalize_path(_candidate))
    if image == null or image.is_empty() or image.get_size() != Vector2i(320, 32) or image.get_format() != Image.FORMAT_RGBA8:
        _fail("Expected externally reviewed 320x32 RGBA derivative, ten 32px cells")
        return
    _profile = NpcVisualProfile.new()
    _profile.role_id = &"npc:temporary_escort"
    _profile.texture = ImageTexture.create_from_image(image)
    _profile.animation_library = _library()
    var errors := _profile.validate_presentation()
    if not errors.is_empty():
        _fail("Existing escort intake rejects candidate: " + "; ".join(errors))
        return
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT)) != OK:
        _fail("Cannot create isolated review output folder")
        return

    root.size = CANVAS
    root.content_scale_size = CANVAS
    for state: String in ["idle", "walk"]:
        for zoom: int in [1, 2]:
            var page := await _page(state, zoom)
            if page.is_empty():
                quit(1)
                return
            _pages.append(page)
    var evidence := {
        "status": "REVIEW_ONLY_UNACCEPTED_NOT_LIVE",
        "original_generated_sources": "NOT_VERIFIED_HERE_REQUIRES_SEPARATE_TRANSFER_AND_PROVENANCE",
        "derivative": _candidate,
        "derivative_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(_candidate)),
        "static_identity": ANCHOR, "static_sha256": ANCHOR_SHA,
        "live_profile": LIVE_PATH,
        "live_profile_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(LIVE_PATH)),
        "production_profile_modified": false,
        "layout": "idle 0..3, walk 4..9; each cell 32x32; anchor (16,29); right-authored left-mirrored",
        "review_seconds_per_frame_not_approved_cadence": REVIEW_STEP,
        "engine": Engine.get_version_info().get("string", ""),
        "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
        "display_server": DisplayServer.get_name(), "viewport": [640, 360], "pages": _pages,
    }
    var output := FileAccess.open(OUT + "escort_animation_candidate_native_evidence.json", FileAccess.WRITE)
    if output == null:
        _fail("Cannot save review metadata")
        return
    output.store_string(JSON.stringify(evidence, "  ") + "\n")
    output.close()
    print("ESCORT REVIEW ONLY PASS pages=", _pages.size(), " derivative_sha256=", evidence["derivative_sha256"])
    quit(0)


func _library() -> AnimationLibrary:
    var result := AnimationLibrary.new()
    for state: String in ["idle", "walk"]:
        var first: int = 0 if state == "idle" else 4
        var count: int = 4 if state == "idle" else 6
        var clip := Animation.new()
        clip.length = float(count) * REVIEW_STEP
        clip.loop_mode = Animation.LOOP_LINEAR
        var track := clip.add_track(Animation.TYPE_VALUE)
        clip.track_set_path(track, NodePath("NpcSprite:frame"))
        clip.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
        for index: int in range(count):
            clip.track_insert_key(track, float(index) * REVIEW_STEP, first + index)
        result.add_animation(StringName(state), clip)
    return result


func _page(state: String, zoom: int) -> Dictionary:
    var viewport := SubViewport.new()
    viewport.size = CANVAS
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    root.add_child(viewport)
    var background := ColorRect.new()
    background.size = Vector2(CANVAS)
    background.color = Color("#282b36")
    viewport.add_child(background)
    _label(viewport, "ESCORT SOURCE REVIEW ONLY  |  " + state.to_upper() + "  |  " + str(zoom) + "x", Vector2(8, 8))
    _label(viewport, "RIGHT / authored", Vector2(8, 45))
    _label(viewport, "LEFT / mirrored", Vector2(8, 195))
    var count: int = 4 if state == "idle" else 6
    var first: int = 0 if state == "idle" else 4
    var start_x := 132.0 if count == 4 else 88.0
    var spacing := 120.0 if count == 4 else 100.0
    var samples: Array[Dictionary] = []
    for right: bool in [true, false]:
        var y := 128.0 if right else 280.0
        for index: int in range(count):
            var presenter := NpcVisualPresenter.new()
            presenter.profile = _profile
            presenter.facing_right = right
            presenter.scale = Vector2.ONE * zoom
            presenter.position = Vector2(start_x + float(index) * spacing, y)
            viewport.add_child(presenter)
            if presenter.sprite == null or presenter.animation_player == null or presenter.sprite.hframes != 10 or presenter.sprite.vframes != 1 or presenter.sprite.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
                _fail("Actual NPC presenter cannot display review-only candidate")
                viewport.queue_free()
                return {}
            presenter.set_semantic_state(&"follow" if state == "walk" else &"wait")
            presenter.animation_player.advance(0.0)
            presenter.animation_player.seek(float(index) * REVIEW_STEP, true)
            presenter.animation_player.pause()
            if presenter.sprite.frame != first + index or presenter.sprite.flip_h == right:
                _fail("Real animation/frame or direction mismatch: " + state + " " + str(index))
                viewport.queue_free()
                return {}
            _label(viewport, str(first + index), Vector2(presenter.position.x - 8, y + 32 * zoom))
            samples.append({
                "state": state, "frame": presenter.sprite.frame,
                "direction": "right" if right else "left", "zoom": zoom,
                "anchor_xy": [presenter.position.x, presenter.position.y],
                "flip_h": presenter.sprite.flip_h,
            })
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var screenshot := viewport.get_texture().get_image()
    var image_path := OUT + "escort_%s_%dx_native_review.png" % [state, zoom]
    if screenshot.is_empty() or screenshot.get_size() != CANVAS or screenshot.save_png(ProjectSettings.globalize_path(image_path)) != OK:
        _fail("Native GL candidate screenshot failed: " + image_path)
        viewport.queue_free()
        return {}
    var result := {
        "image": image_path, "image_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(image_path)),
        "state": state, "zoom": zoom, "samples": samples,
    }
    viewport.queue_free()
    await process_frame
    return result


func _label(parent: Node, value: String, at: Vector2) -> void:
    var label := Label.new()
    label.text = value
    label.position = at
    label.add_theme_font_size_override("font_size", 12)
    parent.add_child(label)


func _fail(reason: String) -> void:
    push_error("ESCORT REVIEW BLOCKED: " + reason)
    quit(1)
