class_name Region3SideQuestsPlaytestContent
extends Resource

# These are count/reward proposals, NOT runtime quest encounters: the Region 3
# authored staging manifest still lacks exact placement/escort/defense anchors.
@export var playtest_placeholder: bool = true
@export var quest_specs: Dictionary = {}


func validate_content() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("side-quest count/reward data must retain provisional flag")
    var expected := [
        Region3SideQuestStagingService.SLOT_SIDE_A,
        Region3SideQuestStagingService.SLOT_SIDE_B,
        Region3SideQuestStagingService.SLOT_SIDE_C,
    ]
    if quest_specs.size() != expected.size():
        errors.append("exactly three approved Region 3 side slots required")
    for slot_id: StringName in expected:
        var raw: Variant = quest_specs.get(String(slot_id), null)
        if not raw is Dictionary:
            errors.append("%s requires a playtest record" % String(slot_id))
            continue
        var entry := raw as Dictionary
        if entry.get("slot_id", null) != slot_id:
            errors.append("%s slot identity mismatch" % String(slot_id))
        if bool(entry.get("runtime_ready", true)):
            errors.append("%s cannot claim runtime-ready before exact anchors/actors/policies exist" % String(slot_id))
        if not StableId.is_valid(String(entry.get("xp_source_id", ""))):
            errors.append("%s requires a stable XP source" % String(slot_id))
        if typeof(entry.get("gold_reward", null)) != TYPE_INT or int(entry.get("gold_reward", -1)) < 0:
            errors.append("%s gold reward must be explicitly nonnegative" % String(slot_id))
        var waves: Variant = entry.get("enemy_waves", null)
        if not waves is Array or (waves as Array).is_empty():
            errors.append("%s requires provisional wave/count authoring" % String(slot_id))
            continue
        var total := 0
        for wave: Variant in waves as Array:
            if not wave is Dictionary:
                errors.append("%s wave must be a dictionary" % String(slot_id))
                continue
            var archetype := StringName(String((wave as Dictionary).get("archetype_id", "")))
            var count: Variant = (wave as Dictionary).get("count", null)
            if not EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS.has(archetype) or typeof(count) != TYPE_INT or int(count) <= 0:
                errors.append("%s requires canonical enemy identity and positive count" % String(slot_id))
                continue
            total += int(count)
        if int(entry.get("enemy_count", -1)) != total:
            errors.append("%s must match summed authored wave counts" % String(slot_id))
    return errors


func descriptor(slot_id: StringName) -> Dictionary:
    if not validate_content().is_empty():
        return {}
    var entry: Variant = quest_specs.get(String(slot_id), null)
    return (entry as Dictionary).duplicate(true) if entry is Dictionary else {}
