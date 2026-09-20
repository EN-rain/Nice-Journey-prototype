extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_ROOT := "user://test_gameplay_safe_resource_roundtrip"

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var service := SaveService.new(SAVE_ROOT)
    service.delete_slot(1)
    await _test_round_trip(service)
    service.delete_slot(1)
    if _failures == 0:
        print("GAMEPLAY SAFE RESOURCE ROUNDTRIP TEST PASS")
    else:
        push_error("GAMEPLAY SAFE RESOURCE ROUNDTRIP TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_round_trip(service: SaveService) -> void:
    var profile := ProfileCreationService.create_profile(1, "Safe Resource Roundtrip", "mage")
    _expect(profile != null, "safe-resource fixture profile creates")
    if profile == null:
        return
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    _expect(service.save_profile(1, profile) == OK, "safe-resource source profile persists")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(service, 1), "safe-resource gameplay accepts save context")
    get_root().add_child(gameplay)
    await process_frame

    _expect(gameplay.player.health.restore_safe_state({"current": 73}), "fixture establishes partial HP")
    _expect(gameplay.player.stamina.restore_safe_state({
        "current": 41.0,
        "regeneration_block_time": 0.75,
    }), "fixture establishes partial stamina plus regeneration delay")
    var combat_state := gameplay.combat_runtime.capture_safe_state()
    combat_state["mana"] = 37.0
    combat_state["mana_regeneration_delay_ticks"] = 43
    combat_state["action_cooldowns"] = {"skill:roundtrip_cooldown": 57}
    _expect(gameplay.combat_runtime.restore_safe_state(combat_state), "fixture establishes mana delay and an active cooldown")

    var travel := gameplay.request_tower_travel(1, false)
    _expect(bool(travel.get("accepted", false)), "tower checkpoint commits the current resource/cooldown state")
    var loaded := service.load_profile(1)
    _expect(loaded != null, "checkpointed profile reloads from disk")
    if loaded == null:
        gameplay.queue_free()
        await process_frame
        return

    var saved_player := loaded.safe_state.get("player_state", {}) as Dictionary
    var saved_health := saved_player.get("health_state", {}) as Dictionary
    var saved_stamina := saved_player.get("stamina_state", {}) as Dictionary
    var saved_combat := saved_player.get("combat_state", {}) as Dictionary
    _expect(int(saved_health.get("current", -1)) == 73, "disk checkpoint preserves exact HP")
    _expect(is_equal_approx(float(saved_stamina.get("current", -1.0)), 41.0), "disk checkpoint preserves exact stamina amount")
    _expect(is_equal_approx(float(saved_stamina.get("regeneration_block_time", -1.0)), 0.75), "disk checkpoint preserves stamina regeneration delay")
    _expect(is_equal_approx(float(saved_combat.get("mana", -1.0)), 37.0), "disk checkpoint preserves exact Mage mana")
    _expect(int(saved_combat.get("mana_regeneration_delay_ticks", -1)) == 43, "disk checkpoint preserves Mage regeneration delay")
    _expect(int((saved_combat.get("action_cooldowns", {}) as Dictionary).get("skill:roundtrip_cooldown", -1)) == 57, "disk checkpoint preserves action cooldown ticks")

    gameplay.queue_free()
    await process_frame

    var restored := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    restored.set_profile(loaded)
    _expect(restored.set_save_context(service, 1), "fresh gameplay accepts persisted save context")
    get_root().add_child(restored)

    _expect(restored.is_tower_floor_active(), "fresh GameplayRoot restores the persisted tower floor immediately")
    _expect(restored.player.health.current_hp == 73, "fresh GameplayRoot restores HP without a free refill")
    _expect(is_equal_approx(restored.player.stamina.current_stamina, 41.0), "fresh GameplayRoot restores stamina without a free refill")
    var restored_stamina := restored.player.stamina.capture_safe_state()
    _expect(is_equal_approx(float(restored_stamina.get("regeneration_block_time", -1.0)), 0.75), "fresh GameplayRoot restores stamina regeneration suppression")
    _expect(is_equal_approx(restored.combat_runtime.get_mana(), 37.0), "fresh GameplayRoot restores Mage mana without a free refill")
    var restored_combat := restored.combat_runtime.capture_safe_state()
    _expect(int(restored_combat.get("mana_regeneration_delay_ticks", -1)) == 43, "fresh GameplayRoot restores Mage regeneration suppression")
    _expect(int((restored_combat.get("action_cooldowns", {}) as Dictionary).get("skill:roundtrip_cooldown", -1)) == 57, "fresh GameplayRoot restores active action cooldowns")

    restored.queue_free()
    await process_frame

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
