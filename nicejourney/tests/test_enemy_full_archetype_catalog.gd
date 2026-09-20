extends SceneTree

var failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var errors: PackedStringArray = EnemyArchetypeCatalog.validate_catalog()
    _expect(errors.is_empty(), "complete 12-archetype threat-card catalog validates")
    if not errors.is_empty():
        push_error("catalog errors: %s" % ", ".join(errors))

    var definitions: Array[EnemyArchetypeDefinition] = EnemyArchetypeCatalog.all_definitions()
    _expect(definitions.size() == 12, "prototype catalog contains exactly twelve reusable archetypes")

    var seen: Dictionary = {}
    for definition: EnemyArchetypeDefinition in definitions:
        _expect(definition != null and definition.validate_definition().is_empty(), "%s threat card is structurally valid" % String(definition.archetype_id))
        _expect(not seen.has(definition.archetype_id), "%s appears exactly once" % String(definition.archetype_id))
        seen[definition.archetype_id] = true
        _expect(definition.tactic_ids.has(definition.signature_action_id), "%s signature commitment is an authored tactic" % String(definition.archetype_id))
        _expect(definition.tactic_ids.has(&"tactic:hold_observe"), "%s retains a fair non-committing observation option" % String(definition.archetype_id))
        _expect(not definition.counterplay_ids.is_empty(), "%s exposes declared counterplay" % String(definition.archetype_id))
        _expect(not definition.defensive_limit_ids.is_empty(), "%s exposes declared defensive/action limits" % String(definition.archetype_id))

    for required_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        _expect(seen.has(required_id), "catalog contains locked archetype %s" % String(required_id))
        _expect(EnemyArchetypeCatalog.get_definition(required_id) != null, "catalog lookup resolves %s" % String(required_id))

    _test_remaining_contracts()
    _test_selector_compatibility()

    if failures == 0:
        print("ENEMY FULL ARCHETYPE CATALOG TEST PASS")
    else:
        push_error("ENEMY FULL ARCHETYPE CATALOG TEST FAILURES: %d" % failures)
    quit(failures)

func _test_remaining_contracts() -> void:
    var skirmisher := EnemyArchetypeCatalog.get_definition(&"skirmisher")
    _expect(skirmisher != null and skirmisher.signature_action_id == &"action:skirmisher_dash_cut", "Skirmisher owns a readable committed mobility strike")
    _expect(skirmisher != null and skirmisher.counterplay_ids.has(&"counter:punish_dash_recovery"), "Skirmisher exposes punishable dash recovery")

    var assassin := EnemyArchetypeCatalog.get_definition(&"assassin")
    _expect(assassin != null and assassin.signature_action_id == &"action:assassin_flank_strike", "Assassin uses observable flank commitment instead of hidden omniscient damage")
    _expect(assassin != null and assassin.defensive_limit_ids.has(&"limit:requires_observed_flank"), "Assassin flank pressure requires an observed authored condition")
    _expect(assassin != null and not _definition_contains_fragment(assassin, "stealth"), "Assassin threat card does not invent a stealth/invisibility subsystem")

    var mobile_ranged := EnemyArchetypeCatalog.get_definition(&"mobile_ranged")
    _expect(mobile_ranged != null and mobile_ranged.preferred_range == EnemyArchetypeDefinition.RANGE_MID, "Mobile Ranged prefers mid-range pressure rather than duplicating Marksman")
    _expect(mobile_ranged != null and mobile_ranged.defensive_limit_ids.has(&"limit:bounded_reposition_between_shots"), "Mobile Ranged movement is bounded between shots")

    var caster := EnemyArchetypeCatalog.get_definition(&"caster")
    _expect(caster != null and caster.defensive_limit_ids.has(&"limit:telegraph_required"), "Caster pressure requires a readable telegraph")
    _expect(caster != null and caster.counterplay_ids.has(&"counter:leave_cast_zone"), "Caster area pressure preserves positional counterplay")

    var support := EnemyArchetypeCatalog.get_definition(&"support")
    _expect(support != null and support.signature_action_id == &"action:support_ally_ward", "Support uses bounded ally ward identity without inventing mandatory enemy healing")
    _expect(support != null and support.defensive_limit_ids.has(&"limit:no_self_chain_ward"), "Support cannot chain its ward indefinitely onto itself")

    var summoner := EnemyArchetypeCatalog.get_definition(&"summoner")
    _expect(summoner != null and summoner.defensive_limit_ids.has(&"limit:finite_reinforcement_budget"), "Summoner charges reinforcements to a finite authored budget")
    _expect(summoner != null and summoner.defensive_limit_ids.has(&"limit:full_ai_cap_required"), "Summoner reinforcements remain under the global FULL-AI cap")
    _expect(summoner != null and summoner.counterplay_ids.has(&"counter:interrupt_summon_commit"), "Summoner exposes counterplay during the reinforcement commitment")

    var flying := EnemyArchetypeCatalog.get_definition(&"flying_harrier")
    _expect(flying != null and flying.defensive_limit_ids.has(&"limit:visible_targeting_required"), "Flying Harrier targeting remains visible")
    _expect(flying != null and flying.defensive_limit_ids.has(&"limit:starter_class_hits_required"), "Flying Harrier cannot become indefinitely unreachable to a starter class")
    _expect(flying != null and flying.counterplay_ids.has(&"counter:punish_grounded_recovery"), "Flying Harrier exposes a grounded recovery opportunity")

    var controller := EnemyArchetypeCatalog.get_definition(&"controller_disruptor")
    _expect(controller != null and controller.signature_action_id == &"action:controller_slow_field", "Controller/Disruptor uses the approved Slow behavior family for readable control")
    _expect(controller != null and controller.defensive_limit_ids.has(&"limit:no_hidden_input_read"), "Controller/Disruptor explicitly forbids hidden raw-input reading")
    _expect(controller != null and controller.counterplay_ids.has(&"counter:leave_control_zone"), "Controller/Disruptor control zone preserves visible positional counterplay")

func _test_selector_compatibility() -> void:
    for definition: EnemyArchetypeDefinition in EnemyArchetypeCatalog.remaining_slice_definitions():
        var context := {
            "target_visible": true,
            "observation_confidence": 1.0,
            "reaction_delay_satisfied": true,
            "distance_band": definition.preferred_range,
            "reservation_available": true,
            "cooldown_ready": true,
            "objective_contested": false,
            "observed_player_recovering": true,
            "observed_player_committed": false,
            "observation_age_ticks": 0,
        }
        var selected: Dictionary = EnemyTacticalSelector.select_tactic(definition, context)
        _expect(bool(selected.get("accepted", false)), "%s threat card is compatible with the shared fair tactical selector" % String(definition.archetype_id))
        _expect(StringName(selected.get("tactic_id", &"")) == definition.signature_action_id, "%s can select its signature commitment only after legal reservation/cooldown/reaction gates" % String(definition.archetype_id))

func _definition_contains_fragment(definition: EnemyArchetypeDefinition, fragment: String) -> bool:
    var ids: Array[StringName] = []
    ids.append_array(definition.observable_trigger_ids)
    ids.append(definition.signature_action_id)
    ids.append(definition.recovery_window_id)
    ids.append_array(definition.defensive_limit_ids)
    ids.append_array(definition.counterplay_ids)
    ids.append(definition.group_role_id)
    ids.append(definition.objective_behavior_id)
    ids.append_array(definition.allowed_variant_ids)
    ids.append_array(definition.tactic_ids)
    for id_value: StringName in ids:
        if String(id_value).contains(fragment):
            return true
    return false

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    failures += 1
    push_error("FAIL: %s" % message)
