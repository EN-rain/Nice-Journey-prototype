extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    _expect(gameplay != null, "gameplay scene instantiates for inspector-authoring validation")
    if gameplay != null:
        gameplay.world_canvas_size = Vector2i(640, 360)
        gameplay.grid_cell_size = 32
        gameplay.background_color = Color(0.08, 0.09, 0.12, 1.0)
        gameplay.grid_color = Color(0.14, 0.15, 0.19, 1.0)
        gameplay.grid_line_width = 1.0
        root.add_child(gameplay)
        await process_frame
        _expect(gameplay.world_canvas_size == Vector2i(640, 360), "world canvas size is inspector editable")
        _expect(gameplay.grid_cell_size == 32, "greybox grid cell size is inspector editable")
        _expect(gameplay.background_color.is_equal_approx(Color(0.08, 0.09, 0.12, 1.0)), "greybox background color is inspector editable")
        _expect(gameplay.grid_color.is_equal_approx(Color(0.14, 0.15, 0.19, 1.0)), "greybox grid color is inspector editable")
        _expect(is_equal_approx(gameplay.grid_line_width, 1.0), "greybox grid line width is inspector editable")
        gameplay.queue_free()

    var source := FileAccess.get_file_as_string("res://src/app/gameplay.gd")
    _expect(source.contains("@export var world_canvas_size"), "gameplay canvas dimensions are exported instead of buried in draw code")
    _expect(source.contains("@export var background_color"), "gameplay background presentation is exported")
    _expect(source.contains("@export var grid_color"), "gameplay grid presentation is exported")
    var draw_index := source.find("func _draw()")
    var draw_source := source.substr(draw_index) if draw_index >= 0 else ""
    _expect(not draw_source.contains("Color(0.08"), "draw code does not hardcode the greybox background color")
    _expect(not draw_source.contains("Color(0.14"), "draw code does not hardcode the greybox grid color")
    _expect(source.contains("set_world_bounds(Rect2(Vector2.ZERO, Vector2(world_canvas_size)))"), "camera bounds consume the inspector-authored world canvas size")

    if _failures == 0:
        print("GAMEPLAY PRESENTATION INSPECTOR AUTHORING TEST PASS")
    else:
        push_error("GAMEPLAY PRESENTATION INSPECTOR AUTHORING TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
