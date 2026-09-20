extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_PATH := "user://tests/region3_side_quest_death_retry"
const ANNIHILATION_ID: StringName = &"side_region3_annihilation"
var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save := SaveService.new(SAVE_PATH)
    save.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Regional Death Retry", "melee")
    _expect(save.save_profile(1, profile) == OK, "durable profile exists before death retry")
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    game.set_save_context(save, 1)
    root.add_child(game)
    await process_frame
    if not game.ensure_starting_world():
        _expect(false, "Region 3 loads before death retry")
        await _finish(game, save)
        return
    var accepted := game.request_region3_side_quest(ANNIHILATION_ID)
    _expect(bool(accepted.get("accepted", false)), "regional annihilation attempt saves before combat")
    var runtime := game._region3_side_runtime()
    var encounter_ids := runtime.get_active_encounter_ids()
    _expect(encounter_ids.size() == 1, "annihilation begins with one live combat encounter")
    if encounter_ids.is_empty():
        await _finish(game, save)
        return
    var encounter := runtime.get_encounter_runtime(encounter_ids[0])
    var actor_id := StringName(String(runtime.get_visuals_by_actor(encounter_ids[0]).keys()[0]))
    var fatal_contact := encounter.resolve_direct_contact(
        actor_id, &"player:local", 910000, 0,
        {"domain": DirectHitResolver.DOMAIN_PHYSICAL,
         "delivery": DirectHitResolver.DELIVERY_CONTACT, "raw_damage": 10000.0,
         "dodgeable": true, "blockable": true, "parryable": true,
         "guard_pressure": 0.0, "critical_triggered": false,
         "critical_multiplier": 1.0, "weak_point_triggered": false, "weak_point_multiplier": 1.0},
        false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(fatal_contact.get("accepted", false)) and bool(fatal_contact.get("target_defeated", false)),
        "canonical enemy contact defeats regional player")
    _expect(game.is_death_retry_open(), "regional death enters the existing retry overlay")
    var restored := game.retry_failed_attempt()
    _expect(bool(restored.get("accepted", false)) and bool(restored.get("restored_live_gameplay", false)),
        "retry restores the committed regional quest attempt")
    if bool(restored.get("accepted", false)):
        game._exit_death_retry_flow()
        var rebound := game._region3_side_runtime()
        _expect(rebound != null and rebound.is_quest_attempt_active() and
            rebound.active_quest_id() == ANNIHILATION_ID,
            "checkpoint retry rebinds the same active regional quest")
        _expect(rebound.get_active_encounter_ids().size() == 1,
            "checkpoint retry respawns the annihilation encounter")
        _expect(game.player.health.current_hp > 0,
            "checkpoint retry restores living player health")
        _expect((game.get_node("TopWall") as StaticBody2D).collision_layer == 0,
            "checkpoint retry leaves foundation collision disabled while Region 3 is active")
        _expect(game.player.camera._world_bounds == game.region3_town_session_host.get_world_bounds(),
            "checkpoint retry preserves regional camera bounds")
    await _finish(game, save)


func _finish(game: GameplayRoot, save: SaveService) -> void:
    game.queue_free()
    await process_frame
    save.delete_slot(1)
    if _failures == 0:
        print("REGION3 SIDE QUEST DEATH RETRY TEST PASS")
    else:
        push_error("REGION3 SIDE QUEST DEATH RETRY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, label: String) -> void:
    if ok:
        print("PASS: %s" % label)
    else:
        _failures += 1
        push_error("FAIL: %s" % label)
