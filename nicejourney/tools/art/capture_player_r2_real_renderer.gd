extends SceneTree
## Actual non-headless Compatibility viewport renderer for all ten R2 candidates.
## Only allocates local AnimationLibrary copies and real player scene instances.
## Never edits the production AnimationLibrary or any accepted animation textures.

const PLAYER: PackedScene = preload("res://src/player/player.tscn")
const OUT := "res://assets/art/player/animations/review_r2_engine/"
const STATES: Array[String] = [
    "attack", "heavy_attack", "block", "parry", "cast", "hit",
    "interact", "use_item", "death", "dodge",
]
const SOURCE_SUFFIX := {
    "attack": "v04_r2_candidate", "heavy_attack": "v04_r2_candidate",
    "block": "v04_r2_candidate", "parry": "v04_r2_candidate",
    "cast": "v04_r2_candidate", "hit": "v04_r2_candidate",
    "interact": "v03_r2_candidate", "use_item": "v03_r2_candidate",
    "death": "v03_r2_candidate", "dodge": "v03_r2_candidate",
}
const CLASS_IDS: Array[String] = ["none", "melee", "ranged", "mage"]
const VIEWPORT_SIZE := Vector2i(640, 360)
const BACKGROUND := Color(0.24, 0.24, 0.24, 1.0)
const ROW_Y := [67, 139, 211, 283]
const ROW_STYLE := [
    {"revision": "live_v03", "facing": "right"},
    {"revision": "r2_candidate", "facing": "right"},
    {"revision": "live_v03", "facing": "left"},
    {"revision": "r2_candidate", "facing": "left"},
]

var _canvas: ColorRect = null
var _records: Array[Dictionary] = []


func _init() -> void:
    call_deferred("_capture_all")


func _capture_all() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Real Compatibility capture requires non-headless Godot")
        quit(1)
        return
    if String(ProjectSettings.get_setting("rendering/renderer/rendering_method")) != "gl_compatibility":
        push_error("Project does not use GL Compatibility renderer")
        quit(1)
        return
    root.size = VIEWPORT_SIZE
    root.content_scale_size = VIEWPORT_SIZE
    root.transparent_bg = false
    _canvas = ColorRect.new()
    _canvas.color = BACKGROUND
    _canvas.position = Vector2.ZERO
    _canvas.size = VIEWPORT_SIZE
    _canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(_canvas)
    var absolute_dir: String = ProjectSettings.globalize_path(OUT)
    if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
        push_error("Could not create player review directory")
        quit(1)
        return
    for state: String in STATES:
        for kind: String in CLASS_IDS:
            for scale_int: int in ([1, 2] if kind == "none" else [2]):
                var result: Dictionary = await _capture_page(state, kind, scale_int)
                if result.is_empty():
                    quit(1)
                    return
                _records.append(result)
    var manifest := {
        "schema": "nicejourney-player-r2-real-renderer/v1",
        "acceptance": "DIAGNOSTIC_ONLY_CANDIDATES_UNAPPROVED_NO_PRODUCTION_INTEGRATION",
        "renderer": "Godot GL Compatibility, non-headless, current root viewport",
        "godot_version": Engine.get_version_info().get("string", ""),
        "display_server": DisplayServer.get_name(),
        "project_rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
        "source_scene": PLAYER.resource_path,
        "production_library": "res://src/player/presentation/player_body_animation_library.tres",
        "production_library_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path("res://src/player/presentation/player_body_animation_library.tres")),
        "viewport_dimensions": [640, 360],
        "class_profiles": [
            "res://src/player/presentation/profiles/starter_weapon_melee.tres",
            "res://src/player/presentation/profiles/starter_weapon_ranged.tres",
            "res://src/player/presentation/profiles/starter_weapon_mage.tres",
        ],
        "record_count": _records.size(),
        "pages": _records,
    }
    var path: String = OUT + "player_r2_renderer_evidence.json"
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("Cannot write capture provenance: " + path)
        quit(1)
        return
    file.store_string(JSON.stringify(manifest, "  ") + "\n")
    file.close()
    print("PLAYER R2 REAL COMPATIBILITY RENDER PASS pages=", _records.size(), " display=", DisplayServer.get_name(), " path=", path)
    quit(0)


func _capture_page(state: String, kind: String, scale_int: int) -> Dictionary:
    var old_path := "res://assets/art/player/animations/player_body_%s_sheet_v03.png" % state
    var r2_path := "res://assets/art/player/animations/player_body_%s_sheet_%s.png" % [state, SOURCE_SUFFIX[state]]
    var live: Texture2D = load(old_path) as Texture2D
    var candidate: Texture2D = load(r2_path) as Texture2D
    if live == null or candidate == null or live.get_height() != 32 or candidate.get_height() != 32:
        push_error("Missing/invalid source texture: " + state)
        return {}
    var n: int = maxi(live.get_width(), candidate.get_width()) / 32
    if n > 7 or n < 3:
        push_error("Unsupported frame count: " + state)
        return {}
    var fixtures: Array[Node] = []
    var labels: Array[Label] = []
    var samples: Array[Dictionary] = []
    for row_index: int in range(4):
        var row: Dictionary = ROW_STYLE[row_index]
        var revised: bool = row["revision"] == "r2_candidate"
        var tex: Texture2D = candidate if revised else live
        var dir: Vector2 = Vector2.LEFT if row["facing"] == "left" else Vector2.RIGHT
        var label := Label.new()
        label.text = "%s %s\n%s %dx" % [state, "R2" if revised else "V03", "LEFT" if dir == Vector2.LEFT else "RIGHT", scale_int]
        label.position = Vector2(4, ROW_Y[row_index] - 34)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _canvas.add_child(label)
        labels.append(label)
        for index: int in range(n):
            if index >= tex.get_width() / 32:
                continue
            var player: PlayerController = PLAYER.instantiate() as PlayerController
            if player == null:
                push_error("Cannot instantiate player scene")
                _clear_page(fixtures, labels)
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
            player.scale = Vector2.ONE * float(scale_int)
            # At x=170 this gives seven 64px cells, ending at x=586.
            player.position = Vector2(170 + (index * 64 if scale_int == 2 else index * 32), ROW_Y[row_index])
            if kind != "none" and not player.configure_starter_visuals(StringName(kind)):
                push_error("Unable to configure player profile: " + kind)
                _clear_page(fixtures, labels)
                return {}
            player.apply_aim_direction(dir)
            var anim_player := player.get_node("BodyAnimationPlayer") as AnimationPlayer
            if revised and not _install_local_candidate_library(anim_player, state, candidate):
                push_error("Cannot clone candidate AnimationLibrary: " + state)
                _clear_page(fixtures, labels)
                return {}
            anim_player.play(StringName(state))
            anim_player.advance(0.0)
            # The renderer awaits several frames; without pause(), Godot's
            # AnimationPlayer overrides the manually selected index and a
            # screenshot falsely claims it shows source frame `index`.
            anim_player.pause()
            var body := player.get_node("BodyVisual/Body") as Sprite2D
            if body.texture != tex or body.hframes != tex.get_width() / 32:
                push_error("Real AnimationPlayer did not select expected texture/hframes: " + state)
                _clear_page(fixtures, labels)
                return {}
            body.frame = index
            var weapon := player.get_node("WeaponPivot/MainHand") as Sprite2D
            var shield := player.get_node("BodyVisual/ShieldVisual") as Sprite2D
            var source_hash := FileAccess.get_sha256(ProjectSettings.globalize_path(r2_path if revised else old_path))
            samples.append({
                "revision": row["revision"], "facing": row["facing"], "class": kind,
                "scale": scale_int, "frame": index, "row": row_index,
                "player_position_xy": [player.position.x, player.position.y],
                "texture": r2_path if revised else old_path,
                "texture_sha256": source_hash,
                "frame_count": body.hframes,
                "body_sprite_position_xy": [body.position.x, body.position.y],
                "body_visual_scale_xy": [player.body_visual.scale.x, player.body_visual.scale.y],
                "grip_global_position_xy": [player.grip_anchor.global_position.x, player.grip_anchor.global_position.y],
                "weapon_pivot_global_position_xy": [player.weapon_pivot.global_position.x, player.weapon_pivot.global_position.y],
                "weapon_pivot_rotation": player.weapon_pivot.rotation,
                "weapon_texture": weapon.texture.resource_path if weapon.texture != null else "",
                "weapon_position_xy": [weapon.position.x, weapon.position.y],
                "shield_visible": shield.visible and shield.texture != null,
                "shield_texture": shield.texture.resource_path if shield.texture != null else "",
                "shield_position_xy": [shield.position.x, shield.position.y],
            })
    await process_frame
    await process_frame
    for fixture_index: int in range(fixtures.size()):
        var subject: PlayerController = fixtures[fixture_index] as PlayerController
        var sample: Dictionary = samples[fixture_index]
        var sampled_body: Sprite2D = subject.get_node("BodyVisual/Body") as Sprite2D
        if sampled_body.frame != int(sample["frame"]) or sampled_body.texture.resource_path != String(sample["texture"]):
            push_error("Capture pose drift: %s/%s/%s/%s expected frame %d, got %d" % [state, kind, sample["revision"], sample["facing"], sample["frame"], sampled_body.frame])
            _clear_page(fixtures, labels)
            return {}
    await RenderingServer.frame_post_draw
    var picture: Image = root.get_texture().get_image()
    var output := OUT + "%s_%s_%dx.png" % [state, kind, scale_int]
    if picture.is_empty() or picture.get_size() != VIEWPORT_SIZE or picture.save_png(ProjectSettings.globalize_path(output)) != OK:
        push_error("Real renderer capture failed: " + output)
        _clear_page(fixtures, labels)
        return {}
    var evidence := {
        "state": state, "class": kind, "zoom": scale_int,
        "image": output,
        "image_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(output)),
        "dimensions": [picture.get_width(), picture.get_height()],
        "source_v03": old_path, "source_v03_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(old_path)),
        "candidate": r2_path, "candidate_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(r2_path)),
        "samples": samples,
    }
    print("PLAYER R2 REAL RENDER PAGE ", state, " ", kind, " ", scale_int, "x ", samples.size(), " samples ", output)
    _clear_page(fixtures, labels)
    await process_frame
    return evidence


func _install_local_candidate_library(player_animation: AnimationPlayer, state: String, texture: Texture2D) -> bool:
    var live_library: AnimationLibrary = player_animation.get_animation_library(&"")
    if live_library == null or not live_library.has_animation(StringName(state)):
        return false
    var isolated := AnimationLibrary.new()
    for name: StringName in live_library.get_animation_list():
        var clip: Animation = live_library.get_animation(name).duplicate(true) as Animation
        if clip == null:
            return false
        if String(name) == state:
            var texture_track: int = clip.find_track(NodePath("BodyVisual/Body:texture"), Animation.TYPE_VALUE)
            var columns_track: int = clip.find_track(NodePath("BodyVisual/Body:hframes"), Animation.TYPE_VALUE)
            if texture_track < 0 or columns_track < 0:
                return false
            clip.track_set_key_value(texture_track, 0, texture)
            clip.track_set_key_value(columns_track, 0, texture.get_width() / 32)
            # Existing hit clip may request a now-missing sixth frame; the
            # isolated review fixture still samples every actual R2 frame.
        if isolated.add_animation(name, clip) != OK:
            return false
    player_animation.remove_animation_library(&"")
    return player_animation.add_animation_library(&"", isolated) == OK


func _clear_page(fixtures: Array[Node], labels: Array[Label]) -> void:
    for node: Node in fixtures:
        node.queue_free()
    for label: Label in labels:
        label.queue_free()
