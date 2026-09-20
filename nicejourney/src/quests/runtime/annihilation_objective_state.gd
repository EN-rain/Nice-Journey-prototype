class_name AnnihilationObjectiveState
extends RefCounted

var required_actor_ids: Array[StringName] = []
var defeated_actor_ids: Array[StringName] = []

func configure(required_ids: Array[StringName]) -> bool:
    if required_ids.is_empty():
        return false
    var seen: Dictionary = {}
    for actor_id: StringName in required_ids:
        if not StableId.is_valid(String(actor_id)) or seen.has(actor_id):
            return false
        seen[actor_id] = true
    required_actor_ids = required_ids.duplicate()
    required_actor_ids.sort()
    defeated_actor_ids.clear()
    return true

func record_actor_defeated(actor_id: StringName) -> Dictionary:
    if not StableId.is_valid(String(actor_id)):
        return _result(false, &"invalid_actor_id")
    if not required_actor_ids.has(actor_id):
        return _result(false, &"actor_not_required")
    if defeated_actor_ids.has(actor_id):
        return _result(true, &"duplicate_ignored")
    defeated_actor_ids.append(actor_id)
    defeated_actor_ids.sort()
    return _result(true, &"")

func is_complete() -> bool:
    return not required_actor_ids.is_empty() and defeated_actor_ids.size() == required_actor_ids.size()

func remaining_actor_ids() -> Array[StringName]:
    var result: Array[StringName] = []
    for actor_id: StringName in required_actor_ids:
        if not defeated_actor_ids.has(actor_id):
            result.append(actor_id)
    return result

func to_dictionary() -> Dictionary:
    return {
        "required_actor_ids": _strings(required_actor_ids),
        "defeated_actor_ids": _strings(defeated_actor_ids),
    }

func load_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := validate_dictionary(data)
    if not errors.is_empty():
        return errors
    required_actor_ids = _names(data["required_actor_ids"] as Array)
    defeated_actor_ids = _names(data["defeated_actor_ids"] as Array)
    return errors

static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    var required := _validated_ids(data.get("required_actor_ids", null), "required_actor_ids", errors)
    var defeated := _validated_ids(data.get("defeated_actor_ids", null), "defeated_actor_ids", errors)
    if required.is_empty():
        errors.append("required_actor_ids must not be empty")
    for actor_id: StringName in defeated:
        if not required.has(actor_id):
            errors.append("defeated_actor_ids may contain only designated required actors")
    return errors

func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "defeated_count": defeated_actor_ids.size(),
        "required_count": required_actor_ids.size(),
        "complete": is_complete(),
        "remaining_actor_ids": remaining_actor_ids(),
    }

static func _validated_ids(value: Variant, label: String, errors: PackedStringArray) -> Array[StringName]:
    var result: Array[StringName] = []
    if not value is Array:
        errors.append("%s must be an array" % label)
        return result
    var seen: Dictionary = {}
    for raw: Variant in value as Array:
        if not (typeof(raw) == TYPE_STRING or typeof(raw) == TYPE_STRING_NAME) or not StableId.is_valid(String(raw)):
            errors.append("%s requires stable IDs" % label)
            continue
        var id := StringName(String(raw))
        if seen.has(id):
            errors.append("%s must be unique" % label)
            continue
        seen[id] = true
        result.append(id)
    result.sort()
    return result

static func _strings(values: Array[StringName]) -> Array[String]:
    var result: Array[String] = []
    for value: StringName in values:
        result.append(String(value))
    return result

static func _names(values: Array) -> Array[StringName]:
    var result: Array[StringName] = []
    for value: Variant in values:
        result.append(StringName(String(value)))
    result.sort()
    return result
