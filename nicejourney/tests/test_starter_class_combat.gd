extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_locked_starter_kits()
    _test_resource_free_basic_actions()
    _test_basic_attack_resolution_contract()
    _test_melee_defense_state()
    _test_mage_mana_recovery()
    _test_invalid_configuration()

    if _failures == 0:
        print("STARTER CLASS COMBAT TEST PASS")
    else:
        push_error("STARTER CLASS COMBAT TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_locked_starter_kits() -> void:
    var tuning: StarterCombatTuning = StarterCombatTuning.new()
    var melee: StarterKitDefinition = StarterKitCatalog.create(&"melee", tuning)
    var ranged: StarterKitDefinition = StarterKitCatalog.create(&"ranged", tuning)
    var mage: StarterKitDefinition = StarterKitCatalog.create(&"mage", tuning)

    _expect(melee != null and StarterKitCatalog.validate_locked_contract(melee).is_empty(), "Melee starter kit satisfies the locked DR-04 contract")
    _expect(melee.main_hand_id == &"starter_sword" and melee.off_hand_id == &"starter_shield", "Melee starts sword plus shield")
    _expect(melee.supports_block and melee.supports_parry, "Melee starter shield supports block and parry")
    _expect(not melee.has_mana and not melee.tracks_ammunition, "Melee does not invent mana or ammunition")

    _expect(ranged != null and StarterKitCatalog.validate_locked_contract(ranged).is_empty(), "Ranged starter kit satisfies the locked DR-04 contract")
    _expect(ranged.main_hand_id == &"starter_bow" and ranged.off_hand_id == &"" and ranged.two_handed and not ranged.off_hand_allowed, "Ranged starts with two-handed bow and empty locked off-hand")
    _expect(not ranged.tracks_ammunition, "Ranged prototype tracks no ammunition")
    _expect(not ranged.supports_block and not ranged.supports_parry and not ranged.has_mana, "Ranged starter kit relies on dodge without baseline block/parry or mana")

    _expect(mage != null and StarterKitCatalog.validate_locked_contract(mage).is_empty(), "Mage starter kit satisfies the locked DR-04 contract")
    _expect(mage.main_hand_id == &"starter_staff" and mage.off_hand_id == &"" and mage.two_handed and not mage.off_hand_allowed, "Mage starts with two-handed staff and empty locked off-hand")
    _expect(mage.has_mana and not mage.tracks_ammunition, "Mage alone exposes mana and no ammunition")
    _expect(not mage.supports_block and not mage.supports_parry, "Mage starter kit has no baseline block/parry")


func _test_resource_free_basic_actions() -> void:
    var tuning: StarterCombatTuning = StarterCombatTuning.new()
    for class_id: StringName in [&"melee", &"ranged", &"mage"]:
        var machine: ActionStateMachine = ActionStateMachine.new()
        var runtime: ClassCombatRuntime = ClassCombatRuntime.new()
        runtime.tuning = tuning
        runtime.bind_runtime(machine)
        _expect(runtime.configure_class(class_id), "%s starter runtime configures" % String(class_id))
        _expect(runtime.starter_kit.basic_action.cost_amount == 0.0 and runtime.starter_kit.basic_action.cost_resource == &"", "%s basic attack is resource-free" % String(class_id))
        if class_id == &"mage":
            _expect(runtime.resource_pool.set_value(&"mana", 0.0), "Mage mana can be depleted for exhausted-resource fixture")
        _expect(runtime.request_basic_attack(Vector2.RIGHT), "%s retains a usable basic attack at exhausted class resources" % String(class_id))
        _expect(machine.get_current_action_id() == runtime.starter_kit.basic_action.action_id, "%s basic request enters the shared action framework" % String(class_id))
        runtime.free()
        machine.free()


func _test_basic_attack_resolution_contract() -> void:
    var tuning: StarterCombatTuning = StarterCombatTuning.new()
    var defender: Dictionary = _base_defender()

    var melee: StarterKitDefinition = StarterKitCatalog.create(&"melee", tuning)
    var melee_hit: Dictionary = DirectHitResolver.resolve(melee.make_basic_attack_payload(), defender)
    _expect(melee_hit["accepted"] and melee_hit["outcome"] == DirectHitResolver.OUTCOME_HIT, "Melee starter basic resolves through the shared direct-hit resolver")
    _expect(melee.basic_damage_domain == DirectHitResolver.DOMAIN_PHYSICAL and melee.basic_delivery == DirectHitResolver.DELIVERY_CONTACT, "Melee starter basic is Physical contact")

    var ranged: StarterKitDefinition = StarterKitCatalog.create(&"ranged", tuning)
    var ranged_payload: Dictionary = ranged.make_basic_attack_payload()
    _expect(ranged_payload["delivery"] == DirectHitResolver.DELIVERY_PROJECTILE and not ranged_payload["parryable"], "Ranged starter basic is an unparryable prototype projectile")
    _expect(DirectHitResolver.resolve(ranged_payload, defender)["accepted"], "Ranged starter basic is valid shared-resolver input")

    var mage: StarterKitDefinition = StarterKitCatalog.create(&"mage", tuning)
    var mage_payload: Dictionary = mage.make_basic_attack_payload()
    _expect(mage_payload["domain"] == DirectHitResolver.DOMAIN_ARCANE and mage_payload["delivery"] == DirectHitResolver.DELIVERY_PROJECTILE, "Mage starter bolt is Arcane projectile damage")
    _expect(DirectHitResolver.resolve(mage_payload, defender)["accepted"], "Mage starter basic is valid shared-resolver input")


func _test_melee_defense_state() -> void:
    var tuning := StarterCombatTuning.new()
    tuning.melee_parry_window_ticks = 3
    tuning.melee_parry_recovery_ticks = 2
    var machine := ActionStateMachine.new()
    var runtime := ClassCombatRuntime.new()
    runtime.tuning = tuning
    runtime.bind_runtime(machine)
    _expect(runtime.configure_class(&"melee"), "Melee defense runtime configures")
    _expect(runtime.request_block(true), "supported Melee block enters sustained defense state")
    _expect(runtime.get_defense_mode() == DirectHitResolver.DEFENSE_BLOCK, "Melee block exposes authoritative defense mode")
    _expect(not runtime.request_basic_attack(Vector2.RIGHT), "committed basic attack does not start through active block")
    _expect(runtime.request_block(false) and runtime.get_defense_mode() == DirectHitResolver.DEFENSE_NONE, "block release clears defense state")
    tuning.melee_parry_window_ticks = 0
    _expect(not runtime.request_parry() and runtime.get_defense_mode() == DirectHitResolver.DEFENSE_NONE,
        "invalidated live Inspector parry window cannot create permanent zero-window parry")
    tuning.melee_parry_window_ticks = 3
    _expect(runtime.request_parry(), "supported Melee parry starts its authored timing window")
    _expect(runtime.get_defense_mode() == DirectHitResolver.DEFENSE_PARRY and runtime.get_parry_window_ticks_remaining() == 3, "parry exposes its configured active window")
    _expect(not runtime.request_parry(), "parry cannot be spammed during its active window")
    runtime.advance_resource_tick()
    runtime.advance_resource_tick()
    runtime.advance_resource_tick()
    _expect(runtime.get_defense_mode() == DirectHitResolver.DEFENSE_NONE, "parry mode clears when its active window expires")
    _expect(runtime.get_parry_recovery_ticks_remaining() == 2, "parry enters configured recovery after the active window")
    _expect(not runtime.request_block(true), "block cannot bypass active parry recovery")
    runtime.advance_resource_tick()
    runtime.advance_resource_tick()
    _expect(runtime.request_block(true), "block becomes legal after parry recovery")
    runtime.cancel_defense()

    for unsupported_class: StringName in [&"ranged", &"mage"]:
        var unsupported_machine := ActionStateMachine.new()
        var unsupported := ClassCombatRuntime.new()
        unsupported.tuning = tuning
        unsupported.bind_runtime(unsupported_machine)
        _expect(unsupported.configure_class(unsupported_class), "%s defense fixture configures" % String(unsupported_class))
        _expect(not unsupported.request_block(true) and not unsupported.request_parry(), "%s starter kit cannot accept unsupported block/parry" % String(unsupported_class))
        unsupported.free()
        unsupported_machine.free()
    runtime.free()
    machine.free()


func _test_mage_mana_recovery() -> void:
    var tuning: StarterCombatTuning = StarterCombatTuning.new()
    tuning.mage_max_mana = 20.0
    tuning.mage_regeneration_delay_ticks = 3
    tuning.mage_regeneration_per_tick = 2.0

    var machine: ActionStateMachine = ActionStateMachine.new()
    var runtime: ClassCombatRuntime = ClassCombatRuntime.new()
    runtime.tuning = tuning
    runtime.bind_runtime(machine)
    _expect(runtime.configure_class(&"mage"), "Mage runtime configures its mana resource")

    var spell: ActionDefinition = ActionDefinition.new()
    spell.action_id = &"fixture_mana_spell"
    spell.startup_ticks = 1
    spell.commit_ticks = 1
    spell.active_ticks = 1
    spell.recovery_ticks = 1
    spell.cost_resource = &"mana"
    spell.cost_amount = 5.0
    _expect(machine.request_action(spell), "Mage mana-spending action is admitted with sufficient mana")
    machine.advance_fixed_tick()
    _expect(is_equal_approx(runtime.get_mana(), 15.0), "Mana spends exactly once at action commitment")
    _expect(runtime.mana_regenerator.get_remaining_delay_ticks() == 3, "Mana-spending commitment starts the authored regeneration delay")

    runtime.advance_resource_tick()
    runtime.advance_resource_tick()
    runtime.advance_resource_tick()
    _expect(is_equal_approx(runtime.get_mana(), 15.0), "Mana does not regenerate during the configured delay")
    runtime.advance_resource_tick()
    _expect(is_equal_approx(runtime.get_mana(), 17.0), "Mana regenerates after delay even without an out-of-combat requirement")

    var second_spell: ActionDefinition = ActionDefinition.new()
    second_spell.action_id = &"fixture_mana_spell_two"
    second_spell.startup_ticks = 0
    second_spell.commit_ticks = 1
    second_spell.active_ticks = 1
    second_spell.recovery_ticks = 0
    second_spell.cost_resource = &"mana"
    second_spell.cost_amount = 2.0
    while machine.is_busy():
        machine.advance_fixed_tick()
    _expect(machine.request_action(second_spell), "second mana-spending action can start after the first finishes")
    _expect(runtime.mana_regenerator.get_remaining_delay_ticks() == 3, "zero-startup mana action commits immediately and restarts regeneration delay")
    _expect(is_equal_approx(runtime.get_mana(), 15.0), "second mana commitment spends exactly once")
    runtime.free()
    machine.free()


func _test_invalid_configuration() -> void:
    var tuning: StarterCombatTuning = StarterCombatTuning.new()
    _expect(StarterKitCatalog.create(&"warlock", tuning) == null, "unknown class cannot fabricate a starter kit")

    var bad_tuning: StarterCombatTuning = StarterCombatTuning.new()
    bad_tuning.mage_max_mana = NAN
    _expect(StarterKitCatalog.create(&"mage", bad_tuning) == null, "nonfinite starter tuning is rejected")

    var invalid_projectile: StarterKitDefinition = StarterKitCatalog.create(&"ranged", tuning)
    invalid_projectile.basic_parryable = true
    _expect(not invalid_projectile.validate_definition().is_empty(), "parryable prototype projectile is rejected at starter-kit validation")


func _base_defender() -> Dictionary:
    return {
        "evade_window_active": false,
        "defense_mode": &"none",
        "block_supported": false,
        "parry_supported": false,
        "facing_covered": false,
        "current_stamina": 100.0,
        "physical_defense": 0.0,
        "arcane_defense": 0.0,
    }


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
