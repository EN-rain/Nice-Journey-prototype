class_name QuestProgressState
extends RefCounted

const STATE_UNAVAILABLE: StringName = &"unavailable"
const STATE_AVAILABLE: StringName = &"available"
const STATE_ACTIVE: StringName = &"active"
const STATE_SUSPENDED: StringName = &"suspended"
const STATE_FAILED: StringName = &"failed"
const STATE_ABANDONED: StringName = &"abandoned"
const STATE_RETRY_READY: StringName = &"retry_ready"
const STATE_OBJECTIVES_COMPLETE: StringName = &"objectives_complete"
const STATE_COMPLETED: StringName = &"completed"

const VALID_STATES: Array[StringName] = [
    STATE_UNAVAILABLE,
    STATE_AVAILABLE,
    STATE_ACTIVE,
    STATE_SUSPENDED,
    STATE_FAILED,
    STATE_ABANDONED,
    STATE_RETRY_READY,
    STATE_OBJECTIVES_COMPLETE,
    STATE_COMPLETED,
]


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    for quest_key: Variant in data.keys():
        var quest_id: StringName = StringName(String(quest_key))
        var definition: QuestDefinition = QuestCatalog.get_definition(quest_id)
        if definition == null:
            errors.append("unknown quest_id: %s" % String(quest_id))
            continue
        var raw_entry: Variant = data[quest_key]
        if not raw_entry is Dictionary:
            errors.append("quest progress entry must be a dictionary: %s" % String(quest_id))
            continue
        var entry: Dictionary = raw_entry as Dictionary
        var state_variant: Variant = entry.get("state", null)
        if not (typeof(state_variant) == TYPE_STRING or typeof(state_variant) == TYPE_STRING_NAME):
            errors.append("quest state must be String/StringName: %s" % String(quest_id))
        else:
            var state_id: StringName = StringName(String(state_variant))
            if not VALID_STATES.has(state_id):
                errors.append("unknown quest state: %s" % String(state_id))
        var stage_variant: Variant = entry.get("stage_id", &"")
        if not (typeof(stage_variant) == TYPE_STRING or typeof(stage_variant) == TYPE_STRING_NAME):
            errors.append("stage_id must be String/StringName: %s" % String(quest_id))
        else:
            var stage_id: StringName = StringName(String(stage_variant))
            if stage_id != &"" and not definition.stage_ids.has(stage_id):
                errors.append("stage_id is not declared by quest %s: %s" % [String(quest_id), String(stage_id)])
        var attempt_variant: Variant = entry.get("attempt_id", &"")
        if not (typeof(attempt_variant) == TYPE_STRING or typeof(attempt_variant) == TYPE_STRING_NAME):
            errors.append("attempt_id must be String/StringName: %s" % String(quest_id))
        else:
            var attempt_text: String = String(attempt_variant)
            if not attempt_text.is_empty() and not StableId.is_valid(attempt_text):
                errors.append("attempt_id must be empty or a stable ID: %s" % String(quest_id))
        var objective_variant: Variant = entry.get("objective_state", {})
        if not objective_variant is Dictionary:
            errors.append("objective_state must be a dictionary when present: %s" % String(quest_id))
        var history_variant: Variant = entry.get("attempt_history", [])
        if not history_variant is Array:
            errors.append("attempt_history must be an array when present: %s" % String(quest_id))
        else:
            var seen_attempts: Dictionary = {}
            for raw_attempt: Variant in history_variant as Array:
                var attempt_text := String(raw_attempt)
                if not StableId.is_valid(attempt_text):
                    errors.append("attempt_history contains invalid attempt ID: %s" % String(quest_id))
                    continue
                if seen_attempts.has(attempt_text):
                    errors.append("attempt_history contains duplicate attempt ID: %s" % String(quest_id))
                seen_attempts[attempt_text] = true
            var current_attempt_text := String(entry.get("attempt_id", &""))
            if not current_attempt_text.is_empty() and not seen_attempts.is_empty() and not seen_attempts.has(current_attempt_text):
                errors.append("current attempt_id must exist in attempt_history when history is present: %s" % String(quest_id))
    return errors
