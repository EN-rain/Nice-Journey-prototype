class_name DelayedResourceRegenerator
extends RefCounted

var delay_ticks: int = 0
var amount_per_tick: float = 0.0
var _remaining_delay_ticks: int = 0


func configure(authored_delay_ticks: int, authored_amount_per_tick: float) -> bool:
    if authored_delay_ticks < 0 or not is_finite(authored_amount_per_tick) or authored_amount_per_tick < 0.0:
        return false
    delay_ticks = authored_delay_ticks
    amount_per_tick = authored_amount_per_tick
    _remaining_delay_ticks = 0
    return true


func notify_spend() -> void:
    _remaining_delay_ticks = delay_ticks


func advance_fixed_tick(pool: ResourcePool, resource_id: StringName) -> bool:
    if pool == null or resource_id == &"" or not pool.has_resource(resource_id):
        return false
    if _remaining_delay_ticks > 0:
        _remaining_delay_ticks -= 1
        return true
    if amount_per_tick <= 0.0:
        return true
    return pool.restore(resource_id, amount_per_tick)


func get_remaining_delay_ticks() -> int:
    return _remaining_delay_ticks

func restore_remaining_delay_ticks(remaining_ticks: int) -> bool:
    if remaining_ticks < 0:
        return false
    _remaining_delay_ticks = mini(remaining_ticks, delay_ticks)
    return true
