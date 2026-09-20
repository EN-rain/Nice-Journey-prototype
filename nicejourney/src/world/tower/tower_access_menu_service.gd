class_name TowerAccessMenuService
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_SIGIL_NOT_OWNED: StringName = &"sigil_not_owned"
const REASON_OPERATION_BLOCKED: StringName = &"operation_blocked"
const REASON_FLOOR_LOCKED: StringName = &"floor_locked"

static func build_menu(profile: ProfileSnapshot, operation_guard: GameplayOperationGuard = null) -> Dictionary:
    var context_reason := _context_reason(profile, operation_guard)
    if context_reason != &"":
        return _rejected(context_reason)
    if not PrototypeTowerFloorCatalog.validate_catalog().is_empty():
        return _rejected(REASON_INVALID_CONTEXT)

    var entries: Array[Dictionary] = []
    for floor_id: int in range(1, PrototypeTowerFloorCatalog.FLOOR_COUNT + 1):
        if not _is_selectable(profile, floor_id):
            continue
        entries.append(_entry(profile, floor_id))
    return {
        "accepted": true,
        "reason_id": &"",
        "entries": entries,
    }

static func validate_selection(profile: ProfileSnapshot, operation_guard: GameplayOperationGuard, floor_id: int) -> Dictionary:
    var context_reason := _context_reason(profile, operation_guard)
    if context_reason != &"":
        return _selection(false, context_reason, floor_id, {})
    if floor_id < 1 or floor_id > PrototypeTowerFloorCatalog.FLOOR_COUNT:
        return _selection(false, REASON_FLOOR_LOCKED, floor_id, {})
    if not _is_selectable(profile, floor_id):
        return _selection(false, REASON_FLOOR_LOCKED, floor_id, {})
    var entry := _entry(profile, floor_id)
    return _selection(true, &"", floor_id, entry)

static func _context_reason(profile: ProfileSnapshot, operation_guard: GameplayOperationGuard) -> StringName:
    if profile == null:
        return REASON_INVALID_CONTEXT
    if not Region3PreparationCommitService.has_tower_sigil(profile):
        return REASON_SIGIL_NOT_OWNED
    if operation_guard != null and not operation_guard.is_allowed(GameplayOperationGuard.OP_SIGIL_TRAVEL):
        return REASON_OPERATION_BLOCKED
    return &""

static func _is_selectable(profile: ProfileSnapshot, floor_id: int) -> bool:
    return _is_cleared(profile, floor_id) or bool(profile.permanent_flags.get("tower_floor_%d_unlocked" % floor_id, false))

static func _is_cleared(profile: ProfileSnapshot, floor_id: int) -> bool:
    if bool(profile.permanent_flags.get("tower_floor_%d_cleared" % floor_id, false)):
        return true
    var raw_floor: Variant = profile.tower_floor_states.get(str(floor_id), null)
    return raw_floor is Dictionary and bool((raw_floor as Dictionary).get("primary_cleared", false))

static func _entry(profile: ProfileSnapshot, floor_id: int) -> Dictionary:
    var catalog_entry := PrototypeTowerFloorCatalog.get_entry(floor_id)
    var recommended_level := int(catalog_entry["recommended_level"])
    var rank: DangerEvaluator.Rank = DangerEvaluator.evaluate_rank(profile.level, recommended_level)
    var active_quests := _active_quest_ids(profile, floor_id)
    var cleared := _is_cleared(profile, floor_id)
    return {
        "floor_id": floor_id,
        "recommended_level": recommended_level,
        "danger_rank": int(rank),
        "danger_display": DangerEvaluator.display_name(rank),
        "requires_danger_confirmation": DangerEvaluator.requires_explicit_travel_confirmation(rank),
        "cleared": cleared,
        "state": &"cleared" if cleared else &"unlocked_uncleared",
        "active_quest_ids": active_quests,
        "elite_warning": int(catalog_entry["elite_target"]) > 0,
        "elite_target": int(catalog_entry["elite_target"]),
        "boss_warning": bool(catalog_entry["boss"]),
    }

static func _active_quest_ids(profile: ProfileSnapshot, floor_id: int) -> Array[StringName]:
    var result: Array[StringName] = []
    for quest_id: StringName in TowerFloorGenerationCommitService.expected_quest_ids_for_floor(floor_id):
        var raw: Variant = profile.quest_progress.get(String(quest_id), null)
        if not raw is Dictionary:
            continue
        var state := StringName(String((raw as Dictionary).get("state", &"")))
        if state in [
            QuestProgressState.STATE_ACTIVE,
            QuestProgressState.STATE_SUSPENDED,
            QuestProgressState.STATE_RETRY_READY,
            QuestProgressState.STATE_OBJECTIVES_COMPLETE,
        ]:
            result.append(quest_id)
    result.sort()
    return result

static func _selection(accepted: bool, reason_id: StringName, floor_id: int, entry: Dictionary) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "floor_id": floor_id,
        "entry": entry.duplicate(true),
    }

static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "entries": [],
    }
