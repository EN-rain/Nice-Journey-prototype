class_name EnemyPlaytestAttackCatalog
extends Resource

@export var playtest_placeholder: bool = true
@export var attack_by_archetype: Dictionary = {}
@export var balance_evidence_reference: String = ""
# Ally-ward, reinforcement-call, and slow-field signatures are not damage
# attacks; never invent physical hits to mark their authoring complete.
@export var deferred_non_damage_archetypes: Array[StringName] = []


func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("temporary enemy attacks must remain flagged playtest")
    var non_damage: Array[StringName] = [&"support", &"summoner", &"controller_disruptor"]
    var deferred_seen := {}
    for archetype_id: StringName in deferred_non_damage_archetypes:
        if not non_damage.has(archetype_id):
            errors.append("only approved non-damage signatures may be deferred: %s" % String(archetype_id))
        if deferred_seen.has(archetype_id):
            errors.append("duplicate non-damage signature deferment: %s" % String(archetype_id))
        deferred_seen[archetype_id] = true
    for archetype_id: StringName in non_damage:
        if not deferred_seen.has(archetype_id):
            errors.append("non-damage signature must remain explicitly deferred: %s" % String(archetype_id))
    var seen: Dictionary = {}
    for raw_id: Variant in attack_by_archetype.keys():
        var archetype_id := StringName(String(raw_id))
        if not EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS.has(archetype_id):
            errors.append("unapproved enemy archetype: %s" % String(archetype_id))
            continue
        if seen.has(archetype_id):
            errors.append("duplicate canonical enemy archetype attack: %s" % String(archetype_id))
            continue
        seen[archetype_id] = true
        if non_damage.has(archetype_id):
            errors.append("non-damage signature cannot author a direct hit: %s" % String(archetype_id))
            continue
        var attack: Variant = attack_by_archetype[raw_id]
        if not attack is EnemySignatureAttackAuthoring:
            errors.append("invalid attack for %s" % String(archetype_id))
            continue
        var definition := EnemyArchetypeCatalog.get_definition(archetype_id)
        if definition == null or (attack as EnemySignatureAttackAuthoring).action_id != definition.signature_action_id:
            errors.append("signature action mismatch for %s" % String(archetype_id))
        for error: String in (attack as EnemySignatureAttackAuthoring).validate_authoring():
            errors.append("%s: %s" % [String(archetype_id), error])
        if (attack as EnemySignatureAttackAuthoring).payload != null and (attack as EnemySignatureAttackAuthoring).payload.raw_damage <= 0.0:
            errors.append("damage signature requires positive raw damage: %s" % String(archetype_id))
        var authored := attack as EnemySignatureAttackAuthoring
        if authored.geometry != null:
            var timing := EnemySignatureActionTimingCatalog.get_timing(archetype_id)
            for error: String in authored.geometry.validate_live_delivery(int(timing.get("active_ticks", 0))):
                errors.append("%s live geometry: %s" % [String(archetype_id), error])
            # EnemyPlaytestLiveDelivery currently emits one attack contact at
            # ACTIVE entry; accepting other ticks would advertise nonexistent hits.
            if authored.geometry.hit_interval_count != 1 or authored.geometry.hit_active_ticks != PackedInt32Array([0]):
                errors.append("%s live delivery supports one hit at ACTIVE tick zero" % String(archetype_id))
            if authored.geometry.query_shape != null:
                var bounds := authored.geometry.query_shape.get_rect()
                if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
                    errors.append("%s query shape requires finite positive bounds" % String(archetype_id))
        if authored.payload != null:
            var requires_projectile := archetype_id in [&"marksman", &"mobile_ranged", &"caster"]
            var expected := DirectHitResolver.DELIVERY_PROJECTILE if requires_projectile else DirectHitResolver.DELIVERY_CONTACT
            if authored.payload.delivery != expected:
                errors.append("%s delivery must match the current live signature role" % String(archetype_id))
    for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        if not seen.has(archetype_id) and not deferred_non_damage_archetypes.has(archetype_id):
            errors.append("missing playtest attack or explicit non-damage deferment for %s" % String(archetype_id))
        if seen.has(archetype_id) and deferred_non_damage_archetypes.has(archetype_id):
            errors.append("archetype cannot be an attack and deferred: %s" % String(archetype_id))
    return errors


func attack_for(archetype_id: StringName) -> EnemySignatureAttackAuthoring:
    if not validate_catalog().is_empty():
        return null
    var entry: Variant = attack_by_archetype.get(String(archetype_id), null)
    return (entry as EnemySignatureAttackAuthoring).duplicate(true) as EnemySignatureAttackAuthoring if entry is EnemySignatureAttackAuthoring else null


func production_readiness_errors() -> PackedStringArray:
    var errors := validate_catalog()
    if playtest_placeholder:
        errors.append("enemy attack geometry, damage and action timing remain PLAYTEST")
    if balance_evidence_reference.strip_edges().is_empty():
        errors.append("approved enemy attack balance/contact evidence reference is missing")
    for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        if not deferred_non_damage_archetypes.has(archetype_id):
            var attack := attack_for(archetype_id)
            if attack != null and attack.geometry != null and String(attack.geometry.geometry_id).begins_with("geometry:playtest:"):
                errors.append("%s geometry is provisional" % String(archetype_id))
    return errors
