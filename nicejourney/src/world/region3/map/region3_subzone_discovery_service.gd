class_name Region3SubzoneDiscoveryService
extends RefCounted

const PLAYER_DROP_STATE_VALIDATOR: Script = preload("res://src/items/player_drop_state_validator.gd")
const REGION_ID: int = 3
const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_STATE_INVALID: StringName = &"region_discovery_state_invalid"
const REASON_MAP_REVISION_MISMATCH: StringName = &"region_map_revision_mismatch"
const REASON_POSITION_INVALID: StringName = &"region_discovery_position_invalid"
const REASON_STATE_UNINITIALIZED: StringName = &"region_discovery_state_uninitialized"

static func ensure_initialized(profile: ProfileSnapshot, layout: Region3AuthoredTownLayout) -> Dictionary:
    if profile == null or layout == null or layout.world_layout_definition == null:
        return _rejected(REASON_INVALID_CONTEXT)
    if not layout.validate_layout().is_empty():
        return _rejected(REASON_INVALID_CONTEXT)

    if profile.region_state.is_empty():
        profile.region_state = {
            "region_id": REGION_ID,
            "map_revision_id": String(layout.map_revision_id),
            "explored_zone_ids": [],
            "loose_items": {},
        }
        return {
            "accepted": true,
            "reason_id": &"",
            "initialized": true,
            "changed": true,
        }

    var errors := validate_state_dictionary(profile.region_state)
    if not errors.is_empty():
        var rejected := _rejected(REASON_STATE_INVALID)
        rejected["errors"] = errors.duplicate()
        return rejected
    if int(profile.region_state.get("region_id", 0)) != REGION_ID:
        return _rejected(REASON_STATE_INVALID)
    if StringName(String(profile.region_state.get("map_revision_id", &""))) != layout.map_revision_id:
        return _rejected(REASON_MAP_REVISION_MISMATCH)
    var position_errors := validate_loose_positions_for_layout(profile.region_state, layout)
    if not position_errors.is_empty():
        var rejected := _rejected(REASON_STATE_INVALID)
        rejected["errors"] = position_errors.duplicate()
        return rejected
    return {
        "accepted": true,
        "reason_id": &"",
        "initialized": false,
        "changed": false,
    }


static func mark_local_position_explored(
    profile: ProfileSnapshot,
    layout: Region3AuthoredTownLayout,
    local_position_px: Vector2
) -> Dictionary:
    var resolved := zone_id_at_local_position(layout, local_position_px)
    if not bool(resolved.get("accepted", false)):
        return resolved
    var initialized := ensure_initialized(profile, layout)
    if not bool(initialized.get("accepted", false)):
        return initialized
    var zone_id := StringName(String(resolved.get("zone_id", &"")))
    if zone_id == &"":
        return {
            "accepted": true,
            "reason_id": &"",
            "changed": bool(initialized.get("changed", false)),
            "zone_id": &"",
            "tile": resolved.get("tile", Vector2i(-1, -1)),
        }
    var marked := mark_zone_explored(profile, layout, zone_id)
    marked["tile"] = resolved.get("tile", Vector2i(-1, -1))
    return marked


static func zone_id_at_local_position(
    layout: Region3AuthoredTownLayout,
    local_position_px: Vector2
) -> Dictionary:
    if layout == null or layout.world_layout_definition == null or layout.tile_size <= 0:
        return _rejected(REASON_INVALID_CONTEXT)
    if not is_finite(local_position_px.x) or not is_finite(local_position_px.y):
        return _rejected(REASON_POSITION_INVALID)
    var tile := Vector2i(
        floori(local_position_px.x / float(layout.tile_size)),
        floori(local_position_px.y / float(layout.tile_size))
    )
    if tile.x < 0 or tile.y < 0 or tile.x >= layout.map_size_tiles.x or tile.y >= layout.map_size_tiles.y:
        return _rejected(REASON_POSITION_INVALID)
    var zone := _zone_at_tile(layout.world_layout_definition, tile)
    return {
        "accepted": true,
        "reason_id": &"",
        "zone_id": zone.zone_id if zone != null else &"",
        "tile": tile,
    }


static func mark_zone_explored(
    profile: ProfileSnapshot,
    layout: Region3AuthoredTownLayout,
    zone_id: StringName
) -> Dictionary:
    var initialized := ensure_initialized(profile, layout)
    if not bool(initialized.get("accepted", false)):
        return initialized
    var zone := layout.world_layout_definition.get_zone(zone_id)
    if zone == null:
        return _rejected(REASON_INVALID_CONTEXT)

    var explored := _normalized_explored_ids(profile.region_state.get("explored_zone_ids", []))
    if explored.has(zone_id):
        return {
            "accepted": true,
            "reason_id": &"",
            "changed": bool(initialized.get("changed", false)),
            "zone_id": zone_id,
        }

    explored.append(zone_id)
    explored.sort()
    var serialized: Array[String] = []
    for explored_id: StringName in explored:
        serialized.append(String(explored_id))
    profile.region_state["explored_zone_ids"] = serialized
    return {
        "accepted": true,
        "reason_id": &"",
        "changed": true,
        "zone_id": zone_id,
    }


static func explored_zone_entries(
    profile: ProfileSnapshot,
    layout: Region3AuthoredTownLayout
) -> Dictionary:
    if profile == null or layout == null or layout.world_layout_definition == null:
        return {"accepted": false, "reason_id": REASON_INVALID_CONTEXT, "entries": [], "errors": PackedStringArray()}
    if profile.region_state.is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_UNINITIALIZED, "entries": [], "errors": PackedStringArray()}
    var errors := validate_state_dictionary(profile.region_state)
    if not errors.is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_INVALID, "entries": [], "errors": errors.duplicate()}
    if StringName(String(profile.region_state.get("map_revision_id", &""))) != layout.map_revision_id:
        return {"accepted": false, "reason_id": REASON_MAP_REVISION_MISMATCH, "entries": [], "errors": PackedStringArray()}
    var position_errors := validate_loose_positions_for_layout(profile.region_state, layout)
    if not position_errors.is_empty():
        return {"accepted": false, "reason_id": REASON_STATE_INVALID, "entries": [], "errors": position_errors.duplicate()}

    var explored := _normalized_explored_ids(profile.region_state.get("explored_zone_ids", []))
    var entries: Array[Dictionary] = []
    for raw_zone: Resource in layout.world_layout_definition.zones:
        var zone := raw_zone as Region3WorldZoneDefinition
        if zone == null or not explored.has(zone.zone_id):
            continue
        entries.append({
            "zone_id": zone.zone_id,
            "tile_rect": zone.tile_rect,
        })
    return {
        "accepted": true,
        "reason_id": &"",
        "entries": entries,
        "errors": PackedStringArray(),
    }


static func validate_state_dictionary(raw_state: Variant) -> PackedStringArray:
    var errors := PackedStringArray()
    if not raw_state is Dictionary:
        errors.append("region_state must be a dictionary")
        return errors
    var state := raw_state as Dictionary
    if state.is_empty():
        return errors
    if int(state.get("region_id", 0)) != REGION_ID:
        errors.append("region_id must be 3")
    if not StableId.is_valid(String(state.get("map_revision_id", ""))):
        errors.append("map_revision_id must be a stable ID")
    var raw_ids: Variant = state.get("explored_zone_ids", null)
    if not raw_ids is Array:
        errors.append("explored_zone_ids must be an array")
        return errors
    var seen: Dictionary = {}
    for raw_id: Variant in raw_ids as Array:
        var zone_id := StringName(String(raw_id))
        if not Region3WorldLayoutDefinition.REQUIRED_ZONE_IDS.has(zone_id):
            errors.append("explored_zone_ids contains unknown Region 3 zone: %s" % String(zone_id))
            continue
        if seen.has(zone_id):
            errors.append("explored_zone_ids contains duplicate zone: %s" % String(zone_id))
            continue
        seen[zone_id] = true

    var raw_loose_items: Variant = state.get("loose_items", {})
    if not raw_loose_items is Dictionary:
        errors.append("loose_items must be a dictionary")
        return errors
    for raw_source_id: Variant in (raw_loose_items as Dictionary).keys():
        var raw_entry: Variant = (raw_loose_items as Dictionary)[raw_source_id]
        if not bool(PLAYER_DROP_STATE_VALIDATOR.should_validate_entry(raw_source_id, raw_entry)):
            errors.append("loose_items currently supports only validated player_drop records: %s" % String(raw_source_id))
            continue
        var source_id := StringName(String(raw_source_id))
        var drop_errors := PLAYER_DROP_STATE_VALIDATOR.validate_entry(raw_entry, source_id) as PackedStringArray
        for drop_error: String in drop_errors:
            errors.append("loose_items[%s]: %s" % [String(raw_source_id), drop_error])
    return errors


static func validate_loose_positions_for_layout(
    raw_state: Variant,
    layout: Region3AuthoredTownLayout
) -> PackedStringArray:
    var errors := PackedStringArray()
    if layout == null or layout.world_layout_definition == null or layout.tile_size <= 0:
        errors.append("Region 3 authored layout is required for loose-item position validation")
        return errors
    if not raw_state is Dictionary:
        errors.append("region_state must be a dictionary")
        return errors
    var raw_loose_items: Variant = (raw_state as Dictionary).get("loose_items", {})
    if not raw_loose_items is Dictionary:
        errors.append("loose_items must be a dictionary")
        return errors
    for raw_source_id: Variant in (raw_loose_items as Dictionary).keys():
        var raw_entry: Variant = (raw_loose_items as Dictionary)[raw_source_id]
        if not raw_entry is Dictionary:
            continue
        var raw_position: Variant = (raw_entry as Dictionary).get("world_position", null)
        if not raw_position is Dictionary:
            continue
        var position := raw_position as Dictionary
        var x: Variant = position.get("x", null)
        var y: Variant = position.get("y", null)
        if not _finite_number(x) or not _finite_number(y):
            continue # Structural validation reports malformed coordinates first.
        var resolved := zone_id_at_local_position(layout, Vector2(float(x), float(y)))
        if not bool(resolved.get("accepted", false)):
            errors.append("loose_items[%s] position is outside the authored Region 3 map" % String(raw_source_id))
    return errors


static func _finite_number(value: Variant) -> bool:
    return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func _zone_at_tile(
    world_layout: Region3WorldLayoutDefinition,
    tile: Vector2i
) -> Region3WorldZoneDefinition:
    if world_layout == null:
        return null
    for raw_zone: Resource in world_layout.zones:
        var zone := raw_zone as Region3WorldZoneDefinition
        if zone != null and zone.tile_rect.has_point(tile):
            return zone
    return null


static func _normalized_explored_ids(raw_ids: Variant) -> Array[StringName]:
    var result: Array[StringName] = []
    if not raw_ids is Array:
        return result
    for raw_id: Variant in raw_ids as Array:
        var zone_id := StringName(String(raw_id))
        if Region3WorldLayoutDefinition.REQUIRED_ZONE_IDS.has(zone_id) and not result.has(zone_id):
            result.append(zone_id)
    result.sort()
    return result


static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "initialized": false,
        "changed": false,
        "zone_id": &"",
        "errors": PackedStringArray(),
    }
