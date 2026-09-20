extends SceneTree

# Renderer-only control: exercise exact Inspector-owned scenes without gameplay,
# collision, action timing, camera following or projectile despawn.
const RANGED: PackedScene = preload("res://src/combat/skills/player_arrow_projectile_v02.tscn")
const MAGE: PackedScene = preload("res://src/combat/skills/player_arcane_projectile_v02.tscn")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    if DisplayServer.get_name() == "headless":
        print("STATIC PROJECTILE RENDERER SKIP: needs native framebuffer")
        quit(0)
        return
    for class_id: String in ["ranged", "mage"]:
        await _capture(class_id, RANGED if class_id == "ranged" else MAGE)
    if _failures == 0:
        print("STATIC PROJECTILE NATIVE RENDERER TEST PASS")
    else:
        push_error("STATIC PROJECTILE NATIVE RENDERER TEST FAILURES: %d" % _failures)
    quit(_failures)


func _capture(class_id: String, scene: PackedScene) -> void:
    var stage := Node2D.new()
    stage.name = "StaticProjectileStage"
    root.add_child(stage)
    var backing := ColorRect.new()
    backing.name = "MeasuredGameplayBackground"
    backing.size = Vector2(640, 360)
    backing.color = Color8(23, 24, 27)
    backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(backing)
    var visual := scene.instantiate() as Node2D
    stage.add_child(visual)
    visual.position = Vector2(250, 180)
    var sprite := visual.get_node_or_null("Body") as Sprite2D
    _expect(sprite != null and sprite.texture != null, "%s static scene has loaded Sprite2D" % class_id)
    if sprite != null:
        _expect(sprite.is_visible_in_tree(), "%s static Sprite2D visible in tree" % class_id)
        print("STATIC PROJECTILE STATE: %s local=%s global=%s canvas=%s offset=%s modulate=%s self_modulate=%s viewport=%s" %
            [class_id, visual.position, visual.global_position,
             sprite.get_global_transform_with_canvas().origin, sprite.offset,
             sprite.modulate, sprite.self_modulate, root.get_viewport().get_visible_rect()])
    for _frame: int in 3:
        await process_frame
    RenderingServer.force_draw(true)
    var image := root.get_viewport().get_texture().get_image()
    _expect(image != null and not image.is_empty(), "%s static native framebuffer present" % class_id)
    if image != null and not image.is_empty():
        var path := "res://artifacts/combat/player_projectile_%s_v02_static_renderer_evidence.png" % class_id
        _expect(DirAccess.make_dir_recursive_absolute("res://artifacts/combat") == OK, "static capture destination present")
        _expect(image.save_png(path) == OK, "%s static framebuffer saved" % class_id)
        print("STATIC PROJECTILE RENDERER EVIDENCE: %s %dx%d" % [path, image.get_width(), image.get_height()])
    stage.queue_free()
    await process_frame


func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
