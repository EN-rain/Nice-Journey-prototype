class_name NpcVisualProfile
extends Resource

@export var role_id: StringName = &""
@export var texture: Texture2D = null
@export var animation_library: AnimationLibrary = null
@export var frame_size: Vector2i = Vector2i(32, 32)
@export var ground_anchor: Vector2 = Vector2(16.0, 29.0)
@export var mirror_left: bool = true
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var wait_animation: StringName = &"idle"
@export var follow_animation: StringName = &"walk"
@export var panic_animation: StringName = &"walk"

func animation_for_semantic_state(state: StringName) -> StringName:
    match state:
        &"wait": return wait_animation
        &"follow": return follow_animation
        &"panic": return panic_animation
        &"walk": return walk_animation
        _: return idle_animation

func validate_presentation() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(role_id)): errors.append("role_id must be a stable ID")
    if frame_size != Vector2i(32, 32): errors.append("NPC frame_size must remain 32x32")
    if ground_anchor != Vector2(16.0, 29.0): errors.append("NPC ground_anchor must remain (16,29)")
    if not mirror_left: errors.append("NPC art must author right-facing art and mirror left")
    return errors
