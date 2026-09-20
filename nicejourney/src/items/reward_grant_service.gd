class_name RewardGrantService
extends RefCounted

const REASON_INVALID_INPUT: StringName = &"invalid_input"
const REASON_DUPLICATE_CLAIM: StringName = &"duplicate_claim"
const REASON_INVALID_REWARD: StringName = &"invalid_reward"
const REASON_PENDING_NOT_FOUND: StringName = &"pending_not_found"
const REASON_INVENTORY_FULL: StringName = &"inventory_full"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"


static func grant_bundle(
    inventory: InventoryState,
    economy: EconomyState,
    ledger: ClaimLedger,
    claim_id: StringName,
    source_id: StringName,
    gold_amount: int,
    protected_rewards: Array,
    normal_rewards: Array
) -> Dictionary:
    if inventory == null or economy == null or ledger == null:
        return _result(false, REASON_INVALID_INPUT)
    if not StableId.is_valid(String(claim_id)) or not StableId.is_valid(String(source_id)) or gold_amount < 0:
        return _result(false, REASON_INVALID_INPUT)
    if ledger.is_claimed(claim_id) or economy.pending_reward_claims.has(String(claim_id)):
        return _result(false, REASON_DUPLICATE_CLAIM)

    var temp_inventory := _clone_inventory(inventory)
    var temp_economy := _clone_economy(economy)
    var temp_ledger := _clone_ledger(ledger)
    if temp_inventory == null or temp_economy == null or temp_ledger == null:
        return _result(false, REASON_COMMIT_FAILED)

    if not temp_inventory.add_gold(gold_amount):
        return _result(false, REASON_INVALID_REWARD)
    for raw_reward: Variant in protected_rewards:
        if not raw_reward is Dictionary:
            return _result(false, REASON_INVALID_REWARD)
        var reward: Dictionary = raw_reward as Dictionary
        var raw_item_id: Variant = reward.get("item_id", null)
        if not (typeof(raw_item_id) == TYPE_STRING or typeof(raw_item_id) == TYPE_STRING_NAME):
            return _result(false, REASON_INVALID_REWARD)
        var item_id := StringName(String(raw_item_id))
        if not StableId.is_valid(String(item_id)) or typeof(reward.get("tower_sigil", null)) != TYPE_BOOL:
            return _result(false, REASON_INVALID_REWARD)
        if not temp_inventory.grant_protected(item_id, bool(reward["tower_sigil"])):
            return _result(false, REASON_INVALID_REWARD)

    var normal_candidate := _clone_inventory(temp_inventory)
    if normal_candidate == null:
        return _result(false, REASON_COMMIT_FAILED)
    var normal_pending := false
    for raw_reward: Variant in normal_rewards:
        if not raw_reward is Dictionary:
            return _result(false, REASON_INVALID_REWARD)
        var reward: Dictionary = raw_reward as Dictionary
        if not _valid_normal_reward(reward):
            return _result(false, REASON_INVALID_REWARD)
        var add: Dictionary = normal_candidate.try_add_normal(
            StringName(String(reward["item_instance_id"])),
            StringName(String(reward["definition_id"])),
            int(reward["quantity"]),
            bool(reward["stackable"])
        )
        if bool(add.get("accepted", false)):
            continue
        if StringName(add.get("reason_id", &"")) == InventoryState.REASON_INVENTORY_FULL:
            normal_pending = true
            break
        return {
            "accepted": false,
            "reason_id": REASON_INVALID_REWARD,
            "inventory_reason_id": StringName(add.get("reason_id", &"")),
        }

    if normal_pending:
        if not temp_economy.add_pending_reward(claim_id, source_id, normal_rewards):
            return _result(false, REASON_COMMIT_FAILED)
    else:
        temp_inventory = normal_candidate

    if not temp_ledger.try_claim(claim_id, source_id):
        return _result(false, REASON_DUPLICATE_CLAIM)
    if not _commit_clones(inventory, economy, ledger, temp_inventory, temp_economy, temp_ledger):
        return _result(false, REASON_COMMIT_FAILED)

    return {
        "accepted": true,
        "reason_id": &"",
        "claim_id": claim_id,
        "normal_rewards_pending": normal_pending,
        "message_id": &"reward_waiting_inventory_full" if normal_pending else &"reward_committed",
    }


static func claim_pending_normal(
    inventory: InventoryState,
    economy: EconomyState,
    ledger: ClaimLedger,
    reward_claim_id: StringName,
    transaction_id: StringName
) -> Dictionary:
    if inventory == null or economy == null or ledger == null:
        return _result(false, REASON_INVALID_INPUT)
    if not StableId.is_valid(String(reward_claim_id)) or not StableId.is_valid(String(transaction_id)):
        return _result(false, REASON_INVALID_INPUT)
    if ledger.is_claimed(transaction_id):
        return _result(false, REASON_DUPLICATE_CLAIM)
    var pending: Dictionary = economy.get_pending_reward(reward_claim_id)
    if pending.is_empty():
        return _result(false, REASON_PENDING_NOT_FOUND)

    var temp_inventory := _clone_inventory(inventory)
    var temp_economy := _clone_economy(economy)
    var temp_ledger := _clone_ledger(ledger)
    if temp_inventory == null or temp_economy == null or temp_ledger == null:
        return _result(false, REASON_COMMIT_FAILED)

    for raw_reward: Variant in pending["normal_rewards"] as Array:
        var reward: Dictionary = raw_reward as Dictionary
        var add: Dictionary = temp_inventory.try_add_normal(
            StringName(String(reward["item_instance_id"])),
            StringName(String(reward["definition_id"])),
            int(reward["quantity"]),
            bool(reward["stackable"])
        )
        if not bool(add.get("accepted", false)):
            var inventory_reason := StringName(add.get("reason_id", &""))
            return {
                "accepted": false,
                "reason_id": REASON_INVENTORY_FULL if inventory_reason == InventoryState.REASON_INVENTORY_FULL else REASON_INVALID_REWARD,
                "inventory_reason_id": inventory_reason,
            }

    if not temp_economy.remove_pending_reward(reward_claim_id):
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_ledger.try_claim(transaction_id, reward_claim_id):
        return _result(false, REASON_DUPLICATE_CLAIM)
    if not _commit_clones(inventory, economy, ledger, temp_inventory, temp_economy, temp_ledger):
        return _result(false, REASON_COMMIT_FAILED)
    return {
        "accepted": true,
        "reason_id": &"",
        "reward_claim_id": reward_claim_id,
        "transaction_id": transaction_id,
    }


static func _valid_normal_reward(reward: Dictionary) -> bool:
    for key: String in ["item_instance_id", "definition_id"]:
        var value: Variant = reward.get(key, null)
        if not (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME) or not StableId.is_valid(String(value)):
            return false
    if typeof(reward.get("stackable", null)) != TYPE_BOOL:
        return false
    if not NormalStackQuantityValidator.is_valid(reward.get("quantity", null)):
        return false
    return bool(reward["stackable"]) or int(reward["quantity"]) == 1


static func _clone_inventory(source: InventoryState) -> InventoryState:
    var clone := InventoryState.new()
    return clone if clone.load_dictionary(source.to_dictionary()).is_empty() else null


static func _clone_economy(source: EconomyState) -> EconomyState:
    var clone := EconomyState.new()
    return clone if clone.load_dictionary(source.to_dictionary()).is_empty() else null


static func _clone_ledger(source: ClaimLedger) -> ClaimLedger:
    var clone := ClaimLedger.new()
    return clone if clone.load_dictionary(source.to_dictionary()).is_empty() else null


static func _commit_clones(
    inventory: InventoryState,
    economy: EconomyState,
    ledger: ClaimLedger,
    temp_inventory: InventoryState,
    temp_economy: EconomyState,
    temp_ledger: ClaimLedger
) -> bool:
    var inventory_data: Dictionary = temp_inventory.to_dictionary()
    var economy_data: Dictionary = temp_economy.to_dictionary()
    var ledger_data: Dictionary = temp_ledger.to_dictionary()
    if not InventoryState.validate_dictionary(inventory_data).is_empty():
        return false
    if not EconomyState.validate_dictionary(economy_data).is_empty():
        return false
    if not ClaimLedger.validate_dictionary(ledger_data).is_empty():
        return false
    return (
        inventory.load_dictionary(inventory_data).is_empty()
        and economy.load_dictionary(economy_data).is_empty()
        and ledger.load_dictionary(ledger_data).is_empty()
    )


static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {"accepted": accepted, "reason_id": reason_id}
