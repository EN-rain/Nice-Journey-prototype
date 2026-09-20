class_name Region3SideQuestsPlaytest
extends Resource

# Provisional wave counts and rewards; runtime still requires the separately
# validated Inspector-owned Region 3 quest markers and enemy roster.
@export var playtest_placeholder: bool = true
@export var quest_specs: Array[Dictionary] = []


func validate_content(progression: ProgressionPlaytestContent) -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder or progression == null or not progression.validate_content().is_empty():
        errors.append("valid flagged progression bundle required")
        return errors
    var slots := [Region3SideQuestStagingService.SLOT_SIDE_A, Region3SideQuestStagingService.SLOT_SIDE_B, Region3SideQuestStagingService.SLOT_SIDE_C]
    var families := [Region3SideQuestStagingService.FAMILY_ESCORT, Region3SideQuestStagingService.FAMILY_ANNIHILATION, Region3SideQuestStagingService.FAMILY_DEFENSE]
    var sources := [&"quest:side_region3_escort", &"quest:side_region3_annihilation", &"quest:side_region3_defense"]
    var routes := [Region3SideQuestStagingService.ROUTE_SOUTH_APPROACH, Region3SideQuestStagingService.ROUTE_WEST_APPROACH, Region3SideQuestStagingService.ROUTE_NORTH_APPROACH]
    var seen := {}
    for spec: Dictionary in quest_specs:
        var slot := StringName(String(spec.get("slot_id", &"")))
        var index := slots.find(slot)
        if index < 0 or seen.has(slot):
            errors.append("unknown or duplicate side quest slot")
            continue
        seen[slot] = true
        if StringName(String(spec.get("objective_family", &""))) != families[index]:
            errors.append("quest family mismatch")
        if StringName(String(spec.get("staging_route_name", &""))) != routes[index]:
            errors.append("quest staging route mismatch")
        for policy_key: String in ["leave_policy_id", "retry_policy_id"]:
            if not StableId.is_valid(String(spec.get(policy_key, ""))):
                errors.append("%s requires a stable declared policy ID" % policy_key)
        var reward := progression.reward_for_source(sources[index])
        var raw_xp: Variant = spec.get("xp_reward", null)
        if typeof(raw_xp) != TYPE_INT or int(raw_xp) < 0 or reward == null or int(raw_xp) != reward.xp_amount:
            errors.append("XP reward source mismatch")
        var waves: Variant = spec.get("enemy_counts_by_wave", null)
        if not waves is PackedInt32Array or (waves as PackedInt32Array).is_empty():
            errors.append("side quest missing concrete wave counts")
        else:
            # Escort and Annihilation run a single encounter; only Defense owns
            # wave advancement. Multi-wave plans for A/B would strand actors.
            if index != 2 and (waves as PackedInt32Array).size() != 1:
                errors.append("escort and annihilation require exactly one wave")
            for enemy_count: int in waves as PackedInt32Array:
                if enemy_count <= 0 or enemy_count > 12:
                    errors.append("wave count outside FULL-AI cap")
        if not bool(spec.get("runtime_enabled", false)):
            errors.append("all three authored side slots must be enabled for validated runtime staging")
    if seen.size() != 3:
        errors.append("all reserved slots required")
    return errors
