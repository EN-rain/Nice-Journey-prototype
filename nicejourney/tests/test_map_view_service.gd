extends SceneTree

const DISCOVERY_SERVICE_SCRIPT: Script = preload("res://src/world/tower/tower_floor_discovery_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_layer_identity_and_world_context()
    _test_region_context()
    _test_tower_identity_without_room_leak()
    _test_invalid_contexts()

    if _failures == 0:
        print("MAP VIEW SERVICE TEST PASS")
    else:
        push_error("MAP VIEW SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_layer_identity_and_world_context() -> void:
    var descriptors := MapViewService.layer_descriptors()
    _expect(descriptors.size() == 3, "map view service exposes exactly three map layers")
    _expect(MapViewService.validate_layer_descriptors().is_empty(), "map view layer descriptors satisfy the locked identity validator")
    _expect(StringName(descriptors[0]["layer_id"]) == MapLayerIdentityValidator.LAYER_WORLD_MAP, "World layer remains first")
    _expect(StringName(descriptors[1]["layer_id"]) == MapLayerIdentityValidator.LAYER_REGION_MAP, "Region layer remains second")
    _expect(StringName(descriptors[2]["layer_id"]) == MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP, "Tower Floor layer remains third")

    var profile := ProfileSnapshot.new()
    var result := MapViewService.build_layer(profile, MapLayerIdentityValidator.LAYER_WORLD_MAP)
    _expect(bool(result.get("accepted", false)), "World map layer builds from an existing profile")
    var regions := result.get("regions", []) as Array
    _expect(regions.size() == 12, "World map exposes exactly the twelve locked region identities")
    var playable_count := 0
    var future_locked_count := 0
    for region_variant: Variant in regions:
        var region := region_variant as Dictionary
        var region_id := int(region.get("region_id", 0))
        if bool(region.get("playable", false)):
            playable_count += 1
            _expect(region_id == 3 and StringName(region.get("state", &"")) == WorldRegionCatalogValidator.STATE_PROTOTYPE_STARTING_REGION, "only Region 3 is the playable prototype region")
        elif StringName(region.get("state", &"")) == WorldRegionCatalogValidator.STATE_FUTURE_LOCKED:
            future_locked_count += 1
    _expect(playable_count == 1 and future_locked_count == 11, "World map keeps the other eleven regions future-locked")
    _expect(not bool(result.get("region_discovery_state_available", true)), "World map does not fabricate per-region discovery state")
    _expect(not bool(result.get("travel_action_available", true)), "World map cannot grant travel")


func _test_region_context() -> void:
    var result := MapViewService.build_layer(ProfileSnapshot.new(), MapLayerIdentityValidator.LAYER_REGION_MAP)
    _expect(bool(result.get("accepted", false)), "Region map layer builds")
    _expect(int(result.get("region_id", 0)) == 3, "Region map is scoped to the sole prototype Region 3")
    _expect(StringName(result.get("map_revision_id", &"")) == Region3AuthoredTownLayout.MAP_REVISION_ID, "Region map exposes the authoritative authored map revision")
    _expect(result.get("map_size_tiles", Vector2i.ZERO) == Vector2i(160, 160), "Region map exposes the locked 160x160 authored reservation")
    _expect(int(result.get("structure_count", 0)) == 20, "Region map reports the locked 20-structure manifest")
    _expect(int(result.get("functional_structure_count", 0)) == 8 and int(result.get("decorative_structure_count", 0)) == 12, "Region map keeps the locked 8 functional / 12 decorative split")
    _expect(result.get("town_tile_rect", Rect2i()) == Rect2i(48, 48, 64, 64) and result.get("plaza_tile_rect", Rect2i()) == Rect2i(69, 81, 23, 13), "Region map consumes the exact authored town/plaza reservations")
    var region_routes := result.get("route_polylines", []) as Array
    _expect(region_routes.size() == 13, "Region map exposes all 13 authored road/connector polylines")
    var region_landmarks := result.get("public_landmarks", []) as Array
    _expect(region_landmarks.size() == 1 and StringName((region_landmarks[0] as Dictionary).get("landmark_kind", &"")) == Region3TownStructureManifestValidator.ROLE_CENTRAL_TOWER, "Region map exposes only the fixed Central Tower landmark before service discovery exists")
    _expect(not str(result).contains("blacksmith") and not str(result).contains("general_merchant") and not str(result).contains("quest_hall"), "Region map geometry does not leak undiscovered service identities")
    _expect(bool(result.get("service_discovery_state_available", false)), "Region map recognizes the live profile-backed service discovery owner")
    _expect(bool(result.get("world_layout_definition_available", false)), "Region map consumes the validated authored Region 3 world-layout definition")
    _expect((result.get("discovered_services", []) as Array).is_empty(), "Region map exposes no service marker before any service interaction is discovered")
    _expect(bool(result.get("explored_subzone_geometry_available", false)), "Region map exposes that authoritative subzone geometry exists")
    _expect(not bool(result.get("explored_subzone_state_available", true)) and (result.get("explored_subzones", []) as Array).is_empty(), "Region map keeps explored-subzone state unavailable before physical traversal initializes discovery")
    _expect(StringName(result.get("explored_subzone_unavailable_reason_id", &"")) == Region3SubzoneDiscoveryService.REASON_STATE_UNINITIALIZED, "Region map exposes the exact uninitialized-discovery blocker")
    _expect(not bool(result.get("quest_marker_state_available", true)) and (result.get("quest_markers", []) as Array).is_empty(), "Region map keeps quest markers explicitly unavailable without authored anchors")
    _expect(StringName(result.get("quest_marker_unavailable_reason_id", &"")) == Region3WorldLayoutDefinition.REASON_QUEST_MARKER_GEOMETRY_UNAUTHORED, "Region map exposes the exact quest-marker geometry blocker")
    _expect(not bool(result.get("quest_anchor_discovery_state_available", true)), "Region map does not fabricate quest-anchor discovery state")
    _expect(not bool(result.get("checkpoint_marker_state_available", true)) and (result.get("checkpoint_markers", []) as Array).is_empty(), "Region map keeps checkpoint markers unavailable without authored checkpoint geometry")
    _expect(StringName(result.get("checkpoint_marker_unavailable_reason_id", &"")) == Region3WorldLayoutDefinition.REASON_CHECKPOINT_GEOMETRY_UNAUTHORED, "Region map exposes the exact checkpoint geometry blocker")
    _expect(not bool(result.get("risk_marker_state_available", true)) and (result.get("risk_markers", []) as Array).is_empty(), "Region map does not fabricate risk-marker state")
    _expect(StringName(result.get("risk_marker_unavailable_reason_id", &"")) == Region3WorldLayoutDefinition.REASON_REGION_DANGER_CONCRETE_LEVEL_UNAUTHORED, "Region map exposes the exact concrete danger-data blocker")
    _expect(not bool(result.get("travel_action_available", true)), "Region map cannot grant travel")


func _test_tower_identity_without_room_leak() -> void:
    var profile := ProfileSnapshot.new()
    profile.level = 2
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_4_unlocked"] = true
    profile.quest_progress["primary_floor_4"] = {"state": QuestProgressState.STATE_ACTIVE}
    var no_floor := MapViewService.build_layer(profile, MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP)
    _expect(bool(no_floor.get("accepted", false)) and not bool(no_floor.get("available", true)), "Tower map remains a valid layer when no current generated floor exists")
    _expect((no_floor.get("room_entries", []) as Array).is_empty() and bool(no_floor.get("room_geometry_withheld", false)), "Tower map with no floor exposes no hidden room geometry")
    var no_floor_travel := no_floor.get("eligible_travel_floors", []) as Array
    _expect(bool(no_floor.get("travel_eligibility_available", false)) and no_floor_travel.size() == 1 and int((no_floor_travel[0] as Dictionary).get("floor_id", 0)) == 4, "Tower map may inspect authoritative eligible travel even when no generated floor view is active")
    _expect(int(no_floor.get("travel_player_level", 0)) == 2, "Tower map pre-entry snapshot preserves the authoritative player level")
    if no_floor_travel.size() == 1:
        var floor4_travel := no_floor_travel[0] as Dictionary
        _expect(int(floor4_travel.get("recommended_level", 0)) == 4, "Tower map pre-entry snapshot preserves authoritative Recommended Level")
        _expect(StringName(floor4_travel.get("main_objective_quest_id", &"")) == &"primary_floor_4", "Tower map identifies the actually-active primary floor objective without inventing one")
        _expect((floor4_travel.get("active_quest_ids", []) as Array).has(&"primary_floor_4"), "Tower map preserves authoritative active quest identity")
        _expect(not bool(floor4_travel.get("special_hazard_state_available", true)) and (floor4_travel.get("known_special_hazards", []) as Array).is_empty(), "Tower map leaves special hazards Unknown when no authored hazard owner exists")
    _expect(not bool(no_floor.get("travel_action_available", true)), "read-only eligibility never grants a map travel action")

    profile.permanent_flags["tower_floor_10_unlocked"] = true
    var warning_snapshot := MapViewService.build_layer(profile, MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP)
    var floor10_entry: Dictionary = {}
    for raw_entry: Variant in warning_snapshot.get("eligible_travel_floors", []) as Array:
        if raw_entry is Dictionary and int((raw_entry as Dictionary).get("floor_id", 0)) == 10:
            floor10_entry = raw_entry as Dictionary
            break
    _expect(not floor10_entry.is_empty() and bool(floor10_entry.get("elite_warning", false)) and int(floor10_entry.get("elite_target", 0)) == 3, "Tower map preserves the authoritative Floor 10 elite warning target")
    _expect(bool(floor10_entry.get("boss_warning", false)) and int(floor10_entry.get("recommended_level", 0)) == 10, "Tower map preserves authoritative Floor 10 boss and Recommended Level warnings")
    profile.permanent_flags.erase("tower_floor_10_unlocked")

    var floor4 := _floor_state(4, &"floor_instance:test:floor_4", &"tower_layout:test_floor_4", false)
    floor4.layout_manifest = {
        "rooms": [
            {"room_instance_id": &"room:discovered_fixture", "rect": Rect2i(2, 3, 6, 5), "tags": [&"combat", &"secret"], "module_id": &"module:hidden_semantics"},
            {"room_instance_id": &"room:undiscovered_fixture", "rect": Rect2i(12, 3, 8, 7), "tags": [&"boss"], "module_id": &"module:hidden_semantics_2"},
        ],
        "edges": [{"from_room_id": &"room:discovered_fixture", "to_room_id": &"room:undiscovered_fixture"}],
    }
    floor4.add_checkpoint_anchor(&"checkpoint:visible_fixture", &"room:discovered_fixture", Vector2i(1, 1))
    floor4.add_checkpoint_anchor(&"checkpoint:hidden_fixture", &"room:undiscovered_fixture", Vector2i(1, 1))
    profile.tower_floor_states["4"] = floor4.to_dictionary()
    profile.safe_state = {"floor_id": 4}

    var result := MapViewService.build_layer(profile, MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP)
    _expect(bool(result.get("accepted", false)) and bool(result.get("available", false)), "Tower map exposes valid current floor identity")
    _expect(int(result.get("floor_id", 0)) == 4 and StringName(result.get("instance_id", &"")) == floor4.instance_id, "Tower map reports the exact persisted current floor identity")
    _expect(StringName(result.get("layout_revision_id", &"")) == floor4.layout_revision_id, "Tower map reports the exact persisted layout revision")
    _expect(int(result.get("checkpoint_count", 0)) == 2, "Tower map may report registered checkpoint count without exposing hidden marker positions")
    _expect(int(result.get("visible_checkpoint_count", -1)) == 0 and (result.get("checkpoint_markers", []) as Array).is_empty(), "Tower map exposes no checkpoint marker before its anchored room is discovered")
    _expect(int(result.get("visible_connection_count", -1)) == 0 and (result.get("room_connections", []) as Array).is_empty(), "Tower map exposes no connection while either endpoint remains undiscovered")
    _expect(int(result.get("visible_risk_marker_count", -1)) == 0 and (result.get("risk_markers", []) as Array).is_empty(), "Tower map exposes no risk marker before the room itself is discovered")
    _expect(not result.has("layout_manifest"), "Tower map does not return the persisted full layout manifest")
    _expect((result.get("room_entries", []) as Array).is_empty(), "Tower map exposes no generated room before physical discovery")
    _expect(bool(result.get("room_discovery_state_available", false)) and bool(result.get("room_geometry_withheld", false)), "Tower map owns discovery state while continuing to withhold undiscovered geometry")
    _expect(not bool(result.get("travel_action_available", true)), "Tower map cannot bypass Tower Access travel rules")

    var discovered: Dictionary = DISCOVERY_SERVICE_SCRIPT.mark_room_discovered(profile, 4, &"room:discovered_fixture")
    _expect(bool(discovered.get("accepted", false)) and bool(discovered.get("changed", false)), "authoritative room discovery updates the persisted floor state")
    var discovered_result := MapViewService.build_layer(profile, MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP)
    var visible_rooms := discovered_result.get("room_entries", []) as Array
    _expect(int(discovered_result.get("discovered_room_count", 0)) == 1 and visible_rooms.size() == 1, "Tower map exposes exactly the discovered room count")
    if visible_rooms.size() == 1:
        var visible_room := visible_rooms[0] as Dictionary
        _expect(StringName(visible_room.get("room_instance_id", &"")) == &"room:discovered_fixture" and visible_room.get("rect", Rect2i()) == Rect2i(2, 3, 6, 5), "Tower map exposes the discovered room's authored geometry")
        _expect(not visible_room.has("tags") and not visible_room.has("module_id"), "Tower map does not leak semantic tags/module identity with discovered geometry")
    var risks := discovered_result.get("risk_markers", []) as Array
    _expect(int(discovered_result.get("visible_risk_marker_count", 0)) == 1 and risks.size() == 1, "Tower map exposes risk only for the discovered room")
    if risks.size() == 1:
        var risk := risks[0] as Dictionary
        _expect(StringName(risk.get("room_instance_id", &"")) == &"room:discovered_fixture" and StringName(risk.get("risk_id", &"")) == DISCOVERY_SERVICE_SCRIPT.RISK_COMBAT, "discovered combat room exposes only the stable combat risk marker")
        _expect(not risk.has("tags") and not risk.has("module_id"), "risk marker does not leak unrelated room semantics")
    var markers := discovered_result.get("checkpoint_markers", []) as Array
    _expect(int(discovered_result.get("visible_checkpoint_count", 0)) == 1 and markers.size() == 1, "Tower map exposes only checkpoints anchored inside discovered rooms")
    if markers.size() == 1:
        var marker := markers[0] as Dictionary
        _expect(StringName(marker.get("checkpoint_id", &"")) == &"checkpoint:visible_fixture" and marker.get("world_tile", Vector2i.ZERO) == Vector2i(3, 4), "visible checkpoint marker resolves its authored local anchor into exact world-tile geometry")
    _expect(int(discovered_result.get("visible_connection_count", -1)) == 0 and (discovered_result.get("room_connections", []) as Array).is_empty(), "Tower map withholds an edge whose other endpoint is still undiscovered")
    _expect(not str(discovered_result).contains("room:undiscovered_fixture") and not str(discovered_result).contains("checkpoint:hidden_fixture"), "Tower map result leaks neither undiscovered room identity nor its checkpoint marker")

    var second_discovery: Dictionary = DISCOVERY_SERVICE_SCRIPT.mark_room_discovered(profile, 4, &"room:undiscovered_fixture")
    _expect(bool(second_discovery.get("accepted", false)) and bool(second_discovery.get("changed", false)), "second physical discovery may reveal the formerly hidden connected room")
    var connected_result := MapViewService.build_layer(profile, MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP)
    var connections := connected_result.get("room_connections", []) as Array
    _expect(int(connected_result.get("visible_connection_count", 0)) == 1 and connections.size() == 1, "Tower map reveals a navigation edge only after both endpoint rooms are discovered")
    var connected_risks := connected_result.get("risk_markers", []) as Array
    _expect(int(connected_result.get("visible_risk_marker_count", 0)) == 2 and connected_risks.size() == 2, "Tower map reveals boss risk only after the boss room is discovered")
    _expect(str(connected_risks).contains("risk:combat") and str(connected_risks).contains("risk:boss"), "discovered risk markers retain stable combat and boss identities")
    if connections.size() == 1:
        var connection := connections[0] as Dictionary
        var endpoints: Array[StringName] = [StringName(connection.get("from_room_id", &"")), StringName(connection.get("to_room_id", &""))]
        endpoints.sort()
        _expect(endpoints == [&"room:discovered_fixture", &"room:undiscovered_fixture"], "visible Tower connection preserves the exact authored discovered endpoints")

    var guard := GameplayOperationGuard.new()
    var blocker := guard.acquire_blocker(&"test:map_travel_block", GameplayOperationGuard.REASON_ACTIVE_COMBAT, "Active combat", [GameplayOperationGuard.OP_SIGIL_TRAVEL])
    _expect(blocker > 0, "map eligibility fixture acquires the shared Sigil-travel blocker")
    var blocked_travel := MapViewService.build_layer(profile, MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP, 4, guard)
    _expect(not bool(blocked_travel.get("travel_eligibility_available", true)) and StringName(blocked_travel.get("travel_eligibility_reason_id", &"")) == TowerAccessMenuService.REASON_OPERATION_BLOCKED, "Tower map reuses the authoritative operation guard for blocked travel eligibility")
    _expect((blocked_travel.get("eligible_travel_floors", []) as Array).is_empty() and not bool(blocked_travel.get("travel_action_available", true)), "blocked travel snapshot exposes neither eligible entries nor a travel action")
    guard.release_blocker(blocker)
    guard.free()

    var floor7 := _floor_state(7, &"floor_instance:test:floor_7", &"tower_layout:test_floor_7", true)
    profile.tower_floor_states["7"] = floor7.to_dictionary()
    var active_override := MapViewService.build_layer(profile, MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP, 7)
    _expect(int(active_override.get("floor_id", 0)) == 7 and bool(active_override.get("primary_cleared", false)), "live active floor identity takes precedence over a stale safe-state floor")

    var profile_before := profile.to_dictionary()
    (result.get("room_entries", []) as Array).append({"fake": true})
    result["instance_id"] = &"mutated:result"
    _expect(profile.to_dictionary() == profile_before, "mutating returned map data cannot mutate persistent profile/floor state")


func _test_invalid_contexts() -> void:
    var null_profile := MapViewService.build_layer(null, MapLayerIdentityValidator.LAYER_WORLD_MAP)
    _expect(not bool(null_profile.get("accepted", true)) and StringName(null_profile.get("reason_id", &"")) == MapViewService.REASON_INVALID_PROFILE, "map view rejects a missing profile")
    var unknown := MapViewService.build_layer(ProfileSnapshot.new(), &"minimap")
    _expect(not bool(unknown.get("accepted", true)) and StringName(unknown.get("reason_id", &"")) == MapViewService.REASON_UNKNOWN_LAYER, "map view rejects unknown layer IDs")

    var unsigiled := ProfileSnapshot.new()
    var unsigiled_tower := MapViewService.build_layer(unsigiled, MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP)
    _expect(not bool(unsigiled_tower.get("travel_eligibility_available", true)) and StringName(unsigiled_tower.get("travel_eligibility_reason_id", &"")) == TowerAccessMenuService.REASON_SIGIL_NOT_OWNED, "Tower map reports the existing Sigil requirement instead of inventing travel eligibility")

    var profile := ProfileSnapshot.new()
    profile.safe_state = {"floor_id": 5}
    profile.tower_floor_states["5"] = {"floor_id": 5}
    var invalid_floor := MapViewService.build_layer(profile, MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP)
    _expect(bool(invalid_floor.get("accepted", false)) and not bool(invalid_floor.get("available", true)), "invalid persisted tower data cannot become visible floor map data")
    _expect(StringName(invalid_floor.get("reason_id", &"")) == MapViewService.REASON_FLOOR_STATE_INVALID, "invalid tower floor state is reported explicitly")
    _expect((invalid_floor.get("room_entries", []) as Array).is_empty(), "invalid tower floor state leaks no room data")


func _floor_state(floor_id: int, instance_id: StringName, revision_id: StringName, cleared: bool) -> FloorInstanceState:
    var state := FloorInstanceState.new()
    state.floor_id = floor_id
    state.instance_id = instance_id
    state.seed = floor_id * 100
    state.layout_revision_id = revision_id
    state.layout_manifest = {}
    state.primary_cleared = cleared
    return state


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
