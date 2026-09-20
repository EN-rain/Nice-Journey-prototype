class_name TowerProductionEncounterContentCatalog
extends RefCounted

const CONTENT_STATUS: StringName = &"production_v01"
const ENCOUNTER_CONFIG_ID: StringName = &"encounters:tower_production_v01"
const DEFENSE_OBJECTIVE_MAX_HP: int = 100

# Directly authored production-v01 baseline. Values intentionally match the
# mechanically validated playtest population used before this promotion.
const REUSABLE_ENEMY_TARGETS: Dictionary = {
    1: 3,
    2: 4,
    3: 4,
    4: 5,
    5: 6,
    6: 6,
    7: 6,
    8: 7,
    9: 8,
    10: 7,
}


static func build_plan(floor_state: FloorInstanceState) -> Dictionary:
    var plan := TowerPrototypeEncounterContentCatalog.build_plan(floor_state)
    if plan.is_empty():
        return {}
    var floor_id := floor_state.floor_id
    if not REUSABLE_ENEMY_TARGETS.has(floor_id):
        return {}
    var placements := plan.get("placements", []) as Array
    if placements.size() != int(REUSABLE_ENEMY_TARGETS[floor_id]):
        return {}
    plan["plan_id"] = StringName("encounter_plan:tower_floor_%02d_production_v01" % floor_id)
    plan["content_status"] = CONTENT_STATUS
    plan["encounter_config_id"] = ENCOUNTER_CONFIG_ID
    if not TowerEncounterPlanValidator.validate(plan, floor_state).is_empty():
        return {}
    return plan


static func objective_configs(floor_state: FloorInstanceState, plan: Dictionary) -> Dictionary:
    if floor_state == null or not TowerEncounterPlanValidator.validate(plan, floor_state).is_empty():
        return {}
    if StringName(String(plan.get("content_status", &""))) != CONTENT_STATUS:
        return {}

    var result: Dictionary = {}
    var bindings := floor_state.layout_manifest.get("objective_bindings", {}) as Dictionary
    for raw_quest_id: Variant in bindings.keys():
        var quest_id := StringName(String(raw_quest_id))
        var definition := QuestCatalog.get_definition(quest_id)
        if definition == null or definition.kind != QuestDefinition.KIND_PRIMARY:
            continue
        if definition.floor_id != floor_state.floor_id:
            continue

        # Floor 10 primary progression is owned by the Tenth Warden bridge,
        # not by generic reusable resident defeats.
        if floor_state.floor_id == 10:
            continue

        var room_id := StringName(String(bindings[raw_quest_id]))
        var actor_ids := _actor_ids_for_room(plan, room_id)
        match definition.family:
            QuestDefinition.FAMILY_ANNIHILATION:
                if not actor_ids.is_empty():
                    result[quest_id] = {
                        "required_actor_ids": actor_ids,
                        "content_status": CONTENT_STATUS,
                    }
            QuestDefinition.FAMILY_TOWER_DEFENSE:
                if not actor_ids.is_empty() and not definition.required_objective_ids.is_empty():
                    var wave_id := StringName("wave:%s_production_v01" % String(quest_id))
                    result[quest_id] = {
                        "objective_id": definition.required_objective_ids[0],
                        "objective_max_hp": DEFENSE_OBJECTIVE_MAX_HP,
                        "required_actor_ids_by_wave": {wave_id: actor_ids},
                        "content_status": CONTENT_STATUS,
                    }
            QuestDefinition.FAMILY_ESCORT:
                var authored := TowerEscortObjectiveAuthoring.build_production_v01(floor_state, quest_id)
                var objective_config_variant: Variant = authored.get("objective_config", null)
                if objective_config_variant is Dictionary and not (objective_config_variant as Dictionary).is_empty():
                    var config := (objective_config_variant as Dictionary).duplicate(true)
                    config["content_status"] = CONTENT_STATUS
                    result[quest_id] = config
    return result


static func quest_bindings_by_actor(floor_state: FloorInstanceState, plan: Dictionary) -> Dictionary:
    if floor_state == null or not TowerEncounterPlanValidator.validate(plan, floor_state).is_empty():
        return {}
    if StringName(String(plan.get("content_status", &""))) != CONTENT_STATUS:
        return {}
    var result: Dictionary = {}
    var objective_bindings := floor_state.layout_manifest.get("objective_bindings", {}) as Dictionary
    for raw_quest_id: Variant in objective_bindings.keys():
        var quest_id := StringName(String(raw_quest_id))
        var definition := QuestCatalog.get_definition(quest_id)
        if definition == null or definition.kind != QuestDefinition.KIND_PRIMARY:
            continue
        if definition.family == QuestDefinition.FAMILY_ESCORT or definition.floor_id == 10:
            continue
        var room_id := StringName(String(objective_bindings[raw_quest_id]))
        var wave_id := StringName("wave:%s_production_v01" % String(quest_id))
        for actor_id: StringName in _actor_ids_for_room(plan, room_id):
            var entry := {"quest_id": quest_id}
            if definition.family == QuestDefinition.FAMILY_TOWER_DEFENSE:
                entry["wave_id"] = wave_id
            var actor_bindings: Array = result.get(actor_id, []) as Array
            actor_bindings.append(entry)
            result[actor_id] = actor_bindings
    return result


static func encounter_ids(plan: Dictionary) -> Array[StringName]:
    return TowerPrototypeEncounterContentCatalog.encounter_ids(plan)


static func validate_floor_content(floor_state: FloorInstanceState) -> PackedStringArray:
    var errors := PackedStringArray()
    if floor_state == null:
        errors.append("floor_state is required")
        return errors
    var plan := build_plan(floor_state)
    if plan.is_empty():
        errors.append("production encounter plan could not be built")
        return errors
    if StringName(String(plan.get("content_status", &""))) != CONTENT_STATUS:
        errors.append("production encounter plan content status mismatch")
    if (plan.get("placements", []) as Array).size() != int(REUSABLE_ENEMY_TARGETS.get(floor_state.floor_id, -1)):
        errors.append("production encounter placement count mismatch")
    if floor_state.floor_id >= 2 and floor_state.floor_id <= 9:
        var quest_id := StringName("primary_floor_%d" % floor_state.floor_id)
        var configs := objective_configs(floor_state, plan)
        if not configs.has(quest_id):
            errors.append("production primary objective config missing")
    if floor_state.floor_id == 10 and objective_configs(floor_state, plan).has(&"primary_floor_10"):
        errors.append("Floor 10 generic residents cannot own Tenth Warden primary completion")
    return errors


static func _actor_ids_for_room(plan: Dictionary, room_id: StringName) -> Array[StringName]:
    var result: Array[StringName] = []
    for raw_placement: Variant in plan.get("placements", []) as Array:
        if not raw_placement is Dictionary:
            continue
        var placement := raw_placement as Dictionary
        if StringName(String(placement.get("room_instance_id", &""))) != room_id:
            continue
        var actor_id := StringName(String(placement.get("actor_id", &"")))
        if StableId.is_valid(String(actor_id)):
            result.append(actor_id)
    result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
    return result
