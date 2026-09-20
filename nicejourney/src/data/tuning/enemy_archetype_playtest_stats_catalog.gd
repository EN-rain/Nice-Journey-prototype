class_name EnemyArchetypePlaytestStatsCatalog
extends Resource

@export var playtest_placeholder: bool = true
@export var stats_by_archetype: Dictionary = {}
@export var balance_evidence_reference: String = ""


func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("temporary enemy archetype stats must remain marked PLAYTEST")
    var seen := {}
    for raw_id: Variant in stats_by_archetype.keys():
        var archetype_id := StringName(String(raw_id))
        if not EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS.has(archetype_id):
            errors.append("unapproved archetype stats key: %s" % String(archetype_id))
            continue
        if seen.has(archetype_id):
            errors.append("duplicate canonical archetype stats key: %s" % String(archetype_id))
            continue
        seen[archetype_id] = true
        var value: Variant = stats_by_archetype[raw_id]
        if not value is EnemyArchetypePlaytestStats:
            errors.append("missing or invalid stats for %s" % String(archetype_id))
            continue
        var stats := value as EnemyArchetypePlaytestStats
        if stats.archetype_id != archetype_id:
            errors.append("archetype stats identity mismatch for %s" % String(archetype_id))
        for error: String in stats.validate_authoring():
            errors.append("%s: %s" % [String(archetype_id), error])
    for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        if not seen.has(archetype_id):
            errors.append("missing archetype stats: %s" % String(archetype_id))
    return errors


func stats_for(archetype_id: StringName) -> EnemyArchetypePlaytestStats:
    if not validate_catalog().is_empty():
        return null
    var value: Variant = stats_by_archetype.get(String(archetype_id), null)
    return (value as EnemyArchetypePlaytestStats).duplicate(true) as EnemyArchetypePlaytestStats if value is EnemyArchetypePlaytestStats else null


# A separate diagnostic from valid PLAYTEST runtime data: do not silently
# promote twelve neutral role profiles or fabricate difficulty/reward authority.
func production_readiness_errors() -> PackedStringArray:
    var errors := validate_catalog()
    if playtest_placeholder:
        errors.append("enemy role stats remain PLAYTEST")
    if balance_evidence_reference.strip_edges().is_empty():
        errors.append("approved per-role balance evidence reference is missing")
    var distinct_profiles := {}
    for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        var stats := stats_for(archetype_id)
        if stats == null:
            continue
        var profile := [stats.hp_multiplier, stats.stamina_bonus, stats.physical_defense_bonus,
            stats.arcane_defense_bonus, stats.poise_multiplier]
        distinct_profiles[str(profile)] = true
        if stats.difficulty_rating == -1:
            errors.append("%s difficulty is unauthored" % String(archetype_id))
        if stats.xp_reward == -1 or stats.gold_reward == -1:
            errors.append("%s encounter reward policy is unauthored (do not grant rewards)" % String(archetype_id))
    if distinct_profiles.size() < 2:
        errors.append("all enemy roles still share one neutral stat profile")
    return errors
