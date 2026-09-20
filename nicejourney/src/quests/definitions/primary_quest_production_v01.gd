class_name PrimaryQuestProductionV01
extends RefCounted

const CONTENT_STATUS: StringName = &"production_v01"
const LEAVE_RULE_ID: StringName = &"leave:primary_floor_attempt_block_v01"
const RETRY_RESET_ID: StringName = &"reset:latest_safe_attempt_v01"
const COMPLETION_OBJECTIVE_ID: StringName = &"completion:required_primary_objective_v01"
const COMPLETION_TURN_IN_ID: StringName = &"completion:quest_hall_turn_in_v01"
const REWARD_NEXT_FLOOR_ID: StringName = &"reward:next_floor_unlock_v01"
const REWARD_MILESTONE_ID: StringName = &"reward:prototype_milestone_clear_v01"

const FAILURE_ANNIHILATION: StringName = &"failure:player_defeat_attempt_rollback_v01"
const FAILURE_ESCORT: StringName = &"failure:escort_actor_defeat_v01"
const FAILURE_DEFENSE: StringName = &"failure:defended_objective_destroyed_v01"
const FAILURE_BOSS: StringName = &"failure:tenth_warden_failed_attempt_v01"


static func apply(definition: QuestDefinition) -> QuestDefinition:
    if definition == null or definition.kind != QuestDefinition.KIND_PRIMARY:
        return definition
    if definition.floor_id < 2 or definition.floor_id > 10:
        return definition

    var floor_id := definition.floor_id
    definition.playtest_placeholder = false

    definition.prerequisites_declared = true
    definition.prerequisite_ids = [unlocked_fact_id(floor_id)]

    definition.required_objectives_declared = true
    definition.required_objective_ids = [required_objective_id(floor_id, definition.family)]

    definition.optional_objectives_declared = true
    definition.optional_objective_ids = []

    definition.instance_bindings_declared = true
    definition.instance_binding_ids = [
        StringName("binding:primary_floor_%d_committed_instance_v01" % floor_id)
    ]

    definition.leave_rule_declared = true
    definition.leave_rule_id = LEAVE_RULE_ID

    definition.failure_rule_declared = true
    definition.failure_rule_id = failure_rule_id(floor_id, definition.family)

    definition.retry_reset_declared = true
    definition.retry_reset_ids = [RETRY_RESET_ID]

    definition.rewards_declared = true
    definition.reward_ids = [
        REWARD_MILESTONE_ID if floor_id == 10 else REWARD_NEXT_FLOOR_ID
    ]

    definition.branch_effects_declared = true
    definition.branch_effect_ids = []

    definition.completion_conditions_declared = true
    definition.completion_condition_ids = [
        COMPLETION_OBJECTIVE_ID,
        COMPLETION_TURN_IN_ID,
    ]
    return definition


static func unlocked_fact_id(floor_id: int) -> StringName:
    return StringName("tower_floor_%d_unlocked" % floor_id)


static func required_objective_id(floor_id: int, family: StringName) -> StringName:
    if floor_id == 10:
        return &"objective:primary_floor_10_tenth_warden"
    match family:
        QuestDefinition.FAMILY_ESCORT:
            return StringName("objective:primary_floor_%d_escort" % floor_id)
        QuestDefinition.FAMILY_TOWER_DEFENSE:
            return StringName("objective:primary_floor_%d_defense" % floor_id)
        QuestDefinition.FAMILY_ANNIHILATION:
            return StringName("objective:primary_floor_%d_annihilation" % floor_id)
        _:
            return &""


static func failure_rule_id(floor_id: int, family: StringName) -> StringName:
    if floor_id == 10:
        return FAILURE_BOSS
    match family:
        QuestDefinition.FAMILY_ESCORT:
            return FAILURE_ESCORT
        QuestDefinition.FAMILY_TOWER_DEFENSE:
            return FAILURE_DEFENSE
        QuestDefinition.FAMILY_ANNIHILATION:
            return FAILURE_ANNIHILATION
        _:
            return &""


static func satisfied_prerequisite_facts(profile: ProfileSnapshot, definition: QuestDefinition) -> Array[StringName]:
    var result: Array[StringName] = []
    if profile == null or definition == null:
        return result
    for fact_id: StringName in definition.prerequisite_ids:
        if bool(profile.permanent_flags.get(String(fact_id), false)):
            result.append(fact_id)
    return result


static func validate_definition(definition: QuestDefinition) -> PackedStringArray:
    var errors := PackedStringArray()
    if definition == null or definition.kind != QuestDefinition.KIND_PRIMARY:
        errors.append("production-v01 requires a primary quest definition")
        return errors
    if definition.floor_id < 2 or definition.floor_id > 10:
        errors.append("production-v01 owns Floors 2 through 10")
        return errors
    if definition.playtest_placeholder:
        errors.append("production-v01 primary cannot remain playtest_placeholder")
    if definition.prerequisite_ids != [unlocked_fact_id(definition.floor_id)]:
        errors.append("production-v01 prerequisite must be the destination floor unlock fact")
    if definition.required_objective_ids != [required_objective_id(definition.floor_id, definition.family)]:
        errors.append("production-v01 required objective identity mismatch")
    if not definition.optional_objective_ids.is_empty():
        errors.append("production-v01 primary optional objective set must be empty")
    if definition.leave_rule_id != LEAVE_RULE_ID:
        errors.append("production-v01 leave rule mismatch")
    if definition.failure_rule_id != failure_rule_id(definition.floor_id, definition.family):
        errors.append("production-v01 failure rule mismatch")
    if definition.retry_reset_ids != [RETRY_RESET_ID]:
        errors.append("production-v01 retry reset mismatch")
    var expected_reward := REWARD_MILESTONE_ID if definition.floor_id == 10 else REWARD_NEXT_FLOOR_ID
    if definition.reward_ids != [expected_reward]:
        errors.append("production-v01 progression reward mismatch")
    if not definition.branch_effect_ids.is_empty():
        errors.append("production-v01 primary branch effects must be empty")
    if definition.completion_condition_ids != [COMPLETION_OBJECTIVE_ID, COMPLETION_TURN_IN_ID]:
        errors.append("production-v01 completion conditions mismatch")
    return errors
