class_name TowerPrototypeEncounterPreparationService
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_PLAN_FAILED: StringName = &"plan_failed"
const REASON_ENEMY_STATE_FAILED: StringName = &"enemy_state_failed"
const REASON_OBJECTIVE_BIND_FAILED: StringName = &"objective_bind_failed"

static func prepare(
    profile: ProfileSnapshot,
    floor_state: FloorInstanceState,
    tuning: TowerPrototypeEnemyRuntimeTuning
) -> Dictionary:
    if profile == null or floor_state == null or tuning == null:
        return _rejected(REASON_INVALID_CONTEXT)
    if not FloorInstanceState.validate_dictionary(floor_state.to_dictionary()).is_empty():
        return _rejected(REASON_INVALID_CONTEXT)
    var plan := TowerPrototypeEncounterContentCatalog.build_plan(floor_state)
    if plan.is_empty():
        return _rejected(REASON_PLAN_FAILED)
    var enemy_states := TowerPrototypeEnemyRuntimeFactory.build_states(floor_state, plan, tuning)
    if enemy_states.is_empty() and not (plan.get("placements", []) as Array).is_empty():
        return _rejected(REASON_ENEMY_STATE_FAILED)
    return {
        "accepted": true,
        "reason_id": &"",
        "floor_id": floor_state.floor_id,
        "plan": plan,
        "enemy_states": enemy_states,
        "objective_configs": TowerPrototypeEncounterContentCatalog.objective_configs(floor_state, plan),
        "quest_bindings_by_actor": TowerPrototypeEncounterContentCatalog.quest_bindings_by_actor(floor_state, plan),
        "encounter_ids": TowerPrototypeEncounterContentCatalog.encounter_ids(plan),
    }

static func bind_active_objectives(profile: ProfileSnapshot, raw_configs: Variant) -> Dictionary:
    if profile == null or not raw_configs is Dictionary:
        return _rejected(REASON_INVALID_CONTEXT)
    var configs := raw_configs as Dictionary
    var before := profile.quest_progress.duplicate(true)
    var bound_ids: Array[StringName] = []
    var already_bound_ids: Array[StringName] = []
    var inactive_ids: Array[StringName] = []
    var quest_ids: Array = configs.keys()
    quest_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    for raw_quest_id: Variant in quest_ids:
        var quest_id := StringName(String(raw_quest_id))
        var raw_entry: Variant = profile.quest_progress.get(String(quest_id), null)
        if not raw_entry is Dictionary:
            inactive_ids.append(quest_id)
            continue
        var entry := raw_entry as Dictionary
        if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_ACTIVE:
            inactive_ids.append(quest_id)
            continue
        var existing_state: Variant = entry.get("objective_state", {})
        if existing_state is Dictionary and not (existing_state as Dictionary).is_empty():
            already_bound_ids.append(quest_id)
            continue
        var config_variant: Variant = configs[raw_quest_id]
        if not config_variant is Dictionary:
            profile.quest_progress = before
            return _bind_rejected(quest_id)
        var result := QuestFamilyObjectiveService.bind(profile, quest_id, config_variant as Dictionary)
        if not bool(result.get("accepted", false)):
            profile.quest_progress = before
            return _bind_rejected(quest_id, StringName(result.get("reason_id", &"")))
        bound_ids.append(quest_id)
    return {
        "accepted": true,
        "reason_id": &"",
        "bound_quest_ids": bound_ids,
        "already_bound_quest_ids": already_bound_ids,
        "inactive_quest_ids": inactive_ids,
    }

static func _bind_rejected(quest_id: StringName, bind_reason_id: StringName = &"") -> Dictionary:
    var result := _rejected(REASON_OBJECTIVE_BIND_FAILED)
    result["quest_id"] = quest_id
    result["bind_reason_id"] = bind_reason_id
    return result

static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "floor_id": 0,
        "plan": {},
        "enemy_states": {},
        "objective_configs": {},
        "quest_bindings_by_actor": {},
        "encounter_ids": [],
    }
