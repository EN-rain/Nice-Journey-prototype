extends SceneTree
## Review-only real Player scene: production V03 interact vs R3 body + detached source sparks.
## Do not mutate any production AnimationLibrary, texture, frame clock, or game scene.

const PLAYER: PackedScene = preload("res://src/player/player.tscn")
const BASE := "res://assets/art/player/animations/"
const OUT := BASE + "review_r3/live_v03_interact_comparison/"
const LIVE := BASE + "player_body_interact_sheet_v03.png"
const R3_BODY := BASE + "review_r3/player_interact_body_v03_r3_detached_candidate.png"
const R3_FX := BASE + "review_r3/player_interact_vfx_v03_r3_detached_candidate.png"
const PRODUCTION_LIBRARY := "res://src/player/presentation/player_body_animation_library.tres"
const EXPECTED_LIVE_SHA := "6df0a03f1b64154ca3ec3e36093167fa0778335cf6aeb83cf4ea88b444f05443"
const EXPECTED_R3_BODY_SHA := "30ed5bb9f47b4c741cc97987cd2f64a9025bb80944814097114a261fba607802"
const EXPECTED_R3_FX_SHA := "23d3f59f81392e67e21c14a76794e4451bc136dba5d90365612b189d50548690"
const VIEWPORT := Vector2i(640, 360)
const ROW_Y := [67, 139, 211, 283]
const COUNT := 5

var _canvas: ColorRect
var _pages: Array[Dictionary] = []


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if DisplayServer.get_name() == "headless" or String(ProjectSettings.get_setting("rendering/renderer/rendering_method")) != "gl_compatibility":
        push_error("Interact comparison requires native GL Compatibility rendering")
        quit(1)
        return
    if FileAccess.get_sha256(ProjectSettings.globalize_path(LIVE)) != EXPECTED_LIVE_SHA \
            or FileAccess.get_sha256(ProjectSettings.globalize_path(R3_BODY)) != EXPECTED_R3_BODY_SHA \
            or FileAccess.get_sha256(ProjectSettings.globalize_path(R3_FX)) != EXPECTED_R3_FX_SHA:
        push_error("Source or review texture changed; fail closed before creating evidence")
        quit(1)
        return
    var live: Texture2D = load(LIVE) as Texture2D
    var body: Texture2D = load(R3_BODY) as Texture2D
    var sparks: Texture2D = load(R3_FX) as Texture2D
    if live == null or body == null or sparks == null \
            or live.get_size() != Vector2(COUNT * 32, 32) \
            or body.get_size() != live.get_size() or sparks.get_size() != live.get_size():
        push_error("Five-frame production and review textures must have the same 160x32 geometry")
        quit(1)
        return

    root.size = VIEWPORT
    root.content_scale_size = VIEWPORT
    root.transparent_bg = false
    _canvas = ColorRect.new()
    _canvas.color = Color(0.24, 0.24, 0.24, 1.0)
    _canvas.size = VIEWPORT
    _canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(_canvas)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT)) != OK:
        push_error("Cannot create review-only capture output directory")
        quit(1)
        return
    for kind: String in ["none", "melee"]:
        for zoom: int in [1, 2]:
            var page := await _page(kind, zoom, live, body, sparks)
            if page.is_empty():
                quit(1)
                return
            _pages.append(page)
    var evidence := {
        "schema": "player-interact-live-v03-versus-r3-native-review/v1",
        "acceptance": "REVIEW_ONLY_NOT_PRODUCTION_OR_ART_ACCEPTED",
        "engine_version": Engine.get_version_info().get("string", ""),
        "display_server": DisplayServer.get_name(),
        "rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
        "scene": PLAYER.resource_path,
        "production_library": PRODUCTION_LIBRARY,
        "production_library_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(PRODUCTION_LIBRARY)),
        "source_live": LIVE,
        "source_live_sha256": EXPECTED_LIVE_SHA,
        "source_r3_body": R3_BODY,
        "source_r3_body_sha256": EXPECTED_R3_BODY_SHA,
        "source_r3_vfx": R3_FX,
        "source_r3_vfx_sha256": EXPECTED_R3_FX_SHA,
        "background_rgb": [61, 61, 61],
        "dimensions": [640, 360],
        "frame_count": COUNT,
        "page_count": _pages.size(),
        "pages": _pages,
    }
    var output := FileAccess.open(OUT + "player_interact_live_v03_r3_native_evidence.json", FileAccess.WRITE)
    if output == null:
        push_error("Cannot write review-only evidence")
        quit(1)
        return
    output.store_string(JSON.stringify(evidence, "  ") + "\n")
    output.close()
    print("PLAYER INTERACT REAL LIVE-V03 VS R3 PAGES=", _pages.size())
    quit(0)


func _page(kind: String, zoom: int, live: Texture2D, body: Texture2D, sparks: Texture2D) -> Dictionary:
    var actors: Array[PlayerController] = []
    var labels: Array[Label] = []
    var samples: Array[Dictionary] = []
    for row: int in range(4):
        var split: bool = row == 1 or row == 3
        var left: bool = row >= 2
        var label := Label.new()
        label.text = "INTERACT %s\n%s %dx" % ["R3+FX" if split else "LIVE V03", "LEFT" if left else "RIGHT", zoom]
        label.position = Vector2(4, ROW_Y[row] - 34)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _canvas.add_child(label)
        labels.append(label)
        for frame: int in range(COUNT):
            var actor: PlayerController = PLAYER.instantiate() as PlayerController
            if actor == null:
                push_error("Failed to instantiate production Player scene")
                return {}
            _canvas.add_child(actor)
            actors.append(actor)
            actor.camera.enabled = false
            actor.camera.set_process(false)
            actor.camera.set_physics_process(false)
            actor.set_process(false)
            actor.set_physics_process(false)
            actor.body_animator.set_process(false)
            actor.body_animator.set_physics_process(false)
            actor.movement.set_physics_process(false)
            actor.scale = Vector2.ONE * zoom
            actor.position = Vector2(170 + 64 * frame, ROW_Y[row])
            if kind == "melee" and not actor.configure_starter_visuals(&"melee"):
                push_error("Could not bind actual melee starter visual")
                return {}
            actor.apply_aim_direction(Vector2.LEFT if left else Vector2.RIGHT)
            var anim := actor.get_node("BodyAnimationPlayer") as AnimationPlayer
            if split and not _isolate_review_interact(anim, body):
                push_error("Cannot isolate R3 review; production library must stay bound on live row")
                return {}
            anim.play(&"interact")
            anim.advance(0.0)
            anim.pause()
            var sprite := actor.get_node("BodyVisual/Body") as Sprite2D
            if sprite.texture != (body if split else live) or sprite.hframes != COUNT:
                push_error("AnimationPlayer did not choose the expected production/review texture")
                return {}
            sprite.frame = frame
            if split:
                var effect := Sprite2D.new()
                effect.name = "ReviewOnlyDetachedSparks"
                effect.position = sprite.position
                effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                effect.texture = sparks
                effect.hframes = COUNT
                effect.frame = frame
                actor.body_visual.add_child(effect)
            samples.append({
                "row": row, "frame": frame, "revision": "r3_body_and_source_sparks" if split else "live_v03",
                "facing": "left" if left else "right", "zoom": zoom,
                "player_xy": [actor.position.x, actor.position.y],
                "body_path": R3_BODY if split else LIVE,
                "body_sha256": EXPECTED_R3_BODY_SHA if split else EXPECTED_LIVE_SHA,
                "effect_path": R3_FX if split else "",
                "effect_sha256": EXPECTED_R3_FX_SHA if split else "",
                "body_frame": sprite.frame, "body_hframes": sprite.hframes,
                "body_visual_scale": [actor.body_visual.scale.x, actor.body_visual.scale.y],
            })
    await process_frame
    await process_frame
    for i: int in range(actors.size()):
        var sprite := actors[i].get_node("BodyVisual/Body") as Sprite2D
        if sprite.frame != int(samples[i]["frame"]) or sprite.texture.resource_path != String(samples[i]["body_path"]):
            push_error("Live-versus-R3 interact review frame drift")
            return {}
    await RenderingServer.frame_post_draw
    var screenshot := root.get_texture().get_image()
    var path := OUT + "interact_%s_%dx.png" % [kind, zoom]
    if screenshot.is_empty() or screenshot.get_size() != VIEWPORT or screenshot.save_png(ProjectSettings.globalize_path(path)) != OK:
        push_error("Native interact screenshot capture failed")
        return {}
    var page := {
        "state": "interact", "class": kind, "zoom": zoom,
        "image": path, "image_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(path)),
        "frames": COUNT, "samples": samples,
    }
    print("INTERACT LIVE V03 vs R3 REAL PLAYER ", kind, " ", zoom, "x")
    for actor: PlayerController in actors:
        actor.queue_free()
    for label: Label in labels:
        label.queue_free()
    await process_frame
    return page


func _isolate_review_interact(anim: AnimationPlayer, texture: Texture2D) -> bool:
    var original: AnimationLibrary = anim.get_animation_library(&"")
    if original == null or not original.has_animation(&"interact"):
        return false
    var copied := AnimationLibrary.new()
    for key: StringName in original.get_animation_list():
        var clip := original.get_animation(key).duplicate(true) as Animation
        if clip == null:
            return false
        if key == &"interact":
            var track := clip.find_track(NodePath("BodyVisual/Body:texture"), Animation.TYPE_VALUE)
            var columns := clip.find_track(NodePath("BodyVisual/Body:hframes"), Animation.TYPE_VALUE)
            if track < 0 or columns < 0 or clip.track_get_key_count(track) != 1:
                return false
            clip.track_set_key_value(track, 0, texture)
            clip.track_set_key_value(columns, 0, COUNT)
        if copied.add_animation(key, clip) != OK:
            return false
    anim.remove_animation_library(&"")
    return anim.add_animation_library(&"", copied) == OK
