extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_annihilation_profile_flow()
    _test_escort_profile_flow()
    _test_defense_profile_flow()
    if _failures == 0:
        print("QUEST FAMILY OBJECTIVE SERVICE TEST PASS")
    else:
        push_error("QUEST FAMILY OBJECTIVE SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_annihilation_profile_flow() -> void:
    var profile := _active_profile(&"primary_floor_4")
    var bind := QuestFamilyObjectiveService.bind(profile, &"primary_floor_4", {"required_actor_ids": [&"enemy:a", &"enemy:b"]})
    _expect(bool(bind["accepted"]), "annihilation objective binds through quest profile owner")
    _expect(not bool(QuestFamilyObjectiveService.apply_event(profile, &"primary_floor_4", QuestFamilyObjectiveService.EVENT_ACTOR_DEFEATED, {"actor_id": &"enemy:optional"})["accepted"]), "annihilation profile owner rejects optional enemy event")
    _expect(bool(QuestFamilyObjectiveService.apply_event(profile, &"primary_floor_4", QuestFamilyObjectiveService.EVENT_ACTOR_DEFEATED, {"actor_id": &"enemy:a"})["accepted"]), "first designated annihilation defeat commits")
    var final := QuestFamilyObjectiveService.apply_event(profile, &"primary_floor_4", QuestFamilyObjectiveService.EVENT_ACTOR_DEFEATED, {"actor_id": &"enemy:b"})
    _expect(bool(final["accepted"]) and bool(final["objectives_complete"]), "annihilation service reports complete at exact designated count")
    _expect(_state(profile, &"primary_floor_4") == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "annihilation quest profile state advances to ObjectivesComplete")

func _test_escort_profile_flow() -> void:
    var profile := _active_profile(&"primary_floor_2")
    var bind := QuestFamilyObjectiveService.bind(profile, &"primary_floor_2", {
        "actor_id": &"npc:floor2_escort",
        "route_node_ids": [&"route:start", &"route:turn", &"route:approach"],
        "goal_id": &"goal:floor2",
        "safe_retry_origin_id": &"retry:floor2",
        "failure_policy_id": &"failure:floor2_authored",
    })
    _expect(bool(bind["accepted"]), "escort objective binds through quest profile owner")
    _expect(not bool(QuestFamilyObjectiveService.apply_event(profile, &"primary_floor_2", QuestFamilyObjectiveService.EVENT_ROUTE_NODE_REACHED, {"route_node_id": &"route:turn"})["accepted"]), "escort service refuses route skipping")
    _expect(bool(QuestFamilyObjectiveService.apply_event(profile, &"primary_floor_2", QuestFamilyObjectiveService.EVENT_WAIT_CHANGED, {"wait_requested": true})["accepted"]), "escort wait state commits explicitly")
    for node_id: StringName in [&"route:start", &"route:turn", &"route:approach"]:
        _expect(bool(QuestFamilyObjectiveService.apply_event(profile, &"primary_floor_2", QuestFamilyObjectiveService.EVENT_ROUTE_NODE_REACHED, {"route_node_id": node_id})["accepted"]), "escort route node %s commits" % String(node_id))
    var goal := QuestFamilyObjectiveService.apply_event(profile, &"primary_floor_2", QuestFamilyObjectiveService.EVENT_GOAL_REACHED, {"goal_id": &"goal:floor2"})
    _expect(bool(goal["objectives_complete"]) and _state(profile, &"primary_floor_2") == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "escort goal advances quest only after full authored route")

    var failed_profile := _active_profile(&"primary_floor_6")
    QuestFamilyObjectiveService.bind(failed_profile, &"primary_floor_6", {
        "actor_id": &"npc:floor6_escort", "route_node_ids": [&"route:a"], "goal_id": &"goal:floor6",
        "safe_retry_origin_id": &"retry:floor6", "failure_policy_id": &"failure:floor6_authored",
    })
    var failed := QuestFamilyObjectiveService.apply_event(failed_profile, &"primary_floor_6", QuestFamilyObjectiveService.EVENT_FAILED, {"reason_id": &"failure:actor_death"})
    _expect(bool(failed["failed"]) and _state(failed_profile, &"primary_floor_6") == QuestProgressState.STATE_FAILED, "explicit escort failure advances quest to Failed without granting completion")

func _test_defense_profile_flow() -> void:
    var profile := _active_profile(&"primary_floor_3")
    var bind := QuestFamilyObjectiveService.bind(profile, &"primary_floor_3", {
        "objective_id": &"objective:floor3_defense",
        "objective_max_hp": 50,
        "required_actor_ids_by_wave": {"wave:1": [&"enemy:w1a", &"enemy:w1b"], "wave:2": [&"enemy:w2a"]},
    })
    _expect(bool(bind["accepted"]), "tower-defense objective binds through quest profile owner")
    var damage := QuestFamilyObjectiveService.apply_event(profile, &"primary_floor_3", QuestFamilyObjectiveService.EVENT_OBJECTIVE_DAMAGE, {"amount": 10})
    _expect(bool(damage["accepted"]) and not bool(damage["failed"]), "non-terminal defense damage commits")
    for pair: Array in [[&"wave:1", &"enemy:w1a"], [&"wave:1", &"enemy:w1b"], [&"wave:2", &"enemy:w2a"]]:
        _expect(bool(QuestFamilyObjectiveService.apply_event(profile, &"primary_floor_3", QuestFamilyObjectiveService.EVENT_ACTOR_DEFEATED, {"wave_id": pair[0], "actor_id": pair[1]})["accepted"]), "required defense actor event commits")
    _expect(_state(profile, &"primary_floor_3") == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "tower-defense profile reaches ObjectivesComplete only after required waves")

    var failed_profile := _active_profile(&"primary_floor_7")
    QuestFamilyObjectiveService.bind(failed_profile, &"primary_floor_7", {"objective_id": &"objective:f7", "objective_max_hp": 5, "required_actor_ids_by_wave": {"wave:1": [&"enemy:x"]}})
    var failed := QuestFamilyObjectiveService.apply_event(failed_profile, &"primary_floor_7", QuestFamilyObjectiveService.EVENT_OBJECTIVE_DAMAGE, {"amount": 5})
    _expect(bool(failed["failed"]) and _state(failed_profile, &"primary_floor_7") == QuestProgressState.STATE_FAILED, "destroyed defense objective advances quest to Failed")

func _active_profile(quest_id: StringName) -> ProfileSnapshot:
    var profile := ProfileCreationService.create_profile(1, "Quest Runtime", "melee")
    profile.quest_progress[String(quest_id)] = {"state": QuestProgressState.STATE_ACTIVE, "stage_id": QuestCatalog.get_definition(quest_id).stage_ids[-1], "attempt_id": StringName("attempt:%s" % String(quest_id)), "objective_state": {}}
    return profile

func _state(profile: ProfileSnapshot, quest_id: StringName) -> StringName:
    return StringName(String((profile.quest_progress[String(quest_id)] as Dictionary).get("state", &"")))

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
