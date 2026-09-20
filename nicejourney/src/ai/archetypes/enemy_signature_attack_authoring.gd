class_name EnemySignatureAttackAuthoring
extends Resource

@export var action_id: StringName = &""
@export var geometry: EnemyAttackGeometryAuthoring = null
@export var payload: EnemyAttackPayloadAuthoring = null


func validate_authoring() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(action_id)):
        errors.append("action_id must be a stable ID")
    if geometry == null:
        errors.append("geometry authoring is required")
    else:
        for error: String in geometry.validate_authoring():
            errors.append("geometry: %s" % error)
    if payload == null:
        errors.append("payload authoring is required")
    else:
        for error: String in payload.validate_authoring():
            errors.append("payload: %s" % error)
    return errors

