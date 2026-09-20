class_name TowerTravelCommitService
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_INVALID_PLAN: StringName = &"invalid_plan"
const REASON_STALE_SOURCE: StringName = &"stale_source_profile"
const REASON_SAVE_BOUNDARY_BLOCKED: StringName = &"save_boundary_blocked"
const REASON_RUNTIME_INVALID: StringName = &"destination_runtime_invalid"
const REASON_SAFE_STATE_INVALID: StringName = &"safe_state_invalid"
const REASON_SAVE_FAILED: StringName = &"save_failed"

static func prepare_runtime(plan: Dictionary, visual_catalog: TowerRoomVisualCatalog) -> Dictionary:
    if visual_catalog == null or not _plan_shape_valid(plan):
        return _runtime_rejected(REASON_INVALID_PLAN)
    var staged := ProfileSnapshot.from_dictionary(plan["staged_profile"] as Dictionary)
    if staged == null or not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _runtime_rejected(REASON_INVALID_PLAN)
    var floor_id := int(plan["floor_id"])
    var raw_floor: Variant = staged.tower_floor_states.get(str(floor_id), null)
    if not raw_floor is Dictionary:
        return _runtime_rejected(REASON_INVALID_PLAN)
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(raw_floor as Dictionary).is_empty() or floor_state.floor_id != floor_id:
        return _runtime_rejected(REASON_INVALID_PLAN)
    var arrival := TowerArrivalResolver.resolve_entrance(floor_state)
    if not bool(arrival.get("accepted", false)):
        return _runtime_rejected(REASON_RUNTIME_INVALID)
    var build := TowerFloorRuntimeComposer.build(floor_state.layout_manifest, visual_catalog)
    if not bool(build.get("accepted", false)):
        var rejected := _runtime_rejected(REASON_RUNTIME_INVALID)
        rejected["build_reason_id"] = StringName(build.get("reason_id", &""))
        rejected["build_errors"] = (build.get("errors", PackedStringArray()) as PackedStringArray).duplicate()
        return rejected
    var root := build.get("root") as Node2D
    if root == null or int(root.get_meta(&"floor_id", -1)) != floor_id:
        if root != null:
            root.free()
        return _runtime_rejected(REASON_RUNTIME_INVALID)
    return {
        "accepted": true,
        "reason_id": &"",
        "floor_id": floor_id,
        "arrival": arrival.duplicate(true),
        "runtime_root": root,
    }

static func commit(
    save_coordinator: SaveRequestCoordinator,
    slot_index: int,
    live_profile: ProfileSnapshot,
    operation_guard: GameplayOperationGuard,
    plan: Dictionary,
    runtime_preparation: Dictionary,
    player_state: Dictionary,
    quest_attempt_state: Dictionary,
    snapshot_sequence: int
) -> Dictionary:
    if save_coordinator == null or live_profile == null or operation_guard == null:
        return _commit_rejected(REASON_INVALID_CONTEXT)
    if not _plan_shape_valid(plan):
        return _commit_rejected(REASON_INVALID_PLAN)
    if live_profile.to_dictionary() != (plan["source_profile"] as Dictionary):
        return _commit_rejected(REASON_STALE_SOURCE)
    if not operation_guard.is_allowed(GameplayOperationGuard.OP_SIGIL_TRAVEL):
        return _commit_rejected(TowerAccessMenuService.REASON_OPERATION_BLOCKED)
    if not operation_guard.is_allowed(GameplayOperationGuard.OP_MANUAL_SAVE):
        return _commit_rejected(REASON_SAVE_BOUNDARY_BLOCKED)
    if not _runtime_matches_plan(plan, runtime_preparation):
        return _commit_rejected(REASON_RUNTIME_INVALID)
    if snapshot_sequence < 0:
        return _commit_rejected(REASON_SAFE_STATE_INVALID)

    var floor_id := int(plan["floor_id"])
    var arrival := runtime_preparation["arrival"] as Dictionary
    var safe_state := SafeCheckpointState.make(
        StringName("safe:tower_floor_%d_arrival" % floor_id),
        StringName("tower:floor_%d" % floor_id),
        floor_id,
        StringName(String(arrival.get("arrival_anchor_id", &""))),
        player_state,
        quest_attempt_state,
        snapshot_sequence
    )
    if safe_state.is_empty():
        return _commit_rejected(REASON_SAFE_STATE_INVALID)

    var provider := func() -> Variant:
        return _capture_fresh_snapshot(live_profile, plan, safe_state)
    var save_status := save_coordinator.request_save(
        slot_index,
        SaveRequestCoordinator.REQUEST_CHECKPOINT,
        provider
    )
    if StringName(save_status.get("state", &"")) != SaveRequestCoordinator.STATE_SUCCEEDED:
        var rejected := _commit_rejected(REASON_SAVE_FAILED)
        rejected["save_status"] = save_status.duplicate(true)
        return rejected

    var committed := _capture_fresh_snapshot(live_profile, plan, safe_state) as ProfileSnapshot
    if committed == null:
        return _commit_rejected(REASON_STALE_SOURCE)
    _apply_snapshot(live_profile, committed)
    return {
        "accepted": true,
        "reason_id": &"",
        "floor_id": floor_id,
        "arrival": arrival.duplicate(true),
        "safe_state": safe_state.duplicate(true),
        "runtime_root": runtime_preparation["runtime_root"],
        "save_status": save_status.duplicate(true),
    }

static func _capture_fresh_snapshot(live_profile: ProfileSnapshot, plan: Dictionary, safe_state: Dictionary) -> Variant:
    if live_profile == null or live_profile.to_dictionary() != (plan.get("source_profile", {}) as Dictionary):
        return null
    var staged_variant: Variant = plan.get("staged_profile", null)
    if not staged_variant is Dictionary:
        return null
    var staged := ProfileSnapshot.from_dictionary(staged_variant as Dictionary)
    if staged == null:
        return null
    staged.safe_state = safe_state.duplicate(true)
    if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return null
    return staged

static func _runtime_matches_plan(plan: Dictionary, runtime_preparation: Dictionary) -> bool:
    if not bool(runtime_preparation.get("accepted", false)):
        return false
    var floor_id := int(plan.get("floor_id", -1))
    if int(runtime_preparation.get("floor_id", -1)) != floor_id:
        return false
    var root := runtime_preparation.get("runtime_root") as Node2D
    if root == null or int(root.get_meta(&"floor_id", -1)) != floor_id:
        return false
    var planned_destination: Variant = plan.get("destination", null)
    if not planned_destination is Dictionary:
        return false
    var planned_arrival: Variant = (planned_destination as Dictionary).get("arrival", null)
    var runtime_arrival: Variant = runtime_preparation.get("arrival", null)
    return planned_arrival is Dictionary and runtime_arrival is Dictionary and (planned_arrival as Dictionary) == (runtime_arrival as Dictionary)

static func _plan_shape_valid(plan: Dictionary) -> bool:
    return (
        bool(plan.get("accepted", false))
        and bool(plan.get("ready_for_transfer_commit", false))
        and int(plan.get("floor_id", 0)) >= 1
        and int(plan.get("floor_id", 0)) <= 10
        and plan.get("source_profile", null) is Dictionary
        and plan.get("staged_profile", null) is Dictionary
        and plan.get("destination", null) is Dictionary
    )

static func _apply_snapshot(target: ProfileSnapshot, source: ProfileSnapshot) -> void:
    target.profile_id = source.profile_id
    target.protagonist_name = source.protagonist_name
    target.class_id = source.class_id
    target.level = source.level
    target.xp = source.xp
    target.skill_points = source.skill_points
    target.skill_state = source.skill_state.duplicate(true)
    target.item_state = source.item_state.duplicate(true)
    target.storage_state = source.storage_state.duplicate(true)
    target.equipment_state = source.equipment_state.duplicate(true)
    target.economy_state = source.economy_state.duplicate(true)
    target.tower_floor_states = source.tower_floor_states.duplicate(true)
    target.safe_state = source.safe_state.duplicate(true)
    target.quest_progress = source.quest_progress.duplicate(true)
    target.permanent_flags = source.permanent_flags.duplicate(true)
    target.claimed_transactions = source.claimed_transactions.duplicate(true)

static func _runtime_rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "floor_id": 0,
        "arrival": {},
        "runtime_root": null,
        "build_reason_id": &"",
        "build_errors": PackedStringArray(),
    }

static func _commit_rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "floor_id": 0,
        "arrival": {},
        "safe_state": {},
        "runtime_root": null,
        "save_status": {},
    }
