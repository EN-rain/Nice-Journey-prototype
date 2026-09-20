extends SceneTree

const TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var town := TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    root.add_child(town)
    await process_frame

    _expect(town != null, "Region 3 authored town layout scene instantiates")
    if town != null:
        _expect(town.map_revision_id == &"region3_town_layout_v01", "authored town layout has a stable revision ID")
        _expect(town.tile_size == 32, "authored town layout uses the 32 px logical tile contract")
        _expect(town.map_size_tiles == Vector2i(160, 160), "authored Region 3 traversal reservation is 160x160 tiles")
        _expect(town.town_tile_rect == Rect2i(48, 48, 64, 64), "authored town reservation remains x48-111/y48-111")
        _expect(town.plaza_tile_rect == Rect2i(69, 81, 23, 13), "tower plaza reservation matches the master greybox brief")
        _expect(town.environment_support_profile != null, "authored town owns the Region 3 environment-support profile")
        if town.environment_support_profile != null:
            _expect(town.environment_support_profile.validate_profile().is_empty(), "Region 3 environment-support V02 textures validate")
            _expect(town.environment_support_profile.town_props.resource_path.ends_with("region3_prop_sheet_v02.png"), "town props use V02 pixel art")
            _expect(town.environment_support_profile.ground_road.resource_path.ends_with("region3_ground_road_tileset_v02.png"), "ground/road uses V02 pixel art")
            _expect(town.environment_support_profile.ruins_modules.resource_path.ends_with("region3_ruins_module_sheet_v02.png"), "ruins use V02 pixel art")
            _expect(town.environment_support_profile.south_outskirts_support.resource_path.ends_with("region3_outskirts_support_sheet_v02.png"), "south outskirts uses V02 pixel art")
            _expect(town.environment_support_profile.east_risk_zone_support.resource_path.ends_with("region3_risk_zone_support_sheet_v02.png"), "east risk zone uses V02 pixel art")
        _expect(town.validate_layout().is_empty(), "authored town scene satisfies its placement and 20/8/12 manifest contract")

        var anchors: Array[Region3TownStructureAnchor] = []
        for child: Node in town.get_children():
            if child is Region3TownStructureAnchor:
                anchors.append(child as Region3TownStructureAnchor)
        _expect(anchors.size() == 20, "authored town contains exactly 20 structure anchors")

        var functional := 0
        var decorative := 0
        var roles: Dictionary = {}
        var ids: Dictionary = {}
        for anchor: Region3TownStructureAnchor in anchors:
            _expect(anchor.validate_anchor().is_empty(), "%s anchor validates" % String(anchor.structure_id))
            _expect(anchor.position.is_equal_approx(anchor.expected_world_position(float(town.tile_size))), "%s sits at the center of its reserved master lot" % String(anchor.structure_id))
            _expect(anchor.sprite != null and anchor.sprite.texture != null, "%s resolves an inspector-authored visual texture" % String(anchor.structure_id))
            _expect(not ids.has(anchor.structure_id), "%s structure ID is unique" % String(anchor.structure_id))
            ids[anchor.structure_id] = true
            if anchor.category == Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
                functional += 1
                roles[anchor.role_id] = true
                _expect(anchor.entrance_tile != Vector2i(-1, -1), "%s has an inspector-authored entrance tile" % String(anchor.structure_id))
                _expect(anchor.approach_tile != Vector2i(-1, -1), "%s has an inspector-authored exterior approach tile" % String(anchor.structure_id))
                _expect(town.town_tile_rect.has_point(anchor.approach_tile), "%s functional approach remains inside the authored town reservation" % String(anchor.structure_id))
            else:
                decorative += 1
        _expect(functional == 8, "authored town has exactly eight functional structures")
        _expect(decorative == 12, "authored town has exactly twelve decorative structures")
        for role_id: StringName in Region3TownStructureManifestValidator.REQUIRED_FUNCTIONAL_ROLES:
            _expect(roles.has(role_id), "authored town places functional role %s" % String(role_id))

        var routes := town.get_node_or_null("Routes") as Node2D
        _expect(routes != null, "authored town owns an inspector-editable route draft")
        if routes != null:
            var loop := routes.get_node_or_null("CirculationLoop") as Line2D
            _expect(loop != null and loop.points.size() == 5, "town circulation loop is explicitly authored")
            if loop != null:
                _expect(loop.points[0].is_equal_approx(loop.points[loop.points.size() - 1]), "town circulation loop is closed")
                _expect(is_equal_approx(loop.width, 96.0), "circulation loop uses a three-tile draft width where the reserved service/tower lots constrain the four-tile target")
            for approach_name: String in ["NorthApproach", "SouthApproach", "WestApproach", "EastApproach"]:
                var approach := routes.get_node_or_null(approach_name) as Line2D
                _expect(approach != null and approach.points.size() >= 2, "%s is explicitly authored" % approach_name)
                if approach != null:
                    _expect(is_equal_approx(approach.width, 128.0), "%s uses the four-tile initial clear-width hypothesis" % approach_name)
            for connector_name: String in ["StorageConnector", "TrainingConnector", "QuestConnector", "BlacksmithConnector", "MerchantConnector", "InnConnector", "ClinicConnector"]:
                var connector := routes.get_node_or_null(connector_name) as Line2D
                _expect(connector != null and connector.points.size() >= 2, "%s service connector exists" % connector_name)
                if connector != null:
                    _expect(is_equal_approx(connector.width, 96.0), "%s preserves the three-tile minimum escort-route hypothesis" % connector_name)
            _expect(routes.get_node_or_null("TowerPlazaSpine") is Line2D, "tower entrance/plaza spine explicitly connects the central landmark to the circulation draft")

    var anchor_source := FileAccess.get_file_as_string("res://src/world/region3/layout/region3_town_structure_anchor.gd")
    _expect(not anchor_source.contains("res://assets/art"), "Region 3 authored-layout runtime contains no hardcoded art paths")

    if town != null:
        town.queue_free()
    if _failures == 0:
        print("REGION 3 AUTHORED TOWN LAYOUT TEST PASS")
    else:
        push_error("REGION 3 AUTHORED TOWN LAYOUT TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
