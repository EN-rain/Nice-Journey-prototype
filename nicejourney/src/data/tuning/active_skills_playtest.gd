class_name ActiveSkillsPlaytest
extends Resource

# PLAYTEST action clocks and rank adjustments. Rank changes affect magnitude,
# resource cost and recovery only; this is not final production authority.
@export var playtest_placeholder: bool = true
@export var actions: Array[ActionDefinition] = []
@export var rank_adjustments: Dictionary = {}


func action_for_rank(skill_id: StringName, rank: int) -> ActionDefinition:
    if not validate_content().is_empty() or rank < 1 or rank > 3:
        return null
    for action: ActionDefinition in actions:
        if action.action_id != StringName("action:playtest:%s" % String(skill_id)):
            continue
        var ranked := action.duplicate(true) as ActionDefinition
        if rank > 1:
            var adjustment := adjustment_for_rank(skill_id, rank)
            ranked.cost_amount *= float(adjustment["cost_multiplier"])
            ranked.recovery_ticks = maxi(0, ranked.recovery_ticks + int(adjustment["recovery_ticks_delta"]))
        return ranked if ranked.validate_definition().is_empty() and ranked.cost_amount > 0.0 else null
    return null


func effect_for_rank(skill_id: StringName, rank: int, base_effect: Dictionary) -> Dictionary:
    if base_effect.is_empty() or not validate_content().is_empty() or rank < 1 or rank > 3:
        return {}
    var effect := base_effect.duplicate(true)
    if rank > 1:
        var multiplier := float(adjustment_for_rank(skill_id, rank)["magnitude_multiplier"])
        if skill_id == &"aegis_ward":
            effect["ward_ticks"] = maxi(1, roundi(float(effect["ward_ticks"]) * multiplier))
        else:
            effect["raw_damage"] = float(effect["raw_damage"]) * multiplier
            effect["guard_pressure"] = float(effect["guard_pressure"]) * multiplier
            effect["poise_damage"] = float(effect["poise_damage"]) * multiplier
    return effect


func adjustment_for_rank(skill_id: StringName, rank: int) -> Dictionary:
    var record: Variant = rank_adjustments.get(String(skill_id), null)
    if not record is Dictionary or rank < 2 or rank > 3:
        return {}
    var value: Variant = (record as Dictionary).get("rank_%d" % rank, null)
    return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func action_definitions_by_mechanic() -> Dictionary:
    if not validate_content().is_empty():
        return {}
    var result: Dictionary = {}
    for action: ActionDefinition in actions:
        var skill_id := StringName(String(action.action_id).trim_prefix("action:playtest:"))
        var skill := SkillCatalog.get_definition(skill_id)
        if skill == null:
            return {}
        result[skill.mechanic_id] = action
    return result


func validate_content() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("active skill timings must be flagged provisional")
    var seen := {}
    for action: ActionDefinition in actions:
        if action == null or not action.validate_definition().is_empty():
            errors.append("invalid provisional skill action")
            continue
        var skill_id := StringName(String(action.action_id).trim_prefix("action:playtest:"))
        var definition := SkillCatalog.get_definition(skill_id)
        if definition == null or definition.kind != SkillDefinition.KIND_ACTIVE or action.cost_resource != definition.cost_resource:
            errors.append("unapproved skill or resource identity")
            continue
        if seen.has(skill_id):
            errors.append("duplicate skill action")
        seen[skill_id] = action
    for raw_ids: Variant in SkillCatalog.ACTIVE_IDS_BY_CLASS.values():
        for skill_id: StringName in raw_ids as Array:
            if not seen.has(skill_id):
                errors.append("missing provisional action: %s" % String(skill_id))
            var base_action := seen.get(skill_id) as ActionDefinition
            var record: Variant = rank_adjustments.get(String(skill_id), null)
            if not record is Dictionary or (record as Dictionary).size() != 2:
                errors.append("missing rank-2/3 adjustments: %s" % String(skill_id))
                continue
            var previous_magnitude := 1.0
            var previous_cost := 1.0
            var previous_recovery := 0
            for rank: int in [2, 3]:
                var adjustment: Variant = (record as Dictionary).get("rank_%d" % rank, null)
                if not adjustment is Dictionary or (adjustment as Dictionary).size() != 3:
                    errors.append("invalid rank adjustment for %s rank %d" % [String(skill_id), rank])
                    continue
                var numbers_valid := true
                for key: String in ["magnitude_multiplier", "cost_multiplier"]:
                    var value: Variant = (adjustment as Dictionary).get(key, null)
                    if not (typeof(value) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(float(value)) or float(value) <= 0.0:
                        errors.append("%s rank %d %s must be finite and positive" % [String(skill_id), rank, key])
                        numbers_valid = false
                var delta: Variant = (adjustment as Dictionary).get("recovery_ticks_delta", null)
                if typeof(delta) != TYPE_INT or int(delta) < -600 or int(delta) > 600:
                    errors.append("%s rank %d recovery_ticks_delta must be a bounded integer" % [String(skill_id), rank])
                    continue
                if not numbers_valid:
                    continue
                var magnitude := float((adjustment as Dictionary)["magnitude_multiplier"])
                var cost := float((adjustment as Dictionary)["cost_multiplier"])
                var recovery := int(delta)
                if magnitude < previous_magnitude or cost > previous_cost or recovery > previous_recovery:
                    errors.append("%s rank %d must not regress prior magnitude, cost or recovery" % [String(skill_id), rank])
                if is_equal_approx(magnitude, previous_magnitude) and is_equal_approx(cost, previous_cost) and recovery == previous_recovery:
                    errors.append("%s rank %d must improve at least one authored magnitude/cost/recovery field" % [String(skill_id), rank])
                if base_action != null and base_action.recovery_ticks > 0 and base_action.recovery_ticks + recovery <= 0:
                    errors.append("%s rank %d must preserve an authored recovery window" % [String(skill_id), rank])
                previous_magnitude = magnitude
                previous_cost = cost
                previous_recovery = recovery
    if rank_adjustments.size() != 9:
        errors.append("exactly nine canonical active rank records required")
    return errors
