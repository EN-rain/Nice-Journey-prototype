extends SceneTree

const QUEST_LOG_VIEW_SERVICE_SCRIPT: Script = preload("res://src/ui/quest_log_view_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Quest Log", "melee")
    var empty: Dictionary = QUEST_LOG_VIEW_SERVICE_SCRIPT.build_log(profile)
    _expect(bool(empty.get("accepted", false)) and int(empty.get("entry_count", -1)) == 0, "quest log starts from persisted quest state only and does not expose unaccepted catalog definitions")

    var primary_objective := AnnihilationObjectiveState.new()
    _expect(primary_objective.configure([&"enemy:log_a", &"enemy:log_b"]), "quest log fixture configures a valid primary annihilation objective")
    _expect(bool(primary_objective.record_actor_defeated(&"enemy:log_a").get("accepted", false)), "quest log fixture records authoritative primary progress")
    profile.quest_progress["primary_floor_1"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:quest_log_primary",
        "objective_state": primary_objective.to_dictionary(),
    }

    var escort := EscortObjectiveState.new()
    _expect(escort.configure(
        &"npc:quest_log_escort",
        [&"route:quest_log_a", &"route:quest_log_b"],
        &"goal:quest_log",
        &"retry:quest_log",
        &"policy:quest_log"
    ), "quest log fixture configures a valid side escort objective")
    _expect(bool(escort.record_route_node_reached(&"route:quest_log_a").get("accepted", false)), "quest log fixture records exact escort route progress")
    _expect(bool(escort.record_failure(&"failure:quest_log_blocked").get("accepted", false)), "quest log fixture records an exact escort failure reason")
    profile.quest_progress["side_region3_escort"] = {
        "state": QuestProgressState.STATE_FAILED,
        "stage_id": &"escort_objective",
        "attempt_id": &"attempt:quest_log_side",
        "objective_state": escort.to_dictionary(),
        "leave_reason_id": "leave:quest_log_previous",
    }

    profile.quest_progress["primary_floor_10"] = {
        "state": QuestProgressState.STATE_OBJECTIVES_COMPLETE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:quest_log_boss",
        "objective_state": {
            "boss_actor_id": String(Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID),
            "boss_defeated": true,
        },
    }

    var economy := EconomyState.new()
    _expect(economy.add_pending_reward(
        &"claim:quest_log_waiting",
        &"source:quest_log_closed",
        [{
            "item_instance_id": "item:quest_log_waiting",
            "definition_id": "itemdef:quest_log_waiting",
            "quantity": 2,
            "stackable": true,
        }]
    ), "quest log fixture persists a normal reward that remains pending after source closure")
    profile.economy_state = economy.to_dictionary()

    var log: Dictionary = QUEST_LOG_VIEW_SERVICE_SCRIPT.build_log(profile)
    _expect(bool(log.get("accepted", false)) and int(log.get("entry_count", 0)) == 3, "quest log returns exactly the three persisted quest entries")
    _expect(int(log.get("pending_reward_claim_count", 0)) == 1, "quest log exposes the persistent pending normal-reward queue independently of quest/source lifetime")
    _expect(not bool(log.get("pending_reward_claim_action_available", true)) and bool(log.get("pending_reward_claim_requires_outside_combat", false)), "quest log marks pending reward claim as outside-combat but withholds mutation until a durable action owner exists")
    var pending_claims := log.get("pending_reward_claims", []) as Array
    if pending_claims.size() == 1:
        var pending := pending_claims[0] as Dictionary
        _expect(StringName(pending.get("claim_id", &"")) == &"claim:quest_log_waiting" and StringName(pending.get("source_id", &"")) == &"source:quest_log_closed", "quest log preserves exact pending reward claim/source IDs")
        _expect(int(pending.get("normal_reward_count", 0)) == 1 and int(pending.get("normal_reward_quantity_total", 0)) == 2, "quest log reports exact pending normal reward count and quantity")
        var pending_rewards := pending.get("normal_rewards", []) as Array
        if pending_rewards.size() == 1:
            var pending_reward := pending_rewards[0] as Dictionary
            _expect(StringName(pending_reward.get("definition_id", &"")) == &"itemdef:quest_log_waiting" and StringName(pending_reward.get("item_instance_id", &"")) == &"item:quest_log_waiting" and int(pending_reward.get("quantity", 0)) == 2, "quest log exposes exact pending item definition/instance/quantity without inventing presentation metadata")
        _expect(not bool(pending.get("claim_action_available", true)) and bool(pending.get("requires_outside_combat", false)), "pending reward entry preserves the same fail-closed action boundary")
    var entries := log.get("entries", []) as Array
    _expect(entries.size() == 3, "quest log snapshot contains the exact persisted entry count")
    if entries.size() == 3:
        _expect(StringName((entries[0] as Dictionary).get("quest_id", &"")) == &"primary_floor_1", "quest log deterministically orders primary quests before side quests")
        _expect(StringName((entries[1] as Dictionary).get("quest_id", &"")) == &"primary_floor_10", "quest log orders persisted primary floors deterministically")
        _expect(StringName((entries[2] as Dictionary).get("quest_id", &"")) == &"side_region3_escort", "quest log keeps the persisted side quest after primary entries")

    var primary := _find_entry(entries, &"primary_floor_1")
    _expect(not primary.is_empty(), "quest log exposes the persisted Floor 1 primary identity")
    if not primary.is_empty():
        _expect(StringName(primary.get("progress_kind", &"")) == QUEST_LOG_VIEW_SERVICE_SCRIPT.PROGRESS_ANNIHILATION, "quest log derives annihilation progress from the persisted objective owner")
        _expect(int(primary.get("defeated_count", -1)) == 1 and int(primary.get("required_count", -1)) == 2, "quest log reports exact annihilation progress counts")
        _expect(StringName(primary.get("scope_id", &"")) == &"tower:floor_1" and int(primary.get("floor_id", 0)) == 1, "quest log exposes the authored map scope and floor location")
        _expect(bool(primary.get("acceptance_anchor_available", false)) and StringName(primary.get("acceptance_anchor_id", &"")) == &"r3:functional:02", "quest log exposes Floor 1's explicitly authored Quest Hall acceptance anchor")
        _expect(not bool(primary.get("acceptance_conditions_available", true)), "quest log does not fabricate acceptance-condition ownership")
        _expect(bool(primary.get("turn_in_authoring_available", false)) and bool(primary.get("turn_in_anchor_available", false)) and StringName(primary.get("turn_in_anchor_id", &"")) == &"r3:functional:02", "quest log exposes Floor 1's authoritative Quest Hall turn-in anchor")
        _expect(not bool(primary.get("leave_policy_available", true)) and not bool(primary.get("failure_policy_available", true)) and not bool(primary.get("retry_policy_available", true)), "quest log does not fabricate leave/failure/retry policy ownership")
        _expect(not bool(primary.get("reward_authoring_available", true)) and not bool(primary.get("branch_effect_authoring_available", true)) and not bool(primary.get("completion_authoring_available", true)), "quest log withholds undeclared reward/branch/completion authoring")

    var side := _find_entry(entries, &"side_region3_escort")
    _expect(not side.is_empty(), "quest log exposes the persisted Region 3 escort identity")
    if not side.is_empty():
        _expect(StringName(side.get("progress_kind", &"")) == QUEST_LOG_VIEW_SERVICE_SCRIPT.PROGRESS_ESCORT, "quest log derives escort progress from persisted objective state")
        _expect(int(side.get("next_route_index", -1)) == 1 and int(side.get("route_count", -1)) == 2, "quest log reports exact escort route progress")
        _expect(StringName(side.get("failure_reason_id", &"")) == &"failure:quest_log_blocked", "quest log preserves the exact recorded escort failure reason")
        _expect(StringName(side.get("last_leave_reason_id", &"")) == &"leave:quest_log_previous", "quest log preserves exact historical leave reason without presenting it as a general leave policy")
        _expect(StringName(side.get("scope_id", &"")) == &"region3:south_outskirts", "quest log exposes the authored Region 3 side-quest map scope")
        _expect(not bool(side.get("acceptance_anchor_available", true)) and not side.has("acceptance_anchor_id"), "quest log withholds an undeclared side-quest acceptance anchor")

    var boss := _find_entry(entries, &"primary_floor_10")
    _expect(not boss.is_empty(), "quest log exposes the persisted Floor 10 primary identity")
    if not boss.is_empty():
        _expect(StringName(boss.get("progress_kind", &"")) == QUEST_LOG_VIEW_SERVICE_SCRIPT.PROGRESS_BOSS and bool(boss.get("boss_defeated", false)), "quest log uses the dedicated persisted Tenth Warden completion state")
        _expect(bool(boss.get("completed_outcome_available", false)) and StringName(boss.get("completed_outcome_state", &"")) == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "quest log reports exact completed-objective outcome state")

    _test_declared_contract_metadata()

    var detached: Dictionary = log.duplicate(true)
    ((detached.get("entries", []) as Array)[0] as Dictionary)["quest_id"] = &"quest:mutated"
    (((detached.get("pending_reward_claims", []) as Array)[0] as Dictionary).get("normal_rewards", []) as Array)[0]["quantity"] = 99
    var rebuilt: Dictionary = QUEST_LOG_VIEW_SERVICE_SCRIPT.build_log(profile)
    _expect(StringName(((rebuilt.get("entries", []) as Array)[0] as Dictionary).get("quest_id", &"")) == &"primary_floor_1", "quest log snapshots cannot mutate persisted quest ownership")
    _expect(int(((((rebuilt.get("pending_reward_claims", []) as Array)[0] as Dictionary).get("normal_rewards", []) as Array)[0] as Dictionary).get("quantity", 0)) == 2, "quest log pending reward snapshots are detached from persisted economy ownership")

    var malformed := ProfileCreationService.create_profile(2, "Malformed Quest", "melee")
    malformed.quest_progress["primary_floor_1"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:malformed_quest_log",
        "objective_state": {"required_actor_ids": ["enemy:a"], "defeated_actor_ids": ["enemy:not_required"]},
    }
    var rejected: Dictionary = QUEST_LOG_VIEW_SERVICE_SCRIPT.build_log(malformed)
    _expect(not bool(rejected.get("accepted", true)) and StringName(rejected.get("reason_id", &"")) == QUEST_LOG_VIEW_SERVICE_SCRIPT.REASON_QUEST_STATE_INVALID, "quest log fails closed on malformed persisted objective state")

    var bad_economy_profile := ProfileCreationService.create_profile(3, "Malformed Economy", "mage")
    bad_economy_profile.economy_state = economy.to_dictionary()
    var bad_pending := (bad_economy_profile.economy_state["pending_reward_claims"] as Dictionary)["claim:quest_log_waiting"] as Dictionary
    var bad_rewards := bad_pending["normal_rewards"] as Array
    (bad_rewards[0] as Dictionary)["quantity"] = 2.5
    var economy_rejected: Dictionary = QUEST_LOG_VIEW_SERVICE_SCRIPT.build_log(bad_economy_profile)
    _expect(not bool(economy_rejected.get("accepted", true)) and StringName(economy_rejected.get("reason_id", &"")) == QUEST_LOG_VIEW_SERVICE_SCRIPT.REASON_ECONOMY_STATE_INVALID, "quest log fails closed on malformed persisted pending-reward economy state")

    if _failures == 0:
        print("QUEST LOG VIEW SERVICE TEST PASS")
    else:
        push_error("QUEST LOG VIEW SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _find_entry(entries: Array, quest_id: StringName) -> Dictionary:
    for raw_entry: Variant in entries:
        if raw_entry is Dictionary and StringName(String((raw_entry as Dictionary).get("quest_id", &""))) == quest_id:
            return (raw_entry as Dictionary).duplicate(true)
    return {}


func _test_declared_contract_metadata() -> void:
    var definition := QuestDefinition.new()
    definition.quest_id = &"quest:log_contract_fixture"
    definition.kind = QuestDefinition.KIND_SIDE
    definition.family = QuestDefinition.FAMILY_ANNIHILATION
    definition.scope_id = &"region3:test_scope"
    definition.stage_ids = [&"stage:test"]
    definition.prerequisites_declared = true
    definition.prerequisite_ids = [&"quest:prior_a", &"quest:prior_b"]
    definition.acceptance_anchor_declared = true
    definition.acceptance_anchor_id = &"anchor:accept"
    definition.turn_in_anchor_declared = true
    definition.turn_in_anchor_id = &"anchor:turn_in"
    definition.leave_rule_declared = true
    definition.leave_rule_id = &"leave:fixture"
    definition.failure_rule_declared = true
    definition.failure_rule_id = &"failure:fixture"
    definition.retry_reset_declared = true
    definition.retry_reset_ids = [&"reset:objective", &"reset:actors"]
    definition.rewards_declared = true
    definition.reward_ids = [&"reward:fixture"]
    definition.branch_effects_declared = true
    definition.branch_effect_ids = []
    definition.completion_conditions_declared = true
    definition.completion_condition_ids = [&"completion:fixture"]

    var built: Dictionary = QUEST_LOG_VIEW_SERVICE_SCRIPT._build_entry(definition, {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"stage:test",
        "objective_state": {},
    })
    _expect(bool(built.get("accepted", false)), "quest log metadata fixture builds without requiring objective-state content")
    _expect(bool(built.get("prerequisite_authoring_available", false)) and (built.get("prerequisite_ids", []) as Array).size() == 2, "declared prerequisite IDs are exposed exactly")
    _expect(bool(built.get("acceptance_anchor_available", false)) and StringName(built.get("acceptance_anchor_id", &"")) == &"anchor:accept", "declared acceptance anchor is exposed exactly")
    _expect(bool(built.get("turn_in_authoring_available", false)) and bool(built.get("turn_in_anchor_available", false)) and StringName(built.get("turn_in_anchor_id", &"")) == &"anchor:turn_in", "declared turn-in anchor is exposed exactly")
    _expect(bool(built.get("leave_policy_available", false)) and StringName(built.get("leave_rule_id", &"")) == &"leave:fixture", "declared leave rule is exposed exactly")
    _expect(bool(built.get("failure_policy_available", false)) and StringName(built.get("failure_rule_id", &"")) == &"failure:fixture", "declared failure rule is exposed exactly")
    _expect(bool(built.get("retry_policy_available", false)) and (built.get("retry_reset_ids", []) as Array).size() == 2, "declared retry reset set is exposed exactly")
    _expect(bool(built.get("reward_authoring_available", false)) and (built.get("reward_ids", []) as Array) == [&"reward:fixture"], "declared reward IDs are exposed exactly")
    _expect(bool(built.get("branch_effect_authoring_available", false)) and (built.get("branch_effect_ids", []) as Array).is_empty(), "explicitly declared empty branch effects remain distinguishable from missing authoring")
    _expect(bool(built.get("completion_authoring_available", false)) and (built.get("completion_condition_ids", []) as Array) == [&"completion:fixture"], "declared completion conditions are exposed exactly")

    definition.turn_in_anchor_id = &""
    var automatic: Dictionary = QUEST_LOG_VIEW_SERVICE_SCRIPT._build_entry(definition, {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"stage:test",
        "objective_state": {},
    })
    _expect(bool(automatic.get("turn_in_authoring_available", false)) and not bool(automatic.get("turn_in_anchor_available", true)) and not automatic.has("turn_in_anchor_id"), "explicit empty turn-in declaration exposes automatic-completion authoring without inventing an anchor")

    definition.turn_in_anchor_id = &"anchor:turn_in"
    definition.reward_ids.clear()
    var no_rewards: Dictionary = QUEST_LOG_VIEW_SERVICE_SCRIPT._build_entry(definition, {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"stage:test",
        "objective_state": {},
    })
    _expect(bool(no_rewards.get("reward_authoring_available", false)) and (no_rewards.get("reward_ids", []) as Array).is_empty(), "explicitly authored no-reward policy remains visible in the quest log")

    definition.acceptance_anchor_id = &"invalid anchor"
    var malformed: Dictionary = QUEST_LOG_VIEW_SERVICE_SCRIPT._build_entry(definition, {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"stage:test",
        "objective_state": {},
    })
    _expect(not bool(malformed.get("acceptance_anchor_available", true)) and not malformed.has("acceptance_anchor_id"), "malformed declared values fail closed and are withheld")


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
