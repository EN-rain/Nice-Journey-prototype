class_name TowerRoomVisualProfile
extends Resource

const ROOM_TYPES: Array[StringName] = [
    &"combat",
    &"safe",
    &"reward",
    &"vendor",
    &"secret",
    &"elite",
    &"objective",
    &"boss",
]

@export var room_type: StringName = &""
@export var texture: Texture2D
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var sprite_scale: Vector2 = Vector2.ONE
@export_range(-128, 128, 1) var z_index: int = 0
@export var modulate: Color = Color.WHITE

func validate_profile() -> PackedStringArray:
    var errors := PackedStringArray()
    if not ROOM_TYPES.has(room_type):
        errors.append("room_type must be one of the eight prototype tower visual room categories")
    if texture == null:
        errors.append("texture is required")
    if not _is_finite_vector(sprite_offset):
        errors.append("sprite_offset must be finite")
    if not _is_finite_vector(sprite_scale):
        errors.append("sprite_scale must be finite")
    return errors

func _is_finite_vector(value: Vector2) -> bool:
    return is_finite(value.x) and is_finite(value.y)
