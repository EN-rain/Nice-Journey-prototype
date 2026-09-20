class_name TowerProductionEncounterPreparationService
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
    var plan := TowerProductionEncounterContentCatalog.build_plan(floor_state)
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
        "objective_configs": TowerProductionEncounterContentCatalog.objective_configs(floor_state, plan),
        "quest_bindings_by_actor": TowerProductionEncounterContentCatalog.quest_bindings_by_actor(floor_state, plan),
        "encounter_ids": TowerProductionEncounterContentCatalog.encounter_ids(plan),
    }


static func bind_active_objectives(profile: ProfileSnapshot, raw_configs: Variant) -> Dictionary:
    return TowerPrototypeEncounterPreparationService.bind_active_objectives(profile, raw_configs)


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
