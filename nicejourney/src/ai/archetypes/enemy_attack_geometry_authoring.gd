class_name EnemyAttackGeometryAuthoring
extends Resource

@export var authored: bool = false
@export var geometry_id: StringName = &""
@export var query_shape: Shape2D = null
@export_range(0.0, 4096.0, 0.1) var max_reach_px: float = 0.0
@export_flags_2d_physics var collision_mask: int = 0
@export_range(0, 16, 1) var hit_interval_count: int = 0

@export_category("Live Delivery Authoring")
@export var live_placement_declared: bool = false
@export var local_offset: Vector2 = Vector2.ZERO
@export var local_rotation_radians: float = 0.0
@export var hit_active_ticks: PackedInt32Array = PackedInt32Array()


func validate_authoring() -> PackedStringArray:
    var errors := PackedStringArray()
    if not authored:
        errors.append("attack geometry is not authored")
        return errors
    if not StableId.is_valid(String(geometry_id)):
        errors.append("geometry_id must be a stable ID")
    if query_shape == null:
        errors.append("query_shape is required")
    if not is_finite(max_reach_px) or max_reach_px <= 0.0:
        errors.append("max_reach_px must be finite and positive")
    if collision_mask <= 0:
        errors.append("collision_mask must include at least one physics layer")
    if hit_interval_count <= 0:
        errors.append("hit_interval_count must be at least 1")
    if not _finite_vector(local_offset):
        errors.append("local_offset must be finite")
    if not is_finite(local_rotation_radians):
        errors.append("local_rotation_radians must be finite")
    return errors


func validate_live_delivery(active_ticks: int) -> PackedStringArray:
    var errors := validate_authoring()
    if not live_placement_declared:
        errors.append("live attack placement must be explicitly authored")
    if active_ticks <= 0:
        errors.append("active_ticks must be positive for live delivery")
    if hit_active_ticks.size() != hit_interval_count:
        errors.append("hit_active_ticks must declare exactly one tick for each hit interval")
    for index: int in range(hit_active_ticks.size()):
        var active_tick := int(hit_active_ticks[index])
        if active_tick < 0 or active_tick >= active_ticks:
            errors.append("hit_active_ticks[%d] must fall inside the authored active phase" % index)
    return errors


func live_query_transform(origin: Transform2D) -> Transform2D:
    return origin * Transform2D(local_rotation_radians, local_offset)


func _finite_vector(value: Vector2) -> bool:
    return is_finite(value.x) and is_finite(value.y)

