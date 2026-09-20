class_name PlayerStaminaResourcePool
extends ResourcePool

# Player stamina is owned by StaminaComponent. The action clock only routes
# commit-time costs; it must not maintain a second drifting stamina total.
const RESOURCE_STAMINA: StringName = &"stamina"
var _stamina_source: StaminaComponent = null


func bind_stamina_source(source: StaminaComponent) -> bool:
    if source == null or not is_instance_valid(source) or source.tuning == null:
        return false
    _stamina_source = source
    return true


func _live_stamina() -> StaminaComponent:
    return _stamina_source if _stamina_source != null and is_instance_valid(_stamina_source) and _stamina_source.tuning != null else null


func has_resource(resource_id: StringName) -> bool:
    if resource_id == RESOURCE_STAMINA:
        return _live_stamina() != null
    return super.has_resource(resource_id)


func get_value(resource_id: StringName) -> float:
    if resource_id == RESOURCE_STAMINA:
        var source := _live_stamina()
        return source.current_stamina if source != null else 0.0
    return super.get_value(resource_id)


func get_maximum(resource_id: StringName) -> float:
    if resource_id == RESOURCE_STAMINA:
        var source := _live_stamina()
        return source.get_max_stamina() if source != null else 0.0
    return super.get_maximum(resource_id)


func can_spend(resource_id: StringName, amount: float) -> bool:
    if resource_id == RESOURCE_STAMINA:
        var source := _live_stamina()
        return source != null and source.can_spend(amount)
    return super.can_spend(resource_id, amount)


func try_spend(resource_id: StringName, amount: float) -> bool:
    if resource_id == RESOURCE_STAMINA:
        var source := _live_stamina()
        return source != null and source.try_spend(amount)
    return super.try_spend(resource_id, amount)
