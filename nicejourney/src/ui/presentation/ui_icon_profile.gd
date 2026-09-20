class_name UiIconProfile
extends Resource

@export var icon_id: StringName = &""
@export var texture: Texture2D
@export var minimum_size: Vector2 = Vector2(32, 32)
@export var expand_mode: TextureRect.ExpandMode = TextureRect.EXPAND_IGNORE_SIZE
@export var stretch_mode: TextureRect.StretchMode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func validate_profile() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(icon_id)):
        errors.append("icon_id must be a stable ID")
    if texture == null:
        errors.append("texture is required")
    if not is_finite(minimum_size.x) or not is_finite(minimum_size.y) or minimum_size.x < 0.0 or minimum_size.y < 0.0:
        errors.append("minimum_size must be finite and non-negative")
    return errors
