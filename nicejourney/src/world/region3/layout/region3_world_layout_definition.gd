class_name Region3WorldLayoutDefinition
extends Resource

const REQUIRED_ZONE_IDS: Array[StringName] = [
    &"R3-TOWN",
    &"R3-OUTSKIRTS",
    &"R3-ROADS",
    &"R3-RUINS",
    &"R3-RISK",
]

const REQUIRED_QUEST_ANCHOR_IDS: Array[StringName] = [
    &"R3-MAIN-START",
    &"R3-SIDE-A",
    &"R3-SIDE-B",
    &"R3-SIDE-C",
    &"R3-RISK-OPTIONAL",
]

const REASON_EXPLORED_SUBZONE_GEOMETRY_STATE_UNAVAILABLE: StringName = &"explored_subzone_geometry_state_unavailable"
const REASON_EXPLORED_SUBZONE_STATE_OWNER_UNAVAILABLE: StringName = &"explored_subzone_state_owner_unavailable"
const REASON_QUEST_MARKER_GEOMETRY_UNAUTHORED: StringName = &"quest_marker_geometry_unauthored"
const REASON_CHECKPOINT_GEOMETRY_UNAUTHORED: StringName = &"checkpoint_geometry_unauthored"
const REASON_REGION_DANGER_CONCRETE_LEVEL_UNAUTHORED: StringName = &"region_danger_concrete_level_unauthored"
const REASON_QUEST_MARKER_STATE_OWNER_UNAVAILABLE: StringName = &"quest_marker_state_owner_unavailable"
const REASON_CHECKPOINT_MARKER_STATE_OWNER_UNAVAILABLE: StringName = &"checkpoint_marker_state_owner_unavailable"
const REASON_REGION_DANGER_STATE_OWNER_UNAVAILABLE: StringName = &"region_danger_state_owner_unavailable"

@export var map_revision_id: StringName = &""
@export var map_size_tiles: Vector2i = Vector2i.ZERO
@export var zones: Array[Resource] = []
@export var quest_marker_anchors: Array[Resource] = []
@export var checkpoint_anchors: Array[Resource] = []


func validate_definition(known_structure_ids: Dictionary = {}) -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(map_revision_id)):
        errors.append("map_revision_id must be a stable ID")
    if map_size_tiles.x <= 0 or map_size_tiles.y <= 0:
        errors.append("map_size_tiles must be positive")

    var zone_ids: Dictionary = {}
    var typed_zones: Array[Region3WorldZoneDefinition] = []
    for index: int in range(zones.size()):
        var zone := zones[index] as Region3WorldZoneDefinition
        if zone == null:
            errors.append("zones[%d] must be a Region3WorldZoneDefinition" % index)
            continue
        for zone_error: String in zone.validate_definition(map_size_tiles):
            errors.append("%s: %s" % [String(zone.zone_id), zone_error])
        if zone_ids.has(zone.zone_id):
            errors.append("duplicate zone_id %s" % String(zone.zone_id))
        zone_ids[zone.zone_id] = true
        typed_zones.append(zone)

    for required_zone_id: StringName in REQUIRED_ZONE_IDS:
        if not zone_ids.has(required_zone_id):
            errors.append("missing required zone_id %s" % String(required_zone_id))
    if zone_ids.size() != REQUIRED_ZONE_IDS.size():
        errors.append("Region 3 world layout must contain exactly the five authored travel/subzone reservations")

    for first_index: int in range(typed_zones.size()):
        for second_index: int in range(first_index + 1, typed_zones.size()):
            if _rects_overlap(typed_zones[first_index].tile_rect, typed_zones[second_index].tile_rect):
                errors.append(
                    "zone rectangles must not overlap: %s / %s"
                    % [String(typed_zones[first_index].zone_id), String(typed_zones[second_index].zone_id)]
                )

    var quest_ids: Dictionary = {}
    for index: int in range(quest_marker_anchors.size()):
        var anchor := quest_marker_anchors[index] as Region3QuestMarkerAnchorDefinition
        if anchor == null:
            errors.append("quest_marker_anchors[%d] must be a Region3QuestMarkerAnchorDefinition" % index)
            continue
        for anchor_error: String in anchor.validate_definition(zone_ids, known_structure_ids):
            errors.append("%s: %s" % [String(anchor.anchor_id), anchor_error])
        if anchor.exact_tile_authored:
            var anchor_zone := get_zone(anchor.zone_id)
            if anchor_zone != null and not anchor_zone.tile_rect.has_point(anchor.tile):
                errors.append("%s: exact quest-marker tile must belong to its declared zone" % String(anchor.anchor_id))
        if quest_ids.has(anchor.anchor_id):
            errors.append("duplicate quest anchor_id %s" % String(anchor.anchor_id))
        quest_ids[anchor.anchor_id] = true

    for required_anchor_id: StringName in REQUIRED_QUEST_ANCHOR_IDS:
        if not quest_ids.has(required_anchor_id):
            errors.append("missing required quest anchor_id %s" % String(required_anchor_id))
    if quest_ids.size() != REQUIRED_QUEST_ANCHOR_IDS.size():
        errors.append("Region 3 world layout must contain exactly the five master-authored regional quest/encounter anchor bindings")

    var checkpoint_ids: Dictionary = {}
    for index: int in range(checkpoint_anchors.size()):
        var checkpoint := checkpoint_anchors[index] as Region3CheckpointAnchorDefinition
        if checkpoint == null:
            errors.append("checkpoint_anchors[%d] must be a Region3CheckpointAnchorDefinition" % index)
            continue
        for checkpoint_error: String in checkpoint.validate_definition(map_size_tiles, zone_ids):
            errors.append("%s: %s" % [String(checkpoint.checkpoint_id), checkpoint_error])
        var checkpoint_zone := get_zone(checkpoint.zone_id)
        if checkpoint_zone != null and not checkpoint_zone.tile_rect.has_point(checkpoint.tile):
            errors.append("%s: checkpoint tile must belong to its declared zone" % String(checkpoint.checkpoint_id))
        if checkpoint_ids.has(checkpoint.checkpoint_id):
            errors.append("duplicate checkpoint_id %s" % String(checkpoint.checkpoint_id))
        checkpoint_ids[checkpoint.checkpoint_id] = true

    return errors


func get_zone(zone_id: StringName) -> Region3WorldZoneDefinition:
    for raw_zone: Resource in zones:
        var zone := raw_zone as Region3WorldZoneDefinition
        if zone != null and zone.zone_id == zone_id:
            return zone
    return null


func get_quest_anchor(anchor_id: StringName) -> Region3QuestMarkerAnchorDefinition:
    for raw_anchor: Resource in quest_marker_anchors:
        var anchor := raw_anchor as Region3QuestMarkerAnchorDefinition
        if anchor != null and anchor.anchor_id == anchor_id:
            return anchor
    return null


func has_authored_checkpoint_geometry() -> bool:
    return not checkpoint_anchors.is_empty()


func has_authored_quest_marker_geometry() -> bool:
    if quest_marker_anchors.is_empty():
        return false
    for raw_anchor: Resource in quest_marker_anchors:
        var anchor := raw_anchor as Region3QuestMarkerAnchorDefinition
        if anchor == null or not anchor.exact_tile_authored:
            return false
    return true


func has_concrete_region_danger_data() -> bool:
    var hostile_zone_count := 0
    for raw_zone: Resource in zones:
        var zone := raw_zone as Region3WorldZoneDefinition
        if zone == null or zone.safe_zone or not zone.travel_destination:
            continue
        hostile_zone_count += 1
        if not zone.has_concrete_recommended_level():
            return false
    return hostile_zone_count > 0


func map_content_readiness() -> Dictionary:
    var quest_geometry_available := has_authored_quest_marker_geometry()
    var checkpoint_geometry_available := has_authored_checkpoint_geometry()
    var risk_data_available := has_concrete_region_danger_data()
    return {
        "explored_subzone_geometry_available": not zones.is_empty(),
        "explored_subzone_state_available": false,
        "explored_subzone_unavailable_reason_id": REASON_EXPLORED_SUBZONE_STATE_OWNER_UNAVAILABLE,
        "quest_marker_geometry_available": quest_geometry_available,
        "quest_marker_state_available": false,
        "quest_marker_unavailable_reason_id": (
            REASON_QUEST_MARKER_STATE_OWNER_UNAVAILABLE
            if quest_geometry_available
            else REASON_QUEST_MARKER_GEOMETRY_UNAUTHORED
        ),
        "checkpoint_marker_geometry_available": checkpoint_geometry_available,
        "checkpoint_marker_state_available": false,
        "checkpoint_marker_unavailable_reason_id": (
            REASON_CHECKPOINT_MARKER_STATE_OWNER_UNAVAILABLE
            if checkpoint_geometry_available
            else REASON_CHECKPOINT_GEOMETRY_UNAUTHORED
        ),
        "risk_marker_data_available": risk_data_available,
        "risk_marker_state_available": false,
        "risk_marker_unavailable_reason_id": (
            REASON_REGION_DANGER_STATE_OWNER_UNAVAILABLE
            if risk_data_available
            else REASON_REGION_DANGER_CONCRETE_LEVEL_UNAUTHORED
        ),
    }


static func _rects_overlap(first: Rect2i, second: Rect2i) -> bool:
    var first_end := first.position + first.size
    var second_end := second.position + second.size
    return (
        first.position.x < second_end.x
        and first_end.x > second.position.x
        and first.position.y < second_end.y
        and first_end.y > second.position.y
    )
