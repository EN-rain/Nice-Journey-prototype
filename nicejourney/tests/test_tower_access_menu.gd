extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_catalog()
    _test_menu()
    _test_guards()
    print("TOWER ACCESS MENU TEST PASS" if _failures == 0 else "TOWER ACCESS MENU TEST FAIL")
    quit(_failures)

func _test_catalog() -> void:
    _expect(PrototypeTowerFloorCatalog.validate_catalog().is_empty(), "floor catalog validates")
    for floor_id: int in range(1, 11):
        var e := PrototypeTowerFloorCatalog.get_entry(floor_id)
        _expect(int(e["recommended_level"]) == floor_id, "recommended level %d" % floor_id)
        _expect(int(e["population_budget"]) == floor_id * 10, "population budget %d" % floor_id)
    _expect(int(PrototypeTowerFloorCatalog.get_entry(5)["elite_target"]) == 3, "floor 5 elites")
    _expect(bool(PrototypeTowerFloorCatalog.get_entry(10)["boss"]), "floor 10 boss")

func _test_menu() -> void:
    var profile := ProfileCreationService.create_profile(1, "Sigil Tester", "melee")
    profile.level = 1
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    for floor_id: int in [1, 2, 4, 10]:
        profile.permanent_flags["tower_floor_%d_unlocked" % floor_id] = true
    profile.permanent_flags["tower_floor_3_cleared"] = true
    profile.quest_progress["primary_floor_4"] = {"state": QuestProgressState.STATE_ACTIVE, "stage_id": &"floor_objective", "attempt_id": &"attempt:f4p", "objective_state": {}}
    profile.quest_progress["side_tower_floor4_escort"] = {"state": QuestProgressState.STATE_SUSPENDED, "stage_id": &"escort_objective", "attempt_id": &"attempt:f4s", "objective_state": {}}
    var guard := GameplayOperationGuard.new()
    var menu := TowerAccessMenuService.build_menu(profile, guard)
    _expect(bool(menu["accepted"]), "menu opens")
    var entries: Array = menu["entries"]
    _expect(entries.size() == 5, "only cleared/unlocked floors are listed")
    _expect(_find(entries, 3).get("state") == &"cleared", "cleared floor listed")
    _expect(_find(entries, 5).is_empty(), "locked floor hidden")
    var f2 := _find(entries, 2)
    _expect(int(f2["danger_rank"]) == int(DangerEvaluator.Rank.II) and not bool(f2["requires_danger_confirmation"]), "danger II behavior")
    var f4 := _find(entries, 4)
    _expect(int(f4["danger_rank"]) == int(DangerEvaluator.Rank.IV) and bool(f4["requires_danger_confirmation"]), "danger IV warning")
    _expect((f4["active_quest_ids"] as Array).size() == 2, "floor quest indicators")
    var f10 := _find(entries, 10)
    _expect(bool(f10["elite_warning"]) and bool(f10["boss_warning"]), "floor 10 warnings")
    _expect(bool(TowerAccessMenuService.validate_selection(profile, guard, 10)["accepted"]), "underlevel does not hard-lock unlocked floor")
    guard.free()

func _test_guards() -> void:
    var profile := ProfileCreationService.create_profile(1, "Guard Tester", "mage")
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    var guard := GameplayOperationGuard.new()
    _expect(TowerAccessMenuService.build_menu(profile, guard)["reason_id"] == TowerAccessMenuService.REASON_SIGIL_NOT_OWNED, "sigil required")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    _expect(bool(TowerAccessMenuService.build_menu(profile, guard)["accepted"]), "menu opens outside combat")
    var token := guard.acquire_blocker(&"combat:fixture", GameplayOperationGuard.REASON_ACTIVE_COMBAT, "Active combat", [GameplayOperationGuard.OP_SIGIL_TRAVEL])
    _expect(token > 0, "combat blocker acquired")
    _expect(TowerAccessMenuService.validate_selection(profile, guard, 1)["reason_id"] == TowerAccessMenuService.REASON_OPERATION_BLOCKED, "stale selection blocked")
    guard.release_blocker(token)
    _expect(bool(TowerAccessMenuService.validate_selection(profile, guard, 1)["accepted"]), "selection restored")
    _expect(not bool(TowerAccessMenuService.validate_selection(profile, guard, 2)["accepted"]), "locked floor rejected")
    guard.free()

func _find(entries: Array, floor_id: int) -> Dictionary:
    for raw: Variant in entries:
        if raw is Dictionary and int((raw as Dictionary).get("floor_id", 0)) == floor_id:
            return (raw as Dictionary).duplicate(true)
    return {}

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
