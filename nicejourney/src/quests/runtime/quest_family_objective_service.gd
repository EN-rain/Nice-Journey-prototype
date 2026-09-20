class_name QuestFamilyObjectiveService
extends RefCounted

const EVENT_ACTOR_DEFEATED: StringName = &"actor_defeated"
const EVENT_ROUTE_NODE_REACHED: StringName = &"route_node_reached"
const EVENT_WAIT_CHANGED: StringName = &"wait_changed"
const EVENT_GOAL_REACHED: StringName = &"goal_reached"
const EVENT_FAILED: StringName = &"failed"
const EVENT_OBJECTIVE_DAMAGE: StringName = &"objective_damage"

static func bind(profile: ProfileSnapshot, quest_id: StringName, authored_config: Dictionary) -> Dictionary:
    var context := _active_context(profile, quest_id)
    if not bool(context.get("accepted", false)):
        return context
    var definition := context["definition"] as QuestDefinition
    var entry := context["entry"] as Dictionary
    if entry.has("objective_state") and not (entry.get("objective_state", {}) as Dictionary).is_empty():
        return _result(false, &"objective_already_bound", false, false)

    var state_data: Dictionary = {}
    match definition.family:
        QuestDefinition.FAMILY_ANNIHILATION:
            var state := AnnihilationObjectiveState.new()
            var ids := _name_array(authored_config.get("required_actor_ids", []))
            if not state.configure(ids):
                return _result(false, &"invalid_authored_config", false, false)
            state_data = state.to_dictionary()
        QuestDefinition.FAMILY_ESCORT:
            var state := EscortObjectiveState.new()
            var route := _name_array(authored_config.get("route_node_ids", []))
            if not state.configure(
                StringName(String(authored_config.get("actor_id", &""))),
                route,
                StringName(String(authored_config.get("goal_id", &""))),
                StringName(String(authored_config.get("safe_retry_origin_id", &""))),
                StringName(String(authored_config.get("failure_policy_id", &"")))
            ):
                return _result(false, &"invalid_authored_config", false, false)
            state_data = state.to_dictionary()
        QuestDefinition.FAMILY_TOWER_DEFENSE:
            var state := TowerDefenseObjectiveState.new()
            if not state.configure(
                StringName(String(authored_config.get("objective_id", &""))),
                int(authored_config.get("objective_max_hp", 0)),
                authored_config.get("required_actor_ids_by_wave", {}) as Dictionary
            ):
                return _result(false, &"invalid_authored_config", false, false)
            state_data = state.to_dictionary()
        _:
            return _result(false, &"unsupported_family", false, false)

    entry["objective_state"] = state_data
    profile.quest_progress[String(quest_id)] = entry
    return _result(true, &"", false, false)

static func apply_event(profile: ProfileSnapshot, quest_id: StringName, event_id: StringName, payload: Dictionary) -> Dictionary:
    var context := _active_context(profile, quest_id)
    if not bool(context.get("accepted", false)):
        return context
    var definition := context["definition"] as QuestDefinition
    var entry := context["entry"] as Dictionary
    var raw_state: Variant = entry.get("objective_state", null)
    if not raw_state is Dictionary or (raw_state as Dictionary).is_empty():
        return _result(false, &"objective_unbound", false, false)

    var event_result: Dictionary = {}
    var complete := false
    var failed := false
    var next_state: Dictionary = {}
    match definition.family:
        QuestDefinition.FAMILY_ANNIHILATION:
            if event_id != EVENT_ACTOR_DEFEATED:
                return _result(false, &"event_not_supported", false, false)
            var state := AnnihilationObjectiveState.new()
            if not state.load_dictionary(raw_state as Dictionary).is_empty():
                return _result(false, &"objective_state_invalid", false, false)
            event_result = state.record_actor_defeated(StringName(String(payload.get("actor_id", &""))))
            complete = state.is_complete()
            next_state = state.to_dictionary()
        QuestDefinition.FAMILY_ESCORT:
            var state := EscortObjectiveState.new()
            if not state.load_dictionary(raw_state as Dictionary).is_empty():
                return _result(false, &"objective_state_invalid", false, false)
            match event_id:
                EVENT_ROUTE_NODE_REACHED:
                    event_result = state.record_route_node_reached(StringName(String(payload.get("route_node_id", &""))))
                EVENT_WAIT_CHANGED:
                    if typeof(payload.get("wait_requested", null)) != TYPE_BOOL:
                        return _result(false, &"invalid_event_payload", false, false)
                    var accepted := state.set_wait_requested(bool(payload["wait_requested"]))
                    event_result = {"accepted": accepted, "reason_id": &"" if accepted else &"objective_terminal"}
                EVENT_GOAL_REACHED:
                    event_result = state.record_goal_reached(StringName(String(payload.get("goal_id", &""))))
                EVENT_FAILED:
                    event_result = state.record_failure(StringName(String(payload.get("reason_id", &""))))
                _:
                    return _result(false, &"event_not_supported", false, false)
            complete = state.is_complete()
            failed = state.failed
            next_state = state.to_dictionary()
        QuestDefinition.FAMILY_TOWER_DEFENSE:
            var state := TowerDefenseObjectiveState.new()
            if not state.load_dictionary(raw_state as Dictionary).is_empty():
                return _result(false, &"objective_state_invalid", false, false)
            match event_id:
                EVENT_ACTOR_DEFEATED:
                    event_result = state.record_actor_defeated(
                        StringName(String(payload.get("wave_id", &""))),
                        StringName(String(payload.get("actor_id", &"")))
                    )
                EVENT_OBJECTIVE_DAMAGE:
                    if typeof(payload.get("amount", null)) != TYPE_INT:
                        return _result(false, &"invalid_event_payload", false, false)
                    event_result = state.apply_objective_damage(int(payload["amount"]))
                _:
                    return _result(false, &"event_not_supported", false, false)
            complete = state.is_complete()
            failed = state.failed
            next_state = state.to_dictionary()
        _:
            return _result(false, &"unsupported_family", false, false)

    if not bool(event_result.get("accepted", false)):
        return _result(false, StringName(event_result.get("reason_id", &"event_rejected")), complete, failed)
    entry["objective_state"] = next_state
    if complete:
        entry["state"] = QuestProgressState.STATE_OBJECTIVES_COMPLETE
    elif failed:
        entry["state"] = QuestProgressState.STATE_FAILED
    profile.quest_progress[String(quest_id)] = entry
    var result := _result(true, StringName(event_result.get("reason_id", &"")), complete, failed)
    result["objective_state"] = next_state.duplicate(true)
    return result

static func _active_context(profile: ProfileSnapshot, quest_id: StringName) -> Dictionary:
    if profile == null:
        return _result(false, &"invalid_profile", false, false)
    var definition := QuestCatalog.get_definition(quest_id)
    if definition == null:
        return _result(false, &"unknown_quest", false, false)
    var raw_entry: Variant = profile.quest_progress.get(String(quest_id), null)
    if not raw_entry is Dictionary:
        return _result(false, &"quest_not_active", false, false)
    var entry := (raw_entry as Dictionary).duplicate(true)
    if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_ACTIVE:
        return _result(false, &"quest_not_active", false, false)
    return {"accepted": true, "definition": definition, "entry": entry}

static func _name_array(value: Variant) -> Array[StringName]:
    var result: Array[StringName] = []
    if not value is Array:
        return result
    for raw: Variant in value as Array:
        result.append(StringName(String(raw)))
    return result

static func _result(accepted: bool, reason_id: StringName, complete: bool, failed: bool) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "objectives_complete": complete,
        "failed": failed,
    }
