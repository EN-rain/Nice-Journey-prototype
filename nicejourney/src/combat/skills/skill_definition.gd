class_name SkillDefinition
extends Resource

const KIND_ACTIVE: StringName = &"active"
const KIND_PASSIVE: StringName = &"passive"

@export var skill_id: StringName = &""
@export var class_id: StringName = &""
@export var kind: StringName = &""
@export var display_name: String = ""
@export var mechanic_id: StringName = &""
@export var starting_grant: bool = false
@export_range(1, 3, 1) var max_rank: int = 3
@export var cost_resource: StringName = &""
@export var prerequisite_event_id: StringName = &""


func validate_definition() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if not StableId.is_valid(String(skill_id)):
        errors.append("skill_id must be a stable ID")
    if not ["melee", "ranged", "mage"].has(String(class_id)):
        errors.append("class_id must be melee, ranged, or mage")
    if kind != KIND_ACTIVE and kind != KIND_PASSIVE:
        errors.append("kind must be active or passive")
    if display_name.strip_edges().is_empty():
        errors.append("display_name is required")
    if not StableId.is_valid(String(mechanic_id)):
        errors.append("mechanic_id must be a stable ID")
    if max_rank != 3:
        errors.append("prototype skills must have exactly three ranks")
    if not String(cost_resource).is_empty() and not StableId.is_valid(String(cost_resource)):
        errors.append("cost_resource must be empty or a stable ID")
    if not String(prerequisite_event_id).is_empty() and not StableId.is_valid(String(prerequisite_event_id)):
        errors.append("prerequisite_event_id must be empty or a stable ID")
    if kind == KIND_PASSIVE and (cost_resource != &"" or prerequisite_event_id != &""):
        errors.append("passive skills cannot own action resource/prerequisite-event data")
    return errors
