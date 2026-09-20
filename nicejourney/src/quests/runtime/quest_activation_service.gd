class_name QuestActivationService
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_PREREQUISITES_NOT_SATISFIED: StringName = &"prerequisites_not_satisfied"
const REASON_QUEST_NOT_AVAILABLE: StringName = &"quest_not_available"
const REASON_QUEST_ALREADY_TERMINAL: StringName = &"quest_already_terminal"
const REASON_ATTEMPT_ID_REUSED: StringName = &"attempt_id_reused"
const REASON_OBJECTIVE_BIND_FAILED: StringName = &"objective_bind_failed"
const REASON_RETRY_NOT_ALLOWED: StringName = &"retry_not_allowed"
const REASON_STAGED_PROFILE_INVALID: StringName = &"staged_profile_invalid"
const REASON_AUTHORED_CONTRACT_UNAVAILABLE: StringName = &"authored_contract_unavailable"
const REASON_ACCEPTANCE_ANCHOR_MISMATCH: StringName = &"acceptance_anchor_mismatch"
const REASON_PREREQUISITE_FACTS_INVALID: StringName = &"prerequisite_facts_invalid"


static func evaluate_authored_acceptance(
    definition: QuestDefinition,
    presented_anchor_id: StringName,
    satisfied_prerequisite_ids: Array[StringName]
) -> Dictionary:
    if definition == null:
        return {"accepted": false, "reason_id": REASON_INVALID_CONTEXT, "contract_errors": PackedStringArray(), "missing_prerequisite_ids": []}
    var contract_errors := definition.validate_definition()
    contract_errors.append_array(definition.validate_production_contract())
    if not contract_errors.is_empty():
        return {
            "accepted": false,
            "reason_id": REASON_AUTHORED_CONTRACT_UNAVAILABLE,
            "contract_errors": contract_errors.duplicate(),
            "missing_prerequisite_ids": [],
        }
    if presented_anchor_id != definition.acceptance_anchor_id:
        return {
            "accepted": false,
            "reason_id": REASON_ACCEPTANCE_ANCHOR_MISMATCH,
            "contract_errors": PackedStringArray(),
            "missing_prerequisite_ids": [],
        }
    var seen: Dictionary = {}
    for fact_id: StringName in satisfied_prerequisite_ids:
        if not StableId.is_valid(String(fact_id)) or seen.has(fact_id):
            return {
                "accepted": false,
                "reason_id": REASON_PREREQUISITE_FACTS_INVALID,
                "contract_errors": PackedStringArray(),
                "missing_prerequisite_ids": [],
            }
        seen[fact_id] = true
    var missing: Array[StringName] = []
    for prerequisite_id: StringName in definition.prerequisite_ids:
        if not seen.has(prerequisite_id):
            missing.append(prerequisite_id)
    if not missing.is_empty():
        return {
            "accepted": false,
            "reason_id": REASON_PREREQUISITES_NOT_SATISFIED,
            "contract_errors": PackedStringArray(),
            "missing_prerequisite_ids": missing.duplicate(),
        }
    return {
        "accepted": true,
        "reason_id": &"",
        "contract_errors": PackedStringArray(),
        "missing_prerequisite_ids": [],
    }


static func activate_authored(
    profile: ProfileSnapshot,
    quest_id: StringName,
    attempt_id: StringName,
    presented_anchor_id: StringName,
    satisfied_prerequisite_ids: Array[StringName],
    authored_objective_config: Dictionary = {}
) -> Dictionary:
    var definition := _definition(profile, quest_id)
    if definition == null:
        return _result(false, REASON_INVALID_CONTEXT, quest_id, &"", &"")
    var policy := evaluate_authored_acceptance(definition, presented_anchor_id, satisfied_prerequisite_ids)
    if not bool(policy.get("accepted", false)):
        var rejected := _result(false, StringName(policy.get("reason_id", REASON_AUTHORED_CONTRACT_UNAVAILABLE)), quest_id, _current_state(profile, quest_id), _current_state(profile, quest_id))
        rejected["contract_errors"] = (policy.get("contract_errors", PackedStringArray()) as PackedStringArray).duplicate()
        rejected["missing_prerequisite_ids"] = (policy.get("missing_prerequisite_ids", []) as Array).duplicate()
        return rejected
    return _activate_after_authored_policy(profile, quest_id, attempt_id, authored_objective_config)


static func _activate_after_authored_policy(
    profile: ProfileSnapshot,
    quest_id: StringName,
    attempt_id: StringName,
    authored_objective_config: Dictionary = {}
) -> Dictionary:
    var before := _current_state(profile, quest_id)
    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null:
        return _result(false, REASON_STAGED_PROFILE_INVALID, quest_id, before, before)

    var availability_result: Dictionary = {}
    var state := _current_state(staged, quest_id)
    if state == &"" or state == QuestProgressState.STATE_UNAVAILABLE:
        availability_result = mark_available(staged, quest_id, true)
        if not bool(availability_result.get("accepted", false)):
            return _activation_rejection(availability_result, quest_id, before, availability_result)
        state = QuestProgressState.STATE_AVAILABLE
    if state != QuestProgressState.STATE_AVAILABLE:
        var unavailable := _result(false, REASON_QUEST_NOT_AVAILABLE, quest_id, before, before)
        unavailable["availability_result"] = availability_result.duplicate(true)
        unavailable["authored_contract_admitted"] = false
        return unavailable

    var accepted := accept(staged, quest_id, attempt_id, true, authored_objective_config)
    if not bool(accepted.get("accepted", false)):
        return _activation_rejection(accepted, quest_id, before, availability_result)
    if not _commit_if_valid(profile, staged):
        var invalid := _result(false, REASON_STAGED_PROFILE_INVALID, quest_id, before, before)
        invalid["availability_result"] = availability_result.duplicate(true)
        invalid["authored_contract_admitted"] = false
        return invalid

    accepted["before_state"] = before
    accepted["after_state"] = QuestProgressState.STATE_ACTIVE
    accepted["mutated"] = before != QuestProgressState.STATE_ACTIVE
    accepted["availability_result"] = availability_result.duplicate(true)
    accepted["authored_contract_admitted"] = true
    return accepted


static func _activation_rejection(
    staged_result: Dictionary,
    quest_id: StringName,
    before: StringName,
    availability_result: Dictionary
) -> Dictionary:
    var rejected := _result(
        false,
        StringName(staged_result.get("reason_id", REASON_STAGED_PROFILE_INVALID)),
        quest_id,
        before,
        before
    )
    rejected["objective_reason_id"] = StringName(staged_result.get("objective_reason_id", &""))
    rejected["availability_result"] = availability_result.duplicate(true)
    rejected["authored_contract_admitted"] = false
    return rejected


static func mark_available(
    profile: ProfileSnapshot,
    quest_id: StringName,
    prerequisites_satisfied: bool
) -> Dictionary:
    var definition := _definition(profile, quest_id)
    if definition == null:
        return _result(false, REASON_INVALID_CONTEXT, quest_id, &"", &"")
    if not prerequisites_satisfied:
        return _result(false, REASON_PREREQUISITES_NOT_SATISFIED, quest_id, _current_state(profile, quest_id), _current_state(profile, quest_id))

    var before := _current_state(profile, quest_id)
    if before == QuestProgressState.STATE_COMPLETED:
        return _result(false, REASON_QUEST_ALREADY_TERMINAL, quest_id, before, before)
    if before != &"" and before != QuestProgressState.STATE_UNAVAILABLE and before != QuestProgressState.STATE_AVAILABLE:
        return _result(false, REASON_QUEST_NOT_AVAILABLE, quest_id, before, before)

    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    var entry := _entry(staged, quest_id)
    entry["state"] = QuestProgressState.STATE_AVAILABLE
    entry["stage_id"] = &""
    entry["attempt_id"] = &""
    entry["objective_state"] = {}
    if not entry.has("attempt_history"):
        entry["attempt_history"] = []
    staged.quest_progress[String(quest_id)] = entry
    if not _commit_if_valid(profile, staged):
        return _result(false, REASON_STAGED_PROFILE_INVALID, quest_id, before, before)
    return _result(true, &"", quest_id, before, QuestProgressState.STATE_AVAILABLE)


static func accept(
    profile: ProfileSnapshot,
    quest_id: StringName,
    attempt_id: StringName,
    acceptance_admitted: bool,
    authored_objective_config: Dictionary = {}
) -> Dictionary:
    var definition := _definition(profile, quest_id)
    if definition == null or not StableId.is_valid(String(attempt_id)):
        return _result(false, REASON_INVALID_CONTEXT, quest_id, _current_state(profile, quest_id), _current_state(profile, quest_id))
    var before := _current_state(profile, quest_id)
    if not acceptance_admitted:
        return _result(false, REASON_PREREQUISITES_NOT_SATISFIED, quest_id, before, before)
    if before != QuestProgressState.STATE_AVAILABLE:
        return _result(false, REASON_QUEST_NOT_AVAILABLE, quest_id, before, before)

    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    var entry := _entry(staged, quest_id)
    var history := _attempt_history(entry)
    if history.has(attempt_id):
        return _result(false, REASON_ATTEMPT_ID_REUSED, quest_id, before, before)
    history.append(attempt_id)
    entry["state"] = QuestProgressState.STATE_ACTIVE
    entry["stage_id"] = definition.stage_ids[0]
    entry["attempt_id"] = attempt_id
    entry["attempt_history"] = _strings(history)
    entry["objective_state"] = {}
    entry.erase("failure_reason_id")
    entry.erase("leave_rule_id")
    entry.erase("leave_reason_id")
    entry.erase("suspended_objective_state")
    staged.quest_progress[String(quest_id)] = entry

    if not authored_objective_config.is_empty():
        var bind := QuestFamilyObjectiveService.bind(staged, quest_id, authored_objective_config)
        if not bool(bind.get("accepted", false)):
            var rejected := _result(false, REASON_OBJECTIVE_BIND_FAILED, quest_id, before, before)
            rejected["objective_reason_id"] = StringName(bind.get("reason_id", &""))
            return rejected

    if not _commit_if_valid(profile, staged):
        return _result(false, REASON_STAGED_PROFILE_INVALID, quest_id, before, before)
    var result := _result(true, &"", quest_id, before, QuestProgressState.STATE_ACTIVE)
    result["attempt_id"] = attempt_id
    result["stage_id"] = definition.stage_ids[0]
    return result


static func mark_retry_ready(
    profile: ProfileSnapshot,
    quest_id: StringName,
    recovery_conditions_satisfied: bool
) -> Dictionary:
    var definition := _definition(profile, quest_id)
    if definition == null:
        return _result(false, REASON_INVALID_CONTEXT, quest_id, &"", &"")
    var before := _current_state(profile, quest_id)
    if not recovery_conditions_satisfied:
        return _result(false, REASON_RETRY_NOT_ALLOWED, quest_id, before, before)
    if before != QuestProgressState.STATE_FAILED and before != QuestProgressState.STATE_ABANDONED:
        return _result(false, REASON_RETRY_NOT_ALLOWED, quest_id, before, before)

    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    var entry := _entry(staged, quest_id)
    entry["state"] = QuestProgressState.STATE_RETRY_READY
    staged.quest_progress[String(quest_id)] = entry
    if not _commit_if_valid(profile, staged):
        return _result(false, REASON_STAGED_PROFILE_INVALID, quest_id, before, before)
    return _result(true, &"", quest_id, before, QuestProgressState.STATE_RETRY_READY)


static func retry(
    profile: ProfileSnapshot,
    quest_id: StringName,
    attempt_id: StringName,
    retry_admitted: bool,
    authored_objective_config: Dictionary = {}
) -> Dictionary:
    var definition := _definition(profile, quest_id)
    if definition == null or not StableId.is_valid(String(attempt_id)):
        return _result(false, REASON_INVALID_CONTEXT, quest_id, _current_state(profile, quest_id), _current_state(profile, quest_id))
    var before := _current_state(profile, quest_id)
    if not retry_admitted or before != QuestProgressState.STATE_RETRY_READY:
        return _result(false, REASON_RETRY_NOT_ALLOWED, quest_id, before, before)

    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    var entry := _entry(staged, quest_id)
    var history := _attempt_history(entry)
    if history.has(attempt_id):
        return _result(false, REASON_ATTEMPT_ID_REUSED, quest_id, before, before)
    history.append(attempt_id)
    entry["state"] = QuestProgressState.STATE_ACTIVE
    entry["stage_id"] = definition.stage_ids[0]
    entry["attempt_id"] = attempt_id
    entry["attempt_history"] = _strings(history)
    entry["objective_state"] = {}
    entry.erase("failure_reason_id")
    entry.erase("leave_rule_id")
    entry.erase("leave_reason_id")
    entry.erase("suspended_objective_state")
    staged.quest_progress[String(quest_id)] = entry

    if not authored_objective_config.is_empty():
        var bind := QuestFamilyObjectiveService.bind(staged, quest_id, authored_objective_config)
        if not bool(bind.get("accepted", false)):
            var rejected := _result(false, REASON_OBJECTIVE_BIND_FAILED, quest_id, before, before)
            rejected["objective_reason_id"] = StringName(bind.get("reason_id", &""))
            return rejected

    if not _commit_if_valid(profile, staged):
        return _result(false, REASON_STAGED_PROFILE_INVALID, quest_id, before, before)
    var result := _result(true, &"", quest_id, before, QuestProgressState.STATE_ACTIVE)
    result["attempt_id"] = attempt_id
    result["stage_id"] = definition.stage_ids[0]
    return result


static func _definition(profile: ProfileSnapshot, quest_id: StringName) -> QuestDefinition:
    if profile == null or not StableId.is_valid(String(quest_id)):
        return null
    return QuestCatalog.get_definition(quest_id)


static func _entry(profile: ProfileSnapshot, quest_id: StringName) -> Dictionary:
    var raw: Variant = profile.quest_progress.get(String(quest_id), {})
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


static func _current_state(profile: ProfileSnapshot, quest_id: StringName) -> StringName:
    if profile == null:
        return &""
    var raw: Variant = profile.quest_progress.get(String(quest_id), null)
    if not raw is Dictionary:
        return &""
    return StringName(String((raw as Dictionary).get("state", &"")))


static func _attempt_history(entry: Dictionary) -> Array[StringName]:
    var result: Array[StringName] = []
    var raw: Variant = entry.get("attempt_history", [])
    if not raw is Array:
        return result
    for value: Variant in raw as Array:
        result.append(StringName(String(value)))
    return result


static func _strings(values: Array[StringName]) -> Array[String]:
    var result: Array[String] = []
    for value: StringName in values:
        result.append(String(value))
    return result


static func _commit_if_valid(target: ProfileSnapshot, staged: ProfileSnapshot) -> bool:
    if staged == null or not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return false
    target.quest_progress = staged.quest_progress.duplicate(true)
    return true


static func _result(
    accepted: bool,
    reason_id: StringName,
    quest_id: StringName,
    before_state: StringName,
    after_state: StringName
) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "quest_id": quest_id,
        "before_state": before_state,
        "after_state": after_state,
        "mutated": accepted and before_state != after_state,
        "objective_reason_id": &"",
    }
