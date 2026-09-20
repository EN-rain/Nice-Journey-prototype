class_name PrimaryQuestProductionAuthority
extends RefCounted

const CONTENT_STATUS_PLAYTEST_PLACEHOLDER: StringName = &"playtest_placeholder"
const CONTENT_STATUS_PRODUCTION_V01: StringName = PrimaryQuestProductionV01.CONTENT_STATUS
const TENTH_WARDEN_ACTOR_ID: StringName = &"enemy:tenth_warden"


static func readiness(definition: QuestDefinition) -> Dictionary:
    if definition == null:
        return rejected_status(&"definition_missing")
    if definition.kind != QuestDefinition.KIND_PRIMARY or definition.floor_id < 1 or definition.floor_id > 10:
        return rejected_status(&"primary_floor_definition_required")

    # Floor 1 retains its separately packaged Region 3/Sigil production path.
    # Floors 2–10 now use the directly authored production-v01 primary contract.
    if definition.floor_id >= 2:
        return _production_v01_readiness(definition)
    return _legacy_floor1_readiness(definition)


static func _production_v01_readiness(definition: QuestDefinition) -> Dictionary:
    var definition_errors := definition.validate_definition()
    var contract_errors := definition.validate_production_contract()
    var production_errors := PrimaryQuestProductionV01.validate_definition(definition)
    for error: String in production_errors:
        contract_errors.append(error)

    var known_semantics := {
        "quest_id": definition.quest_id,
        "floor_id": definition.floor_id,
        "family": definition.family,
        "floor_family_allocation_status": CONTENT_STATUS_PRODUCTION_V01,
        "required_primary_objective_count": 1,
        "required_objective_id": definition.required_objective_ids[0] if not definition.required_objective_ids.is_empty() else &"",
        "acceptance_anchor_id": definition.acceptance_anchor_id,
        "turn_in_anchor_id": definition.turn_in_anchor_id,
        "leave_rule_id": definition.leave_rule_id,
        "failure_rule_id": definition.failure_rule_id,
        "retry_reset_ids": definition.retry_reset_ids.duplicate(),
        "reward_ids": definition.reward_ids.duplicate(),
        "branch_effect_ids": definition.branch_effect_ids.duplicate(),
        "completion_condition_ids": definition.completion_condition_ids.duplicate(),
    }
    if definition.floor_id == 5 or definition.floor_id == 10:
        known_semantics["floor_population_required_elite_count"] = 3
    if definition.floor_id == 10:
        known_semantics["boss_required"] = true
        known_semantics["boss_actor_id"] = TENTH_WARDEN_ACTOR_ID
        known_semantics["floor_11_permitted"] = false

    return {
        "accepted": definition_errors.is_empty() and production_errors.is_empty(),
        "reason_id": &"" if definition_errors.is_empty() and production_errors.is_empty() else &"definition_invalid",
        "production_ready": definition_errors.is_empty() and contract_errors.is_empty(),
        "known_semantics": known_semantics,
        "quest_missing_authoritative_fields": PackedStringArray(),
        "external_runtime_missing_authoritative_fields": PackedStringArray(),
        "contract_errors": contract_errors.duplicate(),
    }


static func _legacy_floor1_readiness(definition: QuestDefinition) -> Dictionary:
    var quest_missing := PackedStringArray()
    var known_semantics := {
        "quest_id": definition.quest_id,
        "floor_id": definition.floor_id,
        "family": definition.family,
        "floor_family_allocation_status": CONTENT_STATUS_PLAYTEST_PLACEHOLDER,
        "required_primary_objective_count": 1,
    }
    match definition.family:
        QuestDefinition.FAMILY_ANNIHILATION:
            quest_missing.append_array(PackedStringArray([
                "designated_required_actor_or_group_ids",
                "required_actor_reachability_or_activation_ordering",
            ]))
        QuestDefinition.FAMILY_ESCORT:
            quest_missing.append_array(PackedStringArray([
                "escort_actor_id",
                "escort_route_node_ids",
                "escort_goal_id",
                "escort_wait_follow_interaction_id",
                "escort_health_or_failure_policy",
                "escort_safe_retry_origin_id",
                "escort_save_eligibility_policy",
            ]))
        QuestDefinition.FAMILY_TOWER_DEFENSE:
            quest_missing.append_array(PackedStringArray([
                "defended_objective_id",
                "defended_objective_health_and_failure_state",
                "admitted_attacker_group_ids_by_wave",
                "wave_completion_condition",
            ]))
        _:
            return rejected_status(&"unsupported_primary_family")

    var definition_errors := definition.validate_definition()
    var contract_errors := definition.validate_production_contract()
    return {
        "accepted": definition_errors.is_empty(),
        "reason_id": &"" if definition_errors.is_empty() else &"definition_invalid",
        "production_ready": false,
        "known_semantics": known_semantics,
        "quest_missing_authoritative_fields": quest_missing,
        "external_runtime_missing_authoritative_fields": PackedStringArray(),
        "contract_errors": contract_errors.duplicate(),
    }


static func rejected_status(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "production_ready": false,
        "known_semantics": {},
        "quest_missing_authoritative_fields": PackedStringArray(),
        "external_runtime_missing_authoritative_fields": PackedStringArray(),
        "contract_errors": PackedStringArray(),
    }
