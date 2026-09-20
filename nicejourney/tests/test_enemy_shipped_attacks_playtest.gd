extends SceneTree

const ATTACKS: EnemyPlaytestAttackCatalog = preload("res://src/data/tuning/enemy_attacks_playtest_v01.tres")
const DEFERRED: Array[StringName] = [&"support", &"summoner", &"controller_disruptor"]
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _expect(ATTACKS != null and ATTACKS.playtest_placeholder and ATTACKS.validate_catalog().is_empty(), "shipped enemy attack catalog validates and explicitly remains playtest")
    _expect(ATTACKS.attack_by_archetype.size() == 9 and ATTACKS.deferred_non_damage_archetypes.size() == 3, "nine offensive archetypes have authored temporary attack data, three non-damage signatures stay deferred")
    for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        var definition := EnemyArchetypeCatalog.get_definition(archetype_id)
        _expect(definition != null and definition.validate_definition().is_empty(), "%s preserves canonical archetype authority" % String(archetype_id))
        if definition == null:
            continue
        if DEFERRED.has(archetype_id):
            _expect(definition.signature_attack_authoring == null, "%s is not wrongly converted into a raw damaging attack" % String(archetype_id))
            continue
        _expect(definition.signature_attack_authoring == null, "%s canonical archetype stays independent of provisional combat tuning" % String(archetype_id))
        var authored := ATTACKS.attack_for(archetype_id)
        definition.signature_attack_authoring = authored
        _expect(authored != null and definition.validate_signature_attack_authoring().is_empty(), "%s ships validated provisional signature payload and geometry" % String(archetype_id))
        if authored != null:
            _expect(authored.action_id == definition.signature_action_id and authored.geometry.hit_interval_count == 1, "%s is tied to its canonical signature and explicit hit identity" % String(archetype_id))
            _expect(authored.geometry.max_reach_px > 0.0 and authored.geometry.collision_mask == 1 and authored.geometry.live_placement_declared, "%s has finite shape/reach/mask/placement authoring" % String(archetype_id))
            if authored.payload.delivery == DirectHitResolver.DELIVERY_PROJECTILE:
                _expect(not authored.payload.parryable and authored.payload.dodgeable, "%s playtest projectile remains dodgeable but non-parryable" % String(archetype_id))
    if _failures == 0:
        print("ENEMY SHIPPED ATTACKS PLAYTEST TEST PASS")
    else:
        push_error("ENEMY SHIPPED ATTACKS PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(ok: bool, name: String) -> void:
    if ok:
        print("PASS: %s" % name)
        return
    _failures += 1
    push_error("FAIL: %s" % name)
