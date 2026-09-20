extends SceneTree

const TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const TILE_SIZE := 32.0

const TOWN_RECT := Rect2(48 * TILE_SIZE, 48 * TILE_SIZE, 64 * TILE_SIZE, 64 * TILE_SIZE)
const WEST_ROAD_RECT := Rect2(16 * TILE_SIZE, 64 * TILE_SIZE, 32 * TILE_SIZE, 64 * TILE_SIZE)
const NORTH_RUINS_RECT := Rect2(40 * TILE_SIZE, 16 * TILE_SIZE, 72 * TILE_SIZE, 32 * TILE_SIZE)
const SOUTH_OUTSKIRTS_RECT := Rect2(48 * TILE_SIZE, 112 * TILE_SIZE, 64 * TILE_SIZE, 32 * TILE_SIZE)
const EAST_RISK_RECT := Rect2(112 * TILE_SIZE, 40 * TILE_SIZE, 32 * TILE_SIZE, 72 * TILE_SIZE)

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var town := TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    root.add_child(town)
    await process_frame
    _expect(town != null, "Region 3 authored town instantiates with environment dressing")
    if town == null:
        quit(_failures)
        return

    _expect(town.environment_support_profile != null, "Region 3 exposes its environment-support visual profile")
    if town.environment_support_profile != null:
        _expect(not town.environment_support_profile.has_complete_source_evidence(), "Batch 2 preview support derivatives remain explicitly non-production until all exact source evidence is accepted")

    var dressing := town.get_node_or_null("EnvironmentDressing") as Node2D
    _expect(dressing != null, "authored town scene owns scene-authored environment dressing")
    if dressing != null:
        _validate_zone(dressing, "TownProps", TOWN_RECT, "region3_prop_sheet_v02.png")
        _validate_zone(dressing, "Ruins", NORTH_RUINS_RECT, "region3_ruins_module_sheet_v02.png")
        _validate_zone(dressing, "SouthOutskirts", SOUTH_OUTSKIRTS_RECT, "region3_outskirts_support_sheet_v02.png")
        _validate_zone(dressing, "EastRiskZone", EAST_RISK_RECT, "region3_risk_zone_support_sheet_v02.png")
        _validate_ground(dressing)

    var source := FileAccess.get_file_as_string("res://src/world/region3/layout/region3_authored_town_layout.gd")
    _expect(not source.contains("region3_prop_sheet") and not source.contains("region3_ground_road") and not source.contains("region3_ruins_module"), "gameplay layout script does not hardcode environment-art paths")

    town.queue_free()
    if _failures == 0:
        print("REGION 3 ENVIRONMENT DRESSING TEST PASS")
    else:
        push_error("REGION 3 ENVIRONMENT DRESSING TEST FAILURES: %d" % _failures)
    quit(_failures)

func _validate_zone(dressing: Node2D, zone_name: String, zone_rect: Rect2, expected_texture_suffix: String) -> void:
    var zone := dressing.get_node_or_null(zone_name) as Node2D
    _expect(zone != null, "%s dressing group exists" % zone_name)
    if zone == null:
        return
    _expect(zone.get_child_count() > 0, "%s contains authored visual placements" % zone_name)
    for child: Node in zone.get_children():
        var sprite := child as Sprite2D
        _expect(sprite != null, "%s/%s is a Sprite2D placement" % [zone_name, child.name])
        if sprite == null:
            continue
        _expect(sprite.texture != null, "%s/%s owns an inspector-authored texture" % [zone_name, child.name])
        if sprite.texture != null:
            _expect(sprite.texture.resource_path.ends_with(expected_texture_suffix), "%s/%s uses the correct V02 support sheet" % [zone_name, child.name])
        _expect(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s/%s preserves nearest filtering" % [zone_name, child.name])
        _expect(sprite.region_enabled and sprite.region_rect.size.x > 0.0 and sprite.region_rect.size.y > 0.0, "%s/%s crops one authored source region" % [zone_name, child.name])
        _expect(zone_rect.has_point(sprite.position), "%s/%s remains inside its master-authored zone reservation" % [zone_name, child.name])

func _validate_ground(dressing: Node2D) -> void:
    var ground := dressing.get_node_or_null("Ground") as Node2D
    _expect(ground != null, "ground dressing group exists")
    if ground == null:
        return
    _expect(ground.get_child_count() >= 10, "ground dressing provides multiple authored route/material samples")
    for child: Node in ground.get_children():
        var sprite := child as Sprite2D
        _expect(sprite != null, "Ground/%s is a Sprite2D placement" % child.name)
        if sprite == null:
            continue
        _expect(sprite.texture != null and sprite.texture.resource_path.ends_with("region3_ground_road_tileset_v02.png"), "Ground/%s uses V02 ground/road pixel art" % child.name)
        _expect(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Ground/%s preserves nearest filtering" % child.name)
        _expect(sprite.region_enabled and sprite.region_rect.size.x > 0.0 and sprite.region_rect.size.y > 0.0, "Ground/%s crops one authored source region" % child.name)
        var allowed_rect := _ground_zone_for_name(String(child.name))
        _expect(allowed_rect.size.x > 0.0 and allowed_rect.has_point(sprite.position), "Ground/%s remains inside its intended authored zone" % child.name)

func _ground_zone_for_name(node_name: String) -> Rect2:
    if node_name.begins_with("Town"):
        return TOWN_RECT
    if node_name.begins_with("WestRoad"):
        return WEST_ROAD_RECT
    if node_name.begins_with("North"):
        return NORTH_RUINS_RECT
    if node_name.begins_with("SouthRoad"):
        return SOUTH_OUTSKIRTS_RECT
    if node_name.begins_with("RiskGround"):
        return EAST_RISK_RECT
    return Rect2()

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
