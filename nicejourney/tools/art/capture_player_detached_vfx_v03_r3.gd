extends SceneTree
## Isolated real-player GL review. No edits to production resources or R2 captures.

const PLAYER: PackedScene = preload("res://src/player/player.tscn")
const OUT := "res://assets/art/player/animations/review_r3/engine/"
const STATES: Array[String] = ["interact", "use_item"]
const CLASSES: Array[String] = ["none", "melee"]
const VIEWPORT := Vector2i(640, 360)
const ROW_Y := [67, 139, 211, 283]
const BG := Color(0.24, 0.24, 0.24, 1.0)

var _canvas: ColorRect
var _pages: Array[Dictionary] = []


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if DisplayServer.get_name() == "headless" or String(ProjectSettings.get_setting("rendering/renderer/rendering_method")) != "gl_compatibility":
        push_error("R3 needs real non-headless GL Compatibility rendering")
        quit(1)
        return
    root.size = VIEWPORT
    root.content_scale_size = VIEWPORT
    root.transparent_bg = false
    _canvas = ColorRect.new()
    _canvas.color = BG
    _canvas.size = VIEWPORT
    _canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(_canvas)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT)) != OK:
        push_error("Cannot create bounded R3 review directory")
        quit(1)
        return
    for state: String in STATES:
        for kind: String in CLASSES:
            for zoom: int in [1, 2]:
                var page: Dictionary = await _page(state, kind, zoom)
                if page.is_empty():
                    quit(1)
                    return
                _pages.append(page)
    var provenance := {
        "schema": "player-detached-vfx-r3-native-review/v1",
        "acceptance": "DIAGNOSTIC_ONLY_NOT_RUNTIME_BOUND_OR_ART_ACCEPTED",
        "display_server": DisplayServer.get_name(),
        "rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
        "engine_version": Engine.get_version_info().get("string", ""),
        "scene": PLAYER.resource_path,
        "production_library": "res://src/player/presentation/player_body_animation_library.tres",
        "production_library_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path("res://src/player/presentation/player_body_animation_library.tres")),
        "dimensions": [640, 360],
        "background_rgb": [61, 61, 61],
        "page_count": _pages.size(),
        "pages": _pages,
    }
    var evidence_file := FileAccess.open(OUT + "player_r3_native_evidence.json", FileAccess.WRITE)
    if evidence_file == null:
        push_error("Cannot write R3 renderer evidence")
        quit(1)
        return
    evidence_file.store_string(JSON.stringify(provenance, "  ") + "\n")
    evidence_file.close()
    print("PLAYER R3 ACTUAL GL REVIEW pages=", _pages.size(), " display=", DisplayServer.get_name())
    quit(0)


func _page(state: String, kind: String, zoom: int) -> Dictionary:
    var origin_path := "res://assets/art/player/animations/player_body_%s_sheet_v03_r2_candidate.png" % state
    var body_path := "res://assets/art/player/animations/review_r3/player_%s_body_v03_r3_detached_candidate.png" % state
    var effect_path := "res://assets/art/player/animations/review_r3/player_%s_vfx_v03_r3_detached_candidate.png" % state
    var origin: Texture2D = load(origin_path) as Texture2D
    var revised: Texture2D = load(body_path) as Texture2D
    var effect: Texture2D = load(effect_path) as Texture2D
    if origin == null or revised == null or effect == null or origin.get_size() != revised.get_size() or origin.get_size() != effect.get_size() or origin.get_height() != 32:
        push_error("R3 source texture geometry is invalid for " + state)
        return {}
    var count: int = origin.get_width() / 32
    if count != (5 if state == "interact" else 7):
        push_error("R3 source frame count is unexpected")
        return {}
    var fixtures: Array[Node] = []
    var labels: Array[Label] = []
    var samples: Array[Dictionary] = []
    for row_index: int in range(4):
        var is_r3: bool = row_index == 1 or row_index == 3
        var left: bool = row_index >= 2
        var label := Label.new()
        label.text = "%s %s\n%s %dx" % [state, "R3+FX" if is_r3 else "R2", "LEFT" if left else "RIGHT", zoom]
        label.position = Vector2(4, ROW_Y[row_index] - 34)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _canvas.add_child(label)
        labels.append(label)
        for frame_index: int in range(count):
            var player: PlayerController = PLAYER.instantiate() as PlayerController
            if player == null:
                push_error("Failed to instantiate actual player scene")
                return {}
            _canvas.add_child(player)
            fixtures.append(player)
            player.camera.enabled = false
            player.camera.set_process(false)
            player.camera.set_physics_process(false)
            player.set_process(false)
            player.set_physics_process(false)
            player.body_animator.set_process(false)
            player.body_animator.set_physics_process(false)
            player.movement.set_physics_process(false)
            player.scale = Vector2.ONE * zoom
            player.position = Vector2(170 + 64 * frame_index, ROW_Y[row_index])
            if kind != "none" and not player.configure_starter_visuals(StringName(kind)):
                push_error("R3 could not configure real starter visual " + kind)
                return {}
            player.apply_aim_direction(Vector2.LEFT if left else Vector2.RIGHT)
            var anim := player.get_node("BodyAnimationPlayer") as AnimationPlayer
            var texture := revised if is_r3 else origin
            if not _isolated_library(anim, state, texture):
                push_error("R3 cannot isolate review AnimationLibrary")
                return {}
            anim.play(StringName(state))
            anim.advance(0.0)
            anim.pause()
            var body := player.get_node("BodyVisual/Body") as Sprite2D
            if body.texture != texture or body.hframes != count:
                push_error("R3 real AnimationPlayer did not select candidate texture")
                return {}
            body.frame = frame_index
            if is_r3:
                var fx := Sprite2D.new()
                fx.name = "ReviewOnlyDetachedEffect"
                fx.position = body.position
                fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                fx.texture = effect
                fx.hframes = count
                fx.frame = frame_index
                player.body_visual.add_child(fx)
            samples.append({
                "row": row_index, "frame": frame_index,
                "revision": "r3_plus_detached_effect" if is_r3 else "r2_original",
                "facing": "left" if left else "right", "zoom": zoom,
                "player_xy": [player.position.x, player.position.y],
                "body_path": body_path if is_r3 else origin_path,
                "body_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(body_path if is_r3 else origin_path)),
                "effect_path": effect_path if is_r3 else "",
                "effect_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(effect_path)) if is_r3 else "",
                "body_frame": body.frame, "body_hframes": body.hframes,
                "body_visual_scale": [player.body_visual.scale.x, player.body_visual.scale.y],
            })
    await process_frame
    await process_frame
    for i: int in range(fixtures.size()):
        var actual_body := fixtures[i].get_node("BodyVisual/Body") as Sprite2D
        if actual_body.frame != int(samples[i]["frame"]) or actual_body.texture.resource_path != String(samples[i]["body_path"]):
            push_error("R3 renderer sample drift")
            return {}
    await RenderingServer.frame_post_draw
    var screenshot := root.get_texture().get_image()
    var output_path := OUT + "%s_%s_%dx.png" % [state, kind, zoom]
    if screenshot.is_empty() or screenshot.get_size() != VIEWPORT or screenshot.save_png(ProjectSettings.globalize_path(output_path)) != OK:
        push_error("R3 screenshot failed")
        return {}
    var page := {
        "state": state, "class": kind, "zoom": zoom, "image": output_path,
        "image_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(output_path)),
        "r2_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(origin_path)),
        "r3_body_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(body_path)),
        "r3_effect_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(effect_path)),
        "frames": count, "samples": samples,
    }
    print("R3 REAL PLAYER PAGE ", state, " ", kind, " ", zoom, "x frames=", count)
    for item: Node in fixtures:
        item.queue_free()
    for item: Label in labels:
        item.queue_free()
    await process_frame
    return page


func _isolated_library(anim: AnimationPlayer, state: String, texture: Texture2D) -> bool:
    var original: AnimationLibrary = anim.get_animation_library(&"")
    if original == null or not original.has_animation(StringName(state)):
        return false
    var copied := AnimationLibrary.new()
    for key: StringName in original.get_animation_list():
        var clip := original.get_animation(key).duplicate(true) as Animation
        if clip == null:
            return false
        if String(key) == state:
            var tex_track: int = clip.find_track(NodePath("BodyVisual/Body:texture"), Animation.TYPE_VALUE)
            var columns_track: int = clip.find_track(NodePath("BodyVisual/Body:hframes"), Animation.TYPE_VALUE)
            if tex_track < 0 or columns_track < 0:
                return false
            clip.track_set_key_value(tex_track, 0, texture)
            clip.track_set_key_value(columns_track, 0, texture.get_width() / 32)
        if copied.add_animation(key, clip) != OK:
            return false
    anim.remove_animation_library(&"")
    return anim.add_animation_library(&"", copied) == OK
