extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const PROGRESSION: ProgressionPlaytestContent = preload("res://src/data/tuning/progression_playtest_v01.tres")
const QUESTS: Region3SideQuestsPlaytest = preload("res://src/data/tuning/region3_side_quests_playtest_v01.tres")
const SKILLS: ActiveSkillsPlaytest = preload("res://src/data/tuning/active_skills_playtest_v01.tres")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _expect(QUESTS != null and QUESTS.playtest_placeholder and QUESTS.validate_content(PROGRESSION).is_empty(), "reserved Region 3 side quests have provisional wave-count/reward plans")
    _expect(SKILLS != null and SKILLS.playtest_placeholder and SKILLS.validate_content().is_empty(), "all nine approved active skills have provisional ActionDefinitions")
    _expect(QUESTS.quest_specs.size() == 3, "exactly three reserved quest slots are present")
    for spec: Dictionary in QUESTS.quest_specs:
        _expect(bool(spec.get("runtime_enabled", false)), "side quest %s permits activation only after the separate authored marker validation" % String(spec.get("slot_id", &"")))
    _expect(SKILLS.actions.size() == 9, "three classes each retain three active skill identities")
    for raw_action: Variant in SKILLS.actions:
        var action := raw_action as ActionDefinition
        _expect(not action.uses_aim or action.aim_lock_point == ActionDefinition.AimLockPoint.COMMIT, "%s playtest action uses approved commit aim lock" % String(action.action_id))
    _expect(not bool(ActiveSkillProductionAuthority.readiness(&"arc_cleave").get("production_ready", true)), "timing-only skill data does not pretend full attack/projectile/cue production authority exists")

    var gameplay := GAMEPLAY.instantiate() as GameplayRoot
    _expect(gameplay.side_quests_playtest == QUESTS and gameplay.active_skills_playtest == SKILLS, "shipped Gameplay scene assigns both explicit provisional resource bundles")
    gameplay.set_profile(ProfileCreationService.create_profile(1, "Side Quest Skill Test", "melee"))
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.progression_playtest_content == PROGRESSION and gameplay.side_quests_playtest.validate_content(gameplay.progression_playtest_content).is_empty(), "shipped reserved quest plan is consistent with finite per-slot XP sources")
    gameplay.queue_free()
    await process_frame
    if _failures == 0:
        print("SIDE QUESTS AND SKILLS PLAYTEST TEST PASS")
    else:
        push_error("SIDE QUESTS AND SKILLS PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, name: String) -> void:
    if ok:
        print("PASS: %s" % name)
        return
    _failures += 1
    push_error("FAIL: %s" % name)
