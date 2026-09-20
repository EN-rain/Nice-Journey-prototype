class_name FloorInstanceState
extends RefCounted

const PLAYER_DROP_STATE_VALIDATOR: Script = preload("res://src/items/player_drop_state_validator.gd")

var floor_id: int = 0
var instance_id: StringName = &""
var seed: int = 0
var layout_revision_id: StringName = &""
var layout_manifest: Dictionary = {}
var discovered_room_ids: Array[StringName] = []
var defeated_actor_ids: Array[StringName] = []
var claimed_source_ids: Array[StringName] = []
var loose_items: Dictionary = {}
var vendor_state: Dictionary = {}
var quest_state: Dictionary = {}
var checkpoint_ids: Array[StringName] = []
var checkpoint_anchors: Dictionary = {}
var boss_defeated: bool = false
var primary_cleared: bool = false


func mark_room_discovered(room_instance_id: StringName) -> bool:
    if not StableId.is_valid(String(room_instance_id)) or discovered_room_ids.has(room_instance_id):
        return false
    discovered_room_ids.append(room_instance_id)
    discovered_room_ids.sort()
    return true


func mark_actor_defeated(actor_id: StringName, is_boss: bool = false) -> bool:
    if not StableId.is_valid(String(actor_id)) or defeated_actor_ids.has(actor_id):
        return false
    defeated_actor_ids.append(actor_id)
    defeated_actor_ids.sort()
    if is_boss:
        boss_defeated = true
    return true


func claim_source(source_id: StringName) -> bool:
    if not StableId.is_valid(String(source_id)) or claimed_source_ids.has(source_id):
        return false
    claimed_source_ids.append(source_id)
    claimed_source_ids.sort()
    return true


func add_checkpoint(checkpoint_id: StringName) -> bool:
    if not StableId.is_valid(String(checkpoint_id)) or checkpoint_ids.has(checkpoint_id):
        return false
    checkpoint_ids.append(checkpoint_id)
    checkpoint_ids.sort()
    return true

func add_checkpoint_anchor(checkpoint_id: StringName, room_instance_id: StringName, local_tile: Vector2i) -> bool:
    if not StableId.is_valid(String(checkpoint_id)) or not StableId.is_valid(String(room_instance_id)):
        return false
    if checkpoint_ids.has(checkpoint_id) or checkpoint_anchors.has(String(checkpoint_id)):
        return false
    checkpoint_ids.append(checkpoint_id)
    checkpoint_ids.sort()
    checkpoint_anchors[String(checkpoint_id)] = {
        "room_instance_id": String(room_instance_id),
        "local_tile_x": local_tile.x,
        "local_tile_y": local_tile.y,
    }
    return true

func get_checkpoint_anchor(checkpoint_id: StringName) -> Dictionary:
    var raw: Variant = checkpoint_anchors.get(String(checkpoint_id), null)
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func to_dictionary() -> Dictionary:
    return {
        "floor_id": floor_id,
        "instance_id": String(instance_id),
        "seed": seed,
        "layout_revision_id": String(layout_revision_id),
        "layout_manifest": _encode_persistent_variant(layout_manifest),
        "discovered_room_ids": _string_array(discovered_room_ids),
        "defeated_actor_ids": _string_array(defeated_actor_ids),
        "claimed_source_ids": _string_array(claimed_source_ids),
        "loose_items": loose_items.duplicate(true),
        "vendor_state": vendor_state.duplicate(true),
        "quest_state": quest_state.duplicate(true),
        "checkpoint_ids": _string_array(checkpoint_ids),
        "checkpoint_anchors": checkpoint_anchors.duplicate(true),
        "boss_defeated": boss_defeated,
        "primary_cleared": primary_cleared,
    }


func load_dictionary(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = validate_dictionary(data)
    if not errors.is_empty():
        return errors
    floor_id = int(data["floor_id"])
    instance_id = StringName(String(data["instance_id"]))
    seed = int(data["seed"])
    layout_revision_id = StringName(String(data["layout_revision_id"]))
    var decoded_manifest: Variant = _decode_persistent_variant(data.get("layout_manifest", {}))
    layout_manifest = _normalize_layout_manifest_types(decoded_manifest as Dictionary) if decoded_manifest is Dictionary else {}
    var raw_discovered_rooms: Variant = data.get("discovered_room_ids", [])
    discovered_room_ids = _to_string_name_array(raw_discovered_rooms as Array) if raw_discovered_rooms is Array else []
    defeated_actor_ids = _to_string_name_array(data["defeated_actor_ids"] as Array)
    claimed_source_ids = _to_string_name_array(data["claimed_source_ids"] as Array)
    loose_items = (data["loose_items"] as Dictionary).duplicate(true)
    vendor_state = (data["vendor_state"] as Dictionary).duplicate(true)
    quest_state = (data["quest_state"] as Dictionary).duplicate(true)
    checkpoint_ids = _to_string_name_array(data["checkpoint_ids"] as Array)
    var raw_checkpoint_anchors: Variant = data.get("checkpoint_anchors", {})
    checkpoint_anchors = (raw_checkpoint_anchors as Dictionary).duplicate(true) if raw_checkpoint_anchors is Dictionary else {}
    boss_defeated = bool(data["boss_defeated"])
    primary_cleared = bool(data["primary_cleared"])
    return errors


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if not _is_integral(data.get("floor_id", null)) or int(data.get("floor_id", 0)) < 1 or int(data.get("floor_id", 0)) > 10:
        errors.append("floor_id must be an integer from 1 through 10")
    if not StableId.is_valid(String(data.get("instance_id", ""))):
        errors.append("instance_id must be a stable ID")
    if not _is_integral(data.get("seed", null)) or int(data.get("seed", -1)) < 0:
        errors.append("seed must be a nonnegative integer")
    if not StableId.is_valid(String(data.get("layout_revision_id", ""))):
        errors.append("layout_revision_id must be a stable ID")
    if data.has("layout_manifest") and not data.get("layout_manifest", null) is Dictionary:
        errors.append("layout_manifest must be a dictionary when present")
    elif data.has("layout_manifest"):
        var decoded_manifest: Variant = _decode_persistent_variant(data.get("layout_manifest", {}))
        if not decoded_manifest is Dictionary:
            errors.append("layout_manifest must decode to a dictionary")
    if data.has("discovered_room_ids"):
        _validate_id_array(data.get("discovered_room_ids", null), "discovered_room_ids", errors)
    _validate_id_array(data.get("defeated_actor_ids", null), "defeated_actor_ids", errors)
    _validate_id_array(data.get("claimed_source_ids", null), "claimed_source_ids", errors)
    _validate_id_array(data.get("checkpoint_ids", null), "checkpoint_ids", errors)
    _validate_checkpoint_anchors(data.get("checkpoint_anchors", {}), data.get("checkpoint_ids", []), errors)
    for key: String in ["loose_items", "vendor_state", "quest_state"]:
        if not data.get(key, null) is Dictionary:
            errors.append("%s must be a dictionary" % key)
    var loose_items_variant: Variant = data.get("loose_items", null)
    if loose_items_variant is Dictionary:
        for raw_source_key: Variant in (loose_items_variant as Dictionary).keys():
            var raw_entry: Variant = (loose_items_variant as Dictionary)[raw_source_key]
            if not bool(PLAYER_DROP_STATE_VALIDATOR.should_validate_entry(raw_source_key, raw_entry)):
                continue
            var source_id := StringName(String(raw_source_key))
            var drop_errors: PackedStringArray = PLAYER_DROP_STATE_VALIDATOR.validate_entry(raw_entry, source_id)
            for drop_error: String in drop_errors:
                errors.append("loose_items[%s]: %s" % [String(raw_source_key), drop_error])
    if typeof(data.get("boss_defeated", null)) != TYPE_BOOL:
        errors.append("boss_defeated must be boolean")
    if typeof(data.get("primary_cleared", null)) != TYPE_BOOL:
        errors.append("primary_cleared must be boolean")
    return errors


static func ordinary_revisit_copy(data: Dictionary) -> Dictionary:
    if not validate_dictionary(data).is_empty():
        return {}
    return data.duplicate(true)


static func supports_fresh_reset() -> bool:
    return false


static func _validate_id_array(value: Variant, label: String, errors: PackedStringArray) -> void:
    if not value is Array:
        errors.append("%s must be an array" % label)
        return
    var seen: Dictionary = {}
    for id_variant: Variant in value as Array:
        var id_text: String = String(id_variant)
        if not StableId.is_valid(id_text):
            errors.append("%s contains invalid stable ID" % label)
        elif seen.has(id_text):
            errors.append("%s contains duplicate ID: %s" % [label, id_text])
        seen[id_text] = true


static func _validate_checkpoint_anchors(value: Variant, checkpoint_ids_variant: Variant, errors: PackedStringArray) -> void:
    if not value is Dictionary:
        errors.append("checkpoint_anchors must be a dictionary when present")
        return
    var checkpoint_ids_lookup: Dictionary = {}
    if checkpoint_ids_variant is Array:
        for raw_id: Variant in checkpoint_ids_variant as Array:
            checkpoint_ids_lookup[String(raw_id)] = true
    for raw_key: Variant in (value as Dictionary).keys():
        var checkpoint_id := String(raw_key)
        if not StableId.is_valid(checkpoint_id):
            errors.append("checkpoint_anchors contains invalid checkpoint ID")
            continue
        if not checkpoint_ids_lookup.has(checkpoint_id):
            errors.append("checkpoint_anchors key must also exist in checkpoint_ids")
        var raw_anchor: Variant = (value as Dictionary)[raw_key]
        if not raw_anchor is Dictionary:
            errors.append("checkpoint_anchors entries must be dictionaries")
            continue
        var anchor := raw_anchor as Dictionary
        if not StableId.is_valid(String(anchor.get("room_instance_id", ""))):
            errors.append("checkpoint_anchors room_instance_id must be a stable ID")
        if not _is_integral(anchor.get("local_tile_x", null)) or not _is_integral(anchor.get("local_tile_y", null)):
            errors.append("checkpoint_anchors local tile coordinates must be integers")

static func _is_integral(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return true
    if typeof(value) != TYPE_FLOAT:
        return false
    var number: float = float(value)
    return is_finite(number) and is_equal_approx(number, round(number))


static func _encode_persistent_variant(value: Variant) -> Variant:
    match typeof(value):
        TYPE_STRING_NAME:
            return {
                "__nice_journey_variant_type__": "StringName",
                "value": String(value),
            }
        TYPE_VECTOR2I:
            var vector: Vector2i = value as Vector2i
            return {
                "__nice_journey_variant_type__": "Vector2i",
                "x": vector.x,
                "y": vector.y,
            }
        TYPE_RECT2I:
            var rect: Rect2i = value as Rect2i
            return {
                "__nice_journey_variant_type__": "Rect2i",
                "x": rect.position.x,
                "y": rect.position.y,
                "w": rect.size.x,
                "h": rect.size.y,
            }
        TYPE_ARRAY:
            var encoded_array: Array = []
            for entry: Variant in value as Array:
                encoded_array.append(_encode_persistent_variant(entry))
            return encoded_array
        TYPE_DICTIONARY:
            var encoded_dictionary: Dictionary = {}
            for raw_key: Variant in (value as Dictionary).keys():
                encoded_dictionary[String(raw_key)] = _encode_persistent_variant((value as Dictionary)[raw_key])
            return encoded_dictionary
        _:
            return value


static func _decode_persistent_variant(value: Variant) -> Variant:
    if value is Array:
        var decoded_array: Array = []
        for entry: Variant in value as Array:
            decoded_array.append(_decode_persistent_variant(entry))
        return decoded_array
    if not value is Dictionary:
        return value
    var dictionary: Dictionary = value as Dictionary
    var marker := String(dictionary.get("__nice_journey_variant_type__", ""))
    match marker:
        "StringName":
            return StringName(String(dictionary.get("value", "")))
        "Vector2i":
            return Vector2i(int(dictionary.get("x", 0)), int(dictionary.get("y", 0)))
        "Rect2i":
            return Rect2i(
                int(dictionary.get("x", 0)),
                int(dictionary.get("y", 0)),
                int(dictionary.get("w", 0)),
                int(dictionary.get("h", 0))
            )
    var decoded_dictionary: Dictionary = {}
    for raw_key: Variant in dictionary.keys():
        decoded_dictionary[String(raw_key)] = _decode_persistent_variant(dictionary[raw_key])
    return decoded_dictionary


static func _normalize_layout_manifest_types(source: Dictionary) -> Dictionary:
    var result := source.duplicate(true)
    for key: String in ["floor_id", "generation_seed"]:
        if result.has(key) and (typeof(result[key]) == TYPE_INT or typeof(result[key]) == TYPE_FLOAT):
            result[key] = int(result[key])
    if result.get("rooms", null) is Array:
        var normalized_rooms: Array[Dictionary] = []
        for raw_room: Variant in result["rooms"] as Array:
            if not raw_room is Dictionary:
                continue
            var room := (raw_room as Dictionary).duplicate(true)
            for key: String in ["objective_socket_capacity", "elite_capacity"]:
                if room.has(key) and (typeof(room[key]) == TYPE_INT or typeof(room[key]) == TYPE_FLOAT):
                    room[key] = int(room[key])
            normalized_rooms.append(room)
        result["rooms"] = normalized_rooms
    if result.get("edges", null) is Array:
        var normalized_edges: Array[Dictionary] = []
        for raw_edge: Variant in result["edges"] as Array:
            if not raw_edge is Dictionary:
                continue
            var edge := (raw_edge as Dictionary).duplicate(true)
            if edge.has("route_width_tiles") and (typeof(edge["route_width_tiles"]) == TYPE_INT or typeof(edge["route_width_tiles"]) == TYPE_FLOAT):
                edge["route_width_tiles"] = int(edge["route_width_tiles"])
            normalized_edges.append(edge)
        result["edges"] = normalized_edges
    return result


static func _string_array(values: Array[StringName]) -> Array[String]:
    var result: Array[String] = []
    for value: StringName in values:
        result.append(String(value))
    return result


static func _to_string_name_array(values: Array) -> Array[StringName]:
    var result: Array[StringName] = []
    for value: Variant in values:
        result.append(StringName(String(value)))
    return result
