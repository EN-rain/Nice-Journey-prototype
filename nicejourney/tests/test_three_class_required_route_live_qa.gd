extends SceneTree

# Mechanical route gate, not a human-input combat or visual-fairness playtest.
# Each class uses the shipped GameplayRoot, actual Tower travel/exit scene,
# Quest Hall interaction, JSON save and separately claimed XP. Floors 1-9
# resolve real residents and objectives; Escorts traverse physical waypoints;
# Floor 10 defeats the live boss and emits its actual terminal bridge.
# Attack damage is a controlled fatal fixture, not class DPS/fairness evidence.
const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_ROOT: String = "user://tests/three_class_required_route_live_qa"

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    # Parallel headless gates must never race on this route's slot files.
    var save := SaveService.new("%s/%d" % [SAVE_ROOT, OS.get_process_id()])
    for class_id: String in ["melee", "ranged", "mage"]:
        save.delete_slot(1)
        await _verify_class_route(save, class_id)
    save.delete_slot(1)
    if _failures == 0:
        print("THREE CLASS REQUIRED ROUTE LIVE QA TEST PASS (live objectives, controlled attack damage)")
    else:
        push_error("THREE CLASS REQUIRED ROUTE LIVE QA TEST FAILURES: %d" % _failures)
    quit(_failures)


func _verify_class_route(save: SaveService, class_id: String) -> void:
    var profile := ProfileCreationService.create_profile(1, "Full Route " + class_id, class_id)
    if not _expect(profile != null, "%s: creates valid profile" % class_id):
        return
    if not _expect(save.save_profile(1, profile) == OK, "%s: initial profile is durable" % class_id):
        return

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    if not _expect(gameplay.set_save_context(save, 1), "%s: save context accepted" % class_id):
        gameplay.free()
        return
    root.add_child(gameplay)
    await process_frame
    if not _expect(gameplay.ensure_starting_world() and gameplay.is_region3_active(), "%s: live Region 3 starts" % class_id):
        gameplay.queue_free()
        await process_frame
        return

    var quest_hall := _quest_hall(gameplay)
    if not _expect(quest_hall != null, "%s: authored Quest Hall is present" % class_id):
        gameplay.queue_free()
        await process_frame
        return
    quest_hall.call("_on_body_entered", gameplay.player)
    var preparation := quest_hall.request_service(StringName("interaction:route:%s:prepare" % class_id))
    var prep_result := gameplay.last_region3_quest_hall_preparation_result
    var prepared := _expect(bool(preparation.get("admitted", false))
        and bool(prep_result.get("accepted", false))
        and Region3PreparationCommitService.has_tower_sigil(profile)
        and Region3PreparationCommitService.is_floor_1_unlocked(profile),
        "%s: Quest Hall grants Sigil and Floor 1 from live preparation" % class_id)
    quest_hall.call("_on_body_exited", gameplay.player)
    if not prepared:
        gameplay.queue_free()
        await process_frame
        return

    var expected_xp := 0
    for floor_id: int in range(1, 11):
        var label := "%s Floor %d" % [class_id, floor_id]
        var quest_id := StringName("primary_floor_%d" % floor_id)
        var raw_quest: Variant = profile.quest_progress.get(String(quest_id), null)
        if not _expect(raw_quest is Dictionary
            and StringName(String((raw_quest as Dictionary).get("state", &""))) == QuestProgressState.STATE_ACTIVE,
            "%s: current primary explicitly Active before travel" % label):
            break
        var travel := gameplay.request_tower_travel(floor_id, true)
        if not _expect(bool(travel.get("accepted", false))
            and gameplay.is_tower_floor_active()
            and gameplay.tower_floor_session_host.active_floor_id == floor_id,
            "%s: real floor travel/arrival accepted (%s)" % [label, String(travel.get("reason_id", &""))]):
            break
        var durable_travel := save.load_profile(1)
        if not _expect(durable_travel != null
            and int(durable_travel.safe_state.get("floor_id", 0)) == floor_id,
            "%s: floor-entry checkpoint persists" % label):
            break
        var raw_floor: Variant = profile.tower_floor_states.get(str(floor_id), null)
        var floor := FloorInstanceState.new()
        if not _expect(raw_floor is Dictionary
            and floor.load_dictionary(raw_floor as Dictionary).is_empty()
            and floor.floor_id == floor_id,
            "%s: generated floor state is valid" % label):
            break

        var exit_room_id := StringName(String(floor.layout_manifest.get("exit_room_id", &"")))
        var exit_trigger := _discovery_trigger(gameplay.tower_floor_session_host.active_runtime_root, exit_room_id)
        if not _expect(exit_trigger != null, "%s: physically authored safe exit exists" % label):
            break
        exit_trigger.emit_signal(&"player_entered", exit_room_id)
        if not _expect(not bool(gameplay.last_tower_primary_exit_result.get("accepted", true))
            and gameplay.is_tower_floor_active(),
            "%s: exit cannot bank an unfinished primary" % label):
            break

        # All non-boss primaries use live resident HP/contact/quest bindings.
        # Damage magnitude remains a controlled fatal fixture; no class DPS,
        # player survival or human-input fairness is asserted by this route.
        if floor_id == 1:
            if not await _defeat_live_floor1_primary(gameplay, floor, label):
                break
        elif floor_id == 10:
            if not await _defeat_live_production_residents(gameplay, floor, label):
                break
            if not await _defeat_live_floor10_boss(gameplay, floor, label):
                break
        else:
            var escort: TowerEscortRuntime = null
            if floor_id in [2, 6, 8]:
                escort = gameplay.tower_floor_session_host.get_escort_runtime(quest_id)
                if not _expect(escort != null and escort.actor != null,
                    "%s: physical production Escort actor is active" % label):
                    break
                escort.set_physics_process(false)
            if not await _defeat_live_production_residents(gameplay, floor, label):
                break
            if escort != null and not await _complete_live_escort(gameplay, escort, quest_id, label):
                break
            var primary := profile.quest_progress.get(String(quest_id), {}) as Dictionary
            if not _expect(StringName(String(primary.get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE,
                "%s: live objective reaches ObjectivesComplete without a quest-state fixture" % label):
                break

        exit_trigger.emit_signal(&"player_entered", exit_room_id)
        await process_frame
        var exit_result := gameplay.last_tower_primary_exit_result
        if not _expect(bool(exit_result.get("accepted", false))
            and bool(exit_result.get("durable", false))
            and gameplay.is_region3_active()
            and not gameplay.is_tower_floor_active(),
            "%s: authored exit banks primary state and returns to Region 3 (%s)"
                % [label, String(exit_result.get("reason_id", &""))]):
            break
        quest_hall = _quest_hall(gameplay)
        if not _expect(quest_hall != null, "%s: Quest Hall exists after region return" % label):
            break
        quest_hall.call("_on_body_entered", gameplay.player)
        var turn_request := quest_hall.request_service(
            StringName("interaction:route:%s:floor_%d:turn_in" % [class_id, floor_id]))
        var turn_in := gameplay.last_region3_primary_turn_in_result
        expected_xp += 80 * floor_id
        if floor_id == 10:
            expected_xp += 160
        expected_xp = mini(expected_xp, 4500)
        if not _expect(bool(turn_request.get("admitted", false))
            and bool(turn_in.get("accepted", false))
            and bool((turn_in.get("xp_award", {}) as Dictionary).get("durable", false))
            and (floor_id != 10 or bool((turn_in.get("boss_xp_award", {}) as Dictionary).get("durable", false))),
            "%s: Quest Hall commits actual separate finite rewards (reason=%s, save_error=%d, xp=%d, level=%d)"
                % [label, String(turn_in.get("reason_id", &"")), int(turn_in.get("save_error", -1)), profile.xp, profile.level]):
            break
        if not _expect(profile.xp == expected_xp
            and profile.level <= 10
            and not profile.permanent_flags.has("tower_floor_11_unlocked"),
            "%s: finite cumulative XP, Level 10 cap and no Floor 11" % label):
            break
        var disk := save.load_profile(1)
        if not _expect(disk != null
            and disk.xp == profile.xp
            and disk.level == profile.level
            and int(disk.safe_state.get("floor_id", -1)) == 0,
            "%s: Quest Hall XP/level and Region safe checkpoint survive disk round trip" % label):
            break
        var before_duplicate := profile.to_dictionary()
        var duplicate := gameplay.request_completed_quest_xp(quest_id)
        if not _expect(not bool(duplicate.get("accepted", true))
            and profile.to_dictionary() == before_duplicate,
            "%s: repeated primary XP claim leaves profile unchanged" % label):
            break
        if floor_id < 10:
            var accepted_request := quest_hall.request_service(
                StringName("interaction:route:%s:floor_%d:accept_next" % [class_id, floor_id]))
            var accepted := gameplay.last_region3_primary_accept_result
            var next_primary := profile.quest_progress.get("primary_floor_%d" % (floor_id + 1), {}) as Dictionary
            if not _expect(bool(accepted_request.get("admitted", false))
                and bool(accepted.get("durable", false))
                and StringName(String(next_primary.get("state", &""))) == QuestProgressState.STATE_ACTIVE,
                "%s: next primary explicitly accepted and durable" % label):
                break
        quest_hall.call("_on_body_exited", gameplay.player)

    _expect(profile.level == 10 and profile.xp == 4500 and profile.skill_points == 9
        and bool(profile.permanent_flags.get(Floor10PrimaryBossObjectiveService.FLAG_FLOOR_10_CLEARED, false))
        and not profile.permanent_flags.has("tower_floor_11_unlocked"),
        "%s: all ten floors reach finite Level 10 milestone without farming" % class_id)
    gameplay.queue_free()
    await process_frame


func _defeat_live_floor1_primary(gameplay: GameplayRoot, floor: FloorInstanceState, label: String) -> bool:
    var plan := TowerPrototypeEncounterContentCatalog.build_plan(floor)
    var bindings := floor.layout_manifest.get("objective_bindings", {}) as Dictionary
    var primary_room := StringName(String(bindings.get("primary_floor_1", &"")))
    var encounter_id: StringName = &""
    for candidate: StringName in TowerPrototypeEncounterContentCatalog.encounter_ids(plan):
        for placement: Dictionary in TowerEncounterPlanValidator.placements_for_encounter(plan, candidate):
            if StringName(String(placement.get("room_instance_id", &""))) == primary_room:
                encounter_id = candidate
                break
        if encounter_id != &"":
            break
    var trigger := _encounter_trigger(gameplay.tower_floor_session_host.active_runtime_root, primary_room)
    if not _expect(primary_room != &"" and encounter_id != &"" and trigger != null,
        "%s: generated Floor 1 has real primary encounter/room trigger" % label):
        return false
    trigger.player_entered.emit(primary_room)
    await process_frame
    var activated := gameplay.last_tower_encounter_trigger_result
    var encounter := gameplay.tower_encounter_session_host.get_encounter_runtime(encounter_id)
    if not _expect(bool(activated.get("accepted", false)) and encounter != null,
        "%s: physical primary-room signal activates authoritative combat" % label):
        return false
    var residents := TowerEncounterPlanValidator.placements_for_encounter(plan, encounter_id)
    if not _expect(not residents.is_empty(), "%s: primary encounter owns real enemies" % label):
        return false
    for index: int in range(residents.size()):
        var actor := StringName(String(residents[index].get("actor_id", &"")))
        var enemy := encounter.get_combatant(actor)
        if not _expect(enemy != null, "%s: resident %s has live HP" % [label, String(actor)]):
            return false
        if index == 0 and not await _deliver_class_basic_to_live_actor(gameplay, encounter_id, actor, label):
            return false
        if not enemy.is_defeated():
            var hit := encounter.resolve_direct_contact(
                &"player:local", actor, 880000 + index, 0, _fatal_player_attack(),
                false, DirectHitResolver.DEFENSE_NONE, false)
            if not _expect(bool(hit.get("target_defeated", false)),
                "%s: real resident %s defeated through controlled contact damage" % [label, String(actor)]):
                return false
    await process_frame
    var primary := gameplay._profile.quest_progress.get("primary_floor_1", {}) as Dictionary
    if not _expect(StringName(String(primary.get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE,
        "%s: live defeated resident set completes Floor 1 objective" % label):
        return false
    return _expect(gameplay.end_tower_encounter(encounter_id),
        "%s: authoritative combat releases floor-exit guard" % label)


func _deliver_class_basic_to_live_actor(
    gameplay: GameplayRoot,
    encounter_id: StringName,
    actor_id: StringName,
    label: String
) -> bool:
    var encounter := gameplay.tower_encounter_session_host.get_encounter_runtime(encounter_id)
    var visuals := gameplay.tower_encounter_session_host.get_visuals_by_actor(encounter_id)
    var visual := visuals.get(actor_id) as Node2D
    var combatant := encounter.get_combatant(actor_id) if encounter != null else null
    if not _expect(visual != null and combatant != null,
        "%s: class basic targets an actual living encounter visual/HP owner" % label):
        return false
    return await _deliver_class_basic_to_target(gameplay, visual, combatant, actor_id, label)


func _deliver_class_basic_to_live_boss(
    gameplay: GameplayRoot,
    sanctum: TenthWardenSanctum,
    boss: CombatantRuntimeState,
    label: String
) -> bool:
    if not _expect(sanctum != null and sanctum.boss_visual != null and boss != null,
        "%s: normal basic targets the actual Warden visual/HP owner" % label):
        return false
    return await _deliver_class_basic_to_target(
        gameplay, sanctum.boss_visual, boss, Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID, label)


func _deliver_class_basic_to_target(
    gameplay: GameplayRoot,
    visual: Node2D,
    combatant: CombatantRuntimeState,
    actor_id: StringName,
    label: String
) -> bool:
    # Deterministic player position/aim are controlled input setup. Contact
    # geometry, action clocks, projectile travel, HP and damage remain live.
    var class_id := gameplay.combat_runtime.get_class_id()
    var distance := 32.0 if class_id != &"ranged" else 64.0
    gameplay.player.global_position = visual.global_position - Vector2(distance, 0.0)
    gameplay.player.velocity = Vector2.ZERO
    gameplay.player.apply_aim_direction(Vector2.RIGHT)
    var runtime := gameplay.combat_runtime
    var machine := runtime.action_state_machine
    var basic := runtime.starter_kit.basic_action
    var before := combatant.current_hp
    if not _expect(runtime.request_basic_attack(Vector2.RIGHT),
        "%s: %s starts real basic action with starter weapon" % [label, String(class_id)]):
        return false
    for _tick: int in basic.startup_ticks + basic.commit_ticks:
        machine.advance_fixed_tick()
    if not _expect(machine.get_phase() == ActionStateMachine.Phase.ACTIVE,
        "%s: %s reaches the real basic ACTIVE window" % [label, String(class_id)]):
        return false
    for _tick: int in range(100):
        if combatant.current_hp < before:
            break
        await physics_frame
    var delivered := gameplay.player_playtest_attack_delivery.last_contact_result
    var hp_delivered := (
        combatant.current_hp < before
        and StringName(String(delivered.get("target_id", &""))) == actor_id
        and bool(delivered.get("accepted", false))
    )
    # Let the authored ACTIVE and RECOVERY clocks finish before another safe
    # checkpoint/travel request. An in-flight action must block safe saves.
    for _tick: int in range(300):
        if machine.get_phase() == ActionStateMachine.Phase.IDLE:
            break
        machine.advance_fixed_tick()
    return _expect(hp_delivered and machine.get_phase() == ActionStateMachine.Phase.IDLE,
        "%s: %s basic deals live HP damage and recovers before travel (target_hp=%d/%d, last_contact=%s, phase=%d)" % [
            label, String(class_id), combatant.current_hp, before,
            str(delivered) if not hp_delivered else "accepted", machine.get_phase()])


func _defeat_live_production_residents(gameplay: GameplayRoot, floor: FloorInstanceState, label: String) -> bool:
    var plan := TowerProductionEncounterContentCatalog.build_plan(floor)
    if not _expect(not plan.is_empty(), "%s: production encounter plan exists" % label):
        return false
    var encounter_ids := TowerProductionEncounterContentCatalog.encounter_ids(plan)
    if not _expect(not encounter_ids.is_empty(), "%s: production residents are authored" % label):
        return false
    if floor.floor_id == 10:
        var elite_count := 0
        for placement: Dictionary in plan.get("placements", []) as Array:
            if bool(placement.get("elite", false)):
                elite_count += 1
        if not _expect(elite_count == 3,
            "%s: three separately authored Floor 10 elites are present outside the boss" % label):
            return false
    for encounter_id: StringName in encounter_ids:
        var residents := TowerEncounterPlanValidator.placements_for_encounter(plan, encounter_id)
        if not _expect(not residents.is_empty(), "%s: %s owns placed residents" % [label, String(encounter_id)]):
            return false
        var room_id := StringName(String(residents[0].get("room_instance_id", &"")))
        var trigger := _encounter_trigger(gameplay.tower_floor_session_host.active_runtime_root, room_id)
        if not _expect(trigger != null, "%s: %s has a physical encounter trigger" % [label, String(encounter_id)]):
            return false
        trigger.player_entered.emit(room_id)
        await process_frame
        var activation := gameplay.last_tower_encounter_trigger_result
        var encounter := gameplay.tower_encounter_session_host.get_encounter_runtime(encounter_id)
        if not _expect(bool(activation.get("accepted", false)) and encounter != null,
            "%s: %s activates through the shipped room/encounter owner (%s)" % [
                label, String(encounter_id), String(activation.get("reason_id", &""))]):
            return false
        for index: int in range(residents.size()):
            var actor := StringName(String(residents[index].get("actor_id", &"")))
            var before: CombatantRuntimeState = encounter.get_combatant(actor)
            if not _expect(before != null and not before.is_defeated(),
                "%s: %s is a live non-defeated combatant" % [label, String(actor)]):
                return false
            if index == 0 and not await _deliver_class_basic_to_live_actor(
                gameplay, encounter_id, actor, label):
                return false
            if not before.is_defeated():
                var hit := encounter.resolve_direct_contact(
                    &"player:local", actor, 900000 + index, 0, _fatal_player_attack(),
                    false, DirectHitResolver.DEFENSE_NONE, false)
                if not _expect(bool(hit.get("accepted", false))
                    and bool(hit.get("target_defeated", false)) and before.is_defeated(),
                    "%s: %s HP defeat reaches live combat and quest progress" % [label, String(actor)]):
                    return false
        await process_frame
        if not _expect(gameplay.end_tower_encounter(encounter_id),
            "%s: %s releases Active Combat after resident defeat" % [label, String(encounter_id)]):
            return false
    if floor.floor_id != 10:
        return true
    return _expect(gameplay.tower_encounter_session_host.get_active_encounter_count() == 0,
        "%s: Floor 10 resident and elite encounters release before boss activation" % label)


func _complete_live_escort(
    gameplay: GameplayRoot,
    escort: TowerEscortRuntime,
    quest_id: StringName,
    label: String
) -> bool:
    var initial := escort.get_debug_snapshot()
    if not _expect(bool(initial.get("configured", false)) and not bool(initial.get("terminal", true)),
        "%s: physical Escort driver starts with a live route" % label):
        return false
    var reached := false
    for _step: int in range(900):
        var result := escort.advance_fixed(1.0 / 60.0)
        var entry := gameplay._profile.quest_progress.get(String(quest_id), {}) as Dictionary
        if StringName(String(entry.get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE:
            reached = true
            break
        if not bool(result.get("accepted", false)):
            return _expect(false, "%s: Escort physical route rejected: %s" % [
                label, String(result.get("reason_id", &""))])
        await physics_frame
    var final_state := escort.get_debug_snapshot()
    return _expect(reached and escort.is_terminal()
        and int(final_state.get("current_hp", 0)) > 0,
        "%s: physical Escort completes ordered waypoints/goal alive" % label)


func _defeat_live_floor10_boss(gameplay: GameplayRoot, floor: FloorInstanceState, label: String) -> bool:
    var room_id := StringName(String((floor.layout_manifest.get("objective_bindings", {}) as Dictionary).get(
        String(Floor10PrimaryBossObjectiveService.QUEST_ID), &"")))
    var trigger := _encounter_trigger(gameplay.tower_floor_session_host.active_runtime_root, room_id)
    if not _expect(trigger != null, "%s: actual authored Warden room has an encounter trigger" % label):
        return false
    trigger.player_entered.emit(room_id)
    var activation := gameplay.last_tower_encounter_trigger_result
    var sanctum := gameplay.tower_floor_session_host.active_runtime_root.get_node_or_null(
        "TenthWardenProductionSanctum") as TenthWardenSanctum
    if not _expect(bool(activation.get("accepted", false))
        and bool(activation.get("runtime_driver_ready", false))
        and bool(activation.get("progression_bound", false))
        and sanctum != null and sanctum.boss_runtime != null,
        "%s: shipped two-phase Warden activates with live boss/progression owners" % label):
        return false
    # Freeze autonomous physics during deterministic damage delivery; the
    # controller's action/transition clocks still run below. Test damage is
    # controlled and does not establish a class's ordinary combat DPS.
    sanctum.set_physics_process(false)
    var boss := sanctum.encounter_runtime.get_combatant(Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID)
    if not _expect(boss != null and boss.max_hp > 1, "%s: Warden has live authored HP" % label):
        return false
    if not await _deliver_class_basic_to_live_boss(gameplay, sanctum, boss, label):
        return false
    var first_attack := _fatal_player_attack()
    first_attack["raw_damage"] = float(boss.max_hp) * 0.8
    var first := sanctum.boss_runtime.resolve_player_contact(99001, 0, first_attack)
    var phase_state := sanctum.boss_runtime.state
    if not _expect(bool(first.get("accepted", false)) and not boss.is_defeated()
        and phase_state.transition_pending,
        "%s: combat damage drops Warden below the irreversible 50%% transition" % label):
        return false
    for _tick: int in range(900):
        if phase_state.transition_committed:
            break
        sanctum.autonomous_runtime.advance_fixed_tick(false)
        sanctum.live_contact_delivery.advance_fixed_tick()
    if not _expect(phase_state.phase == TenthWardenEncounterState.PHASE_TWO
        and phase_state.transition_committed,
        "%s: live Warden action clocks commit Phase 2 once" % label):
        return false
    var fatal := sanctum.boss_runtime.resolve_player_contact(99002, 0, _fatal_player_attack())
    if not _expect(bool(fatal.get("accepted", false)) and boss.is_defeated(),
        "%s: Warden actually loses final HP through shared contact resolver" % label):
        return false
    if not _expect(sanctum.commit_terminal_outcome(),
        "%s: actual boss terminal victory emits the live progression bridge" % label):
        return false
    await process_frame
    var entry := gameplay._profile.quest_progress.get(
        String(Floor10PrimaryBossObjectiveService.QUEST_ID), {}) as Dictionary
    return _expect(StringName(String(entry.get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE
        and not gameplay.shared_active_combat.is_active(),
        "%s: real Warden defeat completes primary and releases combat" % label)


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


func _encounter_trigger(runtime_root: Node2D, room_id: StringName) -> TowerEncounterRoomTrigger:
    if runtime_root == null:
        return null
    var rooms := runtime_root.get_node_or_null("Rooms")
    if rooms == null:
        return null
    for room_node: Node in rooms.get_children():
        if StringName(String(room_node.get_meta(&"room_instance_id", &""))) == room_id:
            return room_node.get_node_or_null("EncounterTrigger") as TowerEncounterRoomTrigger
    return null


func _quest_hall(gameplay: GameplayRoot) -> Region3FunctionalServiceInteraction:
    if not gameplay.is_region3_active():
        return null
    return gameplay.region3_town_session_host.active_runtime_root.get_node_or_null(
        "QuestHall/ServiceInteraction") as Region3FunctionalServiceInteraction


func _discovery_trigger(runtime_root: Node2D, room_id: StringName) -> Area2D:
    if runtime_root == null:
        return null
    var rooms := runtime_root.get_node_or_null("Rooms")
    if rooms == null:
        return null
    for room_node: Node in rooms.get_children():
        if StringName(String(room_node.get_meta(&"room_instance_id", &""))) == room_id:
            return room_node.get_node_or_null("DiscoveryTrigger") as Area2D
    return null


func _expect(ok: bool, description: String) -> bool:
    if ok:
        print("PASS: %s" % description)
        return true
    _failures += 1
    push_error("FAIL: %s" % description)
    return false
