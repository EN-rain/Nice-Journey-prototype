class_name QuestLeaveRuleDefinition
extends Resource

const MODE_BLOCK: StringName = &"block_with_reason"
const MODE_CONFIRM_TERMINAL: StringName = &"confirm_terminal"
const MODE_SERIALIZE_SUSPEND: StringName = &"serialize_and_suspend"
const MODES: Array[StringName] = [MODE_BLOCK, MODE_CONFIRM_TERMINAL, MODE_SERIALIZE_SUSPEND]

@export var rule_id: StringName = &""
@export var mode: StringName = MODE_BLOCK
@export var reason_id: StringName = &""
@export_multiline var reason_text: String = ""
@export var terminal_state: StringName = &""

func validate_definition() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(rule_id)):
        errors.append("rule_id must be a stable ID")
    if not MODES.has(mode):
        errors.append("mode must be block_with_reason, confirm_terminal, or serialize_and_suspend")
    if not StableId.is_valid(String(reason_id)):
        errors.append("reason_id must be a stable ID")
    if reason_text.strip_edges().is_empty():
        errors.append("reason_text must explain the leave consequence")
    if mode == MODE_CONFIRM_TERMINAL:
        if terminal_state != QuestProgressState.STATE_ABANDONED and terminal_state != QuestProgressState.STATE_FAILED:
            errors.append("confirm_terminal must declare abandoned or failed as its terminal_state")
    elif terminal_state != &"":
        errors.append("terminal_state is only valid for confirm_terminal")
    return errors
