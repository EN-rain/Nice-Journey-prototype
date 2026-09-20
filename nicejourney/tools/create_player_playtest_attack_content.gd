extends SceneTree

const OUTPUT := "res://src/data/tuning/player_attacks_playtest_v01.tres"
const MARKER: PackedScene = preload("res://src/combat/skills/player_projectile_placeholder.tscn")
const STARTER_POISE: StarterCombatTuning = preload("res://src/data/tuning/starter_combat_default.tres")


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var content := PlayerPlaytestAttackContent.new()
    content.resource_name = "PLAYTEST player basic and nine active skill effects — editable hit envelopes"
    content.playtest_placeholder = true
    content.projectile_placeholder_scene = MARKER
    content.basic_by_class = {
        "melee": _entry(&"melee", 76.0, 64.0, 0.0, &"physical", 2.0, 1).merged({"poise_damage": STARTER_POISE.melee_poise_damage}, true),
        "ranged": _entry(&"projectile", 320.0, 8.0, 0.0, &"physical", 1.0, 1, 280.0, 15.0).merged({"poise_damage": STARTER_POISE.ranged_poise_damage}, true),
        "mage": _entry(&"projectile", 300.0, 8.0, 0.0, &"arcane", 1.0, 1, 240.0, 16.0).merged({"poise_damage": STARTER_POISE.mage_poise_damage}, true),
    }
    content.active_skill_effects = {
        "arc_cleave": _entry(&"melee", 104.0, 85.0, 12.0, &"physical", 3.0, 4).merged({"poise_damage": 3.0}, true),
        "driving_thrust": _entry(&"melee", 116.0, 20.0, 18.0, &"physical", 4.0, 1).merged({"movement_distance_px": 36.0, "poise_damage": 4.0}, true),
        "riposte": _entry(&"melee", 88.0, 40.0, 21.0, &"physical", 4.0, 1).merged({"poise_damage": 4.0}, true),
        "piercing_shot": _entry(&"projectile", 370.0, 8.0, 13.0, &"physical", 2.0, 3, 380.0, 17.0),
        "fan_shot": _entry(&"projectile", 230.0, 30.0, 8.0, &"physical", 1.0, 3, 285.0, 15.0, 3).merged({"sequence_interval_ticks": 2}),
        "backstep_shot": _entry(&"projectile", 285.0, 8.0, 12.0, &"physical", 2.0, 1, 325.0, 15.0).merged({"movement_distance_px": 64.0, "evade_window_ticks": 4}),
        "arcane_lance": _entry(&"projectile", 355.0, 8.0, 15.0, &"arcane", 2.0, 1, 350.0, 16.0),
        "delayed_pulse": _entry(&"pulse", 108.0, 180.0, 17.0, &"arcane", 3.0, 5, 0.0, 0.0, 1, 24),
        "aegis_ward": _entry(&"ward", 78.0, 180.0, 0.0, &"arcane", 0.0, 1, 0.0, 0.0, 1, 0, 90),
    }
    var errors := content.validate_content()
    if not errors.is_empty():
        push_error("Invalid playtest attack content: %s" % str(errors))
        quit(1)
        return
    var status := ResourceSaver.save(content, OUTPUT)
    print("PLAYER PLAYTEST ATTACK CONTENT: %d" % status)
    quit(0 if status == OK else 1)


func _entry(mode: StringName, reach: float, half_angle: float, damage: float,
    domain: StringName, pressure: float, targets: int, speed: float = 0.0,
    radius: float = 0.0, count: int = 1, delay: int = 0, ward_ticks: int = 0) -> Dictionary:
    return {
        "mode": mode,
        "range_px": reach,
        "half_angle_degrees": half_angle,
        "raw_damage": damage,
        "domain": domain,
        "guard_pressure": pressure,
        "poise_damage": 0.0,
        "max_targets": targets,
        "projectile_speed_px_per_second": speed,
        "projectile_hit_radius_px": radius,
        "projectile_count": count,
        "delay_ticks": delay,
        "ward_ticks": ward_ticks,
    }
