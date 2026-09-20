class_name Floor10BossProgressionBridge
extends RefCounted

signal progression_committed(result: Dictionary)

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_ALREADY_BOUND: StringName = &"already_bound"

var profile: ProfileSnapshot = null
var sanctum: TenthWardenSanctum = null
var last_result: Dictionary = {}
var _bound: bool = false


func bind(source_profile: ProfileSnapshot, source_sanctum: TenthWardenSanctum) -> Dictionary:
    if _bound:
        return {"accepted": false, "reason_id": REASON_ALREADY_BOUND}
    if source_profile == null or source_sanctum == null:
        return {"accepted": false, "reason_id": REASON_INVALID_CONTEXT}
    profile = source_profile
    sanctum = source_sanctum
    sanctum.terminal_outcome_committed.connect(_on_terminal_outcome_committed)
    _bound = true
    return {"accepted": true, "reason_id": &""}


func unbind() -> void:
    if sanctum != null and is_instance_valid(sanctum):
        var callback := Callable(self, &"_on_terminal_outcome_committed")
        if sanctum.terminal_outcome_committed.is_connected(callback):
            sanctum.terminal_outcome_committed.disconnect(callback)
    profile = null
    sanctum = null
    _bound = false


func is_bound() -> bool:
    return _bound and profile != null and sanctum != null and is_instance_valid(sanctum)


func _on_terminal_outcome_committed(outcome_id: StringName) -> void:
    if not is_bound():
        last_result = {"accepted": false, "reason_id": REASON_INVALID_CONTEXT}
        progression_committed.emit(last_result.duplicate(true))
        return
    last_result = Floor10PrimaryBossObjectiveService.record_terminal_outcome(profile, outcome_id)
    last_result["outcome_id"] = outcome_id
    progression_committed.emit(last_result.duplicate(true))
