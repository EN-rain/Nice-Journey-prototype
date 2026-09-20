class_name SaveRequestCoordinator
extends RefCounted

const REQUEST_AUTOSAVE: StringName = &"autosave"
const REQUEST_CHECKPOINT: StringName = &"checkpoint"
const REQUEST_MANUAL: StringName = &"manual"

const STATE_PENDING: StringName = &"pending"
const STATE_SUCCEEDED: StringName = &"succeeded"
const STATE_FAILED: StringName = &"failed"

const REASON_SNAPSHOT_CAPTURE_FAILED: StringName = &"snapshot_capture_failed"
const REASON_SAVE_COMMIT_FAILED: StringName = &"save_commit_failed"

signal status_changed(slot_index: int, status: Dictionary)

var _save_service: SaveService
var _guard: GameplayOperationGuard
var _next_request_id: int = 1
var _pending_by_slot: Dictionary = {}
var _status_by_slot: Dictionary = {}

func _init(save_service: SaveService, guard: GameplayOperationGuard) -> void:
    _save_service = save_service
    _guard = guard
    _guard.blocker_added.connect(_on_guard_changed)
    _guard.blocker_removed.connect(_on_guard_changed)

func request_save(slot_index: int, request_kind: StringName, snapshot_provider: Callable) -> Dictionary:
    var request_id: int = _next_request_id
    _next_request_id += 1

    if slot_index < 1 or slot_index > SaveService.SLOT_COUNT:
        return _failed_request_status(slot_index, request_id, request_kind, &"invalid_slot", "Save slot is invalid.", ERR_INVALID_PARAMETER)
    if not _is_supported_kind(request_kind):
        if _pending_by_slot.has(slot_index):
            return _make_status(slot_index, request_id, request_kind, STATE_FAILED, &"invalid_request_kind", "Save request kind is invalid.", ERR_INVALID_PARAMETER)
        return _failed_request_status(slot_index, request_id, request_kind, &"invalid_request_kind", "Save request kind is invalid.", ERR_INVALID_PARAMETER)
    if not snapshot_provider.is_valid():
        if _pending_by_slot.has(slot_index):
            return _make_status(slot_index, request_id, request_kind, STATE_FAILED, REASON_SNAPSHOT_CAPTURE_FAILED, "Snapshot provider is unavailable.", ERR_INVALID_PARAMETER)
        return _failed_request_status(slot_index, request_id, request_kind, REASON_SNAPSHOT_CAPTURE_FAILED, "Snapshot provider is unavailable.", ERR_INVALID_PARAMETER)

    var blockers: Array[Dictionary] = _guard.get_blocking_reasons(GameplayOperationGuard.OP_MANUAL_SAVE)
    if not blockers.is_empty():
        var blocker: Dictionary = blockers[0]
        if request_kind == REQUEST_MANUAL:
            return _failed_request_status(slot_index, request_id, request_kind, StringName(blocker["reason_id"]), String(blocker["reason_text"]), ERR_UNAVAILABLE)
        _pending_by_slot[slot_index] = {
            "request_id": request_id,
            "request_kind": request_kind,
            "snapshot_provider": snapshot_provider,
        }
        return _set_status(slot_index, request_id, request_kind, STATE_PENDING, StringName(blocker["reason_id"]), String(blocker["reason_text"]), OK)

    _pending_by_slot.erase(slot_index)
    return _commit(slot_index, request_id, request_kind, snapshot_provider)

func process_pending() -> void:
    var blockers: Array[Dictionary] = _guard.get_blocking_reasons(GameplayOperationGuard.OP_MANUAL_SAVE)
    if not blockers.is_empty():
        _refresh_pending_status()
        return

    var slots: Array = _pending_by_slot.keys()
    slots.sort()
    for slot_variant: Variant in slots:
        var slot_index: int = int(slot_variant)
        if not _pending_by_slot.has(slot_index):
            continue
        var pending: Dictionary = _pending_by_slot[slot_index]
        _pending_by_slot.erase(slot_index)
        _commit(
            slot_index,
            int(pending["request_id"]),
            StringName(pending["request_kind"]),
            pending["snapshot_provider"] as Callable
        )

func get_status(slot_index: int) -> Dictionary:
    if not _status_by_slot.has(slot_index):
        return {}
    return (_status_by_slot[slot_index] as Dictionary).duplicate(true)

func _commit(slot_index: int, request_id: int, request_kind: StringName, snapshot_provider: Callable) -> Dictionary:
    if not snapshot_provider.is_valid():
        return _set_status(slot_index, request_id, request_kind, STATE_FAILED, REASON_SNAPSHOT_CAPTURE_FAILED, "Snapshot provider is unavailable.", ERR_INVALID_PARAMETER)
    var captured: Variant = snapshot_provider.call()
    if not captured is ProfileSnapshot:
        return _set_status(slot_index, request_id, request_kind, STATE_FAILED, REASON_SNAPSHOT_CAPTURE_FAILED, "Snapshot provider did not return a ProfileSnapshot.", ERR_INVALID_DATA)

    var save_error: int = _save_service.save_profile(slot_index, captured as ProfileSnapshot)
    if save_error != OK:
        return _set_status(slot_index, request_id, request_kind, STATE_FAILED, REASON_SAVE_COMMIT_FAILED, "Save commit failed with error %d." % save_error, save_error)
    return _set_status(slot_index, request_id, request_kind, STATE_SUCCEEDED, &"", "", OK)

func _set_status(slot_index: int, request_id: int, request_kind: StringName, state: StringName, reason_id: StringName, reason_text: String, error_code: int) -> Dictionary:
    var status: Dictionary = _make_status(slot_index, request_id, request_kind, state, reason_id, reason_text, error_code)
    _status_by_slot[slot_index] = status
    status_changed.emit(slot_index, status.duplicate(true))
    return status.duplicate(true)

func _failed_request_status(slot_index: int, request_id: int, request_kind: StringName, reason_id: StringName, reason_text: String, error_code: int) -> Dictionary:
    if _pending_by_slot.has(slot_index):
        return _make_status(slot_index, request_id, request_kind, STATE_FAILED, reason_id, reason_text, error_code)
    return _set_status(slot_index, request_id, request_kind, STATE_FAILED, reason_id, reason_text, error_code)

func _make_status(slot_index: int, request_id: int, request_kind: StringName, state: StringName, reason_id: StringName, reason_text: String, error_code: int) -> Dictionary:
    return {
        "slot_index": slot_index,
        "request_id": request_id,
        "request_kind": request_kind,
        "state": state,
        "reason_id": reason_id,
        "reason_text": reason_text,
        "error_code": error_code,
    }

func _is_supported_kind(request_kind: StringName) -> bool:
    return request_kind == REQUEST_AUTOSAVE or request_kind == REQUEST_CHECKPOINT or request_kind == REQUEST_MANUAL

func _on_guard_changed(_token: int, _reason_id: StringName) -> void:
    _refresh_pending_status()

func _refresh_pending_status() -> void:
    var blockers: Array[Dictionary] = _guard.get_blocking_reasons(GameplayOperationGuard.OP_MANUAL_SAVE)
    var reason_id: StringName = &""
    var reason_text: String = ""
    if not blockers.is_empty():
        reason_id = StringName(blockers[0]["reason_id"])
        reason_text = String(blockers[0]["reason_text"])
    for slot_variant: Variant in _pending_by_slot.keys():
        var slot_index: int = int(slot_variant)
        var pending: Dictionary = _pending_by_slot[slot_index]
        _set_status(slot_index, int(pending["request_id"]), StringName(pending["request_kind"]), STATE_PENDING, reason_id, reason_text, OK)
