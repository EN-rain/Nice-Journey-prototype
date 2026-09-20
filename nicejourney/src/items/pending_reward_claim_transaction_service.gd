class_name PendingRewardClaimTransactionService
extends RefCounted

const REASON_INVALID_INPUT: StringName = &"invalid_input"
const REASON_OPERATION_BLOCKED: StringName = &"operation_blocked"
const REASON_PROFILE_INVALID: StringName = &"profile_invalid"
const REASON_PENDING_NOT_FOUND: StringName = &"pending_not_found"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"


static func claim(
    profile: ProfileSnapshot,
    operation_guard: GameplayOperationGuard,
    reward_claim_id: StringName,
    transaction_id: StringName
) -> Dictionary:
    if (
        profile == null
        or operation_guard == null
        or not StableId.is_valid(String(reward_claim_id))
        or not StableId.is_valid(String(transaction_id))
    ):
        return _result(false, REASON_INVALID_INPUT)

    var blocking_reasons := operation_guard.get_blocking_reasons(GameplayOperationGuard.OP_SERVICE)
    if not blocking_reasons.is_empty():
        return {
            "accepted": false,
            "reason_id": REASON_OPERATION_BLOCKED,
            "blocking_reasons": blocking_reasons.duplicate(true),
            "durable": false,
        }

    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null or not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _result(false, REASON_PROFILE_INVALID)
    if staged.item_state.is_empty() or staged.economy_state.is_empty():
        return _result(false, REASON_PENDING_NOT_FOUND)

    var inventory := InventoryState.new()
    var economy := EconomyState.new()
    var ledger := ClaimLedger.new()
    if not inventory.load_dictionary(staged.item_state).is_empty():
        return _result(false, REASON_PROFILE_INVALID)
    if not economy.load_dictionary(staged.economy_state).is_empty():
        return _result(false, REASON_PROFILE_INVALID)
    if not ledger.load_dictionary(staged.claimed_transactions).is_empty():
        return _result(false, REASON_PROFILE_INVALID)

    var claim_result := RewardGrantService.claim_pending_normal(
        inventory,
        economy,
        ledger,
        reward_claim_id,
        transaction_id
    )
    if not bool(claim_result.get("accepted", false)):
        var rejected := claim_result.duplicate(true)
        rejected["durable"] = false
        return rejected

    staged.item_state = inventory.to_dictionary()
    staged.economy_state = economy.to_dictionary()
    staged.claimed_transactions = ledger.to_dictionary()
    if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    profile.item_state = staged.item_state.duplicate(true)
    profile.economy_state = staged.economy_state.duplicate(true)
    profile.claimed_transactions = staged.claimed_transactions.duplicate(true)
    return {
        "accepted": true,
        "reason_id": &"",
        "reward_claim_id": reward_claim_id,
        "transaction_id": transaction_id,
        "durable": false,
        "durability_boundary": &"next_safe_snapshot",
    }


static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "durable": false,
    }
