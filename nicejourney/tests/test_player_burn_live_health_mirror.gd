extends SceneTree

const SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const PLAYER_TUNING: PlayerCombatRuntimeTuning = preload("res://src/data/tuning/player_combat_runtime_default.tres")
const STATUS: StatusPlaytestTuning = preload("res://src/data/tuning/status_effects_playtest_v01.tres")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var game := SCENE.instantiate() as GameplayRoot
    game.set_profile(ProfileCreationService.create_profile(1, "Burn Mirror", "melee"))
    root.add_child(game)
    await process_frame

    var state_a := PlayerCombatantRuntimeBinding.create_state(game.player, game.combat_runtime, PLAYER_TUNING)
    var state_b := PlayerCombatantRuntimeBinding.create_state(game.player, game.combat_runtime, PLAYER_TUNING)
    var encounter_a := CombatEncounterRuntime.new()
    var encounter_b := CombatEncounterRuntime.new()
    _expect(encounter_a.configure(&"encounter:burn_mirror_a") and encounter_b.configure(&"encounter:burn_mirror_b"), "separate encounters configure")
    _expect(encounter_a.register_player(state_a) and encounter_b.register_player(state_b), "each encounter registers its own player state")
    var enemy_a := _enemy(&"enemy:burn_mirror_a")
    var enemy_b := _enemy(&"enemy:burn_mirror_b")
    _expect(encounter_a.register_enemy(enemy_a) and encounter_b.register_enemy(enemy_b), "each encounter registers an enemy")
    encounter_a.status_playtest_tuning = STATUS

    var binding_a := PlayerCombatantRuntimeBinding.new()
    var binding_b := PlayerCombatantRuntimeBinding.new()
    _expect(binding_a.bind(game.player, encounter_a, state_a) and binding_b.bind(game.player, encounter_b, state_b), "two encounter bindings mirror one live player")
    var events: Array[String] = []
    encounter_a.status_damage_resolved.connect(func(actor_id: StringName, damage: int, hp_after: int) -> void:
        if actor_id == state_a.actor_id:
            events.append("burn:%d:%d" % [damage, hp_after])
    )
    binding_a.live_player_defeated.connect(func(_actor_id: StringName) -> void:
        events.append("death:%d" % game.player.health.current_hp)
    )

    _expect(bool(encounter_a.apply_status_to_target(state_a.actor_id, STATUS.application(PrototypeStatusResolver.BEHAVIOR_BURN)).get("accepted", false)), "live player accepts provisional Burn")
    var initial_hp := game.player.health.current_hp
    var before := encounter_a.advance_status_ticks(29)
    _expect(bool(before.get("accepted", false)) and game.player.health.current_hp == initial_hp, "Burn does not hit before its configured cadence")
    var tick := encounter_a.advance_status_ticks(1)
    _expect(bool(tick.get("accepted", false)) and game.player.health.current_hp == initial_hp - STATUS.burn_damage_per_tick, "Burn reaches live HealthComponent immediately")
    _expect(state_a.current_hp == game.player.health.current_hp and state_b.current_hp == game.player.health.current_hp, "one Burn tick synchronizes all overlapping encounter player states")
    _expect(events == ["burn:2:%d" % (initial_hp - 2)], "exactly one status damage event emitted for a Burn tick")

    game.player.health.set_current_hp(3)
    _expect(state_a.current_hp == 3 and state_b.current_hp == 3, "live health adjustment synchronizes both encounter owners")
    encounter_a.advance_status_ticks(30)
    _expect(game.player.health.current_hp == 1 and state_b.current_hp == 1, "subsequent Burn tick preserves live and second encounter health")
    encounter_a.advance_status_ticks(30)
    _expect(game.player.health.current_hp == 0 and state_a.is_defeated() and state_b.is_defeated(), "fatal Burn reduces live and overlapping encounter HP to zero")
    _expect(events.slice(-2) == ["burn:2:0", "death:0"], "fatal status damage mirrors to player before defeat event")
    var count_before := events.size()
    encounter_a.advance_status_ticks(30)
    _expect(events.size() == count_before, "dead player never receives an extra Burn tick or repeated defeat")
    _expect(encounter_b.status_playtest_tuning == null, "unrelated encounter does not gain Burn tuning")

    binding_a.unbind()
    binding_b.unbind()
    game.player.health.set_current_hp(12)
    encounter_a.status_damage_resolved.emit(state_a.actor_id, 2, 4)
    _expect(game.player.health.current_hp == 12, "unbound status signal cannot mutate the live player")
    encounter_a.end_encounter()
    encounter_b.end_encounter()
    game.queue_free()
    await process_frame

    if _failures == 0:
        print("PLAYER BURN LIVE HEALTH MIRROR TEST PASS")
    else:
        push_error("PLAYER BURN LIVE HEALTH MIRROR TEST FAILURES: %d" % _failures)
    quit(_failures)


func _enemy(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    state.configure(actor_id, 30, 0.0, 0.0, 0.0, 10.0, true, false, false)
    return state


func _expect(ok: bool, name: String) -> void:
    if ok:
        print("PASS: %s" % name)
    else:
        _failures += 1
        push_error("FAIL: %s" % name)
