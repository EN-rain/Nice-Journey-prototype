extends SceneTree

const OUTPUT := "res://src/data/tuning/status_effects_playtest_v01.tres"


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var values := build_resource()
    if not values.validate_tuning().is_empty():
        push_error("Playtest status tuning failed structural validation")
        quit(1)
        return
    var saved := ResourceSaver.save(values, OUTPUT)
    print("STATUS PLAYTEST TUNING: %d" % saved)
    quit(0 if saved == OK else 1)


# Keep this generator aligned with the shipped Inspector resource. The older
# StatusEffectsPlaytestTuning class is a separate legacy development surface.
static func build_resource() -> StatusPlaytestTuning:
    var values := StatusPlaytestTuning.new()
    values.resource_name = "PLAYTEST Burn and Slow v01 — provisional timing, damage, speed"
    values.playtest_placeholder = true
    values.burn_duration_ticks = 180
    values.burn_tick_interval_ticks = 30
    values.burn_damage_per_tick = 2
    values.slow_duration_ticks = 150
    values.slow_reduction_fraction = 0.25
    values.slow_speed_floor_multiplier = 0.4
    return values
