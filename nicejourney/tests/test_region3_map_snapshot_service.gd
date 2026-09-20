extends SceneTree

const LAYOUT_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const MAP_SNAPSHOT_SERVICE_SCRIPT: Script = preload("res://src/world/region3/map/region3_map_snapshot_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var layout := LAYOUT_SCENE.instantiate() as Region3AuthoredTownLayout
    _expect(layout != null, "Region 3 map snapshot fixture instantiates the authored layout")
    if layout == null:
        quit(1)
        return

    var snapshot: Dictionary = MAP_SNAPSHOT_SERVICE_SCRIPT.build_from_layout(layout)
    _expect(bool(snapshot.get("accepted", false)), "validated Region 3 layout produces public map geometry")
    _expect(StringName(snapshot.get("map_revision_id", &"")) == Region3AuthoredTownLayout.MAP_REVISION_ID, "Region map snapshot preserves the authored map revision")
    _expect(snapshot.get("map_size_tiles", Vector2i.ZERO) == Vector2i(160, 160), "Region map snapshot preserves the 160x160 authored reservation")
    _expect(snapshot.get("town_tile_rect", Rect2i()) == Rect2i(48, 48, 64, 64), "Region map snapshot preserves the authored town reservation")
    _expect(snapshot.get("plaza_tile_rect", Rect2i()) == Rect2i(69, 81, 23, 13), "Region map snapshot preserves the authored plaza reservation")

    var routes := snapshot.get("route_polylines", []) as Array
    _expect(routes.size() == 13, "Region map snapshot exposes all 13 inspector-authored road/connector polylines")
    var seen_routes: Dictionary = {}
    var circulation: Dictionary = {}
    for raw_route: Variant in routes:
        if not raw_route is Dictionary:
            continue
        var route := raw_route as Dictionary
        var route_name := StringName(String(route.get("route_name", &"")))
        seen_routes[route_name] = true
        if route_name == &"CirculationLoop":
            circulation = route
    _expect(seen_routes.size() == 13 and seen_routes.has(&"NorthApproach") and seen_routes.has(&"ClinicConnector"), "Region map route names remain unique and preserve authored scene identities")
    var circulation_points := circulation.get("points_tiles", PackedVector2Array()) as PackedVector2Array
    _expect(circulation_points.size() == 5 and circulation_points[0].is_equal_approx(Vector2(68, 65)) and circulation_points[2].is_equal_approx(Vector2(92, 95)), "Region map routes are converted from authored world pixels to exact tile-space geometry")

    var landmarks := snapshot.get("public_landmarks", []) as Array
    _expect(landmarks.size() == 1, "Region map exposes only the fixed public Central Tower landmark before service discovery exists")
    if landmarks.size() == 1:
        var tower := landmarks[0] as Dictionary
        _expect(StringName(tower.get("landmark_id", &"")) == &"r3:functional:01", "public Region landmark preserves the Central Tower structure identity")
        _expect(StringName(tower.get("landmark_kind", &"")) == Region3TownStructureManifestValidator.ROLE_CENTRAL_TOWER, "public Region landmark is explicitly the Central Tower")
        _expect((tower.get("position_tiles", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(80.0, 73.5)), "Central Tower map marker uses the exact authored lot-center position")
    _expect(not str(snapshot).contains("blacksmith") and not str(snapshot).contains("general_merchant") and not str(snapshot).contains("quest_hall"), "Region map snapshot does not leak undiscovered service identities")
    _expect(not bool(snapshot.get("service_discovery_state_available", true)), "Region map snapshot does not fabricate service discovery state")
    _expect(bool(snapshot.get("world_layout_definition_available", false)), "Region map snapshot recognizes the validated authored world-layout definition")
    _expect(bool(snapshot.get("explored_subzone_geometry_available", false)), "Region map snapshot recognizes authoritative subzone geometry")
    _expect(not bool(snapshot.get("explored_subzone_state_available", true)) and (snapshot.get("explored_subzones", []) as Array).is_empty(), "Region map snapshot withholds explored subzones until physical discovery state exists")
    _expect(
        StringName(snapshot.get("explored_subzone_unavailable_reason_id", &"")) == Region3WorldLayoutDefinition.REASON_EXPLORED_SUBZONE_STATE_OWNER_UNAVAILABLE,
        "Region map snapshot without a profile reports the missing discovery-state owner"
    )
    _expect(not bool(snapshot.get("quest_marker_state_available", true)), "Region map snapshot does not fabricate quest marker state")
    _expect((snapshot.get("quest_markers", []) as Array).is_empty(), "Region map snapshot exposes no quest marker geometry without an authored anchor owner")
    _expect(
        StringName(snapshot.get("quest_marker_unavailable_reason_id", &"")) == Region3WorldLayoutDefinition.REASON_QUEST_MARKER_GEOMETRY_UNAUTHORED,
        "Region map snapshot exposes the exact quest-marker geometry blocker"
    )
    _expect(not bool(snapshot.get("checkpoint_marker_state_available", true)) and (snapshot.get("checkpoint_markers", []) as Array).is_empty(), "Region map snapshot withholds checkpoint markers until checkpoint geometry is authored")
    _expect(
        StringName(snapshot.get("checkpoint_marker_unavailable_reason_id", &"")) == Region3WorldLayoutDefinition.REASON_CHECKPOINT_GEOMETRY_UNAUTHORED,
        "Region map snapshot exposes the exact Region-checkpoint geometry blocker"
    )
    _expect(not bool(snapshot.get("risk_marker_state_available", true)) and (snapshot.get("risk_markers", []) as Array).is_empty(), "Region map snapshot does not fabricate Region danger state")
    _expect(
        StringName(snapshot.get("risk_marker_unavailable_reason_id", &"")) == Region3WorldLayoutDefinition.REASON_REGION_DANGER_CONCRETE_LEVEL_UNAUTHORED,
        "Region map snapshot exposes the exact concrete Region danger blocker"
    )

    var profile := ProfileCreationService.create_profile(1, "Region Map Discovery", "melee")
    _expect(bool(Region3ServiceDiscoveryService.mark_discovered(profile, &"r3:functional:03", &"blacksmith").get("accepted", false)), "live Blacksmith interaction can create explicit service discovery state")
    _expect(bool(Region3SubzoneDiscoveryService.mark_zone_explored(profile, layout, &"R3-TOWN").get("accepted", false)), "physical-discovery fixture marks only the authored town subzone")
    var discovered: Dictionary = MAP_SNAPSHOT_SERVICE_SCRIPT.build_from_layout(layout, profile)
    _expect(bool(discovered.get("service_discovery_state_available", false)), "Region map reports service-discovery ownership when a profile is supplied")
    var discovered_services := discovered.get("discovered_services", []) as Array
    _expect(discovered_services.size() == 1, "Region map exposes only the service identity actually discovered by interaction")
    if discovered_services.size() == 1:
        var blacksmith := discovered_services[0] as Dictionary
        _expect(StringName(blacksmith.get("landmark_id", &"")) == &"r3:functional:03" and StringName(blacksmith.get("landmark_kind", &"")) == &"blacksmith", "discovered service marker preserves exact authored structure/role identity")
    _expect((discovered.get("public_landmarks", []) as Array).size() == 2, "discovered service augments the always-public Central Tower without exposing other services")
    _expect(not str(discovered).contains("general_merchant") and not str(discovered).contains("quest_hall"), "undiscovered service identities remain withheld after another service is discovered")
    var explored := discovered.get("explored_subzones", []) as Array
    _expect(bool(discovered.get("explored_subzone_state_available", false)) and explored.size() == 1, "Region map exposes only the explicitly explored subzone")
    if explored.size() == 1:
        _expect(StringName(String((explored[0] as Dictionary).get("zone_id", &""))) == &"R3-TOWN", "Region map explored-subzone marker preserves exact zone identity")
    _expect((discovered.get("quest_markers", []) as Array).is_empty() and (discovered.get("checkpoint_markers", []) as Array).is_empty() and (discovered.get("risk_markers", []) as Array).is_empty(), "service/subzone discovery does not imply quest, checkpoint or danger state")

    _test_provisional_danger_markers(layout, profile)

    var detached_routes := snapshot.get("route_polylines", []) as Array
    (detached_routes[0] as Dictionary)["points_tiles"] = PackedVector2Array([Vector2.ZERO, Vector2.ONE])
    var fresh: Dictionary = MAP_SNAPSHOT_SERVICE_SCRIPT.build_from_layout(layout)
    _expect((fresh.get("route_polylines", []) as Array).size() == 13, "mutating a returned Region map snapshot cannot alter the authored layout")

    layout.map_size_tiles = Vector2i(159, 160)
    var invalid: Dictionary = MAP_SNAPSHOT_SERVICE_SCRIPT.build_from_layout(layout)
    _expect(not bool(invalid.get("accepted", true)) and StringName(invalid.get("reason_id", &"")) == MAP_SNAPSHOT_SERVICE_SCRIPT.REASON_INVALID_LAYOUT, "Region map snapshot fails closed when authored layout validation fails")
    _expect((invalid.get("explored_subzones", []) as Array).is_empty() and (invalid.get("quest_markers", []) as Array).is_empty() and (invalid.get("checkpoint_markers", []) as Array).is_empty() and (invalid.get("risk_markers", []) as Array).is_empty(), "rejected Region map snapshots expose no withheld state payloads")

    layout.queue_free()
    if _failures == 0:
        print("REGION 3 MAP SNAPSHOT SERVICE TEST PASS")
    else:
        push_error("REGION 3 MAP SNAPSHOT SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_provisional_danger_markers(layout: Region3AuthoredTownLayout, profile: ProfileSnapshot) -> void:
    var original_world := layout.world_layout_definition
    var provisional := original_world.duplicate(true) as Region3WorldLayoutDefinition
    for raw_zone: Resource in provisional.zones:
        var zone := raw_zone as Region3WorldZoneDefinition
        if zone != null and not zone.safe_zone and zone.travel_destination:
            zone.recommended_level = zone.recommended_level_min
    layout.world_layout_definition = provisional
    _expect(layout.validate_layout().is_empty(), "test-only exact recommendations remain inside authored master ranges")
    var fresh_profile := ProfileCreationService.create_profile(1, "Unauthored Discovery", "melee")
    var uninitialized: Dictionary = MAP_SNAPSHOT_SERVICE_SCRIPT.build_from_layout(layout, fresh_profile)
    _expect(
        not bool(uninitialized.get("risk_marker_state_available", true))
        and StringName(String(uninitialized.get("risk_marker_unavailable_reason_id", &""))) == Region3SubzoneDiscoveryService.REASON_STATE_UNINITIALIZED,
        "concrete danger data alone does not reveal undiscovered Region zones"
    )

    var town_only: Dictionary = MAP_SNAPSHOT_SERVICE_SCRIPT.build_from_layout(layout, profile)
    _expect(bool(town_only.get("risk_marker_state_available", false)) and (town_only.get("risk_markers", []) as Array).is_empty(), "safe-only exploration yields no false numeric town Danger rank")
    _expect(bool(Region3SubzoneDiscoveryService.mark_zone_explored(profile, layout, &"R3-OUTSKIRTS").get("accepted", false)), "fixture discovers authored outskirts")
    var outskirts: Dictionary = MAP_SNAPSHOT_SERVICE_SCRIPT.build_from_layout(layout, profile)
    var visible := outskirts.get("risk_markers", []) as Array
    _expect(visible.size() == 1, "Region danger markers expose only an explored hostile zone")
    if visible.size() == 1:
        var marker := visible[0] as Dictionary
        _expect(StringName(String(marker.get("zone_id", &""))) == &"R3-OUTSKIRTS" and marker.get("tile_rect", Rect2i()) == Rect2i(48, 112, 64, 32), "Region danger uses exact authored zone identity and geometry")
        _expect(int(marker.get("recommended_level", 0)) == 1 and int(marker.get("danger_rank", 0)) == DangerEvaluator.Rank.I, "test-only lower-band recommendation calculates DANGER I at equal player level")
    _expect(bool(Region3SubzoneDiscoveryService.mark_zone_explored(profile, layout, &"R3-RISK").get("accepted", false)), "fixture discovers optional risk zone")
    var higher_risk: Dictionary = MAP_SNAPSHOT_SERVICE_SCRIPT.build_from_layout(layout, profile)
    visible = higher_risk.get("risk_markers", []) as Array
    _expect(visible.size() == 2, "multiple explored hostile zones produce deterministic danger entries")
    if visible.size() == 2:
        var risk := visible[1] as Dictionary
        _expect(StringName(String(risk.get("zone_id", &""))) == &"R3-RISK" and int(risk.get("danger_rank", 0)) == DangerEvaluator.Rank.V, "optional risk-zone recommendation evaluates the existing five-level deficit rule")
        _expect(bool(risk.get("requires_danger_confirmation", false)), "DANGER V reports menu-travel confirmation requirement without granting travel")
    profile.level = 8
    var leveled: Dictionary = MAP_SNAPSHOT_SERVICE_SCRIPT.build_from_layout(layout, profile)
    visible = leveled.get("risk_markers", []) as Array
    if visible.size() == 2:
        _expect(int((visible[1] as Dictionary).get("danger_rank", 0)) == DangerEvaluator.Rank.I, "Region danger is recomputed at map read when player level changes")
    profile.level = 1
    provisional.get_zone(&"R3-RISK").recommended_level = -1
    var incomplete: Dictionary = MAP_SNAPSHOT_SERVICE_SCRIPT.build_from_layout(layout, profile)
    _expect((incomplete.get("risk_markers", []) as Array).is_empty() and not bool(incomplete.get("risk_marker_state_available", true)), "incomplete exact Region authoring fails closed without leaking partial danger")
    layout.world_layout_definition = original_world
    _expect(not original_world.has_concrete_region_danger_data(), "no test-only recommendation is written into the shipped world resource")


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
