extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const PLAYER_TUNING: PlayerCombatRuntimeTuning = preload("res://src/data/tuning/player_combat_runtime_default.tres")
var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    for class_id: String in ["melee", "ranged", "mage"]:
        await _verify(class_id)
    if _failures == 0:
        print("GAMEPLAY OPT-IN COMBAT BALANCE CAPTURE TEST PASS")
    else:
        push_error("GAMEPLAY OPT-IN COMBAT BALANCE CAPTURE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _verify(class_id: String) -> void:
    var profile := ProfileCreationService.create_profile(1, "Balance " + class_id, class_id)
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    root.add_child(game)
    await process_frame
    var encounter := CombatEncounterRuntime.new()
    var player_state := PlayerCombatantRuntimeBinding.create_state(
        game.player, game.combat_runtime, PLAYER_TUNING, &"player:local")
    var enemy := CombatantRuntimeState.new()
    _expect(player_state != null and enemy.configure(&"enemy:balance_capture", 50, 0.0,
        0.0, 0.0, 20.0, true, false, false), "%s: real player and fixture enemy" % class_id)
    if player_state == null:
        game.queue_free()
        await process_frame
        return
    _expect(encounter.configure(StringName("encounter:capture:%s" % class_id))
        and encounter.register_player(player_state) and encounter.register_enemy(enemy),
        "%s: live encounter registered" % class_id)
    game._on_region3_side_encounter_started(encounter.encounter_id, encounter)
    _expect((game.get_balance_capture_report()["rows"] as Array).is_empty(),
        "%s: default-off capture does not observe a live encounter" % class_id)
    game.set_balance_capture_enabled(true)
    _expect((game.get_balance_capture_report()["rows"] as Array).size() == 1,
        "%s: enabling mid-encounter binds current authoritative signals" % class_id)
    var contact := encounter.resolve_direct_contact(player_state.actor_id, enemy.actor_id,
        7001, 0, game.combat_runtime.make_basic_attack_payload(),
        false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(contact.get("accepted", false)), "%s: live class basic hit resolves" % class_id)
    var current := game.get_balance_capture_report()
    var captured := (current["rows"] as Array)[0] as Dictionary
    _expect(captured["damage_dealt"] == int(contact["hp_damage"])
        and not bool(captured["capture_complete"]), "%s: live hit recorded without mutation" % class_id)
    game._on_region3_side_encounter_ended(encounter.encounter_id)
    var ended := (game.get_balance_capture_report()["rows"] as Array)[0] as Dictionary
    _expect(bool(ended["capture_complete"]) and ended["damage_dealt"] == captured["damage_dealt"],
        "%s: encounter teardown preserves completed trace" % class_id)
    game.set_balance_capture_enabled(false)
    _expect(not game.collect_combat_balance_telemetry
        and (game.get_balance_capture_report()["rows"] as Array).size() == 1,
        "%s: stop leaves completed trace readable and prevents future attachment" % class_id)
    encounter.end_encounter()
    game.queue_free()
    await process_frame


func _expect(ok: bool, label: String) -> void:
    if not ok:
        _failures += 1
        push_error("FAIL: " + label)
