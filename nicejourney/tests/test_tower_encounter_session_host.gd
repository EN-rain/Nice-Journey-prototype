extends SceneTree

const VISUAL_CATALOG: EnemyVisualSceneCatalog = preload("res://src/enemies/presentation/enemy_visual_scene_catalog.tres")
var _failures := 0
var _host_delivery_windows: Array[Dictionary] = []

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    await _test_live_session_progress_and_cleanup()
    await _test_shared_cap_and_resolved_revisit()
    if _failures == 0:
        print("TOWER ENCOUNTER SESSION HOST TEST PASS")
    else:
        push_error("TOWER ENCOUNTER SESSION HOST TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_live_session_progress_and_cleanup() -> void:
    var profile := ProfileCreationService.create_profile(1, "Encounter Host", "melee")
    var floor := _floor_state(4, 44041)
    _expect(profile != null and TowerFloorStateService.commit_floor_state(profile, floor), "session host fixture commits persistent Floor 4 state")
    profile.quest_progress["primary_floor_4"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:floor4_session_host",
        "objective_state": {},
    }
    _expect(bool(QuestFamilyObjectiveService.bind(profile, &"primary_floor_4", {
        "required_actor_ids": [&"enemy:session_duelist", &"enemy:session_marksman"],
    }).get("accepted", false)), "session host fixture binds authored Floor 4 annihilation targets")

    var plan := _plan(4, [
        _placement(&"enemy:session_duelist", &"duelist", &"encounter:session_floor4", Vector2i(2, 2)),
        _placement(&"enemy:session_marksman", &"marksman", &"encounter:session_floor4", Vector2i(3, 2)),
    ])
    var player := _combatant(&"player:session_host", 100)
    var enemies := {
        &"enemy:session_duelist": _combatant(&"enemy:session_duelist", 20),
        &"enemy:session_marksman": _combatant(&"enemy:session_marksman", 20),
    }
    var bindings := {
        &"enemy:session_duelist": [{"quest_id": &"primary_floor_4"}],
        &"enemy:session_marksman": [{"quest_id": &"primary_floor_4"}],
    }
    var host := TowerEncounterSessionHost.new()
    _host_delivery_windows.clear()
    host.enemy_active_delivery_window_opened.connect(_on_host_delivery_window_opened)
    get_root().add_child(host)
    var started := host.activate_encounter(profile, floor, plan, &"encounter:session_floor4", player, enemies, VISUAL_CATALOG, bindings)
    _expect(bool(started.get("accepted", false)) and host.get_active_encounter_count() == 1, "session host activates runtime, presentation and progress ownership together")
    _expect(host.shared_active_combat.is_active() and host.shared_full_ai.get_admitted_count() == 2, "session host owns shared Active Combat and FULL-AI ledgers")
    _expect(host.get_child_count() == 1, "session host parents the live encounter presentation root")
    var blackboard := host.get_blackboard(&"encounter:session_floor4")
    _expect(blackboard != null and blackboard.encounter_id == &"encounter:session_floor4", "session host creates one encounter-scoped blackboard")
    var role_lifecycle := EnemyRootLifecycle.new()
    _expect(role_lifecycle.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:activate"), "blackboard cleanup fixture activates a role lifecycle")
    _expect(blackboard != null and blackboard.try_claim_role(&"role:fixture", &"enemy:session_duelist", role_lifecycle), "live resident can own an encounter coordination role")
    var encounter := host.get_encounter_runtime(&"encounter:session_floor4")
    _expect(encounter != null and encounter.get_active_enemy_count() == 2, "session host exposes authoritative live encounter runtime")
    if encounter != null:
        var status_applied := encounter.apply_status_to_target(player.actor_id, {
            "status_id": &"slow:session_host_fixture",
            "behavior": PrototypeStatusResolver.BEHAVIOR_SLOW,
            "magnitude": 0.25,
            "duration_ticks": 3,
        })
        _expect(bool(status_applied.get("accepted", false)), "session host status-tick fixture applies an authored Slow state")
        await encounter.status_state_changed
        var player_statuses := encounter.get_status_states(player.actor_id)
        _expect(player_statuses.size() == 1 and int((player_statuses[0] as Dictionary).get("remaining_ticks", -1)) == 2, "session host advances encounter status duration exactly once per physics tick")
    var duelist_runtime := host.get_archetype_runtime(&"encounter:session_floor4", &"enemy:session_duelist")
    var duelist_driver := host.get_action_phase_driver(&"encounter:session_floor4", &"enemy:session_duelist")
    var duelist_delivery := host.get_attack_delivery_executor(&"encounter:session_floor4", &"enemy:session_duelist")
    var duelist_movement := host.get_movement_driver(&"encounter:session_floor4", &"enemy:session_duelist")
    _expect(duelist_runtime != null and duelist_driver != null, "host creates authoritative phase-clock ownership for live archetype actions")
    _expect(duelist_delivery != null and duelist_delivery.runtime == duelist_runtime and duelist_delivery.phase_driver == duelist_driver, "host creates one ACTIVE delivery executor bound to the exact runtime and phase owner")
    _expect(duelist_movement != null and duelist_movement.navigation_agent != null, "host creates navigation-backed movement execution for live enemy tactics")
    if duelist_runtime != null and duelist_driver != null:
        var selection := duelist_runtime.choose_tactic(_selector_context(), {})
        _expect(bool(duelist_driver.begin(selection, 40001, {}).get("accepted", false)), "hosted action driver commits through the existing reservation boundary")
        var windup_ticks := int(EnemySignatureActionTimingCatalog.get_timing(&"duelist").get("windup_ticks", 0))
        for _tick: int in range(windup_ticks + 1):
            await physics_frame
        _expect(duelist_runtime.phase_id == EnemyArchetypeRuntime.PHASE_ACTIVE, "session host advances hosted signature windup on fixed physics ticks")
        _expect(_host_delivery_windows.size() == 1, "session host forwards exactly one verified ACTIVE delivery window")
        if not _host_delivery_windows.is_empty():
            var hosted_delivery := _host_delivery_windows[0]
            _expect(StringName(hosted_delivery.get("encounter_id", &"")) == &"encounter:session_floor4", "hosted delivery window stays scoped to its encounter")
            _expect(StringName(hosted_delivery.get("actor_id", &"")) == &"enemy:session_duelist" and int(hosted_delivery.get("action_instance_id", 0)) == 40001, "hosted delivery window preserves actor/action-instance ownership")
            _expect(not hosted_delivery.has("raw_damage") and not hosted_delivery.has("delivery"), "hosted delivery boundary does not invent an unauthored attack payload")

    if encounter != null:
        var first := encounter.resolve_direct_contact(
            player.actor_id, &"enemy:session_duelist", 41001, 0, _attack(100.0), false,
            DirectHitResolver.DEFENSE_NONE, false
        )
        _expect(bool(first.get("accepted", false)) and bool(first.get("target_defeated", false)), "authoritative contact defeats first live encounter resident")
        _expect(floor.defeated_actor_ids.has(&"enemy:session_duelist"), "session progress binder persists first enemy defeat into floor state")
        _expect(blackboard != null and blackboard.get_role_owner(&"role:fixture") == &"", "enemy defeat releases its encounter-blackboard role ownership")
        _expect(StringName(String((profile.quest_progress["primary_floor_4"] as Dictionary).get("state", &""))) == QuestProgressState.STATE_ACTIVE, "annihilation objective stays active after first designated defeat")

        var second := encounter.resolve_direct_contact(
            player.actor_id, &"enemy:session_marksman", 41002, 0, _attack(100.0), false,
            DirectHitResolver.DEFENSE_NONE, false
        )
        _expect(bool(second.get("accepted", false)) and bool(second.get("target_defeated", false)), "authoritative contact defeats second live encounter resident")
        _expect(StringName(String((profile.quest_progress["primary_floor_4"] as Dictionary).get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "second designated defeat advances live Floor 4 objective to ObjectivesComplete")
        _expect(not host.shared_active_combat.is_active() and host.shared_full_ai.get_admitted_count() == 0, "combat runtime releases shared pressure ownership when all enemies are defeated")

    _expect(host.end_encounter(&"encounter:session_floor4"), "session host explicitly closes completed encounter presentation/runtime ownership")
    await process_frame
    _expect(host.get_active_encounter_count() == 0 and host.get_child_count() == 0, "completed encounter session cleans up presentation nodes")
    host.queue_free()
    await process_frame

func _test_shared_cap_and_resolved_revisit() -> void:
    var profile := ProfileCreationService.create_profile(1, "Encounter Overlap", "ranged")
    var floor := _floor_state(2, 22042)
    _expect(profile != null and TowerFloorStateService.commit_floor_state(profile, floor), "overlap fixture commits Floor 2 state")
    var placements: Array = []
    var states: Dictionary = {}
    for index: int in range(6):
        var actor_a := StringName("enemy:host_overlap_a_%02d" % index)
        var actor_b := StringName("enemy:host_overlap_b_%02d" % index)
        placements.append(_placement(actor_a, &"duelist", &"encounter:host_overlap_a", Vector2i(2 + index, 2)))
        placements.append(_placement(actor_b, &"marksman", &"encounter:host_overlap_b", Vector2i(2 + index, 3)))
        states[actor_a] = _combatant(actor_a, 20)
        states[actor_b] = _combatant(actor_b, 20)
    var plan := _plan(2, placements)
    var host := TowerEncounterSessionHost.new()
    get_root().add_child(host)
    var a := host.activate_encounter(profile, floor, plan, &"encounter:host_overlap_a", _combatant(&"player:host_overlap_a", 100), states, VISUAL_CATALOG)
    var b := host.activate_encounter(profile, floor, plan, &"encounter:host_overlap_b", _combatant(&"player:host_overlap_b", 100), states, VISUAL_CATALOG)
    _expect(bool(a.get("accepted", false)) and bool(b.get("accepted", false)), "session host supports two overlapping six-enemy encounter groups")
    _expect(host.shared_full_ai.get_admitted_count() == 12 and host.get_active_encounter_count() == 2, "overlapping sessions consume one shared twelve-actor FULL-AI cap")
    _expect(host.end_encounter(&"encounter:host_overlap_a") and host.shared_full_ai.get_admitted_count() == 6, "ending one hosted encounter releases only its own FULL-AI actors")
    _expect(host.end_encounter(&"encounter:host_overlap_b") and host.shared_full_ai.get_admitted_count() == 0, "ending all hosted encounters releases the shared ledger")
    await process_frame

    var resolved_actor := &"enemy:resolved_revisit"
    var resolved_plan := _plan(2, [_placement(resolved_actor, &"skirmisher", &"encounter:resolved_revisit", Vector2i(2, 2))])
    _expect(floor.mark_actor_defeated(resolved_actor), "resolved revisit fixture records persistent defeat")
    _expect(TowerFloorStateService.commit_floor_state(profile, floor), "resolved revisit fixture persists the defeat")
    var resolved := host.activate_encounter(profile, floor, resolved_plan, &"encounter:resolved_revisit", _combatant(&"player:resolved_revisit", 100), {}, VISUAL_CATALOG)
    _expect(bool(resolved.get("accepted", false)) and bool(resolved.get("resolved", false)), "hosted revisit keeps a fully defeated encounter resolved without runtime creation")
    _expect(host.get_active_encounter_count() == 0 and host.get_child_count() == 0, "resolved revisit creates no phantom session or presentation")
    host.queue_free()
    await process_frame

func _floor_state(floor_id: int, seed: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id, seed, &"tower_generator:v01", &"tower_modules:v01", &"encounters:v01", &"quest_flags:session_host_test"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    var state := TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:session_host_%d_%d" % [floor_id, seed]), manifest
    )
    _expect(state != null, "Floor %d session fixture builds" % floor_id)
    return state

func _plan(floor_id: int, placements: Array) -> Dictionary:
    return {
        "plan_id": StringName("encounter_plan:session_host_%d_%d" % [floor_id, placements.size()]),
        "floor_id": floor_id,
        "complete_floor_plan": false,
        "placements": placements,
    }

func _placement(actor_id: StringName, archetype_id: StringName, encounter_id: StringName, local_tile: Vector2i) -> Dictionary:
    return {
        "actor_id": actor_id,
        "archetype_id": archetype_id,
        "encounter_id": encounter_id,
        "room_instance_id": &"room:objective_00",
        "local_tile": local_tile,
        "elite": false,
    }

func _combatant(actor_id: StringName, hp: int) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, hp, 100.0, 0.0, 0.0, 10.0, true, false, false), "combatant fixture configures: %s" % String(actor_id))
    return state

func _selector_context() -> Dictionary:
    return {
        "target_visible": true,
        "observation_confidence": 1.0,
        "reaction_delay_satisfied": true,
        "distance_band": EnemyArchetypeDefinition.RANGE_CLOSE,
        "reservation_available": true,
        "cooldown_ready": true,
        "objective_contested": false,
        "observed_player_recovering": true,
        "observed_player_committed": false,
        "observation_age_ticks": 0,
    }

func _attack(raw_damage: float) -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": raw_damage,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 0.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }

func _on_host_delivery_window_opened(encounter_id: StringName, context: Dictionary) -> void:
    var detached := context.duplicate(true)
    detached["encounter_id"] = encounter_id
    _host_delivery_windows.append(detached)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
