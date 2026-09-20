class_name TowerFloorGenerationCommitService
extends RefCounted

const MAX_DETERMINISTIC_CANDIDATES: int = 8

const REASON_INVALID_REQUEST: StringName = &"invalid_request"
const REASON_INVALID_CANDIDATE_LIST: StringName = &"invalid_candidate_list"
const REASON_NO_COMPATIBLE_LAYOUT: StringName = &"no_compatible_layout"
const REASON_ACCEPTED_CANDIDATE: StringName = &"accepted_candidate"
const REASON_ACCEPTED_FALLBACK: StringName = &"accepted_fallback"


static func expected_quest_ids_for_floor(floor_id: int) -> Array[StringName]:
    var result: Array[StringName] = []
    if floor_id < 1 or floor_id > 10:
        return result
    result.append(QuestCatalog.FLOOR_PRIMARY_IDS[floor_id - 1])
    for definition: QuestDefinition in QuestCatalog.all_definitions():
        if definition.kind == QuestDefinition.KIND_SIDE and definition.floor_id == floor_id:
            result.append(definition.quest_id)
    result.sort()
    return result


static func build_request(
    floor_id: int,
    generation_seed: int,
    generator_version: StringName,
    module_content_version: StringName,
    encounter_config_id: StringName,
    quest_world_flags_signature: StringName
) -> Dictionary:
    return {
        "floor_id": floor_id,
        "generation_seed": generation_seed,
        "generator_version": generator_version,
        "module_content_version": module_content_version,
        "encounter_config_id": encounter_config_id,
        "quest_world_flags_signature": quest_world_flags_signature,
        "required_quest_ids": expected_quest_ids_for_floor(floor_id),
    }


static func validate_request(raw_request: Variant) -> PackedStringArray:
    var errors := PackedStringArray()
    if not raw_request is Dictionary:
        errors.append("generation request must be a dictionary")
        return errors
    var request: Dictionary = raw_request as Dictionary
    if typeof(request.get("floor_id", null)) != TYPE_INT or int(request.get("floor_id", 0)) < 1 or int(request.get("floor_id", 0)) > 10:
        errors.append("floor_id must be an integer from 1 through 10")
    if typeof(request.get("generation_seed", null)) != TYPE_INT or int(request.get("generation_seed", -1)) < 0:
        errors.append("generation_seed must be a nonnegative integer")
    for key: String in ["generator_version", "module_content_version", "encounter_config_id", "quest_world_flags_signature"]:
        var value: Variant = request.get(key, null)
        if not (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME) or not StableId.is_valid(String(value)):
            errors.append("%s must be a stable ID" % key)
    if not request.get("required_quest_ids", null) is Array:
        errors.append("required_quest_ids must be an array")
        return errors
    if errors.is_empty():
        var expected: Array[StringName] = expected_quest_ids_for_floor(int(request["floor_id"]))
        var supplied: Array[StringName] = _normalized_ids(request["required_quest_ids"] as Array, errors)
        if supplied != expected:
            errors.append("required_quest_ids must exactly match the approved primary plus reserved tower-side quest sockets")
    return errors


static func choose_valid_manifest(raw_request: Variant, raw_candidates: Variant, raw_fallback: Variant) -> Dictionary:
    var request_errors: PackedStringArray = validate_request(raw_request)
    if not request_errors.is_empty():
        return _rejected(REASON_INVALID_REQUEST, request_errors, [])
    if not raw_candidates is Array:
        return _rejected(REASON_INVALID_CANDIDATE_LIST, PackedStringArray(["candidates must be an array"]), [])
    var candidates: Array = raw_candidates as Array
    if candidates.size() > MAX_DETERMINISTIC_CANDIDATES:
        return _rejected(
            REASON_INVALID_CANDIDATE_LIST,
            PackedStringArray(["candidate count exceeds the configured eight-candidate generation hypothesis"]),
            []
        )

    var request: Dictionary = (raw_request as Dictionary).duplicate(true)
    var candidate_failures: Array[Dictionary] = []
    for index: int in range(candidates.size()):
        var errors: PackedStringArray = TowerFloorLayoutManifestValidator.validate_manifest(candidates[index], request)
        if errors.is_empty():
            return {
                "accepted": true,
                "reason_id": REASON_ACCEPTED_CANDIDATE,
                "candidate_index": index,
                "used_fallback": false,
                "manifest": (candidates[index] as Dictionary).duplicate(true),
                "candidate_failures": candidate_failures.duplicate(true),
            }
        candidate_failures.append({
            "candidate_index": index,
            "errors": Array(errors),
        })

    var fallback_errors: PackedStringArray = TowerFloorLayoutManifestValidator.validate_manifest(raw_fallback, request)
    if fallback_errors.is_empty():
        return {
            "accepted": true,
            "reason_id": REASON_ACCEPTED_FALLBACK,
            "candidate_index": -1,
            "used_fallback": true,
            "manifest": (raw_fallback as Dictionary).duplicate(true),
            "candidate_failures": candidate_failures.duplicate(true),
        }

    return _rejected(REASON_NO_COMPATIBLE_LAYOUT, fallback_errors, candidate_failures)


static func floor_state_from_manifest(instance_id: StringName, raw_manifest: Variant) -> FloorInstanceState:
    if not StableId.is_valid(String(instance_id)) or not raw_manifest is Dictionary:
        return null
    var manifest: Dictionary = raw_manifest as Dictionary
    var request := {
        "floor_id": manifest.get("floor_id", null),
        "generation_seed": manifest.get("generation_seed", null),
        "generator_version": manifest.get("generator_version", null),
        "module_content_version": manifest.get("module_content_version", null),
        "encounter_config_id": manifest.get("encounter_config_id", null),
        "quest_world_flags_signature": manifest.get("quest_world_flags_signature", null),
        "required_quest_ids": (manifest.get("reserved_quest_ids", []) as Array).duplicate() if manifest.get("reserved_quest_ids", null) is Array else [],
    }
    if not validate_request(request).is_empty():
        return null
    if not TowerFloorLayoutManifestValidator.validate_manifest(manifest, request).is_empty():
        return null
    if not _manifest_identity_fields_valid(manifest):
        return null
    var state := FloorInstanceState.new()
    state.floor_id = int(manifest["floor_id"])
    state.instance_id = instance_id
    state.seed = int(manifest["generation_seed"])
    state.layout_revision_id = StringName(String(manifest["layout_revision_id"]))
    state.layout_manifest = manifest.duplicate(true)
    state.quest_state = {
        "reserved_quest_ids": (manifest["reserved_quest_ids"] as Array).duplicate(true),
        "objective_bindings": (manifest["objective_bindings"] as Dictionary).duplicate(true),
    }
    if state.floor_id == 10 and not _register_floor10_preboss_checkpoint(state, manifest):
        return null
    return state


static func _register_floor10_preboss_checkpoint(state: FloorInstanceState, manifest: Dictionary) -> bool:
    var rooms_by_id: Dictionary = {}
    var boss_ids: Array[StringName] = []
    for raw_room: Variant in manifest.get("rooms", []) as Array:
        if not raw_room is Dictionary:
            continue
        var room := raw_room as Dictionary
        var room_id := StringName(String(room.get("room_instance_id", &"")))
        rooms_by_id[room_id] = room
        var tags: Array = room.get("tags", []) as Array
        if tags.has(TowerFloorLayoutManifestValidator.TAG_BOSS):
            boss_ids.append(room_id)
    if boss_ids.size() != 1:
        return false
    var boss_id := boss_ids[0]
    var safe_neighbors: Array[StringName] = []
    for raw_edge: Variant in manifest.get("edges", []) as Array:
        if not raw_edge is Dictionary:
            continue
        var edge := raw_edge as Dictionary
        var from_id := StringName(String(edge.get("from_room_id", &"")))
        var to_id := StringName(String(edge.get("to_room_id", &"")))
        var neighbor := &"" as StringName
        if from_id == boss_id:
            neighbor = to_id
        elif to_id == boss_id:
            neighbor = from_id
        if neighbor == &"" or not rooms_by_id.has(neighbor):
            continue
        var candidate := rooms_by_id[neighbor] as Dictionary
        if (candidate.get("tags", []) as Array).has(TowerFloorLayoutManifestValidator.TAG_SAFE):
            safe_neighbors.append(neighbor)
    safe_neighbors.sort()
    if safe_neighbors.is_empty():
        return false
    var room_id := safe_neighbors[0]
    var room := rooms_by_id[room_id] as Dictionary
    var definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(room.get("module_id", &""))))
    if definition == null or definition.arrival_candidates.is_empty():
        return false
    for local_tile: Vector2i in definition.arrival_candidates:
        var safe := false
        for walkable: Rect2i in definition.walkable_rects:
            if walkable.has_point(local_tile):
                safe = true
                break
        if not safe:
            continue
        var blocked := false
        for collision: Rect2i in definition.collision_rects:
            if collision.has_point(local_tile):
                blocked = true
                break
        if not blocked:
            return state.add_checkpoint_anchor(&"checkpoint:floor10_preboss", room_id, local_tile)
    return false

static func floor_state_identity_from_manifest(raw_manifest: Variant) -> Dictionary:
    if not raw_manifest is Dictionary:
        return {}
    var manifest: Dictionary = raw_manifest as Dictionary
    if not _manifest_identity_fields_valid(manifest):
        return {}
    return {
        "floor_id": int(manifest["floor_id"]),
        "seed": int(manifest["generation_seed"]),
        "layout_revision_id": StringName(String(manifest["layout_revision_id"])),
    }


static func _manifest_identity_fields_valid(manifest: Dictionary) -> bool:
    return (
        typeof(manifest.get("floor_id", null)) == TYPE_INT
        and int(manifest["floor_id"]) >= 1
        and int(manifest["floor_id"]) <= 10
        and typeof(manifest.get("generation_seed", null)) == TYPE_INT
        and int(manifest["generation_seed"]) >= 0
        and (typeof(manifest.get("layout_revision_id", null)) == TYPE_STRING or typeof(manifest.get("layout_revision_id", null)) == TYPE_STRING_NAME)
        and StableId.is_valid(String(manifest.get("layout_revision_id", "")))
    )


static func _normalized_ids(values: Array, errors: PackedStringArray) -> Array[StringName]:
    var result: Array[StringName] = []
    var seen: Dictionary = {}
    for value: Variant in values:
        if not (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME) or not StableId.is_valid(String(value)):
            errors.append("required_quest_ids contains an invalid stable ID")
            continue
        var id := StringName(String(value))
        if seen.has(id):
            errors.append("required_quest_ids contains duplicate ID: %s" % String(id))
            continue
        seen[id] = true
        result.append(id)
    result.sort()
    return result


static func _rejected(reason_id: StringName, errors: PackedStringArray, candidate_failures: Array) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "candidate_index": -1,
        "used_fallback": false,
        "manifest": {},
        "errors": Array(errors),
        "candidate_failures": candidate_failures.duplicate(true),
    }
