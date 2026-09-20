class_name TowerEscortRuntimeTuning
extends Resource

@export var authored: bool = false
@export var speed_px_per_second: float = 0.0
@export var arrival_tolerance_px: float = 0.0
@export var collision_shape: Shape2D = null
@export_flags_2d_physics var collision_layer: int = 0
@export_flags_2d_physics var collision_mask: int = 0

# Production policy is intentionally separate from the mechanics-only tuning
# gate so focused movement tests may still provide a minimal physical fixture.
@export var max_hp: int = 0
@export var health_policy_id: StringName = &""
@export var failure_policy_id: StringName = &""
@export var separation_policy_id: StringName = &""
@export var repath_policy_id: StringName = &""
@export var save_policy_id: StringName = &""


func validate_tuning() -> PackedStringArray:
    var errors := PackedStringArray()
    if not authored:
        errors.append("Tower escort physical tuning is not authored")
    if not is_finite(speed_px_per_second) or speed_px_per_second <= 0.0:
        errors.append("speed_px_per_second must be finite and positive")
    if not is_finite(arrival_tolerance_px) or arrival_tolerance_px <= 0.0:
        errors.append("arrival_tolerance_px must be finite and positive")
    if collision_shape == null:
        errors.append("collision_shape is required")
    else:
        var bounds := collision_shape.get_rect()
        if not is_finite(bounds.size.x) or not is_finite(bounds.size.y) or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
            errors.append("collision_shape must have a finite positive footprint")
    if collision_layer <= 0:
        errors.append("collision_layer must include at least one physics layer")
    if collision_mask <= 0:
        errors.append("collision_mask must include at least one physics layer")
    return errors


func validate_production_tuning() -> PackedStringArray:
    var errors := validate_tuning()
    if max_hp <= 0:
        errors.append("max_hp must be positive for production Escort")
    for field: Dictionary in [
        {"name": "health_policy_id", "value": health_policy_id},
        {"name": "failure_policy_id", "value": failure_policy_id},
        {"name": "separation_policy_id", "value": separation_policy_id},
        {"name": "repath_policy_id", "value": repath_policy_id},
        {"name": "save_policy_id", "value": save_policy_id},
    ]:
        if not StableId.is_valid(String(field["value"])):
            errors.append("%s must be a stable ID" % String(field["name"]))
    if failure_policy_id != TowerEscortObjectiveAuthoring.FAILURE_POLICY_ACTOR_DEFEAT:
        errors.append("production Escort failure_policy_id must match objective authoring")
    return errors
