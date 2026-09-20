extends SceneTree

const OUTPUT := "res://src/data/tuning/region3_side_quests_playtest_v01.tres"


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var content := Region3SideQuestsPlaytestContent.new()
    content.resource_name = "PLAYTEST Region 3 side-quest enemy counts/rewards — spatial authoring pending"
    content.playtest_placeholder = true
    content.quest_specs = {
        "R3-SIDE-A": {
            "slot_id": &"R3-SIDE-A",
            "objective_family": Region3SideQuestStagingService.FAMILY_ESCORT,
            "zone_id": Region3SideQuestStagingService.ZONE_OUTSKIRTS,
            "enemy_count": 2,
            "enemy_waves": [{"archetype_id": &"duelist", "count": 2}],
            "xp_source_id": &"quest:region3_side_a",
            "gold_reward": 12,
            "runtime_ready": false,
        },
        "R3-SIDE-B": {
            "slot_id": &"R3-SIDE-B",
            "objective_family": Region3SideQuestStagingService.FAMILY_ANNIHILATION,
            "zone_id": Region3SideQuestStagingService.ZONE_ROADS,
            "enemy_count": 3,
            "enemy_waves": [{"archetype_id": &"bruiser", "count": 1}, {"archetype_id": &"skirmisher", "count": 2}],
            "xp_source_id": &"quest:region3_side_b",
            "gold_reward": 18,
            "runtime_ready": false,
        },
        "R3-SIDE-C": {
            "slot_id": &"R3-SIDE-C",
            "objective_family": Region3SideQuestStagingService.FAMILY_DEFENSE,
            "zone_id": Region3SideQuestStagingService.ZONE_RUINS,
            "enemy_count": 5,
            "enemy_waves": [{"archetype_id": &"duelist", "count": 2}, {"archetype_id": &"marksman", "count": 3}],
            "xp_source_id": &"quest:region3_side_c",
            "gold_reward": 24,
            "runtime_ready": false,
        },
    }
    var errors := content.validate_content()
    if not errors.is_empty():
        push_error("Side-quest provisional authoring invalid: %s" % str(errors))
        quit(1)
        return
    var code := ResourceSaver.save(content, OUTPUT)
    print("SIDE QUEST PLAYTEST CONTENT: %d" % code)
    quit(0 if code == OK else 1)
