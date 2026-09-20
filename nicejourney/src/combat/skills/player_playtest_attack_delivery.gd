class_name PlayerPlaytestAttackDelivery
extends Node2D

# Opt-in playtest hit-delivery owner. Only active, visible encounter actors
# may be hit; the canonical encounter resolves HP, mitigation and defeat.
signal playtest_contact_resolved(encounter_id: StringName, actor_id: StringName, result: Dictionary)

@export var content: PlayerPlaytestAttackContent
@export_range(1, 300, 1) var projectile_max_lifetime_ticks: int = 120
@export var ward_marker_color: Color = Color(0.4, 0.75, 1.0, 0.4)

var player: PlayerController = null
var class_runtime: ClassCombatRuntime = null
var host: TowerEncounterSessionHost = null
var boss_provider: Callable = Callable()
var region3_side_target_provider: Callable = Callable()
var skill_rank_profile: ProfileSnapshot = null
var skill_rank_tuning: ActiveSkillsPlaytest = null
var passive_skill_runtime: RefCounted = null
var last_contact_result: Dictionary = {}
var last_started_action_id: StringName = &""
var last_skill_movement_distance_px: float = 0.0
var _backstep_evade_ticks_remaining: int = 0
var _projectiles: Array[Dictionary] = []
var _pending_shots: Array[Dictionary] = []
var _pulses: Array[Dictionary] = []
var _ward_marker: Node2D = null


func configure(source_player: PlayerController, source_class_runtime: ClassCombatRuntime,
    source_host: TowerEncounterSessionHost, source_boss_provider: Callable = Callable()) -> bool:
    if (
        source_player == null or source_class_runtime == null or source_host == null
        or source_class_runtime.action_state_machine == null or content == null
        or not content.validate_content().is_empty()
    ):
        return false
    var previous := class_runtime.action_state_machine if class_runtime != null else null
    if previous != null and previous.phase_changed.is_connected(_on_action_phase_changed):
        previous.phase_changed.disconnect(_on_action_phase_changed)
    player = source_player
    class_runtime = source_class_runtime
    host = source_host
    boss_provider = source_boss_provider
    _clear_effects()
    class_runtime.action_state_machine.phase_changed.connect(_on_action_phase_changed)
    return true


func configure_skill_ranks(profile: ProfileSnapshot, tuning: ActiveSkillsPlaytest) -> bool:
    skill_rank_profile = null
    skill_rank_tuning = null
    if profile == null or tuning == null or not tuning.validate_content().is_empty():
        return false
    if not SkillLoadoutState.validate_dictionary(profile.skill_state).is_empty():
        return false
    skill_rank_profile = profile
    skill_rank_tuning = tuning
    return true


func set_passive_skill_runtime(runtime: RefCounted) -> void:
    passive_skill_runtime = runtime


func effect_for_action(action_id: StringName) -> Dictionary:
    if content == null or not content.validate_content().is_empty():
        return {}
    if class_runtime != null and class_runtime.starter_kit != null and class_runtime.starter_kit.basic_action != null:
        if class_runtime.starter_kit.basic_action.action_id == action_id:
            return content.basic_for(class_runtime.get_class_id())
    var prefix := "action:playtest:"
    if not String(action_id).begins_with(prefix):
        return {}
    var skill_id := StringName(String(action_id).trim_prefix(prefix))
    var effect := content.skill_for(skill_id)
    if skill_rank_profile == null or skill_rank_tuning == null:
        return effect
    var state := skill_rank_profile.skill_state
    if not SkillLoadoutState.validate_dictionary(state).is_empty():
        return {}
    var rank := int((state["ranks"] as Dictionary).get(String(skill_id), 0))
    return skill_rank_tuning.effect_for_rank(skill_id, rank, effect)


func _on_action_phase_changed(action_id: StringName, action_instance_id: int, phase: int) -> void:
    if phase != ActionStateMachine.Phase.ACTIVE or action_instance_id <= 0:
        return
    var effect := effect_for_action(action_id)
    if effect.is_empty() or player == null or not is_instance_valid(player):
        return
    var aim := _aim_direction()
    var payload := PlayerPlaytestAttackContent.make_payload(effect)
    if class_runtime != null and class_runtime.starter_kit != null and class_runtime.starter_kit.basic_action.action_id == action_id:
        payload = class_runtime.make_basic_attack_payload()
        payload["poise_damage"] = class_runtime.starter_kit.basic_poise_damage
    elif class_runtime != null and StringName(String(effect.get("mode", &""))) != PlayerPlaytestAttackContent.MODE_WARD:
        payload["raw_damage"] = float(payload.get("raw_damage", 0.0)) + class_runtime.get_playtest_weapon_attack_bonus()
    last_started_action_id = action_id
    last_skill_movement_distance_px = 0.0
    if action_id == &"action:playtest:driving_thrust":
        last_skill_movement_distance_px = _move_player_committed(aim * float(effect.get("movement_distance_px", 0.0)))
    elif action_id == &"action:playtest:backstep_shot":
        last_skill_movement_distance_px = _move_player_committed(-aim * float(effect.get("movement_distance_px", 0.0)))
        _backstep_evade_ticks_remaining = int(effect.get("evade_window_ticks", 0))
    match StringName(String(effect.get("mode", &""))):
        PlayerPlaytestAttackContent.MODE_MELEE:
            _deliver_instant(effect, payload, player.global_position, aim, action_instance_id)
        PlayerPlaytestAttackContent.MODE_PROJECTILE:
            _spawn_projectiles(effect, payload, aim, action_instance_id)
        PlayerPlaytestAttackContent.MODE_PULSE:
            _spawn_delayed_pulse(effect, payload, aim, action_instance_id)
        PlayerPlaytestAttackContent.MODE_WARD:
            _start_ward(effect)


func _aim_direction() -> Vector2:
    var direction := Vector2.ZERO
    if class_runtime != null and class_runtime.action_state_machine != null:
        var machine := class_runtime.action_state_machine
        direction = machine.get_locked_aim_sample() if machine.has_locked_aim_sample() else machine.get_current_aim_sample()
    if not direction.is_finite() or direction.length_squared() <= 0.0001:
        direction = player.get_aim_direction() if player != null else Vector2.RIGHT
    if not direction.is_finite() or direction.length_squared() <= 0.0001:
        return Vector2.RIGHT
    return direction.normalized()


func _deliver_instant(effect: Dictionary, payload: Dictionary, origin: Vector2,
    aim: Vector2, instance_id: int, passive_origin: Vector2 = Vector2.INF) -> void:
    var limit := int(effect.get("max_targets", 1))
    var reach := float(effect.get("range_px", 0.0))
    var min_dot := cos(deg_to_rad(float(effect.get("half_angle_degrees", 0.0))))
    var candidates: Array[Dictionary] = []
    for target: Dictionary in _live_targets():
        var target_position := target.get("position", Vector2.INF) as Vector2
        var delta := target_position - origin
        if not target_position.is_finite() or delta.length_squared() > reach * reach:
            continue
        if delta.length_squared() > 0.0001 and aim.dot(delta.normalized()) < min_dot:
            continue
        if not _has_clear_contact_path(origin, target_position):
            continue
        var candidate := target.duplicate()
        candidate["distance_squared"] = delta.length_squared()
        candidates.append(candidate)
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if bool(a.get("weak_point", false)) != bool(b.get("weak_point", false)):
            return bool(a.get("weak_point", false))
        return float(a["distance_squared"]) < float(b["distance_squared"])
    )
    var hit_count := 0
    var already_hit: Dictionary = {}
    for target: Dictionary in candidates:
        if already_hit.has(StringName(String(target.get("actor_id", &"")))):
            continue
        var result := _resolve_target(target, instance_id, 0, payload,
            passive_origin if passive_origin.is_finite() else origin)
        if bool(result.get("accepted", false)):
            hit_count += 1
            already_hit[StringName(String(target.get("actor_id", &"")))] = true
        if hit_count >= limit:
            break


func _spawn_projectiles(effect: Dictionary, payload: Dictionary, aim: Vector2, instance_id: int) -> void:
    if content == null or content.projectile_placeholder_scene == null:
        return
    var count := int(effect.get("projectile_count", 1))
    var spread := float(effect.get("half_angle_degrees", 0.0))
    _spawn_projectile(effect, payload, aim.rotated(deg_to_rad(-spread)) if count > 1 else aim, instance_id, 0)
    if count > 1:
        _pending_shots.append({
            "action_instance_id": instance_id,
            "effect": effect.duplicate(true),
            "payload": payload.duplicate(true),
            "aim": aim,
            "next_index": 1,
            "ticks_until_next": int(effect.get("sequence_interval_ticks", 0)),
        })


func _spawn_projectile(effect: Dictionary, payload: Dictionary, direction: Vector2, instance_id: int, index: int) -> void:
    var visual := content.projectile_placeholder_scene.instantiate() as Node2D
    if visual == null:
        return
    add_child(visual)
    visual.global_position = player.global_position
    visual.rotation = direction.angle()
    _projectiles.append({
        "visual": visual,
        "launch_origin": player.global_position,
        "direction": direction,
        "speed": float(effect.get("projectile_speed_px_per_second", 0.0)),
        "range": float(effect.get("range_px", 0.0)),
        "remaining": projectile_max_lifetime_ticks,
        "traveled": 0.0,
        "hit_radius": float(effect.get("projectile_hit_radius_px", 0.0)),
        "max_targets": int(effect.get("max_targets", 1)),
        "hit_targets": {},
        "payload": payload.duplicate(true),
        "action_instance_id": instance_id,
        "hit_interval_index": index,
    })


func _move_player_committed(displacement: Vector2) -> float:
    if player == null or not is_instance_valid(player) or player.is_climbing() or not displacement.is_finite():
        return 0.0
    var before := player.global_position
    # The CharacterBody2D collision solver, not direct position assignment,
    # owns the authored displacement. A blocked step cannot cross world walls.
    player.move_and_collide(displacement)
    return before.distance_to(player.global_position)


func has_active_backstep_evade_window() -> bool:
    if _backstep_evade_ticks_remaining <= 0 or player == null or not is_instance_valid(player) or player.health.current_hp <= 0:
        return false
    var machine := class_runtime.action_state_machine if class_runtime != null else null
    return machine != null and machine.get_phase() == ActionStateMachine.Phase.ACTIVE and machine.get_current_action_id() == &"action:playtest:backstep_shot"


func _spawn_delayed_pulse(effect: Dictionary, payload: Dictionary, aim: Vector2, instance_id: int) -> void:
    if content == null or content.projectile_placeholder_scene == null:
        return
    var visual := content.projectile_placeholder_scene.instantiate() as Node2D
    if visual == null:
        return
    add_child(visual)
    var radius := float(effect.get("range_px", 0.0))
    visual.global_position = player.global_position + aim * radius * 0.65
    visual.scale = Vector2.ONE * maxf(1.0, radius / 5.0)
    visual.modulate = Color(0.5, 0.85, 1.0, 0.2)
    _pulses.append({
        "visual": visual,
        "launch_origin": player.global_position,
        "remaining": int(effect.get("delay_ticks", 0)),
        "effect": effect.duplicate(true),
        "payload": payload.duplicate(true),
        "action_instance_id": instance_id,
    })


func _start_ward(effect: Dictionary) -> void:
    if class_runtime == null or not class_runtime.activate_playtest_ward(int(effect.get("ward_ticks", 0))):
        return
    if _ward_marker != null and is_instance_valid(_ward_marker):
        _ward_marker.queue_free()
    _ward_marker = content.projectile_placeholder_scene.instantiate() as Node2D
    if _ward_marker != null:
        add_child(_ward_marker)
        _ward_marker.global_position = player.global_position
        _ward_marker.scale = Vector2.ONE * maxf(1.0, float(effect.get("range_px", 0.0)) / 10.0)
        _ward_marker.modulate = ward_marker_color


func _physics_process(delta: float) -> void:
    var machine := class_runtime.action_state_machine if class_runtime != null else null
    for index: int in range(_pending_shots.size() - 1, -1, -1):
        var sequence := _pending_shots[index]
        if machine == null or machine.get_phase() != ActionStateMachine.Phase.ACTIVE or machine.get_current_instance_id() != int(sequence["action_instance_id"]):
            _pending_shots.remove_at(index)
            continue
        sequence["ticks_until_next"] = int(sequence["ticks_until_next"]) - 1
        if int(sequence["ticks_until_next"]) > 0:
            continue
        var effect := sequence["effect"] as Dictionary
        var shot_index := int(sequence["next_index"])
        var count := int(effect["projectile_count"])
        var spread := float(effect["half_angle_degrees"])
        var direction := (sequence["aim"] as Vector2).rotated(deg_to_rad(lerpf(-spread, spread, float(shot_index) / float(count - 1))))
        _spawn_projectile(effect, sequence["payload"] as Dictionary, direction, int(sequence["action_instance_id"]), shot_index)
        sequence["next_index"] = shot_index + 1
        sequence["ticks_until_next"] = int(effect.get("sequence_interval_ticks", 0))
        if int(sequence["next_index"]) >= count:
            _pending_shots.remove_at(index)
    if _ward_marker != null and is_instance_valid(_ward_marker):
        if class_runtime == null or not class_runtime.has_active_playtest_ward() or player == null or not is_instance_valid(player):
            _ward_marker.queue_free()
            _ward_marker = null
        else:
            _ward_marker.global_position = player.global_position
    for index: int in range(_projectiles.size() - 1, -1, -1):
        var projectile := _projectiles[index]
        var visual := projectile.get("visual") as Node2D
        if visual == null or not is_instance_valid(visual):
            _projectiles.remove_at(index)
            continue
        var previous := visual.global_position
        var range_left := maxf(0.0, float(projectile["range"]) - float(projectile["traveled"]))
        var step := (projectile["direction"] as Vector2) * minf(float(projectile["speed"]) * delta, range_left)
        var next := previous + step
        var obstacle := _first_obstacle_on_segment(previous, next)
        if not obstacle.is_empty():
            next = obstacle.get("position", previous) as Vector2
        projectile["remaining"] = int(projectile["remaining"]) - 1
        projectile["traveled"] = float(projectile["traveled"]) + previous.distance_to(next)
        var hits := projectile["hit_targets"] as Dictionary
        var candidates: Array[Dictionary] = []
        for target: Dictionary in _live_targets():
            var target_id := StringName(String(target.get("actor_id", &"")))
            if hits.has(target_id):
                continue
            var position := target.get("position", Vector2.INF) as Vector2
            if not position.is_finite():
                continue
            var closest := Geometry2D.get_closest_point_to_segment(position, previous, next)
            if closest.distance_to(position) > float(projectile["hit_radius"]) or not _has_clear_contact_path(previous, position):
                continue
            var candidate := target.duplicate()
            candidate["distance_squared"] = previous.distance_squared_to(closest)
            candidates.append(candidate)
        candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            if bool(a.get("weak_point", false)) != bool(b.get("weak_point", false)):
                return bool(a.get("weak_point", false))
            return float(a["distance_squared"]) < float(b["distance_squared"])
        )
        for target: Dictionary in candidates:
            var target_id := StringName(String(target["actor_id"]))
            var result := _resolve_target(target, int(projectile["action_instance_id"]),
                int(projectile["hit_interval_index"]), projectile["payload"] as Dictionary,
                projectile["launch_origin"] as Vector2)
            if bool(result.get("accepted", false)):
                hits[target_id] = true
            if hits.size() >= int(projectile["max_targets"]):
                break
        visual.global_position = next
        if not obstacle.is_empty() or int(projectile["remaining"]) <= 0 or float(projectile["traveled"]) >= float(projectile["range"]) or hits.size() >= int(projectile["max_targets"]):
            visual.queue_free()
            _projectiles.remove_at(index)
    for index: int in range(_pulses.size() - 1, -1, -1):
        var pulse := _pulses[index]
        pulse["remaining"] = int(pulse["remaining"]) - 1
        if int(pulse["remaining"]) > 0:
            continue
        var pulse_visual := pulse["visual"] as Node2D
        if pulse_visual != null and is_instance_valid(pulse_visual):
            var pulse_entry := (pulse["effect"] as Dictionary).duplicate(true)
            pulse_entry["half_angle_degrees"] = 180.0
            _deliver_instant(pulse_entry, pulse["payload"] as Dictionary,
                pulse_visual.global_position, Vector2.RIGHT, int(pulse["action_instance_id"]),
                pulse["launch_origin"] as Vector2)
            pulse_visual.queue_free()
        _pulses.remove_at(index)
    if _backstep_evade_ticks_remaining > 0:
        _backstep_evade_ticks_remaining -= 1


func _live_targets() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if host != null and is_instance_valid(host):
        for encounter_id: StringName in host.get_active_encounter_ids():
            var encounter := host.get_encounter_runtime(encounter_id)
            if encounter == null or encounter.get_combatant(&"player:local") == null:
                continue
            var visuals := host.get_visuals_by_actor(encounter_id)
            for raw_id: Variant in visuals.keys():
                var actor_id := StringName(String(raw_id))
                var visual := visuals.get(raw_id) as Node2D
                var combatant := encounter.get_combatant(actor_id)
                if visual == null or not is_instance_valid(visual) or combatant == null or combatant.is_defeated():
                    continue
                result.append({
                    "encounter_id": encounter_id,
                    "actor_id": actor_id,
                    "position": visual.global_position,
                    "encounter": encounter,
                    "boss": false,
                })
    if boss_provider.is_valid():
        var raw_boss: Variant = boss_provider.call()
        if raw_boss is TenthWardenSanctum:
            var sanctum := raw_boss as TenthWardenSanctum
            if (
                is_instance_valid(sanctum) and sanctum.boss_runtime != null
                and sanctum.encounter_runtime != null and sanctum.boss_visual != null
                and sanctum.boss_runtime.evaluate_live_outcome() == TenthWardenEncounterState.OUTCOME_ONGOING
            ):
                result.append({
                    "encounter_id": sanctum.encounter_id,
                    "actor_id": sanctum.boss_runtime.boss_id,
                    "position": sanctum.boss_visual.global_position,
                    "encounter": sanctum.encounter_runtime,
                    "boss": true,
                    "sanctum": sanctum,
                })
                var weak_position := sanctum.get_exposed_weak_point_position()
                if weak_position.is_finite():
                    result.append({
                        "encounter_id": sanctum.encounter_id,
                        "actor_id": sanctum.boss_runtime.boss_id,
                        "position": weak_position,
                        "encounter": sanctum.encounter_runtime,
                        "boss": true,
                        "weak_point": true,
                        "sanctum": sanctum,
                    })
    if region3_side_target_provider.is_valid():
        var side_targets: Variant = region3_side_target_provider.call()
        if side_targets is Array:
            for raw_target: Variant in side_targets as Array:
                if raw_target is Dictionary:
                    result.append((raw_target as Dictionary).duplicate())
    return result


func _resolve_target(target: Dictionary, instance_id: int, hit_index: int, payload: Dictionary,
    passive_origin: Vector2 = Vector2.INF) -> Dictionary:
    var encounter_id := StringName(String(target.get("encounter_id", &"")))
    var actor_id := StringName(String(target.get("actor_id", &"")))
    var encounter := target.get("encounter") as CombatEncounterRuntime
    if encounter == null or encounter.get_combatant(actor_id) == null:
        return {"accepted": false, "reason_id": &"target_unavailable"}
    var resolved: Dictionary
    var target_payload := payload.duplicate(true)
    if bool(target.get("boss", false)):
        var sanctum := target.get("sanctum") as TenthWardenSanctum
        if sanctum == null or not is_instance_valid(sanctum) or sanctum.boss_runtime == null:
            return {"accepted": false, "reason_id": &"boss_unavailable"}
        if bool(target.get("weak_point", false)):
            if not sanctum.get_exposed_weak_point_position().is_finite():
                return {"accepted": false, "reason_id": &"weak_point_window_closed"}
            target_payload["weak_point_triggered"] = true
            target_payload["weak_point_multiplier"] = sanctum.weak_point_damage_multiplier
    if passive_skill_runtime != null and passive_skill_runtime.has_method("modify_attack_payload"):
        var origin := passive_origin if passive_origin.is_finite() else (
            player.global_position if player != null and is_instance_valid(player) else Vector2.INF)
        var target_position := target.get("position", Vector2.INF) as Vector2
        if origin.is_finite() and target_position.is_finite():
            var modified: Variant = passive_skill_runtime.call("modify_attack_payload", target_payload, origin, target_position,
                bool(target_payload.get("weak_point_triggered", false)))
            if modified is Dictionary:
                target_payload = modified as Dictionary
    if bool(target.get("boss", false)):
        resolved = (target.get("sanctum") as TenthWardenSanctum).boss_runtime.resolve_player_contact(instance_id, hit_index, target_payload)
    else:
        resolved = encounter.resolve_direct_contact(&"player:local", actor_id, instance_id, hit_index,
            target_payload, false, DirectHitResolver.DEFENSE_NONE, false)
    # Shared contact admission is the sole gate: a rejected, dodged, blocked,
    # parried or already-fatal contact must never grant a second poise strike.
    if bool(resolved.get("accepted", false)) and not encounter.get_combatant(actor_id).is_defeated() \
        and StringName(resolved.get("outcome", &"")) in [DirectHitResolver.OUTCOME_HIT, DirectHitResolver.OUTCOME_GUARD_BROKEN]:
        var poise_amount := float(target_payload.get("poise_damage", 0.0))
        if is_finite(poise_amount) and poise_amount > 0.0:
            resolved["poise_result"] = encounter.apply_poise_to_target(actor_id, poise_amount)
    last_contact_result = resolved.duplicate(true)
    last_contact_result["target_id"] = actor_id
    last_contact_result["encounter_id"] = encounter_id
    playtest_contact_resolved.emit(encounter_id, actor_id, last_contact_result.duplicate(true))
    return resolved


func _has_clear_contact_path(origin: Vector2, destination: Vector2) -> bool:
    if not origin.is_finite() or not destination.is_finite():
        return false
    if origin.distance_squared_to(destination) <= 0.0001:
        return true
    return _first_obstacle_on_segment(origin, destination).is_empty()


func _first_obstacle_on_segment(origin: Vector2, destination: Vector2) -> Dictionary:
    if origin.distance_squared_to(destination) <= 0.0001:
        return {}
    var ray := PhysicsRayQueryParameters2D.create(origin, destination, 1)
    if player != null and is_instance_valid(player):
        ray.exclude = [player.get_rid()]
    ray.collide_with_areas = false
    ray.collide_with_bodies = true
    return get_world_2d().direct_space_state.intersect_ray(ray)


func _exit_tree() -> void:
    _clear_effects()
    var machine := class_runtime.action_state_machine if class_runtime != null else null
    if machine != null and is_instance_valid(machine) and machine.phase_changed.is_connected(_on_action_phase_changed):
        machine.phase_changed.disconnect(_on_action_phase_changed)


func _clear_effects() -> void:
    _backstep_evade_ticks_remaining = 0
    if _ward_marker != null and is_instance_valid(_ward_marker):
        _ward_marker.queue_free()
    _ward_marker = null
    for projectile: Dictionary in _projectiles:
        var visual := projectile.get("visual") as Node2D
        if visual != null and is_instance_valid(visual):
            visual.queue_free()
    for pulse: Dictionary in _pulses:
        var visual := pulse.get("visual") as Node2D
        if visual != null and is_instance_valid(visual):
            visual.queue_free()
    _projectiles.clear()
    _pending_shots.clear()
    _pulses.clear()
