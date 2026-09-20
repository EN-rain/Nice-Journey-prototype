extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_catalog_contract()
    _test_fallbacks_reference_authored_modules()
    if _failures == 0:
        print("TOWER MODULE CATALOG TEST PASS")
    else:
        push_error("TOWER MODULE CATALOG TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_catalog_contract() -> void:
    var definitions := TowerPrototypeModuleCatalog.all_definitions()
    _expect(definitions.size() == 8, "prototype tower catalog owns eight reusable authored module definitions")
    _expect(TowerPrototypeModuleCatalog.validate_catalog().is_empty(), "all prototype module geometry/contracts validate")
    var seen: Dictionary = {}
    for definition: TowerRoomModuleDefinition in definitions:
        _expect(not seen.has(definition.module_id), "%s module identity is unique" % String(definition.module_id))
        seen[definition.module_id] = true
        _expect(not definition.walkable_rects.is_empty(), "%s declares walkable space" % String(definition.module_id))
        _expect(not definition.connectors.is_empty(), "%s declares authored connectors" % String(definition.module_id))
        _expect(not definition.arrival_candidates.is_empty(), "%s declares safe arrival candidates" % String(definition.module_id))
        _expect(definition.actor_clearance_size.x > 0 and definition.actor_clearance_size.y > 0, "%s declares actor clearance" % String(definition.module_id))
        for raw_connector_id: Variant in definition.connectors.keys():
            var connector := definition.connectors[raw_connector_id] as Dictionary
            var tile := connector["tile"] as Vector2i
            var blocked := false
            for rect: Rect2i in definition.collision_rects:
                if rect.has_point(tile):
                    blocked = true
                    break
            _expect(not blocked, "%s connector %s is not sealed by collision" % [String(definition.module_id), String(raw_connector_id)])

func _test_fallbacks_reference_authored_modules() -> void:
    for floor_id: int in range(1, 11):
        var request := TowerFloorGenerationCommitService.build_request(
            floor_id,
            71000 + floor_id,
            &"generator:module_test_v01",
            &"modules:prototype_v01",
            &"encounters:module_test_v01",
            &"quest_flags:module_test"
        )
        var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
        _expect(not manifest.is_empty(), "Floor %d fallback builds from the authored module catalog" % floor_id)
        if manifest.is_empty():
            continue
        _expect(TowerPrototypeModuleCatalog.validate_manifest_modules(manifest).is_empty(), "Floor %d fallback preserves module footprints/socket capacities" % floor_id)
        for raw_room: Variant in manifest["rooms"] as Array:
            var room := raw_room as Dictionary
            var definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(room["module_id"])))
            _expect(definition != null, "Floor %d room %s resolves an authored reusable module" % [floor_id, String(room["room_instance_id"])])

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
