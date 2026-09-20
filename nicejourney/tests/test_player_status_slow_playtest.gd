extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const STATUS: StatusPlaytestTuning = preload("res://src/data/tuning/status_effects_playtest_v01.tres")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(ProfileCreationService.create_profile(1, "Player Slow Playtest", "melee"))
    root.add_child(game)
    await process_frame
    var player := game.player
    var movement := player.movement
    var walk := movement.tuning.walk_speed
    var run := movement.tuning.run_speed
    _expect(game.status_playtest_tuning == STATUS and STATUS.validate_tuning().is_empty(), "shipped scene owns valid provisional status tuning")
    _expect(is_equal_approx(movement.calculate_move_velocity(Vector2.RIGHT, false).length(), walk), "no Slow preserves authored walk speed")

    var slow := STATUS.application(PrototypeStatusResolver.BEHAVIOR_SLOW)
    _expect(game.combat_runtime.store_status_safe_states([{
        "status_id": slow["status_id"],
        "behavior": slow["behavior"],
        "magnitude": slow["magnitude"],
        "remaining_ticks": slow["duration_ticks"],
    }]), "safe-state owner holds the authored player Slow")
    player._refresh_status_movement_multiplier()
    _expect(is_equal_approx(movement.get_status_speed_multiplier(), 0.75), "player slow reads persisted status when no encounter is bound")
    _expect(is_equal_approx(movement.calculate_move_velocity(Vector2.RIGHT, false).length(), walk * 0.75), "Slow reduces normal movement only by strongest magnitude")
    _expect(is_equal_approx(movement.calculate_move_velocity(Vector2.RIGHT, true).length(), run * 0.75), "Slow also reduces run movement without retuning authored run speed")

    var stronger := {
        "status_id": &"status:playtest_slow_other",
        "behavior": PrototypeStatusResolver.BEHAVIOR_SLOW,
        "magnitude": 0.95,
        "remaining_ticks": 10,
    }
    _expect(game.combat_runtime.store_status_safe_states([
        {
            "status_id": slow["status_id"],
            "behavior": slow["behavior"],
            "magnitude": slow["magnitude"],
            "remaining_ticks": slow["duration_ticks"],
        }, stronger
    ]), "different valid Slow identities coexist")
    player._refresh_status_movement_multiplier()
    _expect(is_equal_approx(movement.get_status_speed_multiplier(), STATUS.slow_speed_floor_multiplier), "player Slow obeys same strongest-only movement floor as enemy Slow")

    player.stamina.restore_full()
    _expect(movement.try_start_dash(player.stamina, Vector2.RIGHT), "dash remains available with Slow instead of scaling dodge or action clocks")
    movement._tick_burst(player, 0.0)
    _expect(is_equal_approx(player.velocity.length(), movement.tuning.dash_speed * STATUS.slow_speed_floor_multiplier), "movement burst displacement respects Slow without modifying its duration")

    _expect(game.combat_runtime.store_status_safe_states([]), "all Slow can be removed by the existing safe-state owner")
    player._refresh_status_movement_multiplier()
    _expect(is_equal_approx(movement.get_status_speed_multiplier(), 1.0), "status expiration immediately restores normal speed")
    _expect(is_equal_approx(movement.calculate_move_velocity(Vector2.RIGHT, false).length(), walk), "no stale Slow survives restoration")
    _expect(not movement.set_status_speed_multiplier(0.0) and not movement.set_status_speed_multiplier(INF) and is_equal_approx(movement.get_status_speed_multiplier(), 1.0), "invalid external movement multipliers cannot poison movement state")

    game.queue_free()
    await process_frame
    if _failures == 0:
        print("PLAYER STATUS SLOW PLAYTEST TEST PASS")
    else:
        push_error("PLAYER STATUS SLOW PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
