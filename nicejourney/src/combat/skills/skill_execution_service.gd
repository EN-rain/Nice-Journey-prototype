class_name SkillExecutionService
extends RefCounted

const REASON_INVALID_PROFILE: StringName = &"invalid_profile"
const REASON_SKILL_STATE_INVALID: StringName = &"skill_state_invalid"
const REASON_SLOT_OUT_OF_RANGE: StringName = &"slot_out_of_range"
const REASON_TEMPORARY_SKILL_UNAUTHORED: StringName = &"temporary_skill_unauthored"
const REASON_SKILL_NOT_ACTIVE: StringName = &"skill_not_active"
const REASON_PREREQUISITE_STATE_REQUIRED: StringName = &"prerequisite_state_required"
const REASON_PREREQUISITE_UNSATISFIED: StringName = &"prerequisite_unsatisfied"
const REASON_ACTION_DEFINITION_REQUIRED: StringName = &"action_definition_required"
const REASON_ACTION_DEFINITION_INVALID: StringName = &"action_definition_invalid"
const REASON_ACTION_DEFINITION_MISMATCH: StringName = &"action_definition_mismatch"
const REASON_RANK_TUNING_UNAVAILABLE: StringName = &"rank_tuning_unavailable"
const REASON_PRODUCTION_AUTHORING_INCOMPLETE: StringName = &"production_authoring_incomplete"
const REASON_PRODUCTION_AUTHORITY_INCOMPLETE: StringName = &"production_authority_incomplete"
const REASON_ACTION_REQUEST_UNAVAILABLE: StringName = &"action_request_unavailable"
const REASON_ACTION_REQUEST_REJECTED: StringName = &"action_request_rejected"


static func resolve_equipped_action(
    profile: ProfileSnapshot,
    slot_index: int,
    action_definitions_by_mechanic: Dictionary,
    prerequisite_events: Dictionary = {},
    rank_tuning: ActiveSkillsPlaytest = null
) -> Dictionary:
    if profile == null:
        return _rejected(REASON_INVALID_PROFILE, slot_index)
    if profile.skill_state.is_empty() or not SkillLoadoutState.validate_dictionary(profile.skill_state).is_empty():
        return _rejected(REASON_SKILL_STATE_INVALID, slot_index)
    if slot_index < 0 or slot_index >= SkillLoadoutState.ACTIVE_SLOT_COUNT:
        return _rejected(REASON_SLOT_OUT_OF_RANGE, slot_index)

    var state := SkillLoadoutState.new()
    if not state.load_dictionary(profile.skill_state).is_empty():
        return _rejected(REASON_SKILL_STATE_INVALID, slot_index)
    var skill_id := state.active_slots[slot_index]
    var definition := SkillCatalog.get_definition(skill_id)
    if definition == null:
        return _rejected(REASON_TEMPORARY_SKILL_UNAUTHORED, slot_index, skill_id)
    if definition.kind != SkillDefinition.KIND_ACTIVE or definition.class_id != state.class_id or not state.is_learned(skill_id):
        return _rejected(REASON_SKILL_NOT_ACTIVE, slot_index, skill_id)

    if definition.prerequisite_event_id != &"":
        var prerequisite_key := String(definition.prerequisite_event_id)
        if not prerequisite_events.has(definition.prerequisite_event_id) and not prerequisite_events.has(prerequisite_key):
            return _rejected(REASON_PREREQUISITE_STATE_REQUIRED, slot_index, skill_id, definition.mechanic_id)
        var satisfied: Variant = prerequisite_events.get(definition.prerequisite_event_id, prerequisite_events.get(prerequisite_key, false))
        if not satisfied is bool or not bool(satisfied):
            return _rejected(REASON_PREREQUISITE_UNSATISFIED, slot_index, skill_id, definition.mechanic_id)

    var raw_action: Variant = action_definitions_by_mechanic.get(
        definition.mechanic_id,
        action_definitions_by_mechanic.get(String(definition.mechanic_id), null)
    )
    if not raw_action is ActionDefinition:
        return _rejected(REASON_ACTION_DEFINITION_REQUIRED, slot_index, skill_id, definition.mechanic_id)
    var action := raw_action as ActionDefinition
    if not action.validate_definition().is_empty() or not StableId.is_valid(String(action.action_id)):
        return _rejected(REASON_ACTION_DEFINITION_INVALID, slot_index, skill_id, definition.mechanic_id)
    if action.cost_resource != definition.cost_resource:
        return _rejected(REASON_ACTION_DEFINITION_MISMATCH, slot_index, skill_id, definition.mechanic_id)

    var rank := state.get_rank(skill_id)
    if rank_tuning != null:
        if not rank_tuning.validate_content().is_empty():
            return _rejected(REASON_RANK_TUNING_UNAVAILABLE, slot_index, skill_id, definition.mechanic_id)
        var ranked_action := rank_tuning.action_for_rank(skill_id, rank)
        if ranked_action == null or ranked_action.action_id != action.action_id or ranked_action.cost_resource != action.cost_resource:
            return _rejected(REASON_RANK_TUNING_UNAVAILABLE, slot_index, skill_id, definition.mechanic_id)
        action = ranked_action

    return {
        "accepted": true,
        "reason_id": &"",
        "slot_index": slot_index,
        "skill_id": skill_id,
        "mechanic_id": definition.mechanic_id,
        "rank": rank,
        "action_definition": action,
        "action_id": action.action_id,
    }


static func resolve_equipped_production_action(
    profile: ProfileSnapshot,
    slot_index: int,
    action_definitions_by_mechanic: Dictionary,
    prerequisite_events: Dictionary = {}
) -> Dictionary:
    var resolved := resolve_equipped_action(profile, slot_index, action_definitions_by_mechanic, prerequisite_events)
    if not bool(resolved.get("accepted", false)):
        return resolved
    var action := resolved.get("action_definition") as ActionDefinition
    var mechanic_id := StringName(resolved.get("mechanic_id", &""))
    var skill_id := StringName(resolved.get("skill_id", &""))
    var authoring_errors := ActiveSkillProductionAuthority.validate_action_contract(skill_id, action)
    if not authoring_errors.is_empty():
        var rejected := _rejected(
            REASON_PRODUCTION_AUTHORING_INCOMPLETE,
            slot_index,
            skill_id,
            mechanic_id
        )
        rejected["production_authoring_errors"] = authoring_errors.duplicate()
        return rejected
    var authority := ActiveSkillProductionAuthority.readiness(skill_id)
    if not bool(authority.get("accepted", false)) or not bool(authority.get("production_ready", false)):
        var rejected := _rejected(
            REASON_PRODUCTION_AUTHORITY_INCOMPLETE,
            slot_index,
            skill_id,
            mechanic_id
        )
        rejected["production_missing_fields"] = (authority.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray).duplicate()
        rejected["production_known_semantics"] = (authority.get("known_semantics", {}) as Dictionary).duplicate(true)
        return rejected
    var result := resolved.duplicate(true)
    result["production_authoring_manifest"] = action.production_skill_authoring_manifest(mechanic_id).duplicate(true)
    result["production_missing_fields"] = PackedStringArray()
    result["production_known_semantics"] = (authority.get("known_semantics", {}) as Dictionary).duplicate(true)
    return result


static func request_active(
    profile: ProfileSnapshot,
    slot_index: int,
    action_definitions_by_mechanic: Dictionary,
    action_request: Callable,
    input_action_id: StringName,
    aim_sample: Vector2 = Vector2.ZERO,
    prerequisite_events: Dictionary = {},
    rank_tuning: ActiveSkillsPlaytest = null
) -> Dictionary:
    var resolved := resolve_equipped_action(profile, slot_index, action_definitions_by_mechanic, prerequisite_events, rank_tuning)
    if not bool(resolved.get("accepted", false)):
        return resolved
    if not action_request.is_valid() or not StableId.is_valid(String(input_action_id)):
        return _rejected(
            REASON_ACTION_REQUEST_UNAVAILABLE,
            slot_index,
            StringName(resolved.get("skill_id", &"")),
            StringName(resolved.get("mechanic_id", &""))
        )
    var accepted: Variant = action_request.call(input_action_id, resolved.get("action_definition") as ActionDefinition, aim_sample)
    if not accepted is bool or not bool(accepted):
        return _rejected(
            REASON_ACTION_REQUEST_REJECTED,
            slot_index,
            StringName(resolved.get("skill_id", &"")),
            StringName(resolved.get("mechanic_id", &""))
        )
    var result := resolved.duplicate(true)
    result["input_action_id"] = input_action_id
    return result


static func request_active_production(
    profile: ProfileSnapshot,
    slot_index: int,
    action_definitions_by_mechanic: Dictionary,
    action_request: Callable,
    input_action_id: StringName,
    aim_sample: Vector2 = Vector2.ZERO,
    prerequisite_events: Dictionary = {}
) -> Dictionary:
    var resolved := resolve_equipped_production_action(profile, slot_index, action_definitions_by_mechanic, prerequisite_events)
    if not bool(resolved.get("accepted", false)):
        return resolved
    if not action_request.is_valid() or not StableId.is_valid(String(input_action_id)):
        return _rejected(
            REASON_ACTION_REQUEST_UNAVAILABLE,
            slot_index,
            StringName(resolved.get("skill_id", &"")),
            StringName(resolved.get("mechanic_id", &""))
        )
    var accepted: Variant = action_request.call(input_action_id, resolved.get("action_definition") as ActionDefinition, aim_sample)
    if not accepted is bool or not bool(accepted):
        return _rejected(
            REASON_ACTION_REQUEST_REJECTED,
            slot_index,
            StringName(resolved.get("skill_id", &"")),
            StringName(resolved.get("mechanic_id", &""))
        )
    var result := resolved.duplicate(true)
    result["input_action_id"] = input_action_id
    return result


static func _rejected(
    reason_id: StringName,
    slot_index: int,
    skill_id: StringName = &"",
    mechanic_id: StringName = &""
) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "slot_index": slot_index,
        "skill_id": skill_id,
        "mechanic_id": mechanic_id,
        "action_definition": null,
        "action_id": &"",
        "production_authoring_errors": PackedStringArray(),
        "production_missing_fields": PackedStringArray(),
        "production_known_semantics": {},
    }
