extends SceneTree

# Real GameplayRoot Floor 1 primary: no fatal payload or forced enemy HP.
# Movement/AI/physics/contact/quests remain live. Script aims and attacks;
# initial player placement is controlled, so NOT human-input fairness.
const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_ROOT: String = "user://tests/three_class_live_combat_playtest"
const REPORT_PATH: String = "res://docs/evidence/combat_floor1_live_playtest_local.json"
const OBSERVE_TICKS: int = 120
const FIGHT_LIMIT_TICKS: int = 900

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var rows: Array[Dictionary] = []
    for class_id: String in ["melee", "ranged", "mage"]:
        var row := await _play_class(class_id)
        if not row.is_empty():
            rows.append(row)
    _expect(rows.size() == 3, "three classes completed one live Floor 1 trial")
    var accepted_world_contacts := 0
    for row: Dictionary in rows:
        accepted_world_contacts += int(row.get("accepted_enemy_world_contacts", 0))
    _expect(accepted_world_contacts > 0, "live enemy world-contact path is exercised by the combined three-class trial")
    var report := {
        "label": "PLAYTEST LIVE Floor 1 physical encounter, scripted aiming/actions, no fatal fixtures",
        "model": "live_floor1_primary_ai_movement_projectiles_basic_and_first_equipped_active_skill",
        "scenario": "verified_clear_out_of_close_range_standoff_then_scripted_32px_combat_and_dynamic_aim",
        "limitations": [
            "Scripted clear stand-off selection, combat-position reset, aiming, first active skill and basic attacks; not a human playtest.",
            "Single fixed generated Floor 1 primary per class; enemy hits can legitimately miss and cannot establish hit probabilities.",
            "Other live residents may attack; playtest stops on death, target defeat, or tick limit.",
            "Only the first equipped rank-one active skill is tested; other skills/ranks/passives, equipment, boss and final difficulty are not tested or approved.",
        ],
        "floor_id": 1,
        "rows": rows,
    }
    if OS.get_cmdline_user_args().has("--write-balance-evidence") and _failures == 0:
        var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
        _expect(file != null, "live playtest evidence file opens")
        if file != null:
            file.store_string(JSON.stringify(report, "\t") + "\n")
            file.close()
            print("LIVE PLAYTEST EVIDENCE: " + ProjectSettings.globalize_path(REPORT_PATH))
    if _failures == 0:
        print("THREE CLASS FLOOR1 LIVE COMBAT PLAYTEST PASS")
    else:
        push_error("THREE CLASS FLOOR1 LIVE COMBAT PLAYTEST FAILURES: %d" % _failures)
    quit(_failures)


func _play_class(class_id: String) -> Dictionary:
    var save := SaveService.new("%s/%d/%s" % [SAVE_ROOT, OS.get_process_id(), class_id])
    save.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Live Balance " + class_id, class_id)
    if not _expect(profile != null and save.save_profile(1, profile) == OK,
            "%s: independent save and class profile" % class_id):
        return {}
    var gameplay := GAMEPLAY.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    if not _expect(gameplay.set_save_context(save, 1), "%s: save context" % class_id):
        gameplay.free()
        return {}
    root.add_child(gameplay)
    await process_frame
    if not _expect(gameplay.ensure_starting_world(), "%s: Region 3 starts" % class_id):
        gameplay.queue_free()
        await process_frame
        return {}
    var hall := gameplay.region3_town_session_host.active_runtime_root.get_node_or_null(
        "QuestHall/ServiceInteraction") as Region3FunctionalServiceInteraction
    if not _expect(hall != null, "%s: real Quest Hall service" % class_id):
        gameplay.queue_free()
        await process_frame
        return {}
    hall.call("_on_body_entered", gameplay.player)
    var prep := hall.request_service(StringName("interaction:playtest:%s:prepare" % class_id))
    hall.call("_on_body_exited", gameplay.player)
    if not _expect(bool(prep.get("admitted", false))
        and bool(gameplay.last_region3_quest_hall_preparation_result.get("accepted", false)),
        "%s: Sigil and Floor 1 preparation" % class_id):
        gameplay.queue_free()
        await process_frame
        return {}
    var travel := gameplay.request_tower_travel(1, true)
    if not _expect(bool(travel.get("accepted", false)) and gameplay.is_tower_floor_active(),
        "%s: actual Floor 1 session" % class_id):
        gameplay.queue_free()
        await process_frame
        return {}
    var raw_floor: Variant = profile.tower_floor_states.get("1", null)
    var floor := FloorInstanceState.new()
    if not _expect(raw_floor is Dictionary
        and floor.load_dictionary(raw_floor as Dictionary).is_empty(),
        "%s: valid authored floor state" % class_id):
        gameplay.queue_free()
        await process_frame
        return {}
    var plan := TowerPrototypeEncounterContentCatalog.build_plan(floor)
    var room_id := StringName(String(
        (floor.layout_manifest.get("objective_bindings", {}) as Dictionary).get("primary_floor_1", &"")))
    var encounter_id: StringName = &""
    for candidate: StringName in TowerPrototypeEncounterContentCatalog.encounter_ids(plan):
        for placement: Dictionary in TowerEncounterPlanValidator.placements_for_encounter(plan, candidate):
            if StringName(String(placement.get("room_instance_id", &""))) == room_id:
                encounter_id = candidate
                break
        if encounter_id != &"":
            break
    var trigger: TowerEncounterRoomTrigger = null
    var rooms := gameplay.tower_floor_session_host.active_runtime_root.get_node_or_null("Rooms")
    if rooms != null:
        for node: Node in rooms.get_children():
            if StringName(String(node.get_meta(&"room_instance_id", &""))) == room_id:
                trigger = node.get_node_or_null("EncounterTrigger") as TowerEncounterRoomTrigger
                break
    if not _expect(trigger != null and encounter_id != &"",
        "%s: real objective encounter trigger" % class_id):
        gameplay.queue_free()
        await process_frame
        return {}
    gameplay.set_balance_capture_enabled(true)
    trigger.player_entered.emit(room_id)
    await process_frame
    var encounter := gameplay.tower_encounter_session_host.get_encounter_runtime(encounter_id)
    var residents := TowerEncounterPlanValidator.placements_for_encounter(plan, encounter_id)
    if not _expect(encounter != null and not residents.is_empty(),
        "%s: actual live enemy HP and AI owner" % class_id):
        gameplay.queue_free()
        await process_frame
        return {}
    var target_id := StringName(String(residents[0].get("actor_id", &"")))
    var target := encounter.get_combatant(target_id)
    var visual := gameplay.tower_encounter_session_host.get_visuals_by_actor(encounter_id).get(target_id) as Node2D
    if not _expect(target != null and visual != null,
        "%s: target has live visual/HP" % class_id):
        gameplay.queue_free()
        await process_frame
        return {}
    var class_runtime := gameplay.combat_runtime
    var machine := class_runtime.action_state_machine
    # Probe unobstructed stand-offs before assigning a movement expectation:
    # Floor 1's west-side 128 px location is behind authored tile collision.
    var standoff := Vector2.INF
    var source := visual.global_position
    var space := gameplay.get_world_2d().direct_space_state
    for offset: Vector2 in [
        Vector2(104, 0), Vector2(-104, 0), Vector2(0, 104), Vector2(0, -104),
        Vector2(112, 0), Vector2(-112, 0), Vector2(0, 112), Vector2(0, -112),
        Vector2(80, 80), Vector2(-80, -80), Vector2(-80, 80), Vector2(80, -80),
    ]:
        var candidate := source + offset
        var ray := PhysicsRayQueryParameters2D.create(source, candidate, 1)
        ray.exclude = [gameplay.player.get_rid()]
        if not space.intersect_ray(ray).is_empty():
            continue
        var point_query := PhysicsPointQueryParameters2D.new()
        point_query.position = candidate
        point_query.collision_mask = 1
        point_query.exclude = [gameplay.player.get_rid()]
        if not space.intersect_point(point_query).is_empty():
            continue
        standoff = candidate
        break
    var clear_standoff := standoff.is_finite()
    gameplay.player.global_position = standoff if clear_standoff else source - Vector2(32.0, 0.0)
    gameplay.player.velocity = Vector2.ZERO
    gameplay.player.apply_aim_direction((source - gameplay.player.global_position).normalized())
    var movement_px := 0.0
    # GDScript lambda scalar captures are copies. Share a mutable Dictionary
    # so the emitted host/delivery events are measured by the owning test.
    var live_events := {"active_windows": 0, "world_contacts": 0}
    var attacks_requested := 0
    var skill_trial := {"requested": false, "accepted": false, "skill_id": String((profile.skill_state["active_slots"] as Array)[0]), "action_id": "", "rank": 0}
    var first_hp := target.current_hp
    var last_enemy_position := visual.global_position
    gameplay.tower_encounter_session_host.enemy_active_delivery_window_opened.connect(
        func(_id: StringName, _ctx: Dictionary) -> void:
            if _id == encounter_id:
                live_events["active_windows"] += 1)
    gameplay.enemy_playtest_live_delivery.playtest_enemy_contact_resolved.connect(
        func(_id: StringName, _actor: StringName, _result: Dictionary) -> void:
            if _id == encounter_id and bool(_result.get("accepted", false)):
                live_events["world_contacts"] += 1)
    for tick: int in range(OBSERVE_TICKS + FIGHT_LIMIT_TICKS):
        if target.is_defeated() or gameplay.player.health.current_hp <= 0:
            break
        if tick == OBSERVE_TICKS:
            # Separate approach measurement from the controlled combat station.
            gameplay.player.global_position = visual.global_position - Vector2(32.0, 0.0)
            gameplay.player.velocity = Vector2.ZERO
            gameplay.player.apply_aim_direction(Vector2.RIGHT)
        if tick >= OBSERVE_TICKS and not machine.is_busy():
            var aim := visual.global_position - gameplay.player.global_position
            if aim.length_squared() > 0.0001:
                gameplay.player.apply_aim_direction(aim.normalized())
            if attacks_requested >= 1 and not bool(skill_trial["requested"]):
                skill_trial["requested"] = true
                var request := gameplay.request_active_skill_slot(0)
                skill_trial["accepted"] = bool(request.get("accepted", false))
                skill_trial["action_id"] = String(request.get("action_id", ""))
                skill_trial["rank"] = int(request.get("rank", 0))
            elif class_runtime.request_basic_attack(gameplay.player.get_aim_direction()):
                attacks_requested += 1
        await physics_frame
        movement_px += last_enemy_position.distance_to(visual.global_position)
        last_enemy_position = visual.global_position
    var report := gameplay.get_balance_capture_report()
    var observed: Dictionary = {}
    for raw: Variant in report.get("rows", []) as Array:
        var row := raw as Dictionary
        if String(row.get("encounter_id", "")) == String(encounter_id):
            observed = row.duplicate(true)
    observed["class_id"] = class_id
    observed["floor_id"] = 1
    observed["target_archetype_id"] = String(residents[0].get("archetype_id", ""))
    observed["target_hp_before"] = first_hp
    observed["target_hp_after"] = target.current_hp
    observed["enemy_movement_px"] = movement_px
    observed["stand_off_distance_px"] = source.distance_to(standoff) if clear_standoff else 32.0
    observed["stand_off_clear"] = clear_standoff
    observed["combat_start_distance_px"] = 32.0
    observed["enemy_active_windows"] = int(live_events["active_windows"])
    observed["accepted_enemy_world_contacts"] = int(live_events["world_contacts"])
    observed["scripted_basics_requested"] = attacks_requested
    observed["skill_trial"] = skill_trial.duplicate(true)
    observed["target_defeated"] = target.is_defeated()
    observed["player_hp_remaining"] = gameplay.player.health.current_hp
    observed["timed_out"] = not target.is_defeated() and gameplay.player.health.current_hp > 0
    observed["target_time_to_defeat_ticks"] = int(observed.get("last_damage_tick", -1)) - int(observed.get("first_action_tick", -1)) if target.is_defeated() else -1
    print("LIVE FLOOR1 %s %s" % [class_id, JSON.stringify(observed)])
    var basic_id := String(class_runtime.starter_kit.basic_action.action_id)
    _expect(not observed.is_empty() and attacks_requested > 0 and
        int((observed.get("successful_contacts_by_action", {}) as Dictionary).get(basic_id, 0)) > 0,
        "%s: normal basics reach real target contact, not only requested actions" % class_id)
    _expect(bool(skill_trial["accepted"]) and int(skill_trial["rank"]) == 1
        and int((observed.get("action_counts", {}) as Dictionary).get(String(skill_trial["action_id"]), 0)) >= 1,
        "%s: first equipped PLAYTEST active skill runs through live action/telemetry" % class_id)
    _expect(int(live_events["active_windows"]) > 0,
        "%s: live enemy AI emits real ACTIVE attack windows" % class_id)
    _expect(clear_standoff and movement_px > 0.0,
        "%s: verified clear stand-off and real Duelist approach both observed" % class_id)
    _expect(target.is_defeated() and gameplay.player.health.current_hp > 0
        and not bool(observed["timed_out"]),
        "%s: physical duel ends with target HP defeat and surviving class" % class_id)
    gameplay.queue_free()
    await process_frame
    save.delete_slot(1)
    return observed


func _expect(ok: bool, label: String) -> bool:
    if not ok:
        _failures += 1
        push_error("FAIL: " + label)
    return ok
