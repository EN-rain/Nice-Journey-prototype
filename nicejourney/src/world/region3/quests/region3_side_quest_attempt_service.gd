class_name Region3SideQuestAttemptService
extends RefCounted

# Actor IDs, routes and wave membership are built from the authored scene and
# the finite playtest content bundle. A fresh attempt rebinds those IDs after
# the previous attempt's live actors have been removed.
const QUEST_ESCORT: StringName = &"side_region3_escort"
const QUEST_ANNIHILATION: StringName = &"side_region3_annihilation"
const QUEST_DEFENSE: StringName = &"side_region3_defense"

const REASON_INVALID_AUTHORING: StringName = &"side_quest_authoring_invalid"
const REASON_INVALID_CONTEXT: StringName = &"side_quest_context_invalid"
const REASON_SAVE_FAILED: StringName = &"side_quest_save_failed"
const REASON_OBJECTIVES_INCOMPLETE: StringName = &"side_quest_objectives_incomplete"

static func build_authored_descriptors(
    layout: Region3AuthoredTownLayout,
    anchors: Region3SideQuestPlaytestAnchorLayer,
    quests: Region3SideQuestsPlaytest,
    progression: ProgressionPlaytestContent
) -> Dictionary:
    if layout == null or anchors == null or quests == null or progression == null:
        return _rejected(REASON_INVALID_AUTHORING)
    var errors := anchors.validate_for_layout(layout)
    errors.append_array(quests.validate_content(progression))
    if not errors.is_empty():
        var rejected := _rejected(REASON_INVALID_AUTHORING)
        rejected["errors"] = errors.duplicate()
        return rejected
    var specs: Dictionary = {}
    for spec: Dictionary in quests.quest_specs:
        specs[StringName(String(spec.get("slot_id", &"")))] = spec
    var descriptors: Dictionary = {}
    for slot: StringName in [
        Region3SideQuestStagingService.SLOT_SIDE_A,
        Region3SideQuestStagingService.SLOT_SIDE_B,
        Region3SideQuestStagingService.SLOT_SIDE_C,
    ]:
        var spec := specs.get(slot, {}) as Dictionary
        if spec.is_empty() or not bool(spec.get("runtime_enabled", false)):
            return _rejected(REASON_INVALID_AUTHORING)
        var quest_id := quest_for_slot(slot)
        var placement_paths: Array[NodePath] = []
        var archetypes: Array[StringName] = []
        match slot:
            Region3SideQuestStagingService.SLOT_SIDE_A:
                placement_paths = anchors.escort_hostile_spawn_paths
                archetypes = anchors.escort_enemy_archetype_ids
            Region3SideQuestStagingService.SLOT_SIDE_B:
                placement_paths = anchors.west_hostile_spawn_paths
                archetypes = anchors.west_enemy_archetype_ids
            Region3SideQuestStagingService.SLOT_SIDE_C:
                placement_paths = anchors.north_hostile_spawn_paths
                archetypes = anchors.north_enemy_archetype_ids
        var counts := spec.get("enemy_counts_by_wave", PackedInt32Array()) as PackedInt32Array
        var placements: Array[Dictionary] = []
        var waves: Dictionary = {}
        var offset := 0
        for wave_index: int in range(counts.size()):
            var wave_id := StringName("%s:wave:%02d" % [String(quest_id), wave_index + 1])
            var required: Array[String] = []
            for actor_index: int in range(counts[wave_index]):
                if offset >= placement_paths.size() or offset >= archetypes.size():
                    return _rejected(REASON_INVALID_AUTHORING)
                var actor_id := StringName("%s:hostile:%02d" % [String(quest_id), offset + 1])
                var world_position := anchors.marker_world_position(placement_paths[offset])
                if not world_position.is_finite():
                    return _rejected(REASON_INVALID_AUTHORING)
                placements.append({
                    "actor_id": actor_id,
                    "archetype_id": archetypes[offset],
                    "world_position": world_position,
                    "wave_id": wave_id,
                })
                required.append(String(actor_id))
                offset += 1
            waves[String(wave_id)] = required
        if offset != placement_paths.size():
            return _rejected(REASON_INVALID_AUTHORING)
        var config: Dictionary = {}
        var descriptor := {
            "quest_id": quest_id,
            "slot_id": slot,
            "objective_family": StringName(String(spec["objective_family"])),
            "enemy_placements": placements,
            "wave_ids": waves.keys(),
            "xp_reward": int(spec["xp_reward"]),
            "reward_source_id": StringName("quest:%s" % String(quest_id)),
            "leave_policy_id": StringName(String(spec["leave_policy_id"])),
            "retry_policy_id": StringName(String(spec["retry_policy_id"])),
            "hostile_objective_damage": anchors.hostile_objective_damage,
            "hostile_objective_contact_radius_px": anchors.hostile_objective_contact_radius_px,
            "hostile_objective_contact_cooldown_ticks": anchors.hostile_objective_contact_cooldown_ticks,
        }
        match slot:
            Region3SideQuestStagingService.SLOT_SIDE_A:
                var route_ids: Array[StringName] = []
                var route_points: Array[Dictionary] = []
                for index: int in anchors.escort_route_paths.size():
                    var route_id := StringName("%s:route:%02d" % [String(quest_id), index + 1])
                    route_ids.append(route_id)
                    route_points.append({
                        "route_node_id": route_id,
                        "world_position": anchors.marker_world_position(anchors.escort_route_paths[index]),
                    })
                var goal_id := StringName("%s:goal" % String(quest_id))
                config = {
                    "actor_id": StringName("%s:escort" % String(quest_id)),
                    "route_node_ids": route_ids,
                    "goal_id": goal_id,
                    "safe_retry_origin_id": StringName("%s:retry_origin" % String(quest_id)),
                    "failure_policy_id": StringName(String(spec["retry_policy_id"])),
                }
                descriptor["escort_start_world_position"] = anchors.marker_world_position(anchors.escort_start_path)
                descriptor["escort_goal_world_position"] = anchors.marker_world_position(anchors.escort_goal_path)
                descriptor["escort_route"] = route_points
                descriptor["escort_max_hp"] = anchors.escort_max_hp
                descriptor["escort_speed_px_per_second"] = anchors.escort_speed_px_per_second
                descriptor["escort_arrival_tolerance_px"] = anchors.escort_arrival_tolerance_px
                descriptor["escort_follow_distance_px"] = anchors.escort_follow_distance_px
            Region3SideQuestStagingService.SLOT_SIDE_B:
                var required_ids: Array[StringName] = []
                for placement: Dictionary in placements:
                    required_ids.append(placement["actor_id"])
                config = {"required_actor_ids": required_ids}
                descriptor["return_landmark_world_position"] = anchors.marker_world_position(anchors.west_return_landmark_path)
            Region3SideQuestStagingService.SLOT_SIDE_C:
                config = {
                    "objective_id": StringName("%s:protected_objective" % String(quest_id)),
                    "objective_max_hp": anchors.defense_max_hp,
                    "required_actor_ids_by_wave": waves.duplicate(true),
                }
                descriptor["defense_objective_world_position"] = anchors.marker_world_position(anchors.north_defense_objective_path)
        descriptor["objective_config"] = config
        descriptors[quest_id] = descriptor
    return {"accepted": true, "reason_id": &"", "descriptors": descriptors}

static func quest_for_slot(slot_id: StringName) -> StringName:
    match slot_id:
        Region3SideQuestStagingService.SLOT_SIDE_A:
            return QUEST_ESCORT
        Region3SideQuestStagingService.SLOT_SIDE_B:
            return QUEST_ANNIHILATION
        Region3SideQuestStagingService.SLOT_SIDE_C:
            return QUEST_DEFENSE
    return &""

static func commit_accept(
    save: SaveService, slot: int, profile: ProfileSnapshot,
    descriptor: Dictionary, attempt_id: StringName
) -> Dictionary:
    var quest_id := StringName(String(descriptor.get("quest_id", &"")))
    if not _valid_context(save, slot, profile, quest_id) or not StableId.is_valid(String(attempt_id)):
        return _rejected(REASON_INVALID_CONTEXT)
    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null:
        return _rejected(REASON_INVALID_CONTEXT)
    var raw: Variant = staged.quest_progress.get(String(quest_id), {})
    var current := StringName(String((raw as Dictionary).get("state", &""))) if raw is Dictionary else &""
    var activation: Dictionary = {}
    if current in [&"", QuestProgressState.STATE_UNAVAILABLE, QuestProgressState.STATE_AVAILABLE]:
        if current != QuestProgressState.STATE_AVAILABLE:
            activation = QuestActivationService.mark_available(staged, quest_id, true)
            if not bool(activation.get("accepted", false)):
                return activation
        activation = QuestActivationService.accept(staged, quest_id, attempt_id, true, descriptor.get("objective_config", {}) as Dictionary)
    elif current in [QuestProgressState.STATE_FAILED, QuestProgressState.STATE_ABANDONED, QuestProgressState.STATE_RETRY_READY]:
        if current != QuestProgressState.STATE_RETRY_READY:
            activation = QuestActivationService.mark_retry_ready(staged, quest_id, true)
            if not bool(activation.get("accepted", false)):
                return activation
        activation = QuestActivationService.retry(staged, quest_id, attempt_id, true, descriptor.get("objective_config", {}) as Dictionary)
    else:
        return _rejected(&"side_quest_not_accepting")
    if not bool(activation.get("accepted", false)):
        return activation
    return _commit_profile_quest(save, slot, profile, staged, quest_id, activation)

static func commit_event(
    save: SaveService, slot: int, profile: ProfileSnapshot, quest_id: StringName,
    attempt_id: StringName, event_id: StringName, payload: Dictionary,
    runtime_snapshot: Dictionary = {}
) -> Dictionary:
    if not _valid_context(save, slot, profile, quest_id):
        return _rejected(REASON_INVALID_CONTEXT)
    var entry := profile.quest_progress.get(String(quest_id), {}) as Dictionary
    if StringName(String(entry.get("attempt_id", &""))) != attempt_id:
        return _rejected(&"side_quest_stale_attempt")
    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null:
        return _rejected(REASON_INVALID_CONTEXT)
    if not _normalize_defense_objective_json_numbers(staged, quest_id):
        return _rejected(&"side_quest_objective_state_invalid")
    var result := QuestFamilyObjectiveService.apply_event(staged, quest_id, event_id, payload)
    if not bool(result.get("accepted", false)):
        return result
    if StringName(String(result.get("reason_id", &""))) == &"duplicate_ignored":
        result["durable"] = true
        return result
    if not runtime_snapshot.is_empty():
        if not _valid_runtime_snapshot(runtime_snapshot):
            return _rejected(&"side_quest_runtime_snapshot_invalid")
        var staged_entry := (staged.quest_progress[String(quest_id)] as Dictionary).duplicate(true)
        staged_entry["runtime_state"] = runtime_snapshot.duplicate(true)
        staged.quest_progress[String(quest_id)] = staged_entry
    return _commit_profile_quest(save, slot, profile, staged, quest_id, result)

static func commit_runtime_snapshot(
    save: SaveService, slot: int, profile: ProfileSnapshot,
    quest_id: StringName, attempt_id: StringName, snapshot: Dictionary
) -> Dictionary:
    if not _valid_context(save, slot, profile, quest_id) or not _valid_runtime_snapshot(snapshot):
        return _rejected(REASON_INVALID_CONTEXT)
    var raw: Variant = profile.quest_progress.get(String(quest_id), null)
    if not raw is Dictionary:
        return _rejected(&"side_quest_not_active")
    var entry := raw as Dictionary
    if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_ACTIVE:
        return _rejected(&"side_quest_not_active")
    if StringName(String(entry.get("attempt_id", &""))) != attempt_id:
        return _rejected(&"side_quest_stale_attempt")
    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null:
        return _rejected(REASON_INVALID_CONTEXT)
    var staged_entry := (staged.quest_progress[String(quest_id)] as Dictionary).duplicate(true)
    staged_entry["runtime_state"] = snapshot.duplicate(true)
    staged.quest_progress[String(quest_id)] = staged_entry
    return _commit_profile_quest(save, slot, profile, staged, quest_id, {"accepted": true})

static func commit_turn_in(
    save: SaveService, slot: int, profile: ProfileSnapshot,
    quest_id: StringName, attempt_id: StringName
) -> Dictionary:
    if not _valid_context(save, slot, profile, quest_id):
        return _rejected(REASON_INVALID_CONTEXT)
    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null:
        return _rejected(REASON_INVALID_CONTEXT)
    var entry := staged.quest_progress.get(String(quest_id), {}) as Dictionary
    if StringName(String(entry.get("attempt_id", &""))) != attempt_id:
        return _rejected(&"side_quest_stale_attempt")
    if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_OBJECTIVES_COMPLETE:
        return _rejected(REASON_OBJECTIVES_INCOMPLETE)
    entry["state"] = QuestProgressState.STATE_COMPLETED
    staged.quest_progress[String(quest_id)] = entry
    var result := _commit_profile_quest(save, slot, profile, staged, quest_id, {"accepted": true, "quest_id": quest_id})
    if bool(result.get("accepted", false)):
        result["xp_claim_pending"] = true
    return result

static func commit_leave(
    save: SaveService, slot: int, profile: ProfileSnapshot,
    descriptor: Dictionary, confirmed: bool
) -> Dictionary:
    var quest_id := StringName(String(descriptor.get("quest_id", &"")))
    if not _valid_context(save, slot, profile, quest_id):
        return _rejected(REASON_INVALID_CONTEXT)
    var rule := QuestLeaveRuleDefinition.new()
    rule.rule_id = StringName(String(descriptor.get("leave_policy_id", &"")))
    rule.mode = QuestLeaveRuleDefinition.MODE_CONFIRM_TERMINAL
    rule.reason_id = &"region3_side_quest_departure"
    rule.reason_text = "Leaving this quest site ends the current attempt. Return to retry."
    rule.terminal_state = QuestProgressState.STATE_ABANDONED
    if not confirmed:
        return QuestLeaveTransactionService.preview(profile, quest_id, rule)
    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null:
        return _rejected(REASON_INVALID_CONTEXT)
    var result := QuestLeaveTransactionService.apply(staged, quest_id, rule, true)
    if not bool(result.get("accepted", false)):
        return result
    return _commit_profile_quest(save, slot, profile, staged, quest_id, result)

static func _valid_context(save: SaveService, slot: int, profile: ProfileSnapshot, quest_id: StringName) -> bool:
    return save != null and slot >= 1 and slot <= SaveService.SLOT_COUNT and profile != null and quest_id in [
        QUEST_ESCORT, QUEST_ANNIHILATION, QUEST_DEFENSE,
    ]

# JSON reload represents integral HP as TYPE_FLOAT. Normalize the persisted
# defense objective before the canonical objective service validates it; reject
# fractional/unsafe values instead of silently truncating durable quest data.
static func _normalize_defense_objective_json_numbers(profile: ProfileSnapshot, quest_id: StringName) -> bool:
    if quest_id != QUEST_DEFENSE:
        return true
    var entry := profile.quest_progress.get(String(quest_id), {}) as Dictionary
    var objective := entry.get("objective_state", {}) as Dictionary
    if objective.is_empty():
        return false
    for key: String in ["objective_max_hp", "objective_current_hp"]:
        var raw: Variant = objective.get(key, null)
        if typeof(raw) not in [TYPE_INT, TYPE_FLOAT]:
            return false
        var value := float(raw)
        if not is_finite(value) or value < 0.0 or value > 2147483647.0 or not is_equal_approx(value, round(value)):
            return false
        objective[key] = int(value)
    if int(objective["objective_max_hp"]) <= 0 or int(objective["objective_current_hp"]) > int(objective["objective_max_hp"]):
        return false
    entry["objective_state"] = objective
    profile.quest_progress[String(quest_id)] = entry
    return true


static func _valid_runtime_snapshot(snapshot: Dictionary) -> bool:
    if snapshot.size() != 3:
        return false
    for key: String in ["actor_pos_x", "actor_pos_y"]:
        var value: Variant = snapshot.get(key, null)
        if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)):
            return false
    var raw_hp: Variant = snapshot.get("escort_hp", null)
    if typeof(raw_hp) not in [TYPE_INT, TYPE_FLOAT]:
        return false
    var hp := float(raw_hp)
    return is_finite(hp) and hp > 0.0 and hp <= 2147483647.0 and is_equal_approx(hp, round(hp))

static func _commit_profile_quest(
    save: SaveService, slot: int, profile: ProfileSnapshot, staged: ProfileSnapshot,
    quest_id: StringName, result: Dictionary
) -> Dictionary:
    if staged == null or not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _rejected(&"side_quest_profile_invalid")
    var save_error := save.save_profile(slot, staged)
    if save_error != OK:
        var rejected := _rejected(REASON_SAVE_FAILED)
        rejected["save_error"] = save_error
        return rejected
    profile.quest_progress = staged.quest_progress.duplicate(true)
    var committed := result.duplicate(true)
    committed["accepted"] = true
    committed["quest_id"] = quest_id
    committed["durable"] = true
    committed["save_error"] = OK
    return committed

static func _rejected(reason: StringName) -> Dictionary:
    return {"accepted": false, "reason_id": reason, "durable": false, "errors": PackedStringArray()}
