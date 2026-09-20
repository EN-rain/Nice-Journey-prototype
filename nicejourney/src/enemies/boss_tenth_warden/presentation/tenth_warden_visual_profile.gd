class_name TenthWardenVisualProfile
extends Resource

@export var boss_id: StringName = &"tenth_warden"
@export var animation_library: AnimationLibrary
@export var body_offset: Vector2 = Vector2.ZERO
@export var body_scale: Vector2 = Vector2.ONE
@export_range(-128, 128, 1) var body_z_index: int = 0
@export var idle_animation: StringName = &"idle"
@export var phase_two_animation: StringName = &"phase_two"
@export var hit_animation: StringName = &"hit"
@export var death_animation: StringName = &"death"
@export var move_visuals: Array[TenthWardenMoveVisualBinding] = []

func validate_profile() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(boss_id)):
        errors.append("boss_id must be a stable ID")
    if animation_library == null:
        errors.append("animation_library is required")
        return errors
    for animation_name: StringName in [idle_animation, phase_two_animation, hit_animation, death_animation]:
        if animation_name == &"" or not animation_library.has_animation(animation_name):
            errors.append("required animation missing: %s" % String(animation_name))
    var seen_moves: Dictionary = {}
    for binding: TenthWardenMoveVisualBinding in move_visuals:
        if binding == null:
            errors.append("move_visuals cannot contain null bindings")
            continue
        for error: String in binding.validate_binding(animation_library):
            errors.append("%s: %s" % [String(binding.move_id), error])
        if seen_moves.has(binding.move_id):
            errors.append("duplicate move_id: %s" % String(binding.move_id))
        seen_moves[binding.move_id] = true
    if not _finite_vector(body_offset) or not _finite_vector(body_scale):
        errors.append("body transform values must be finite")
    return errors

func find_move(move_id: StringName) -> TenthWardenMoveVisualBinding:
    for binding: TenthWardenMoveVisualBinding in move_visuals:
        if binding != null and binding.move_id == move_id:
            return binding
    return null

func _finite_vector(value: Vector2) -> bool:
    return is_finite(value.x) and is_finite(value.y)
