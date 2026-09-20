class_name EnemySignatureActionTimingCatalog
extends RefCounted

# Reversible initial playtest tuning. These values define clocks only; attack geometry,
# displacement, damage and telegraph shape remain owned by their authoritative systems.
const _TIMINGS: Dictionary = {
    &"duelist": {"windup_ticks": 18, "active_ticks": 5, "recovery_ticks": 20, "cooldown_ticks": 45},
    &"bruiser": {"windup_ticks": 28, "active_ticks": 7, "recovery_ticks": 28, "cooldown_ticks": 60},
    &"defender": {"windup_ticks": 22, "active_ticks": 5, "recovery_ticks": 24, "cooldown_ticks": 55},
    &"skirmisher": {"windup_ticks": 14, "active_ticks": 4, "recovery_ticks": 18, "cooldown_ticks": 40},
    &"assassin": {"windup_ticks": 20, "active_ticks": 4, "recovery_ticks": 24, "cooldown_ticks": 60},
    &"marksman": {"windup_ticks": 30, "active_ticks": 3, "recovery_ticks": 22, "cooldown_ticks": 55},
    &"mobile_ranged": {"windup_ticks": 20, "active_ticks": 3, "recovery_ticks": 18, "cooldown_ticks": 45},
    &"caster": {"windup_ticks": 36, "active_ticks": 6, "recovery_ticks": 28, "cooldown_ticks": 65},
    &"support": {"windup_ticks": 24, "active_ticks": 4, "recovery_ticks": 24, "cooldown_ticks": 60},
    &"summoner": {"windup_ticks": 42, "active_ticks": 6, "recovery_ticks": 32, "cooldown_ticks": 90},
    &"flying_harrier": {"windup_ticks": 20, "active_ticks": 5, "recovery_ticks": 24, "cooldown_ticks": 55},
    &"controller_disruptor": {"windup_ticks": 32, "active_ticks": 8, "recovery_ticks": 26, "cooldown_ticks": 70},
}

static func get_timing(archetype_id: StringName) -> Dictionary:
    var raw: Variant = _TIMINGS.get(archetype_id, null)
    if not raw is Dictionary:
        return {}
    return (raw as Dictionary).duplicate(true)

static func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        var timing := get_timing(archetype_id)
        if timing.is_empty():
            errors.append("missing signature timing for %s" % String(archetype_id))
            continue
        for key: String in ["windup_ticks", "active_ticks", "recovery_ticks", "cooldown_ticks"]:
            var value: Variant = timing.get(key, null)
            if typeof(value) != TYPE_INT or int(value) < 0:
                errors.append("%s %s must be a nonnegative integer" % [String(archetype_id), key])
        if int(timing.get("windup_ticks", 0)) <= 0 or int(timing.get("active_ticks", 0)) <= 0:
            errors.append("%s requires observable windup and active phases" % String(archetype_id))
    for raw_id: Variant in _TIMINGS.keys():
        var archetype_id := StringName(String(raw_id))
        if not EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS.has(archetype_id):
            errors.append("timing catalog contains unknown archetype %s" % String(archetype_id))
    return errors
