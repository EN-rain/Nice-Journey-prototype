class_name ResourcePool
extends RefCounted

var _values: Dictionary = {}
var _maximums: Dictionary = {}

func define_resource(resource_id: StringName, maximum: float, initial: float = -1.0) -> bool:
    if String(resource_id).is_empty() or maximum < 0.0:
        return false
    var starting_value: float = maximum if initial < 0.0 else clampf(initial, 0.0, maximum)
    _maximums[resource_id] = maximum
    _values[resource_id] = starting_value
    return true

func has_resource(resource_id: StringName) -> bool:
    return _maximums.has(resource_id)

func get_value(resource_id: StringName) -> float:
    return float(_values.get(resource_id, 0.0))

func get_maximum(resource_id: StringName) -> float:
    return float(_maximums.get(resource_id, 0.0))

func can_spend(resource_id: StringName, amount: float) -> bool:
    if amount < 0.0 or not has_resource(resource_id):
        return false
    return get_value(resource_id) + 0.0001 >= amount

func try_spend(resource_id: StringName, amount: float) -> bool:
    if not can_spend(resource_id, amount):
        return false
    _values[resource_id] = clampf(get_value(resource_id) - amount, 0.0, get_maximum(resource_id))
    return true

func restore(resource_id: StringName, amount: float) -> bool:
    if amount < 0.0 or not has_resource(resource_id):
        return false
    _values[resource_id] = clampf(get_value(resource_id) + amount, 0.0, get_maximum(resource_id))
    return true

func set_value(resource_id: StringName, value: float) -> bool:
    if not has_resource(resource_id):
        return false
    _values[resource_id] = clampf(value, 0.0, get_maximum(resource_id))
    return true
