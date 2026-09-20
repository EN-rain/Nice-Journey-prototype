extends SceneTree

const SKILL_TREE_VIEW_SERVICE_SCRIPT: Script = preload("res://src/ui/skill_tree_view_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Skill Tree", "melee")
    profile.skill_points = 2
    var view: Dictionary = SKILL_TREE_VIEW_SERVICE_SCRIPT.build_view(profile)
    _expect(bool(view.get("accepted", false)), "skill tree view accepts the initialized persistent class skill state")
    _expect(StringName(view.get("class_id", &"")) == &"melee" and int(view.get("skill_points", -1)) == 2, "skill tree view exposes exact class identity and unspent skill points")
    _expect(int(view.get("entry_count", 0)) == 6 and (view.get("entries", []) as Array).size() == 6, "skill tree view exposes exactly six approved class skills")
    _expect((view.get("active_slots", []) as Array).size() == 2 and (view.get("passive_slots", []) as Array).size() == 2, "skill tree view preserves exact two-active/two-passive loadout ownership")
    _expect(not bool(view.get("safe_swap_state_available", true)) and not bool(view.get("loadout_swap_action_available", true)), "skill tree view does not fabricate safe town/rest swap ownership")
    _expect(not bool(view.get("rank_purchase_action_available", true)) and not bool(view.get("rank_purchase_save_transaction_available", true)), "skill tree view does not expose irreversible rank spending before durable transaction ownership exists")

    var actionable: Dictionary = SKILL_TREE_VIEW_SERVICE_SCRIPT.build_view(profile, {
        "rank_purchase_commit_available": true,
        "loadout_swap_commit_available": true,
        "safe_interaction": true,
        "active_combat": false,
    })
    _expect(bool(actionable.get("rank_purchase_action_available", false)) and bool(actionable.get("rank_purchase_save_transaction_available", false)), "skill tree view exposes irreversible spending only when a durable commit owner is supplied")
    _expect(bool(actionable.get("safe_swap_state_available", false)) and bool(actionable.get("loadout_swap_action_available", false)), "skill tree view exposes loadout swaps only with explicit safe non-combat interaction state")

    var arc := _find_entry(view.get("entries", []) as Array, &"arc_cleave")
    var actionable_arc := _find_entry(actionable.get("entries", []) as Array, &"arc_cleave")
    _expect(not arc.is_empty(), "skill tree view exposes Arc Cleave")
    if not arc.is_empty():
        _expect(bool(arc.get("learned", false)) and bool(arc.get("equipped", false)) and int(arc.get("rank", 0)) == 1, "starting active is persisted as learned rank 1 and equipped")
        _expect(int(arc.get("rank_cost_skill_points", 0)) == 1 and bool(arc.get("rank_purchase_preview_available", false)), "skill tree preview reports the approved one-skill-point next-rank cost")
        _expect(StringName(arc.get("mechanic_id", &"")) == &"wide_committed_melee_sweep" and StringName(arc.get("cost_resource", &"")) == &"stamina", "skill tree preview exposes authored mechanic and action-resource identities")
        _expect(not bool(arc.get("action_cost_amount_available", true)), "skill tree preview does not fabricate unauthored action cost amounts")
        _expect(bool(actionable_arc.get("rank_purchase_available", false)), "durable action context enables a one-point next-rank purchase without changing preview semantics")

    var riposte := _find_entry(view.get("entries", []) as Array, &"riposte")
    _expect(not riposte.is_empty(), "skill tree view exposes locked Riposte alternative")
    if not riposte.is_empty():
        _expect(not bool(riposte.get("learned", true)) and int(riposte.get("rank", -1)) == 0, "alternative active remains honestly locked at rank 0")
        _expect(StringName(riposte.get("prerequisite_event_id", &"")) == &"successful_parry", "Riposte preview preserves the authored successful-parry prerequisite ID")
        _expect(not bool(riposte.get("prerequisite_satisfied_state_available", true)), "skill tree preview does not guess whether the prerequisite event was durably satisfied")
        _expect(not bool(riposte.get("incompatibility_state_available", true)), "skill tree preview exposes missing incompatibility ownership instead of inventing none")

    _expect(SkillProgressionService.begin_temporary_active(profile, 0, &"quest_skill:test_override"), "skill tree fixture applies an authoritative temporary active override")
    var temp_view: Dictionary = SKILL_TREE_VIEW_SERVICE_SCRIPT.build_view(profile)
    var temp := temp_view.get("temporary_override", {}) as Dictionary
    _expect(bool(temp_view.get("accepted", false)) and not temp.is_empty(), "skill tree view preserves serializable temporary override state")
    _expect(int(temp.get("slot_index", -1)) == 0 and StringName(String(temp.get("temporary_skill_id", &""))) == &"quest_skill:test_override" and StringName(String(temp.get("displaced_skill_id", &""))) == &"arc_cleave", "skill tree view preserves exact temporary/displaced active identities")
    _expect(StringName(String((temp_view.get("active_slots", []) as Array)[0])) == &"quest_skill:test_override", "skill tree view reflects the exact temporary active slot contents")

    var detached: Dictionary = temp_view.duplicate(true)
    (detached.get("active_slots", []) as Array)[0] = "skill:mutated"
    var fresh: Dictionary = SKILL_TREE_VIEW_SERVICE_SCRIPT.build_view(profile)
    _expect(StringName(String((fresh.get("active_slots", []) as Array)[0])) == &"quest_skill:test_override", "skill tree view snapshots cannot mutate persistent loadout state")

    var malformed := ProfileCreationService.create_profile(2, "Skill Tree Bad", "mage")
    malformed.skill_state["active_slots"] = ["arcane_lance"]
    var rejected: Dictionary = SKILL_TREE_VIEW_SERVICE_SCRIPT.build_view(malformed)
    _expect(not bool(rejected.get("accepted", true)) and StringName(rejected.get("reason_id", &"")) == SKILL_TREE_VIEW_SERVICE_SCRIPT.REASON_SKILL_STATE_INVALID, "skill tree view fails closed on malformed persistent skill state")

    if _failures == 0:
        print("SKILL TREE VIEW SERVICE TEST PASS")
    else:
        push_error("SKILL TREE VIEW SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _find_entry(entries: Array, skill_id: StringName) -> Dictionary:
    for raw_entry: Variant in entries:
        if raw_entry is Dictionary and StringName(String((raw_entry as Dictionary).get("skill_id", &""))) == skill_id:
            return (raw_entry as Dictionary).duplicate(true)
    return {}


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
