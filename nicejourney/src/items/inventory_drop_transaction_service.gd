class_name InventoryDropTransactionService
extends RefCounted

const PLAYER_DROP_STATE_VALIDATOR: Script = preload("res://src/items/player_drop_state_validator.gd")
const ENTRY_KIND: StringName = &"player_drop"
const DROP_SOURCE_PREFIX: String = "player_drop:"
const REASON_INVALID_INPUT: StringName = &"invalid_input"
const REASON_DUPLICATE_TRANSACTION: StringName = &"duplicate_transaction"
const REASON_ITEM_NOT_FOUND: StringName = &"item_not_found"
const REASON_PROTECTED_ITEM: StringName = &"protected_item"
const REASON_FLOOR_NOT_FOUND: StringName = &"floor_not_found"
const REASON_SOURCE_EXISTS: StringName = &"source_exists"
const REASON_SOURCE_NOT_FOUND: StringName = &"source_not_found"
const REASON_NOT_PLAYER_DROP: StringName = &"not_player_drop"
const REASON_INVENTORY_FULL: StringName = &"inventory_full"
const REASON_DUPLICATE_ITEM_INSTANCE: StringName = &"duplicate_item_instance"
const REASON_COMMIT_FAILED: StringName = &"commit_failed"


static func drop_full_stack(
    profile: ProfileSnapshot,
    floor_id: int,
    transaction_id: StringName,
    item_instance_id: StringName,
    world_position: Vector2
) -> Dictionary:
    if not _base_inputs_valid(profile, floor_id, transaction_id) or not StableId.is_valid(String(item_instance_id)) or not _finite_position(world_position):
        return _result(false, REASON_INVALID_INPUT)

    var states: Dictionary = _load_states(profile, floor_id)
    if not bool(states.get("accepted", false)):
        return _result(false, StringName(states.get("reason_id", REASON_COMMIT_FAILED)))
    var inventory := states["inventory"] as InventoryState
    var ledger := states["ledger"] as ClaimLedger
    var floor := states["floor"] as FloorInstanceState

    if ledger.is_claimed(transaction_id):
        return _result(false, REASON_DUPLICATE_TRANSACTION)
    if inventory.protected_items.has(String(item_instance_id)):
        var policy: Dictionary = ProtectedItemOperationPolicy.evaluate(
            ProtectedItemOperationPolicy.OP_DROP,
            inventory.protected_items[String(item_instance_id)] as Dictionary
        )
        return {
            "accepted": false,
            "reason_id": REASON_PROTECTED_ITEM,
            "policy_reason_id": StringName(policy.get("reason_id", &"")),
        }

    var item: Dictionary = inventory.get_normal_slot(item_instance_id)
    if item.is_empty():
        return _result(false, REASON_ITEM_NOT_FOUND)

    var source_id := StringName("%s%s" % [DROP_SOURCE_PREFIX, String(transaction_id)])
    if floor.loose_items.has(String(source_id)):
        return _result(false, REASON_SOURCE_EXISTS)

    var temp_inventory := InventoryState.new()
    var temp_ledger := ClaimLedger.new()
    var temp_floor := FloorInstanceState.new()
    if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_floor.load_dictionary(floor.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    var owned_quantity := int(item.get("quantity", 0))
    var removed: Dictionary = temp_inventory.try_remove_normal(item_instance_id, owned_quantity)
    if not bool(removed.get("accepted", false)):
        return _result(false, REASON_COMMIT_FAILED)

    var entry: Dictionary = {
        "entry_kind": String(ENTRY_KIND),
        "source_id": String(source_id),
        "item": item.duplicate(true),
        "world_position": {
            "x": world_position.x,
            "y": world_position.y,
        },
    }
    if not (PLAYER_DROP_STATE_VALIDATOR.validate_entry(entry, source_id) as PackedStringArray).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    temp_floor.loose_items[String(source_id)] = entry
    if not temp_ledger.try_claim(transaction_id, source_id):
        return _result(false, REASON_DUPLICATE_TRANSACTION)

    var commit: Dictionary = _commit_profile(profile, floor_id, temp_inventory, temp_ledger, temp_floor)
    if not bool(commit.get("accepted", false)):
        return commit
    return {
        "accepted": true,
        "reason_id": &"",
        "transaction_id": transaction_id,
        "source_id": source_id,
        "item_instance_id": item_instance_id,
        "definition_id": StringName(String(item.get("definition_id", &""))),
        "quantity": owned_quantity,
        "world_position": world_position,
    }


static func collect_player_drop(
    profile: ProfileSnapshot,
    floor_id: int,
    source_id: StringName,
    transaction_id: StringName
) -> Dictionary:
    if not _base_inputs_valid(profile, floor_id, transaction_id) or not StableId.is_valid(String(source_id)):
        return _result(false, REASON_INVALID_INPUT)

    var states: Dictionary = _load_states(profile, floor_id)
    if not bool(states.get("accepted", false)):
        return _result(false, StringName(states.get("reason_id", REASON_COMMIT_FAILED)))
    var inventory := states["inventory"] as InventoryState
    var ledger := states["ledger"] as ClaimLedger
    var floor := states["floor"] as FloorInstanceState

    if ledger.is_claimed(transaction_id):
        return _result(false, REASON_DUPLICATE_TRANSACTION)
    var raw_entry: Variant = floor.loose_items.get(String(source_id), null)
    if not raw_entry is Dictionary:
        return _result(false, REASON_SOURCE_NOT_FOUND)
    var entry := raw_entry as Dictionary
    if StringName(String(entry.get("entry_kind", &""))) != ENTRY_KIND:
        return _result(false, REASON_NOT_PLAYER_DROP)
    if not (PLAYER_DROP_STATE_VALIDATOR.validate_entry(entry, source_id) as PackedStringArray).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    var item := (entry.get("item", {}) as Dictionary).duplicate(true)
    var item_instance_id := StringName(String(item.get("item_instance_id", &"")))
    if not inventory.get_normal_slot(item_instance_id).is_empty():
        return _result(false, REASON_DUPLICATE_ITEM_INSTANCE)

    var temp_inventory := InventoryState.new()
    var temp_ledger := ClaimLedger.new()
    var temp_floor := FloorInstanceState.new()
    if not temp_inventory.load_dictionary(inventory.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_ledger.load_dictionary(ledger.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    if not temp_floor.load_dictionary(floor.to_dictionary()).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    var inventory_data: Dictionary = temp_inventory.to_dictionary()
    var normal_slots := inventory_data.get("normal_slots", []) as Array
    if normal_slots.size() >= NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY:
        return _result(false, REASON_INVENTORY_FULL)
    normal_slots.append(item.duplicate(true))
    inventory_data["normal_slots"] = normal_slots
    if not temp_inventory.load_dictionary(inventory_data).is_empty():
        return _result(false, REASON_COMMIT_FAILED)

    temp_floor.loose_items.erase(String(source_id))
    if not temp_ledger.try_claim(transaction_id, source_id):
        return _result(false, REASON_DUPLICATE_TRANSACTION)

    var commit: Dictionary = _commit_profile(profile, floor_id, temp_inventory, temp_ledger, temp_floor)
    if not bool(commit.get("accepted", false)):
        return commit
    return {
        "accepted": true,
        "reason_id": &"",
        "transaction_id": transaction_id,
        "source_id": source_id,
        "item_instance_id": item_instance_id,
        "definition_id": StringName(String(item.get("definition_id", &""))),
        "quantity": int(item.get("quantity", 0)),
        "world_position": _entry_position(entry),
    }


static func _load_states(profile: ProfileSnapshot, floor_id: int) -> Dictionary:
    if profile.item_state.is_empty():
        return {"accepted": false, "reason_id": REASON_ITEM_NOT_FOUND}
    var raw_floor: Variant = profile.tower_floor_states.get(str(floor_id), null)
    if not raw_floor is Dictionary:
        return {"accepted": false, "reason_id": REASON_FLOOR_NOT_FOUND}
    var inventory := InventoryState.new()
    var ledger := ClaimLedger.new()
    var floor := FloorInstanceState.new()
    if not inventory.load_dictionary(profile.item_state).is_empty():
        return {"accepted": false, "reason_id": REASON_COMMIT_FAILED}
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return {"accepted": false, "reason_id": REASON_COMMIT_FAILED}
    if not floor.load_dictionary(raw_floor as Dictionary).is_empty() or floor.floor_id != floor_id:
        return {"accepted": false, "reason_id": REASON_COMMIT_FAILED}
    return {
        "accepted": true,
        "inventory": inventory,
        "ledger": ledger,
        "floor": floor,
    }


static func _commit_profile(
    profile: ProfileSnapshot,
    floor_id: int,
    inventory: InventoryState,
    ledger: ClaimLedger,
    floor: FloorInstanceState
) -> Dictionary:
    var item_data := inventory.to_dictionary()
    var claim_data := ledger.to_dictionary()
    var floor_data := floor.to_dictionary()
    if not InventoryState.validate_dictionary(item_data).is_empty() or not ClaimLedger.validate_dictionary(claim_data).is_empty() or not FloorInstanceState.validate_dictionary(floor_data).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    var candidate := profile.to_dictionary()
    candidate["item_state"] = item_data.duplicate(true)
    candidate["claimed_transactions"] = claim_data.duplicate(true)
    var floor_states := (candidate.get("tower_floor_states", {}) as Dictionary).duplicate(true)
    floor_states[str(floor_id)] = floor_data.duplicate(true)
    candidate["tower_floor_states"] = floor_states
    if not ProfileSnapshot.validate_dictionary(candidate).is_empty():
        return _result(false, REASON_COMMIT_FAILED)
    profile.item_state = item_data
    profile.claimed_transactions = claim_data
    profile.tower_floor_states = floor_states
    return {"accepted": true, "reason_id": &""}


static func _entry_position(entry: Dictionary) -> Vector2:
    var position := entry.get("world_position", {}) as Dictionary
    return Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))


static func _base_inputs_valid(profile: ProfileSnapshot, floor_id: int, transaction_id: StringName) -> bool:
    return (
        profile != null
        and floor_id >= 1
        and floor_id <= 10
        and StableId.is_valid(String(transaction_id))
    )


static func _finite_position(position: Vector2) -> bool:
    return is_finite(position.x) and is_finite(position.y)


static func _result(accepted: bool, reason_id: StringName) -> Dictionary:
    return {"accepted": accepted, "reason_id": reason_id}
