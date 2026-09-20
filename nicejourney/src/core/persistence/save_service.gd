class_name SaveService
extends RefCounted

const DEFAULT_SAVE_ROOT: String = "user://saves"
const SLOT_COUNT: int = 3

var _save_root: String = DEFAULT_SAVE_ROOT

func _init(save_root: String = DEFAULT_SAVE_ROOT) -> void:
    _save_root = save_root

func save_profile(slot_index: int, profile: ProfileSnapshot) -> int:
    if not _is_valid_slot(slot_index):
        return ERR_INVALID_PARAMETER

    var payload: Dictionary = profile.to_dictionary()
    var validation_errors: PackedStringArray = ProfileSnapshot.validate_dictionary(payload)
    if not validation_errors.is_empty():
        push_error("Save rejected: %s" % ", ".join(validation_errors))
        return ERR_INVALID_DATA

    var root_error: int = DirAccess.make_dir_recursive_absolute(_absolute_root())
    if root_error != OK and root_error != ERR_ALREADY_EXISTS:
        return root_error

    var current_path: String = _slot_path(slot_index)
    var temporary_path: String = current_path + ".tmp"
    var backup_path: String = current_path + ".bak"

    var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(payload, "\t", true))
    file.flush()
    file.close()

    var verify_payload: Dictionary = _read_dictionary(temporary_path)
    if verify_payload.is_empty():
        _remove_if_exists(temporary_path)
        return ERR_FILE_CORRUPT
    var verify_errors: PackedStringArray = ProfileSnapshot.validate_dictionary(verify_payload)
    if not verify_errors.is_empty():
        _remove_if_exists(temporary_path)
        return ERR_INVALID_DATA

    var absolute_current: String = ProjectSettings.globalize_path(current_path)
    var absolute_temporary: String = ProjectSettings.globalize_path(temporary_path)
    var absolute_backup: String = ProjectSettings.globalize_path(backup_path)

    _remove_if_exists(backup_path)
    if FileAccess.file_exists(current_path):
        var backup_error: int = DirAccess.rename_absolute(absolute_current, absolute_backup)
        if backup_error != OK:
            _remove_if_exists(temporary_path)
            return backup_error

    var commit_error: int = DirAccess.rename_absolute(absolute_temporary, absolute_current)
    if commit_error != OK:
        if FileAccess.file_exists(backup_path):
            DirAccess.rename_absolute(absolute_backup, absolute_current)
        _remove_if_exists(temporary_path)
        return commit_error

    return OK

func load_profile(slot_index: int) -> ProfileSnapshot:
    if not _is_valid_slot(slot_index):
        push_error("Invalid save slot: %d" % slot_index)
        return null
    var result: Dictionary = load_profile_with_status(slot_index)
    return result.get("profile") as ProfileSnapshot

func load_profile_with_status(slot_index: int) -> Dictionary:
    if not _is_valid_slot(slot_index):
        return {
            "slot_index": slot_index,
            "state": &"failed",
            "reason_id": &"invalid_slot",
            "loaded_from": &"",
            "profile": null,
            "current": {},
            "backup": {},
        }

    var current_path: String = _slot_path(slot_index)
    var current: Dictionary = _read_generation_status(current_path)
    var backup: Dictionary = _read_generation_status(current_path + ".bak")
    if StringName(current.get("state", &"")) == &"valid":
        return _make_load_result(slot_index, &"current", current, backup)

    if StringName(backup.get("state", &"")) == &"valid":
        return _make_load_result(slot_index, &"backup", current, backup)

    return {
        "slot_index": slot_index,
        "state": &"unavailable",
        "reason_id": &"no_valid_generation",
        "loaded_from": &"",
        "profile": null,
        "current": _public_generation_status(current),
        "backup": _public_generation_status(backup),
    }

func delete_slot(slot_index: int) -> int:
    if not _is_valid_slot(slot_index):
        return ERR_INVALID_PARAMETER
    _remove_if_exists(_slot_path(slot_index))
    _remove_if_exists(_slot_path(slot_index) + ".tmp")
    _remove_if_exists(_slot_path(slot_index) + ".bak")
    return OK

func _is_valid_slot(slot_index: int) -> bool:
    return slot_index >= 1 and slot_index <= SLOT_COUNT

func _absolute_root() -> String:
    return ProjectSettings.globalize_path(_save_root)

func _slot_path(slot_index: int) -> String:
    return "%s/slot_%d.json" % [_save_root, slot_index]

func _read_dictionary(path: String) -> Dictionary:
    var status: Dictionary = _read_generation_status(path)
    if StringName(status.get("state", &"")) != &"valid":
        return {}
    return (status.get("payload", {}) as Dictionary).duplicate(true)

func _read_generation_status(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return _missing_generation_status()
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {
            "state": &"corrupt",
            "reason_id": &"open_failed",
            "validation_errors": PackedStringArray(),
            "payload": {},
        }
    var text: String = file.get_as_text()
    file.close()
    var parser: JSON = JSON.new()
    if parser.parse(text) != OK:
        return {
            "state": &"corrupt",
            "reason_id": &"json_parse_failed",
            "validation_errors": PackedStringArray(),
            "payload": {},
        }
    var parsed: Variant = parser.data
    if not parsed is Dictionary:
        return {
            "state": &"corrupt",
            "reason_id": &"root_not_dictionary",
            "validation_errors": PackedStringArray(),
            "payload": {},
        }
    var payload: Dictionary = (parsed as Dictionary).duplicate(true)
    var errors: PackedStringArray = ProfileSnapshot.validate_dictionary(payload)
    if not errors.is_empty():
        return {
            "state": &"incompatible",
            "reason_id": &"profile_validation_failed",
            "validation_errors": errors.duplicate(),
            "payload": {},
        }
    return {
        "state": &"valid",
        "reason_id": &"",
        "validation_errors": PackedStringArray(),
        "payload": payload,
    }

func _make_load_result(slot_index: int, loaded_from: StringName, current: Dictionary, backup: Dictionary) -> Dictionary:
    var selected: Dictionary = current if loaded_from == &"current" else backup
    var payload: Dictionary = selected.get("payload", {}) as Dictionary
    return {
        "slot_index": slot_index,
        "state": &"loaded",
        "reason_id": &"",
        "loaded_from": loaded_from,
        "profile": ProfileSnapshot.from_dictionary(payload),
        "current": _public_generation_status(current),
        "backup": _public_generation_status(backup),
    }

func _public_generation_status(status: Dictionary) -> Dictionary:
    return {
        "state": StringName(status.get("state", &"missing")),
        "reason_id": StringName(status.get("reason_id", &"missing")),
        "validation_errors": (status.get("validation_errors", PackedStringArray()) as PackedStringArray).duplicate(),
    }

func _missing_generation_status() -> Dictionary:
    return {
        "state": &"missing",
        "reason_id": &"missing",
        "validation_errors": PackedStringArray(),
        "payload": {},
    }

func _remove_if_exists(path: String) -> void:
    if not FileAccess.file_exists(path):
        return
    var absolute_path: String = ProjectSettings.globalize_path(path)
    DirAccess.remove_absolute(absolute_path)
