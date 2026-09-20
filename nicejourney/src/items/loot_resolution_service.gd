class_name LootResolutionService
extends RefCounted

const KIND_GOLD: StringName = &"gold"
const KIND_NORMAL: StringName = &"normal"

const REASON_INVALID_INPUT: StringName = &"invalid_input"
const REASON_SOURCE_ALREADY_CLAIMED: StringName = &"source_already_claimed"
const REASON_INVALID_TABLE: StringName = &"invalid_table"
const REASON_INVENTORY_FULL: StringName = &"inventory_full"
const REASON_DUPLICATE_CLAIM: StringName = &"duplicate_claim"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"
const REASON_SOURCE_NOT_RESOLVED: StringName = &"source_not_resolved"


static func resolve_source(
    floor_state: FloorInstanceState,
    source_id: StringName,
    claim_id: StringName,
    gameplay_loot_seed: int,
    fixed_rewards: Array,
    weighted_entries: Array,
    weighted_rolls: int
) -> Dictionary:
    if floor_state == null or not StableId.is_valid(String(source_id)) or not StableId.is_valid(String(claim_id)) or gameplay_loot_seed < 0:
        return _result(false, REASON_INVALID_INPUT)
    if weighted_rolls < 0 or weighted_rolls > 32:
        return _result(false, REASON_INVALID_INPUT)
    if floor_state.claimed_source_ids.has(source_id):
        return _result(false, REASON_SOURCE_ALREADY_CLAIMED)
    if floor_state.loose_items.has(String(source_id)):
        var existing: Variant = floor_state.loose_items[String(source_id)]
        if not existing is Dictionary:
            return _result(false, REASON_COMMIT_FAILED)
        var existing_entry: Dictionary = existing as Dictionary
        if StringName(String(existing_entry.get("claim_id", &""))) != claim_id:
            return _result(false, REASON_INVALID_INPUT)
        return {
            "accepted": true,
            "reason_id": &"",
            "already_resolved": true,
            "source_id": source_id,
            "claim_id": claim_id,
            "rewards": (existing_entry.get("rewards", []) as Array).duplicate(true),
        }

    var fixed_result: Dictionary = _normalize_fixed_rewards(source_id, fixed_rewards)
    if not bool(fixed_result.get("accepted", false)):
        return _result(false, REASON_INVALID_TABLE)
    var weighted_result: Dictionary = _normalize_weighted_entries(weighted_entries)
    if not bool(weighted_result.get("accepted", false)):
        return _result(false, REASON_INVALID_TABLE)
    if weighted_rolls > 0 and (weighted_result.get("entries", []) as Array).is_empty():
        return _result(false, REASON_INVALID_TABLE)

    var rewards: Array = (fixed_result["rewards"] as Array).duplicate(true)
    var entries: Array = weighted_result["entries"] as Array
    if weighted_rolls > 0:
        var rng := RandomNumberGenerator.new()
        rng.seed = _mixed_seed(gameplay_loot_seed, source_id)
        var total_weight: int = int(weighted_result["total_weight"])
        for roll_index: int in range(weighted_rolls):
            var pick: int = rng.randi_range(1, total_weight)
            var running := 0
            var selected: Dictionary = {}
            for raw_entry: Variant in entries:
                var entry: Dictionary = raw_entry as Dictionary
                running += int(entry["weight"])
                if pick <= running:
                    selected = entry
                    break
            if selected.is_empty():
                return _result(false, REASON_COMMIT_FAILED)
            rewards.append(_materialize_reward(source_id, selected["entry_id"], selected["reward"] as Dictionary, roll_index))

    var entry := {
        "source_id": source_id,
        "claim_id": claim_id,
        "rewards": rewards.duplicate(true),
    }
    floor_state.loose_items[String(source_id)] = entry
    return {
        "accepted": true,
        "reason_id": &"",
        "already_resolved": false,
        "source_id": source_id,
        "claim_id": claim_id,
        "rewards": rewards.duplicate(true),
    }


static func collect_resolved_source(
    floor_state: FloorInstanceState,
    inventory: InventoryState,
    ledger: ClaimLedger,
    source_id: StringName
) -> Dictionary:
    if floor_state == null or inventory == null or ledger == null or not StableId.is_valid(String(source_id)):
        return _result(false, REASON_INVALID_INPUT)
    if floor_state.claimed_source_ids.has(source_id):
        return _result(false, REASON_SOURCE_ALREADY_CLAIMED)
    var raw_entry: Variant = floor_state.loose_items.get(String(source_id), null)
    if not raw_entry is Dictionary:
        return _result(false, REASON_SOURCE_NOT_RESOLVED)
    var entry: Dictionary = raw_entry as Dictionary
    var claim_id := StringName(String(entry.get("claim_id", &"")))
    if not StableId.is_valid(String(claim_id)):
        return _result(false, REASON_COMMIT_FAILED)
    if ledger.is_claimed(claim_id):
        return _result(false, REASON_DUPLICATE_CLAIM)

    var temp_inventory := InventoryState.new()
    if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    var temp_ledger := ClaimLedger.new()
    if not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    var temp_floor := FloorInstanceState.new()
    if not temp_floor.load_dictionary(floor_state.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    var gold_total := 0
    for raw_reward: Variant in entry.get("rewards", []) as Array:
        if not raw_reward is Dictionary:
            return _result(false, REASON_COMMIT_FAILED)
        var reward: Dictionary = raw_reward as Dictionary
        var kind := StringName(String(reward.get("kind", &"")))
        match kind:
            KIND_GOLD:
                var amount: int = int(reward.get("amount", -1))
                if amount < 0 or gold_total > 2147483647 - amount:
                    return _result(false, REASON_COMMIT_FAILED)
                gold_total += amount
            KIND_NORMAL:
                var add: Dictionary = temp_inventory.try_add_normal(
                    StringName(String(reward.get("item_instance_id", &""))),
                    StringName(String(reward.get("definition_id", &""))),
                    int(reward.get("quantity", 0)),
                    bool(reward.get("stackable", false))
                )
                if not bool(add.get("accepted", false)):
                    if StringName(add.get("reason_id", &"")) == InventoryState.REASON_INVENTORY_FULL:
                        return {
                            "accepted": false,
                            "reason_id": REASON_INVENTORY_FULL,
                            "source_remains": true,
                        }
                    return _result(false, REASON_COMMIT_FAILED)
            _:
                return _result(false, REASON_COMMIT_FAILED)

    if not temp_inventory.add_gold(gold_total):
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_ledger.try_claim(claim_id, source_id):
        return _result(false, REASON_DUPLICATE_CLAIM)
    if not temp_floor.claim_source(source_id):
        return _result(false, REASON_COMMIT_FAILED)
    temp_floor.loose_items.erase(String(source_id))

    var inventory_data := temp_inventory.to_dictionary()
    var ledger_data := temp_ledger.to_dictionary()
    var floor_data := temp_floor.to_dictionary()
    if not InventoryState.validate_dictionary(inventory_data).is_empty() or not ClaimLedger.validate_dictionary(ledger_data).is_empty() or not FloorInstanceState.validate_dictionary(floor_data).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not inventory.load_dictionary(inventory_data).is_empty() or not ledger.load_dictionary(ledger_data).is_empty() or not floor_state.load_dictionary(floor_data).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    return {
        "accepted": true,
        "reason_id": &"",
        "source_id": source_id,
        "claim_id": claim_id,
        "gold_collected": gold_total,
    }


static func _normalize_fixed_rewards(source_id: StringName, fixed_rewards: Array) -> Dictionary:
    var rewards: Array = []
    for index: int in range(fixed_rewards.size()):
        var raw_reward: Variant = fixed_rewards[index]
        if not raw_reward is Dictionary or not _valid_reward_template(raw_reward as Dictionary):
            return {"accepted": false}
        rewards.append(_materialize_reward(source_id, StringName("fixed_%02d" % index), raw_reward as Dictionary, index))
    return {"accepted": true, "rewards": rewards}


static func _normalize_weighted_entries(weighted_entries: Array) -> Dictionary:
    var entries: Array[Dictionary] = []
    var seen_ids: Dictionary = {}
    var total_weight := 0
    for raw_entry: Variant in weighted_entries:
        if not raw_entry is Dictionary:
            return {"accepted": false}
        var entry: Dictionary = raw_entry as Dictionary
        var raw_id: Variant = entry.get("entry_id", null)
        if not (typeof(raw_id) == TYPE_STRING or typeof(raw_id) == TYPE_STRING_NAME) or not StableId.is_valid(String(raw_id)):
            return {"accepted": false}
        var entry_id := StringName(String(raw_id))
        if seen_ids.has(entry_id):
            return {"accepted": false}
        seen_ids[entry_id] = true
        if typeof(entry.get("weight", null)) != TYPE_INT or int(entry["weight"]) <= 0:
            return {"accepted": false}
        if not entry.get("reward", null) is Dictionary or not _valid_reward_template(entry["reward"] as Dictionary):
            return {"accepted": false}
        total_weight += int(entry["weight"])
        if total_weight <= 0 or total_weight > 2147483647:
            return {"accepted": false}
        entries.append({
            "entry_id": entry_id,
            "weight": int(entry["weight"]),
            "reward": (entry["reward"] as Dictionary).duplicate(true),
        })
    entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return String(left["entry_id"]) < String(right["entry_id"])
    )
    return {"accepted": true, "entries": entries, "total_weight": total_weight}


static func _valid_reward_template(reward: Dictionary) -> bool:
    var kind := StringName(String(reward.get("kind", &"")))
    if kind == KIND_GOLD:
        return typeof(reward.get("amount", null)) == TYPE_INT and int(reward["amount"]) >= 0
    if kind != KIND_NORMAL:
        return false
    var raw_definition: Variant = reward.get("definition_id", null)
    if not (typeof(raw_definition) == TYPE_STRING or typeof(raw_definition) == TYPE_STRING_NAME) or not StableId.is_valid(String(raw_definition)):
        return false
    if typeof(reward.get("stackable", null)) != TYPE_BOOL or not NormalStackQuantityValidator.is_valid(reward.get("quantity", null)):
        return false
    return bool(reward["stackable"]) or int(reward["quantity"]) == 1


static func _materialize_reward(source_id: StringName, entry_id: StringName, reward_template: Dictionary, ordinal: int) -> Dictionary:
    var reward: Dictionary = reward_template.duplicate(true)
    if StringName(String(reward["kind"])) == KIND_NORMAL:
        reward["item_instance_id"] = StringName("loot:%s:%s:%02d" % [String(source_id), String(entry_id), ordinal])
    return reward


static func _mixed_seed(base_seed: int, source_id: StringName) -> int:
    var value: int = base_seed & 0x7fffffff
    var bytes: PackedByteArray = String(source_id).to_utf8_buffer()
    for byte_value: int in bytes:
        value = (value * 1103515245 + int(byte_value) + 12345) & 0x7fffffff
    return value


static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {"accepted": accepted, "reason_id": reason_id}
