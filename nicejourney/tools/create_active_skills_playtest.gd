extends SceneTree

const OUTPUT := "res://src/data/tuning/active_skills_playtest_v01.tres"


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var catalog := ActiveSkillsPlaytest.new()
    catalog.resource_name = "PLAYTEST nine active skill action clocks with effects and rank scaling"
    catalog.playtest_placeholder = true
    # Explicit temporary balance candidates. These three Inspector fields for
    # each of the nine skills may be tuned independently without code changes.
    for raw_ids: Variant in SkillCatalog.ACTIVE_IDS_BY_CLASS.values():
        for skill_id: StringName in raw_ids as Array:
            catalog.rank_adjustments[String(skill_id)] = {
                "rank_2": {"magnitude_multiplier": 1.1, "cost_multiplier": 0.95, "recovery_ticks_delta": -1},
                "rank_3": {"magnitude_multiplier": 1.2, "cost_multiplier": 0.9, "recovery_ticks_delta": -2},
            }
    var index := 0
    for raw_ids: Variant in SkillCatalog.ACTIVE_IDS_BY_CLASS.values():
        for skill_id: StringName in raw_ids as Array:
            var definition := SkillCatalog.get_definition(skill_id)
            var action := ActionDefinition.new()
            action.action_id = StringName("action:playtest:%s" % String(skill_id))
            action.startup_ticks = 9 + index % 4
            action.commit_ticks = 1
            action.active_ticks = 5 if skill_id != &"aegis_ward" else 12
            action.recovery_ticks = 17 + index % 3
            action.cooldown_ticks = 24
            action.buffer_lifetime_ticks = 8
            action.cost_resource = definition.cost_resource
            action.cost_amount = 12.0 + float(index % 3) * 4.0
            action.uses_aim = skill_id != &"aegis_ward"
            action.aim_lock_point = ActionDefinition.AimLockPoint.COMMIT
            action.allow_aim_tracking_after_lock = false
            catalog.actions.append(action)
            index += 1
    var errors := catalog.validate_content()
    if not errors.is_empty():
        push_error("playtest skill actions invalid: %s" % str(errors))
        quit(1)
        return
    var code := ResourceSaver.save(catalog, OUTPUT)
    print("ACTIVE SKILL PLAYTEST ACTIONS: %d" % code)
    quit(0 if code == OK else 1)
