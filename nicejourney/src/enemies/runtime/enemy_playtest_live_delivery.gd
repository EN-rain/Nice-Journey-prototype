class_name EnemyPlaytestLiveDelivery
extends Node2D

# Optional runtime geometry owner: active windows alone are NEVER a hit.
# Physics-verified contacts are passed through the existing encounter executor.
signal playtest_enemy_contact_resolved(encounter_id: StringName, actor_id: StringName, result: Dictionary)
signal successful_player_parry(encounter_id: StringName, actor_id: StringName)

@export var playtest_placeholder: bool = true
@export var projectile_placeholder_scene: PackedScene
@export_range(1.0, 2000.0, 0.1) var projectile_speed_px_per_second: float = 270.0
@export_range(1, 600, 1) var projectile_lifetime_ticks: int = 120
@export var player_hit_center_offset: Vector2 = Vector2(0, -5)

var player: PlayerController = null
var class_runtime: ClassCombatRuntime = null
var host: TowerEncounterSessionHost = null
var region3_host: Region3SideQuestRuntime = null
var defender_provider: PlayerDefenderFactsProvider = PlayerDefenderFactsProvider.new()
var last_delivery_result: Dictionary = {}
var _projectiles: Array[Dictionary] = []


func configure(source_player: PlayerController, source_class_runtime: ClassCombatRuntime,
    source_host: TowerEncounterSessionHost, defender_tuning: PlayerDefenderFactsTuning) -> bool:
    if (
        not playtest_placeholder or projectile_placeholder_scene == null
        or not is_finite(projectile_speed_px_per_second) or projectile_speed_px_per_second <= 0.0
        or projectile_lifetime_ticks <= 0 or not player_hit_center_offset.is_finite()
        or source_player == null or source_class_runtime == null or source_host == null
        or not defender_provider.configure(source_player, source_class_runtime, defender_tuning).is_empty()
    ):
        return false
    _disconnect_host(host)
    _clear_projectiles()
    player = source_player
    class_runtime = source_class_runtime
    host = source_host
    host.enemy_active_delivery_window_opened.connect(_on_active_window.bind(host))
    host.encounter_ended.connect(_on_encounter_ended.bind(host))
    return true


func set_region3_host(source_region3_host: Region3SideQuestRuntime) -> void:
    if region3_host == source_region3_host:
        return
    _disconnect_host(region3_host)
    _clear_projectiles(region3_host)
    region3_host = source_region3_host
    if region3_host != null and is_instance_valid(region3_host):
        region3_host.enemy_active_delivery_window_opened.connect(_on_active_window.bind(region3_host))
        region3_host.encounter_ended.connect(_on_encounter_ended.bind(region3_host))


func _on_active_window(encounter_id: StringName, context: Dictionary, emitter: Variant = null) -> void:
    var source: Variant = _source_for_encounter(encounter_id)
    if source == null or (emitter != null and source != emitter) or player == null or not bool(context.get("accepted", false)):
        return
    if StringName(String(context.get("encounter_id", &""))) != encounter_id:
        return
    var actor_id := StringName(String(context.get("actor_id", &"")))
    var runtime: EnemyArchetypeRuntime = source.get_archetype_runtime(encounter_id, actor_id)
    var executor: EnemyActiveAttackDeliveryExecutor = source.get_attack_delivery_executor(encounter_id, actor_id)
    var visual := source.get_visuals_by_actor(encounter_id).get(actor_id) as Node2D
    if runtime == null or executor == null or visual == null or not is_instance_valid(visual):
        return
    if runtime.definition == null or not runtime.definition.validate_signature_attack_authoring().is_empty():
        return
    var authoring := runtime.definition.signature_attack_authoring
    var geometry := authoring.geometry
    if geometry == null or authoring.payload == null:
        return
    var driver: EnemySignatureActionPhaseDriver = source.get_action_phase_driver(encounter_id, actor_id)
    if driver == null or not geometry.validate_live_delivery(int(driver.timing.get("active_ticks", 0))).is_empty():
        return
    # A host signal is an announcement, not authority to replay or retarget an
    # attack. Check the live reservation and the original observed aim again.
    var current := runtime.get_active_delivery_context(int(context.get("action_instance_id", -1)))
    if (not bool(current.get("accepted", false))
        or driver.action_instance_id != int(context.get("action_instance_id", -1))
        or current.get("reservation_token") != context.get("reservation_token")
        or current.get("action_id") != context.get("action_id")
        or current.get("target_id") != context.get("target_id")
        or current.get("has_committed_observation_position") != context.get("has_committed_observation_position")
        or current.get("committed_observation_position") != context.get("committed_observation_position")):
        return
    var raw_target: Variant = context.get("committed_observation_position", null)
    if not bool(context.get("has_committed_observation_position", false)) or not raw_target is Vector2 or not (raw_target as Vector2).is_finite():
        return
    var origin := visual.global_position
    var direction := (raw_target as Vector2) - origin
    if not origin.is_finite() or direction.length_squared() <= 0.0001:
        return
    direction = direction.normalized()
    var instance_id := int(context.get("action_instance_id", -1))
    if authoring.payload.delivery == DirectHitResolver.DELIVERY_PROJECTILE:
        _spawn_projectile(encounter_id, actor_id, instance_id, origin, direction, geometry, executor, source)
        return
    if origin.distance_to(player.global_position) > geometry.max_reach_px:
        return
    var shape_query := PhysicsShapeQueryParameters2D.new()
    shape_query.shape = geometry.query_shape
    shape_query.transform = geometry.live_query_transform(Transform2D(direction.angle(), origin))
    shape_query.collision_mask = geometry.collision_mask
    shape_query.collide_with_areas = false
    shape_query.collide_with_bodies = true
    var contacts := get_world_2d().direct_space_state.intersect_shape(shape_query, 32)
    for contact: Dictionary in contacts:
        if contact.get("collider") == player:
            _confirm_player_contact(encounter_id, actor_id, instance_id, 0, geometry.geometry_id, executor, origin, source)
            return


func _spawn_projectile(encounter_id: StringName, actor_id: StringName, instance_id: int,
    origin: Vector2, direction: Vector2, geometry: EnemyAttackGeometryAuthoring,
    executor: EnemyActiveAttackDeliveryExecutor, source: Variant) -> void:
    var ticket := executor.authorize_projectile_launch(instance_id, geometry.geometry_id)
    if ticket <= 0:
        return
    var marker := projectile_placeholder_scene.instantiate() as Node2D
    if marker == null:
        executor.release_projectile_launch(ticket)
        return
    add_child(marker)
    marker.global_position = geometry.live_query_transform(Transform2D(direction.angle(), origin)).origin
    marker.rotation = direction.angle()
    marker.modulate = Color(1.0, 0.35, 0.32, 0.9)
    _projectiles.append({
        "visual": marker,
        "encounter_id": encounter_id,
        "actor_id": actor_id,
        "action_instance_id": instance_id,
        "launch_ticket": ticket,
        "direction": direction,
        "traveled": 0.0,
        "max_reach": geometry.max_reach_px,
        "remaining": projectile_lifetime_ticks,
        "geometry_id": geometry.geometry_id,
        "collision_mask": geometry.collision_mask,
        "executor": executor,
        "source": source,
    })


func _physics_process(delta: float) -> void:
    for index: int in range(_projectiles.size() - 1, -1, -1):
        var projectile := _projectiles[index] as Dictionary
        var marker := projectile.get("visual") as Node2D
        if marker == null or not is_instance_valid(marker):
            _release_projectile_ticket(projectile)
            _projectiles.remove_at(index)
            continue
        var encounter_id := StringName(String(projectile["encounter_id"]))
        var actor_id := StringName(String(projectile["actor_id"]))
        var source: Variant = _source_for_encounter(encounter_id)
        if source == null or source != projectile.get("source"):
            _release_projectile_ticket(projectile)
            marker.queue_free()
            _projectiles.remove_at(index)
            continue
        var origin := marker.global_position
        var direction := projectile["direction"] as Vector2
        var step := direction * projectile_speed_px_per_second * delta
        var destination := origin + step
        var ray := PhysicsRayQueryParameters2D.create(origin, destination, int(projectile["collision_mask"]))
        ray.collide_with_areas = false
        ray.collide_with_bodies = true
        var collision := get_world_2d().direct_space_state.intersect_ray(ray)
        if not collision.is_empty():
            if collision.get("collider") == player:
                _confirm_player_contact(encounter_id, actor_id, int(projectile["action_instance_id"]),
                    0, StringName(String(projectile["geometry_id"])),
                    projectile["executor"] as EnemyActiveAttackDeliveryExecutor,
                    origin, source, int(projectile["launch_ticket"]))
            _release_projectile_ticket(projectile)
            marker.queue_free()
            _projectiles.remove_at(index)
            continue
        marker.global_position = destination
        projectile["traveled"] = float(projectile["traveled"]) + step.length()
        projectile["remaining"] = int(projectile["remaining"]) - 1
        if float(projectile["traveled"]) >= float(projectile["max_reach"]) or int(projectile["remaining"]) <= 0:
            _release_projectile_ticket(projectile)
            marker.queue_free()
            _projectiles.remove_at(index)


func _confirm_player_contact(encounter_id: StringName, actor_id: StringName,
    action_instance_id: int, hit_interval_index: int, geometry_id: StringName,
    executor: EnemyActiveAttackDeliveryExecutor, origin: Vector2, expected_source: Variant = null,
    launch_ticket: int = 0) -> Dictionary:
    if executor == null or player == null or not defender_provider.is_configured():
        return {"accepted": false, "reason_id": &"playtest_defender_unavailable"}
    var source: Variant = _source_for_encounter(encounter_id)
    if source == null or (expected_source != null and source != expected_source):
        return {"accepted": false, "reason_id": &"playtest_encounter_unavailable"}
    var current: EnemyArchetypeRuntime = source.get_archetype_runtime(encounter_id, actor_id)
    if current == null or current.definition == null or source.get_attack_delivery_executor(encounter_id, actor_id) != executor:
        return {"accepted": false, "reason_id": &"playtest_attacker_unavailable"}
    var defender_facts := defender_provider.make_snapshot(origin, player.global_position)
    if defender_facts.is_empty():
        return {"accepted": false, "reason_id": &"playtest_defender_facts_unavailable"}
    var contact := {
        "actor_id": actor_id,
        "target_id": current.target_id,
        "action_id": current.definition.signature_action_id,
        "action_instance_id": action_instance_id,
        "hit_interval_index": hit_interval_index,
        "geometry_id": geometry_id,
        "contact_confirmed": true,
        "critical_triggered": false,
        "weak_point_triggered": false,
    }
    # Aegis Ward is a temporary magic block, not permanent mage shield
    # equipment. Give the live combatant permission for this contact only.
    var encounter: CombatEncounterRuntime = source.get_encounter_runtime(encounter_id)
    var player_state := encounter.get_combatant(current.target_id) if encounter != null else null
    var base_block_supported := player_state.block_supported if player_state != null else false
    if player_state != null and bool(defender_facts.get("playtest_ward_active", false)):
        player_state.block_supported = true
    var result := executor.resolve_launched_projectile_impact(
        launch_ticket, geometry_id, bool(defender_facts["evade_window_active"]),
        StringName(String(defender_facts["defense_mode"])), bool(defender_facts["facing_covered"])) if launch_ticket > 0 else executor.resolve_authored_contact(
        contact, bool(defender_facts["evade_window_active"]),
        StringName(String(defender_facts["defense_mode"])), bool(defender_facts["facing_covered"]))
    if player_state != null:
        player_state.block_supported = base_block_supported
    last_delivery_result = result.duplicate(true)
    last_delivery_result["encounter_id"] = encounter_id
    last_delivery_result["actor_id"] = actor_id
    playtest_enemy_contact_resolved.emit(encounter_id, actor_id, last_delivery_result.duplicate(true))
    if bool(result.get("accepted", false)) and result.get("outcome", &"") == DirectHitResolver.OUTCOME_PARRIED:
        successful_player_parry.emit(encounter_id, actor_id)
    return result


func _source_for_encounter(encounter_id: StringName) -> Variant:
    var tower_active := host != null and is_instance_valid(host) and host.is_encounter_active(encounter_id)
    var region_active := region3_host != null and is_instance_valid(region3_host) and region3_host.is_encounter_active(encounter_id)
    if tower_active == region_active:
        return null
    return host if tower_active else region3_host


func _disconnect_host(source: Variant) -> void:
    if source == null or not is_instance_valid(source):
        return
    var callback := _on_active_window.bind(source)
    if source.enemy_active_delivery_window_opened.is_connected(callback):
        source.enemy_active_delivery_window_opened.disconnect(callback)
    var ended_callback := _on_encounter_ended.bind(source)
    if source.encounter_ended.is_connected(ended_callback):
        source.encounter_ended.disconnect(ended_callback)


func _on_encounter_ended(encounter_id: StringName, source: Variant) -> void:
    _clear_projectiles(source, encounter_id)


func _clear_projectiles(source: Variant = null, encounter_id: StringName = &"") -> void:
    for entry: Dictionary in _projectiles:
        if source != null and (entry.get("source") != source or (encounter_id != &"" and entry.get("encounter_id") != encounter_id)):
            continue
        _release_projectile_ticket(entry)
        var marker := entry.get("visual") as Node2D
        if marker != null and is_instance_valid(marker):
            marker.queue_free()
    if source == null:
        _projectiles.clear()
    else:
        _projectiles = _projectiles.filter(func(entry: Dictionary) -> bool:
            return entry.get("source") != source or (encounter_id != &"" and entry.get("encounter_id") != encounter_id))


func _release_projectile_ticket(entry: Dictionary) -> void:
    var executor := entry.get("executor") as EnemyActiveAttackDeliveryExecutor
    if executor != null:
        executor.release_projectile_launch(int(entry.get("launch_ticket", 0)))


func _exit_tree() -> void:
    _disconnect_host(host)
    _disconnect_host(region3_host)
    _clear_projectiles()
