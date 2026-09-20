extends SceneTree

const WORLD_LAYOUT: Region3WorldLayoutDefinition = preload("res://src/world/region3/layout/region3_world_layout_definition.tres")
const TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var town := TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    _expect(town != null, "Region 3 world-layout fixture instantiates the authored town")
    if town == null:
        quit(1)
        return

    var structure_ids: Dictionary = {}
    for child: Node in town.get_children():
        var anchor := child as Region3TownStructureAnchor
        if anchor != null:
            structure_ids[anchor.structure_id] = true

    _expect(WORLD_LAYOUT != null, "Region 3 world-layout definition resource loads")
    _expect(WORLD_LAYOUT.validate_definition(structure_ids).is_empty(), "Region 3 world-layout definition validates against the authored structure identities")
    _expect(WORLD_LAYOUT.map_revision_id == town.map_revision_id, "world geography is bound to the exact authored map revision")
    _expect(WORLD_LAYOUT.map_size_tiles == Vector2i(160, 160), "world geography owns the 160x160 Region 3 reservation")

    _expect(WORLD_LAYOUT.zones.size() == 5, "world geography contains exactly the five traversable master-authored zone reservations")
    _expect_zone(&"R3-TOWN", Rect2i(48, 48, 64, 64), true, -1, -1)
    _expect_zone(&"R3-OUTSKIRTS", Rect2i(48, 112, 64, 32), false, 1, 2)
    _expect_zone(&"R3-ROADS", Rect2i(16, 64, 32, 64), false, 2, 4)
    _expect_zone(&"R3-RUINS", Rect2i(40, 16, 72, 32), false, 4, 7)
    _expect_zone(&"R3-RISK", Rect2i(112, 40, 32, 72), false, 8, 10)

    for raw_zone: Resource in WORLD_LAYOUT.zones:
        var zone := raw_zone as Region3WorldZoneDefinition
        if zone == null or zone.safe_zone:
            continue
        _expect(not zone.has_concrete_recommended_level(), "%s preserves a master tuning band without pretending one concrete Recommended Level is authored" % String(zone.zone_id))

    _expect(WORLD_LAYOUT.quest_marker_anchors.size() == 5, "world geography exposes exactly the five master-authored regional quest/encounter anchor bindings")
    _expect_quest_anchor(&"R3-MAIN-START", &"R3-TOWN", &"r3:functional:02")
    _expect_quest_anchor(&"R3-SIDE-A", &"R3-OUTSKIRTS")
    _expect_quest_anchor(&"R3-SIDE-B", &"R3-ROADS")
    _expect_quest_anchor(&"R3-SIDE-C", &"R3-RUINS")
    _expect_quest_anchor(&"R3-RISK-OPTIONAL", &"R3-RISK")

    for raw_anchor: Resource in WORLD_LAYOUT.quest_marker_anchors:
        var anchor := raw_anchor as Region3QuestMarkerAnchorDefinition
        if anchor == null:
            continue
        _expect(not anchor.exact_tile_authored and anchor.tile == Vector2i(-1, -1), "%s does not fabricate an exact quest-marker tile absent from the master" % String(anchor.anchor_id))

    _expect(WORLD_LAYOUT.checkpoint_anchors.is_empty(), "no regional checkpoint geometry is fabricated before exact checkpoint coordinates are authored")
    _expect(not WORLD_LAYOUT.has_authored_checkpoint_geometry(), "world geography reports checkpoint geometry unavailable while the master only permits checkpoints without placing them")
    _expect(not WORLD_LAYOUT.has_authored_quest_marker_geometry(), "world geography reports quest-marker geometry unavailable while exact quest tiles remain unauthored")
    _expect(not WORLD_LAYOUT.has_concrete_region_danger_data(), "world geography does not convert Recommended Level tuning bands into fabricated concrete danger data")
    var readiness: Dictionary = WORLD_LAYOUT.map_content_readiness()
    _expect(bool(readiness.get("explored_subzone_geometry_available", false)), "world-layout readiness exposes the existing authoritative subzone rectangles")
    _expect(
        StringName(readiness.get("explored_subzone_unavailable_reason_id", &"")) == Region3WorldLayoutDefinition.REASON_EXPLORED_SUBZONE_STATE_OWNER_UNAVAILABLE,
        "world-layout readiness reports only the missing discovery-state owner, not missing geometry"
    )
    _expect(
        StringName(readiness.get("quest_marker_unavailable_reason_id", &"")) == Region3WorldLayoutDefinition.REASON_QUEST_MARKER_GEOMETRY_UNAUTHORED,
        "world-layout readiness reports the exact quest-marker geometry blocker"
    )
    _expect(
        StringName(readiness.get("checkpoint_marker_unavailable_reason_id", &"")) == Region3WorldLayoutDefinition.REASON_CHECKPOINT_GEOMETRY_UNAUTHORED,
        "world-layout readiness reports the exact Region-checkpoint geometry blocker"
    )
    _expect(
        StringName(readiness.get("risk_marker_unavailable_reason_id", &"")) == Region3WorldLayoutDefinition.REASON_REGION_DANGER_CONCRETE_LEVEL_UNAUTHORED,
        "world-layout readiness reports the exact concrete Region danger blocker"
    )

    _test_fail_closed_validation(structure_ids)
    _test_exact_playtest_recommendations(structure_ids)

    town.queue_free()
    if _failures == 0:
        print("REGION 3 WORLD LAYOUT DEFINITION TEST PASS")
    else:
        push_error("REGION 3 WORLD LAYOUT DEFINITION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect_zone(
    zone_id: StringName,
    expected_rect: Rect2i,
    safe_zone: bool,
    expected_min: int,
    expected_max: int
) -> void:
    var zone := WORLD_LAYOUT.get_zone(zone_id)
    _expect(zone != null, "%s zone definition exists" % String(zone_id))
    if zone == null:
        return
    _expect(zone.tile_rect == expected_rect, "%s owns the exact master-authored reservation" % String(zone_id))
    _expect(zone.safe_zone == safe_zone, "%s preserves the authored safe/hostile ownership" % String(zone_id))
    _expect(zone.recommended_level_min == expected_min and zone.recommended_level_max == expected_max, "%s preserves only its authored Recommended Level band" % String(zone_id))
    _expect(zone.recommended_level == -1, "%s keeps its exact PLAYTEST Recommended Level unauthored" % String(zone_id))


func _expect_quest_anchor(anchor_id: StringName, zone_id: StringName, structure_id: StringName = &"") -> void:
    var anchor := WORLD_LAYOUT.get_quest_anchor(anchor_id)
    _expect(anchor != null, "%s quest/encounter anchor binding exists" % String(anchor_id))
    if anchor == null:
        return
    _expect(anchor.zone_id == zone_id, "%s is owned by the master-authored Region 3 zone" % String(anchor_id))
    _expect(anchor.structure_id == structure_id, "%s preserves only the explicitly authored structure binding" % String(anchor_id))


func _test_fail_closed_validation(structure_ids: Dictionary) -> void:
    var overlapping := WORLD_LAYOUT.duplicate(true) as Region3WorldLayoutDefinition
    var overlap_zone := overlapping.get_zone(&"R3-RISK")
    overlap_zone.tile_rect = Rect2i(100, 80, 32, 32)
    _expect(_contains(overlapping.validate_definition(structure_ids), "zone rectangles must not overlap"), "overlapping zone ownership is rejected")

    var bad_marker := Region3QuestMarkerAnchorDefinition.new()
    bad_marker.anchor_id = &"R3-SIDE-A"
    bad_marker.zone_id = &"R3-OUTSKIRTS"
    bad_marker.tile = Vector2i(70, 120)
    _expect(_contains(bad_marker.validate_definition(_zone_id_set()), "tile must remain unset until an exact quest-marker tile is authored"), "quest marker coordinates cannot be smuggled in without explicit exact-tile authoring")

    var bad_structure := Region3QuestMarkerAnchorDefinition.new()
    bad_structure.anchor_id = &"R3-MAIN-START"
    bad_structure.zone_id = &"R3-TOWN"
    bad_structure.structure_id = &"r3:functional:99"
    _expect(_contains(bad_structure.validate_definition(_zone_id_set(), structure_ids), "structure_id must reference an authored Region 3 structure"), "quest anchors cannot bind an invented Region 3 structure")

    var wrong_zone_marker := WORLD_LAYOUT.duplicate(true) as Region3WorldLayoutDefinition
    var side_a := wrong_zone_marker.get_quest_anchor(&"R3-SIDE-A")
    side_a.exact_tile_authored = true
    side_a.tile = Vector2i(80, 80)
    _expect(_contains(wrong_zone_marker.validate_definition(structure_ids), "exact quest-marker tile must belong to its declared zone"), "exact quest-marker geometry cannot escape its declared zone")

    var bad_checkpoint := Region3CheckpointAnchorDefinition.new()
    bad_checkpoint.checkpoint_id = &"checkpoint:test"
    bad_checkpoint.zone_id = &"R3-OUTSKIRTS"
    bad_checkpoint.tile = Vector2i(200, 200)
    _expect(_contains(bad_checkpoint.validate_definition(Vector2i(160, 160), _zone_id_set()), "checkpoint tile must be an exact authored tile inside Region 3"), "checkpoint geometry fails closed outside the authored map")

    var wrong_zone_checkpoint_layout := WORLD_LAYOUT.duplicate(true) as Region3WorldLayoutDefinition
    var wrong_zone_checkpoint := Region3CheckpointAnchorDefinition.new()
    wrong_zone_checkpoint.checkpoint_id = &"checkpoint:test_wrong_zone"
    wrong_zone_checkpoint.zone_id = &"R3-OUTSKIRTS"
    wrong_zone_checkpoint.tile = Vector2i(80, 80)
    wrong_zone_checkpoint_layout.checkpoint_anchors.append(wrong_zone_checkpoint)
    _expect(_contains(wrong_zone_checkpoint_layout.validate_definition(structure_ids), "checkpoint tile must belong to its declared zone"), "checkpoint geometry cannot escape its declared zone")


func _test_exact_playtest_recommendations(structure_ids: Dictionary) -> void:
    var provisional := WORLD_LAYOUT.duplicate(true) as Region3WorldLayoutDefinition
    for raw_zone: Resource in provisional.zones:
        var zone := raw_zone as Region3WorldZoneDefinition
        if zone != null and not zone.safe_zone and zone.travel_destination:
            zone.recommended_level = zone.recommended_level_min
    _expect(provisional.validate_definition(structure_ids).is_empty(), "Inspector-authored exact PLAYTEST recommendations within master bands validate")
    _expect(provisional.has_concrete_region_danger_data(), "all four exact recommendations enable concrete Region danger data")
    _expect(bool(provisional.map_content_readiness().get("risk_marker_data_available", false)), "Region danger content readiness follows explicit authored values")

    provisional.get_zone(&"R3-ROADS").recommended_level = -1
    _expect(not provisional.has_concrete_region_danger_data(), "a single unauthored hostile zone keeps Region danger markers unavailable")
    provisional.get_zone(&"R3-ROADS").recommended_level = 99
    _expect(_contains(provisional.validate_definition(structure_ids), "exact Recommended Level must belong"), "out-of-band exact recommendations cannot silently override master tuning ranges")
    provisional.get_zone(&"R3-TOWN").recommended_level = 1
    _expect(_contains(provisional.validate_definition(structure_ids), "safe zones must not publish"), "town safety cannot become an invented numeric Danger rank")
    _expect(not WORLD_LAYOUT.has_concrete_region_danger_data(), "fixture mutations do not author production recommended levels")


func _zone_id_set() -> Dictionary:
    var result: Dictionary = {}
    for raw_zone: Resource in WORLD_LAYOUT.zones:
        var zone := raw_zone as Region3WorldZoneDefinition
        if zone != null:
            result[zone.zone_id] = true
    return result


func _contains(errors: PackedStringArray, fragment: String) -> bool:
    for error: String in errors:
        if error.contains(fragment):
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
