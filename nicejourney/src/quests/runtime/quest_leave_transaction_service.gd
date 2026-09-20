class_name QuestLeaveTransactionService
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_RULE_INVALID: StringName = &"rule_invalid"
const REASON_QUEST_NOT_ACTIVE: StringName = &"quest_not_active"
const REASON_BLOCKED: StringName = &"leave_blocked"
const REASON_CONFIRMATION_REQUIRED: StringName = &"confirmation_required"
const REASON_OBJECTIVE_STATE_NOT_SERIALIZABLE: StringName = &"objective_state_not_serializable"

static func preview(profile: ProfileSnapshot, quest_id: StringName, rule: QuestLeaveRuleDefinition) -> Dictionary:
    var context := _context(profile, quest_id, rule)
    if not bool(context.get("accepted", false)):
        return context
    var entry := context["entry"] as Dictionary
    return _result(
        true,
        &"",
        rule,
        StringName(String(entry.get("state", &""))),
        _target_state(rule),
        rule.mode == QuestLeaveRuleDefinition.MODE_CONFIRM_TERMINAL,
        false
    )

static func apply(
    profile: ProfileSnapshot,
    quest_id: StringName,
    rule: QuestLeaveRuleDefinition,
    confirmed: bool = false
) -> Dictionary:
    var context := _context(profile, quest_id, rule)
    if not bool(context.get("accepted", false)):
        return context
    var entry := context["entry"] as Dictionary
    var before_state := StringName(String(entry.get("state", &"")))

    match rule.mode:
        QuestLeaveRuleDefinition.MODE_BLOCK:
            return _result(false, REASON_BLOCKED, rule, before_state, before_state, false, false)
        QuestLeaveRuleDefinition.MODE_CONFIRM_TERMINAL:
            if not confirmed:
                return _result(false, REASON_CONFIRMATION_REQUIRED, rule, before_state, rule.terminal_state, true, false)
            entry["state"] = rule.terminal_state
            entry["leave_rule_id"] = String(rule.rule_id)
            entry["leave_reason_id"] = String(rule.reason_id)
            profile.quest_progress[String(quest_id)] = entry
            return _result(true, &"", rule, before_state, rule.terminal_state, true, true)
        QuestLeaveRuleDefinition.MODE_SERIALIZE_SUSPEND:
            var objective_state: Variant = entry.get("objective_state", {})
            if not objective_state is Dictionary:
                return _result(false, REASON_OBJECTIVE_STATE_NOT_SERIALIZABLE, rule, before_state, before_state, false, false)
            entry["state"] = QuestProgressState.STATE_SUSPENDED
            entry["leave_rule_id"] = String(rule.rule_id)
            entry["leave_reason_id"] = String(rule.reason_id)
            entry["suspended_objective_state"] = (objective_state as Dictionary).duplicate(true)
            profile.quest_progress[String(quest_id)] = entry
            return _result(true, &"", rule, before_state, QuestProgressState.STATE_SUSPENDED, false, true)
        _:
            return _result(false, REASON_RULE_INVALID, rule, before_state, before_state, false, false)

static func _context(profile: ProfileSnapshot, quest_id: StringName, rule: QuestLeaveRuleDefinition) -> Dictionary:
    if profile == null or not StableId.is_valid(String(quest_id)):
        return {"accepted": false, "reason_id": REASON_INVALID_CONTEXT}
    if rule == null or not rule.validate_definition().is_empty():
        return {"accepted": false, "reason_id": REASON_RULE_INVALID}
    var definition := QuestCatalog.get_definition(quest_id)
    if definition == null:
        return {"accepted": false, "reason_id": REASON_INVALID_CONTEXT}
    var raw: Variant = profile.quest_progress.get(String(quest_id), null)
    if not raw is Dictionary:
        return {"accepted": false, "reason_id": REASON_QUEST_NOT_ACTIVE}
    var entry := (raw as Dictionary).duplicate(true)
    var state := StringName(String(entry.get("state", &"")))
    if state != QuestProgressState.STATE_ACTIVE and state != QuestProgressState.STATE_OBJECTIVES_COMPLETE:
        return {"accepted": false, "reason_id": REASON_QUEST_NOT_ACTIVE}
    return {"accepted": true, "entry": entry, "definition": definition}

static func _target_state(rule: QuestLeaveRuleDefinition) -> StringName:
    match rule.mode:
        QuestLeaveRuleDefinition.MODE_CONFIRM_TERMINAL:
            return rule.terminal_state
        QuestLeaveRuleDefinition.MODE_SERIALIZE_SUSPEND:
            return QuestProgressState.STATE_SUSPENDED
        _:
            return &""

static func _result(
    accepted: bool,
    reason_id: StringName,
    rule: QuestLeaveRuleDefinition,
    before_state: StringName,
    after_state: StringName,
    confirmation_required: bool,
    mutated: bool
) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "rule_id": rule.rule_id if rule != null else &"",
        "mode": rule.mode if rule != null else &"",
        "leave_reason_id": rule.reason_id if rule != null else &"",
        "reason_text": rule.reason_text if rule != null else "",
        "before_state": before_state,
        "after_state": after_state,
        "confirmation_required": confirmation_required,
        "mutated": mutated,
    }
