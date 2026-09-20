extends SceneTree

const VIEW_SCRIPT: Script = preload("res://src/ui/skill_hud_view_service.gd")
const ICON_CATALOG: Resource = preload("res://src/ui/presentation/ui_icon_catalog.tres")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_locked_class_loadouts()
    _test_authored_action_availability()
    _test_temporary_override()
    _test_invalid_state_rejected()

    if _failures == 0:
        print("SKILL HUD VIEW SERVICE TEST PASS")
    else:
        push_error("SKILL HUD VIEW SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_locked_class_loadouts() -> void:
    for class_id: String in ["melee", "ranged", "mage"]:
        var profile := ProfileCreationService.create_profile(1, "Skill HUD", class_id)
        var result: Dictionary = VIEW_SCRIPT.build_active_slots(profile)
        _expect(bool(result.get("accepted", false)), "%s active-skill HUD view accepts initialized profile state" % class_id)
        _expect(StringName(result.get("class_id", &"")) == StringName(class_id), "%s HUD view preserves exact class identity" % class_id)
        var slots := result.get("active_slots", []) as Array
        _expect(slots.size() == SkillLoadoutState.ACTIVE_SLOT_COUNT, "%s HUD view exposes exactly two active slots" % class_id)
        var expected: Array = SkillCatalog.STARTING_ACTIVE_IDS_BY_CLASS[StringName(class_id)]
        for index: int in range(mini(slots.size(), expected.size())):
            var slot := slots[index] as Dictionary
            var skill_id := StringName(slot.get("skill_id", &""))
            var definition := SkillCatalog.get_definition(skill_id)
            _expect(skill_id == expected[index], "%s active slot %d preserves equipped skill identity" % [class_id, index])
            _expect(definition != null and String(slot.get("display_name", "")) == definition.display_name, "%s active slot %d uses the authored skill display name" % [class_id, index])
            _expect(int(slot.get("rank", 0)) == 1, "%s starting active slot %d reports persistent rank 1" % [class_id, index])
            _expect(not bool(slot.get("runtime_action_available", true)), "%s active slot %d does not pretend the unhooked skill action is executable" % [class_id, index])
            _expect(not bool(slot.get("production_ready", true)) and not (slot.get("production_missing_fields", PackedStringArray()) as PackedStringArray).is_empty(), "%s active slot %d exposes unresolved production authority instead of claiming readiness" % [class_id, index])
            _expect(not bool(slot.get("cooldown_state_available", true)), "%s active slot %d with no runtime action owner exposes no fabricated cooldown" % [class_id, index])
            var icon_id := StringName(slot.get("icon_id", &""))
            _expect(icon_id == StringName("skill_%s" % String(skill_id)) and ICON_CATALOG.call("get_profile", icon_id) != null, "%s active slot %d resolves its existing inspector-owned icon" % [class_id, index])

        var mutable := result.duplicate(true)
        var mutable_slots := mutable.get("active_slots", []) as Array
        if not mutable_slots.is_empty():
            (mutable_slots[0] as Dictionary)["rank"] = 99
        var repeat: Dictionary = VIEW_SCRIPT.build_active_slots(profile)
        _expect(int(((repeat.get("active_slots", []) as Array)[0] as Dictionary).get("rank", 0)) == 1, "%s HUD result mutation cannot alter persistent loadout state" % class_id)


func _test_authored_action_availability() -> void:
    var profile := ProfileCreationService.create_profile(1, "Skill HUD Runtime", "mage")
    var action := ActionDefinition.new()
    action.action_id = &"skill_action:arcane_lance"
    action.startup_ticks = 2
    action.commit_ticks = 1
    action.active_ticks = 1
    action.recovery_ticks = 2
    action.cooldown_ticks = 12
    action.cost_resource = &"mana"
    action.cost_amount = 5.0
    action.uses_aim = true
    var machine := ActionStateMachine.new()
    var pool := ResourcePool.new()
    _expect(pool.define_resource(&"mana", 100.0), "HUD cooldown fixture owns sufficient mana")
    machine.set_resource_pool(pool)
    _expect(machine.request_action(action, Vector2.RIGHT), "HUD cooldown fixture starts the caller-authored action")
    machine.advance_fixed_tick()
    machine.advance_fixed_tick()
    var result: Dictionary = VIEW_SCRIPT.build_active_slots(profile, {
        &"focused_arcane_projectile": action,
    }, {}, machine)
    var first := (result.get("active_slots", []) as Array)[0] as Dictionary
    var second := (result.get("active_slots", []) as Array)[1] as Dictionary
    _expect(bool(first.get("runtime_action_available", false)) and StringName(first.get("action_id", &"")) == &"skill_action:arcane_lance", "HUD marks generic runtime action availability only when an ActionDefinition is supplied for its mechanic ID")
    _expect(not bool(first.get("production_ready", true)) and not bool(first.get("production_runtime_action_available", true)), "HUD distinguishes a generic action fixture from a production-ready active skill")
    _expect(bool(first.get("cooldown_state_available", false)) and int(first.get("cooldown_ticks", 0)) == 12, "HUD reads the real action-state-machine cooldown for an authored action ID")
    _expect(not bool(second.get("runtime_action_available", true)) and StringName(second.get("runtime_action_reason_id", &"")) == SkillExecutionService.REASON_ACTION_DEFINITION_REQUIRED, "HUD keeps other active skills unavailable when their authored action definitions are absent")
    machine.free()


func _test_temporary_override() -> void:
    var profile := ProfileCreationService.create_profile(1, "Temporary", "mage")
    var state := SkillLoadoutState.new()
    _expect(state.load_dictionary(profile.skill_state).is_empty(), "temporary HUD fixture restores the persisted Mage loadout")
    _expect(state.begin_temporary_active(0, &"temporary:quest_arcane_key"), "temporary HUD fixture applies the existing reversible temporary-slot contract")
    profile.skill_state = state.to_dictionary()
    _expect(SkillLoadoutState.validate_dictionary(profile.skill_state).is_empty(), "temporary HUD fixture remains a valid persistent skill state")

    var result: Dictionary = VIEW_SCRIPT.build_active_slots(profile)
    var slots := result.get("active_slots", []) as Array
    var first := slots[0] as Dictionary
    _expect(bool(result.get("accepted", false)) and bool(first.get("temporary", false)), "HUD view preserves temporary active-slot identity")
    _expect(StringName(first.get("skill_id", &"")) == &"temporary:quest_arcane_key", "HUD view reports the exact temporary skill ID")
    _expect(not bool(first.get("catalog_definition_available", true)) and StringName(first.get("icon_id", &"")) == &"", "unknown temporary quest skill fabricates neither catalog metadata nor an icon")
    _expect(not bool(first.get("runtime_action_available", true)), "temporary loadout view does not invent an executable action")


func _test_invalid_state_rejected() -> void:
    var profile := ProfileCreationService.create_profile(1, "Invalid", "melee")
    profile.skill_state["active_slots"] = ["arc_cleave", "arc_cleave"]
    var result: Dictionary = VIEW_SCRIPT.build_active_slots(profile)
    _expect(not bool(result.get("accepted", true)) and StringName(result.get("reason_id", &"")) == VIEW_SCRIPT.REASON_SKILL_STATE_INVALID, "invalid duplicated active-slot state fails closed")
    _expect((result.get("active_slots", []) as Array).is_empty(), "rejected skill state exposes no misleading HUD slots")


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
