class_name TowerDefenseObjectiveState
extends RefCounted

var objective_id: StringName = &""
var objective_max_hp: int = 0
var objective_current_hp: int = 0
var required_actor_ids_by_wave: Dictionary = {}
var defeated_actor_ids_by_wave: Dictionary = {}
var failed: bool = false

func configure(new_objective_id: StringName, max_hp: int, required_waves: Dictionary) -> bool:
    if not StableId.is_valid(String(new_objective_id)) or max_hp <= 0:
        return false
    var normalized := _normalize_waves(required_waves)
    if normalized.is_empty():
        return false
    objective_id = new_objective_id
    objective_max_hp = max_hp
    objective_current_hp = max_hp
    required_actor_ids_by_wave = normalized
    defeated_actor_ids_by_wave = {}
    for wave_id: Variant in normalized.keys():
        defeated_actor_ids_by_wave[String(wave_id)] = []
    failed = false
    return true

func apply_objective_damage(amount: int) -> Dictionary:
    if amount <= 0:
        return _result(false, &"invalid_damage")
    if failed or is_complete():
        return _result(false, &"objective_terminal")
    objective_current_hp = maxi(0, objective_current_hp - amount)
    if objective_current_hp == 0:
        failed = true
    return _result(true, &"")

func record_actor_defeated(wave_id: StringName, actor_id: StringName) -> Dictionary:
    if failed or is_complete():
        return _result(false, &"objective_terminal")
    if not required_actor_ids_by_wave.has(String(wave_id)):
        return _result(false, &"wave_not_required")
    var required: Array = required_actor_ids_by_wave[String(wave_id)] as Array
    if not required.has(String(actor_id)):
        return _result(false, &"actor_not_required")
    var defeated: Array = defeated_actor_ids_by_wave[String(wave_id)] as Array
    if defeated.has(String(actor_id)):
        return _result(true, &"duplicate_ignored")
    defeated.append(String(actor_id))
    defeated.sort()
    defeated_actor_ids_by_wave[String(wave_id)] = defeated
    return _result(true, &"")

func is_wave_complete(wave_id: StringName) -> bool:
    if not required_actor_ids_by_wave.has(String(wave_id)):
        return false
    var required: Array = required_actor_ids_by_wave[String(wave_id)] as Array
    var defeated: Array = defeated_actor_ids_by_wave.get(String(wave_id), []) as Array
    return not required.is_empty() and defeated.size() == required.size()

func is_complete() -> bool:
    if failed or objective_current_hp <= 0 or required_actor_ids_by_wave.is_empty():
        return false
    for wave_id: Variant in required_actor_ids_by_wave.keys():
        if not is_wave_complete(StringName(String(wave_id))):
            return false
    return true

func to_dictionary() -> Dictionary:
    return {
        "objective_id": String(objective_id),
        "objective_max_hp": objective_max_hp,
        "objective_current_hp": objective_current_hp,
        "required_actor_ids_by_wave": _copy_wave_dictionary(required_actor_ids_by_wave),
        "defeated_actor_ids_by_wave": _copy_wave_dictionary(defeated_actor_ids_by_wave),
        "failed": failed,
    }

func load_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := validate_dictionary(data)
    if not errors.is_empty():
        return errors
    objective_id = StringName(String(data["objective_id"]))
    objective_max_hp = int(data["objective_max_hp"])
    objective_current_hp = int(data["objective_current_hp"])
    required_actor_ids_by_wave = _copy_wave_dictionary(data["required_actor_ids_by_wave"] as Dictionary)
    defeated_actor_ids_by_wave = _copy_wave_dictionary(data["defeated_actor_ids_by_wave"] as Dictionary)
    failed = bool(data["failed"])
    return errors

static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(data.get("objective_id", ""))):
        errors.append("objective_id must be a stable ID")
    if typeof(data.get("objective_max_hp", null)) != TYPE_INT or int(data.get("objective_max_hp", 0)) <= 0:
        errors.append("objective_max_hp must be a positive integer")
    if typeof(data.get("objective_current_hp", null)) != TYPE_INT:
        errors.append("objective_current_hp must be an integer")
    else:
        var current := int(data["objective_current_hp"])
        var maximum := int(data.get("objective_max_hp", 0))
        if current < 0 or current > maximum:
            errors.append("objective_current_hp must remain within 0..objective_max_hp")
    if typeof(data.get("failed", null)) != TYPE_BOOL:
        errors.append("failed must be boolean")
    if not data.get("required_actor_ids_by_wave", null) is Dictionary:
        errors.append("required_actor_ids_by_wave must be a dictionary")
        return errors
    if not data.get("defeated_actor_ids_by_wave", null) is Dictionary:
        errors.append("defeated_actor_ids_by_wave must be a dictionary")
        return errors
    var required := _normalize_waves(data["required_actor_ids_by_wave"] as Dictionary, errors)
    if required.is_empty():
        errors.append("at least one required defense wave is required")
    var defeated_raw := data["defeated_actor_ids_by_wave"] as Dictionary
    for wave_id: Variant in required.keys():
        if not defeated_raw.has(String(wave_id)):
            errors.append("every required wave needs defeated-actor state")
            continue
        var local_errors := PackedStringArray()
        var defeated := AnnihilationObjectiveState._validated_ids(defeated_raw[String(wave_id)], "defeated actors", local_errors)
        for error: String in local_errors:
            errors.append("wave %s: %s" % [String(wave_id), error])
        for actor_id: StringName in defeated:
            if not (required[String(wave_id)] as Array).has(String(actor_id)):
                errors.append("wave %s defeated actors must be required actors" % String(wave_id))
    if bool(data.get("failed", false)) and int(data.get("objective_current_hp", 1)) > 0:
        errors.append("failed defense requires objective_current_hp == 0")
    return errors

static func _normalize_waves(raw: Dictionary, errors: PackedStringArray = PackedStringArray()) -> Dictionary:
    var result: Dictionary = {}
    for raw_wave_id: Variant in raw.keys():
        var wave_id := String(raw_wave_id)
        if not StableId.is_valid(wave_id):
            errors.append("wave IDs must be stable")
            continue
        var local_errors := PackedStringArray()
        var ids := AnnihilationObjectiveState._validated_ids(raw[raw_wave_id], "required actors", local_errors)
        for error: String in local_errors:
            errors.append("wave %s: %s" % [wave_id, error])
        if ids.is_empty():
            errors.append("wave %s must require at least one actor" % wave_id)
            continue
        var serialized: Array[String] = []
        for actor_id: StringName in ids:
            serialized.append(String(actor_id))
        result[wave_id] = serialized
    return result

static func _copy_wave_dictionary(source: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for key: Variant in source.keys():
        result[String(key)] = (source[key] as Array).duplicate(true)
    return result

func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    var completed_wave_ids: Array[StringName] = []
    for wave_id: Variant in required_actor_ids_by_wave.keys():
        if is_wave_complete(StringName(String(wave_id))):
            completed_wave_ids.append(StringName(String(wave_id)))
    completed_wave_ids.sort()
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "objective_current_hp": objective_current_hp,
        "objective_max_hp": objective_max_hp,
        "failed": failed,
        "complete": is_complete(),
        "completed_wave_ids": completed_wave_ids,
    }
