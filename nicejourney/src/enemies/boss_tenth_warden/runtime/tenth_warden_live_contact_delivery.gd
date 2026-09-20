class_name TenthWardenLiveContactDelivery
extends RefCounted

signal contact_resolved(result: Dictionary)

const REASON_INVALID_DEFENDER_FACTS: StringName = &"invalid_defender_facts"

var sanctum: TenthWardenSanctum = null
var player: PlayerController = null
var class_runtime: ClassCombatRuntime = null
var boss_anchor: Node2D = null
var defender_facts_provider: Callable = Callable()

var _active_context: Dictionary = {}
var _attempted_hit_intervals: Dictionary = {}
var _last_target_shape_checked: bool = false
var _last_target_shape_overlap: bool = false
var _arc_volley_projectiles: Array[Dictionary] = []
var last_arc_volley_impact: Dictionary = {}


func configure(
    source_sanctum: TenthWardenSanctum,
    source_player: PlayerController,
    source_class_runtime: ClassCombatRuntime,
    source_boss_anchor: Node2D,
    source_defender_facts_provider: Callable
) -> bool:
    reset()
    if (
        source_sanctum == null
        or source_player == null
        or source_class_runtime == null
        or source_boss_anchor == null
        or source_defender_facts_provider.is_null()
        or not source_defender_facts_provider.is_valid()
    ):
        return false
    if (
        source_sanctum.autonomous_runtime == null
        or source_sanctum.boss_runtime == null
        or source_sanctum.production_authoring == null
        or not source_sanctum.production_authoring.validate_authoring().is_empty()
    ):
        return false

    sanctum = source_sanctum
    player = source_player
    class_runtime = source_class_runtime
    boss_anchor = source_boss_anchor
    defender_facts_provider = source_defender_facts_provider
    if not sanctum.boss_active_delivery_window_opened.is_connected(_on_delivery_window_opened):
        sanctum.boss_active_delivery_window_opened.connect(_on_delivery_window_opened)
    return true


func is_configured() -> bool:
    return (
        sanctum != null
        and is_instance_valid(sanctum)
        and player != null
        and is_instance_valid(player)
        and class_runtime != null
        and boss_anchor != null
        and is_instance_valid(boss_anchor)
        and not defender_facts_provider.is_null()
        and defender_facts_provider.is_valid()
    )


func advance_fixed_tick(delta: float = 1.0 / 60.0) -> bool:
    if not is_configured():
        return false
    if not is_finite(delta) or delta <= 0.0:
        return false
    _advance_arc_volley_projectiles(delta)
    if _active_context.is_empty():
        return true
    if sanctum.autonomous_runtime == null or sanctum.autonomous_runtime.action_machine == null:
        _clear_active_delivery()
        return false

    var machine := sanctum.autonomous_runtime.action_machine
    if machine.get_phase() != ActionStateMachine.Phase.ACTIVE:
        _clear_active_delivery()
        return true

    var action_id := machine.get_current_action_id()
    var action_instance_id := machine.get_current_instance_id()
    if (
        action_id != StringName(String(_active_context.get("action_id", &"")))
        or action_instance_id != int(_active_context.get("action_instance_id", 0))
    ):
        _clear_active_delivery()
        return false

    var attack := sanctum.production_authoring.attack_for_move(action_id)
    if attack == null or attack.geometry == null:
        _clear_active_delivery()
        return false

    var active_tick := machine.get_phase_elapsed_ticks()
    for hit_interval_index: int in range(attack.geometry.hit_active_ticks.size()):
        if int(attack.geometry.hit_active_ticks[hit_interval_index]) != active_tick:
            continue
        if _attempted_hit_intervals.has(hit_interval_index):
            continue
        _attempted_hit_intervals[hit_interval_index] = true
        _try_deliver_interval(attack, hit_interval_index)
    return true


func reset() -> void:
    if sanctum != null and is_instance_valid(sanctum):
        var callback := Callable(self, &"_on_delivery_window_opened")
        if sanctum.boss_active_delivery_window_opened.is_connected(callback):
            sanctum.boss_active_delivery_window_opened.disconnect(callback)
    sanctum = null
    player = null
    class_runtime = null
    boss_anchor = null
    defender_facts_provider = Callable()
    _clear_active_delivery()
    _clear_arc_volley_projectiles()
    last_arc_volley_impact.clear()


func get_debug_snapshot() -> Dictionary:
    var attempted: Array[int] = []
    for raw_index: Variant in _attempted_hit_intervals.keys():
        attempted.append(int(raw_index))
    attempted.sort()
    return {
        "configured": is_configured(),
        "active_action_id": StringName(String(_active_context.get("action_id", &""))),
        "active_action_instance_id": int(_active_context.get("action_instance_id", 0)),
        "attempted_hit_intervals": attempted,
        "last_target_shape_checked": _last_target_shape_checked,
        "last_target_shape_overlap": _last_target_shape_overlap,
        "arc_volley_projectiles_active": _arc_volley_projectiles.size(),
        "last_arc_volley_impact": last_arc_volley_impact.duplicate(true),
    }


func _on_delivery_window_opened(context: Dictionary) -> void:
    _active_context = context.duplicate(true)
    # The authored startup commits to an aim. Neither the melee query nor the
    # successive Volley projectiles may silently turn to follow a late dodge.
    _active_context["aim_direction"] = sanctum.get_locked_attack_direction()
    _attempted_hit_intervals.clear()


func _try_deliver_interval(
    attack: EnemySignatureAttackAuthoring,
    hit_interval_index: int
) -> void:
    if StringName(String(_active_context.get("action_id", &""))) == TenthWardenEncounterState.MOVE_ARC_VOLLEY:
        _spawn_arc_volley_projectile(attack, hit_interval_index)
        return
    if not _player_is_inside_authored_geometry(attack.geometry):
        return

    var defender_facts_variant: Variant = defender_facts_provider.call(
        boss_anchor.global_position,
        player.global_position
    )
    if not defender_facts_variant is Dictionary:
        contact_resolved.emit(_rejected(REASON_INVALID_DEFENDER_FACTS, hit_interval_index))
        return
    var defender_facts := defender_facts_variant as Dictionary
    for key: String in ["evade_window_active", "defense_mode", "facing_covered"]:
        if not defender_facts.has(key):
            contact_resolved.emit(_rejected(REASON_INVALID_DEFENDER_FACTS, hit_interval_index))
            return
    if (
        not defender_facts["evade_window_active"] is bool
        or not defender_facts["facing_covered"] is bool
    ):
        contact_resolved.emit(_rejected(REASON_INVALID_DEFENDER_FACTS, hit_interval_index))
        return
    var defense_mode := StringName(String(defender_facts["defense_mode"]))
    if not [
        DirectHitResolver.DEFENSE_NONE,
        DirectHitResolver.DEFENSE_BLOCK,
        DirectHitResolver.DEFENSE_PARRY,
    ].has(defense_mode):
        contact_resolved.emit(_rejected(REASON_INVALID_DEFENDER_FACTS, hit_interval_index))
        return

    var contact_facts := {
        "actor_id": _active_context.get("actor_id", &""),
        "target_id": _active_context.get("target_id", &""),
        "action_id": _active_context.get("action_id", &""),
        "action_instance_id": int(_active_context.get("action_instance_id", 0)),
        "hit_interval_index": hit_interval_index,
        "geometry_id": attack.geometry.geometry_id,
        "contact_confirmed": true,
        "critical_triggered": false,
        "weak_point_triggered": false,
    }
    var player_state := sanctum.encounter_runtime.get_combatant(sanctum.boss_runtime.player_id)
    var base_block_supported := player_state.block_supported if player_state != null else false
    if player_state != null and bool(defender_facts.get("playtest_ward_active", false)):
        player_state.block_supported = true
    var result := sanctum.resolve_confirmed_boss_contact(
        contact_facts,
        bool(defender_facts["evade_window_active"]),
        defense_mode,
        bool(defender_facts["facing_covered"])
    )
    if player_state != null:
        player_state.block_supported = base_block_supported
    result["live_delivery"] = true
    result["action_instance_id"] = int(_active_context.get("action_instance_id", 0))
    result["hit_interval_index"] = hit_interval_index
    result["geometry_id"] = attack.geometry.geometry_id
    contact_resolved.emit(result.duplicate(true))


func _spawn_arc_volley_projectile(attack: EnemySignatureAttackAuthoring, hit_interval_index: int) -> void:
    # A ticket can only originate during this exact authenticated ACTIVE window.
    # Its travel may finish during recovery without resurrecting an attack
    # reservation or admitting a hit merely because an action was queued.
    if (
        sanctum.arc_volley_projectile_scene == null or sanctum.arc_volley_projectile_speed_px_s <= 0.0
        or sanctum.arc_volley_projectile_radius_px <= 0.0 or sanctum.arc_volley_projectile_lifetime_ticks <= 0
        or sanctum.boss_runtime == null or attack == null or attack.geometry == null or attack.payload == null
        or attack.payload.delivery != DirectHitResolver.DELIVERY_PROJECTILE
    ):
        return
    var origin := boss_anchor.global_position
    var locked_aim: Vector2 = _active_context.get("aim_direction", Vector2.ZERO)
    if not locked_aim.is_finite() or locked_aim.length_squared() <= 0.0001:
        return
    var count := attack.geometry.hit_interval_count
    var spread_index := float(hit_interval_index) - float(count - 1) * 0.5
    var direction := locked_aim.normalized().rotated(deg_to_rad(spread_index * sanctum.arc_volley_spread_degrees))
    var bullet := sanctum.arc_volley_projectile_scene.instantiate() as Node2D
    if bullet == null:
        return
    sanctum.add_child(bullet)
    bullet.global_position = origin
    bullet.rotation = direction.angle()
    var circle := CircleShape2D.new()
    circle.radius = sanctum.arc_volley_projectile_radius_px
    _arc_volley_projectiles.append({
        "visual": bullet,
        "shape": circle,
        "direction": direction,
        "range_px": attack.geometry.max_reach_px,
        "traveled_px": 0.0,
        "remaining_ticks": sanctum.arc_volley_projectile_lifetime_ticks,
        "action_instance_id": int(_active_context["action_instance_id"]),
        "hit_interval_index": hit_interval_index,
        "geometry_id": attack.geometry.geometry_id,
        "collision_mask": attack.geometry.collision_mask,
        "payload": attack.payload.make_payload(false, false),
    })


func _advance_arc_volley_projectiles(delta: float) -> void:
    if sanctum == null or player == null:
        _clear_arc_volley_projectiles()
        return
    for index: int in range(_arc_volley_projectiles.size() - 1, -1, -1):
        var ticket := _arc_volley_projectiles[index]
        var bullet := ticket.get("visual") as Node2D
        if bullet == null or not is_instance_valid(bullet):
            _arc_volley_projectiles.remove_at(index)
            continue
        if (
            sanctum.boss_runtime == null or sanctum.encounter_runtime == null
            or sanctum.committed_terminal_outcome != TenthWardenEncounterState.OUTCOME_ONGOING
            or sanctum.boss_runtime.evaluate_live_outcome() != TenthWardenEncounterState.OUTCOME_ONGOING
        ):
            bullet.queue_free()
            _arc_volley_projectiles.remove_at(index)
            continue
        var from := bullet.global_position
        var remaining_range := float(ticket["range_px"]) - float(ticket["traveled_px"])
        var step_px := minf(sanctum.arc_volley_projectile_speed_px_s * delta, remaining_range)
        if step_px <= 0.0:
            bullet.queue_free()
            _arc_volley_projectiles.remove_at(index)
            continue
        var to := from + (ticket["direction"] as Vector2) * step_px
        var arena_bounds := sanctum.get_arena_rect().grow(-sanctum.boundary_thickness)
        if not arena_bounds.has_point(sanctum.to_local(to)):
            bullet.queue_free()
            _arc_volley_projectiles.remove_at(index)
            continue
        var ray := PhysicsRayQueryParameters2D.create(from, to, int(ticket["collision_mask"]))
        ray.collide_with_areas = false
        ray.collide_with_bodies = true
        var obstacle := sanctum.get_world_2d().direct_space_state.intersect_ray(ray)
        if not obstacle.is_empty() and obstacle.get("collider") != player:
            bullet.queue_free()
            _arc_volley_projectiles.remove_at(index)
            continue
        var target_shape := player.collision_shape if is_instance_valid(player) else null
        var target_hit := false
        if (
            target_shape != null and target_shape.shape != null and not target_shape.disabled
            and (player.collision_layer & int(ticket["collision_mask"])) != 0
        ):
            var target_transform := player.global_transform * target_shape.transform
            var closest := Geometry2D.get_closest_point_to_segment(target_transform.origin, from, to)
            target_hit = (ticket["shape"] as Shape2D).collide(
                Transform2D(0.0, closest), target_shape.shape, target_transform
            )
        bullet.global_position = to
        ticket["traveled_px"] = float(ticket["traveled_px"]) + step_px
        ticket["remaining_ticks"] = int(ticket["remaining_ticks"]) - 1
        if target_hit:
            _resolve_arc_volley_impact(ticket, from)
        if target_hit or int(ticket["remaining_ticks"]) <= 0 or float(ticket["traveled_px"]) >= float(ticket["range_px"]):
            bullet.queue_free()
            _arc_volley_projectiles.remove_at(index)


func _resolve_arc_volley_impact(ticket: Dictionary, incoming_position: Vector2) -> void:
    if sanctum == null or sanctum.boss_runtime == null or sanctum.encounter_runtime == null:
        return
    var defender: Variant = defender_facts_provider.call(incoming_position, player.global_position)
    if not defender is Dictionary:
        return
    var facts := defender as Dictionary
    if not facts.get("evade_window_active") is bool or not facts.get("facing_covered") is bool:
        return
    var defense := StringName(String(facts.get("defense_mode", &"")))
    if not [DirectHitResolver.DEFENSE_NONE, DirectHitResolver.DEFENSE_BLOCK, DirectHitResolver.DEFENSE_PARRY].has(defense):
        return
    var attack := sanctum.production_authoring.attack_for_move(TenthWardenEncounterState.MOVE_ARC_VOLLEY)
    if (
        attack == null or attack.geometry == null or attack.payload == null
        or attack.geometry.geometry_id != ticket["geometry_id"]
        or attack.payload.delivery != DirectHitResolver.DELIVERY_PROJECTILE
        or int(ticket["hit_interval_index"]) < 0
        or int(ticket["hit_interval_index"]) >= attack.geometry.hit_interval_count
    ):
        return
    var player_state := sanctum.encounter_runtime.get_combatant(sanctum.boss_runtime.player_id)
    var base_block_supported := player_state.block_supported if player_state != null else false
    if player_state != null and bool(facts.get("playtest_ward_active", false)):
        player_state.block_supported = true
    var result := sanctum.encounter_runtime.resolve_direct_contact(
        sanctum.boss_runtime.boss_id, sanctum.boss_runtime.player_id,
        int(ticket["action_instance_id"]), int(ticket["hit_interval_index"]),
        ticket["payload"] as Dictionary, bool(facts["evade_window_active"]),
        defense, bool(facts["facing_covered"])
    )
    if player_state != null:
        player_state.block_supported = base_block_supported
    result["live_delivery"] = true
    result["projectile_travel_confirmed"] = true
    result["action_id"] = TenthWardenEncounterState.MOVE_ARC_VOLLEY
    result["action_instance_id"] = int(ticket["action_instance_id"])
    result["hit_interval_index"] = int(ticket["hit_interval_index"])
    result["geometry_id"] = ticket["geometry_id"]
    last_arc_volley_impact = result.duplicate(true)
    contact_resolved.emit(result.duplicate(true))


func _clear_arc_volley_projectiles() -> void:
    for ticket: Dictionary in _arc_volley_projectiles:
        var bullet := ticket.get("visual") as Node2D
        if bullet != null and is_instance_valid(bullet):
            bullet.queue_free()
    _arc_volley_projectiles.clear()


func _player_is_inside_authored_geometry(geometry: EnemyAttackGeometryAuthoring) -> bool:
    if (
        geometry == null
        or not geometry.live_placement_declared
        or geometry.query_shape == null
        or boss_anchor == null
        or player == null
    ):
        return false
    if boss_anchor.global_position.distance_to(player.global_position) > geometry.max_reach_px:
        return false
    if player.collision_shape == null or player.collision_shape.shape == null or player.collision_shape.disabled:
        return false
    if (geometry.collision_mask & player.collision_layer) == 0:
        return false

    _last_target_shape_checked = true
    # Keep the visible actor upright while its authored attack rectangle is
    # rotated and offset in the locked world-space aim direction.
    var locked_aim: Vector2 = _active_context.get("aim_direction", Vector2.ZERO)
    if not locked_aim.is_finite() or locked_aim.length_squared() <= 0.0001:
        return false
    var attack_basis := Transform2D(locked_aim.angle(), boss_anchor.global_position)
    var attack_transform := geometry.live_query_transform(attack_basis)
    var target_transform := player.global_transform * player.collision_shape.transform
    _last_target_shape_overlap = geometry.query_shape.collide(
        attack_transform,
        player.collision_shape.shape,
        target_transform
    )
    return _last_target_shape_overlap


func _clear_active_delivery() -> void:
    _active_context.clear()
    _attempted_hit_intervals.clear()
    _last_target_shape_checked = false
    _last_target_shape_overlap = false


func _rejected(reason_id: StringName, hit_interval_index: int) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "outcome": DirectHitResolver.OUTCOME_REJECTED,
        "hp_damage": 0,
        "hit_interval_index": hit_interval_index,
        "live_delivery": true,
    }
