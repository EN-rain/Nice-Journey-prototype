class_name EffectVisualProfile
extends Resource

@export var effect_id: StringName = &""
@export var texture: Texture2D
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var sprite_scale: Vector2 = Vector2.ONE
@export var rotation_degrees: float = 0.0
@export_range(-128, 128, 1) var z_index: int = 0
@export var modulate: Color = Color.WHITE
@export var animation_library: AnimationLibrary
@export var default_animation: StringName = &"default"

func validate_profile() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(effect_id)):
        errors.append("effect_id must be a stable ID")
    if texture == null:
        errors.append("texture is required")
    if not _is_finite_vector(sprite_offset):
        errors.append("sprite_offset must be finite")
    if not _is_finite_vector(sprite_scale):
        errors.append("sprite_scale must be finite")
    if not is_finite(rotation_degrees):
        errors.append("rotation_degrees must be finite")
    if animation_library == null:
        errors.append("animation_library is required")
    elif default_animation == &"" or not animation_library.has_animation(default_animation):
        errors.append("default_animation must exist in animation_library")
    return errors

func _is_finite_vector(value: Vector2) -> bool:
    return is_finite(value.x) and is_finite(value.y)
