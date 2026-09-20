class_name Region3TrainingServiceDefinition
extends RefCounted

const STRUCTURE_ID: StringName = &"r3:functional:07"
const ROLE_ID: StringName = &"training_hall"
const SKILL_SURFACE_ID: StringName = SkillsMenu.MODAL_ID


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    _require_stable_id(data, "service_id", errors)
    _require_stable_id(data, "structure_id", errors)
    _require_stable_id(data, "role_id", errors)

    if StringName(String(data.get("structure_id", &""))) != STRUCTURE_ID:
        errors.append("structure_id must identify the authored Region 3 Training Hall")
    if StringName(String(data.get("role_id", &""))) != ROLE_ID:
        errors.append("role_id must identify the Training Hall")

    if typeof(data.get("available", null)) != TYPE_BOOL:
        errors.append("available must be an explicitly authored boolean")
    if typeof(data.get("combat_restricted", null)) != TYPE_BOOL:
        errors.append("combat_restricted must be an explicitly authored boolean")
    elif not bool(data.get("combat_restricted", false)):
        errors.append("Training Hall service must remain unavailable during Active Combat")

    _require_nullable_stable_id(data, "instruction_content_id", errors)
    _require_nullable_stable_id(data, "practice_interaction_id", errors)
    _require_nullable_stable_id(data, "skill_surface_id", errors)

    var skill_surface: Variant = data.get("skill_surface_id", null)
    if skill_surface != null and StringName(String(skill_surface)) != SKILL_SURFACE_ID:
        errors.append("skill_surface_id must reference the existing SkillsMenu surface")
    return errors


static func readiness_view(
    data: Dictionary,
    instruction_content_resolved: bool,
    practice_interaction_resolved: bool
) -> Dictionary:
    var validation_errors: PackedStringArray = validate_dictionary(data)
    var instruction_declared: bool = _is_stable_id_variant(data.get("instruction_content_id", null))
    var practice_declared: bool = _is_stable_id_variant(data.get("practice_interaction_id", null))
    var skill_surface_declared: bool = StringName(String(data.get("skill_surface_id", &""))) == SKILL_SURFACE_ID
    var blockers: Array[StringName] = []

    if not validation_errors.is_empty():
        blockers.append(&"definition_invalid")
    if not bool(data.get("available", false)):
        blockers.append(&"service_unavailable")
    if not instruction_declared:
        blockers.append(&"instruction_content_unauthored")
    elif not instruction_content_resolved:
        blockers.append(&"instruction_content_unresolved")
    if not practice_declared:
        blockers.append(&"practice_interaction_unauthored")
    elif not practice_interaction_resolved:
        blockers.append(&"practice_interaction_unresolved")
    if not skill_surface_declared:
        blockers.append(&"skill_surface_unauthored")

    return {
        "accepted": validation_errors.is_empty(),
        "structure_id": STRUCTURE_ID,
        "role_id": ROLE_ID,
        "service_id": StringName(String(data.get("service_id", &""))),
        "validation_errors": validation_errors.duplicate(),
        "instruction_content_declared": instruction_declared,
        "instruction_content_resolved": instruction_declared and instruction_content_resolved,
        "practice_interaction_declared": practice_declared,
        "practice_interaction_resolved": practice_declared and practice_interaction_resolved,
        "skill_surface_id": StringName(String(data.get("skill_surface_id", &""))),
        "skill_surface_resolved": skill_surface_declared,
        "content_ready": blockers.is_empty(),
        "blockers": blockers.duplicate(),
    }


static func _require_stable_id(data: Dictionary, key: String, errors: PackedStringArray) -> void:
    if not _is_stable_id_variant(data.get(key, null)):
        errors.append("%s must be a stable ID" % key)


static func _require_nullable_stable_id(data: Dictionary, key: String, errors: PackedStringArray) -> void:
    if not data.has(key):
        errors.append("%s must be explicitly present (null when unauthored)" % key)
        return
    var value: Variant = data.get(key, null)
    if value != null and not _is_stable_id_variant(value):
        errors.append("%s must be null or a stable ID" % key)


static func _is_stable_id_variant(value: Variant) -> bool:
    return (
        (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME)
        and StableId.is_valid(String(value))
    )
