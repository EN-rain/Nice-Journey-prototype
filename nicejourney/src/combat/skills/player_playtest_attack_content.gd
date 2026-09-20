class_name PlayerPlaytestAttackContent
extends Resource

# Inspector-authored geometry/damage prototypes. Never production authority.
const MODE_MELEE: StringName = &"melee"
const MODE_PROJECTILE: StringName = &"projectile"
const MODE_PULSE: StringName = &"pulse"
const MODE_WARD: StringName = &"ward"
const MODES: Array[StringName] = [MODE_MELEE, MODE_PROJECTILE, MODE_PULSE, MODE_WARD]

@export var playtest_placeholder: bool = true
@export var basic_by_class: Dictionary = {}
@export var active_skill_effects: Dictionary = {}

# Projectile/area visuals are editor-owned scenes. The placeholder remains
# exclusive to the delayed pulse and ward; class projectiles use distinct art.
@export var projectile_placeholder_scene: PackedScene = null
@export var ranged_projectile_scene: PackedScene = preload("res://src/combat/skills/player_arrow_projectile_v02.tscn")
@export var mage_projectile_scene: PackedScene = preload("res://src/combat/skills/player_arcane_projectile_v02.tscn")


func validate_content() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("playtest attack content must remain explicitly provisional")
    if projectile_placeholder_scene == null:
        errors.append("projectile placeholder scene is required")
    for entry: Array in [["ranged", ranged_projectile_scene], ["mage", mage_projectile_scene]]:
        var scene := entry[1] as PackedScene
        if scene == null or scene.get_state() == null or scene.get_state().get_node_type(0) != "Node2D":
            errors.append("%s projectile requires an Inspector-authored Node2D scene" % String(entry[0]))
    for class_id: StringName in [&"melee", &"ranged", &"mage"]:
        var raw: Variant = basic_by_class.get(String(class_id), null)
        if not raw is Dictionary:
            errors.append("missing basic attack geometry for %s" % String(class_id))
            continue
        var mode := MODE_MELEE if class_id == &"melee" else MODE_PROJECTILE
        for error: String in _validate_record(raw as Dictionary, mode):
            errors.append("basic %s: %s" % [String(class_id), error])
        var basic := raw as Dictionary
        var expected_domain := DirectHitResolver.DOMAIN_ARCANE if class_id == &"mage" else DirectHitResolver.DOMAIN_PHYSICAL
        if StringName(String(basic.get("domain", &""))) != expected_domain:
            errors.append("basic %s must use its approved damage domain" % String(class_id))
        if int(basic.get("max_targets", 0)) != 1 or (mode == MODE_PROJECTILE and int(basic.get("projectile_count", 0)) != 1):
            errors.append("basic %s must deliver a single target/hit without tracked ammunition" % String(class_id))
    if basic_by_class.size() != 3:
        errors.append("only three canonical basic class records are permitted")
    var count := 0
    for raw_ids: Variant in SkillCatalog.ACTIVE_IDS_BY_CLASS.values():
        for skill_id: StringName in raw_ids as Array:
            count += 1
            var raw: Variant = active_skill_effects.get(String(skill_id), null)
            if not raw is Dictionary:
                errors.append("missing playtest skill effect %s" % String(skill_id))
                continue
            var expected_mode := _mode_for_skill(skill_id)
            for error: String in _validate_record(raw as Dictionary, expected_mode, skill_id):
                errors.append("%s: %s" % [String(skill_id), error])
            var expected_domain := DirectHitResolver.DOMAIN_ARCANE if SkillCatalog.get_definition(skill_id).class_id == &"mage" else DirectHitResolver.DOMAIN_PHYSICAL
            if StringName(String((raw as Dictionary).get("domain", &""))) != expected_domain:
                errors.append("%s must use its approved damage domain" % String(skill_id))
    if active_skill_effects.size() != count:
        errors.append("exactly nine canonical active skill records required")
    return errors


func basic_for(class_id: StringName) -> Dictionary:
    if not validate_content().is_empty():
        return {}
    var raw: Variant = basic_by_class.get(String(class_id), null)
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func skill_for(skill_id: StringName) -> Dictionary:
    if not validate_content().is_empty():
        return {}
    var raw: Variant = active_skill_effects.get(String(skill_id), null)
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func _mode_for_skill(skill_id: StringName) -> StringName:
    if skill_id in [&"arc_cleave", &"driving_thrust", &"riposte"]:
        return MODE_MELEE
    if skill_id == &"delayed_pulse":
        return MODE_PULSE
    if skill_id == &"aegis_ward":
        return MODE_WARD
    return MODE_PROJECTILE


func _validate_record(entry: Dictionary, expected_mode: StringName, skill_id: StringName = &"") -> PackedStringArray:
    var errors := PackedStringArray()
    var mode := StringName(String(entry.get("mode", &"")))
    if mode != expected_mode or not MODES.has(mode):
        errors.append("effect mode must match approved skill mechanics")
    for key: String in ["range_px", "half_angle_degrees", "raw_damage", "guard_pressure", "poise_damage"]:
        var raw: Variant = entry.get(key, null)
        if not (typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT) or not is_finite(float(raw)) or float(raw) < 0.0:
            errors.append("%s must be finite and nonnegative" % key)
    if float(entry.get("range_px", 0.0)) <= 0.0 or float(entry.get("range_px", 0.0)) > 4096.0:
        errors.append("range must be positive and inside the maximum world extent")
    if float(entry.get("half_angle_degrees", 0.0)) > 180.0:
        errors.append("half_angle_degrees must not exceed 180")
    var raw_max: Variant = entry.get("max_targets", null)
    if typeof(raw_max) != TYPE_INT or int(raw_max) < 1 or int(raw_max) > 12:
        errors.append("max_targets must respect the shared 12-full-AI cap")
    var domain := StringName(String(entry.get("domain", &"")))
    if domain not in [DirectHitResolver.DOMAIN_PHYSICAL, DirectHitResolver.DOMAIN_ARCANE]:
        errors.append("damage domain must be physical or arcane")
    if skill_id != &"" and mode != MODE_WARD and float(entry.get("raw_damage", 0.0)) <= 0.0:
        errors.append("damaging active skill must have positive authored raw_damage")
    if mode == MODE_PROJECTILE:
        for key: String in ["projectile_speed_px_per_second", "projectile_hit_radius_px"]:
            var raw: Variant = entry.get(key, null)
            if not (typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT) or not is_finite(float(raw)) or float(raw) <= 0.0:
                errors.append("%s must be finite and positive" % key)
        var count: Variant = entry.get("projectile_count", null)
        if typeof(count) != TYPE_INT or int(count) < 1 or int(count) > 5:
            errors.append("projectile count must be 1..5")
        if skill_id == &"fan_shot" and typeof(count) == TYPE_INT and int(count) < 2:
            errors.append("Fan Shot must keep its distinct spread sequence identity")
        elif skill_id in [&"piercing_shot", &"backstep_shot", &"arcane_lance"] and typeof(count) == TYPE_INT and int(count) != 1:
            errors.append("focused/piercing/backstep projectile skills each launch one projectile")
    if mode == MODE_PULSE:
        var raw_delay: Variant = entry.get("delay_ticks", null)
        if typeof(raw_delay) != TYPE_INT or int(raw_delay) <= 0 or int(raw_delay) > 600:
            errors.append("delayed pulse must declare a positive finite tick delay")
    if mode == MODE_WARD:
        var raw_duration: Variant = entry.get("ward_ticks", null)
        if typeof(raw_duration) != TYPE_INT or int(raw_duration) <= 0 or int(raw_duration) > 600:
            errors.append("playtest ward must declare a finite active duration")
    if skill_id in [&"driving_thrust", &"backstep_shot"]:
        var raw_distance: Variant = entry.get("movement_distance_px", null)
        if not (typeof(raw_distance) == TYPE_INT or typeof(raw_distance) == TYPE_FLOAT) or not is_finite(float(raw_distance)) or float(raw_distance) <= 0.0 or float(raw_distance) > 512.0:
            errors.append("committed movement_distance_px must be finite and inside 0..512")
    if skill_id == &"fan_shot":
        var raw_interval: Variant = entry.get("sequence_interval_ticks", null)
        if typeof(raw_interval) != TYPE_INT or int(raw_interval) <= 0 or int(raw_interval) > 120:
            errors.append("fan shot requires a positive sequence_interval_ticks")
    if skill_id == &"backstep_shot":
        var raw_evade: Variant = entry.get("evade_window_ticks", null)
        if typeof(raw_evade) != TYPE_INT or int(raw_evade) <= 0 or int(raw_evade) > 600:
            errors.append("backstep shot requires a finite positive evade_window_ticks")
    return errors


static func make_payload(entry: Dictionary) -> Dictionary:
    if entry.is_empty():
        return {}
    var mode := StringName(String(entry.get("mode", &"")))
    var delivery := DirectHitResolver.DELIVERY_PROJECTILE if mode == MODE_PROJECTILE else DirectHitResolver.DELIVERY_CONTACT
    return {
        "domain": StringName(String(entry.get("domain", &""))),
        "delivery": delivery,
        "raw_damage": float(entry.get("raw_damage", 0.0)),
        "dodgeable": true,
        "blockable": true,
        "parryable": mode == MODE_MELEE,
        "guard_pressure": float(entry.get("guard_pressure", 0.0)),
        "poise_damage": float(entry.get("poise_damage", 0.0)),
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }
