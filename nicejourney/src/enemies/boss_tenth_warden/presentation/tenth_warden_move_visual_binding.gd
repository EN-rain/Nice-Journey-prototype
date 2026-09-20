class_name TenthWardenMoveVisualBinding
extends Resource

@export var move_id: StringName = &""
@export var animation_name: StringName = &""
@export var telegraph_profile: EffectVisualProfile

func validate_binding(animation_library: AnimationLibrary) -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(move_id)):
        errors.append("move_id must be a stable ID")
    if animation_name == &"":
        errors.append("animation_name is required")
    elif animation_library == null or not animation_library.has_animation(animation_name):
        errors.append("animation_name must exist in the configured AnimationLibrary")
    if telegraph_profile != null:
        for error: String in telegraph_profile.validate_profile():
            errors.append("telegraph_profile: %s" % error)
    return errors
