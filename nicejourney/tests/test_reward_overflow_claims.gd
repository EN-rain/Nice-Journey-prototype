extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_full_inventory_commits_entitlement_and_pends_normal_items()
    _test_direct_reward_when_capacity_exists()
    _test_invalid_reward_is_atomic()
    if _failures == 0:
        print("REWARD OVERFLOW CLAIM TEST PASS")
    else:
        push_error("REWARD OVERFLOW CLAIM TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_full_inventory_commits_entitlement_and_pends_normal_items() -> void:
    var inventory := InventoryState.new()
    for index: int in range(NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY):
        _expect(inventory.try_add_normal(StringName("item:overflow_%02d" % index), StringName("itemdef:overflow_%02d" % index), 1, false)["accepted"], "overflow fixture fills normal slot %02d" % index)
    var economy := EconomyState.new()
    var ledger := ClaimLedger.new()
    var normal_rewards: Array = [_normal_reward(&"item:quest_reward_sword", &"itemdef:quest_reward_sword", 1, false)]
    var protected_rewards: Array = [{"item_id": &"quest:key_reward", "tower_sigil": false}]

    var result: Dictionary = RewardGrantService.grant_bundle(
        inventory,
        economy,
        ledger,
        &"reward:quest_overflow",
        &"quest:fixture_overflow",
        50,
        protected_rewards,
        normal_rewards
    )
    _expect(result["accepted"] and result["normal_rewards_pending"], "full inventory commits reward entitlement while pending normal-capacity component")
    _expect(result["message_id"] == &"reward_waiting_inventory_full", "overflow result exposes explicit reward-waiting feedback")
    _expect(inventory.gold == 50, "Gold entitlement commits despite normal inventory pressure")
    _expect(inventory.protected_items.has("quest:key_reward"), "protected quest/key entitlement commits outside normal capacity")
    _expect(inventory.get_normal_slot(&"item:quest_reward_sword").is_empty(), "normal reward is not silently forced into a full grid")
    _expect(ledger.is_claimed(&"reward:quest_overflow"), "reward entitlement claim commits exactly once")
    _expect(not economy.get_pending_reward(&"reward:quest_overflow").is_empty(), "normal reward remains persistently claimable after quest/source closure")

    var retry_duplicate: Dictionary = RewardGrantService.grant_bundle(
        inventory,
        economy,
        ledger,
        &"reward:quest_overflow",
        &"quest:fixture_overflow",
        50,
        protected_rewards,
        normal_rewards
    )
    _expect(not retry_duplicate["accepted"] and retry_duplicate["reason_id"] == RewardGrantService.REASON_DUPLICATE_CLAIM, "duplicate reward event cannot grant Gold/protected entitlements twice")
    _expect(inventory.gold == 50, "duplicate reward event leaves Gold unchanged")

    _expect(inventory.try_remove_normal(&"item:overflow_00", 1)["accepted"], "player can free one normal slot later")
    var claim: Dictionary = RewardGrantService.claim_pending_normal(
        inventory,
        economy,
        ledger,
        &"reward:quest_overflow",
        &"transaction:claim_overflow_reward"
    )
    _expect(claim["accepted"], "pending normal reward claims successfully after capacity revalidation")
    _expect(not inventory.get_normal_slot(&"item:quest_reward_sword").is_empty(), "claimed pending reward enters normal inventory")
    _expect(economy.get_pending_reward(&"reward:quest_overflow").is_empty(), "successful pending claim clears persistent pending entry")
    _expect(ledger.is_claimed(&"transaction:claim_overflow_reward"), "pending-claim transaction is duplicate-resistant")


func _test_direct_reward_when_capacity_exists() -> void:
    var inventory := InventoryState.new()
    var economy := EconomyState.new()
    var ledger := ClaimLedger.new()
    var result: Dictionary = RewardGrantService.grant_bundle(
        inventory,
        economy,
        ledger,
        &"reward:direct",
        &"quest:direct",
        12,
        [],
        [_normal_reward(&"item:direct_potion", &"itemdef:potion", 5, true)]
    )
    _expect(result["accepted"] and not result["normal_rewards_pending"], "reward with capacity commits normal item immediately")
    _expect(inventory.gold == 12 and inventory.get_normal_slot(&"item:direct_potion")["quantity"] == 5, "direct reward commits Gold and normal item together")
    _expect(economy.pending_reward_claims.is_empty(), "direct reward creates no false pending claim")


func _test_invalid_reward_is_atomic() -> void:
    var inventory := InventoryState.new()
    _expect(inventory.add_gold(7), "invalid-reward fixture has baseline Gold")
    var economy := EconomyState.new()
    var ledger := ClaimLedger.new()
    var before_inventory: Dictionary = inventory.to_dictionary()
    var result: Dictionary = RewardGrantService.grant_bundle(
        inventory,
        economy,
        ledger,
        &"reward:invalid",
        &"quest:invalid",
        100,
        [{"item_id": &"not_sigil", "tower_sigil": true}],
        []
    )
    _expect(not result["accepted"] and result["reason_id"] == RewardGrantService.REASON_INVALID_REWARD, "invalid protected reward is rejected before commit")
    _expect(inventory.to_dictionary() == before_inventory, "invalid reward cannot partially add Gold")
    _expect(not ledger.is_claimed(&"reward:invalid") and economy.pending_reward_claims.is_empty(), "invalid reward consumes no claim identity or pending state")


func _normal_reward(instance_id: StringName, definition_id: StringName, quantity: int, stackable: bool) -> Dictionary:
    return {
        "item_instance_id": instance_id,
        "definition_id": definition_id,
        "quantity": quantity,
        "stackable": stackable,
    }


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
