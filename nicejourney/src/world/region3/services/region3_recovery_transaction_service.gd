class_name Region3RecoveryTransactionService
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_DEFINITION_INVALID: StringName = &"definition_invalid"
const REASON_SERVICE_UNAVAILABLE: StringName = &"service_unavailable"
const REASON_COMBAT_RESTRICTED: StringName = &"combat_restricted"
const REASON_RECOVERY_PAYLOAD_UNAVAILABLE: StringName = &"recovery_payload_unavailable"
const REASON_TRANSACTION_ID_INVALID: StringName = &"transaction_id_invalid"
const REASON_DUPLICATE_TRANSACTION: StringName = &"duplicate_transaction"
const REASON_INVENTORY_INVALID: StringName = &"inventory_invalid"
const REASON_INSUFFICIENT_GOLD: StringName = &"insufficient_gold"
const REASON_STAGED_PROFILE_INVALID: StringName = &"staged_profile_invalid"
const REASON_ATOMIC_COMMIT_OWNER_MISSING: StringName = &"atomic_commit_owner_missing"
const REASON_ATOMIC_COMMIT_REJECTED: StringName = &"atomic_commit_rejected"
const REASON_ATOMIC_COMMIT_RECEIPT_INVALID: StringName = &"atomic_commit_receipt_invalid"

const COMMIT_INPUT_STAGED_PROFILE_KEY: String = "staged_profile"
const COMMIT_INPUT_RECOVERY_AMOUNTS_KEY: String = "recovery_amounts"
const COMMIT_INPUT_SAVE_EVENT_ID_KEY: String = "save_event_id"
const COMMIT_RECEIPT_ACCEPTED_KEY: String = "accepted"
const COMMIT_RECEIPT_DURABLE_KEY: String = "durable"
const COMMIT_RECEIPT_PROFILE_COMMITTED_KEY: String = "profile_committed"
const COMMIT_RECEIPT_RECOVERY_COMMITTED_KEY: String = "recovery_committed"
const COMMIT_RECEIPT_TRANSACTION_ID_KEY: String = "transaction_id"


static func prepare(
    profile: ProfileSnapshot,
    definition: Dictionary,
    transaction_id: StringName,
    active_combat: bool
) -> Dictionary:
    if profile == null:
        return _rejected(REASON_INVALID_CONTEXT, transaction_id)
    var definition_errors := Region3RecoveryServiceDefinition.validate_dictionary(definition)
    if not definition_errors.is_empty():
        var invalid := _rejected(REASON_DEFINITION_INVALID, transaction_id)
        invalid["definition_errors"] = definition_errors.duplicate()
        return invalid
    if not bool(definition.get("available", false)):
        return _rejected(REASON_SERVICE_UNAVAILABLE, transaction_id)
    if bool(definition.get("combat_restricted", false)) and active_combat:
        return _rejected(REASON_COMBAT_RESTRICTED, transaction_id)
    if not StableId.is_valid(String(transaction_id)):
        return _rejected(REASON_TRANSACTION_ID_INVALID, transaction_id)
    var recovery_variant: Variant = definition.get("recovery_amounts", null)
    if not recovery_variant is Dictionary or (recovery_variant as Dictionary).is_empty():
        return _rejected(REASON_RECOVERY_PAYLOAD_UNAVAILABLE, transaction_id)

    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null or not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _rejected(REASON_INVALID_CONTEXT, transaction_id)

    var inventory := InventoryState.new()
    if not staged.item_state.is_empty() and not inventory.load_dictionary(staged.item_state).is_empty():
        return _rejected(REASON_INVENTORY_INVALID, transaction_id)
    var ledger := ClaimLedger.new()
    if not ledger.load_dictionary(staged.claimed_transactions).is_empty():
        return _rejected(REASON_INVALID_CONTEXT, transaction_id)
    if ledger.is_claimed(transaction_id):
        return _rejected(REASON_DUPLICATE_TRANSACTION, transaction_id)

    var price_variant: Variant = definition.get("price_gold", null)
    var price_gold := int(price_variant) if price_variant != null else 0
    if not inventory.spend_gold(price_gold):
        return _rejected(REASON_INSUFFICIENT_GOLD, transaction_id)
    if not ledger.try_claim(transaction_id, StringName(String(definition.get("service_id", &"")))):
        return _rejected(REASON_DUPLICATE_TRANSACTION, transaction_id)

    staged.item_state = inventory.to_dictionary()
    staged.claimed_transactions = ledger.to_dictionary()
    if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _rejected(REASON_STAGED_PROFILE_INVALID, transaction_id)

    return {
        "accepted": true,
        "reason_id": &"",
        "transaction_id": transaction_id,
        "service_id": StringName(String(definition.get("service_id", &""))),
        "role_id": StringName(String(definition.get("role_id", &""))),
        "price_gold": price_gold,
        COMMIT_INPUT_RECOVERY_AMOUNTS_KEY: (recovery_variant as Dictionary).duplicate(true),
        COMMIT_INPUT_SAVE_EVENT_ID_KEY: StringName(String(definition.get("save_event_id", &""))) if definition.get("save_event_id", null) != null else &"",
        COMMIT_INPUT_STAGED_PROFILE_KEY: staged.to_dictionary().duplicate(true),
        "requires_atomic_profile_commit": true,
        "requires_atomic_recovery_commit": true,
        "durable": false,
        "definition_errors": PackedStringArray(),
    }


# Public integration contract for the atomic owner:
# - The callback receives a deep copy of the prepared transaction.
# - COMMIT_INPUT_RECOVERY_AMOUNTS_KEY is authored stable resource ID -> amount data.
#   The caller owns mapping those IDs to concrete runtime resources.
# - COMMIT_INPUT_STAGED_PROFILE_KEY already contains the Gold deduction and claim.
# - COMMIT_INPUT_SAVE_EVENT_ID_KEY is authored metadata only; this service assigns no behavior to it.
# - The callback must make its caller-owned profile/recovery changes all-or-nothing before
#   returning accepted=true. On rejection it must leave or restore caller-owned state itself.
# - An accepted receipt must use the COMMIT_RECEIPT_* keys and confirm durable profile and
#   recovery commit for the exact transaction ID.
static func commit(
    profile: ProfileSnapshot,
    definition: Dictionary,
    transaction_id: StringName,
    active_combat: bool,
    atomic_commit_owner: Callable
) -> Dictionary:
    if not atomic_commit_owner.is_valid():
        return _rejected(REASON_ATOMIC_COMMIT_OWNER_MISSING, transaction_id)
    var prepared := prepare(profile, definition, transaction_id, active_combat)
    if not bool(prepared.get("accepted", false)):
        return prepared

    # Validate every service-owned staged invariant before the external owner can commit.
    # After a valid durable receipt, this function has no remaining rejection path.
    var staged := _validated_staged_profile(prepared, transaction_id)
    if staged == null:
        return _rejected(REASON_STAGED_PROFILE_INVALID, transaction_id)

    var raw_receipt: Variant = atomic_commit_owner.call(prepared.duplicate(true))
    if not raw_receipt is Dictionary:
        return _rejected(REASON_ATOMIC_COMMIT_RECEIPT_INVALID, transaction_id)
    var receipt := raw_receipt as Dictionary
    if not bool(receipt.get(COMMIT_RECEIPT_ACCEPTED_KEY, false)):
        var rejected := _rejected(REASON_ATOMIC_COMMIT_REJECTED, transaction_id)
        rejected["commit_receipt"] = receipt.duplicate(true)
        return rejected
    if not _receipt_confirms_atomic_commit(receipt, transaction_id):
        var invalid_receipt := _rejected(REASON_ATOMIC_COMMIT_RECEIPT_INVALID, transaction_id)
        invalid_receipt["commit_receipt"] = receipt.duplicate(true)
        return invalid_receipt

    profile.item_state = staged.item_state.duplicate(true)
    profile.claimed_transactions = staged.claimed_transactions.duplicate(true)

    var result := prepared.duplicate(true)
    result["durable"] = true
    result["commit_receipt"] = receipt.duplicate(true)
    return result


static func _validated_staged_profile(prepared: Dictionary, transaction_id: StringName) -> ProfileSnapshot:
    var staged_payload: Variant = prepared.get(COMMIT_INPUT_STAGED_PROFILE_KEY, null)
    if not staged_payload is Dictionary:
        return null
    var staged := ProfileSnapshot.from_dictionary(staged_payload as Dictionary)
    if staged == null or not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return null
    var staged_ledger := ClaimLedger.new()
    if not staged_ledger.load_dictionary(staged.claimed_transactions).is_empty():
        return null
    if not staged_ledger.is_claimed(transaction_id):
        return null
    return staged


static func _receipt_confirms_atomic_commit(receipt: Dictionary, transaction_id: StringName) -> bool:
    var receipt_transaction_id: Variant = receipt.get(COMMIT_RECEIPT_TRANSACTION_ID_KEY, null)
    if typeof(receipt_transaction_id) != TYPE_STRING and typeof(receipt_transaction_id) != TYPE_STRING_NAME:
        return false
    return (
        _is_true_bool(receipt, COMMIT_RECEIPT_ACCEPTED_KEY)
        and _is_true_bool(receipt, COMMIT_RECEIPT_DURABLE_KEY)
        and _is_true_bool(receipt, COMMIT_RECEIPT_PROFILE_COMMITTED_KEY)
        and _is_true_bool(receipt, COMMIT_RECEIPT_RECOVERY_COMMITTED_KEY)
        and StringName(String(receipt_transaction_id)) == transaction_id
    )


static func _is_true_bool(data: Dictionary, key: String) -> bool:
    var value: Variant = data.get(key, null)
    return typeof(value) == TYPE_BOOL and bool(value)


static func _rejected(reason_id: StringName, transaction_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "transaction_id": transaction_id,
        "durable": false,
        "definition_errors": PackedStringArray(),
    }
