extends SceneTree

const TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const STAGING_SERVICE: Script = preload("res://src/world/region3/quests/region3_side_quest_staging_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var town := TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    root.add_child(town)
    await process_frame

    var snapshot: Dictionary = STAGING_SERVICE.build_from_layout(town)
    _expect(bool(snapshot.get("accepted", false)), "Region 3 side-quest staging reads the validated authored layout")
    _expect(not bool(snapshot.get("runtime_staging_ready", true)), "side-quest staging remains fail-closed while quest-specific runtime authoring is absent")
    _expect((snapshot.get("descriptors", []) as Array).size() == 3, "staging exposes exactly the three master-approved Region 3 side slots")

    var escort: Dictionary = STAGING_SERVICE.descriptor_for_slot(snapshot, STAGING_SERVICE.SLOT_SIDE_A)
    _expect(StringName(String(escort.get("objective_family", &""))) == STAGING_SERVICE.FAMILY_ESCORT, "R3-SIDE-A preserves Escort-family identity")
    _expect(escort.get("zone_tile_rect", Rect2i()) == Rect2i(48, 112, 64, 32), "R3-SIDE-A uses the authored south-outskirts reservation")
    _expect(StringName(String(escort.get("staging_route_name", &""))) == &"SouthApproach", "R3-SIDE-A resolves the real SouthApproach polyline")
    _expect(bool(escort.get("route_enters_reserved_zone", false)) and bool(escort.get("route_touches_town", false)), "SouthApproach is source-backed geometry connecting town and the south-outskirts reservation")
    _expect(_matches_route_snapshot(town, escort), "Escort staging route points are copied from the scene instead of invented")
    var escort_binding := escort.get("objective_binding_blockers", PackedStringArray()) as PackedStringArray
    _expect(escort_binding.has("actor_id") and escort_binding.has("route_node_ids") and escort_binding.has("goal_id"), "Escort staging reports the required un-authored objective identities")
    var escort_runtime := escort.get("runtime_authoring_blockers", PackedStringArray()) as PackedStringArray
    _expect(escort_runtime.has("speed_px_per_second") and escort_runtime.has("arrival_tolerance_px"), "Escort staging does not invent physical movement tuning")

    var annihilation: Dictionary = STAGING_SERVICE.descriptor_for_slot(snapshot, STAGING_SERVICE.SLOT_SIDE_B)
    _expect(StringName(String(annihilation.get("objective_family", &""))) == STAGING_SERVICE.FAMILY_ANNIHILATION, "R3-SIDE-B preserves Annihilation-family identity")
    _expect(annihilation.get("zone_tile_rect", Rect2i()) == Rect2i(16, 64, 32, 64), "R3-SIDE-B uses the authored west-road reservation")
    _expect(StringName(String(annihilation.get("staging_route_name", &""))) == &"WestApproach", "R3-SIDE-B resolves the real WestApproach polyline")
    _expect(bool(annihilation.get("route_enters_reserved_zone", false)) and bool(annihilation.get("route_touches_town", false)), "WestApproach connects the town to the authored west-road quest site")
    _expect(not _contains_text(annihilation.get("geometry_blockers", PackedStringArray()) as PackedStringArray, "does not enter"), "west-road staging recognizes the source-authored route extension")
    _expect((annihilation.get("objective_binding_blockers", PackedStringArray()) as PackedStringArray).has("required_actor_ids"), "Annihilation staging remains blocked on an explicit designated hostile group")

    var defense: Dictionary = STAGING_SERVICE.descriptor_for_slot(snapshot, STAGING_SERVICE.SLOT_SIDE_C)
    _expect(StringName(String(defense.get("objective_family", &""))) == STAGING_SERVICE.FAMILY_DEFENSE, "R3-SIDE-C preserves Defense-family identity")
    _expect(defense.get("zone_tile_rect", Rect2i()) == Rect2i(40, 16, 72, 32), "R3-SIDE-C uses the authored north quest/ruins reservation")
    _expect(StringName(String(defense.get("staging_route_name", &""))) == &"NorthApproach", "R3-SIDE-C resolves the real NorthApproach polyline")
    _expect(bool(defense.get("route_enters_reserved_zone", false)) and bool(defense.get("route_touches_town", false)), "NorthApproach connects the town to the authored defense site")
    _expect(not _contains_text(defense.get("geometry_blockers", PackedStringArray()) as PackedStringArray, "does not enter"), "north defense staging recognizes the source-authored route extension")
    var defense_binding := defense.get("objective_binding_blockers", PackedStringArray()) as PackedStringArray
    _expect(defense_binding.has("objective_id") and defense_binding.has("objective_max_hp") and defense_binding.has("required_actor_ids_by_wave"), "Defense staging reports required protected-objective and wave authoring")
    _expect((defense.get("policy_blockers", PackedStringArray()) as PackedStringArray).has("leave_rule"), "Defense staging reports leave policy as missing instead of inventing it")

    town.queue_free()
    if _failures == 0:
        print("REGION 3 SIDE QUEST STAGING TEST PASS")
    else:
        push_error("REGION 3 SIDE QUEST STAGING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _matches_route_snapshot(town: Region3AuthoredTownLayout, descriptor: Dictionary) -> bool:
    var routes := town.get_node_or_null(town.routes_path) as Node2D
    if routes == null:
        return false
    var route := routes.get_node_or_null(String(descriptor.get("staging_route_name", &""))) as Line2D
    if route == null:
        return false
    var snapshot_points := descriptor.get("staging_route_points_tiles", PackedVector2Array()) as PackedVector2Array
    if snapshot_points.size() != route.points.size():
        return false
    for index: int in range(route.points.size()):
        var expected := town.to_local(route.to_global(route.points[index])) / float(town.tile_size)
        if not snapshot_points[index].is_equal_approx(expected):
            return false
    return true


func _contains_text(values: PackedStringArray, needle: String) -> bool:
    for value: String in values:
        if value.contains(needle):
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
