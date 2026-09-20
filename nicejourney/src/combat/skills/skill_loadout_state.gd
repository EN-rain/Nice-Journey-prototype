class_name SkillLoadoutState
extends RefCounted

const ACTIVE_SLOT_COUNT: int = 2
const PASSIVE_SLOT_COUNT: int = 2

var class_id: StringName = &""
var ranks: Dictionary = {}
var active_slots: Array[StringName] = [&"", &""]
var passive_slots: Array[StringName] = [&"", &""]
var temporary_override: Dictionary = {}


func initialize_for_class(target_class_id: StringName) -> bool:
    if not SkillCatalog.validate_catalog().is_empty():
        return false
    if not SkillCatalog.ACTIVE_IDS_BY_CLASS.has(target_class_id):
        return false
    class_id = target_class_id
    ranks.clear()
    active_slots = [&"", &""]
    passive_slots = [&"", &""]
    temporary_override.clear()

    var active_index: int = 0
    var passive_index: int = 0
    for definition: SkillDefinition in SkillCatalog.definitions_for_class(class_id):
        ranks[String(definition.skill_id)] = 1 if definition.starting_grant else 0
        if not definition.starting_grant:
            continue
        if definition.kind == SkillDefinition.KIND_ACTIVE:
            active_slots[active_index] = definition.skill_id
            active_index += 1
        else:
            passive_slots[passive_index] = definition.skill_id
            passive_index += 1
    return active_index == ACTIVE_SLOT_COUNT and passive_index == PASSIVE_SLOT_COUNT


func get_rank(skill_id: StringName) -> int:
    return int(ranks.get(String(skill_id), 0))


func is_learned(skill_id: StringName) -> bool:
    return get_rank(skill_id) > 0


func can_increase_rank(skill_id: StringName) -> bool:
    var definition: SkillDefinition = SkillCatalog.get_definition(skill_id)
    if definition == null or definition.class_id != class_id:
        return false
    var current_rank: int = get_rank(skill_id)
    return current_rank >= 0 and current_rank < definition.max_rank


func try_increase_rank(skill_id: StringName) -> bool:
    if not can_increase_rank(skill_id):
        return false
    ranks[String(skill_id)] = get_rank(skill_id) + 1
    return true


func equip_active(slot_index: int, skill_id: StringName, safe_interaction: bool, active_combat: bool) -> bool:
    if not _can_swap(slot_index, ACTIVE_SLOT_COUNT, safe_interaction, active_combat):
        return false
    if _temporary_slot_is_locked(slot_index):
        return false
    var definition: SkillDefinition = SkillCatalog.get_definition(skill_id)
    if definition == null or definition.class_id != class_id or definition.kind != SkillDefinition.KIND_ACTIVE or not is_learned(skill_id):
        return false
    var other_index: int = 1 - slot_index
    if active_slots[other_index] == skill_id:
        return false
    active_slots[slot_index] = skill_id
    return true


func equip_passive(slot_index: int, skill_id: StringName, safe_interaction: bool, active_combat: bool) -> bool:
    if not _can_swap(slot_index, PASSIVE_SLOT_COUNT, safe_interaction, active_combat):
        return false
    var definition: SkillDefinition = SkillCatalog.get_definition(skill_id)
    if definition == null or definition.class_id != class_id or definition.kind != SkillDefinition.KIND_PASSIVE or not is_learned(skill_id):
        return false
    var other_index: int = 1 - slot_index
    if passive_slots[other_index] == skill_id:
        return false
    passive_slots[slot_index] = skill_id
    return true


func begin_temporary_active(slot_index: int, temporary_skill_id: StringName) -> bool:
    if slot_index < 0 or slot_index >= ACTIVE_SLOT_COUNT:
        return false
    if not temporary_override.is_empty() or not StableId.is_valid(String(temporary_skill_id)):
        return false
    var displaced: StringName = active_slots[slot_index]
    if displaced == &"" or not is_learned(displaced):
        return false
    temporary_override = {
        "slot_index": slot_index,
        "temporary_skill_id": temporary_skill_id,
        "displaced_skill_id": displaced,
    }
    active_slots[slot_index] = temporary_skill_id
    return true


func end_temporary_active() -> bool:
    if temporary_override.is_empty():
        return false
    var slot_index: int = int(temporary_override.get("slot_index", -1))
    var displaced: StringName = StringName(String(temporary_override.get("displaced_skill_id", "")))
    if slot_index < 0 or slot_index >= ACTIVE_SLOT_COUNT or displaced == &"" or not is_learned(displaced):
        return false
    active_slots[slot_index] = displaced
    temporary_override.clear()
    return true


func to_dictionary() -> Dictionary:
    var serialized_ranks: Dictionary = {}
    for skill_variant: Variant in ranks.keys():
        serialized_ranks[String(skill_variant)] = int(ranks[skill_variant])
    var serialized_active: Array[String] = []
    for skill_id: StringName in active_slots:
        serialized_active.append(String(skill_id))
    var serialized_passive: Array[String] = []
    for skill_id: StringName in passive_slots:
        serialized_passive.append(String(skill_id))
    var serialized_temp: Dictionary = {}
    if not temporary_override.is_empty():
        serialized_temp = {
            "slot_index": int(temporary_override["slot_index"]),
            "temporary_skill_id": String(temporary_override["temporary_skill_id"]),
            "displaced_skill_id": String(temporary_override["displaced_skill_id"]),
        }
    return {
        "class_id": String(class_id),
        "ranks": serialized_ranks,
        "active_slots": serialized_active,
        "passive_slots": serialized_passive,
        "temporary_override": serialized_temp,
    }


func load_dictionary(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = validate_dictionary(data)
    if not errors.is_empty():
        return errors
    class_id = StringName(String(data["class_id"]))
    ranks = (data["ranks"] as Dictionary).duplicate(true)
    active_slots = []
    for value: Variant in data["active_slots"]:
        active_slots.append(StringName(String(value)))
    passive_slots = []
    for value: Variant in data["passive_slots"]:
        passive_slots.append(StringName(String(value)))
    temporary_override = (data["temporary_override"] as Dictionary).duplicate(true)
    if not temporary_override.is_empty():
        temporary_override["temporary_skill_id"] = StringName(String(temporary_override["temporary_skill_id"]))
        temporary_override["displaced_skill_id"] = StringName(String(temporary_override["displaced_skill_id"]))
    return errors


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    var candidate_class: StringName = StringName(String(data.get("class_id", "")))
    if not SkillCatalog.ACTIVE_IDS_BY_CLASS.has(candidate_class):
        errors.append("invalid skill-state class_id")
        return errors
    var raw_ranks: Variant = data.get("ranks", null)
    var raw_active: Variant = data.get("active_slots", null)
    var raw_passive: Variant = data.get("passive_slots", null)
    var raw_temp: Variant = data.get("temporary_override", null)
    if not raw_ranks is Dictionary:
        errors.append("ranks must be a dictionary")
        return errors
    if not raw_active is Array or (raw_active as Array).size() != ACTIVE_SLOT_COUNT:
        errors.append("active_slots must contain exactly two entries")
        return errors
    if not raw_passive is Array or (raw_passive as Array).size() != PASSIVE_SLOT_COUNT:
        errors.append("passive_slots must contain exactly two entries")
        return errors
    if not raw_temp is Dictionary:
        errors.append("temporary_override must be a dictionary")
        return errors

    var allowed_ids: Dictionary = {}
    for definition: SkillDefinition in SkillCatalog.definitions_for_class(candidate_class):
        allowed_ids[String(definition.skill_id)] = definition
    for rank_key: Variant in (raw_ranks as Dictionary).keys():
        var rank_id: String = String(rank_key)
        if not allowed_ids.has(rank_id):
            errors.append("rank references unknown or cross-class skill: %s" % rank_id)
            continue
        var rank_value: Variant = (raw_ranks as Dictionary)[rank_key]
        if not _is_integral_number(rank_value) or int(rank_value) < 0 or int(rank_value) > 3:
            errors.append("rank must be an integer from 0 through 3: %s" % rank_id)
    for expected_id: String in allowed_ids.keys():
        if not (raw_ranks as Dictionary).has(expected_id):
            errors.append("missing rank entry: %s" % expected_id)

    var temp: Dictionary = raw_temp as Dictionary
    var temporary_skill_id: StringName = &""
    var temporary_slot_index: int = -1
    if not temp.is_empty():
        temporary_skill_id = StringName(String(temp.get("temporary_skill_id", "")))
        if temp.has("slot_index") and _is_integral_number(temp["slot_index"]):
            temporary_slot_index = int(temp["slot_index"])

    _validate_slot_array(raw_active as Array, candidate_class, SkillDefinition.KIND_ACTIVE, raw_ranks as Dictionary, errors, "active_slots", temporary_skill_id, temporary_slot_index)
    _validate_slot_array(raw_passive as Array, candidate_class, SkillDefinition.KIND_PASSIVE, raw_ranks as Dictionary, errors, "passive_slots")


    if not temp.is_empty():
        if not temp.has("slot_index") or not _is_integral_number(temp["slot_index"]):
            errors.append("temporary_override slot_index must be an integer")
        else:
            var slot_index: int = int(temp["slot_index"])
            if slot_index < 0 or slot_index >= ACTIVE_SLOT_COUNT:
                errors.append("temporary_override slot_index is out of range")
        var temporary_id: String = String(temp.get("temporary_skill_id", ""))
        var displaced_id: String = String(temp.get("displaced_skill_id", ""))
        if not StableId.is_valid(temporary_id):
            errors.append("temporary_skill_id must be a stable ID")
        if not allowed_ids.has(displaced_id) or int((raw_ranks as Dictionary).get(displaced_id, 0)) <= 0:
            errors.append("displaced_skill_id must be a learned active class skill")
        else:
            var displaced_definition: SkillDefinition = allowed_ids[displaced_id] as SkillDefinition
            if displaced_definition.kind != SkillDefinition.KIND_ACTIVE:
                errors.append("displaced_skill_id must be active")
        if temp.has("slot_index") and _is_integral_number(temp["slot_index"]):
            var temp_slot: int = int(temp["slot_index"])
            if temp_slot >= 0 and temp_slot < ACTIVE_SLOT_COUNT and String((raw_active as Array)[temp_slot]) != temporary_id:
                errors.append("temporary active slot must contain temporary_skill_id")
    return errors


static func _validate_slot_array(raw_slots: Array, candidate_class: StringName, expected_kind: StringName, raw_ranks: Dictionary, errors: PackedStringArray, label: String, temporary_skill_id: StringName = &"", temporary_slot_index: int = -1) -> void:
    var seen: Dictionary = {}
    for slot_index: int in raw_slots.size():
        var skill_id: StringName = StringName(String(raw_slots[slot_index]))
        var definition: SkillDefinition = SkillCatalog.get_definition(skill_id)
        if definition == null:
            if expected_kind == SkillDefinition.KIND_ACTIVE and slot_index == temporary_slot_index and skill_id == temporary_skill_id and StableId.is_valid(String(skill_id)):
                continue
            errors.append("%s references unknown skill: %s" % [label, String(skill_id)])
            continue
        if definition.class_id != candidate_class or definition.kind != expected_kind:
            errors.append("%s references wrong class/kind skill: %s" % [label, String(skill_id)])
            continue
        if int(raw_ranks.get(String(skill_id), 0)) <= 0:
            errors.append("%s references unlearned skill: %s" % [label, String(skill_id)])
        if seen.has(skill_id):
            errors.append("%s cannot equip the same skill twice" % label)
        seen[skill_id] = true


func _can_swap(slot_index: int, slot_count: int, safe_interaction: bool, active_combat: bool) -> bool:
    return slot_index >= 0 and slot_index < slot_count and safe_interaction and not active_combat


func _temporary_slot_is_locked(slot_index: int) -> bool:
    return not temporary_override.is_empty() and int(temporary_override.get("slot_index", -1)) == slot_index


static func _is_integral_number(value: Variant) -> bool:
    var value_type: int = typeof(value)
    if value_type == TYPE_INT:
        return true
    if value_type != TYPE_FLOAT:
        return false
    var numeric: float = float(value)
    return is_finite(numeric) and is_equal_approx(numeric, round(numeric))
