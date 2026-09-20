extends SceneTree
## Native GL Player-scene review of real, previously unselected V04 source poses.
## Only local AnimationLibrary copies. No gameplay bindings or source edits.

const PLAYER: PackedScene = preload("res://src/player/player.tscn")
const OUT := "res://assets/art/player/animations/review_v04_full_source/engine/"
const STATES := ["block", "hit"]
const CLASSES := ["none", "melee"]
const SIZE := Vector2i(640, 360)

var _background: ColorRect
var _pages: Array[Dictionary] = []


func _init() -> void:
    call_deferred("_main")


func _main() -> void:
    if DisplayServer.get_name() == "headless" or String(ProjectSettings.get_setting("rendering/renderer/rendering_method")) != "gl_compatibility":
        push_error("Real Windows GL Compatibility viewport required")
        quit(1)
        return
    root.size = SIZE
    root.content_scale_size = SIZE
    _background = ColorRect.new()
    _background.color = Color(0.24, 0.24, 0.24, 1.0)
    _background.size = SIZE
    _background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(_background)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT)) != OK:
        push_error("Cannot make isolated full-source review directory")
        quit(1)
        return
    for state: String in STATES:
        for kind: String in CLASSES:
            for zoom: int in [1, 2]:
                var result: Dictionary = await _page(state, kind, zoom)
                if result.is_empty():
                    quit(1)
                    return
                _pages.append(result)
    var proof := {
        "schema": "player-v04-full-source-native-review/v1",
        "acceptance": "CANDIDATE_ONLY_SOURCE_POSES_NOT_ART_APPROVED_NOT_LIVE",
        "godot_version": Engine.get_version_info().get("string", ""),
        "display_server": DisplayServer.get_name(),
        "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
        "scene": PLAYER.resource_path,
        "live_library": "res://src/player/presentation/player_body_animation_library.tres",
        "live_library_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path("res://src/player/presentation/player_body_animation_library.tres")),
        "viewport": [640, 360], "background_rgb": [61, 61, 61],
        "page_count": _pages.size(), "pages": _pages,
    }
    var file := FileAccess.open(OUT + "player_v04_full_source_native_evidence.json", FileAccess.WRITE)
    if file == null:
        push_error("Cannot store V04 review evidence")
        quit(1)
        return
    file.store_string(JSON.stringify(proof, "  ") + "\n")
    file.close()
    print("V04 FULL SOURCE REAL GL PASS pages=", _pages.size(), " display=", DisplayServer.get_name())
    quit(0)


func _page(state: String, kind: String, zoom: int) -> Dictionary:
    var frame_count: int = 7 if state == "block" else 6
    var tex_path := "res://assets/art/player/animations/review_v04_full_source/player_%s_all_%d_generated_poses_v04_review_only.png" % [state, frame_count]
    var texture: Texture2D = load(tex_path) as Texture2D
    if texture == null or texture.get_size() != Vector2(32 * frame_count, 32):
        push_error("Invalid V04 source candidate: " + tex_path)
        return {}
    var fixtures: Array[Node] = []
    var labels: Array[Label] = []
    var samples: Array[Dictionary] = []
    for facing: int in range(2):
        var row_y: int = 100 + 140 * facing
        var label := Label.new()
        label.text = "%s generated source ALL %d\n%s %s %dx" % [state, frame_count, "LEFT" if facing else "RIGHT", kind, zoom]
        label.position = Vector2(4, row_y - 40)
        _background.add_child(label)
        labels.append(label)
        for index: int in range(frame_count):
            var player: PlayerController = PLAYER.instantiate() as PlayerController
            if player == null:
                push_error("Failed to instantiate actual Player")
                return {}
            _background.add_child(player)
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
            player.position = Vector2(170 + 64 * index, row_y)
            if kind != "none" and not player.configure_starter_visuals(StringName(kind)):
                push_error("Missing real equipped profile: " + kind)
                return {}
            player.apply_aim_direction(Vector2.LEFT if facing else Vector2.RIGHT)
            var animator := player.get_node("BodyAnimationPlayer") as AnimationPlayer
            if not _local_animation(animator, state, texture):
                push_error("Cannot clone isolated V04 candidate AnimationLibrary")
                return {}
            animator.play(StringName(state))
            animator.advance(0.0)
            animator.pause()
            var body := player.get_node("BodyVisual/Body") as Sprite2D
            if body.texture != texture or body.hframes != frame_count:
                push_error("Actual scene failed to select review texture")
                return {}
            body.frame = index
            samples.append({
                "frame": index, "facing": "left" if facing else "right",
                "player_xy": [player.position.x, player.position.y],
                "body_frame": body.frame, "body_hframes": body.hframes,
                "body_visual_scale": [player.body_visual.scale.x, player.body_visual.scale.y],
            })
    await process_frame
    await process_frame
    for i: int in range(fixtures.size()):
        var body: Sprite2D = fixtures[i].get_node("BodyVisual/Body") as Sprite2D
        if body.frame != int(samples[i]["frame"]) or body.texture.resource_path != tex_path:
            push_error("Native full-source pose drift")
            return {}
    await RenderingServer.frame_post_draw
    var screenshot: Image = root.get_texture().get_image()
    var image_path := OUT + "%s_%s_%dx.png" % [state, kind, zoom]
    if screenshot.is_empty() or screenshot.get_size() != SIZE or screenshot.save_png(ProjectSettings.globalize_path(image_path)) != OK:
        push_error("Full-source native image capture failed")
        return {}
    var page := {
        "state": state, "class": kind, "zoom": zoom, "frames": frame_count,
        "texture": tex_path, "texture_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(tex_path)),
        "image": image_path, "image_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(image_path)),
        "samples": samples,
    }
    print("V04 REAL SOURCE REVIEW ", state, " ", kind, " ", zoom, "x frames=", frame_count)
    for node: Node in fixtures:
        node.queue_free()
    for node: Label in labels:
        node.queue_free()
    await process_frame
    return page


func _local_animation(player_animation: AnimationPlayer, state: String, texture: Texture2D) -> bool:
    var original: AnimationLibrary = player_animation.get_animation_library(&"")
    if original == null or not original.has_animation(StringName(state)):
        return false
    var isolated := AnimationLibrary.new()
    for key: StringName in original.get_animation_list():
        var clip: Animation = original.get_animation(key).duplicate(true) as Animation
        if clip == null:
            return false
        if String(key) == state:
            var tex_track: int = clip.find_track(NodePath("BodyVisual/Body:texture"), Animation.TYPE_VALUE)
            var columns_track: int = clip.find_track(NodePath("BodyVisual/Body:hframes"), Animation.TYPE_VALUE)
            if tex_track < 0 or columns_track < 0:
                return false
            clip.track_set_key_value(tex_track, 0, texture)
            clip.track_set_key_value(columns_track, 0, texture.get_width() / 32)
        if isolated.add_animation(key, clip) != OK:
            return false
    player_animation.remove_animation_library(&"")
    return player_animation.add_animation_library(&"", isolated) == OK
