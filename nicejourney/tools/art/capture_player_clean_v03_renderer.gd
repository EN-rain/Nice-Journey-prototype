extends SceneTree
## Non-headless real player scene/GL Compatibility review for SEVEN live V03 states.
## No AnimationLibrary edits or copied candidate textures: live resource only.

const PLAYER: PackedScene = preload("res://src/player/player.tscn")
const STATES: Array[String] = ["idle", "walk", "run", "dash", "climb", "pickup", "sleep"]
const CLASSES: Array[String] = ["melee", "ranged", "mage"]
const OUTPUT := "res://assets/art/player/animations/review_clean_v03_engine/"
const ROW_Y := [105, 265]
const VIEWPORT := Vector2i(640, 360)


func _init() -> void:
    call_deferred("_capture_all")


func _capture_all() -> void:
    if DisplayServer.get_name() == "headless" or String(ProjectSettings.get_setting("rendering/renderer/rendering_method")) != "gl_compatibility":
        push_error("Requires REAL non-headless GL Compatibility renderer")
        quit(1)
        return
    root.size = VIEWPORT
    root.content_scale_size = VIEWPORT
    var background := ColorRect.new()
    background.color = Color(0.24, 0.24, 0.24)
    background.size = VIEWPORT
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(background)
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT)) != OK:
        push_error("Cannot create review output")
        quit(1)
        return
    var records: Array[Dictionary] = []
    for state: String in STATES:
        for class_id: String in CLASSES:
            for zoom: int in [1, 2]:
                for equipped: bool in [false, true]:
                    var page: Dictionary = await _page(background, state, class_id, zoom, equipped)
                    if page.is_empty():
                        quit(1)
                        return
                    records.append(page)
    var provenance := {
        "schema": "player-clean-v03-real-renderer/v1",
        "acceptance": "OBJECTIVE_NATIVE_RENDER_REVIEW_NOT_SUBJECTIVE_ART_APPROVAL",
        "display": DisplayServer.get_name(),
        "godot_version": Engine.get_version_info().get("string", ""),
        "rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
        "source_scene": PLAYER.resource_path,
        "production_library": "res://src/player/presentation/player_body_animation_library.tres",
        "production_library_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path("res://src/player/presentation/player_body_animation_library.tres")),
        "pages": records,
        "page_count": records.size(),
    }
    var path := OUTPUT + "clean_v03_real_renderer_evidence.json"
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("Cannot write provenance")
        quit(1)
        return
    file.store_string(JSON.stringify(provenance, "  ") + "\n")
    file.close()
    print("CLEAN PLAYER REAL COMPATIBILITY RENDER PASS pages=", records.size(), " path=", path)
    quit(0)


func _page(canvas: ColorRect, state: String, class_id: String, zoom: int, equipped: bool) -> Dictionary:
    var texture_path := "res://assets/art/player/animations/player_body_%s_sheet_v03.png" % state
    var source: Texture2D = load(texture_path) as Texture2D
    if source == null or source.get_height() != 32 or source.get_width() % 32 != 0:
        push_error("Invalid live source sheet: " + state)
        return {}
    var count: int = source.get_width() / 32
    if count < 4 or count > 6:
        push_error("Unexpected sheet frame count: " + state)
        return {}
    var nodes: Array[Node] = []
    var sample_records: Array[Dictionary] = []
    for row: int in range(2):
        var facing: String = "left" if row == 1 else "right"
        var direction: Vector2 = Vector2.LEFT if facing == "left" else Vector2.RIGHT
        var label := Label.new()
        label.text = "%s %s %s %dx" % [state, class_id if equipped else "BODY", facing.to_upper(), zoom]
        label.position = Vector2(3, ROW_Y[row] - 34)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        canvas.add_child(label)
        nodes.append(label)
        for index: int in range(count):
            var player: PlayerController = PLAYER.instantiate() as PlayerController
            if player == null:
                push_error("Cannot instance live Player scene")
                _clear(nodes)
                return {}
            canvas.add_child(player)
            nodes.append(player)
            player.camera.enabled = false
            player.camera.set_process(false)
            player.camera.set_physics_process(false)
            player.set_process(false)
            player.set_physics_process(false)
            player.body_animator.set_process(false)
            player.body_animator.set_physics_process(false)
            player.movement.set_physics_process(false)
            player.scale = Vector2.ONE * float(zoom)
            player.position = Vector2(170 + index * (64 if zoom == 2 else 32), ROW_Y[row])
            if equipped and not player.configure_starter_visuals(StringName(class_id)):
                push_error("Cannot configure actual class profile: " + class_id)
                _clear(nodes)
                return {}
            player.apply_aim_direction(direction)
            var animator: AnimationPlayer = player.get_node("BodyAnimationPlayer") as AnimationPlayer
            if not animator.has_animation(StringName(state)):
                push_error("Live library missing state " + state)
                _clear(nodes)
                return {}
            var clip: Animation = animator.get_animation(StringName(state))
            var frame_track: int = clip.find_track(NodePath("BodyVisual/Body:frame"), Animation.TYPE_VALUE)
            if frame_track < 0 or clip.track_get_key_count(frame_track) != count:
                push_error("Live animation does not key EVERY sheet frame for " + state)
                _clear(nodes)
                return {}
            for key: int in range(count):
                if int(clip.track_get_key_value(frame_track, key)) != key:
                    push_error("Wrong live animation frame key for " + state)
                    _clear(nodes)
                    return {}
            animator.play(StringName(state))
            animator.advance(0.0)
            animator.pause() # Freeze indexed frame while actual GPU draw is awaited.
            var body: Sprite2D = player.get_node("BodyVisual/Body") as Sprite2D
            if body.texture != source or body.hframes != count or body.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
                push_error("Live AnimationPlayer/Body Sprite2D did not bind expected NEAREST texture")
                _clear(nodes)
                return {}
            body.frame = index
            var hand: Sprite2D = player.get_node("WeaponPivot/MainHand") as Sprite2D
            var shield: Sprite2D = player.get_node("BodyVisual/ShieldVisual") as Sprite2D
            sample_records.append({
                "state": state, "frame": index, "frame_count": count,
                "class": class_id if equipped else "none", "facing": facing,
                "zoom": zoom, "row": row,
                "player_xy": [player.position.x, player.position.y],
                "source_texture": texture_path,
                "source_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(texture_path)),
                "body_sprite_xy": [body.position.x, body.position.y],
                "body_visual_scale_xy": [player.body_visual.scale.x, player.body_visual.scale.y],
                "grip_global_xy": [player.grip_anchor.global_position.x, player.grip_anchor.global_position.y],
                "pivot_global_xy": [player.weapon_pivot.global_position.x, player.weapon_pivot.global_position.y],
                "pivot_rotation": player.weapon_pivot.rotation,
                "hand_texture": hand.texture.resource_path if hand.texture != null else "",
                "hand_local_xy": [hand.position.x, hand.position.y],
                "shield_visible": shield.visible and shield.texture != null,
                "shield_texture": shield.texture.resource_path if shield.texture != null else "",
            })
    await process_frame
    await process_frame
    for node: Node in nodes:
        if node is PlayerController:
            var actor := node as PlayerController
            var body: Sprite2D = actor.get_node("BodyVisual/Body") as Sprite2D
            var expected: Dictionary = sample_records.filter(func(x: Dictionary) -> bool: return x["player_xy"] == [actor.position.x, actor.position.y])[0]
            if body.frame != int(expected["frame"]) or body.texture != source:
                push_error("Frame advanced during capture for " + state)
                _clear(nodes)
                return {}
    await RenderingServer.frame_post_draw
    var picture: Image = root.get_texture().get_image()
    var output := OUTPUT + "%s_%s_%s_%dx.png" % [state, class_id, "equipped" if equipped else "body", zoom]
    if picture.get_size() != VIEWPORT or picture.save_png(ProjectSettings.globalize_path(output)) != OK:
        push_error("No true renderer frame readback")
        _clear(nodes)
        return {}
    var result := {
        "state": state, "class": class_id, "zoom": zoom, "equipped": equipped,
        "image": output,
        "image_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(output)),
        "dimensions": [640, 360], "source": texture_path,
        "source_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(texture_path)),
        "samples": sample_records,
    }
    print("CLEAN PLAYER REAL RENDER PAGE ", state, " ", class_id, " ", zoom, "x equipped=", equipped, " frames=", count)
    _clear(nodes)
    await process_frame
    return result


func _clear(nodes: Array[Node]) -> void:
    for node: Node in nodes:
        node.queue_free()
