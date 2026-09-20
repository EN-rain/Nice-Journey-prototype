extends SceneTree

const CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const OUTPUT := "res://docs/evidence/renderer/tower-floor-1-connected-route-review.png"
const METADATA := "res://docs/evidence/renderer/tower-floor-1-connected-route-review.json"

func _init() -> void:
    call_deferred(&"_capture")

func _capture() -> void:
    var request := TowerFloorGenerationCommitService.build_request(1, 90101, &"generator:prototype_v01", &"modules:prototype_v01", &"encounters:prototype_v01", &"questflags:test_v01")
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        push_error("no accepted Floor 1 manifest")
        quit(1)
        return
    var build := TowerFloorRuntimeComposer.build(manifest, CATALOG)
    if not bool(build.get("accepted", false)):
        push_error("actual TowerFloorRuntimeComposer rejected the manifest")
        quit(1)
        return
    var links := (build["root"] as Node2D).get_node("GraphLinks") as Node2D
    if links.get_child_count() == 0:
        push_error("no authored connecting routes")
        quit(1)
        return
    var route := links.get_child(0)
    var committed_tiles: Array = route.get_meta(&"route_tiles", []) as Array
    var route_layer := route.get_node_or_null("FloorTiles") as TileMapLayer
    if committed_tiles.is_empty() or route_layer == null:
        push_error("no live drawn link route")
        quit(1)
        return
    var viewport := SubViewport.new()
    viewport.size = Vector2i(640, 360)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var background := ColorRect.new()
    background.color = Color("#16151f")
    background.size = Vector2(viewport.size)
    background.z_index = -100
    viewport.add_child(background)
    viewport.add_child(build["root"] as Node2D)
    var camera := Camera2D.new()
    var center_tile := committed_tiles[int(committed_tiles.size() / 2)] as Vector2i
    camera.position = (Vector2(center_tile) + Vector2(0.5, 0.5)) * 32.0
    camera.zoom = Vector2.ONE
    camera.enabled = true
    viewport.add_child(camera)
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var screenshot := viewport.get_texture().get_image()
    if screenshot.get_size() != Vector2i(640, 360) or screenshot.save_png(ProjectSettings.globalize_path(OUTPUT)) != OK:
        push_error("cannot preserve native connected-room capture")
        quit(1)
        return
    var drawn_tiles := route_layer.get_used_cells().size()
    var metadata := {
        "scope": "VISUAL_ONLY_EXISTING_PLACEHOLDER / no final generated art acceptance",
        "engine": Engine.get_version_info().get("string", ""),
        "image": OUTPUT,
        "native_canvas": [640, 360],
        "module_tile_pixels": 32,
        "center_world_tile": [center_tile.x, center_tile.y],
        "committed_route_centers": committed_tiles.size(),
        "drawn_route_floor_cells": drawn_tiles,
        "source_atlas": "res://assets/art/environments/tower/tiles/tower_common_tileset_v01.png",
        "source_sha256": FileAccess.get_sha256(ProjectSettings.globalize_path("res://assets/art/environments/tower/tiles/tower_common_tileset_v01.png")),
    }
    var writer := FileAccess.open(METADATA, FileAccess.WRITE)
    if writer == null:
        push_error("cannot preserve route evidence metadata")
        quit(1)
        return
    writer.store_string(JSON.stringify(metadata, "  ") + "\n")
    writer.close()
    print("TOWER CONNECTED ROUTE RENDERER CAPTURE: 640x360, route centers %d, atlas cells %d" % [committed_tiles.size(), drawn_tiles])
    quit(0)
