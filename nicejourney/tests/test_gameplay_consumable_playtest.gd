extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const TONIC: StringName = &"itemdef:region3_playtest_tonic"
const STACK_ID: StringName = &"item:playtest_tonic_stack"
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Tonic Shortcut", "melee")
    var inventory := InventoryState.new()
    _expect(inventory.load_dictionary(profile.item_state).is_empty(), "starter inventory fixture loads")
    _expect(bool(inventory.try_add_normal(STACK_ID, TONIC, 2, true).get("accepted", false)), "two actual provisional tonics are owned")
    _expect(inventory.bind_quick_slot(0, STACK_ID) and inventory.bind_quick_slot(1, STACK_ID), "two shortcuts reference the same real stack without duplicating ownership")
    profile.item_state = inventory.to_dictionary()
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    root.add_child(game)
    await process_frame

    _expect(game.consumable_playtest_tuning != null and game.consumable_playtest_tuning.playtest_placeholder and game.consumable_playtest_tuning.validate_tuning(game.item_category_catalog).is_empty(), "Inspector-authored provisional tonic category and healing value validate")
    _expect(game.consumable_playtest_tuning.heal_amount(TONIC) == 25, "tonic healing comes from editable resource, not gameplay code")
    var full := game.request_consumable_slot(0)
    _expect(not bool(full.get("accepted", true)) and full.get("reason_id", &"") == ConsumablePlaytestUseService.REASON_ALREADY_FULL, "full HP cannot consume inventory")
    var start_claim_count := profile.claimed_transactions.size()

    game.player.health.set_current_hp(70)
    var first := game.request_consumable_slot(0)
    _expect(bool(first.get("accepted", false)) and not bool(first.get("durable", true)) and first.get("durability_boundary", &"") == &"next_safe_snapshot", "first tonic use obeys normal unbanked/safe-save transaction semantics")
    _expect(game.player.health.current_hp == 95 and int(first.get("healed_hp", -1)) == 25, "first tonic heals the actual live HealthComponent by its Inspector amount")
    inventory.load_dictionary(profile.item_state)
    _expect(inventory.get_total_quantity(TONIC) == 1 and inventory.quick_slots[0] == STACK_ID and inventory.quick_slots[1] == STACK_ID, "partial stack removal leaves both legitimate quick references")
    _expect(profile.claimed_transactions.size() == start_claim_count + 1, "one successful use records one unique claim")

    game.input_ownership.open_modal(&"ui:consumable_test")
    var blocked := game.request_consumable_slot(1)
    _expect(not bool(blocked.get("accepted", true)) and game.player.health.current_hp == 95, "modal input ownership prevents shortcut use without healing")
    game.input_ownership.close_modal(&"ui:consumable_test", &"consumable_1")
    _expect(not bool(game.request_consumable_slot(0).get("accepted", true)), "modal close suppresses held triggering shortcut")
    game.input_ownership.notify_action_released(&"consumable_1")

    var second := game.request_consumable_slot(1)
    _expect(bool(second.get("accepted", false)) and game.player.health.current_hp == 100 and int(second.get("healed_hp", -1)) == 5, "last tonic heals only missing HP without exceeding maximum")
    inventory.load_dictionary(profile.item_state)
    _expect(inventory.get_total_quantity(TONIC) == 0 and inventory.quick_slots == [&"", &"", &"", &""], "last item consumption automatically clears every reference to exhausted stack")
    _expect(profile.claimed_transactions.size() == start_claim_count + 2, "second use has a separate transaction claim")
    _expect(not bool(game.request_consumable_slot(0).get("accepted", true)), "exhausted shortcut cannot generate tonic copies")

    _expect(bool(inventory.try_add_normal(&"item:playtest_ore", &"itemdef:region3_playtest_ore", 1, true).get("accepted", false)), "nonconsumable material fixture can be owned")
    _expect(inventory.bind_quick_slot(2, &"item:playtest_ore"), "legacy unvalidated quick reference may load for compatibility")
    profile.item_state = inventory.to_dictionary()
    game.player.health.set_current_hp(60)
    var material := game.request_consumable_slot(2)
    _expect(not bool(material.get("accepted", true)) and material.get("reason_id", &"") == ConsumablePlaytestUseService.REASON_UNAUTHORED, "material cannot be consumed as a tonic despite a legacy quick reference")
    inventory.load_dictionary(profile.item_state)
    _expect(inventory.get_total_quantity(&"itemdef:region3_playtest_ore") == 1 and game.player.health.current_hp == 60, "unauthored shortcut cannot mutate live HP or material inventory")
    _expect(not bool(game.request_consumable_slot(4).get("accepted", true)), "out-of-range quick slot fails closed")

    game.queue_free()
    await process_frame
    if _failures == 0:
        print("GAMEPLAY CONSUMABLE PLAYTEST TEST PASS")
    else:
        push_error("GAMEPLAY CONSUMABLE PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
