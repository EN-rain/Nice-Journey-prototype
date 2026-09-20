extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_catalog_contract()
    _test_starting_grants_and_locked_alternatives()
    _test_rank_spending_and_duplicate_transaction_guard()
    _test_safe_location_loadout_swaps()
    _test_durable_commit_boundaries()
    _test_temporary_active_restoration()
    _test_serialization_and_validation()

    if _failures == 0:
        print("SKILL LOADOUT PROGRESSION TEST PASS")
    else:
        push_error("SKILL LOADOUT PROGRESSION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_catalog_contract() -> void:
    _expect(SkillCatalog.validate_catalog().is_empty(), "locked 18-skill catalog validates")
    _expect(SkillCatalog.all_definitions().size() == 18, "catalog contains exactly three active and three passive skills per class")
    for class_id: StringName in [&"melee", &"ranged", &"mage"]:
        var definitions: Array[SkillDefinition] = SkillCatalog.definitions_for_class(class_id)
        var active_count: int = 0
        var passive_count: int = 0
        var starting_active: int = 0
        var starting_passive: int = 0
        for definition: SkillDefinition in definitions:
            _expect(definition.max_rank == 3, "%s skill %s has exactly three ranks" % [String(class_id), String(definition.skill_id)])
            if definition.kind == SkillDefinition.KIND_ACTIVE:
                active_count += 1
                if definition.starting_grant:
                    starting_active += 1
            else:
                passive_count += 1
                if definition.starting_grant:
                    starting_passive += 1
        _expect(active_count == 3 and passive_count == 3, "%s has exact 3+3 skill pool" % String(class_id))
        _expect(starting_active == 2 and starting_passive == 2, "%s has exact starting 2+2 grants" % String(class_id))
    _expect(SkillCatalog.get_definition(&"riposte").prerequisite_event_id == &"successful_parry", "Riposte is explicitly gated by successful supported parry")
    _expect(SkillCatalog.get_definition(&"aegis_ward").mechanic_id == &"mana_block_window_without_parry", "Aegis Ward uses block-style semantics without parry")


func _test_starting_grants_and_locked_alternatives() -> void:
    for class_id: String in ["melee", "ranged", "mage"]:
        var profile: ProfileSnapshot = ProfileCreationService.create_profile(1, "Tester", class_id)
        _expect(profile != null, "%s profile initializes skill state" % class_id)
        var state: SkillLoadoutState = _load_state(profile)
        _expect(state != null, "%s initialized skill state validates" % class_id)
        var starting_actives: Array = SkillCatalog.STARTING_ACTIVE_IDS_BY_CLASS[StringName(class_id)]
        var starting_passives: Array = SkillCatalog.STARTING_PASSIVE_IDS_BY_CLASS[StringName(class_id)]
        for skill_id: StringName in starting_actives + starting_passives:
            _expect(state.get_rank(skill_id) == 1, "%s starting skill %s is granted at rank 1" % [class_id, String(skill_id)])
        var all_actives: Array = SkillCatalog.ACTIVE_IDS_BY_CLASS[StringName(class_id)]
        var all_passives: Array = SkillCatalog.PASSIVE_IDS_BY_CLASS[StringName(class_id)]
        _expect(state.get_rank(all_actives[2]) == 0, "%s alternative active starts locked" % class_id)
        _expect(state.get_rank(all_passives[2]) == 0, "%s alternative passive starts locked" % class_id)
        _expect(state.active_slots[0] == starting_actives[0] and state.active_slots[1] == starting_actives[1], "%s starting active loadout is deterministic" % class_id)
        _expect(state.passive_slots[0] == starting_passives[0] and state.passive_slots[1] == starting_passives[1], "%s starting passive loadout is deterministic" % class_id)


func _test_rank_spending_and_duplicate_transaction_guard() -> void:
    var profile: ProfileSnapshot = ProfileCreationService.create_profile(1, "Melee Tester", "melee")
    profile.skill_points = 4
    _expect(SkillProgressionService.purchase_rank(profile, &"riposte", &"skill_tx:riposte_1"), "one skill point learns locked alternative at rank 1")
    _expect(profile.skill_points == 3, "learning alternative consumes exactly one skill point")
    _expect(_load_state(profile).get_rank(&"riposte") == 1, "alternative active is learned at rank 1")
    _expect(not SkillProgressionService.purchase_rank(profile, &"riposte", &"skill_tx:riposte_1"), "repeated progression transaction ID cannot spend twice")
    _expect(profile.skill_points == 3 and _load_state(profile).get_rank(&"riposte") == 1, "duplicate progression request leaves points and rank unchanged")

    _expect(SkillProgressionService.purchase_rank(profile, &"riposte", &"skill_tx:riposte_2"), "second point raises learned skill to rank 2")
    _expect(SkillProgressionService.purchase_rank(profile, &"riposte", &"skill_tx:riposte_3"), "third point raises learned skill to rank 3")
    _expect(_load_state(profile).get_rank(&"riposte") == 3 and profile.skill_points == 1, "rank 3 is maximum and each rank costs one point")
    _expect(not SkillProgressionService.purchase_rank(profile, &"riposte", &"skill_tx:riposte_4"), "rank 3 skill cannot be purchased again")
    _expect(profile.skill_points == 1, "failed max-rank purchase does not spend a point")
    _expect(not SkillProgressionService.purchase_rank(profile, &"backstep_shot", &"skill_tx:wrong_class"), "cross-class skill purchase is rejected")


func _test_safe_location_loadout_swaps() -> void:
    var profile: ProfileSnapshot = ProfileCreationService.create_profile(1, "Ranged Tester", "ranged")
    profile.skill_points = 2
    _expect(SkillProgressionService.purchase_rank(profile, &"backstep_shot", &"skill_tx:backstep"), "Ranged alternative active can be learned")
    _expect(SkillProgressionService.purchase_rank(profile, &"expose", &"skill_tx:expose"), "Ranged alternative passive can be learned")

    _expect(not SkillProgressionService.equip_active(profile, 0, &"backstep_shot", false, false), "active loadout cannot change away from a safe interaction")
    _expect(not SkillProgressionService.equip_active(profile, 0, &"backstep_shot", true, true), "active loadout cannot change during Active Combat")
    _expect(SkillProgressionService.equip_active(profile, 0, &"backstep_shot", true, false), "learned active can be swapped at a safe non-combat interaction")
    _expect(_load_state(profile).active_slots[0] == &"backstep_shot", "safe active swap persists")

    _expect(not SkillProgressionService.equip_passive(profile, 0, &"expose", false, false), "passive loadout cannot change away from a safe interaction")
    _expect(SkillProgressionService.equip_passive(profile, 0, &"expose", true, false), "learned passive can be swapped at a safe non-combat interaction")
    _expect(_load_state(profile).passive_slots[0] == &"expose", "safe passive swap persists")
    _expect(not SkillProgressionService.equip_active(profile, 1, &"backstep_shot", true, false), "same active skill cannot occupy both slots")
    _expect(not SkillProgressionService.equip_active(profile, 0, &"arc_cleave", true, false), "cross-class active cannot be equipped")


func _test_durable_commit_boundaries() -> void:
    var save_service := SaveService.new("user://tests/skill_progression_commit")
    save_service.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Durable Skills", "ranged")
    profile.skill_points = 3
    _expect(save_service.save_profile(1, profile) == OK, "durable skill fixture starts from a committed profile")

    var before_failed_save := profile.to_dictionary()
    var failed_save := SkillProgressionService.commit_rank_purchase(
        save_service,
        0,
        profile,
        &"backstep_shot",
        &"skill_commit:failed_save"
    )
    _expect(not bool(failed_save.get("accepted", true)) and StringName(failed_save.get("reason_id", &"")) == SkillProgressionService.REASON_SAVE_FAILED, "rank purchase fails closed when durable save ownership rejects the slot")
    _expect(profile.to_dictionary() == before_failed_save, "failed durable rank save leaves live points, ranks and transaction ledger unchanged")

    var rank_commit := SkillProgressionService.commit_rank_purchase(
        save_service,
        1,
        profile,
        &"backstep_shot",
        &"skill_commit:backstep_rank1"
    )
    _expect(bool(rank_commit.get("accepted", false)) and bool(rank_commit.get("durable", false)), "rank purchase reports success only after the staged profile is saved")
    _expect(profile.skill_points == 2 and _load_state(profile).get_rank(&"backstep_shot") == 1, "durable rank purchase applies the saved rank and one-point spend to live state")
    var disk_after_rank := save_service.load_profile(1)
    _expect(disk_after_rank != null and _load_state(disk_after_rank).get_rank(&"backstep_shot") == 1 and disk_after_rank.claimed_transactions.has("skill_commit:backstep_rank1"), "rank transaction identity and rank ownership are committed in the same disk generation")

    var duplicate_before := profile.to_dictionary()
    var duplicate_rank := SkillProgressionService.commit_rank_purchase(
        save_service,
        1,
        profile,
        &"backstep_shot",
        &"skill_commit:backstep_rank1"
    )
    _expect(not bool(duplicate_rank.get("accepted", true)) and StringName(duplicate_rank.get("reason_id", &"")) == SkillProgressionService.REASON_DUPLICATE_TRANSACTION, "durable rank purchase rejects a repeated transaction identity")
    _expect(profile.to_dictionary() == duplicate_before, "duplicate durable rank transaction mutates no live skill state")

    var unsafe_swap := SkillProgressionService.commit_active_swap(
        save_service,
        1,
        profile,
        0,
        &"backstep_shot",
        &"skill_commit:unsafe_swap",
        false,
        false
    )
    _expect(not bool(unsafe_swap.get("accepted", true)) and StringName(unsafe_swap.get("reason_id", &"")) == SkillProgressionService.REASON_SAFE_INTERACTION_REQUIRED, "durable active swap still requires an explicit safe interaction")
    _expect(not profile.claimed_transactions.has("skill_commit:unsafe_swap"), "rejected unsafe loadout swap does not consume its transaction identity")

    var active_swap := SkillProgressionService.commit_active_swap(
        save_service,
        1,
        profile,
        0,
        &"backstep_shot",
        &"skill_commit:active_swap",
        true,
        false
    )
    _expect(bool(active_swap.get("accepted", false)) and bool(active_swap.get("durable", false)) and _load_state(profile).active_slots[0] == &"backstep_shot", "safe active loadout swap is saved before live slot ownership changes")

    _expect(bool(SkillProgressionService.commit_rank_purchase(save_service, 1, profile, &"expose", &"skill_commit:expose_rank1").get("accepted", false)), "durable fixture learns the alternative passive")
    var passive_swap := SkillProgressionService.commit_passive_swap(
        save_service,
        1,
        profile,
        1,
        &"expose",
        &"skill_commit:passive_swap",
        true,
        false
    )
    _expect(bool(passive_swap.get("accepted", false)) and _load_state(profile).passive_slots[1] == &"expose", "safe passive loadout swap uses the same durable transaction boundary")
    var disk_after_swaps := save_service.load_profile(1)
    _expect(disk_after_swaps != null and _load_state(disk_after_swaps).active_slots[0] == &"backstep_shot" and _load_state(disk_after_swaps).passive_slots[1] == &"expose", "active and passive loadout ownership round-trip from the committed save")
    _expect(disk_after_swaps.claimed_transactions.has("skill_commit:active_swap") and disk_after_swaps.claimed_transactions.has("skill_commit:passive_swap"), "each durable loadout change records its own repeat-resistant transaction identity")
    save_service.delete_slot(1)


func _test_temporary_active_restoration() -> void:
    var profile: ProfileSnapshot = ProfileCreationService.create_profile(1, "Mage Tester", "mage")
    var before: SkillLoadoutState = _load_state(profile)
    var displaced: StringName = before.active_slots[1]
    var points_before: int = profile.skill_points
    var ranks_before: Dictionary = before.ranks.duplicate(true)

    _expect(SkillProgressionService.begin_temporary_active(profile, 1, &"quest_temp:seal_break"), "temporary combat skill can occupy one active slot")
    var temporary: SkillLoadoutState = _load_state(profile)
    _expect(temporary.active_slots[1] == &"quest_temp:seal_break", "temporary skill occupies the selected active slot")
    _expect(StringName(String(temporary.temporary_override["displaced_skill_id"])) == displaced, "temporary override stores displaced learned skill identity")
    _expect(not SkillProgressionService.equip_active(profile, 1, &"arcane_lance", true, false), "temporarily overridden slot cannot be manually remapped")
    _expect(profile.skill_points == points_before and temporary.ranks == ranks_before, "temporary skill spends no permanent points and changes no learned ownership")

    _expect(SkillProgressionService.end_temporary_active(profile), "ending temporary skill succeeds")
    var restored: SkillLoadoutState = _load_state(profile)
    _expect(restored.active_slots[1] == displaced, "ending temporary skill deterministically restores displaced learned skill")
    _expect(restored.temporary_override.is_empty(), "temporary restoration record clears after deterministic restoration")
    _expect(profile.skill_points == points_before and restored.ranks == ranks_before, "temporary restoration preserves permanent progression")


func _test_serialization_and_validation() -> void:
    var profile: ProfileSnapshot = ProfileCreationService.create_profile(1, "Serialize Tester", "melee")
    profile.skill_points = 1
    _expect(SkillProgressionService.purchase_rank(profile, &"parry_recovery", &"skill_tx:parry_recovery"), "fixture learns alternative passive before serialization")
    var dictionary: Dictionary = profile.to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(dictionary).is_empty(), "profile with skill state validates for persistence")
    var loaded: ProfileSnapshot = ProfileSnapshot.from_dictionary(dictionary)
    _expect(loaded.skill_state == profile.skill_state, "skill unlock/rank/loadout state round-trips through profile dictionary")

    var malformed: Dictionary = dictionary.duplicate(true)
    malformed["skill_state"]["class_id"] = "mage"
    _expect(not ProfileSnapshot.validate_dictionary(malformed).is_empty(), "profile rejects skill-state class mismatch")

    malformed = dictionary.duplicate(true)
    malformed["skill_state"]["ranks"]["parry_recovery"] = 4
    _expect(not ProfileSnapshot.validate_dictionary(malformed).is_empty(), "profile rejects skill rank above three")

    malformed = dictionary.duplicate(true)
    malformed["skill_state"]["active_slots"][0] = "riposte"
    _expect(not ProfileSnapshot.validate_dictionary(malformed).is_empty(), "profile rejects an unlearned active in equipped loadout")


func _load_state(profile: ProfileSnapshot) -> SkillLoadoutState:
    if profile == null:
        return null
    var state: SkillLoadoutState = SkillLoadoutState.new()
    if not state.load_dictionary(profile.skill_state).is_empty():
        return null
    return state


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
