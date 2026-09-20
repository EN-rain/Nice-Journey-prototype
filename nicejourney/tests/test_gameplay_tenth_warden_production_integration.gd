extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TOWER_VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")

var _failures := 0
var _live_results: Array[Dictionary] = []


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Production Warden", "melee")
    var floor := _floor_state(10, 104404)
    _expect(profile != null and floor != null and TowerFloorStateService.commit_floor_state(profile, floor), "fixture commits a valid Floor 10")
    if profile == null or floor == null:
        quit(1)
        return
    profile.quest_progress[String(Floor10PrimaryBossObjectiveService.QUEST_ID)] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:test_tenth_warden_production",
        "objective_state": {},
    }

    var authoring := _complete_authoring_fixture()
    _expect(authoring.validate_authoring().is_empty(), "fully authored test boss includes explicit live hit timing and placement")

    var build := TowerFloorRuntimeComposer.build(floor.layout_manifest, TOWER_VISUAL_CATALOG)
    var arrival := TowerArrivalResolver.resolve_entrance(floor)
    _expect(bool(build.get("accepted", false)) and bool(arrival.get("accepted", false)), "fixture builds the legitimate Floor 10 runtime")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.tenth_warden_production_authoring = authoring
    gameplay.player_defender_facts_tuning = _defender_facts_tuning_fixture()
    gameplay.set_profile(profile)
    get_root().add_child(gameplay)
    await process_frame
    _expect(
        gameplay.activate_committed_tower_travel({
            "accepted": true,
            "runtime_root": build.get("root"),
            "arrival": arrival,
        }),
        "fixture activates Floor 10 through the normal travel path"
    )

    var boss_room_id := StringName(String((floor.layout_manifest.get("objective_bindings", {}) as Dictionary).get(String(Floor10PrimaryBossObjectiveService.QUEST_ID), &"")))
    var boss_trigger := _boss_trigger(gameplay, boss_room_id)
    _expect(boss_trigger != null, "legitimate Floor 10 boss room exposes its encounter trigger")
    if boss_trigger == null:
        gameplay.queue_free()
        await process_frame
        quit(1)
        return

    boss_trigger.player_entered.emit(boss_room_id)
    var activation := gameplay.last_tower_encounter_trigger_result
    _expect(bool(activation.get("accepted", false)), "fully authored fixture activates the production Sanctum path")
    _expect(bool(activation.get("runtime_driver_ready", false)), "GameplayRoot reports authoritative live-contact ownership ready")
    _expect(bool(activation.get("progression_bound", false)), "GameplayRoot binds the existing Floor 10 progression bridge")
    _expect(not bool(activation.get("boss_music_available", true)), "boss remains functionally valid when no production music routing is assigned")
    _expect(gameplay.tower_encounter_session_host.get_active_encounter_count() == 0, "boss path does not create a second generic encounter owner")
    _expect(gameplay.shared_full_ai.get_admitted_count() == 1 and gameplay.shared_active_combat.is_active(), "Sanctum reuses shared FULL-AI and Active Combat ownership")

    var sanctum := gameplay.tower_floor_session_host.active_runtime_root.get_node_or_null("TenthWardenProductionSanctum") as TenthWardenSanctum
    _expect(sanctum != null and sanctum.live_contact_delivery != null, "live Sanctum owns the boss contact-delivery driver")
    if sanctum == null or sanctum.live_contact_delivery == null:
        gameplay.queue_free()
        await process_frame
        quit(1)
        return

    sanctum.set_physics_process(false)
    sanctum.live_contact_delivery.contact_resolved.connect(_on_live_contact_resolved)
    gameplay.player.global_position = sanctum.boss_visual.global_position
    gameplay.player.velocity = Vector2.ZERO
    await physics_frame
    await process_frame

    for _tick: int in range(3):
        _advance_live_boss_tick(sanctum)
    var twin_delivery_snapshot := sanctum.live_contact_delivery.get_debug_snapshot()
    _expect(_live_results.size() == 2, "Twin Cut live geometry emits exactly two authored hit identities")
    _expect(
        bool(twin_delivery_snapshot.get("last_target_shape_checked", false))
        and bool(twin_delivery_snapshot.get("last_target_shape_overlap", false)),
        "Twin Cut contact is confirmed by exact authored attack-shape versus player collision-shape overlap"
    )
    if _live_results.size() >= 2:
        _expect(
            int(_live_results[0].get("hit_interval_index", -1)) == 0
            and int(_live_results[1].get("hit_interval_index", -1)) == 1,
            "Twin Cut uses explicit hit indices 0 and 1"
        )
        _expect(
            int(_live_results[0].get("action_instance_id", 0)) == int(_live_results[1].get("action_instance_id", -1)),
            "Twin Cut contacts share one committed action-instance identity"
        )
    var result_count_before_repeat := _live_results.size()
    sanctum.live_contact_delivery.advance_fixed_tick()
    _expect(_live_results.size() == result_count_before_repeat, "re-evaluating the same active tick cannot duplicate an already-attempted hit identity")

    _advance_live_boss_tick(sanctum)
    _expect(
        StringName(sanctum.live_contact_delivery.get_debug_snapshot().get("active_action_id", &"")) == &"",
        "live delivery ownership clears when the active window leaves contact delivery"
    )

    var saw_arc_volley := false
    for _tick: int in range(16):
        _advance_live_boss_tick(sanctum)
        if sanctum.autonomous_runtime != null and sanctum.autonomous_runtime.action_machine.get_current_action_id() == TenthWardenEncounterState.MOVE_ARC_VOLLEY:
            saw_arc_volley = true
        if saw_arc_volley and StringName(sanctum.live_contact_delivery.get_debug_snapshot().get("active_action_id", &"")) == &"":
            break
    _expect(saw_arc_volley, "autonomous production cadence reaches authored Arc Volley")
    _expect(
        StringName(sanctum.live_contact_delivery.get_debug_snapshot().get("active_action_id", &"")) == &"",
        "Arc Volley live-delivery ownership cleans up deterministically without a persistent projectile object"
    )

    var boss := sanctum.encounter_runtime.get_combatant(Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID)
    var fatal := sanctum.boss_runtime.resolve_player_contact(99001, 0, _fatal_player_attack())
    _expect(bool(fatal.get("accepted", false)) and boss != null and boss.is_defeated(), "boss defeat still resolves only through shared combat")
    _expect(sanctum.commit_terminal_outcome(), "controlled fixture commits the authoritative terminal outcome")
    await process_frame

    var entry := profile.quest_progress.get(String(Floor10PrimaryBossObjectiveService.QUEST_ID), {}) as Dictionary
    _expect(StringName(String(entry.get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "live boss victory routes through the existing Floor 10 objective bridge")
    _expect(not bool((profile.tower_floor_states["10"] as Dictionary).get("primary_cleared", false)), "boss victory does not bypass the Floor 10 exit and Quest Hall turn-in")
    _expect(not profile.permanent_flags.has("tower_floor_11_unlocked"), "live boss integration does not invent Floor 11")
    _expect(not gameplay.shared_active_combat.is_active() and gameplay.shared_full_ai.get_admitted_count() == 0, "terminal outcome releases shared combat and FULL-AI ownership")

    gameplay.queue_free()
    await process_frame

    if _failures == 0:
        print("GAMEPLAY TENTH WARDEN PRODUCTION INTEGRATION TEST PASS")
    else:
        push_error("GAMEPLAY TENTH WARDEN PRODUCTION INTEGRATION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _complete_authoring_fixture() -> TenthWardenProductionAuthoring:
    var result := TenthWardenProductionAuthoring.new()
    result.authored = true
    result.max_hp = 60
    result.stamina = 20.0
    result.physical_defense = 0.0
    result.arcane_defense = 0.0
    result.poise_threshold = 10.0
    result.interruptible_declared = true
    result.interruptible = true
    result.block_supported_declared = true
    result.block_supported = false
    result.parry_supported_declared = true
    result.parry_supported = false

    for move_id: StringName in TenthWardenEncounterState.MOVE_IDS:
        result.move_actions.append(_action(move_id, 1, 1, 1, 2))
        result.phase_two_move_actions.append(_action(move_id, 1, 1, 1, 1))

        var geometry := EnemyAttackGeometryAuthoring.new()
        geometry.authored = true
        geometry.geometry_id = StringName("geometry:test_live_tenth_warden:%s" % String(move_id))
        var shape := RectangleShape2D.new()
        shape.size = Vector2(96.0, 96.0)
        geometry.query_shape = shape
        geometry.max_reach_px = 128.0
        geometry.collision_mask = 1
        geometry.hit_interval_count = 2 if move_id == TenthWardenEncounterState.MOVE_TWIN_CUT else 1
        geometry.live_placement_declared = true
        geometry.local_offset = Vector2.ZERO
        geometry.local_rotation_radians = 0.0
        geometry.hit_active_ticks = PackedInt32Array([0, 0]) if move_id == TenthWardenEncounterState.MOVE_TWIN_CUT else PackedInt32Array([0])

        var payload := EnemyAttackPayloadAuthoring.new()
        payload.authored = true
        payload.damage_domain = DirectHitResolver.DOMAIN_PHYSICAL
        payload.delivery = DirectHitResolver.DELIVERY_PROJECTILE if move_id == TenthWardenEncounterState.MOVE_ARC_VOLLEY else DirectHitResolver.DELIVERY_CONTACT
        payload.raw_damage = 1.0
        payload.guard_pressure = 0.0
        payload.dodgeable = true
        payload.blockable = move_id != TenthWardenEncounterState.MOVE_CRESCENT_SWEEP
        payload.parryable = move_id != TenthWardenEncounterState.MOVE_ARC_VOLLEY
        payload.critical_multiplier = 1.0
        payload.weak_point_multiplier = 1.0

        var attack := EnemySignatureAttackAuthoring.new()
        attack.action_id = move_id
        attack.geometry = geometry
        attack.payload = payload
        result.move_attacks.append(attack)

    result.phase_transition_action = _action(TenthWardenEncounterState.ACTION_PHASE_TRANSITION, 1, 1, 1, 1)
    result.phase_one_move_order = [
        TenthWardenEncounterState.MOVE_TWIN_CUT,
        TenthWardenEncounterState.MOVE_ARC_VOLLEY,
        TenthWardenEncounterState.MOVE_WARDEN_LUNGE,
        TenthWardenEncounterState.MOVE_CRESCENT_SWEEP,
        TenthWardenEncounterState.MOVE_PUNISHING_STEP,
    ]
    result.phase_two_move_order = TenthWardenEncounterState.MOVE_IDS.duplicate()
    result.phase_two_heavy_move_ids = [TenthWardenEncounterState.MOVE_WARDEN_LUNGE]
    return result


func _action(action_id: StringName, startup: int, commit: int, active: int, recovery: int) -> ActionDefinition:
    var result := ActionDefinition.new()
    result.action_id = action_id
    result.startup_ticks = startup
    result.commit_ticks = commit
    result.active_ticks = active
    result.recovery_ticks = recovery
    result.cooldown_ticks = 0
    return result


func _floor_state(floor_id: int, seed: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        seed,
        &"tower_generator:v01",
        &"tower_modules:v01",
        &"encounters:v01",
        &"quest_flags:tenth_warden_production_test"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return null
    return TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:tenth_warden_production_%d_%d" % [floor_id, seed]),
        manifest
    )


func _boss_trigger(gameplay: GameplayRoot, room_id: StringName) -> TowerEncounterRoomTrigger:
    var rooms_root := gameplay.tower_floor_session_host.active_runtime_root.get_node_or_null("Rooms")
    if rooms_root == null:
        return null
    for room_node: Node in rooms_root.get_children():
        if StringName(String(room_node.get_meta(&"room_instance_id", &""))) == room_id:
            return room_node.get_node_or_null("EncounterTrigger") as TowerEncounterRoomTrigger
    return null


func _defender_facts_tuning_fixture() -> PlayerDefenderFactsTuning:
    var result := PlayerDefenderFactsTuning.new()
    result.authored = true
    result.dodge_invulnerability_start_seconds = 0.0
    result.dodge_invulnerability_duration_seconds = 0.06
    result.frontal_coverage_degrees = 120.0
    return result


func _fatal_player_attack() -> Dictionary:
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


func _on_live_contact_resolved(result: Dictionary) -> void:
    _live_results.append(result.duplicate(true))


func _advance_live_boss_tick(sanctum: TenthWardenSanctum) -> void:
    sanctum.autonomous_runtime.advance_fixed_tick(sanctum.punishing_step_positioning_condition_met)
    sanctum.live_contact_delivery.advance_fixed_tick()


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
