class_name ActiveSkillsPlaytestContent
extends Resource

# These ActionDefinitions stage timing/costs only. Their effect, aim/movement,
# projectile and defense profiles still need actual runtime ownership.
@export var playtest_placeholder: bool = true
@export var action_by_skill: Dictionary = {}


func validate_content() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("active-skill timing data must remain playtest")
    if action_by_skill.size() != 9:
        errors.append("exactly nine approved active skills require playtest actions")
    for class_id: StringName in [&"melee", &"ranged", &"mage"]:
        for skill_id: StringName in SkillCatalog.ACTIVE_IDS_BY_CLASS[class_id]:
            var raw_action: Variant = action_by_skill.get(String(skill_id), null)
            if not raw_action is ActionDefinition:
                errors.append("missing provisional action for %s" % String(skill_id))
                continue
            for error: String in ActiveSkillProductionAuthority.validate_action_contract(skill_id, raw_action as ActionDefinition):
                errors.append("%s: %s" % [String(skill_id), error])
    return errors


func action_for(skill_id: StringName) -> ActionDefinition:
    var raw_action: Variant = action_by_skill.get(String(skill_id), null)
    return (raw_action as ActionDefinition).duplicate(true) as ActionDefinition if raw_action is ActionDefinition else null
