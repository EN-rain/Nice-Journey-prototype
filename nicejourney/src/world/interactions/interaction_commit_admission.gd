class_name InteractionCommitAdmission
extends RefCounted

const REASON_INVALID_COMMIT_ID: StringName = &"invalid_commit_id"
const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_DUPLICATE_COMMIT: StringName = &"duplicate_commit"
const REASON_OUT_OF_RANGE: StringName = &"out_of_range"
const REASON_TARGET_INVALID: StringName = &"target_invalid"
const REASON_REQUIRED_ITEM_MISSING: StringName = &"required_item_missing"
const REASON_REQUIRED_QUEST_FLAG_MISSING: StringName = &"required_quest_flag_missing"
const REASON_MENU_OWNERSHIP_BLOCKED: StringName = &"menu_ownership_blocked"
const REASON_COMBAT_OWNERSHIP_BLOCKED: StringName = &"combat_ownership_blocked"
const REASON_HOLD_INCOMPLETE: StringName = &"hold_incomplete"

const _PRECONDITIONS: Array[Dictionary] = [
    {"field": &"in_range", "reason": REASON_OUT_OF_RANGE},
    {"field": &"target_state_valid", "reason": REASON_TARGET_INVALID},
    {"field": &"required_item_satisfied", "reason": REASON_REQUIRED_ITEM_MISSING},
    {"field": &"required_quest_flag_satisfied", "reason": REASON_REQUIRED_QUEST_FLAG_MISSING},
    {"field": &"menu_ownership_allows", "reason": REASON_MENU_OWNERSHIP_BLOCKED},
    {"field": &"combat_ownership_allows", "reason": REASON_COMBAT_OWNERSHIP_BLOCKED},
    {"field": &"hold_complete", "reason": REASON_HOLD_INCOMPLETE},
]

var _admitted_commit_ids: Dictionary = {}

func try_admit(raw_commit_id: Variant, raw_context: Variant) -> Dictionary:
    if not (raw_commit_id is String or raw_commit_id is StringName):
        return _result(false, REASON_INVALID_COMMIT_ID)
    var commit_id: StringName = StringName(String(raw_commit_id))
    if not StableId.is_valid(String(commit_id)):
        return _result(false, REASON_INVALID_COMMIT_ID)
    if not raw_context is Dictionary:
        return _result(false, REASON_INVALID_CONTEXT)

    var context: Dictionary = raw_context as Dictionary
    for condition: Dictionary in _PRECONDITIONS:
        var field: StringName = StringName(condition["field"])
        if not context.has(field) or typeof(context[field]) != TYPE_BOOL:
            return _result(false, REASON_INVALID_CONTEXT)

    if _admitted_commit_ids.has(commit_id):
        return _result(false, REASON_DUPLICATE_COMMIT)

    for condition: Dictionary in _PRECONDITIONS:
        var field: StringName = StringName(condition["field"])
        if not bool(context[field]):
            return _result(false, StringName(condition["reason"]))

    _admitted_commit_ids[commit_id] = true
    return _result(true, &"")

func _result(admitted: bool, reason_id: StringName) -> Dictionary:
    return {
        "admitted": admitted,
        "reason_id": reason_id,
    }
