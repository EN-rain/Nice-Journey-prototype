class_name TowerArrivalResolver
extends RefCounted

const REASON_INVALID_FLOOR_STATE: StringName = &"invalid_floor_state"
const REASON_LAYOUT_MISSING: StringName = &"layout_missing"
const REASON_LAYOUT_INVALID: StringName = &"layout_invalid"
const REASON_ENTRANCE_MISSING: StringName = &"entrance_missing"
const REASON_MODULE_INVALID: StringName = &"module_invalid"
const REASON_NO_SAFE_ARRIVAL: StringName = &"no_safe_arrival"
const REASON_SAFE_STATE_INVALID: StringName = &"safe_state_invalid"
const REASON_CHECKPOINT_UNRESOLVED: StringName = &"checkpoint_unresolved"

static func resolve_saved_safe_state(floor_state: FloorInstanceState, safe_state: Dictionary) -> Dictionary:
    if floor_state == null or not SafeCheckpointState.validate_dictionary(safe_state).is_empty():
        return _rejected(REASON_SAFE_STATE_INVALID)
    if int(safe_state.get("floor_id", -1)) != floor_state.floor_id:
        return _rejected(REASON_SAFE_STATE_INVALID)
    var entrance := resolve_entrance(floor_state)
    if not bool(entrance.get("accepted", false)):
        return entrance
    var requested_anchor := StringName(String(safe_state.get("checkpoint_anchor_id", &"")))
    if requested_anchor == StringName(String(entrance.get("arrival_anchor_id", &""))):
        entrance["requested_checkpoint_anchor_id"] = requested_anchor
        entrance["fallback_to_entrance"] = false
        entrance["fallback_reason_id"] = &""
        return entrance
    var checkpoint := resolve_checkpoint(floor_state, requested_anchor)
    if bool(checkpoint.get("accepted", false)):
        checkpoint["requested_checkpoint_anchor_id"] = requested_anchor
        checkpoint["fallback_to_entrance"] = false
        checkpoint["fallback_reason_id"] = &""
        return checkpoint
    entrance["requested_checkpoint_anchor_id"] = requested_anchor
    entrance["fallback_to_entrance"] = true
    entrance["fallback_reason_id"] = StringName(checkpoint.get("reason_id", REASON_CHECKPOINT_UNRESOLVED))
    return entrance

static func resolve_checkpoint(floor_state: FloorInstanceState, checkpoint_id: StringName) -> Dictionary:
    if floor_state == null or not StableId.is_valid(String(checkpoint_id)):
        return _rejected(REASON_CHECKPOINT_UNRESOLVED)
    if not FloorInstanceState.validate_dictionary(floor_state.to_dictionary()).is_empty() or floor_state.layout_manifest.is_empty():
        return _rejected(REASON_INVALID_FLOOR_STATE)
    var anchor := floor_state.get_checkpoint_anchor(checkpoint_id)
    if anchor.is_empty():
        return _rejected(REASON_CHECKPOINT_UNRESOLVED)
    var room_id := StringName(String(anchor.get("room_instance_id", &"")))
    var room: Dictionary = {}
    for raw_room: Variant in floor_state.layout_manifest.get("rooms", []) as Array:
        if raw_room is Dictionary and StringName(String((raw_room as Dictionary).get("room_instance_id", &""))) == room_id:
            room = (raw_room as Dictionary).duplicate(true)
            break
    if room.is_empty() or not room.get("rect", null) is Rect2i:
        return _rejected(REASON_CHECKPOINT_UNRESOLVED)
    var module_id := StringName(String(room.get("module_id", &"")))
    var definition := TowerPrototypeModuleCatalog.get_definition(module_id)
    if definition == null or not definition.validate_definition().is_empty():
        return _rejected(REASON_MODULE_INVALID)
    var local_tile := Vector2i(int(anchor.get("local_tile_x", -1)), int(anchor.get("local_tile_y", -1)))
    if not _candidate_safe(definition, local_tile):
        return _rejected(REASON_NO_SAFE_ARRIVAL)
    var world_tile := (room["rect"] as Rect2i).position + local_tile
    if world_tile.x < 0 or world_tile.y < 0 or world_tile.x >= TowerFloorLayoutManifestValidator.MAX_FOOTPRINT_TILES or world_tile.y >= TowerFloorLayoutManifestValidator.MAX_FOOTPRINT_TILES:
        return _rejected(REASON_NO_SAFE_ARRIVAL)
    return {
        "accepted": true,
        "reason_id": &"",
        "arrival_kind": &"checkpoint",
        "arrival_anchor_id": checkpoint_id,
        "room_instance_id": room_id,
        "module_id": module_id,
        "local_tile": local_tile,
        "world_tile": world_tile,
        "requested_checkpoint_anchor_id": checkpoint_id,
        "fallback_to_entrance": false,
        "fallback_reason_id": &"",
    }

static func resolve_entrance(floor_state: FloorInstanceState) -> Dictionary:
    if floor_state == null:
        return _rejected(REASON_INVALID_FLOOR_STATE)
    var floor_data := floor_state.to_dictionary()
    if not FloorInstanceState.validate_dictionary(floor_data).is_empty():
        return _rejected(REASON_INVALID_FLOOR_STATE)
    if floor_state.layout_manifest.is_empty():
        return _rejected(REASON_LAYOUT_MISSING)
    var manifest := floor_state.layout_manifest.duplicate(true)
    var request := _request_from_manifest(manifest)
    if request.is_empty() or not TowerFloorGenerationCommitService.validate_request(request).is_empty():
        return _rejected(REASON_LAYOUT_INVALID)
    if not TowerFloorLayoutManifestValidator.validate_manifest(manifest, request).is_empty():
        return _rejected(REASON_LAYOUT_INVALID)
    if not TowerFloorTraversalManifestValidator.validate_manifest(manifest).is_empty():
        return _rejected(REASON_LAYOUT_INVALID)

    var entrance_id := StringName(String(manifest.get("entrance_room_id", &"")))
    var entrance_room: Dictionary = {}
    for raw_room: Variant in manifest.get("rooms", []) as Array:
        if raw_room is Dictionary and StringName(String((raw_room as Dictionary).get("room_instance_id", &""))) == entrance_id:
            entrance_room = (raw_room as Dictionary).duplicate(true)
            break
    if entrance_room.is_empty():
        return _rejected(REASON_ENTRANCE_MISSING)

    var module_id := StringName(String(entrance_room.get("module_id", &"")))
    var definition := TowerPrototypeModuleCatalog.get_definition(module_id)
    if definition == null or not definition.validate_definition().is_empty():
        return _rejected(REASON_MODULE_INVALID)
    var room_rect := entrance_room.get("rect", Rect2i()) as Rect2i
    for local_tile: Vector2i in definition.arrival_candidates:
        if not _candidate_safe(definition, local_tile):
            continue
        var world_tile := room_rect.position + local_tile
        if world_tile.x < 0 or world_tile.y < 0 or world_tile.x >= TowerFloorLayoutManifestValidator.MAX_FOOTPRINT_TILES or world_tile.y >= TowerFloorLayoutManifestValidator.MAX_FOOTPRINT_TILES:
            continue
        return {
            "accepted": true,
            "reason_id": &"",
            "arrival_kind": &"entrance",
            "arrival_anchor_id": StringName("arrival:%s:entrance" % String(floor_state.instance_id)),
            "room_instance_id": entrance_id,
            "module_id": module_id,
            "local_tile": local_tile,
            "world_tile": world_tile,
        }
    return _rejected(REASON_NO_SAFE_ARRIVAL)

static func _request_from_manifest(manifest: Dictionary) -> Dictionary:
    if not manifest.get("reserved_quest_ids", null) is Array:
        return {}
    return {
        "floor_id": manifest.get("floor_id", null),
        "generation_seed": manifest.get("generation_seed", null),
        "generator_version": manifest.get("generator_version", null),
        "module_content_version": manifest.get("module_content_version", null),
        "encounter_config_id": manifest.get("encounter_config_id", null),
        "quest_world_flags_signature": manifest.get("quest_world_flags_signature", null),
        "required_quest_ids": (manifest["reserved_quest_ids"] as Array).duplicate(true),
    }

static func _candidate_safe(definition: TowerRoomModuleDefinition, local_tile: Vector2i) -> bool:
    var walkable := false
    for rect: Rect2i in definition.walkable_rects:
        if rect.has_point(local_tile):
            walkable = true
            break
    if not walkable:
        return false
    for rect: Rect2i in definition.collision_rects:
        if rect.has_point(local_tile):
            return false
    return true

static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "arrival_kind": &"",
        "arrival_anchor_id": &"",
        "room_instance_id": &"",
        "module_id": &"",
        "local_tile": Vector2i.ZERO,
        "world_tile": Vector2i.ZERO,
        "requested_checkpoint_anchor_id": &"",
        "fallback_to_entrance": false,
        "fallback_reason_id": &"",
    }
