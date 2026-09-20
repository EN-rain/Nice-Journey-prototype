extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_resolve_once_and_persist_roll()
    _test_world_loot_full_inventory_stays_at_source()
    if _failures == 0:
        print("LOOT RESOLUTION TEST PASS")
    else:
        push_error("LOOT RESOLUTION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_resolve_once_and_persist_roll() -> void:
    var floor := _floor_state()
    var fixed: Array = [{"kind": &"gold", "amount": 7}]
    var weighted: Array = [
        {"entry_id": &"entry:potion", "weight": 3, "reward": {"kind": &"normal", "definition_id": &"itemdef:potion", "quantity": 2, "stackable": true}},
        {"entry_id": &"entry:material", "weight": 1, "reward": {"kind": &"normal", "definition_id": &"itemdef:upgrade_material", "quantity": 1, "stackable": true}},
    ]
    var first: Dictionary = LootResolutionService.resolve_source(floor, &"source:chest_01", &"claim:chest_01", 12345, fixed, weighted, 2)
    _expect(first["accepted"] and not first["already_resolved"], "loot source resolves once from fixed plus weighted authored table")
    var first_rewards: Array = (first["rewards"] as Array).duplicate(true)
    _expect(first_rewards.size() == 3, "resolved source persists fixed reward plus configured weighted rolls")
    _expect(floor.loose_items.has("source:chest_01"), "resolved but uncollected source is stored in persistent floor state")

    var reroll_attempt: Dictionary = LootResolutionService.resolve_source(
        floor,
        &"source:chest_01",
        &"claim:chest_01",
        99999,
        [{"kind": &"gold", "amount": 999}],
        [{"entry_id": &"entry:other", "weight": 1, "reward": {"kind": &"normal", "definition_id": &"itemdef:other", "quantity": 1, "stackable": true}}],
        1
    )
    _expect(reroll_attempt["accepted"] and reroll_attempt["already_resolved"], "known loot source ignores later seed/table changes instead of rerolling")
    _expect((reroll_attempt["rewards"] as Array) == first_rewards, "known loot source returns the exact persisted roll")

    var saved: Dictionary = floor.to_dictionary()
    var restored := FloorInstanceState.new()
    _expect(restored.load_dictionary(saved).is_empty(), "uncollected resolved loot survives floor-state save/load")
    var after_load: Dictionary = LootResolutionService.resolve_source(restored, &"source:chest_01", &"claim:chest_01", 1, [], [], 0)
    _expect(after_load["accepted"] and (after_load["rewards"] as Array) == first_rewards, "reload cannot reroll a resolved source")


func _test_world_loot_full_inventory_stays_at_source() -> void:
    var floor := _floor_state()
    var resolved: Dictionary = LootResolutionService.resolve_source(
        floor,
        &"source:elite_drop",
        &"claim:elite_drop",
        777,
        [{"kind": &"gold", "amount": 20}, {"kind": &"normal", "definition_id": &"itemdef:elite_material", "quantity": 1, "stackable": false}],
        [],
        0
    )
    _expect(resolved["accepted"], "elite world-drop fixture resolves")

    var inventory := InventoryState.new()
    for index: int in range(NormalInventoryCapacityPolicy.NORMAL_SLOT_CAPACITY):
        _expect(inventory.try_add_normal(StringName("item:loot_full_%02d" % index), StringName("itemdef:loot_full_%02d" % index), 1, false)["accepted"], "loot fixture fills slot %02d" % index)
    var ledger := ClaimLedger.new()
    var before_inventory: Dictionary = inventory.to_dictionary()
    var rejected: Dictionary = LootResolutionService.collect_resolved_source(floor, inventory, ledger, &"source:elite_drop")
    _expect(not rejected["accepted"] and rejected["reason_id"] == LootResolutionService.REASON_INVENTORY_FULL and rejected["source_remains"], "full normal grid leaves world loot at its saved source instead of converting it to quest overflow")
    _expect(inventory.to_dictionary() == before_inventory and inventory.gold == 0, "failed world-loot pickup is atomic and does not partially collect Gold")
    _expect(floor.loose_items.has("source:elite_drop") and not floor.claimed_source_ids.has(&"source:elite_drop"), "failed pickup preserves resolved source and unclaimed identity")
    _expect(not ledger.is_claimed(&"claim:elite_drop"), "failed pickup consumes no claim identity")

    _expect(inventory.try_remove_normal(&"item:loot_full_00", 1)["accepted"], "player can free capacity for saved world loot")
    var collected: Dictionary = LootResolutionService.collect_resolved_source(floor, inventory, ledger, &"source:elite_drop")
    _expect(collected["accepted"] and collected["gold_collected"] == 20, "saved world loot collects after capacity revalidation")
    _expect(inventory.gold == 20, "successful source collection commits Gold once")
    _expect(floor.claimed_source_ids.has(&"source:elite_drop") and not floor.loose_items.has("source:elite_drop"), "successful collection consumes source exactly once")
    _expect(ledger.is_claimed(&"claim:elite_drop"), "successful collection persists reward claim identity")
    var duplicate: Dictionary = LootResolutionService.collect_resolved_source(floor, inventory, ledger, &"source:elite_drop")
    _expect(not duplicate["accepted"] and duplicate["reason_id"] == LootResolutionService.REASON_SOURCE_ALREADY_CLAIMED, "collected source cannot pay out twice")


func _floor_state() -> FloorInstanceState:
    var floor := FloorInstanceState.new()
    floor.floor_id = 3
    floor.instance_id = &"floor_instance:loot_fixture"
    floor.seed = 333
    floor.layout_revision_id = &"layout:loot_fixture"
    _expect(FloorInstanceState.validate_dictionary(floor.to_dictionary()).is_empty(), "loot fixture floor state validates")
    return floor


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
