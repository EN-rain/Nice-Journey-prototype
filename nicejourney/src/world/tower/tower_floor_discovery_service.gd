class_name TowerFloorDiscoveryService
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_FLOOR_STATE_MISSING: StringName = &"floor_state_missing"
const REASON_FLOOR_STATE_INVALID: StringName = &"floor_state_invalid"
const REASON_ROOM_NOT_IN_MANIFEST: StringName = &"room_not_in_manifest"
const REASON_STATE_COMMIT_FAILED: StringName = &"state_commit_failed"
const REASON_ALREADY_DISCOVERED: StringName = &"already_discovered"

const RISK_COMBAT: StringName = &"risk:combat"
const RISK_ELITE: StringName = &"risk:elite"
const RISK_BOSS: StringName = &"risk:boss"


static func mark_room_discovered(profile: ProfileSnapshot, floor_id: int, room_instance_id: StringName) -> Dictionary:
    if profile == null or floor_id < 1 or floor_id > PrototypeTowerFloorCatalog.FLOOR_COUNT or not StableId.is_valid(String(room_instance_id)):
        return _result(false, REASON_INVALID_CONTEXT, false, floor_id, room_instance_id, [])
    var raw_floor: Variant = profile.tower_floor_states.get(str(floor_id), null)
    if not raw_floor is Dictionary:
        return _result(false, REASON_FLOOR_STATE_MISSING, false, floor_id, room_instance_id, [])

    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(raw_floor as Dictionary).is_empty() or floor_state.floor_id != floor_id:
        return _result(false, REASON_FLOOR_STATE_INVALID, false, floor_id, room_instance_id, [])
    if not _manifest_has_room(floor_state.layout_manifest, room_instance_id):
        return _result(false, REASON_ROOM_NOT_IN_MANIFEST, false, floor_id, room_instance_id, floor_state.discovered_room_ids)
    if floor_state.discovered_room_ids.has(room_instance_id):
        return _result(true, REASON_ALREADY_DISCOVERED, false, floor_id, room_instance_id, floor_state.discovered_room_ids)
    if not floor_state.mark_room_discovered(room_instance_id):
        return _result(false, REASON_FLOOR_STATE_INVALID, false, floor_id, room_instance_id, floor_state.discovered_room_ids)
    if not TowerFloorStateService.commit_floor_state(profile, floor_state):
        return _result(false, REASON_STATE_COMMIT_FAILED, false, floor_id, room_instance_id, [])
    return _result(true, &"", true, floor_id, room_instance_id, floor_state.discovered_room_ids)


static func visible_room_summaries(floor_state: FloorInstanceState) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if floor_state == null or floor_state.discovered_room_ids.is_empty():
        return result
    var rooms_variant: Variant = floor_state.layout_manifest.get("rooms", null)
    if not rooms_variant is Array:
        return result

    var discovered: Dictionary = {}
    for room_id: StringName in floor_state.discovered_room_ids:
        discovered[room_id] = true
    for raw_room: Variant in rooms_variant as Array:
        if not raw_room is Dictionary:
            continue
        var room := raw_room as Dictionary
        var room_id := StringName(String(room.get("room_instance_id", &"")))
        if not discovered.has(room_id):
            continue
        var rect_variant: Variant = room.get("rect", null)
        if not rect_variant is Rect2i:
            continue
        result.append({
            "room_instance_id": room_id,
            "rect": rect_variant as Rect2i,
        })
    result.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        return String(first.get("room_instance_id", &"")) < String(second.get("room_instance_id", &""))
    )
    return result


static func visible_room_risk_markers(floor_state: FloorInstanceState) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if floor_state == null or floor_state.discovered_room_ids.is_empty():
        return result
    var rooms_variant: Variant = floor_state.layout_manifest.get("rooms", null)
    if not rooms_variant is Array:
        return result

    var discovered: Dictionary = {}
    for room_id: StringName in floor_state.discovered_room_ids:
        discovered[room_id] = true
    for raw_room: Variant in rooms_variant as Array:
        if not raw_room is Dictionary:
            continue
        var room := raw_room as Dictionary
        var room_id := StringName(String(room.get("room_instance_id", &"")))
        if not discovered.has(room_id):
            continue
        var tags_variant: Variant = room.get("tags", null)
        if not tags_variant is Array:
            continue
        var tags := tags_variant as Array
        var risk_id: StringName = &""
        if tags.has(TowerFloorLayoutManifestValidator.TAG_BOSS):
            risk_id = RISK_BOSS
        elif tags.has(TowerFloorLayoutManifestValidator.TAG_ELITE):
            risk_id = RISK_ELITE
        elif tags.has(TowerFloorLayoutManifestValidator.TAG_COMBAT):
            risk_id = RISK_COMBAT
        if risk_id == &"":
            continue
        result.append({
            "room_instance_id": room_id,
            "risk_id": risk_id,
        })
    result.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        return String(first.get("room_instance_id", &"")) < String(second.get("room_instance_id", &""))
    )
    return result


static func visible_room_connections(floor_state: FloorInstanceState) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if floor_state == null or floor_state.discovered_room_ids.size() < 2:
        return result
    var edges_variant: Variant = floor_state.layout_manifest.get("edges", null)
    if not edges_variant is Array:
        return result

    var discovered: Dictionary = {}
    for room_id: StringName in floor_state.discovered_room_ids:
        discovered[room_id] = true
    var seen: Dictionary = {}
    for raw_edge: Variant in edges_variant as Array:
        if not raw_edge is Dictionary:
            continue
        var edge := raw_edge as Dictionary
        var from_id := StringName(String(edge.get("from_room_id", &"")))
        var to_id := StringName(String(edge.get("to_room_id", &"")))
        if not discovered.has(from_id) or not discovered.has(to_id) or from_id == to_id:
            continue
        var pair: Array[String] = [String(from_id), String(to_id)]
        pair.sort()
        var key := "%s|%s" % pair
        if seen.has(key):
            continue
        seen[key] = true
        result.append({
            "from_room_id": StringName(pair[0]),
            "to_room_id": StringName(pair[1]),
        })
    result.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
        var first_key := "%s|%s" % [String(first.get("from_room_id", &"")), String(first.get("to_room_id", &""))]
        var second_key := "%s|%s" % [String(second.get("from_room_id", &"")), String(second.get("to_room_id", &""))]
        return first_key < second_key
    )
    return result


static func _manifest_has_room(manifest: Dictionary, room_instance_id: StringName) -> bool:
    var rooms_variant: Variant = manifest.get("rooms", null)
    if not rooms_variant is Array:
        return false
    for raw_room: Variant in rooms_variant as Array:
        if not raw_room is Dictionary:
            continue
        if StringName(String((raw_room as Dictionary).get("room_instance_id", &""))) == room_instance_id:
            return true
    return false


static func _result(
    accepted: bool,
    reason_id: StringName,
    changed: bool,
    floor_id: int,
    room_instance_id: StringName,
    discovered_room_ids: Array[StringName]
) -> Dictionary:
    var room_ids: Array[String] = []
    for room_id: StringName in discovered_room_ids:
        room_ids.append(String(room_id))
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "changed": changed,
        "floor_id": floor_id,
        "room_instance_id": room_instance_id,
        "discovered_room_ids": room_ids,
    }
