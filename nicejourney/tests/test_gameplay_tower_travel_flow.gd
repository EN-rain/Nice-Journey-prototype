extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_ROOT := "user://test_gameplay_tower_travel_flow"

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var service := SaveService.new(SAVE_ROOT)
    for slot: int in range(1, SaveService.SLOT_COUNT + 1):
        service.delete_slot(slot)
    await _test_floor1_live_commit(service)
    await _test_danger_confirmation(service)
    await _test_active_quest_leave_guard(service)
    for slot: int in range(1, SaveService.SLOT_COUNT + 1):
        service.delete_slot(slot)
    if _failures == 0:
        print("GAMEPLAY TOWER TRAVEL FLOW TEST PASS")
    else:
        push_error("GAMEPLAY TOWER TRAVEL FLOW TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_floor1_live_commit(service: SaveService) -> void:
    var profile := ProfileCreationService.create_profile(1, "Live Travel", "ranged")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    _expect(service.save_profile(1, profile) == OK, "live tower-travel fixture persists source profile")
    var gameplay := await _spawn_gameplay(profile, service, 1)
    var result := gameplay.request_tower_travel(1, false)
    _expect(bool(result.get("accepted", false)), "GameplayRoot performs plan -> runtime preparation -> checkpoint save -> tower activation for Floor 1")
    _expect(gameplay.is_tower_floor_active() and gameplay.tower_floor_session_host.active_floor_id == 1, "successful live travel activates the committed floor in gameplay")
    _expect(profile.tower_floor_states.has("1"), "successful live travel mutates live profile only after durable commit")
    _expect(int(profile.safe_state.get("floor_id", -1)) == 1, "successful live travel advances the durable safe snapshot to Floor 1")
    var loaded := service.load_profile(1)
    _expect(loaded != null and loaded.tower_floor_states.has("1"), "live tower-travel floor instance survives disk reload")
    _expect(loaded != null and int(loaded.safe_state.get("floor_id", -1)) == 1, "live tower-travel safe arrival survives disk reload")
    if loaded != null:
        var player_state := loaded.safe_state.get("player_state", {}) as Dictionary
        _expect(player_state.has("stamina") and player_state.has("position_x") and player_state.has("position_y"), "travel checkpoint captures currently authoritative player movement/resource state")
    gameplay.queue_free()
    await process_frame

func _test_danger_confirmation(service: SaveService) -> void:
    var profile := ProfileCreationService.create_profile(2, "Danger Travel", "mage")
    profile.level = 1
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_4_unlocked"] = true
    _expect(service.save_profile(2, profile) == OK, "danger-confirmation source profile persists")
    var before := profile.to_dictionary()
    var gameplay := await _spawn_gameplay(profile, service, 2)
    var pending := gameplay.request_tower_travel(4, false)
    _expect(not bool(pending.get("accepted", false)) and pending.get("reason_id", &"") == &"danger_confirmation_required", "DANGER III-V live travel cannot bypass explicit confirmation")
    _expect(profile.to_dictionary() == before and not profile.tower_floor_states.has("4"), "unconfirmed danger prompt mutates neither live profile nor floor state")
    var committed := gameplay.request_tower_travel(4, true)
    _expect(bool(committed.get("accepted", false)) and gameplay.tower_floor_session_host.active_floor_id == 4, "confirmed underleveled floor remains enterable")
    gameplay.queue_free()
    await process_frame

func _test_active_quest_leave_guard(service: SaveService) -> void:
    var profile := ProfileCreationService.create_profile(3, "Leave Guard", "melee")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    profile.quest_progress["side_region3_escort"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"escort_objective",
        "attempt_id": &"attempt:live_leave_guard",
        "objective_state": {"actor_id": "npc:escort_fixture", "route_progress": 1},
    }
    _expect(service.save_profile(3, profile) == OK, "active-quest travel guard source profile persists")
    var before := profile.to_dictionary()
    var gameplay := await _spawn_gameplay(profile, service, 3)
    var rejected := gameplay.request_tower_travel(1, false)
    _expect(not bool(rejected.get("accepted", false)) and rejected.get("reason_id", &"") == TowerTravelPlanService.REASON_LEAVE_PLAN_MISSING, "live Sigil travel refuses to strand an active region quest without authored leave policy")
    _expect(profile.to_dictionary() == before, "leave-policy rejection keeps live source profile unchanged")
    var loaded := service.load_profile(3)
    var disk_unchanged := loaded != null and not loaded.tower_floor_states.has("1")
    if loaded != null:
        var loaded_entry := loaded.quest_progress.get("side_region3_escort", {}) as Dictionary
        disk_unchanged = disk_unchanged \
            and StringName(String(loaded_entry.get("state", &""))) == QuestProgressState.STATE_ACTIVE \
            and StringName(String(loaded_entry.get("attempt_id", &""))) == &"attempt:live_leave_guard"
    _expect(disk_unchanged, "leave-policy rejection writes no partial travel state to disk")

    gameplay.shared_active_combat.acquire(&"encounter:test_guard", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER)
    var combat_rejected := gameplay.request_tower_travel(1, false)
    _expect(not bool(combat_rejected.get("accepted", false)) and combat_rejected.get("reason_id", &"") == TowerAccessMenuService.REASON_OPERATION_BLOCKED, "live Sigil travel rechecks shared active-combat state at request time")
    gameplay.shared_active_combat.release_source(&"encounter:test_guard")
    gameplay.queue_free()
    await process_frame

func _spawn_gameplay(profile: ProfileSnapshot, service: SaveService, slot_index: int) -> GameplayRoot:
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(service, slot_index), "GameplayRoot accepts explicit save-slot context")
    get_root().add_child(gameplay)
    await process_frame
    return gameplay

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
