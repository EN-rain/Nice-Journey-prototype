class_name LevelXpRewardDefinition
extends Resource

const FAMILY_MAIN_QUEST: StringName = &"main_quest"
const FAMILY_SIDE_QUEST: StringName = &"side_quest"
const FAMILY_BOSS_COMPLETION: StringName = &"boss_completion"
const FAMILY_COMBAT_ENCOUNTER: StringName = &"combat_encounter"
const FAMILY_ELITE: StringName = &"elite"
const FAMILY_EXPLORATION_OBJECTIVE: StringName = &"exploration_objective"

const DELIVERY_RAW_XP: StringName = &"raw_xp"
const DELIVERY_REWARD_ABSTRACTION: StringName = &"reward_abstraction"

const PRIMARY_FAMILIES: Array[StringName] = [
    FAMILY_MAIN_QUEST,
    FAMILY_SIDE_QUEST,
    FAMILY_BOSS_COMPLETION,
]
const SECONDARY_FAMILIES: Array[StringName] = [
    FAMILY_COMBAT_ENCOUNTER,
    FAMILY_ELITE,
    FAMILY_EXPLORATION_OBJECTIVE,
]
const SUPPORTED_FAMILIES: Array[StringName] = [
    FAMILY_MAIN_QUEST,
    FAMILY_SIDE_QUEST,
    FAMILY_BOSS_COMPLETION,
    FAMILY_COMBAT_ENCOUNTER,
    FAMILY_ELITE,
    FAMILY_EXPLORATION_OBJECTIVE,
]
const SUPPORTED_DELIVERY: Array[StringName] = [
    DELIVERY_RAW_XP,
    DELIVERY_REWARD_ABSTRACTION,
]

@export var definition_id: StringName = &""
@export var source_id: StringName = &""
@export var claim_id: StringName = &""
@export var source_family: StringName = &""
@export var delivery_kind: StringName = &""
@export_range(0, 2147483647, 1) var xp_amount: int = 0
@export var reward_abstraction_id: StringName = &""
@export var explicitly_authored_exploration_objective: bool = false


func validate_definition() -> PackedStringArray:
    var errors := PackedStringArray()
    _require_stable_id(errors, definition_id, "definition_id")
    _require_stable_id(errors, source_id, "source_id")
    _require_stable_id(errors, claim_id, "claim_id")

    if not SUPPORTED_FAMILIES.has(source_family):
        errors.append("source_family must be an approved XP source family")
    if not SUPPORTED_DELIVERY.has(delivery_kind):
        errors.append("delivery_kind must explicitly choose raw_xp or reward_abstraction")

    if delivery_kind == DELIVERY_RAW_XP:
        if xp_amount <= 0:
            errors.append("raw_xp delivery requires a positive authored xp_amount")
        if reward_abstraction_id != &"":
            errors.append("raw_xp delivery cannot also declare reward_abstraction_id")
    elif delivery_kind == DELIVERY_REWARD_ABSTRACTION:
        if xp_amount != 0:
            errors.append("reward_abstraction delivery cannot also declare raw xp_amount")
        _require_stable_id(errors, reward_abstraction_id, "reward_abstraction_id")

    if source_family == FAMILY_EXPLORATION_OBJECTIVE and not explicitly_authored_exploration_objective:
        errors.append("exploration XP is permitted only for an explicitly authored exploration objective")
    elif source_family != FAMILY_EXPLORATION_OBJECTIVE and explicitly_authored_exploration_objective:
        errors.append("explicitly_authored_exploration_objective is only valid for exploration_objective sources")
    return errors


func is_primary_source() -> bool:
    return validate_definition().is_empty() and PRIMARY_FAMILIES.has(source_family)


func is_secondary_source() -> bool:
    return validate_definition().is_empty() and SECONDARY_FAMILIES.has(source_family)


func make_award_request() -> Dictionary:
    var errors := validate_definition()
    if not errors.is_empty():
        return {
            "accepted": false,
            "errors": errors.duplicate(),
            "source_id": source_id,
            "claim_id": claim_id,
            "delivery_kind": delivery_kind,
        }
    return {
        "accepted": true,
        "errors": PackedStringArray(),
        "definition_id": definition_id,
        "source_id": source_id,
        "claim_id": claim_id,
        "source_family": source_family,
        "delivery_kind": delivery_kind,
        "xp_amount": xp_amount,
        "reward_abstraction_id": reward_abstraction_id,
    }


func _require_stable_id(errors: PackedStringArray, value: StringName, field_name: String) -> void:
    if not StableId.is_valid(String(value)):
        errors.append("%s must be a stable ID" % field_name)
