class_name EnemyArchetypeCatalog
extends RefCounted

const FIRST_SLICE_IDS: Array[StringName] = [
    &"duelist",
    &"bruiser",
    &"defender",
    &"marksman",
]

const REMAINING_SLICE_IDS: Array[StringName] = [
    &"skirmisher",
    &"assassin",
    &"mobile_ranged",
    &"caster",
    &"support",
    &"summoner",
    &"flying_harrier",
    &"controller_disruptor",
]

const ALL_ARCHETYPE_IDS: Array[StringName] = [
    &"duelist",
    &"bruiser",
    &"defender",
    &"skirmisher",
    &"assassin",
    &"marksman",
    &"mobile_ranged",
    &"caster",
    &"support",
    &"summoner",
    &"flying_harrier",
    &"controller_disruptor",
]


static func first_slice_definitions() -> Array[EnemyArchetypeDefinition]:
    return [
        _make(
            &"duelist",
            "Duelist",
            EnemyArchetypeDefinition.RANGE_CLOSE,
            [&"cue:player_commit_observed", &"cue:player_recovery_observed", &"cue:distance_changed"],
            &"action:duelist_lunge",
            &"recovery:duelist_lunge",
            [&"limit:single_parry_window", &"limit:no_projectile_parry"],
            [&"counter:outspace_lunge", &"counter:bait_parry", &"counter:punish_recovery"],
            &"group_role:single_target_pressure",
            &"objective:contest_nearest_hostile",
            [&"variant:timing", &"variant:guarded"],
            [&"tactic:hold_observe", &"tactic:approach", &"tactic:reposition_last_known", &"tactic:contest_objective", &"action:duelist_lunge"]
        ),
        _make(
            &"bruiser",
            "Bruiser",
            EnemyArchetypeDefinition.RANGE_CLOSE,
            [&"cue:player_close_observed", &"cue:player_recovery_observed", &"cue:objective_contested"],
            &"action:bruiser_slam",
            &"recovery:bruiser_slam",
            [&"limit:slow_turn_during_commit", &"limit:no_parry_during_slam"],
            [&"counter:dodge_slam", &"counter:punish_heavy_recovery", &"counter:maintain_spacing"],
            &"group_role:space_denial",
            &"objective:pressure_contested_zone",
            [&"variant:armor", &"variant:timing"],
            [&"tactic:hold_observe", &"tactic:approach", &"tactic:reposition_last_known", &"tactic:contest_objective", &"action:bruiser_slam"]
        ),
        _make(
            &"defender",
            "Defender",
            EnemyArchetypeDefinition.RANGE_MID,
            [&"cue:ally_threatened_observed", &"cue:player_commit_observed", &"cue:objective_contested"],
            &"action:defender_guard_counter",
            &"recovery:defender_counter",
            [&"limit:frontal_guard_only", &"limit:guard_pressure_breakable"],
            [&"counter:flank_guard", &"counter:guard_pressure", &"counter:draw_counter_then_recover"],
            &"group_role:ally_screen",
            &"objective:hold_objective_frontage",
            [&"variant:shield", &"variant:counter_timing"],
            [&"tactic:hold_observe", &"tactic:approach", &"tactic:withdraw", &"tactic:reposition_last_known", &"tactic:contest_objective", &"action:defender_guard_counter"]
        ),
        _make(
            &"marksman",
            "Marksman",
            EnemyArchetypeDefinition.RANGE_LONG,
            [&"cue:line_of_sight_observed", &"cue:player_commit_observed", &"cue:distance_changed"],
            &"action:marksman_aimed_shot",
            &"recovery:marksman_shot",
            [&"limit:requires_observed_line_of_sight", &"limit:aim_locks_before_active"],
            [&"counter:break_line_of_sight", &"counter:dodge_after_telegraph", &"counter:close_distance"],
            &"group_role:ranged_lane_pressure",
            &"objective:cover_objective_lane",
            [&"variant:shot_timing", &"variant:lane_choice"],
            [&"tactic:hold_observe", &"tactic:withdraw", &"tactic:reposition_last_known", &"tactic:contest_objective", &"action:marksman_aimed_shot"]
        ),
    ]


static func remaining_slice_definitions() -> Array[EnemyArchetypeDefinition]:
    return [
        _make(
            &"skirmisher",
            "Skirmisher",
            EnemyArchetypeDefinition.RANGE_CLOSE,
            [&"cue:distance_changed", &"cue:player_commit_observed", &"cue:flank_lane_observed"],
            &"action:skirmisher_dash_cut",
            &"recovery:skirmisher_dash_cut",
            [&"limit:no_block_during_dash", &"limit:bounded_dodge_frequency"],
            [&"counter:deny_flank", &"counter:track_dash_entry", &"counter:punish_dash_recovery"],
            &"group_role:mobile_flank_pressure",
            &"objective:rotate_objective_edge",
            [&"variant:dash_timing", &"variant:weapon"],
            [&"tactic:hold_observe", &"tactic:approach", &"tactic:reposition_last_known", &"tactic:contest_objective", &"action:skirmisher_dash_cut"]
        ),
        _make(
            &"assassin",
            "Assassin",
            EnemyArchetypeDefinition.RANGE_CLOSE,
            [&"cue:player_recovery_observed", &"cue:player_commit_observed", &"cue:flank_lane_observed"],
            &"action:assassin_flank_strike",
            &"recovery:assassin_flank_strike",
            [&"limit:requires_observed_flank", &"limit:fragile_during_recovery"],
            [&"counter:face_assassin", &"counter:deny_flank", &"counter:punish_burst_recovery"],
            &"group_role:single_target_burst",
            &"objective:pressure_objective_edge",
            [&"variant:entry_timing", &"variant:feint"],
            [&"tactic:hold_observe", &"tactic:approach", &"tactic:withdraw", &"tactic:reposition_last_known", &"tactic:contest_objective", &"action:assassin_flank_strike"]
        ),
        _make(
            &"mobile_ranged",
            "Mobile Ranged",
            EnemyArchetypeDefinition.RANGE_MID,
            [&"cue:line_of_sight_observed", &"cue:distance_changed", &"cue:player_commit_observed"],
            &"action:mobile_ranged_strafe_shot",
            &"recovery:mobile_ranged_strafe_shot",
            [&"limit:aim_locks_before_active", &"limit:bounded_reposition_between_shots"],
            [&"counter:close_distance", &"counter:break_line_of_sight", &"counter:dodge_projectile_lane"],
            &"group_role:mobile_ranged_pressure",
            &"objective:rotate_objective_lane",
            [&"variant:strafe_side", &"variant:shot_timing"],
            [&"tactic:hold_observe", &"tactic:approach", &"tactic:withdraw", &"tactic:reposition_last_known", &"tactic:contest_objective", &"action:mobile_ranged_strafe_shot"]
        ),
        _make(
            &"caster",
            "Caster",
            EnemyArchetypeDefinition.RANGE_LONG,
            [&"cue:line_of_sight_observed", &"cue:player_commit_observed", &"cue:objective_contested"],
            &"action:caster_delayed_burst",
            &"recovery:caster_delayed_burst",
            [&"limit:cast_commits_before_active", &"limit:telegraph_required"],
            [&"counter:leave_cast_zone", &"counter:close_distance", &"counter:punish_cast_recovery"],
            &"group_role:ranged_area_pressure",
            &"objective:control_objective_zone",
            [&"variant:zone_shape", &"variant:cast_timing"],
            [&"tactic:hold_observe", &"tactic:withdraw", &"tactic:reposition_last_known", &"tactic:contest_objective", &"action:caster_delayed_burst"]
        ),
        _make(
            &"support",
            "Support",
            EnemyArchetypeDefinition.RANGE_MID,
            [&"cue:ally_threatened_observed", &"cue:objective_contested", &"cue:player_commit_observed"],
            &"action:support_ally_ward",
            &"recovery:support_ally_ward",
            [&"limit:requires_observed_ally", &"limit:no_self_chain_ward"],
            [&"counter:separate_support_target", &"counter:pressure_support", &"counter:punish_support_recovery"],
            &"group_role:ally_support",
            &"objective:support_contested_objective",
            [&"variant:ward_timing", &"variant:support_target"],
            [&"tactic:hold_observe", &"tactic:approach", &"tactic:withdraw", &"tactic:reposition_last_known", &"tactic:contest_objective", &"action:support_ally_ward"]
        ),
        _make(
            &"summoner",
            "Summoner",
            EnemyArchetypeDefinition.RANGE_LONG,
            [&"cue:reinforcement_budget_observed", &"cue:objective_contested", &"cue:player_commit_observed"],
            &"action:summoner_reinforcement_call",
            &"recovery:summoner_reinforcement_call",
            [&"limit:finite_reinforcement_budget", &"limit:full_ai_cap_required", &"limit:summon_commit_interruptible"],
            [&"counter:interrupt_summon_commit", &"counter:pressure_summoner", &"counter:deny_reinforcement_space"],
            &"group_role:bounded_reinforcement_controller",
            &"objective:reinforce_contested_objective",
            [&"variant:reinforcement_timing", &"variant:reinforcement_role"],
            [&"tactic:hold_observe", &"tactic:withdraw", &"tactic:reposition_last_known", &"tactic:contest_objective", &"action:summoner_reinforcement_call"]
        ),
        _make(
            &"flying_harrier",
            "Flying Harrier",
            EnemyArchetypeDefinition.RANGE_MID,
            [&"cue:targeting_window_observed", &"cue:distance_changed", &"cue:player_commit_observed"],
            &"action:flying_harrier_dive",
            &"recovery:flying_harrier_dive",
            [&"limit:visible_targeting_required", &"limit:grounded_recovery_window", &"limit:starter_class_hits_required"],
            [&"counter:bait_dive", &"counter:punish_grounded_recovery", &"counter:ranged_intercept"],
            &"group_role:mobile_harassment",
            &"objective:contest_objective_perimeter",
            [&"variant:dive_timing", &"variant:flight_lane"],
            [&"tactic:hold_observe", &"tactic:approach", &"tactic:withdraw", &"tactic:reposition_last_known", &"tactic:contest_objective", &"action:flying_harrier_dive"]
        ),
        _make(
            &"controller_disruptor",
            "Controller / Disruptor",
            EnemyArchetypeDefinition.RANGE_MID,
            [&"cue:objective_contested", &"cue:player_commit_observed", &"cue:route_congestion_observed"],
            &"action:controller_slow_field",
            &"recovery:controller_slow_field",
            [&"limit:telegraphed_control_zone", &"limit:bounded_disable_duration", &"limit:no_hidden_input_read"],
            [&"counter:leave_control_zone", &"counter:pressure_controller", &"counter:avoid_chokepoint"],
            &"group_role:control_space",
            &"objective:deny_objective_route",
            [&"variant:zone_placement", &"variant:control_timing"],
            [&"tactic:hold_observe", &"tactic:approach", &"tactic:withdraw", &"tactic:reposition_last_known", &"tactic:contest_objective", &"action:controller_slow_field"]
        ),
    ]


static func all_definitions() -> Array[EnemyArchetypeDefinition]:
    var result: Array[EnemyArchetypeDefinition] = first_slice_definitions()
    result.append_array(remaining_slice_definitions())
    return result


static func get_first_slice(archetype_id: StringName) -> EnemyArchetypeDefinition:
    for definition: EnemyArchetypeDefinition in first_slice_definitions():
        if definition.archetype_id == archetype_id:
            return definition
    return null


static func get_definition(archetype_id: StringName) -> EnemyArchetypeDefinition:
    for definition: EnemyArchetypeDefinition in all_definitions():
        if definition.archetype_id == archetype_id:
            return definition
    return null


static func validate_first_slice() -> PackedStringArray:
    return _validate_slice(first_slice_definitions(), FIRST_SLICE_IDS, "first production enemy slice")


static func validate_remaining_slice() -> PackedStringArray:
    var errors: PackedStringArray = _validate_slice(remaining_slice_definitions(), REMAINING_SLICE_IDS, "remaining production enemy slice")
    var summoner: EnemyArchetypeDefinition = get_definition(&"summoner")
    if summoner == null or not summoner.defensive_limit_ids.has(&"limit:finite_reinforcement_budget") or not summoner.defensive_limit_ids.has(&"limit:full_ai_cap_required"):
        errors.append("Summoner must declare bounded reinforcement budget and FULL-AI cap compliance")
    var flying: EnemyArchetypeDefinition = get_definition(&"flying_harrier")
    if flying == null or not flying.defensive_limit_ids.has(&"limit:visible_targeting_required") or not flying.defensive_limit_ids.has(&"limit:starter_class_hits_required"):
        errors.append("Flying Harrier must preserve visible targeting and starter-class hit access")
    return errors


static func validate_catalog() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    errors.append_array(validate_first_slice())
    errors.append_array(validate_remaining_slice())
    var definitions: Array[EnemyArchetypeDefinition] = all_definitions()
    if definitions.size() != 12:
        errors.append("prototype catalog must contain exactly twelve reusable archetypes")
    var seen: Dictionary = {}
    for definition: EnemyArchetypeDefinition in definitions:
        if seen.has(definition.archetype_id):
            errors.append("duplicate archetype_id across catalog: %s" % String(definition.archetype_id))
        seen[definition.archetype_id] = true
    for required_id: StringName in ALL_ARCHETYPE_IDS:
        if not seen.has(required_id):
            errors.append("missing prototype archetype: %s" % String(required_id))
    return errors


static func _validate_slice(definitions: Array[EnemyArchetypeDefinition], required_ids: Array[StringName], label: String) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if definitions.size() != required_ids.size():
        errors.append("%s must contain exactly %d archetypes" % [label, required_ids.size()])
    var seen: Dictionary = {}
    for definition: EnemyArchetypeDefinition in definitions:
        for definition_error: String in definition.validate_definition():
            errors.append("%s: %s" % [String(definition.archetype_id), definition_error])
        if seen.has(definition.archetype_id):
            errors.append("duplicate archetype_id: %s" % String(definition.archetype_id))
        seen[definition.archetype_id] = true
        if not definition.tactic_ids.has(definition.signature_action_id):
            errors.append("%s signature action must be eligible as a tactic" % String(definition.archetype_id))
        if not definition.tactic_ids.has(&"tactic:hold_observe"):
            errors.append("%s must retain a non-committing observation tactic" % String(definition.archetype_id))
    for required_id: StringName in required_ids:
        if not seen.has(required_id):
            errors.append("missing archetype: %s" % String(required_id))
    return errors


static func _make(
    archetype_id: StringName,
    role_name: String,
    preferred_range: StringName,
    observable_trigger_ids: Array[StringName],
    signature_action_id: StringName,
    recovery_window_id: StringName,
    defensive_limit_ids: Array[StringName],
    counterplay_ids: Array[StringName],
    group_role_id: StringName,
    objective_behavior_id: StringName,
    allowed_variant_ids: Array[StringName],
    tactic_ids: Array[StringName]
) -> EnemyArchetypeDefinition:
    var definition: EnemyArchetypeDefinition = EnemyArchetypeDefinition.new()
    definition.archetype_id = archetype_id
    definition.role_name = role_name
    definition.preferred_range = preferred_range
    definition.observable_trigger_ids = observable_trigger_ids.duplicate()
    definition.signature_action_id = signature_action_id
    definition.recovery_window_id = recovery_window_id
    definition.defensive_limit_ids = defensive_limit_ids.duplicate()
    definition.counterplay_ids = counterplay_ids.duplicate()
    definition.group_role_id = group_role_id
    definition.objective_behavior_id = objective_behavior_id
    definition.allowed_variant_ids = allowed_variant_ids.duplicate()
    definition.tactic_ids = tactic_ids.duplicate()
    return definition
