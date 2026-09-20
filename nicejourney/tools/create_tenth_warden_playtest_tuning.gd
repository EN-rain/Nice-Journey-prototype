extends SceneTree

# Explicitly provisional numeric authoring. Re-run only to intentionally reset
# the inspector-owned .tres playtest values. No image or texture generation.
const BOSS_PATH := "res://src/enemies/boss_tenth_warden/runtime/tenth_warden_playtest_v01.tres"
const DEFENDER_PATH := "res://src/data/tuning/player_defender_facts_playtest_v01.tres"


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var boss := TenthWardenProductionAuthoring.new()
    boss.resource_name = "PLAYTEST Tenth Warden v01 — provisional balance, not final"
    boss.authored = true
    boss.playtest_placeholder = true
    boss.max_hp = 320
    boss.stamina = 60.0
    boss.stamina_recovery_per_tick = 0.8
    boss.physical_defense = 2.0
    boss.arcane_defense = 2.0
    boss.poise_threshold = 22.0
    boss.interruptible_declared = true
    boss.interruptible = true
    boss.block_supported_declared = true
    boss.block_supported = false
    boss.parry_supported_declared = true
    boss.parry_supported = false

    # One shared, explicitly provisional contact shape per move family across phases.
    # Sizes/offsets describe executable temporary gameplay geometry, not sprite art.
    var moves := [
        {"id": TenthWardenEncounterState.MOVE_TWIN_CUT, "startup": 16, "active": 8, "recovery": 25, "phase_two_recovery": 16, "cost": 8.0, "damage": 7.0, "pressure": 2.0, "size": Vector2(84, 72), "offset": Vector2(30, 0), "reach": 72.0, "hits": [1, 5], "block": true, "parry": true, "arcane": false},
        {"id": TenthWardenEncounterState.MOVE_WARDEN_LUNGE, "startup": 24, "active": 7, "recovery": 33, "phase_two_recovery": 22, "cost": 12.0, "damage": 13.0, "pressure": 5.0, "size": Vector2(144, 56), "offset": Vector2(36, 0), "reach": 108.0, "hits": [3], "block": true, "parry": true, "arcane": false},
        {"id": TenthWardenEncounterState.MOVE_ARC_VOLLEY, "startup": 27, "active": 10, "recovery": 28, "phase_two_recovery": 18, "cost": 14.0, "damage": 5.0, "pressure": 2.0, "size": Vector2(240, 148), "offset": Vector2.ZERO, "reach": 164.0, "hits": [1, 4, 7], "block": true, "parry": false, "arcane": true},
        {"id": TenthWardenEncounterState.MOVE_CRESCENT_SWEEP, "startup": 28, "active": 8, "recovery": 36, "phase_two_recovery": 25, "cost": 16.0, "damage": 14.0, "pressure": 6.0, "size": Vector2(160, 120), "offset": Vector2(32, 0), "reach": 112.0, "hits": [4], "block": false, "parry": false, "arcane": false},
        {"id": TenthWardenEncounterState.MOVE_PUNISHING_STEP, "startup": 18, "active": 6, "recovery": 25, "phase_two_recovery": 16, "cost": 10.0, "damage": 10.0, "pressure": 3.0, "size": Vector2(100, 68), "offset": Vector2(30, 0), "reach": 80.0, "hits": [2], "block": true, "parry": true, "arcane": false},
    ]
    for move: Dictionary in moves:
        var move_id: StringName = move["id"]
        boss.move_actions.append(_action(move_id, int(move["startup"]), int(move["active"]), int(move["recovery"]), float(move["cost"])))
        boss.phase_two_move_actions.append(_action(move_id, maxi(1, int(move["startup"]) - 5), int(move["active"]), int(move["phase_two_recovery"]), float(move["cost"])))

        var shape := RectangleShape2D.new()
        shape.size = move["size"] as Vector2
        var geometry := EnemyAttackGeometryAuthoring.new()
        geometry.authored = true
        geometry.geometry_id = StringName("geometry:playtest:tenth_warden:%s" % String(move_id))
        geometry.query_shape = shape
        geometry.max_reach_px = float(move["reach"])
        geometry.collision_mask = 1
        geometry.hit_interval_count = (move["hits"] as Array).size()
        geometry.live_placement_declared = true
        geometry.local_offset = move["offset"] as Vector2
        geometry.local_rotation_radians = 0.0
        geometry.hit_active_ticks = PackedInt32Array(move["hits"])

        var payload := EnemyAttackPayloadAuthoring.new()
        payload.authored = true
        payload.damage_domain = DirectHitResolver.DOMAIN_ARCANE if bool(move["arcane"]) else DirectHitResolver.DOMAIN_PHYSICAL
        payload.delivery = DirectHitResolver.DELIVERY_PROJECTILE if move_id == TenthWardenEncounterState.MOVE_ARC_VOLLEY else DirectHitResolver.DELIVERY_CONTACT
        payload.raw_damage = float(move["damage"])
        payload.guard_pressure = float(move["pressure"])
        payload.dodgeable = true
        payload.blockable = bool(move["block"])
        payload.parryable = bool(move["parry"])
        payload.critical_multiplier = 1.0
        payload.weak_point_multiplier = 1.5

        var attack := EnemySignatureAttackAuthoring.new()
        attack.action_id = move_id
        attack.geometry = geometry
        attack.payload = payload
        boss.move_attacks.append(attack)

    boss.phase_transition_action = _action(TenthWardenEncounterState.ACTION_PHASE_TRANSITION, 20, 1, 25, 0.0)
    boss.phase_one_move_order = TenthWardenEncounterState.MOVE_IDS.duplicate()
    boss.phase_two_move_order = [
        TenthWardenEncounterState.MOVE_TWIN_CUT,
        TenthWardenEncounterState.MOVE_WARDEN_LUNGE,
        TenthWardenEncounterState.MOVE_ARC_VOLLEY,
        TenthWardenEncounterState.MOVE_CRESCENT_SWEEP,
        TenthWardenEncounterState.MOVE_WARDEN_LUNGE,
        TenthWardenEncounterState.MOVE_PUNISHING_STEP,
    ]
    boss.phase_two_heavy_move_ids = [TenthWardenEncounterState.MOVE_WARDEN_LUNGE, TenthWardenEncounterState.MOVE_CRESCENT_SWEEP]

    var errors := boss.validate_authoring()
    if not errors.is_empty():
        push_error("PLAYTEST BOSS AUTHORING INVALID: %s" % str(errors))
        quit(1)
        return
    var defender := PlayerDefenderFactsTuning.new()
    defender.resource_name = "PLAYTEST Defender Facts v01 — provisional balance, not final"
    defender.authored = true
    defender.playtest_placeholder = true
    defender.dodge_invulnerability_start_seconds = 0.015
    defender.dodge_invulnerability_duration_seconds = 0.09
    defender.frontal_coverage_degrees = 120.0
    var movement := load("res://src/data/tuning/movement_default.tres") as MovementTuning
    if not defender.validate_tuning(movement).is_empty():
        push_error("PLAYTEST DEFENDER TUNING INVALID")
        quit(1)
        return
    var boss_saved := ResourceSaver.save(boss, BOSS_PATH)
    var defender_saved := ResourceSaver.save(defender, DEFENDER_PATH)
    print("PLAYTEST TUNING: boss=%d defender=%d" % [boss_saved, defender_saved])
    quit(0 if boss_saved == OK and defender_saved == OK else 1)


func _action(action_id: StringName, startup: int, active: int, recovery: int, stamina_cost: float) -> ActionDefinition:
    var action := ActionDefinition.new()
    action.action_id = action_id
    action.startup_ticks = startup
    action.commit_ticks = 1
    action.active_ticks = active
    action.recovery_ticks = recovery
    action.cooldown_ticks = 0
    action.cost_resource = TenthWardenProductionAuthoring.STAMINA_RESOURCE_ID if stamina_cost > 0.0 else &""
    action.cost_amount = stamina_cost
    return action
