class_name DeathRetryCoordinator
extends RefCounted

const OUTCOME_ONGOING: StringName = &"ongoing"
const OUTCOME_DEATH_FAILURE: StringName = &"death_failure"
const OUTCOME_RETRY_RESTORED: StringName = &"retry_restored"
const OUTCOME_BOSS_VICTORY_PENDING_COMMIT: StringName = &"boss_victory_pending_commit"


static func retry_failed_attempt(save_service: SaveService, slot_index: int) -> Dictionary:
    var restored: Dictionary = _restore_latest_safe(save_service, slot_index)
    if not bool(restored.get("accepted", false)):
        return restored
    restored["attempt_outcome"] = OUTCOME_RETRY_RESTORED
    restored["death_fee"] = 0
    restored["boss_clear_committed"] = false
    restored["boss_reward_committed"] = false
    return restored


static func resolve_attempt_end(save_service: SaveService, slot_index: int, player_defeated: bool, boss_defeated: bool) -> Dictionary:
    if player_defeated:
        var restored: Dictionary = _restore_latest_safe(save_service, slot_index)
        if not bool(restored.get("accepted", false)):
            return restored
        restored["attempt_outcome"] = OUTCOME_DEATH_FAILURE
        restored["simultaneous_boss_defeat"] = boss_defeated
        restored["death_fee"] = 0
        restored["boss_clear_committed"] = false
        restored["boss_reward_committed"] = false
        return restored
    if boss_defeated:
        return {
            "accepted": true,
            "reason_id": &"",
            "attempt_outcome": OUTCOME_BOSS_VICTORY_PENDING_COMMIT,
            "profile": null,
            "safe_state": {},
            "death_fee": 0,
            "boss_clear_committed": false,
            "boss_reward_committed": false,
            "simultaneous_boss_defeat": false,
        }
    return {
        "accepted": true,
        "reason_id": &"",
        "attempt_outcome": OUTCOME_ONGOING,
        "profile": null,
        "safe_state": {},
        "death_fee": 0,
        "boss_clear_committed": false,
        "boss_reward_committed": false,
        "simultaneous_boss_defeat": false,
    }


static func _restore_latest_safe(save_service: SaveService, slot_index: int) -> Dictionary:
    if save_service == null:
        return _rejected(&"save_service_unavailable")
    var load_result: Dictionary = save_service.load_profile_with_status(slot_index)
    var profile: ProfileSnapshot = load_result.get("profile") as ProfileSnapshot
    if profile == null:
        return _rejected(StringName(load_result.get("reason_id", &"no_valid_generation")))
    if profile.safe_state.is_empty():
        return _rejected(&"no_committed_safe_snapshot")
    var safe_errors: PackedStringArray = SafeCheckpointState.validate_dictionary(profile.safe_state)
    if not safe_errors.is_empty():
        return _rejected(&"invalid_committed_safe_snapshot")
    return {
        "accepted": true,
        "reason_id": &"",
        "profile": profile,
        "safe_state": profile.safe_state.duplicate(true),
        "death_anchor_id": StringName(String(profile.safe_state.get("checkpoint_anchor_id", ""))),
        "floor_id": int(profile.safe_state.get("floor_id", 0)),
        "loaded_from": load_result.get("loaded_from", &""),
    }


static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "attempt_outcome": &"rejected",
        "profile": null,
        "safe_state": {},
        "death_fee": 0,
        "boss_clear_committed": false,
        "boss_reward_committed": false,
        "simultaneous_boss_defeat": false,
    }
