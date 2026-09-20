extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const VISUAL_SCENE: PackedScene = preload("res://src/enemies/boss_tenth_warden/presentation/tenth_warden_visual.tscn")
const BOSS_PLAYTEST: TenthWardenProductionAuthoring = preload("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_playtest_v01.tres")
const DEFENDER_PLAYTEST: PlayerDefenderFactsTuning = preload("res://src/data/tuning/player_defender_facts_playtest_v01.tres")
const TOWER_VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _expect(BOSS_PLAYTEST != null and BOSS_PLAYTEST.validate_authoring().is_empty(), "shipped, explicitly provisional boss resource validates")
    _expect(DEFENDER_PLAYTEST != null and DEFENDER_PLAYTEST.validate_tuning(load("res://src/data/tuning/movement_default.tres") as MovementTuning).is_empty(), "shipped player defense window fits authored dodge movement")
    _expect(BOSS_PLAYTEST.playtest_placeholder and DEFENDER_PLAYTEST.playtest_placeholder and BOSS_PLAYTEST.resource_name.begins_with("PLAYTEST ") and DEFENDER_PLAYTEST.resource_name.begins_with("PLAYTEST "), "boss and defender values have explicit machine-readable playtest provenance")
    _expect(BOSS_PLAYTEST.max_hp == 320 and BOSS_PLAYTEST.stamina_recovery_per_tick > 0.0, "provisional boss has explicit HP and recoverable spendable stamina")
    _expect(BOSS_PLAYTEST.phase_two_move_order.size() == 6 and BOSS_PLAYTEST.is_phase_two_heavy_move(TenthWardenEncounterState.MOVE_WARDEN_LUNGE), "phase two recombines approved moves with an explicitly exposed heavy recovery")
    for move_id: StringName in TenthWardenEncounterState.MOVE_IDS:
        var phase_one := BOSS_PLAYTEST.action_for_move(move_id, TenthWardenEncounterState.PHASE_ONE)
        var phase_two := BOSS_PLAYTEST.action_for_move(move_id, TenthWardenEncounterState.PHASE_TWO)
        var attack := BOSS_PLAYTEST.attack_for_move(move_id)
        _expect(phase_one != null and phase_two != null and attack != null and attack.geometry != null and attack.payload != null, "%s has both phase timings, contact geometry and combat payload" % String(move_id))
        if phase_one != null and phase_two != null and attack != null:
            _expect(phase_two.recovery_ticks < phase_one.recovery_ticks and phase_one.cost_amount > 0.0, "%s phase-two recovery tightens and costs authored stamina" % String(move_id))
            _expect(attack.geometry.validate_live_delivery(phase_one.active_ticks).is_empty() and attack.geometry.validate_live_delivery(phase_two.active_ticks).is_empty(), "%s active hit intervals remain inside both authored phases" % String(move_id))
    var arc := BOSS_PLAYTEST.attack_for_move(TenthWardenEncounterState.MOVE_ARC_VOLLEY)
    _expect(arc.geometry.hit_interval_count == 3 and arc.payload.dodgeable and arc.payload.blockable and not arc.payload.parryable, "Arc Volley provides three provisional timed ranged contacts without parry")
    var sweep := BOSS_PLAYTEST.attack_for_move(TenthWardenEncounterState.MOVE_CRESCENT_SWEEP)
    _expect(sweep.payload.dodgeable and not sweep.payload.blockable, "Crescent Sweep is dodgeable but unblockable")

    var visual := VISUAL_SCENE.instantiate() as TenthWardenVisualController
    root.add_child(visual)
    await process_frame
    _expect(visual.body != null and not visual.body.visible and visual.playtest_body != null and visual.playtest_body.visible, "playtest boss renders a native ColorRect, not a generated image")
    if visual.playtest_body != null:
        var initial_color := visual.playtest_body.color
        _expect(initial_color == visual.playtest_phase_one_color and visual.playtest_body_path == NodePath("PlaytestBody"), "placeholder body node and Phase 1 tint are Inspector-authored")
        visual.play_semantic(visual.profile.phase_two_animation)
        var phase_two_color := visual.playtest_body.color
        _expect(phase_two_color == visual.playtest_phase_two_color, "Phase 2 tint is Inspector-authored")
        visual.set_weak_point_exposed(true)
        _expect(visual.playtest_body.color == visual.playtest_weak_point_color and visual.playtest_body.color != phase_two_color and phase_two_color != initial_color, "phase transition and exposed weak point use independent Inspector-authored placeholder colors")
        visual.set_weak_point_exposed(false)
        _expect(visual.playtest_body.color == phase_two_color, "weak point closes to the phase-two placeholder color")
    visual.queue_free()
    await process_frame

    var profile := ProfileCreationService.create_profile(1, "Shipped Warden Playtest", "melee")
    var request := TowerFloorGenerationCommitService.build_request(10, 103019, &"tower_generator:v01", &"tower_modules:v01", &"encounters:v01", &"quest_flags:tenth_warden_shipped")
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    var floor := TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:tenth_warden_shipped", manifest)
    _expect(profile != null and floor != null and TowerFloorStateService.commit_floor_state(profile, floor), "real Floor 10 playtest fixture commits authored room state")
    if profile == null or floor == null:
        quit(1)
        return
    profile.quest_progress[String(Floor10PrimaryBossObjectiveService.QUEST_ID)] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:tenth_warden_shipped",
        "objective_state": {},
    }
    var build := TowerFloorRuntimeComposer.build(floor.layout_manifest, TOWER_VISUAL_CATALOG)
    var arrival := TowerArrivalResolver.resolve_entrance(floor)
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame
    var readiness := gameplay.get_floor10_boss_production_status()
    _expect(bool(readiness.get("production_ready", false)) and bool(readiness.get("playtest_placeholder", false)), "live shipped GameplayRoot resolves the boss while identifying provisional tuning in diagnostics")
    _expect(gameplay.activate_committed_tower_travel({"accepted": true, "runtime_root": build.get("root"), "arrival": arrival}), "shipped Floor 10 travel activates")
    if gameplay.is_tower_floor_active():
        var boss_room_id := StringName(String((floor.layout_manifest.get("objective_bindings", {}) as Dictionary).get(String(Floor10PrimaryBossObjectiveService.QUEST_ID), &"")))
        var rooms_root := gameplay.tower_floor_session_host.active_runtime_root.get_node_or_null("Rooms")
        var boss_trigger: TowerEncounterRoomTrigger = null
        for room_node: Node in rooms_root.get_children():
            if StringName(String(room_node.get_meta(&"room_instance_id", &""))) == boss_room_id:
                boss_trigger = room_node.get_node_or_null("EncounterTrigger") as TowerEncounterRoomTrigger
                break
        _expect(boss_trigger != null, "live Floor 10 has the authored boss-room trigger")
        if boss_trigger != null:
            boss_trigger.player_entered.emit(boss_room_id)
            _expect(bool(gameplay.last_tower_encounter_trigger_result.get("accepted", false)), "unmodified shipped scene begins the boss, not just an injected test fixture")
            var sanctum := gameplay.tower_floor_session_host.active_runtime_root.get_node_or_null("TenthWardenProductionSanctum") as TenthWardenSanctum
            _expect(sanctum != null and sanctum.autonomous_runtime != null and sanctum.live_contact_delivery != null, "shipped boss owns autonomous moves and live delivery")
            if sanctum != null and sanctum.autonomous_runtime != null:
                sanctum.set_physics_process(false)
                var boss_state := sanctum.encounter_runtime.get_combatant(Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID)
                boss_state.current_stamina = 0.0
                sanctum.autonomous_runtime.advance_fixed_tick()
                _expect(boss_state.current_stamina > 0.0, "boss cannot permanently stall when its authored stamina cost exhausts the pool")
    gameplay.queue_free()
    await process_frame

    if _failures == 0:
        print("TENTH WARDEN SHIPPED PLAYTEST TEST PASS")
    else:
        push_error("TENTH WARDEN SHIPPED PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
