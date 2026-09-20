class_name SkillHudViewService
extends RefCounted

const REASON_INVALID_PROFILE: StringName = &"invalid_profile"
const REASON_SKILL_STATE_UNAVAILABLE: StringName = &"skill_state_unavailable"
const REASON_SKILL_STATE_INVALID: StringName = &"skill_state_invalid"


static func build_active_slots(
    profile: ProfileSnapshot,
    action_definitions_by_mechanic: Dictionary = {},
    prerequisite_events: Dictionary = {},
    action_state_machine: ActionStateMachine = null,
    rank_tuning: ActiveSkillsPlaytest = null,
    passive_runtime: PassiveSkillRuntime = null
) -> Dictionary:
    if profile == null:
        return _rejected(REASON_INVALID_PROFILE)
    if profile.skill_state.is_empty():
        return _rejected(REASON_SKILL_STATE_UNAVAILABLE)
    if not SkillLoadoutState.validate_dictionary(profile.skill_state).is_empty():
        return _rejected(REASON_SKILL_STATE_INVALID)

    var raw_active := profile.skill_state.get("active_slots", []) as Array
    var raw_ranks := profile.skill_state.get("ranks", {}) as Dictionary
    var raw_temp := profile.skill_state.get("temporary_override", {}) as Dictionary
    var temporary_slot_index := int(raw_temp.get("slot_index", -1)) if not raw_temp.is_empty() else -1
    var temporary_skill_id := StringName(String(raw_temp.get("temporary_skill_id", &""))) if not raw_temp.is_empty() else &""

    var slots: Array[Dictionary] = []
    for slot_index: int in range(SkillLoadoutState.ACTIVE_SLOT_COUNT):
        var skill_id := StringName(String(raw_active[slot_index]))
        var temporary := slot_index == temporary_slot_index and skill_id == temporary_skill_id and temporary_skill_id != &""
        var definition := SkillCatalog.get_definition(skill_id)
        var slot: Dictionary = {
            "slot_index": slot_index,
            "skill_id": skill_id,
            "temporary": temporary,
            "runtime_action_available": false,
            "display_name": String(skill_id),
            "rank": 0,
            "cost_resource": &"",
            "icon_id": &"",
            "catalog_definition_available": definition != null,
            "production_ready": false,
            "production_missing_fields": PackedStringArray(),
            "production_known_semantics": {},
            "production_runtime_action_available": false,
            "production_runtime_action_reason_id": &"",
            "cooldown_state_available": false,
            "cooldown_ticks": 0,
            "cost_amount": 0.0,
            "recovery_ticks": 0,
        }
        if definition != null:
            slot["display_name"] = definition.display_name
            slot["rank"] = int(raw_ranks.get(String(skill_id), 0))
            slot["cost_resource"] = definition.cost_resource
            slot["icon_id"] = StringName("skill_%s" % String(skill_id))
            var execution := SkillExecutionService.resolve_equipped_action(
                profile,
                slot_index,
                action_definitions_by_mechanic,
                prerequisite_events,
                rank_tuning
            )
            slot["runtime_action_available"] = bool(execution.get("accepted", false))
            slot["runtime_action_reason_id"] = StringName(execution.get("reason_id", &""))
            slot["action_id"] = StringName(execution.get("action_id", &""))
            if bool(execution.get("accepted", false)):
                var effective_action := execution.get("action_definition") as ActionDefinition
                if passive_runtime != null:
                    effective_action = passive_runtime.modify_action(effective_action)
                slot["cost_amount"] = effective_action.cost_amount
                slot["recovery_ticks"] = effective_action.recovery_ticks
            var authority := ActiveSkillProductionAuthority.readiness(skill_id)
            slot["production_ready"] = bool(authority.get("production_ready", false))
            slot["production_missing_fields"] = (authority.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray).duplicate()
            slot["production_known_semantics"] = (authority.get("known_semantics", {}) as Dictionary).duplicate(true)
            var production_execution := SkillExecutionService.resolve_equipped_production_action(
                profile,
                slot_index,
                action_definitions_by_mechanic,
                prerequisite_events
            )
            slot["production_runtime_action_available"] = bool(production_execution.get("accepted", false))
            slot["production_runtime_action_reason_id"] = StringName(production_execution.get("reason_id", &""))
            if bool(execution.get("accepted", false)) and action_state_machine != null:
                var action_id := StringName(execution.get("action_id", &""))
                slot["cooldown_state_available"] = true
                slot["cooldown_ticks"] = action_state_machine.get_cooldown_ticks(action_id)
        slots.append(slot)

    return {
        "accepted": true,
        "reason_id": &"",
        "class_id": StringName(String(profile.skill_state.get("class_id", &""))),
        "active_slots": slots,
        "runtime_action_available": slots.any(func(slot: Dictionary) -> bool: return bool(slot.get("runtime_action_available", false))),
    }


static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "class_id": &"",
        "active_slots": [],
        "runtime_action_available": false,
    }
