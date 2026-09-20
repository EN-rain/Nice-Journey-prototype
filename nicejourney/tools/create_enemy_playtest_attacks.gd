extends SceneTree

const OUTPUT := "res://src/data/tuning/enemy_attacks_playtest_v01.tres"
const NON_DAMAGE: Array[StringName] = [&"support", &"summoner", &"controller_disruptor"]


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var catalog := EnemyPlaytestAttackCatalog.new()
    catalog.resource_name = "PLAYTEST enemy signature contact v01 — temporary shapes/damage"
    catalog.playtest_placeholder = true
    catalog.deferred_non_damage_archetypes = NON_DAMAGE.duplicate()
    var index := 0
    for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        if NON_DAMAGE.has(archetype_id):
            continue
        var definition := EnemyArchetypeCatalog.get_definition(archetype_id)
        if definition == null:
            quit(1)
            return
        var projectile := definition.preferred_range == EnemyArchetypeDefinition.RANGE_LONG or archetype_id in [&"marksman", &"mobile_ranged"]
        var arcane := archetype_id == &"caster"
        var geometry := EnemyAttackGeometryAuthoring.new()
        geometry.authored = true
        geometry.geometry_id = StringName("geometry:playtest:%s" % String(archetype_id))
        var shape := RectangleShape2D.new()
        shape.size = Vector2(126, 46) if projectile else (Vector2(100, 94) if archetype_id == &"bruiser" else Vector2(74, 58))
        geometry.query_shape = shape
        geometry.max_reach_px = 120.0 if projectile else 76.0
        geometry.collision_mask = 1
        geometry.hit_interval_count = 1
        geometry.live_placement_declared = true
        geometry.local_offset = Vector2.ZERO
        geometry.local_rotation_radians = 0.0
        geometry.hit_active_ticks = PackedInt32Array([0])

        var payload := EnemyAttackPayloadAuthoring.new()
        payload.authored = true
        payload.damage_domain = DirectHitResolver.DOMAIN_ARCANE if arcane else DirectHitResolver.DOMAIN_PHYSICAL
        payload.delivery = DirectHitResolver.DELIVERY_PROJECTILE if projectile else DirectHitResolver.DELIVERY_CONTACT
        payload.raw_damage = 5.0 + float(index)
        payload.guard_pressure = 2.0 if projectile else 3.0
        payload.dodgeable = true
        payload.blockable = true
        payload.parryable = not projectile
        payload.critical_multiplier = 1.0
        payload.weak_point_multiplier = 1.0
        var attack := EnemySignatureAttackAuthoring.new()
        attack.action_id = definition.signature_action_id
        attack.geometry = geometry
        attack.payload = payload
        catalog.attack_by_archetype[String(archetype_id)] = attack
        index += 1
    var errors := catalog.validate_catalog()
    if not errors.is_empty():
        push_error("Enemy playtest attacks invalid: %s" % str(errors))
        quit(1)
        return
    var code := ResourceSaver.save(catalog, OUTPUT)
    print("ENEMY PLAYTEST ATTACKS: %d" % code)
    quit(0 if code == OK else 1)
