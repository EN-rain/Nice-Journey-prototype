extends SceneTree

const SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const ATTACKS: EnemyPlaytestAttackCatalog = preload("res://src/data/tuning/enemy_attacks_playtest_v01.tres")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _expect(ATTACKS != null and ATTACKS.playtest_placeholder and ATTACKS.validate_catalog().is_empty(), "explicit per-archetype playtest attack manifest validates")
    _expect(ATTACKS.attack_by_archetype.size() == 9 and ATTACKS.deferred_non_damage_archetypes.size() == 3, "nine damage signatures have authored payload/geometry; three non-damage signatures are deliberately not misrepresented as hits")
    for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        var attack := ATTACKS.attack_for(archetype_id)
        if ATTACKS.deferred_non_damage_archetypes.has(archetype_id):
            _expect(attack == null, "non-damage signature %s has no invented damaging contact" % String(archetype_id))
            continue
        var definition := EnemyArchetypeCatalog.get_definition(archetype_id)
        _expect(attack != null and definition != null and attack.action_id == definition.signature_action_id and attack.validate_authoring().is_empty(), "%s has its approved action ID, usable temporary hit geometry and combat payload" % String(archetype_id))
        if attack != null:
            _expect(attack.geometry.collision_mask == 1 and attack.geometry.hit_interval_count == 1 and attack.payload.raw_damage > 0.0, "%s declares collision target, exact contact count and numeric damage" % String(archetype_id))
    var gameplay := SCENE.instantiate() as GameplayRoot
    _expect(gameplay.enemy_playtest_attacks == ATTACKS, "shipped scene explicitly assigns reusable enemy playtest attacks")
    gameplay.set_profile(ProfileCreationService.create_profile(1, "Enemy Playtest", "melee"))
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.tower_encounter_session_host.playtest_attack_catalog == ATTACKS, "live Tower encounter host receives the validated attack resource")
    gameplay.queue_free()
    await process_frame
    if _failures == 0:
        print("ENEMY SHIPPED PLAYTEST ATTACKS TEST PASS")
    else:
        push_error("ENEMY SHIPPED PLAYTEST ATTACKS TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, name: String) -> void:
    if ok:
        print("PASS: %s" % name)
        return
    _failures += 1
    push_error("FAIL: %s" % name)
