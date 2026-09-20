class_name ConsumablePlaytestUseService
extends RefCounted

const SOURCE_ID: StringName = &"inventory:consumable_use"
const REASON_INVALID_CONTEXT: StringName = &"consumable_context_invalid"
const REASON_SLOT_EMPTY: StringName = &"consumable_slot_empty"
const REASON_ITEM_NOT_OWNED: StringName = &"consumable_item_not_owned"
const REASON_UNAUTHORED: StringName = &"consumable_effect_unauthored"
const REASON_ALREADY_FULL: StringName = &"consumable_health_full"
const REASON_DUPLICATE: StringName = &"consumable_duplicate_transaction"
const REASON_STAGED_INVALID: StringName = &"consumable_staged_profile_invalid"


static func prepare(
    profile: ProfileSnapshot,
    slot_index: int,
    transaction_id: StringName,
    categories: ItemCategoryCatalog,
    tuning: ConsumablePlaytestTuning,
    current_hp: int,
    max_hp: int
) -> Dictionary:
    if (
        profile == null or slot_index < 0 or slot_index >= InventoryState.QUICK_SLOT_COUNT
        or not StableId.is_valid(String(transaction_id))
        or tuning == null or not tuning.validate_tuning(categories).is_empty()
        or current_hp <= 0 or max_hp <= 0 or current_hp > max_hp
        or not ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty()
    ):
        return _rejected(REASON_INVALID_CONTEXT)
    var inventory := InventoryState.new()
    var ledger := ClaimLedger.new()
    if not inventory.load_dictionary(profile.item_state).is_empty() or not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return _rejected(REASON_INVALID_CONTEXT)
    if ledger.is_claimed(transaction_id):
        return _rejected(REASON_DUPLICATE)
    var item_id := inventory.quick_slots[slot_index]
    if item_id == &"":
        return _rejected(REASON_SLOT_EMPTY)
    var owned := inventory.get_normal_slot(item_id)
    if owned.is_empty():
        return _rejected(REASON_ITEM_NOT_OWNED)
    var definition_id := StringName(String(owned.get("definition_id", &"")))
    if not categories.is_consumable(definition_id):
        return _rejected(REASON_UNAUTHORED)
    var healing := tuning.heal_amount(definition_id)
    if healing <= 0:
        return _rejected(REASON_UNAUTHORED)
    if current_hp >= max_hp:
        return _rejected(REASON_ALREADY_FULL)
    var after_hp := mini(max_hp, current_hp + healing)
    var removal := inventory.try_remove_normal(item_id, 1)
    if not bool(removal.get("accepted", false)) or not ledger.try_claim(transaction_id, SOURCE_ID):
        return _rejected(REASON_STAGED_INVALID)
    var staged_items := inventory.to_dictionary()
    var staged_claims := ledger.to_dictionary()
    var staged := profile.to_dictionary()
    staged["item_state"] = staged_items.duplicate(true)
    staged["claimed_transactions"] = staged_claims.duplicate(true)
    if not ProfileSnapshot.validate_dictionary(staged).is_empty():
        return _rejected(REASON_STAGED_INVALID)
    return {
        "accepted": true,
        "reason_id": &"",
        "slot_index": slot_index,
        "item_instance_id": item_id,
        "definition_id": definition_id,
        "health_before": current_hp,
        "health_after": after_hp,
        "healed_hp": after_hp - current_hp,
        "item_state": staged_items,
        "claimed_transactions": staged_claims,
        "transaction_id": transaction_id,
        "playtest_placeholder": true,
        "durable": false,
        "durability_boundary": &"next_safe_snapshot",
    }


static func _rejected(reason_id: StringName) -> Dictionary:
    return {"accepted": false, "reason_id": reason_id, "durable": false}
