class_name StarterWeaponVisualProfile
extends Resource

@export var class_id: StringName = &""
@export var main_hand_texture: Texture2D = null
@export var main_hand_position: Vector2 = Vector2.ZERO
@export var main_hand_rotation_degrees: float = 0.0
@export var main_hand_scale: Vector2 = Vector2.ONE
@export var shield_texture: Texture2D = null
@export var shield_position: Vector2 = Vector2.ZERO
@export var shield_rotation_degrees: float = 0.0
@export var shield_scale: Vector2 = Vector2.ONE
@export var shield_visible: bool = false


func validate_profile() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if not StableId.is_valid(String(class_id)):
        errors.append("class_id must be a stable ID")
    if main_hand_texture == null:
        errors.append("main_hand_texture is required")
    if shield_visible and shield_texture == null:
        errors.append("shield_texture is required when shield_visible is true")
    if not _is_finite_vector(main_hand_position):
        errors.append("main_hand_position must be finite")
    if not _is_finite_vector(main_hand_scale):
        errors.append("main_hand_scale must be finite")
    if not is_finite(main_hand_rotation_degrees):
        errors.append("main_hand_rotation_degrees must be finite")
    if not _is_finite_vector(shield_position):
        errors.append("shield_position must be finite")
    if not _is_finite_vector(shield_scale):
        errors.append("shield_scale must be finite")
    if not is_finite(shield_rotation_degrees):
        errors.append("shield_rotation_degrees must be finite")
    return errors


func _is_finite_vector(value: Vector2) -> bool:
    return is_finite(value.x) and is_finite(value.y)
