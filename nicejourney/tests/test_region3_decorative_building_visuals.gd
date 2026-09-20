extends SceneTree

const CATALOG: Region3DecorativeBuildingVisualCatalog = preload("res://src/world/region3/presentation/region3_decorative_building_visual_catalog.tres")
const TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _expect(CATALOG != null, "Region 3 decorative building visual catalog loads")
    if CATALOG != null:
        _expect(CATALOG.profiles.size() == Region3TownStructureManifestValidator.DECORATIVE_STRUCTURES, "catalog exposes exactly twelve decorative building profiles")
        _expect(CATALOG.validate_catalog().is_empty(), "all decorative building visual profiles validate")
        for index: int in range(Region3DecorativeBuildingVisualCatalog.REQUIRED_STRUCTURE_IDS.size()):
            var structure_id: StringName = Region3DecorativeBuildingVisualCatalog.REQUIRED_STRUCTURE_IDS[index]
            var profile: Region3DecorativeBuildingVisualProfile = CATALOG.get_profile(structure_id)
            _expect(profile != null, "visual catalog resolves %s" % String(structure_id))
            if profile != null:
                _expect(profile.texture != null, "%s texture is inspector assigned" % String(structure_id))
                if profile.texture != null:
                    _expect(profile.texture.resource_path.ends_with("_v02.png"), "%s uses the current V02 derivative path" % String(structure_id))
                var expected_source_accepted := index < 12
                _expect(profile.exact_source_evidence_accepted == expected_source_accepted, "%s records exact generated-source acceptance independently from derivative availability" % String(structure_id))
                _expect(profile.is_production_ready() == expected_source_accepted, "%s production readiness cannot be inferred from a preview derivative path alone" % String(structure_id))

    var town := TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    root.add_child(town)
    await process_frame
    _expect(town != null, "authored Region 3 town instantiates with decorative profiles")
    if town != null:
        var decorative_count := 0
        for child: Node in town.get_children():
            if not child is Region3TownStructureAnchor:
                continue
            var anchor := child as Region3TownStructureAnchor
            if anchor.category != Region3TownStructureManifestValidator.CATEGORY_DECORATIVE:
                continue
            decorative_count += 1
            _expect(anchor.decorative_profile != null, "%s owns an inspector-authored decorative profile" % String(anchor.structure_id))
            if anchor.decorative_profile != null:
                _expect(anchor.decorative_profile.structure_id == anchor.structure_id, "%s profile identity matches the authored anchor" % String(anchor.structure_id))
                _expect(anchor.sprite != null and anchor.sprite.texture == anchor.decorative_profile.texture, "%s Sprite2D uses the profile texture" % String(anchor.structure_id))
                _expect(anchor.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s preserves nearest filtering" % String(anchor.structure_id))
        _expect(decorative_count == Region3TownStructureManifestValidator.DECORATIVE_STRUCTURES, "authored town consumes all twelve decorative profiles")
        town.queue_free()

    var anchor_source := FileAccess.get_file_as_string("res://src/world/region3/layout/region3_town_structure_anchor.gd")
    _expect(not anchor_source.contains("res://assets/art/"), "decorative building runtime contains no hardcoded art paths")

    if _failures == 0:
        print("REGION 3 DECORATIVE BUILDING VISUAL TEST PASS")
    else:
        push_error("REGION 3 DECORATIVE BUILDING VISUAL TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
