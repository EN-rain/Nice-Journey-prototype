extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_live_contact_and_enemy_lifecycle()
    _test_runtime_defense_mutation()
    _test_player_defeat_signal()
    _test_invalid_contact_does_not_poison_ledger()

    if _failures == 0:
        print("COMBAT ENCOUNTER RUNTIME TEST PASS")
    else:
        push_error("COMBAT ENCOUNTER RUNTIME TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_live_contact_and_enemy_lifecycle() -> void:
    var shared_combat: ActiveCombatRegistry = ActiveCombatRegistry.new()
    var encounter: CombatEncounterRuntime = CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:wave29_fixture", shared_combat), "encounter runtime accepts a stable encounter identity")

    var player: CombatantRuntimeState = _combatant(&"player:protagonist", 100, 100.0, 0.0, 0.0, 50.0, true, true, true)
    var enemy: CombatantRuntimeState = _combatant(&"enemy:duelist_fixture", 18, 0.0, 0.0, 0.0, 15.0, true, false, false)
    _expect(encounter.register_player(player), "runtime registers player combatant")
    _expect(encounter.register_enemy(enemy), "runtime activates first enemy combatant")
    _expect(shared_combat.is_active(), "active enemy acquisition raises shared Active Combat state")
    _expect(encounter.full_ai.is_admitted_to_encounter(enemy.actor_id, encounter.encounter_id), "activated enemy owns one FULL-AI admission in this encounter")

    var reserve_token: int = encounter.reserve_enemy_attack(enemy.actor_id, player.actor_id, 7001)
    _expect(reserve_token > 0, "active admitted enemy can reserve an attack participation token")
    _expect(encounter.reservations.get_active_count() == 1, "reservation becomes observable in encounter-owned ledger")

    var tuning: StarterCombatTuning = StarterCombatTuning.new()
    var melee: StarterKitDefinition = StarterKitCatalog.create(&"melee", tuning)
    var first_hit: Dictionary = encounter.resolve_direct_contact(
        player.actor_id,
        enemy.actor_id,
        1001,
        0,
        melee.make_basic_attack_payload(),
        false,
        DirectHitResolver.DEFENSE_NONE,
        false
    )
    _expect(first_hit["accepted"] and first_hit["hp_damage"] == 10 and first_hit["target_hp_after"] == 8, "first live contact resolves shared damage then mutates encounter-owned HP once")
    _expect(encounter.contacts.has_contact(1001, enemy.actor_id, 0), "successful contact is recorded by action-instance/target/interval identity")

    var duplicate: Dictionary = encounter.resolve_direct_contact(
        player.actor_id,
        enemy.actor_id,
        1001,
        0,
        melee.make_basic_attack_payload(),
        false,
        DirectHitResolver.DEFENSE_NONE,
        false
    )
    _expect(not duplicate["accepted"] and duplicate["reason_id"] == &"duplicate_contact", "duplicate animation/collision delivery cannot damage the same target twice in one hit interval")
    _expect(enemy.current_hp == 8, "duplicate contact rejection leaves HP unchanged")

    var poise: Dictionary = encounter.apply_poise_to_target(enemy.actor_id, 15.0)
    _expect(poise["accepted"] and poise["threshold_reached"] and poise["interruption_recovery_requested"], "encounter mutation owner composes the approved poise threshold/interruption semantics")
    _expect(enemy.accumulated_poise == 0.0, "threshold poise resets on the runtime-owned combatant state")

    var second_hit: Dictionary = encounter.resolve_direct_contact(
        player.actor_id,
        enemy.actor_id,
        1002,
        0,
        melee.make_basic_attack_payload(),
        false,
        DirectHitResolver.DEFENSE_NONE,
        false
    )
    _expect(second_hit["accepted"] and second_hit["target_defeated"] and enemy.current_hp == 0, "second legal contact defeats the enemy through authoritative HP mutation")
    _expect(encounter.get_active_enemy_count() == 0, "enemy lifecycle leaves Active after defeat")
    _expect(not encounter.full_ai.is_admitted(enemy.actor_id), "defeated enemy releases its FULL-AI admission")
    _expect(encounter.reservations.get_active_count() == 0, "enemy death releases outstanding attack reservations")
    _expect(not shared_combat.is_active(), "last hostile defeat releases the encounter Active Combat reason")


func _test_runtime_defense_mutation() -> void:
    var encounter: CombatEncounterRuntime = CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:defense_fixture"), "defense fixture configures")
    var player: CombatantRuntimeState = _combatant(&"player:defender", 100, 15.0, 0.0, 0.0, 50.0, true, true, true)
    var enemy: CombatantRuntimeState = _combatant(&"enemy:attacker", 100, 0.0, 0.0, 0.0, 50.0, true, false, false)
    _expect(encounter.register_player(player) and encounter.register_enemy(enemy), "defense fixture registers combatants")

    var attack: Dictionary = _contact_attack(12.0, 10.0)
    var blocked: Dictionary = encounter.resolve_direct_contact(enemy.actor_id, player.actor_id, 2001, 0, attack, false, DirectHitResolver.DEFENSE_BLOCK, true)
    _expect(blocked["accepted"] and blocked["outcome"] == DirectHitResolver.OUTCOME_BLOCKED, "supported facing block is honored by the live mutation owner")
    _expect(player.current_hp == 100 and is_equal_approx(player.current_stamina, 5.0), "successful live block deals zero HP and applies authored guard pressure")

    var broken: Dictionary = encounter.resolve_direct_contact(enemy.actor_id, player.actor_id, 2002, 0, attack, false, DirectHitResolver.DEFENSE_BLOCK, true)
    _expect(broken["accepted"] and broken["outcome"] == DirectHitResolver.OUTCOME_GUARD_BROKEN, "insufficient live stamina produces guard break")
    _expect(player.current_hp == 88 and is_equal_approx(player.current_stamina, 0.0), "guard-broken live hit applies normal HP damage and zeros available stamina")
    encounter.end_encounter()
    _expect(not encounter.active_combat.is_active() and encounter.reservations.get_active_count() == 0, "explicit encounter exit releases encounter-owned combat/reservation state")


func _test_player_defeat_signal() -> void:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:player_defeat_fixture"), "player-defeat fixture configures")
    var player := _combatant(&"player:defeat_fixture", 20, 100.0, 0.0, 0.0, 50.0, true, false, false)
    var enemy := _combatant(&"enemy:defeat_fixture", 100, 0.0, 0.0, 0.0, 50.0, true, false, false)
    _expect(encounter.register_player(player) and encounter.register_enemy(enemy), "player-defeat fixture registers combatants")
    var defeats: Array[StringName] = []
    encounter.player_defeated.connect(func(actor_id: StringName) -> void: defeats.append(actor_id))
    var reservation := encounter.reserve_enemy_attack(enemy.actor_id, player.actor_id, 4001)
    _expect(reservation > 0, "enemy can own an attack reservation against the live player before defeat")
    var fatal := encounter.resolve_direct_contact(enemy.actor_id, player.actor_id, 4001, 0, _contact_attack(50.0, 0.0), false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(fatal.get("accepted", false)) and bool(fatal.get("target_defeated", false)), "authoritative contact can defeat the registered player")
    _expect(defeats == [&"player:defeat_fixture"], "registered player defeat emits exactly one explicit player_defeated event")
    _expect(encounter.get_active_enemy_count() == 1, "player defeat does not incorrectly resolve the living hostile lifecycle")
    _expect(encounter.reservations.get_active_count() == 0, "player defeat invalidates reservations targeting the defeated player")
    var duplicate := encounter.resolve_direct_contact(enemy.actor_id, player.actor_id, 4002, 0, _contact_attack(50.0, 0.0), false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(not bool(duplicate.get("accepted", false)) and defeats.size() == 1, "defeated player cannot emit duplicate death from later contacts")
    encounter.end_encounter()


func _test_invalid_contact_does_not_poison_ledger() -> void:
    var encounter: CombatEncounterRuntime = CombatEncounterRuntime.new()
    encounter.configure(&"encounter:validation_fixture")
    var player: CombatantRuntimeState = _combatant(&"player:validation", 100, 100.0, 0.0, 0.0, 50.0, true, false, false)
    var enemy: CombatantRuntimeState = _combatant(&"enemy:validation", 100, 0.0, 0.0, 0.0, 50.0, true, false, false)
    encounter.register_player(player)
    encounter.register_enemy(enemy)

    var malformed: Dictionary = _contact_attack(10.0, 0.0)
    malformed["delivery"] = DirectHitResolver.DELIVERY_PROJECTILE
    malformed["parryable"] = true
    var rejected: Dictionary = encounter.resolve_direct_contact(player.actor_id, enemy.actor_id, 3001, 0, malformed, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(not rejected["accepted"] and not encounter.contacts.has_contact(3001, enemy.actor_id, 0), "invalid resolver input is rejected before consuming contact identity")

    malformed["parryable"] = false
    var retry: Dictionary = encounter.resolve_direct_contact(player.actor_id, enemy.actor_id, 3001, 0, malformed, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(retry["accepted"] and encounter.contacts.has_contact(3001, enemy.actor_id, 0), "corrected contact can use the same identity after malformed input was rejected")


func _combatant(
    actor_id: StringName,
    hp: int,
    stamina: float,
    physical_defense: float,
    arcane_defense: float,
    poise_threshold: float,
    interruptible: bool,
    block_supported: bool,
    parry_supported: bool
) -> CombatantRuntimeState:
    var state: CombatantRuntimeState = CombatantRuntimeState.new()
    var accepted: bool = state.configure(
        actor_id,
        hp,
        stamina,
        physical_defense,
        arcane_defense,
        poise_threshold,
        interruptible,
        block_supported,
        parry_supported
    )
    _expect(accepted, "%s combatant fixture validates" % String(actor_id))
    return state


func _contact_attack(raw_damage: float, guard_pressure: float) -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": raw_damage,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": guard_pressure,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
