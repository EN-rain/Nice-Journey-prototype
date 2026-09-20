extends SceneTree

const OUTPUT := "res://src/data/tuning/status_effects_playtest_v01.tres"


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var values := StatusEffectsPlaytestTuning.new()
    values.resource_name = "PLAYTEST Burn Slow v01 — provisional values, no production claim"
    values.playtest_placeholder = true
    values.burn_duration_ticks = 180
    values.burn_tick_interval_ticks = 60
    values.burn_damage_per_tick = 3.0
    values.slow_duration_ticks = 150
    values.slow_speed_reduction = 0.25
    values.minimum_speed_multiplier = 0.6
    if not values.validate_tuning().is_empty():
        push_error("Playtest status tuning failed structural validation")
        quit(1)
        return
    var saved := ResourceSaver.save(values, OUTPUT)
    print("STATUS PLAYTEST TUNING: %d" % saved)
    quit(0 if saved == OK else 1)
