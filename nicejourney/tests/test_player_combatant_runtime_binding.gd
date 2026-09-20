extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const PLAYER_COMBAT_TUNING: PlayerCombatRuntimeTuning = preload("res://src/data/tuning/player_combat_runtime_default.tres")

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    await _test_live_player_binding()
    if _failures == 0:
        print("PLAYER COMBATANT RUNTIME BINDING TEST PASS")
    else:
        push_error("PLAYER COMBATANT RUNTIME BINDING TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_live_player_binding() -> void:
    var profile := ProfileCreationService.create_profile(1, "Combatant Binding", "melee")
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    get_root().add_child(gameplay)
    await process_frame

    var player_state := PlayerCombatantRuntimeBinding.create_state(
        gameplay.player,
        gameplay.combat_runtime,
        PLAYER_COMBAT_TUNING,
        &"player:live_binding"
    )
    _expect(player_state != null, "live player components produce a valid CombatantRuntimeState")
    if player_state == null:
        gameplay.queue_free()
        await process_frame
        return
    _expect(player_state.current_hp == gameplay.player.health.current_hp and is_equal_approx(player_state.current_stamina, gameplay.player.stamina.current_stamina), "created runtime state starts from authoritative live HP/stamina")
    _expect(player_state.block_supported and player_state.parry_supported, "Melee runtime state inherits class-owned defense support")

    var enemy := CombatantRuntimeState.new()
    _expect(enemy.configure(&"enemy:live_binding", 100, 0.0, 0.0, 0.0, 20.0, true, false, false), "binding enemy fixture configures")
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:live_player_binding"), "binding encounter configures")
    _expect(encounter.register_player(player_state) and encounter.register_enemy(enemy), "binding encounter registers live player state and enemy")

    var binding := PlayerCombatantRuntimeBinding.new()
    var defeat_events: Array[StringName] = []
    binding.live_player_defeated.connect(func(actor_id: StringName) -> void: defeat_events.append(actor_id))
    _expect(binding.bind(gameplay.player, encounter, player_state), "player runtime binding attaches to authoritative encounter state")

    _expect(gameplay.player.stamina.try_spend(20.0), "movement/resource owner can spend live stamina")
    _expect(is_equal_approx(player_state.current_stamina, gameplay.player.stamina.current_stamina), "live stamina changes propagate into encounter defender state")

    var hit := encounter.resolve_direct_contact(
        enemy.actor_id,
        player_state.actor_id,
        51001,
        0,
        _attack(25.0, 0.0),
        false,
        DirectHitResolver.DEFENSE_NONE,
        true
    )
    _expect(bool(hit.get("accepted", false)) and gameplay.player.health.current_hp == 75, "authoritative encounter HP damage propagates back to the live HealthComponent")

    var stamina_before := gameplay.player.stamina.current_stamina
    var blocked := encounter.resolve_direct_contact(
        enemy.actor_id,
        player_state.actor_id,
        51002,
        0,
        _attack(10.0, 10.0),
        false,
        DirectHitResolver.DEFENSE_BLOCK,
        true
    )
    _expect(blocked.get("outcome", &"") == DirectHitResolver.OUTCOME_BLOCKED, "live player binding preserves shared block semantics")
    _expect(is_equal_approx(gameplay.player.stamina.current_stamina, stamina_before - 10.0), "guard pressure propagates from encounter state back to movement stamina")
    _expect(float(gameplay.player.stamina.capture_safe_state().get("regeneration_block_time", 0.0)) > 0.0, "combat stamina pressure suppresses regeneration through the live component")

    var fatal := encounter.resolve_direct_contact(
        enemy.actor_id,
        player_state.actor_id,
        51003,
        0,
        _attack(1000.0, 0.0),
        false,
        DirectHitResolver.DEFENSE_NONE,
        true
    )
    _expect(bool(fatal.get("target_defeated", false)) and gameplay.player.health.is_defeated(), "fatal authoritative contact reaches the live player health owner")
    _expect(defeat_events == [&"player:live_binding"], "live binding forwards one explicit player-defeated event")

    binding.unbind()
    encounter.end_encounter()
    gameplay.queue_free()
    await process_frame

func _attack(raw_damage: float, guard_pressure: float) -> Dictionary:
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
