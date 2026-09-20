class_name QuestDefinition
extends Resource

const KIND_PRIMARY: StringName = &"primary"
const KIND_SIDE: StringName = &"side"
const FAMILY_ESCORT: StringName = &"escort"
const FAMILY_TOWER_DEFENSE: StringName = &"tower_defense"
const FAMILY_ANNIHILATION: StringName = &"annihilation"

@export var quest_id: StringName = &""
@export var kind: StringName = &""
@export var family: StringName = &""
@export_range(0, 10, 1) var floor_id: int = 0
@export var scope_id: StringName = &""
@export var stage_ids: Array[StringName] = []
@export var includes_region3_preparation: bool = false
@export var grants_tower_sigil: bool = false
@export_range(0, 10, 1) var unlocks_floor_id: int = 0
@export var playtest_placeholder: bool = false

# §14.5 requires objective and instance-binding declarations in addition to the
# quest family/stage structure above. Declaration flags keep "authored empty"
# distinct from "not authored yet" without inventing production content.
@export var required_objectives_declared: bool = false
@export var required_objective_ids: Array[StringName] = []
@export var optional_objectives_declared: bool = false
@export var optional_objective_ids: Array[StringName] = []
@export var instance_bindings_declared: bool = false
@export var instance_binding_ids: Array[StringName] = []

# §14.5 requires these policies to be declared per quest. Declaration flags are
# separate from values so an intentionally empty authored set (for example no
# branch effects) is distinguishable from content that has never been authored.
@export var prerequisites_declared: bool = false
@export var prerequisite_ids: Array[StringName] = []
@export var acceptance_anchor_declared: bool = false
@export var acceptance_anchor_id: StringName = &""
@export var turn_in_anchor_declared: bool = false
@export var turn_in_anchor_id: StringName = &""
@export var leave_rule_declared: bool = false
@export var leave_rule_id: StringName = &""
@export var failure_rule_declared: bool = false
@export var failure_rule_id: StringName = &""
@export var retry_reset_declared: bool = false
@export var retry_reset_ids: Array[StringName] = []
@export var rewards_declared: bool = false
@export var reward_ids: Array[StringName] = []
@export var branch_effects_declared: bool = false
@export var branch_effect_ids: Array[StringName] = []
@export var completion_conditions_declared: bool = false
@export var completion_condition_ids: Array[StringName] = []


func validate_definition() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if not StableId.is_valid(String(quest_id)):
        errors.append("quest_id must be a stable ID")
    if kind != KIND_PRIMARY and kind != KIND_SIDE:
        errors.append("kind must be primary or side")
    if not [FAMILY_ESCORT, FAMILY_TOWER_DEFENSE, FAMILY_ANNIHILATION].has(family):
        errors.append("family must be one of the three approved quest families")
    if floor_id < 0 or floor_id > 10:
        errors.append("floor_id must be 0 through 10")
    if kind == KIND_PRIMARY and (floor_id < 1 or floor_id > 10):
        errors.append("primary quest must bind one prototype floor")
    if not StableId.is_valid(String(scope_id)):
        errors.append("scope_id must be a stable ID")
    if stage_ids.is_empty():
        errors.append("stage_ids cannot be empty")
    var seen: Dictionary = {}
    for stage_id: StringName in stage_ids:
        if not StableId.is_valid(String(stage_id)):
            errors.append("stage_ids must contain stable IDs")
        elif seen.has(stage_id):
            errors.append("stage_ids must be unique")
        seen[stage_id] = true
    if unlocks_floor_id < 0 or unlocks_floor_id > 10:
        errors.append("unlocks_floor_id must be 0 through 10")
    if grants_tower_sigil and not includes_region3_preparation:
        errors.append("Tower Sigil grant must belong to the Region 3 preparation chain")
    return errors


func validate_authored_contract() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    _validate_declared_id_array(prerequisites_declared, prerequisite_ids, "prerequisites", false, errors)
    _validate_declared_id(acceptance_anchor_declared, acceptance_anchor_id, "acceptance_anchor_id", errors)
    _validate_declared_optional_id(turn_in_anchor_declared, turn_in_anchor_id, "turn_in_anchor_id", errors)
    _validate_declared_id_array(required_objectives_declared, required_objective_ids, "required_objective_ids", true, errors)
    _validate_declared_id_array(optional_objectives_declared, optional_objective_ids, "optional_objective_ids", false, errors)
    _validate_declared_id_array(instance_bindings_declared, instance_binding_ids, "instance_binding_ids", true, errors)
    _validate_objective_membership(errors)
    _validate_declared_id(leave_rule_declared, leave_rule_id, "leave_rule_id", errors)
    _validate_declared_id(failure_rule_declared, failure_rule_id, "failure_rule_id", errors)
    _validate_declared_id_array(retry_reset_declared, retry_reset_ids, "retry_reset_ids", true, errors)
    _validate_declared_id_array(rewards_declared, reward_ids, "rewards", false, errors)
    _validate_declared_id_array(branch_effects_declared, branch_effect_ids, "branch_effects", false, errors)
    _validate_declared_id_array(completion_conditions_declared, completion_condition_ids, "completion_conditions", true, errors)
    return errors


func validate_production_contract() -> PackedStringArray:
    var errors := validate_authored_contract()
    if playtest_placeholder:
        errors.append("playtest placeholder is not production-authoritative")
    return errors


func unauthored_contract_fields() -> PackedStringArray:
    var fields: PackedStringArray = PackedStringArray()
    if not prerequisites_declared:
        fields.append("prerequisite_ids")
    if not acceptance_anchor_declared:
        fields.append("acceptance_anchor_id")
    if not turn_in_anchor_declared:
        fields.append("turn_in_anchor_id")
    if not required_objectives_declared:
        fields.append("required_objective_ids")
    if not optional_objectives_declared:
        fields.append("optional_objective_ids")
    if not instance_bindings_declared:
        fields.append("instance_binding_ids")
    if not leave_rule_declared:
        fields.append("leave_rule_id")
    if not failure_rule_declared:
        fields.append("failure_rule_id")
    if not retry_reset_declared:
        fields.append("retry_reset_ids")
    if not rewards_declared:
        fields.append("reward_ids")
    if not branch_effects_declared:
        fields.append("branch_effect_ids")
    if not completion_conditions_declared:
        fields.append("completion_condition_ids")
    return fields


func _validate_objective_membership(errors: PackedStringArray) -> void:
    if not required_objectives_declared or not optional_objectives_declared:
        return
    var required: Dictionary = {}
    for objective_id: StringName in required_objective_ids:
        required[objective_id] = true
    for objective_id: StringName in optional_objective_ids:
        if required.has(objective_id):
            errors.append("objective ID cannot be both required and optional")


func _validate_declared_id(declared: bool, value: StringName, field_name: String, errors: PackedStringArray) -> void:
    if not declared:
        errors.append("%s must be explicitly declared" % field_name)
        return
    if not StableId.is_valid(String(value)):
        errors.append("%s must be a stable ID" % field_name)


func _validate_declared_optional_id(declared: bool, value: StringName, field_name: String, errors: PackedStringArray) -> void:
    if not declared:
        errors.append("%s must be explicitly declared" % field_name)
        return
    if value != &"" and not StableId.is_valid(String(value)):
        errors.append("%s must be empty for automatic completion or a stable ID" % field_name)


func _validate_declared_id_array(
    declared: bool,
    values: Array[StringName],
    field_name: String,
    require_non_empty: bool,
    errors: PackedStringArray
) -> void:
    if not declared:
        errors.append("%s must be explicitly declared" % field_name)
        return
    if require_non_empty and values.is_empty():
        errors.append("%s must contain at least one stable ID" % field_name)
        return
    var seen: Dictionary = {}
    for value: StringName in values:
        if not StableId.is_valid(String(value)):
            errors.append("%s must contain only stable IDs" % field_name)
        elif seen.has(value):
            errors.append("%s must not contain duplicate IDs" % field_name)
        seen[value] = true
