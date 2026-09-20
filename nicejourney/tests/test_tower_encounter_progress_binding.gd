extends SceneTree

var _failures := 0
var _progress_events: Array[Dictionary] = []

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_live_annihilation_binding()
    _test_rejected_quest_binding_is_atomic()
    if _failures == 0:
        print("TOWER ENCOUNTER PROGRESS BINDING TEST PASS")
    else:
        push_error("TOWER ENCOUNTER PROGRESS BINDING TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_live_annihilation_binding() -> void:
    _progress_events.clear()
    var profile := ProfileCreationService.create_profile(1, "Encounter Progress", "melee")
    var floor := _floor_state(4, 44044)
    _expect(TowerFloorStateService.commit_floor_state(profile, floor), "Floor 4 encounter progress fixture commits persistent floor identity")
    profile.quest_progress["primary_floor_4"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:floor4_progress",
        "objective_state": {},
    }
    var actor_a := &"enemy:floor4_required_a"
    var actor_b := &"enemy:floor4_required_b"
    _expect(bool(QuestFamilyObjectiveService.bind(profile, &"primary_floor_4", {"required_actor_ids": [actor_a, actor_b]}).get("accepted", false)), "Floor 4 annihilation objective binds its authored required actors")

    var plan := {
        "plan_id": &"encounter_plan:floor4_progress",
        "floor_id": 4,
        "complete_floor_plan": false,
        "placements": [
            _placement(actor_a, &"duelist", Vector2i(2, 2)),
            _placement(actor_b, &"marksman", Vector2i(3, 2)),
        ],
    }
    var player := _combatant(&"player:floor4_progress", 100)
    var states := {
        actor_a: _combatant(actor_a, 10),
        actor_b: _combatant(actor_b, 10),
    }
    var activation := TowerEncounterRuntimeFactory.activate(
        floor, plan, &"encounter:floor4_progress", player, states, ActiveCombatRegistry.new(), FullAiSimulationLedger.new()
    )
    _expect(bool(activation.get("accepted", false)), "Floor 4 authored encounter activates for quest-progress binding")
    var encounter := activation.get("encounter_runtime") as CombatEncounterRuntime
    var binder := TowerEncounterProgressBinder.new()
    var bindings := {
        actor_a: [{"quest_id": &"primary_floor_4"}],
        actor_b: [{"quest_id": &"primary_floor_4"}],
    }
    _expect(encounter != null and binder.bind(profile, floor, encounter, bindings), "live encounter defeat signal binds to persistent floor and quest ownership")
    binder.progress_committed.connect(_on_progress_committed)

    var first := encounter.resolve_direct_contact(player.actor_id, actor_a, 9001, 0, _attack(100.0), false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(first.get("target_defeated", false)), "first required enemy is defeated through authoritative combat contact")
    _expect(floor.defeated_actor_ids.has(actor_a), "combat defeat commits to persistent floor actor state")
    var quest_after_first := profile.quest_progress["primary_floor_4"] as Dictionary
    _expect(StringName(String(quest_after_first["state"])) == QuestProgressState.STATE_ACTIVE, "annihilation quest remains active until every designated actor is defeated")

    var second := encounter.resolve_direct_contact(player.actor_id, actor_b, 9002, 0, _attack(100.0), false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(second.get("target_defeated", false)), "second required enemy is defeated through authoritative combat contact")
    _expect(floor.defeated_actor_ids.has(actor_b), "second combat defeat persists to floor state")
    var quest_after_second := profile.quest_progress["primary_floor_4"] as Dictionary
    _expect(StringName(String(quest_after_second["state"])) == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "live encounter defeat events advance the bound annihilation quest to ObjectivesComplete")
    _expect(_progress_events.size() == 2 and bool(_progress_events[0].get("accepted", false)) and bool(_progress_events[1].get("accepted", false)), "binder emits one successful progress transaction per actual defeat")
    _expect((profile.tower_floor_states["4"] as Dictionary).get("defeated_actor_ids", []).size() == 2, "profile-owned floor persistence contains both defeated actor identities")

    binder.unbind()
    if encounter != null:
        encounter.end_encounter()

func _test_rejected_quest_binding_is_atomic() -> void:
    var profile := ProfileCreationService.create_profile(2, "Encounter Atomic", "ranged")
    var floor := _floor_state(4, 44144)
    _expect(TowerFloorStateService.commit_floor_state(profile, floor), "atomic rejection fixture commits Floor 4")
    profile.quest_progress["primary_floor_4"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:floor4_atomic",
        "objective_state": {},
    }
    _expect(bool(QuestFamilyObjectiveService.bind(profile, &"primary_floor_4", {"required_actor_ids": [&"enemy:required_only"]}).get("accepted", false)), "atomic rejection fixture binds designated target")
    var before_profile := profile.to_dictionary()
    var before_floor := floor.to_dictionary()
    var rejected := TowerEncounterProgressService.record_enemy_defeat(
        profile,
        floor,
        &"enemy:incidental",
        [{"quest_id": &"primary_floor_4"}]
    )
    _expect(not bool(rejected.get("accepted", false)) and rejected.get("reason_id", &"") == TowerEncounterProgressService.REASON_QUEST_EVENT_REJECTED, "incidental enemy cannot be committed as a designated quest defeat")
    _expect(profile.to_dictionary() == before_profile, "rejected quest progress leaves profile state unchanged")
    _expect(floor.to_dictionary() == before_floor, "rejected quest progress leaves persistent floor state unchanged")

func _floor_state(floor_id: int, seed: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id, seed, &"tower_generator:v01", &"tower_modules:v01", &"encounters:v01", &"quest_flags:progress_binding_test"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    var state := TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:progress_binding_%d_%d" % [floor_id, seed]), manifest
    )
    _expect(state != null, "Floor %d progress fixture builds from validated fallback" % floor_id)
    return state

func _placement(actor_id: StringName, archetype_id: StringName, local_tile: Vector2i) -> Dictionary:
    return {
        "actor_id": actor_id,
        "archetype_id": archetype_id,
        "encounter_id": &"encounter:floor4_progress",
        "room_instance_id": &"room:objective_01",
        "local_tile": local_tile,
        "elite": false,
    }

func _combatant(actor_id: StringName, hp: int) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, hp, 100.0, 0.0, 0.0, 10.0, true, false, false), "combatant progress fixture configures: %s" % String(actor_id))
    return state

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

func _on_progress_committed(result: Dictionary) -> void:
    _progress_events.append(result.duplicate(true))

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
