class_name SkillCatalog
extends RefCounted

const ACTIVE_IDS_BY_CLASS: Dictionary = {
    &"melee": [&"arc_cleave", &"driving_thrust", &"riposte"],
    &"ranged": [&"piercing_shot", &"fan_shot", &"backstep_shot"],
    &"mage": [&"arcane_lance", &"delayed_pulse", &"aegis_ward"],
}

const PASSIVE_IDS_BY_CLASS: Dictionary = {
    &"melee": [&"efficient_footwork", &"breaker", &"parry_recovery"],
    &"ranged": [&"longshot", &"fleet_recovery", &"expose"],
    &"mage": [&"mana_weave", &"flow_recovery", &"stable_casting"],
}

const STARTING_ACTIVE_IDS_BY_CLASS: Dictionary = {
    &"melee": [&"arc_cleave", &"driving_thrust"],
    &"ranged": [&"piercing_shot", &"fan_shot"],
    &"mage": [&"arcane_lance", &"delayed_pulse"],
}

const STARTING_PASSIVE_IDS_BY_CLASS: Dictionary = {
    &"melee": [&"efficient_footwork", &"breaker"],
    &"ranged": [&"longshot", &"fleet_recovery"],
    &"mage": [&"mana_weave", &"flow_recovery"],
}


static func all_definitions() -> Array[SkillDefinition]:
    return [
        _make(&"arc_cleave", &"melee", SkillDefinition.KIND_ACTIVE, "Arc Cleave", &"wide_committed_melee_sweep", true, &"stamina"),
        _make(&"driving_thrust", &"melee", SkillDefinition.KIND_ACTIVE, "Driving Thrust", &"advancing_narrow_melee_strike", true, &"stamina"),
        _make(&"riposte", &"melee", SkillDefinition.KIND_ACTIVE, "Riposte", &"supported_parry_counter", false, &"stamina", &"successful_parry"),
        _make(&"efficient_footwork", &"melee", SkillDefinition.KIND_PASSIVE, "Efficient Footwork", &"stamina_efficiency", true),
        _make(&"breaker", &"melee", SkillDefinition.KIND_PASSIVE, "Breaker", &"poise_pressure_bonus", true),
        _make(&"parry_recovery", &"melee", SkillDefinition.KIND_PASSIVE, "Parry Recovery", &"parry_recovery_benefit", false),

        _make(&"piercing_shot", &"ranged", SkillDefinition.KIND_ACTIVE, "Piercing Shot", &"committed_piercing_line_projectile", true, &"stamina"),
        _make(&"fan_shot", &"ranged", SkillDefinition.KIND_ACTIVE, "Fan Shot", &"short_spread_projectile_sequence", true, &"stamina"),
        _make(&"backstep_shot", &"ranged", SkillDefinition.KIND_ACTIVE, "Backstep Shot", &"evasive_backstep_committed_shot", false, &"stamina"),
        _make(&"longshot", &"ranged", SkillDefinition.KIND_PASSIVE, "Longshot", &"long_range_effectiveness_bonus", true),
        _make(&"fleet_recovery", &"ranged", SkillDefinition.KIND_PASSIVE, "Fleet Recovery", &"movement_recovery_efficiency", true),
        _make(&"expose", &"ranged", SkillDefinition.KIND_PASSIVE, "Expose", &"visible_weak_point_payoff_bonus", false),

        _make(&"arcane_lance", &"mage", SkillDefinition.KIND_ACTIVE, "Arcane Lance", &"focused_arcane_projectile", true, &"mana"),
        _make(&"delayed_pulse", &"mage", SkillDefinition.KIND_ACTIVE, "Delayed Pulse", &"telegraphed_delayed_arcane_area_hit", true, &"mana"),
        _make(&"aegis_ward", &"mage", SkillDefinition.KIND_ACTIVE, "Aegis Ward", &"mana_block_window_without_parry", false, &"mana"),
        _make(&"mana_weave", &"mage", SkillDefinition.KIND_PASSIVE, "Mana Weave", &"mana_cost_efficiency", true),
        _make(&"flow_recovery", &"mage", SkillDefinition.KIND_PASSIVE, "Flow Recovery", &"mana_recovery_efficiency", true),
        _make(&"stable_casting", &"mage", SkillDefinition.KIND_PASSIVE, "Stable Casting", &"casting_recovery_efficiency", false),
    ]


static func get_definition(skill_id: StringName) -> SkillDefinition:
    for definition: SkillDefinition in all_definitions():
        if definition.skill_id == skill_id:
            return definition
    return null


static func definitions_for_class(class_id: StringName) -> Array[SkillDefinition]:
    var result: Array[SkillDefinition] = []
    for definition: SkillDefinition in all_definitions():
        if definition.class_id == class_id:
            result.append(definition)
    return result


static func validate_catalog() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    var seen: Dictionary = {}
    var definitions: Array[SkillDefinition] = all_definitions()
    if definitions.size() != 18:
        errors.append("prototype skill catalog must contain exactly 18 definitions")
    for definition: SkillDefinition in definitions:
        for definition_error: String in definition.validate_definition():
            errors.append("%s: %s" % [String(definition.skill_id), definition_error])
        if seen.has(definition.skill_id):
            errors.append("duplicate skill_id: %s" % String(definition.skill_id))
        seen[definition.skill_id] = true
    for class_id: StringName in [&"melee", &"ranged", &"mage"]:
        var class_definitions: Array[SkillDefinition] = definitions_for_class(class_id)
        var active_count: int = 0
        var passive_count: int = 0
        var starting_active_count: int = 0
        var starting_passive_count: int = 0
        for definition: SkillDefinition in class_definitions:
            if definition.kind == SkillDefinition.KIND_ACTIVE:
                active_count += 1
                if definition.starting_grant:
                    starting_active_count += 1
            elif definition.kind == SkillDefinition.KIND_PASSIVE:
                passive_count += 1
                if definition.starting_grant:
                    starting_passive_count += 1
        if class_definitions.size() != 6 or active_count != 3 or passive_count != 3:
            errors.append("%s must define exactly three active and three passive skills" % String(class_id))
        if starting_active_count != 2 or starting_passive_count != 2:
            errors.append("%s must start with exactly two active and two passive skills" % String(class_id))
        var expected_active: Array = ACTIVE_IDS_BY_CLASS[class_id]
        var expected_passive: Array = PASSIVE_IDS_BY_CLASS[class_id]
        for skill_id: StringName in expected_active + expected_passive:
            if not seen.has(skill_id):
                errors.append("missing locked skill_id: %s" % String(skill_id))
    return errors


static func _make(
    skill_id: StringName,
    class_id: StringName,
    kind: StringName,
    display_name: String,
    mechanic_id: StringName,
    starting_grant: bool,
    cost_resource: StringName = &"",
    prerequisite_event_id: StringName = &""
) -> SkillDefinition:
    var definition: SkillDefinition = SkillDefinition.new()
    definition.skill_id = skill_id
    definition.class_id = class_id
    definition.kind = kind
    definition.display_name = display_name
    definition.mechanic_id = mechanic_id
    definition.starting_grant = starting_grant
    definition.max_rank = 3
    definition.cost_resource = cost_resource
    definition.prerequisite_event_id = prerequisite_event_id
    return definition
