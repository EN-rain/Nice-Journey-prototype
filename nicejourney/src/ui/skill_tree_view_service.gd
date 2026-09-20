class_name SkillTreeViewService
extends RefCounted

const REASON_INVALID_PROFILE: StringName = &"invalid_profile"
const REASON_SKILL_STATE_UNAVAILABLE: StringName = &"skill_state_unavailable"
const REASON_SKILL_STATE_INVALID: StringName = &"skill_state_invalid"
const RANK_COST_SKILL_POINTS: int = 1


static func build_view(profile: ProfileSnapshot, capabilities: Dictionary = {}) -> Dictionary:
    if profile == null:
        return _rejected(REASON_INVALID_PROFILE)
    if profile.skill_state.is_empty():
        return _rejected(REASON_SKILL_STATE_UNAVAILABLE)
    if not SkillLoadoutState.validate_dictionary(profile.skill_state).is_empty():
        return _rejected(REASON_SKILL_STATE_INVALID)

    var class_id := StringName(String(profile.skill_state.get("class_id", &"")))
    if class_id != StringName(profile.class_id):
        return _rejected(REASON_SKILL_STATE_INVALID)
    var ranks := profile.skill_state.get("ranks", {}) as Dictionary
    var active_slots := profile.skill_state.get("active_slots", []) as Array
    var passive_slots := profile.skill_state.get("passive_slots", []) as Array
    var temporary_override := (profile.skill_state.get("temporary_override", {}) as Dictionary).duplicate(true)
    var entries: Array[Dictionary] = []
    var rank_commit_available := bool(capabilities.get("rank_purchase_commit_available", false))
    var loadout_commit_available := bool(capabilities.get("loadout_swap_commit_available", false))
    var safe_state_available := capabilities.has("safe_interaction") and capabilities.get("safe_interaction") is bool
    var combat_state_available := capabilities.has("active_combat") and capabilities.get("active_combat") is bool
    var safe_interaction := bool(capabilities.get("safe_interaction", false)) if safe_state_available else false
    var active_combat := bool(capabilities.get("active_combat", true)) if combat_state_available else true
    var loadout_action_available := loadout_commit_available and safe_state_available and combat_state_available and safe_interaction and not active_combat

    for definition: SkillDefinition in SkillCatalog.definitions_for_class(class_id):
        var rank := int(ranks.get(String(definition.skill_id), 0))
        var slot_index := -1
        if definition.kind == SkillDefinition.KIND_ACTIVE:
            slot_index = _slot_index(active_slots, definition.skill_id)
        else:
            slot_index = _slot_index(passive_slots, definition.skill_id)
        var prerequisite_known := definition.prerequisite_event_id == &""
        entries.append({
            "skill_id": definition.skill_id,
            "display_name": definition.display_name,
            "class_id": definition.class_id,
            "kind": definition.kind,
            "mechanic_id": definition.mechanic_id,
            "starting_grant": definition.starting_grant,
            "rank": rank,
            "max_rank": definition.max_rank,
            "learned": rank > 0,
            "equipped_slot_index": slot_index,
            "equipped": slot_index >= 0,
            "rank_cost_skill_points": RANK_COST_SKILL_POINTS,
            "rank_purchase_available": rank_commit_available and profile.skill_points >= RANK_COST_SKILL_POINTS and rank < definition.max_rank,
            "rank_purchase_preview_available": rank < definition.max_rank,
            "cost_resource": definition.cost_resource,
            "action_cost_amount_available": false,
            "prerequisite_event_id": definition.prerequisite_event_id,
            "prerequisite_satisfied_state_available": prerequisite_known,
            "prerequisite_satisfied": prerequisite_known,
            "incompatibility_state_available": false,
            "icon_id": StringName("skill_%s" % String(definition.skill_id)),
        })

    entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_kind := StringName(left.get("kind", &""))
        var right_kind := StringName(right.get("kind", &""))
        if left_kind != right_kind:
            return left_kind == SkillDefinition.KIND_ACTIVE
        return String(left.get("skill_id", &"")) < String(right.get("skill_id", &""))
    )

    return {
        "accepted": true,
        "reason_id": &"",
        "class_id": class_id,
        "skill_points": profile.skill_points,
        "entries": entries,
        "entry_count": entries.size(),
        "active_slots": active_slots.duplicate(true),
        "passive_slots": passive_slots.duplicate(true),
        "temporary_override": temporary_override,
        "safe_swap_state_available": safe_state_available and combat_state_available,
        "safe_interaction": safe_interaction,
        "active_combat": active_combat,
        "loadout_swap_action_available": loadout_action_available,
        "rank_purchase_action_available": rank_commit_available,
        "rank_purchase_save_transaction_available": rank_commit_available,
    }


static func _slot_index(slots: Array, skill_id: StringName) -> int:
    for index: int in range(slots.size()):
        if StringName(String(slots[index])) == skill_id:
            return index
    return -1


static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "class_id": &"",
        "skill_points": 0,
        "entries": [],
        "entry_count": 0,
        "active_slots": [],
        "passive_slots": [],
        "temporary_override": {},
        "safe_swap_state_available": false,
        "safe_interaction": false,
        "active_combat": true,
        "loadout_swap_action_available": false,
        "rank_purchase_action_available": false,
        "rank_purchase_save_transaction_available": false,
    }
