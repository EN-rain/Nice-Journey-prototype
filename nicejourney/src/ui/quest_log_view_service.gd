class_name QuestLogViewService
extends RefCounted

const REASON_INVALID_PROFILE: StringName = &"invalid_profile"
const REASON_QUEST_STATE_INVALID: StringName = &"quest_state_invalid"
const REASON_ECONOMY_STATE_INVALID: StringName = &"economy_state_invalid"

const PROGRESS_UNBOUND: StringName = &"unbound"
const PROGRESS_ANNIHILATION: StringName = &"annihilation"
const PROGRESS_ESCORT: StringName = &"escort"
const PROGRESS_TOWER_DEFENSE: StringName = &"tower_defense"
const PROGRESS_BOSS: StringName = &"boss"


static func build_log(profile: ProfileSnapshot) -> Dictionary:
    if profile == null:
        return _rejected(REASON_INVALID_PROFILE)
    var entries: Array[Dictionary] = []
    var quest_ids := PackedStringArray()
    for raw_quest_id: Variant in profile.quest_progress.keys():
        quest_ids.append(String(raw_quest_id))
    quest_ids.sort()
    for quest_text: String in quest_ids:
        var quest_id := StringName(quest_text)
        var raw_entry: Variant = profile.quest_progress.get(quest_text, null)
        if not raw_entry is Dictionary:
            return _rejected(REASON_QUEST_STATE_INVALID)
        var validation := QuestProgressState.validate_dictionary({quest_text: raw_entry})
        if not validation.is_empty():
            return _rejected(REASON_QUEST_STATE_INVALID)
        var definition := QuestCatalog.get_definition(quest_id)
        if definition == null:
            return _rejected(REASON_QUEST_STATE_INVALID)
        var built := _build_entry(definition, (raw_entry as Dictionary).duplicate(true))
        if not bool(built.get("accepted", false)):
            return _rejected(REASON_QUEST_STATE_INVALID)
        entries.append(built)
    entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_kind := StringName(left.get("kind", &""))
        var right_kind := StringName(right.get("kind", &""))
        if left_kind != right_kind:
            return left_kind == QuestDefinition.KIND_PRIMARY
        var left_floor := int(left.get("floor_id", 0))
        var right_floor := int(right.get("floor_id", 0))
        if left_floor != right_floor:
            return left_floor < right_floor
        return String(left.get("quest_id", &"")) < String(right.get("quest_id", &""))
    )

    var pending_result := _build_pending_reward_claims(profile)
    if not bool(pending_result.get("accepted", false)):
        return _rejected(REASON_ECONOMY_STATE_INVALID)
    return {
        "accepted": true,
        "reason_id": &"",
        "entries": entries,
        "entry_count": entries.size(),
        "pending_reward_claims": (pending_result.get("entries", []) as Array).duplicate(true),
        "pending_reward_claim_count": int(pending_result.get("entry_count", 0)),
        "pending_reward_claim_action_available": false,
        "pending_reward_claim_requires_outside_combat": true,
    }


static func _build_entry(definition: QuestDefinition, entry: Dictionary) -> Dictionary:
    var state_id := StringName(String(entry.get("state", &"")))
    var stage_id := StringName(String(entry.get("stage_id", &"")))
    var prerequisite_authoring_available := _declared_id_array_available(
        definition.prerequisites_declared,
        definition.prerequisite_ids,
        false
    )
    var acceptance_anchor_available := _declared_id_available(
        definition.acceptance_anchor_declared,
        definition.acceptance_anchor_id,
        false
    )
    var turn_in_authoring_available := _declared_id_available(
        definition.turn_in_anchor_declared,
        definition.turn_in_anchor_id,
        true
    )
    var leave_policy_available := _declared_id_available(
        definition.leave_rule_declared,
        definition.leave_rule_id,
        false
    )
    var failure_policy_available := _declared_id_available(
        definition.failure_rule_declared,
        definition.failure_rule_id,
        false
    )
    var retry_policy_available := _declared_id_array_available(
        definition.retry_reset_declared,
        definition.retry_reset_ids,
        true
    )
    var reward_authoring_available := _declared_id_array_available(
        definition.rewards_declared,
        definition.reward_ids,
        false
    )
    var branch_authoring_available := _declared_id_array_available(
        definition.branch_effects_declared,
        definition.branch_effect_ids,
        false
    )
    var completion_authoring_available := _declared_id_array_available(
        definition.completion_conditions_declared,
        definition.completion_condition_ids,
        true
    )
    var result: Dictionary = {
        "accepted": true,
        "quest_id": definition.quest_id,
        "kind": definition.kind,
        "family": definition.family,
        "floor_id": definition.floor_id,
        "scope_id": definition.scope_id,
        "stage_id": stage_id,
        "quest_state": state_id,
        "playtest_placeholder": definition.playtest_placeholder,
        "prerequisite_authoring_available": prerequisite_authoring_available,
        "acceptance_conditions_available": prerequisite_authoring_available,
        "acceptance_anchor_available": acceptance_anchor_available,
        "turn_in_authoring_available": turn_in_authoring_available,
        "turn_in_anchor_available": turn_in_authoring_available and definition.turn_in_anchor_id != &"",
        "leave_policy_available": leave_policy_available,
        "failure_policy_available": failure_policy_available,
        "retry_policy_available": retry_policy_available,
        "reward_authoring_available": reward_authoring_available,
        "branch_effect_authoring_available": branch_authoring_available,
        "completion_authoring_available": completion_authoring_available,
        "last_leave_reason_id": StringName(String(entry.get("leave_reason_id", &""))),
        "progress_kind": PROGRESS_UNBOUND,
        "current_required_step_available": stage_id != &"",
        "completed_outcome_available": state_id in [QuestProgressState.STATE_OBJECTIVES_COMPLETE, QuestProgressState.STATE_COMPLETED],
        "completed_outcome_state": state_id if state_id in [QuestProgressState.STATE_OBJECTIVES_COMPLETE, QuestProgressState.STATE_COMPLETED] else &"",
        "failure_reason_id": &"",
    }
    if prerequisite_authoring_available:
        result["prerequisite_ids"] = definition.prerequisite_ids.duplicate()
        # Backward-compatible alias for older Quest Log consumers.
        result["acceptance_condition_ids"] = definition.prerequisite_ids.duplicate()
    if acceptance_anchor_available:
        result["acceptance_anchor_id"] = definition.acceptance_anchor_id
    if turn_in_authoring_available and definition.turn_in_anchor_id != &"":
        result["turn_in_anchor_id"] = definition.turn_in_anchor_id
    if leave_policy_available:
        result["leave_rule_id"] = definition.leave_rule_id
    if failure_policy_available:
        result["failure_rule_id"] = definition.failure_rule_id
    if retry_policy_available:
        result["retry_reset_ids"] = definition.retry_reset_ids.duplicate()
    if reward_authoring_available:
        result["reward_ids"] = definition.reward_ids.duplicate()
    if branch_authoring_available:
        result["branch_effect_ids"] = definition.branch_effect_ids.duplicate()
    if completion_authoring_available:
        result["completion_condition_ids"] = definition.completion_condition_ids.duplicate()

    var raw_objective: Variant = entry.get("objective_state", {})
    if not raw_objective is Dictionary:
        return {"accepted": false}
    var objective := (raw_objective as Dictionary).duplicate(true)
    if objective.is_empty():
        return result

    if definition.quest_id == Floor10PrimaryBossObjectiveService.QUEST_ID and objective.has("boss_actor_id"):
        var boss_actor_id := StringName(String(objective.get("boss_actor_id", &"")))
        if boss_actor_id != Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID or typeof(objective.get("boss_defeated", null)) != TYPE_BOOL:
            return {"accepted": false}
        result["progress_kind"] = PROGRESS_BOSS
        result["boss_actor_id"] = boss_actor_id
        result["boss_defeated"] = bool(objective["boss_defeated"])
        return result

    match definition.family:
        QuestDefinition.FAMILY_ANNIHILATION:
            if not AnnihilationObjectiveState.validate_dictionary(objective).is_empty():
                return {"accepted": false}
            var required := objective.get("required_actor_ids", []) as Array
            var defeated := objective.get("defeated_actor_ids", []) as Array
            result["progress_kind"] = PROGRESS_ANNIHILATION
            result["required_count"] = required.size()
            result["defeated_count"] = defeated.size()
            result["remaining_count"] = maxi(0, required.size() - defeated.size())
        QuestDefinition.FAMILY_ESCORT:
            if not EscortObjectiveState.validate_dictionary(objective).is_empty():
                return {"accepted": false}
            var route := objective.get("route_node_ids", []) as Array
            result["progress_kind"] = PROGRESS_ESCORT
            result["route_count"] = route.size()
            result["next_route_index"] = int(objective.get("next_route_index", 0))
            result["wait_requested"] = bool(objective.get("wait_requested", false))
            result["goal_reached"] = bool(objective.get("goal_reached", false))
            result["failed"] = bool(objective.get("failed", false))
            result["failure_reason_id"] = StringName(String(objective.get("failure_reason_id", &"")))
        QuestDefinition.FAMILY_TOWER_DEFENSE:
            if not TowerDefenseObjectiveState.validate_dictionary(objective).is_empty():
                return {"accepted": false}
            var required_waves := objective.get("required_actor_ids_by_wave", {}) as Dictionary
            var defeated_waves := objective.get("defeated_actor_ids_by_wave", {}) as Dictionary
            var completed_wave_count := 0
            for raw_wave_id: Variant in required_waves.keys():
                var wave_id := String(raw_wave_id)
                var required_ids := required_waves.get(wave_id, []) as Array
                var defeated_ids := defeated_waves.get(wave_id, []) as Array
                if not required_ids.is_empty() and defeated_ids.size() == required_ids.size():
                    completed_wave_count += 1
            result["progress_kind"] = PROGRESS_TOWER_DEFENSE
            result["wave_count"] = required_waves.size()
            result["completed_wave_count"] = completed_wave_count
            result["objective_current_hp"] = int(objective.get("objective_current_hp", 0))
            result["objective_max_hp"] = int(objective.get("objective_max_hp", 0))
            result["failed"] = bool(objective.get("failed", false))
        _:
            return {"accepted": false}
    return result


static func _declared_id_available(declared: bool, value: StringName, allow_empty: bool) -> bool:
    if not declared:
        return false
    if value == &"":
        return allow_empty
    return StableId.is_valid(String(value))


static func _declared_id_array_available(declared: bool, values: Array[StringName], require_non_empty: bool) -> bool:
    if not declared or (require_non_empty and values.is_empty()):
        return false
    var seen: Dictionary = {}
    for value: StringName in values:
        if not StableId.is_valid(String(value)) or seen.has(value):
            return false
        seen[value] = true
    return true


static func _build_pending_reward_claims(profile: ProfileSnapshot) -> Dictionary:
    var economy := EconomyState.new()
    if not profile.economy_state.is_empty():
        var economy_errors := economy.load_dictionary(profile.economy_state)
        if not economy_errors.is_empty():
            return {"accepted": false}
    var claim_ids := PackedStringArray()
    for raw_claim_id: Variant in economy.pending_reward_claims.keys():
        claim_ids.append(String(raw_claim_id))
    claim_ids.sort()
    var entries: Array[Dictionary] = []
    for claim_text: String in claim_ids:
        var claim_id := StringName(claim_text)
        var pending := economy.get_pending_reward(claim_id)
        if pending.is_empty():
            return {"accepted": false}
        var rewards: Array[Dictionary] = []
        var total_quantity := 0
        for raw_reward: Variant in pending.get("normal_rewards", []) as Array:
            if not raw_reward is Dictionary:
                return {"accepted": false}
            var reward := raw_reward as Dictionary
            var quantity := int(reward.get("quantity", 0))
            total_quantity += quantity
            rewards.append({
                "item_instance_id": StringName(String(reward.get("item_instance_id", &""))),
                "definition_id": StringName(String(reward.get("definition_id", &""))),
                "quantity": quantity,
                "stackable": bool(reward.get("stackable", false)),
            })
        entries.append({
            "claim_id": claim_id,
            "source_id": StringName(String(pending.get("source_id", &""))),
            "normal_reward_count": rewards.size(),
            "normal_reward_quantity_total": total_quantity,
            "normal_rewards": rewards,
            "message_id": &"reward_waiting_inventory_full",
            "claim_action_available": false,
            "requires_outside_combat": true,
        })
    return {
        "accepted": true,
        "entries": entries,
        "entry_count": entries.size(),
    }


static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "entries": [],
        "entry_count": 0,
        "pending_reward_claims": [],
        "pending_reward_claim_count": 0,
        "pending_reward_claim_action_available": false,
        "pending_reward_claim_requires_outside_combat": true,
    }
