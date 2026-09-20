class_name EnemyVisualProfile
extends Resource

@export var archetype_id: StringName = &""
@export var animation_library: AnimationLibrary
@export var body_offset: Vector2 = Vector2.ZERO
@export var body_scale: Vector2 = Vector2.ONE
@export_range(-128, 128, 1) var body_z_index: int = 0
@export var default_facing_left: bool = false
@export var idle_animation: StringName = &"idle"
@export var move_animation: StringName = &"move"
@export var windup_animation: StringName = &"windup"
@export var release_animation: StringName = &"release"
@export var hit_animation: StringName = &"hit"
@export var death_animation: StringName = &"death"
@export var block_animation: StringName = &"block"

@export_category("Telegraph presentation")
@export var telegraph_profile: EffectVisualProfile
@export var telegraph_offset: Vector2 = Vector2.ZERO
@export var telegraph_scale: Vector2 = Vector2.ONE
@export var telegraph_rotation_degrees: float = 0.0


func validate_profile() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(archetype_id)):
        errors.append("archetype_id must be a stable ID")
    if animation_library == null:
        errors.append("animation_library is required")
        return errors
    for animation_name: StringName in [idle_animation, move_animation, windup_animation, release_animation, hit_animation, death_animation]:
        if animation_name == &"" or not animation_library.has_animation(animation_name):
            errors.append("required animation missing: %s" % String(animation_name))
    if block_animation != &"" and not animation_library.has_animation(block_animation):
        errors.append("configured block_animation is missing")
    if telegraph_profile != null:
        for error: String in telegraph_profile.validate_profile():
            errors.append("telegraph_profile: %s" % error)
    if not _is_finite_vector(telegraph_offset):
        errors.append("telegraph_offset must be finite")
    if not _is_finite_vector(telegraph_scale):
        errors.append("telegraph_scale must be finite")
    if not is_finite(telegraph_rotation_degrees):
        errors.append("telegraph_rotation_degrees must be finite")
    return errors


func _is_finite_vector(value: Vector2) -> bool:
    return is_finite(value.x) and is_finite(value.y)
