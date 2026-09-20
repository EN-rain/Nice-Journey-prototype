class_name ActiveSkillProductionAuthority
extends RefCounted

const COMMON_ACTION_TUNING_FIELDS = [
    "action_id",
    "eligible_states",
    "startup_ticks",
    "commit_ticks",
    "active_ticks",
    "recovery_ticks",
    "cooldown_ticks",
    "buffer_lifetime_ticks",
    "resource_cost_amount",
    "rank_scaling_by_rank",
    "movement_rules",
    "aim_and_lock_rules",
    "cancel_rules",
    "forced_interruption_rules",
    "cue_event_identities_and_feedback_alignment",
]

const COMMON_ATTACK_FIELDS = [
    "target_mask",
    "raw_damage",
    "damage_tags",
    "contact_count",
    "hit_geometry_or_reach",
    "dodgeable",
    "blockable",
    "critical_configuration",
    "weak_point_interaction",
    "guard_pressure",
    "poise_damage",
    "knockback_effect",
    "status_application",
]

const PROJECTILE_FIELDS = [
    "projectile_speed",
    "projectile_range_or_lifetime",
    "projectile_collision_geometry",
    "projectile_count",
    "projectile_hit_policy",
    "projectile_cleanup_policy",
    "projectile_concurrency_cap_or_budget",
]

const PROGRESSION_SEMANTICS = {
    "maximum_rank": 3,
    "rank_one_unlocks_or_activates": true,
    "skill_point_cost_per_rank": 1,
    "rank_two_three_change_scope": ["magnitude", "cost", "recovery"],
    "rank_up_cannot_change_skill_identity": true,
    "equipped_active_slot_count": 2,
    "loadout_changes_require_safe_town_or_rest_out_of_combat": true,
    "progression_spending_is_permanent": true,
    "prototype_respec_allowed": false,
}

const _RECORDS = {
    &"arc_cleave": {
        "mechanic_id": &"wide_committed_melee_sweep",
        "resource_id": &"stamina",
        "prerequisite_event_id": &"",
        "known_semantics": {
            "committed": true,
            "delivery_family": &"melee",
            "shape_family": &"wide_sweep",
        },
        "additional_missing_fields": ["damage_domain", "parryable"],
    },
    &"driving_thrust": {
        "mechanic_id": &"advancing_narrow_melee_strike",
        "resource_id": &"stamina",
        "prerequisite_event_id": &"",
        "known_semantics": {
            "committed": true,
            "delivery_family": &"melee",
            "shape_family": &"narrow_strike",
            "authored_advancing_movement": true,
        },
        "additional_missing_fields": ["damage_domain", "parryable", "advance_distance_and_motion_profile"],
    },
    &"riposte": {
        "mechanic_id": &"supported_parry_counter",
        "resource_id": &"stamina",
        "prerequisite_event_id": &"successful_parry",
        "known_semantics": {
            "delivery_family": &"counter",
            "requires_successful_supported_parry": true,
            "supported_parry_only": true,
        },
        "additional_missing_fields": ["damage_domain", "parryable", "successful_parry_event_lifetime"],
    },
    &"piercing_shot": {
        "mechanic_id": &"committed_piercing_line_projectile",
        "resource_id": &"stamina",
        "prerequisite_event_id": &"",
        "known_semantics": {
            "committed": true,
            "delivery_family": &"projectile",
            "shape_family": &"line",
            "may_pierce_authored_targets": true,
            "parryable": false,
        },
        "additional_missing_fields": ["damage_domain", "pierce_limit_or_target_rule"],
    },
    &"fan_shot": {
        "mechanic_id": &"short_spread_projectile_sequence",
        "resource_id": &"stamina",
        "prerequisite_event_id": &"",
        "known_semantics": {
            "delivery_family": &"projectile",
            "shape_family": &"spread_sequence",
            "sequence": true,
            "parryable": false,
        },
        "additional_missing_fields": ["damage_domain", "spread_geometry", "sequence_count_and_cadence"],
    },
    &"backstep_shot": {
        "mechanic_id": &"evasive_backstep_committed_shot",
        "resource_id": &"stamina",
        "prerequisite_event_id": &"",
        "known_semantics": {
            "committed": true,
            "delivery_family": &"projectile",
            "authored_evasive_movement": true,
            "parryable": false,
        },
        "additional_missing_fields": ["damage_domain", "backstep_distance_and_motion_profile", "evade_window_ticks"],
    },
    &"arcane_lance": {
        "mechanic_id": &"focused_arcane_projectile",
        "resource_id": &"mana",
        "prerequisite_event_id": &"",
        "known_semantics": {
            "delivery_family": &"projectile",
            "damage_domain": &"arcane",
            "focused_projectile": true,
            "parryable": false,
        },
        "additional_missing_fields": [],
    },
    &"delayed_pulse": {
        "mechanic_id": &"telegraphed_delayed_arcane_area_hit",
        "resource_id": &"mana",
        "prerequisite_event_id": &"",
        "known_semantics": {
            "delivery_family": &"delayed_area_hit",
            "telegraphed": true,
        },
        "additional_missing_fields": ["damage_domain", "delay_ticks", "area_geometry", "parryable"],
    },
    &"aegis_ward": {
        "mechanic_id": &"mana_block_window_without_parry",
        "resource_id": &"mana",
        "prerequisite_event_id": &"",
        "known_semantics": {
            "delivery_family": &"defensive_window",
            "uses_dr06_block_style_semantics": true,
            "brief_defensive_window": true,
            "mana_spending": true,
            "parryable_defense": false,
        },
        "additional_missing_fields": ["ward_coverage", "ward_absorption_resource_semantics", "guard_break_interaction"],
        "non_attack": true,
    },
}


static func readiness(skill_id: StringName) -> Dictionary:
    var definition := SkillCatalog.get_definition(skill_id)
    if definition == null or definition.kind != SkillDefinition.KIND_ACTIVE:
        return {
            "accepted": false,
            "skill_id": skill_id,
            "production_ready": false,
            "known_semantics": {},
            "missing_authoritative_fields": PackedStringArray(),
            "errors": PackedStringArray(["skill_id must identify an approved active skill"]),
        }
    if not _RECORDS.has(skill_id):
        return {
            "accepted": false,
            "skill_id": skill_id,
            "production_ready": false,
            "known_semantics": {},
            "missing_authoritative_fields": PackedStringArray(),
            "errors": PackedStringArray(["approved active skill has no production authority record"]),
        }

    var record := (_RECORDS[skill_id] as Dictionary).duplicate(true)
    var errors := PackedStringArray()
    if StringName(record.get("mechanic_id", &"")) != definition.mechanic_id:
        errors.append("production authority mechanic_id must match SkillCatalog")
    if StringName(record.get("resource_id", &"")) != definition.cost_resource:
        errors.append("production authority resource_id must match SkillCatalog")
    if StringName(record.get("prerequisite_event_id", &"")) != definition.prerequisite_event_id:
        errors.append("production authority prerequisite_event_id must match SkillCatalog")

    var missing := PackedStringArray()
    missing.append_array(COMMON_ACTION_TUNING_FIELDS)
    if not bool(record.get("non_attack", false)):
        missing.append_array(COMMON_ATTACK_FIELDS)
        var known_semantics := record.get("known_semantics", {}) as Dictionary
        if StringName(known_semantics.get("delivery_family", &"")) == &"projectile":
            missing.append_array(PROJECTILE_FIELDS)
    for value: Variant in record.get("additional_missing_fields", []) as Array:
        missing.append(String(value))
    missing = _deduplicate(missing)

    var known_semantics := (record.get("known_semantics", {}) as Dictionary).duplicate(true)
    known_semantics["resource_spending_required"] = definition.cost_resource != &""
    known_semantics["rank_progression"] = PROGRESSION_SEMANTICS.duplicate(true)
    return {
        "accepted": errors.is_empty(),
        "skill_id": skill_id,
        "class_id": definition.class_id,
        "display_name": definition.display_name,
        "starting_grant": definition.starting_grant,
        "mechanic_id": definition.mechanic_id,
        "resource_id": definition.cost_resource,
        "prerequisite_event_id": definition.prerequisite_event_id,
        "known_semantics": known_semantics,
        "production_ready": errors.is_empty() and missing.is_empty(),
        "missing_authoritative_fields": missing,
        "errors": errors,
    }


static func catalog_readiness() -> Dictionary:
    var entries: Array[Dictionary] = []
    var ready_count := 0
    var missing_by_skill: Dictionary = {}
    var errors := validate_catalog_alignment()
    for class_id: StringName in [&"melee", &"ranged", &"mage"]:
        for skill_id: StringName in SkillCatalog.ACTIVE_IDS_BY_CLASS[class_id]:
            var entry := readiness(skill_id)
            entries.append(entry.duplicate(true))
            if bool(entry.get("production_ready", false)):
                ready_count += 1
            else:
                missing_by_skill[String(skill_id)] = (
                    entry.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray
                ).duplicate()
    return {
        "accepted": errors.is_empty(),
        "production_ready": errors.is_empty() and ready_count == 9,
        "approved_active_count": entries.size(),
        "production_ready_count": ready_count,
        "entries": entries,
        "missing_by_skill": missing_by_skill,
        "errors": errors.duplicate(),
    }


static func validate_action_contract(skill_id: StringName, action: ActionDefinition) -> PackedStringArray:
    var errors := PackedStringArray()
    var authority := readiness(skill_id)
    if not bool(authority.get("accepted", false)):
        errors.append("skill_id must identify an approved active skill")
        return errors
    if action == null:
        errors.append("production active skill requires an ActionDefinition")
        return errors
    for error: String in action.validate_definition():
        errors.append(error)
    if not StableId.is_valid(String(action.action_id)):
        errors.append("production action_id must be a stable ID")
    var mechanic_id := StringName(authority.get("mechanic_id", &""))
    for error: String in action.validate_production_skill_authoring(mechanic_id):
        errors.append(error)
    var resource_id := StringName(authority.get("resource_id", &""))
    if action.cost_resource != resource_id:
        errors.append("production action cost_resource must match the approved skill resource")
    if resource_id != &"" and action.cost_amount <= 0.0:
        errors.append("approved resource-spending active skill requires a positive authored cost_amount")
    return _deduplicate(errors)


static func readiness_for_mechanic(mechanic_id: StringName) -> Dictionary:
    for skill_id: StringName in SkillCatalog.ACTIVE_IDS_BY_CLASS[&"melee"] + SkillCatalog.ACTIVE_IDS_BY_CLASS[&"ranged"] + SkillCatalog.ACTIVE_IDS_BY_CLASS[&"mage"]:
        var definition := SkillCatalog.get_definition(skill_id)
        if definition != null and definition.mechanic_id == mechanic_id:
            return readiness(skill_id)
    return {
        "accepted": false,
        "skill_id": &"",
        "mechanic_id": mechanic_id,
        "production_ready": false,
        "known_semantics": {},
        "missing_authoritative_fields": PackedStringArray(),
        "errors": PackedStringArray(["mechanic_id does not identify an approved active skill"]),
    }


static func validate_catalog_alignment() -> PackedStringArray:
    var errors := PackedStringArray()
    var active_ids: Array[StringName] = []
    for class_id: StringName in [&"melee", &"ranged", &"mage"]:
        for skill_id: StringName in SkillCatalog.ACTIVE_IDS_BY_CLASS[class_id]:
            active_ids.append(skill_id)
            var result := readiness(skill_id)
            if not bool(result.get("accepted", false)):
                for error: String in result.get("errors", PackedStringArray()) as PackedStringArray:
                    errors.append("%s: %s" % [String(skill_id), error])
    if active_ids.size() != 9:
        errors.append("production authority expects exactly nine approved active skills")
    for raw_skill_id: Variant in _RECORDS.keys():
        var skill_id := StringName(String(raw_skill_id))
        if not active_ids.has(skill_id):
            errors.append("production authority contains unknown active skill %s" % String(skill_id))
    return errors


static func _deduplicate(values: PackedStringArray) -> PackedStringArray:
    var result := PackedStringArray()
    var seen: Dictionary = {}
    for value: String in values:
        if seen.has(value):
            continue
        seen[value] = true
        result.append(value)
    return result
