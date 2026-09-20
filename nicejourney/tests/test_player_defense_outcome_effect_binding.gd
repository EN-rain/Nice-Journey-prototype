extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

var _failures := 0
var _effect_events: Array[Array] = []


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var player_visual := PLAYER_SCENE.instantiate() as PlayerController
    root.add_child(player_visual)
    await process_frame

    var controller := player_visual.get_node_or_null("CombatOutcomeEffectController") as CombatOutcomeEffectController
    _expect(controller != null, "player scene owns the defense-outcome effect controller")
    _expect(controller != null and controller.presenter != null, "defense-outcome controller resolves its inspector-owned EffectSpritePresenter")
    _expect(controller != null and controller.validate_setup().is_empty(), "inspector-authored defense-outcome effect mappings validate")
    if controller != null:
        controller.effect_played.connect(_on_effect_played)

    var runtime := CombatEncounterRuntime.new()
    _expect(runtime.configure(&"encounter:player_defense_effect_fixture"), "defense-effect fixture configures genuine encounter runtime")
    var player_state := _combatant(&"player:defense_effect_fixture", 100, 20.0, true, true)
    var enemy_state := _combatant(&"enemy:defense_effect_fixture", 100, 0.0, false, false)
    _expect(runtime.register_player(player_state), "defense-effect fixture registers player combatant")
    _expect(runtime.register_enemy(enemy_state), "defense-effect fixture registers attacker through normal enemy lifecycle")
    _expect(controller.bind_runtime(runtime, player_state.actor_id), "defense-outcome controller binds to genuine runtime and stable player identity")

    var blocked := runtime.resolve_direct_contact(
        enemy_state.actor_id,
        player_state.actor_id,
        5101,
        0,
        _attack(8.0, 5.0),
        false,
        DirectHitResolver.DEFENSE_BLOCK,
        true
    )
    _expect(blocked["accepted"] and blocked["outcome"] == DirectHitResolver.OUTCOME_BLOCKED, "authoritative block outcome resolves")
    _expect(controller.get_last_effect_id() == &"vfx_block_spark", "block outcome selects generated block spark through inspector binding")

    var parried := runtime.resolve_direct_contact(
        enemy_state.actor_id,
        player_state.actor_id,
        5102,
        0,
        _attack(8.0, 0.0),
        false,
        DirectHitResolver.DEFENSE_PARRY,
        true
    )
    _expect(parried["accepted"] and parried["outcome"] == DirectHitResolver.OUTCOME_PARRIED, "authoritative parry outcome resolves")
    _expect(controller.get_last_effect_id() == &"vfx_parry_spark", "parry outcome selects generated parry spark through inspector binding")

    var guard_broken := runtime.resolve_direct_contact(
        enemy_state.actor_id,
        player_state.actor_id,
        5103,
        0,
        _attack(8.0, 30.0),
        false,
        DirectHitResolver.DEFENSE_BLOCK,
        true
    )
    _expect(guard_broken["accepted"] and guard_broken["outcome"] == DirectHitResolver.OUTCOME_GUARD_BROKEN, "authoritative guard-break outcome resolves")
    _expect(controller.get_last_effect_id() == &"telegraph_guard_break", "guard-break outcome selects generated guard-break cue through inspector binding")

    _expect(_effect_events == [
        [DirectHitResolver.OUTCOME_BLOCKED, &"vfx_block_spark"],
        [DirectHitResolver.OUTCOME_PARRIED, &"vfx_parry_spark"],
        [DirectHitResolver.OUTCOME_GUARD_BROKEN, &"telegraph_guard_break"],
    ], "effect events preserve authoritative outcome order without polling")

    controller.unbind_runtime()
    _expect(controller.bound_runtime == null and controller.bound_actor_id == &"", "explicit defense-effect unbind clears runtime ownership")

    var source := FileAccess.get_file_as_string("res://src/player/presentation/effects/combat_outcome_effect_controller.gd")
    _expect(not source.contains("res://assets/art"), "defense-outcome controller contains no hardcoded art paths")
    _expect(not source.contains("vfx_block_spark") and not source.contains("vfx_parry_spark") and not source.contains("telegraph_guard_break"), "effect identities remain inspector data rather than runtime constants")
    _expect(not source.contains(".frame =") and not source.contains("frame_coords"), "defense-outcome controller never manually steps sprite frames")

    runtime.end_encounter()
    player_visual.queue_free()
    await process_frame

    if _failures == 0:
        print("PLAYER DEFENSE OUTCOME EFFECT BINDING TEST PASS")
    else:
        push_error("PLAYER DEFENSE OUTCOME EFFECT BINDING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _combatant(actor_id: StringName, hp: int, stamina: float, block_supported: bool, parry_supported: bool) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    var accepted := state.configure(actor_id, hp, stamina, 0.0, 0.0, 20.0, true, block_supported, parry_supported)
    _expect(accepted, "%s combatant validates" % String(actor_id))
    return state


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


func _on_effect_played(outcome_id: StringName, effect_id: StringName) -> void:
    _effect_events.append([outcome_id, effect_id])


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
