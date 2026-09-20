extends SceneTree

const CATALOG: Region3FunctionalBuildingVisualCatalog = preload("res://src/world/region3/presentation/region3_functional_building_visual_catalog.tres")
const VISUAL_SCENE: PackedScene = preload("res://src/world/region3/presentation/region3_functional_building_visual.tscn")

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _expect(CATALOG != null, "Region 3 functional building visual catalog loads")
    if CATALOG != null:
        _expect(CATALOG.profiles.size() == 8, "catalog exposes exactly the eight locked functional building roles")
        _expect(CATALOG.validate_catalog().is_empty(), "all functional building visual profiles validate")
        for role_id: StringName in Region3TownStructureManifestValidator.REQUIRED_FUNCTIONAL_ROLES:
            var profile: Region3FunctionalBuildingVisualProfile = CATALOG.get_profile(role_id)
            _expect(profile != null, "visual catalog resolves %s" % String(role_id))
            if profile != null:
                _expect(profile.texture != null, "%s texture is inspector assigned" % String(role_id))
                if profile.texture != null:
                    _expect(profile.texture.resource_path.ends_with("_v02.png"), "%s profile uses generated V02 production art" % String(role_id))
                var expected_offset := Vector2(0, 96) if role_id == Region3TownStructureManifestValidator.ROLE_CENTRAL_TOWER else Vector2(0, 64)
                _expect(profile.sprite_offset == expected_offset, "%s keeps its Inspector-authored V02 ground/entrance offset" % String(role_id))

    var visual: Region3FunctionalBuildingVisual = VISUAL_SCENE.instantiate() as Region3FunctionalBuildingVisual
    root.add_child(visual)
    await process_frame
    _expect(visual != null, "generic Region 3 functional building Sprite2D presenter instantiates")
    if visual != null and CATALOG != null:
        visual.profile = CATALOG.get_profile(Region3TownStructureManifestValidator.ROLE_CENTRAL_TOWER)
        _expect(visual.apply_profile(), "building presenter applies an inspector-authored role profile")
        _expect(visual.sprite != null and visual.sprite.texture == visual.profile.texture, "building Sprite2D uses the profile texture")
        _expect(visual.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "building presenter preserves nearest filtering")
        visual.queue_free()

    var controller_source: String = FileAccess.get_file_as_string("res://src/world/region3/presentation/region3_functional_building_visual.gd")
    _expect(not controller_source.contains("res://assets/art/"), "Region 3 building runtime contains no hardcoded art paths")

    if _failures == 0:
        print("REGION 3 FUNCTIONAL BUILDING VISUAL TEST PASS")
    else:
        push_error("REGION 3 FUNCTIONAL BUILDING VISUAL TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
