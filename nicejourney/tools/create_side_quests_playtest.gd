extends SceneTree

const OUTPUT := "res://src/data/tuning/region3_side_quests_playtest_v01.tres"
const PROGRESSION: ProgressionPlaytestContent = preload("res://src/data/tuning/progression_playtest_v01.tres")


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var quests := Region3SideQuestsPlaytest.new()
    quests.resource_name = "PLAYTEST Region 3 side quests A/B/C — not live without actor anchors"
    quests.playtest_placeholder = true
    quests.quest_specs = [
        {"slot_id": Region3SideQuestStagingService.SLOT_SIDE_A, "objective_family": Region3SideQuestStagingService.FAMILY_ESCORT, "staging_route_name": Region3SideQuestStagingService.ROUTE_SOUTH_APPROACH, "enemy_counts_by_wave": PackedInt32Array([3]), "xp_reward": 40, "retry_policy_id": &"retry:escort_playtest", "leave_policy_id": &"leave:escort_playtest", "runtime_enabled": false},
        {"slot_id": Region3SideQuestStagingService.SLOT_SIDE_B, "objective_family": Region3SideQuestStagingService.FAMILY_ANNIHILATION, "staging_route_name": Region3SideQuestStagingService.ROUTE_WEST_APPROACH, "enemy_counts_by_wave": PackedInt32Array([5]), "xp_reward": 60, "retry_policy_id": &"retry:annihilation_playtest", "leave_policy_id": &"leave:annihilation_playtest", "runtime_enabled": false},
        {"slot_id": Region3SideQuestStagingService.SLOT_SIDE_C, "objective_family": Region3SideQuestStagingService.FAMILY_DEFENSE, "staging_route_name": Region3SideQuestStagingService.ROUTE_NORTH_APPROACH, "enemy_counts_by_wave": PackedInt32Array([2, 2, 2]), "xp_reward": 80, "retry_policy_id": &"retry:defense_playtest", "leave_policy_id": &"leave:defense_playtest", "runtime_enabled": false},
    ]
    var errors := quests.validate_content(PROGRESSION)
    if not errors.is_empty():
        push_error("side quest playtest plan invalid: %s" % str(errors))
        quit(1)
        return
    var code := ResourceSaver.save(quests, OUTPUT)
    print("SIDE QUEST PLAYTEST PLAN: %d" % code)
    quit(0 if code == OK else 1)
