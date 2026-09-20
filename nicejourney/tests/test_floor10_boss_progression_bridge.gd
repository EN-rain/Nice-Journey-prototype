extends SceneTree

const SANCTUM_SCENE: PackedScene = preload("res://src/world/tower/boss/tenth_warden_sanctum.tscn")

var _failures := 0
var _bridge_result: Dictionary = {}


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Boss Bridge", "melee")
    profile.quest_progress[String(Floor10PrimaryBossObjectiveService.QUEST_ID)] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:floor10_bridge",
        "objective_state": {},
    }
    var floor := FloorInstanceState.new()
    floor.floor_id = 10
    floor.instance_id = &"tower_floor_10:bridge_fixture"
    floor.seed = 1010
    floor.layout_revision_id = &"layout:floor10_bridge_v1"
    floor.quest_state = {"primary_floor_10": "active"}
    _expect(TowerFloorStateService.commit_floor_state(profile, floor), "bridge fixture commits a valid Floor 10 state")

    var sanctum := SANCTUM_SCENE.instantiate() as TenthWardenSanctum
    root.add_child(sanctum)
    await process_frame
    var player := _combatant(&"player:floor10_bridge", 100, true, true)
    var boss := _combatant(Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID, 50, false, false)
    _expect(sanctum.prepare_encounter(player, boss), "bridge fixture prepares the genuine sanctum runtime")

    var bridge := Floor10BossProgressionBridge.new()
    bridge.progression_committed.connect(_on_progression_committed)
    var bound := bridge.bind(profile, sanctum)
    _expect(bool(bound.get("accepted", false)) and bridge.is_bound(), "progression bridge binds one live sanctum to the authoritative profile")

    var hit := sanctum.boss_runtime.resolve_player_contact(9001, 0, _attack(50.0))
    _expect(bool(hit.get("accepted", false)) and bool(hit.get("target_defeated", false)), "bridge fixture defeats the boss through authoritative combat")
    _expect(sanctum.commit_terminal_outcome(), "sanctum commits its terminal victory")
    _expect(bool(_bridge_result.get("accepted", false)) and bool(_bridge_result.get("objectives_complete", false)), "terminal victory is bridged into Floor 10 primary objective progress")
    _expect(StringName(String(_bridge_result.get("outcome_id", &""))) == TenthWardenEncounterState.OUTCOME_VICTORY, "bridge preserves the exact terminal outcome identity")
    var entry := profile.quest_progress[String(Floor10PrimaryBossObjectiveService.QUEST_ID)] as Dictionary
    _expect(StringName(String(entry.get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE, "bridge reaches ObjectivesComplete without silently turning in the quest")
    _expect(not bool((profile.tower_floor_states["10"] as Dictionary).get("primary_cleared", false)), "bridge does not bypass Floor 10 exit/turn-in ownership")

    bridge.unbind()
    _expect(not bridge.is_bound(), "progression bridge can release sanctum ownership cleanly")
    sanctum.queue_free()
    await process_frame

    if _failures == 0:
        print("FLOOR 10 BOSS PROGRESSION BRIDGE TEST PASS")
    else:
        push_error("FLOOR 10 BOSS PROGRESSION BRIDGE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _combatant(actor_id: StringName, hp: int, block_supported: bool, parry_supported: bool) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, hp, 30.0, 0.0, 0.0, 30.0, true, block_supported, parry_supported), "%s combatant validates" % String(actor_id))
    return state


func _attack(raw_damage: float) -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": raw_damage,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 5.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }


func _on_progression_committed(result: Dictionary) -> void:
    _bridge_result = result.duplicate(true)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
