extends SceneTree

const SHOWCASE: PackedScene = preload("res://src/world/region3/presentation/region3_town_visual_showcase.tscn")
const CAPTURES: Array[Dictionary] = [
    {
        "path": "res://docs/evidence/renderer/region3-authored-town-layout-v02-decorative-batch2-staged.png",
        "position": Vector2(2560, 2560),
        "zoom": Vector2(0.12, 0.12),
    },
    {
        "path": "res://docs/evidence/renderer/region3-batch2-town-detail-staged.png",
        "position": Vector2(2560, 2600),
        "zoom": Vector2(0.28, 0.28),
    },
    {
        "path": "res://docs/evidence/renderer/region3-batch2-ruins-detail-staged.png",
        "position": Vector2(2400, 1050),
        "zoom": Vector2(0.34, 0.34),
    },
    {
        "path": "res://docs/evidence/renderer/region3-batch2-outskirts-detail-staged.png",
        "position": Vector2(2560, 4050),
        "zoom": Vector2(0.34, 0.34),
    },
    {
        "path": "res://docs/evidence/renderer/region3-batch2-risk-detail-staged.png",
        "position": Vector2(4100, 2450),
        "zoom": Vector2(0.20, 0.20),
    },
    {
        "path": "res://docs/evidence/renderer/region3-decorative-11-gameplay-review.png",
        "position": Vector2(1632, 3168),
        "zoom": Vector2(0.34, 0.34),
    },
    {
        "path": "res://docs/evidence/renderer/region3-decorative-12-gameplay-review.png",
        "position": Vector2(1632, 2016),
        "zoom": Vector2(0.34, 0.34),
    },
]

func _init() -> void:
    call_deferred(&"_capture")

func _capture() -> void:
    var scene := SHOWCASE.instantiate()
    root.add_child(scene)
    var camera := scene.get_node_or_null("Camera2D") as Camera2D
    if camera == null:
        push_error("Region 3 V02 showcase capture requires Camera2D")
        quit(1)
        return

    await process_frame
    await process_frame
    await process_frame

    for capture: Dictionary in CAPTURES:
        camera.position = capture["position"] as Vector2
        camera.zoom = capture["zoom"] as Vector2
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        var output_path := String(capture["path"])
        var error := image.save_png(ProjectSettings.globalize_path(output_path))
        if error != OK:
            push_error("Region 3 V02 showcase capture failed for %s: %d" % [output_path, error])
            quit(error)
            return
        print("REGION3_V02_CAPTURE:%s:%dx%d" % [output_path, image.get_width(), image.get_height()])

    quit(0)
