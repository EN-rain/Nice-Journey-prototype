extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    for floor_id: int in range(1, 11):
        _test_floor(floor_id)
    _test_tampered_route_rejection()
    if _failures == 0:
        print("TOWER TRAVERSAL MANIFEST TEST PASS")
    else:
        push_error("TOWER TRAVERSAL MANIFEST TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_floor(floor_id: int) -> void:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        81000 + floor_id,
        &"generator:prototype_v01",
        &"modules:prototype_v01",
        &"encounters:prototype_v01",
        &"questflags:traversal_test"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    _expect(not manifest.is_empty(), "Floor %d fallback exists for traversal validation" % floor_id)
    if manifest.is_empty():
        return
    var errors := TowerFloorTraversalManifestValidator.validate_manifest(manifest)
    _expect(errors.is_empty(), "Floor %d fallback connector/route geometry validates" % floor_id)
    for raw_edge: Variant in manifest["edges"] as Array:
        var edge := raw_edge as Dictionary
        var route := edge["route_tiles"] as Array
        _expect(route.size() >= 2, "Floor %d edge %s→%s owns an explicit traversable route" % [floor_id, String(edge["from_room_id"]), String(edge["to_room_id"])])
        _expect(int(edge["route_width_tiles"]) >= 2, "Floor %d edge preserves two-tile actor clearance" % floor_id)
        _expect(StableId.is_valid(String(edge["from_connector_id"])) and StableId.is_valid(String(edge["to_connector_id"])), "Floor %d edge persists stable connector identities" % floor_id)

func _test_tampered_route_rejection() -> void:
    var request := TowerFloorGenerationCommitService.build_request(4, 44004, &"generator:prototype_v01", &"modules:prototype_v01", &"encounters:prototype_v01", &"questflags:traversal_test")
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    var edges := (manifest["edges"] as Array).duplicate(true)
    var first := (edges[0] as Dictionary).duplicate(true)
    first["route_width_tiles"] = 1
    edges[0] = first
    var too_narrow := manifest.duplicate(true)
    too_narrow["edges"] = edges
    _expect(_contains(TowerFloorTraversalManifestValidator.validate_manifest(too_narrow), "smaller than endpoint actor clearance"), "route validator rejects corridor width below authored actor clearance")

    edges = (manifest["edges"] as Array).duplicate(true)
    first = (edges[0] as Dictionary).duplicate(true)
    var route := (first["route_tiles"] as Array).duplicate(true)
    for index: int in range(route.size()):
        route[index] = (route[index] as Vector2i) + Vector2i(0, 1)
    first["route_tiles"] = route
    edges[0] = first
    var wrong_connector := manifest.duplicate(true)
    wrong_connector["edges"] = edges
    _expect(_contains(TowerFloorTraversalManifestValidator.validate_manifest(wrong_connector), "begin on the declared from connector"), "route validator rejects a route detached from its authored connector")

    edges = (manifest["edges"] as Array).duplicate(true)
    first = (edges[0] as Dictionary).duplicate(true)
    route = (first["route_tiles"] as Array).duplicate(true)
    if route.size() >= 3:
        route[1] = route[0] + Vector2i(3, 0)
    first["route_tiles"] = route
    edges[0] = first
    var discontinuous := manifest.duplicate(true)
    discontinuous["edges"] = edges
    _expect(_contains(TowerFloorTraversalManifestValidator.validate_manifest(discontinuous), "Manhattan-contiguous"), "route validator rejects discontinuous traversal geometry")

func _contains(errors: PackedStringArray, needle: String) -> bool:
    for error: String in errors:
        if error.contains(needle):
            return true
    return false

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
