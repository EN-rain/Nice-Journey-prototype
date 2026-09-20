class_name SkillProgressionService
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_INVALID_PROFILE_STATE: StringName = &"invalid_profile_state"
const REASON_INVALID_TRANSACTION_ID: StringName = &"invalid_transaction_id"
const REASON_DUPLICATE_TRANSACTION: StringName = &"duplicate_transaction"
const REASON_INSUFFICIENT_SKILL_POINTS: StringName = &"insufficient_skill_points"
const REASON_RANK_UNAVAILABLE: StringName = &"rank_unavailable"
const REASON_SAFE_INTERACTION_REQUIRED: StringName = &"safe_interaction_required"
const REASON_ACTIVE_COMBAT: StringName = &"active_combat"
const REASON_INVALID_LOADOUT_KIND: StringName = &"invalid_loadout_kind"
const REASON_LOADOUT_REJECTED: StringName = &"loadout_rejected"
const REASON_NO_CHANGE: StringName = &"no_change"
const REASON_CLAIM_REJECTED: StringName = &"claim_rejected"
const REASON_STAGED_PROFILE_INVALID: StringName = &"staged_profile_invalid"
const REASON_SAVE_FAILED: StringName = &"save_failed"

const LOADOUT_ACTIVE: StringName = &"active"
const LOADOUT_PASSIVE: StringName = &"passive"


static func ensure_initialized(profile: ProfileSnapshot) -> bool:
    if profile == null:
        return false
    if not profile.skill_state.is_empty():
        var existing_errors: PackedStringArray = SkillLoadoutState.validate_dictionary(profile.skill_state)
        if not existing_errors.is_empty():
            return false
        return String(profile.skill_state.get("class_id", "")) == profile.class_id
    var state: SkillLoadoutState = SkillLoadoutState.new()
    if not state.initialize_for_class(StringName(profile.class_id)):
        return false
    profile.skill_state = state.to_dictionary()
    return true


static func purchase_rank(profile: ProfileSnapshot, skill_id: StringName, transaction_id: StringName) -> bool:
    if profile == null or profile.skill_points <= 0 or not StableId.is_valid(String(transaction_id)):
        return false
    if not ensure_initialized(profile):
        return false

    var state: SkillLoadoutState = SkillLoadoutState.new()
    if not state.load_dictionary(profile.skill_state).is_empty():
        return false
    if not state.can_increase_rank(skill_id):
        return false

    var ledger: ClaimLedger = ClaimLedger.new()
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return false
    if ledger.is_claimed(transaction_id):
        return false
    var source_id: StringName = StringName("skill_progression:%s" % String(skill_id))
    if not ledger.try_claim(transaction_id, source_id):
        return false

    if not state.try_increase_rank(skill_id):
        return false
    profile.skill_points -= 1
    profile.skill_state = state.to_dictionary()
    profile.claimed_transactions = ledger.to_dictionary()
    return true


static func commit_rank_purchase(
    save_service: SaveService,
    slot_index: int,
    profile: ProfileSnapshot,
    skill_id: StringName,
    transaction_id: StringName
) -> Dictionary:
    if save_service == null or profile == null:
        return _commit_result(false, REASON_INVALID_CONTEXT, transaction_id, skill_id)
    if not StableId.is_valid(String(transaction_id)):
        return _commit_result(false, REASON_INVALID_TRANSACTION_ID, transaction_id, skill_id)
    if not ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty():
        return _commit_result(false, REASON_INVALID_PROFILE_STATE, transaction_id, skill_id)

    var ledger := ClaimLedger.new()
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return _commit_result(false, REASON_INVALID_PROFILE_STATE, transaction_id, skill_id)
    if ledger.is_claimed(transaction_id):
        return _commit_result(false, REASON_DUPLICATE_TRANSACTION, transaction_id, skill_id)
    if profile.skill_points <= 0:
        return _commit_result(false, REASON_INSUFFICIENT_SKILL_POINTS, transaction_id, skill_id)

    var current_state := SkillLoadoutState.new()
    if profile.skill_state.is_empty() or not current_state.load_dictionary(profile.skill_state).is_empty():
        return _commit_result(false, REASON_INVALID_PROFILE_STATE, transaction_id, skill_id)
    if not current_state.can_increase_rank(skill_id):
        return _commit_result(false, REASON_RANK_UNAVAILABLE, transaction_id, skill_id)

    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null or not purchase_rank(staged, skill_id, transaction_id):
        return _commit_result(false, REASON_RANK_UNAVAILABLE, transaction_id, skill_id)
    if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _commit_result(false, REASON_STAGED_PROFILE_INVALID, transaction_id, skill_id)

    var save_error := save_service.save_profile(slot_index, staged)
    if save_error != OK:
        return _commit_result(false, REASON_SAVE_FAILED, transaction_id, skill_id, &"", -1, save_error)

    _apply_persistent_skill_fields(profile, staged)
    return _commit_result(true, &"", transaction_id, skill_id, &"", -1, OK, true)


static func commit_active_swap(
    save_service: SaveService,
    save_slot_index: int,
    profile: ProfileSnapshot,
    loadout_slot_index: int,
    skill_id: StringName,
    transaction_id: StringName,
    safe_interaction: bool,
    active_combat: bool
) -> Dictionary:
    return _commit_loadout_swap(
        save_service,
        save_slot_index,
        profile,
        loadout_slot_index,
        skill_id,
        transaction_id,
        safe_interaction,
        active_combat,
        LOADOUT_ACTIVE
    )


static func commit_passive_swap(
    save_service: SaveService,
    save_slot_index: int,
    profile: ProfileSnapshot,
    loadout_slot_index: int,
    skill_id: StringName,
    transaction_id: StringName,
    safe_interaction: bool,
    active_combat: bool
) -> Dictionary:
    return _commit_loadout_swap(
        save_service,
        save_slot_index,
        profile,
        loadout_slot_index,
        skill_id,
        transaction_id,
        safe_interaction,
        active_combat,
        LOADOUT_PASSIVE
    )


static func equip_active(profile: ProfileSnapshot, slot_index: int, skill_id: StringName, safe_interaction: bool, active_combat: bool) -> bool:
    return _equip(profile, slot_index, skill_id, safe_interaction, active_combat, true)


static func equip_passive(profile: ProfileSnapshot, slot_index: int, skill_id: StringName, safe_interaction: bool, active_combat: bool) -> bool:
    return _equip(profile, slot_index, skill_id, safe_interaction, active_combat, false)


static func begin_temporary_active(profile: ProfileSnapshot, slot_index: int, temporary_skill_id: StringName) -> bool:
    if profile == null or not ensure_initialized(profile):
        return false
    var state: SkillLoadoutState = SkillLoadoutState.new()
    if not state.load_dictionary(profile.skill_state).is_empty():
        return false
    if not state.begin_temporary_active(slot_index, temporary_skill_id):
        return false
    profile.skill_state = state.to_dictionary()
    return true


static func end_temporary_active(profile: ProfileSnapshot) -> bool:
    if profile == null or not ensure_initialized(profile):
        return false
    var state: SkillLoadoutState = SkillLoadoutState.new()
    if not state.load_dictionary(profile.skill_state).is_empty():
        return false
    if not state.end_temporary_active():
        return false
    profile.skill_state = state.to_dictionary()
    return true


static func _equip(profile: ProfileSnapshot, slot_index: int, skill_id: StringName, safe_interaction: bool, active_combat: bool, active: bool) -> bool:
    if profile == null or not ensure_initialized(profile):
        return false
    var state: SkillLoadoutState = SkillLoadoutState.new()
    if not state.load_dictionary(profile.skill_state).is_empty():
        return false
    var accepted: bool = state.equip_active(slot_index, skill_id, safe_interaction, active_combat) if active else state.equip_passive(slot_index, skill_id, safe_interaction, active_combat)
    if not accepted:
        return false
    profile.skill_state = state.to_dictionary()
    return true


static func _commit_loadout_swap(
    save_service: SaveService,
    save_slot_index: int,
    profile: ProfileSnapshot,
    loadout_slot_index: int,
    skill_id: StringName,
    transaction_id: StringName,
    safe_interaction: bool,
    active_combat: bool,
    loadout_kind: StringName
) -> Dictionary:
    if save_service == null or profile == null:
        return _commit_result(false, REASON_INVALID_CONTEXT, transaction_id, skill_id, loadout_kind, loadout_slot_index)
    if not StableId.is_valid(String(transaction_id)):
        return _commit_result(false, REASON_INVALID_TRANSACTION_ID, transaction_id, skill_id, loadout_kind, loadout_slot_index)
    if loadout_kind != LOADOUT_ACTIVE and loadout_kind != LOADOUT_PASSIVE:
        return _commit_result(false, REASON_INVALID_LOADOUT_KIND, transaction_id, skill_id, loadout_kind, loadout_slot_index)
    if not safe_interaction:
        return _commit_result(false, REASON_SAFE_INTERACTION_REQUIRED, transaction_id, skill_id, loadout_kind, loadout_slot_index)
    if active_combat:
        return _commit_result(false, REASON_ACTIVE_COMBAT, transaction_id, skill_id, loadout_kind, loadout_slot_index)
    if not ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty():
        return _commit_result(false, REASON_INVALID_PROFILE_STATE, transaction_id, skill_id, loadout_kind, loadout_slot_index)

    var ledger := ClaimLedger.new()
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return _commit_result(false, REASON_INVALID_PROFILE_STATE, transaction_id, skill_id, loadout_kind, loadout_slot_index)
    if ledger.is_claimed(transaction_id):
        return _commit_result(false, REASON_DUPLICATE_TRANSACTION, transaction_id, skill_id, loadout_kind, loadout_slot_index)

    var current_state := SkillLoadoutState.new()
    if profile.skill_state.is_empty() or not current_state.load_dictionary(profile.skill_state).is_empty():
        return _commit_result(false, REASON_INVALID_PROFILE_STATE, transaction_id, skill_id, loadout_kind, loadout_slot_index)
    var current_slots: Array[StringName] = current_state.active_slots if loadout_kind == LOADOUT_ACTIVE else current_state.passive_slots
    if loadout_slot_index >= 0 and loadout_slot_index < current_slots.size() and current_slots[loadout_slot_index] == skill_id:
        return _commit_result(false, REASON_NO_CHANGE, transaction_id, skill_id, loadout_kind, loadout_slot_index)

    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null:
        return _commit_result(false, REASON_INVALID_PROFILE_STATE, transaction_id, skill_id, loadout_kind, loadout_slot_index)
    var swapped := equip_active(staged, loadout_slot_index, skill_id, safe_interaction, active_combat) if loadout_kind == LOADOUT_ACTIVE else equip_passive(staged, loadout_slot_index, skill_id, safe_interaction, active_combat)
    if not swapped:
        return _commit_result(false, REASON_LOADOUT_REJECTED, transaction_id, skill_id, loadout_kind, loadout_slot_index)

    var staged_ledger := ClaimLedger.new()
    if not staged_ledger.load_dictionary(staged.claimed_transactions).is_empty():
        return _commit_result(false, REASON_INVALID_PROFILE_STATE, transaction_id, skill_id, loadout_kind, loadout_slot_index)
    var source_id := StringName("skill_loadout:%s:%d:%s" % [String(loadout_kind), loadout_slot_index, String(skill_id)])
    if not staged_ledger.try_claim(transaction_id, source_id):
        return _commit_result(false, REASON_CLAIM_REJECTED, transaction_id, skill_id, loadout_kind, loadout_slot_index)
    staged.claimed_transactions = staged_ledger.to_dictionary()

    if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _commit_result(false, REASON_STAGED_PROFILE_INVALID, transaction_id, skill_id, loadout_kind, loadout_slot_index)
    var save_error := save_service.save_profile(save_slot_index, staged)
    if save_error != OK:
        return _commit_result(false, REASON_SAVE_FAILED, transaction_id, skill_id, loadout_kind, loadout_slot_index, save_error)

    _apply_persistent_skill_fields(profile, staged)
    return _commit_result(true, &"", transaction_id, skill_id, loadout_kind, loadout_slot_index, OK, true)


static func _apply_persistent_skill_fields(profile: ProfileSnapshot, staged: ProfileSnapshot) -> void:
    profile.skill_points = staged.skill_points
    profile.skill_state = staged.skill_state.duplicate(true)
    profile.claimed_transactions = staged.claimed_transactions.duplicate(true)


static func _commit_result(
    accepted: bool,
    reason_id: StringName,
    transaction_id: StringName,
    skill_id: StringName,
    loadout_kind: StringName = &"",
    loadout_slot_index: int = -1,
    save_error: int = OK,
    durable: bool = false
) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "transaction_id": transaction_id,
        "skill_id": skill_id,
        "loadout_kind": loadout_kind,
        "loadout_slot_index": loadout_slot_index,
        "save_error": save_error,
        "durable": durable,
    }
