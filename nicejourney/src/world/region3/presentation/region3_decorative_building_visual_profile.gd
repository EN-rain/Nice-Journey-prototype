class_name Region3DecorativeBuildingVisualProfile
extends Resource

@export var structure_id: StringName = &""
@export var texture: Texture2D
@export var exact_source_evidence_accepted: bool = false
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var sprite_scale: Vector2 = Vector2.ONE
@export_range(-128, 128, 1) var z_index: int = 0
@export var modulate: Color = Color.WHITE

func validate_profile() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(structure_id)):
        errors.append("structure_id must be a stable ID")
    if not String(structure_id).begins_with("r3:decorative:"):
        errors.append("structure_id must identify a Region 3 decorative structure")
    if texture == null:
        errors.append("texture is required")
    if not _is_finite_vector(sprite_offset):
        errors.append("sprite_offset must be finite")
    if not _is_finite_vector(sprite_scale):
        errors.append("sprite_scale must be finite")
    return errors

func is_production_ready() -> bool:
    return exact_source_evidence_accepted and validate_profile().is_empty()


func _is_finite_vector(value: Vector2) -> bool:
    return is_finite(value.x) and is_finite(value.y)
