extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_ROOT := "user://test_gameplay_death_retry_restore"

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var service := SaveService.new(SAVE_ROOT)
    service.delete_slot(1)
    await _test_live_retry(service)
    service.delete_slot(1)
    await _test_death_overlay_retry_flow(service)
    service.delete_slot(1)
    if _failures == 0:
        print("GAMEPLAY DEATH RETRY RESTORE TEST PASS")
    else:
        push_error("GAMEPLAY DEATH RETRY RESTORE TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_live_retry(service: SaveService) -> void:
    var profile := ProfileCreationService.create_profile(1, "Live Retry", "mage")
    _expect(profile != null, "live-retry profile creates")
    if profile == null:
        return
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    _expect(service.save_profile(1, profile) == OK, "live-retry source profile persists")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(service, 1), "live-retry gameplay accepts save context")
    get_root().add_child(gameplay)
    await process_frame

    _expect(gameplay.player.health.restore_safe_state({"current": 68}), "retry fixture establishes checkpoint HP state")
    _expect(gameplay.player.stamina.restore_safe_state({"current": 52.0, "regeneration_block_time": 0.5}), "retry fixture establishes checkpoint stamina state")
    var checkpoint_combat := gameplay.combat_runtime.capture_safe_state()
    checkpoint_combat["mana"] = 44.0
    checkpoint_combat["mana_regeneration_delay_ticks"] = 33
    checkpoint_combat["action_cooldowns"] = {"skill:retry_roundtrip": 46}
    _expect(gameplay.combat_runtime.restore_safe_state(checkpoint_combat), "retry fixture establishes checkpoint mana/cooldown state")

    var travel := gameplay.request_tower_travel(1, false)
    _expect(bool(travel.get("accepted", false)), "live-retry fixture commits a durable Floor 1 safe snapshot")
    _expect(gameplay.is_tower_floor_active(), "live-retry fixture enters the tower floor")

    profile.skill_points = 99
    profile.permanent_flags["post_checkpoint_attempt"] = true
    var attempt_floor := FloorInstanceState.new()
    _expect(attempt_floor.load_dictionary(profile.tower_floor_states["1"] as Dictionary).is_empty(), "live-retry fixture reads current unsaved floor attempt")
    _expect(attempt_floor.mark_actor_defeated(&"enemy:post_checkpoint_attempt"), "live-retry fixture records an unsaved post-checkpoint defeat")
    _expect(TowerFloorStateService.commit_floor_state(profile, attempt_floor), "unsaved post-checkpoint floor mutation reaches the live profile")
    _expect(gameplay.player.health.restore_safe_state({"current": 1}), "attempt mutates live HP after checkpoint")
    _expect(gameplay.player.stamina.restore_safe_state({"current": 3.0, "regeneration_block_time": 0.0}), "attempt mutates live stamina after checkpoint")
    var attempt_combat := gameplay.combat_runtime.capture_safe_state()
    attempt_combat["mana"] = 2.0
    attempt_combat["mana_regeneration_delay_ticks"] = 0
    attempt_combat["action_cooldowns"] = {}
    _expect(gameplay.combat_runtime.restore_safe_state(attempt_combat), "attempt mutates live mana/cooldown state after checkpoint")

    var retry := gameplay.retry_failed_attempt()
    _expect(bool(retry.get("accepted", false)), "GameplayRoot retry restores the latest committed safe generation")
    _expect(retry.get("attempt_outcome", &"") == DeathRetryCoordinator.OUTCOME_RETRY_RESTORED, "live retry reports the approved retry-restored outcome")
    _expect(bool(retry.get("restored_live_gameplay", false)), "retry result confirms the live gameplay state was rebuilt")
    _expect(gameplay.is_tower_floor_active() and gameplay.tower_floor_session_host.active_floor_id == 1, "retry reconstructs the persistent Floor 1 runtime")
    _expect(gameplay.player.health.current_hp == 68, "retry restores checkpoint HP instead of post-attempt value")
    _expect(is_equal_approx(gameplay.player.stamina.current_stamina, 52.0), "retry restores checkpoint stamina instead of post-attempt value")
    _expect(is_equal_approx(gameplay.combat_runtime.get_mana(), 44.0), "retry restores checkpoint Mage mana instead of post-attempt value")
    var restored_combat := gameplay.combat_runtime.capture_safe_state()
    _expect(int(restored_combat.get("mana_regeneration_delay_ticks", -1)) == 33, "retry restores checkpoint mana regeneration delay")
    _expect(int((restored_combat.get("action_cooldowns", {}) as Dictionary).get("skill:retry_roundtrip", -1)) == 46, "retry restores checkpoint cooldown ticks")

    var restored_profile := retry.get("profile") as ProfileSnapshot
    _expect(restored_profile != null and restored_profile.skill_points == 0, "retry discards unsaved post-checkpoint progression")
    _expect(restored_profile != null and not restored_profile.permanent_flags.has("post_checkpoint_attempt"), "retry discards unsaved post-checkpoint flags")
    if restored_profile != null:
        var restored_floor := restored_profile.tower_floor_states.get("1", {}) as Dictionary
        _expect(not (restored_floor.get("defeated_actor_ids", []) as Array).has("enemy:post_checkpoint_attempt"), "retry discards unsaved post-checkpoint enemy outcomes")

    var disk := service.load_profile(1)
    _expect(disk != null and disk.skill_points == 0 and not disk.permanent_flags.has("post_checkpoint_attempt"), "retry keeps the durable safe generation authoritative on disk")

    gameplay.queue_free()
    await process_frame

func _test_death_overlay_retry_flow(service: SaveService) -> void:
    var profile := ProfileCreationService.create_profile(1, "Death Overlay", "melee")
    _expect(profile != null, "death-overlay profile creates")
    if profile == null:
        return
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    _expect(service.save_profile(1, profile) == OK, "death-overlay source profile persists")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(service, 1), "death-overlay gameplay accepts save context")
    get_root().add_child(gameplay)
    await process_frame
    var travel := gameplay.request_tower_travel(1, false)
    _expect(bool(travel.get("accepted", false)), "death-overlay fixture commits a Floor 1 checkpoint")

    var encounter_ids := gameplay.get_current_floor_prototype_encounter_ids()
    _expect(not encounter_ids.is_empty(), "death-overlay fixture exposes an authored encounter")
    if encounter_ids.is_empty():
        gameplay.queue_free()
        await process_frame
        return
    var encounter_id := encounter_ids[0]
    var activation := gameplay.activate_current_floor_prototype_encounter(encounter_id)
    _expect(bool(activation.get("accepted", false)), "death-overlay fixture activates authoritative live combat")
    var encounter := gameplay.tower_encounter_session_host.get_encounter_runtime(encounter_id)
    _expect(encounter != null, "death-overlay fixture owns a live encounter runtime")
    if encounter == null:
        gameplay.queue_free()
        await process_frame
        return
    var debug := encounter.get_debug_snapshot()
    var enemy_id: StringName = &""
    for raw_combatant: Variant in debug.get("combatants", []) as Array:
        if not raw_combatant is Dictionary:
            continue
        var candidate := StringName(String((raw_combatant as Dictionary).get("actor_id", &"")))
        if String(candidate).begins_with("enemy:"):
            enemy_id = candidate
            break
    _expect(enemy_id != &"", "death-overlay fixture resolves a live enemy attacker")
    if enemy_id != &"":
        var fatal := encounter.resolve_direct_contact(
            enemy_id,
            &"player:local",
            990001,
            0,
            _fatal_attack(),
            false,
            DirectHitResolver.DEFENSE_NONE,
            false
        )
        _expect(bool(fatal.get("target_defeated", false)), "authoritative enemy contact enters player death resolution")
    await process_frame

    _expect(gameplay.is_death_retry_open(), "player death immediately opens the checkpoint retry flow")
    _expect(gameplay.input_ownership.current_modal() == GameplayRoot.DEATH_RETRY_MODAL_ID, "death flow owns modal gameplay input")
    _expect(not gameplay.operation_guard.is_allowed(GameplayOperationGuard.OP_SIGIL_TRAVEL), "death flow blocks Sigil travel")
    _expect(not gameplay.operation_guard.is_allowed(GameplayOperationGuard.OP_MANUAL_SAVE), "death flow blocks manual save")
    _expect(not gameplay.operation_guard.is_allowed(GameplayOperationGuard.OP_SERVICE), "death flow blocks services")
    _expect(not gameplay.tower_encounter_session_host.is_physics_processing(), "death flow freezes encounter decision/phase simulation while awaiting retry")

    gameplay.death_retry_overlay.retry_requested.emit()
    await process_frame
    _expect(not gameplay.is_death_retry_open(), "successful retry closes the death overlay")
    _expect(gameplay.input_ownership.current_modal() != GameplayRoot.DEATH_RETRY_MODAL_ID, "successful retry releases death modal ownership")
    _expect(gameplay.tower_encounter_session_host.is_physics_processing(), "successful retry resumes encounter-host fixed simulation")
    _expect(gameplay.player.health.current_hp == gameplay.player.health.get_max_hp(), "successful retry restores checkpoint HP")
    _expect(gameplay.is_tower_floor_active() and gameplay.tower_floor_session_host.active_floor_id == 1, "successful retry reconstructs the checkpointed tower floor")
    _expect(gameplay.operation_guard.is_allowed(GameplayOperationGuard.OP_SIGIL_TRAVEL), "successful retry releases death/combat travel blockers")

    gameplay.queue_free()
    await process_frame

func _fatal_attack() -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": 10000.0,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 0.0,
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
