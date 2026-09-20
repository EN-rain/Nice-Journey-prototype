class_name EnemyArchetypeDefinition
extends Resource

const RANGE_CLOSE: StringName = &"close"
const RANGE_MID: StringName = &"mid"
const RANGE_LONG: StringName = &"long"

@export var archetype_id: StringName = &""
@export var role_name: String = ""
@export var preferred_range: StringName = RANGE_CLOSE
@export var observable_trigger_ids: Array[StringName] = []
@export var signature_action_id: StringName = &""
@export var recovery_window_id: StringName = &""
@export var defensive_limit_ids: Array[StringName] = []
@export var counterplay_ids: Array[StringName] = []
@export var group_role_id: StringName = &""
@export var objective_behavior_id: StringName = &""
@export var allowed_variant_ids: Array[StringName] = []
@export var tactic_ids: Array[StringName] = []
@export var signature_attack_authoring: EnemySignatureAttackAuthoring = null


func validate_definition() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if not StableId.is_valid(String(archetype_id)):
        errors.append("archetype_id must be a stable ID")
    if role_name.strip_edges().is_empty():
        errors.append("role_name is required")
    if not [RANGE_CLOSE, RANGE_MID, RANGE_LONG].has(preferred_range):
        errors.append("preferred_range must be close, mid, or long")
    if not StableId.is_valid(String(signature_action_id)):
        errors.append("signature_action_id must be a stable ID")
    if not StableId.is_valid(String(recovery_window_id)):
        errors.append("recovery_window_id must be a stable ID")
    if not StableId.is_valid(String(group_role_id)):
        errors.append("group_role_id must be a stable ID")
    if not StableId.is_valid(String(objective_behavior_id)):
        errors.append("objective_behavior_id must be a stable ID")
    _validate_ids(observable_trigger_ids, "observable_trigger_ids", errors, false)
    _validate_ids(defensive_limit_ids, "defensive_limit_ids", errors, false)
    _validate_ids(counterplay_ids, "counterplay_ids", errors, false)
    _validate_ids(allowed_variant_ids, "allowed_variant_ids", errors, true)
    _validate_ids(tactic_ids, "tactic_ids", errors, false)
    return errors


func validate_signature_attack_authoring() -> PackedStringArray:
    var errors := PackedStringArray()
    if signature_attack_authoring == null:
        errors.append("signature attack authoring is missing")
        return errors
    for authoring_error: String in signature_attack_authoring.validate_authoring():
        errors.append(authoring_error)
    if signature_attack_authoring.action_id != signature_action_id:
        errors.append("signature attack action_id must match signature_action_id")
    return errors


static func _validate_ids(values: Array[StringName], label: String, errors: PackedStringArray, allow_empty: bool) -> void:
    if values.is_empty() and not allow_empty:
        errors.append("%s cannot be empty" % label)
        return
    var seen: Dictionary = {}
    for value: StringName in values:
        if not StableId.is_valid(String(value)):
            errors.append("%s contains an invalid stable ID" % label)
        elif seen.has(value):
            errors.append("%s contains duplicate ID: %s" % [label, String(value)])
        seen[value] = true
