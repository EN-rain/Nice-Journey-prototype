class_name QuestTrackerViewService
extends RefCounted

const REASON_INVALID_PROFILE: StringName = &"invalid_profile"
const REASON_NO_ACTIVE_TOWER_FLOOR: StringName = &"no_active_tower_floor"
const REASON_QUEST_NOT_TRACKABLE: StringName = &"quest_not_trackable"
const REASON_OBJECTIVE_INVALID: StringName = &"objective_invalid"

const PROGRESS_UNBOUND: StringName = &"unbound"
const PROGRESS_ANNIHILATION: StringName = &"annihilation"
const PROGRESS_ESCORT: StringName = &"escort"
const PROGRESS_TOWER_DEFENSE: StringName = &"tower_defense"
const PROGRESS_BOSS: StringName = &"boss"
const PROGRESS_OBJECTIVES_COMPLETE: StringName = &"objectives_complete"


static func build_current_tower_primary(profile: ProfileSnapshot, floor_id: int) -> Dictionary:
    if profile == null:
        return _unavailable(REASON_INVALID_PROFILE, floor_id)
    if floor_id < 1 or floor_id > QuestCatalog.FLOOR_PRIMARY_IDS.size():
        return _unavailable(REASON_NO_ACTIVE_TOWER_FLOOR, floor_id)

    var quest_id: StringName = QuestCatalog.FLOOR_PRIMARY_IDS[floor_id - 1]
    var definition := QuestCatalog.get_definition(quest_id)
    if definition == null or definition.kind != QuestDefinition.KIND_PRIMARY or definition.floor_id != floor_id:
        return _unavailable(REASON_QUEST_NOT_TRACKABLE, floor_id)

    var raw_entry: Variant = profile.quest_progress.get(String(quest_id), null)
    if not raw_entry is Dictionary:
        return _unavailable(REASON_QUEST_NOT_TRACKABLE, floor_id)
    var entry := (raw_entry as Dictionary).duplicate(true)
    var state_id := StringName(String(entry.get("state", &"")))
    if state_id not in [QuestProgressState.STATE_ACTIVE, QuestProgressState.STATE_OBJECTIVES_COMPLETE]:
        return _unavailable(REASON_QUEST_NOT_TRACKABLE, floor_id)

    var result: Dictionary = {
        "available": true,
        "reason_id": &"",
        "floor_id": floor_id,
        "quest_id": quest_id,
        "family": definition.family,
        "kind": definition.kind,
        "scope_id": definition.scope_id,
        "stage_id": StringName(String(entry.get("stage_id", &""))),
        "quest_state": state_id,
        "progress_kind": PROGRESS_UNBOUND,
        "timer_state_available": false,
    }
    if state_id == QuestProgressState.STATE_OBJECTIVES_COMPLETE:
        result["progress_kind"] = PROGRESS_OBJECTIVES_COMPLETE
        return result

    var raw_objective: Variant = entry.get("objective_state", {})
    if not raw_objective is Dictionary or (raw_objective as Dictionary).is_empty():
        return result
    var objective := (raw_objective as Dictionary).duplicate(true)

    if quest_id == Floor10PrimaryBossObjectiveService.QUEST_ID and objective.has("boss_actor_id"):
        var boss_actor_id := StringName(String(objective.get("boss_actor_id", &"")))
        if boss_actor_id != Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID or typeof(objective.get("boss_defeated", null)) != TYPE_BOOL:
            return _invalid_objective(result)
        result["progress_kind"] = PROGRESS_BOSS
        result["boss_actor_id"] = boss_actor_id
        result["boss_defeated"] = bool(objective["boss_defeated"])
        return result

    match definition.family:
        QuestDefinition.FAMILY_ANNIHILATION:
            if not AnnihilationObjectiveState.validate_dictionary(objective).is_empty():
                return _invalid_objective(result)
            var required := objective.get("required_actor_ids", []) as Array
            var defeated := objective.get("defeated_actor_ids", []) as Array
            result["progress_kind"] = PROGRESS_ANNIHILATION
            result["required_count"] = required.size()
            result["defeated_count"] = defeated.size()
            result["remaining_count"] = maxi(0, required.size() - defeated.size())
        QuestDefinition.FAMILY_ESCORT:
            if not EscortObjectiveState.validate_dictionary(objective).is_empty():
                return _invalid_objective(result)
            var route := objective.get("route_node_ids", []) as Array
            result["progress_kind"] = PROGRESS_ESCORT
            result["route_count"] = route.size()
            result["next_route_index"] = int(objective.get("next_route_index", 0))
            result["wait_requested"] = bool(objective.get("wait_requested", false))
            result["goal_reached"] = bool(objective.get("goal_reached", false))
            result["failed"] = bool(objective.get("failed", false))
        QuestDefinition.FAMILY_TOWER_DEFENSE:
            if not TowerDefenseObjectiveState.validate_dictionary(objective).is_empty():
                return _invalid_objective(result)
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
            return _invalid_objective(result)
    return result


static func _invalid_objective(base: Dictionary) -> Dictionary:
    var result := base.duplicate(true)
    result["available"] = false
    result["reason_id"] = REASON_OBJECTIVE_INVALID
    result["progress_kind"] = PROGRESS_UNBOUND
    return result


static func _unavailable(reason_id: StringName, floor_id: int) -> Dictionary:
    return {
        "available": false,
        "reason_id": reason_id,
        "floor_id": floor_id,
        "quest_id": &"",
        "family": &"",
        "kind": &"",
        "scope_id": &"",
        "stage_id": &"",
        "quest_state": &"",
        "progress_kind": PROGRESS_UNBOUND,
        "timer_state_available": false,
    }
