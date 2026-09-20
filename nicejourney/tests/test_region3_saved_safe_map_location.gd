extends SceneTree

const LAYOUT_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var layout := LAYOUT_SCENE.instantiate() as Region3AuthoredTownLayout
    var profile := ProfileCreationService.create_profile(1, "Saved Location", "melee")
    _expect(layout != null and layout.validate_layout().is_empty(), "authored Region 3 layout loads")
    var empty := Region3MapSnapshotService.build_from_layout(layout, profile)
    _expect((empty.get("saved_safe_location", {}) as Dictionary).is_empty(), "new profile does not invent a saved checkpoint")

    var safe := SafeCheckpointState.make(
        &"safe:region3_test", &"region:3", 0, &"checkpoint:region3_town",
        {"position_x": 1920.0, "position_y": 2560.0}, {}, 1)
    _expect(not safe.is_empty(), "test safe state has the actual Region map/checkpoint identities")
    profile.safe_state = safe
    _expect((Region3MapSnapshotService.build_from_layout(layout, profile).get("saved_safe_location", {}) as Dictionary).is_empty(), "saved position without physical discovery does not reveal region geometry")
    _expect(bool(Region3SubzoneDiscoveryService.mark_local_position_explored(profile, layout, Vector2(1920, 2560)).get("accepted", false)), "physically visited town tile is recorded")
    var discovered := Region3MapSnapshotService.build_from_layout(layout, profile)
    var location := discovered.get("saved_safe_location", {}) as Dictionary
    _expect(location.get("position_tiles", Vector2.INF) == Vector2(60, 80), "saved position is converted from real safe-state pixels to authored map tiles")
    _expect(location.get("checkpoint_id", &"") == &"checkpoint:region3_town" and location.get("snapshot_id", &"") == &"safe:region3_test", "saved marker retains safe-state identity")
    _expect(location.get("zone_id", &"") == &"R3-TOWN" and location.get("source_id", &"") == &"profile_safe_state", "saved marker is scoped to actually discovered zone and provenance")
    _expect(not bool(location.get("fixed_authored_checkpoint", true)) and not bool(location.get("travel_action_available", true)), "saved location cannot grant fixed checkpoint or fast travel")
    _expect(not bool(discovered.get("checkpoint_marker_state_available", true)) and (discovered.get("checkpoint_markers", []) as Array).is_empty(), "dynamic saved location never promotes unauthored fixed checkpoints")
    _expect(not bool(discovered.get("quest_marker_state_available", true)) and (discovered.get("quest_markers", []) as Array).is_empty(), "saved location cannot reveal unauthored quest tiles")
    var invalid_fields := [
        {"position_x": INF, "position_y": 2560.0},
        {"position_x": 5120.0, "position_y": 2560.0},
        {"position_x": -1.0, "position_y": 2560.0},
        {"position_x": 1920.0, "position_y": 0.0},
        {"position_x": "1920", "position_y": 2560.0},
    ]
    for invalid: Dictionary in invalid_fields:
        profile.safe_state = safe.duplicate(true)
        profile.safe_state["player_state"] = invalid
        _expect((Region3MapSnapshotService.build_from_layout(layout, profile).get("saved_safe_location", {}) as Dictionary).is_empty(), "malformed/outside/undiscovered safe position fails closed")

    profile.safe_state = safe.duplicate(true)
    profile.safe_state["map_id"] = "tower:floor_1"
    profile.safe_state["floor_id"] = 1
    _expect((Region3MapSnapshotService.build_from_layout(layout, profile).get("saved_safe_location", {}) as Dictionary).is_empty(), "Tower safe state cannot masquerade as a Region checkpoint")
    profile.safe_state = safe.duplicate(true)
    profile.safe_state["checkpoint_anchor_id"] = "checkpoint:unknown"
    _expect((Region3MapSnapshotService.build_from_layout(layout, profile).get("saved_safe_location", {}) as Dictionary).is_empty(), "unrecognized checkpoint identity is hidden")
    profile.safe_state = safe.duplicate(true)
    profile.region_state["map_revision_id"] = "region3_town_layout_v99"
    _expect((Region3MapSnapshotService.build_from_layout(layout, profile).get("saved_safe_location", {}) as Dictionary).is_empty(), "mismatched Region map revision suppresses saved marker")

    var world := layout.world_layout_definition.duplicate(true) as Region3WorldLayoutDefinition
    var checkpoint := Region3CheckpointAnchorDefinition.new()
    checkpoint.checkpoint_id = &"checkpoint:test_invalid"
    checkpoint.zone_id = &"R3-ROADS"
    checkpoint.tile = Vector2i(80, 80)
    world.checkpoint_anchors.append(checkpoint)
    _expect(not world.has_authored_checkpoint_geometry(), "wrong-zone checkpoint coordinates cannot set geometry ready")
    checkpoint.tile = Vector2i(20, 80)
    _expect(world.has_authored_checkpoint_geometry(), "valid explicitly authored checkpoint tile can set geometry ready in a test-only resource")
    for raw_anchor: Resource in world.quest_marker_anchors:
        var anchor := raw_anchor as Region3QuestMarkerAnchorDefinition
        var zone := world.get_zone(anchor.zone_id)
        anchor.exact_tile_authored = true
        anchor.tile = zone.tile_rect.position + Vector2i.ONE # Test-only geometry, never shipped.
    _expect(world.has_authored_quest_marker_geometry(), "five validated test-only exact quest tiles can set geometry ready")
    world.get_quest_anchor(&"R3-SIDE-A").tile = Vector2i(80, 80)
    _expect(not world.has_authored_quest_marker_geometry(), "wrong-zone marker cannot set authored quest geometry ready")

    layout.free()
    if _failures == 0:
        print("REGION 3 SAVED SAFE MAP LOCATION TEST PASS")
    else:
        push_error("REGION 3 SAVED SAFE MAP LOCATION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
