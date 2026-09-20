extends SceneTree

const CATALOG_PATH := "res://src/world/tower/presentation/tower_room_visual_catalog.tres"
const OUTPUT := "res://docs/evidence/renderer/tower-floor-atlas-v01-review.png"
const EVIDENCE := "res://docs/evidence/renderer/tower-floor-atlas-v01-review.json"
const SOURCE := "res://assets/art/environments/tower/tiles/tower_common_tileset_v01.png"
const CASES := [
    {"module": &"module:entrance_safe_v01", "name": "Safe / 6x6", "position": Vector2(88, 264)},
    {"module": &"module:annihilation_objective_v01", "name": "Combat / 10x10", "position": Vector2(390, 200)},
    {"module": &"module:boss_sanctum_v01", "name": "Boss / 14x14", "position": Vector2(780, 136)},
]

func _init() -> void:
    call_deferred(&"_capture")

func _capture() -> void:
    var catalog := load(CATALOG_PATH) as TowerRoomVisualCatalog
    if catalog == null or not catalog.validate_catalog().is_empty():
        push_error("tower visual catalog invalid")
        quit(1)
        return
    var viewport := SubViewport.new()
    viewport.size = Vector2i(1280, 720)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var backdrop := ColorRect.new()
    backdrop.size = Vector2(viewport.size)
    backdrop.color = Color("#252838")
    backdrop.z_index = -10
    viewport.add_child(backdrop)
    var rendered_cases: Array[Dictionary] = []
    for case: Dictionary in CASES:
        var definition := TowerPrototypeModuleCatalog.get_definition(case["module"] as StringName)
        if definition == null:
            push_error("missing authored module: %s" % case["module"])
            quit(1)
            return
        var profile := catalog.get_profile(definition.visual_room_type)
        var room := {
            "room_instance_id": case["module"],
            "module_id": case["module"],
            "rect": Rect2i(Vector2i.ZERO, definition.footprint_size),
            "tags": [],
        }
        var room_node := TowerFloorRuntimeComposer._build_room(room, definition, profile, catalog, 32)
        if room_node == null:
            push_error("failed live tower room visual: %s" % case["module"])
            quit(1)
            return
        room_node.position = case["position"] as Vector2
        viewport.add_child(room_node)
        var label := Label.new()
        label.text = String(case["name"])
        label.position = Vector2(room_node.position.x, 54)
        label.add_theme_font_size_override("font_size", 22)
        viewport.add_child(label)
        rendered_cases.append({"module": String(case["module"]), "size_tiles": [definition.footprint_size.x, definition.footprint_size.y], "pixel_position": [int(room_node.position.x), int(room_node.position.y)]})
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var screenshot := viewport.get_texture().get_image()
    if screenshot.save_png(ProjectSettings.globalize_path(OUTPUT)) != OK:
        push_error("could not save tower atlas renderer evidence")
        quit(1)
        return
    var evidence := {
        "status": "PROVISIONAL_TEXTURE_LIVE_RENDERER_CAPTURE",
        "godot_version": Engine.get_version_info().get("string", ""),
        "renderer": "Godot Compatibility / OpenGL",
        "image": OUTPUT,
        "image_dimensions": [screenshot.get_width(), screenshot.get_height()],
        "asset_source": SOURCE,
        "asset_source_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path(SOURCE)),
        "atlas_tileset_resource": "res://src/world/tower/presentation/tower_common_floor_tileset_v01.tres",
        "native_tile_pixels": 32,
        "room_examples": rendered_cases,
        "scope": "Atlas floor coverage/room category contrast only; no final replacement-art acceptance or boss combat fairness claim",
    }
    var record := FileAccess.open(EVIDENCE, FileAccess.WRITE)
    if record == null:
        push_error("could not write tower atlas evidence metadata")
        quit(1)
        return
    record.store_string(JSON.stringify(evidence, "  ") + "\n")
    record.close()
    print("TOWER ATLAS RENDERER CAPTURE: %dx%d, 3 authored room footprints" % [screenshot.get_width(), screenshot.get_height()])
    quit(0)
