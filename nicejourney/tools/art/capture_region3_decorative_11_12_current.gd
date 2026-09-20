extends SceneTree

const SHOWCASE: PackedScene = preload("res://src/world/region3/presentation/region3_town_visual_showcase.tscn")
const CASES: Array[Dictionary] = [
    {"id": 11, "position": Vector2(1632, 3168)},
    {"id": 12, "position": Vector2(1632, 2016)},
]
const EVIDENCE := "res://docs/evidence/renderer/region3-decorative-11-12-current.json"

func _init() -> void:
    call_deferred(&"_capture")

func _capture() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(640, 360)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var scene := SHOWCASE.instantiate()
    viewport.add_child(scene)
    var camera := scene.get_node_or_null("Camera2D") as Camera2D
    if camera == null:
        push_error("current Region3 showcase has no Camera2D")
        quit(1)
        return
    var records: Array[Dictionary] = []
    for record: Dictionary in CASES:
        var id: int = record["id"]
        var production := "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_%02d_v02.png" % id
        if not ResourceLoader.exists(production):
            push_error("missing current V02 texture: %s" % production)
            quit(1)
            return
        camera.position = record["position"] as Vector2
        camera.zoom = Vector2.ONE
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        var image := viewport.get_texture().get_image()
        var output := "res://docs/evidence/renderer/region3-decorative-%02d-native-current.png" % id
        var save_result := image.save_png(ProjectSettings.globalize_path(output))
        if image.get_size() != Vector2i(640, 360) or save_result != OK:
            push_error("cannot capture native-size Region3 decorative asset %d: pixels=%s save_error=%d" % [id, image.get_size(), save_result])
            quit(1)
            return
        records.append({
            "building_id": id,
            "production_texture": production,
            "production_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(production)),
            "image": output,
            "image_dimensions": [image.get_width(), image.get_height()],
            "camera_position": [int(camera.position.x), int(camera.position.y)],
            "camera_zoom": [1, 1],
        })
    var evidence := {
        "scope": "Fresh native-canvas renderer capture; source hash and visual acceptance remain separately audited",
        "godot_version": Engine.get_version_info().get("string", ""),
        "scene": SHOWCASE.resource_path,
        "records": records,
    }
    var file := FileAccess.open(EVIDENCE, FileAccess.WRITE)
    if file == null:
        push_error("cannot write Region3 renderer evidence metadata")
        quit(1)
        return
    file.store_string(JSON.stringify(evidence, "  ") + "\n")
    file.close()
    print("REGION3 DECORATIVE 11/12 NATIVE RENDERER CAPTURE: 2 x 640x360")
    quit(0)
