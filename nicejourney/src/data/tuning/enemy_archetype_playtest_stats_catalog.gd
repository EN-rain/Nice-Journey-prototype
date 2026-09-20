class_name EnemyArchetypePlaytestStatsCatalog
extends Resource

@export var playtest_placeholder: bool = true
@export var stats_by_archetype: Dictionary = {}


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
