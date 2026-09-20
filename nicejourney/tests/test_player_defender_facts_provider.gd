extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const STARTER_COMBAT_TUNING: StarterCombatTuning = preload("res://src/data/tuning/starter_combat_default.tres")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_tuning_fails_closed_without_authority()
    await _test_live_provider_uses_authoritative_player_state()

    if _failures == 0:
        print("PLAYER DEFENDER FACTS PROVIDER TEST PASS")
    else:
        push_error("PLAYER DEFENDER FACTS PROVIDER TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_tuning_fails_closed_without_authority() -> void:
    var missing := PlayerDefenderFactsTuning.new()
    _expect(not missing.validate_tuning().is_empty(), "defender-facts tuning stays fail-closed until explicitly authored")

    var movement := MovementTuning.new()
    movement.dodge_duration = 0.12
    var authored := PlayerDefenderFactsTuning.new()
    authored.authored = true
    authored.dodge_invulnerability_start_seconds = 0.08
    authored.dodge_invulnerability_duration_seconds = 0.06
    authored.frontal_coverage_degrees = 120.0
    _expect(
        not authored.validate_tuning(movement).is_empty(),
        "dodge invulnerability interval cannot extend beyond the authored dodge movement duration"
    )
    var shipped := preload("res://src/data/tuning/player_defender_facts_playtest_v01.tres") as PlayerDefenderFactsTuning
    var pending := shipped.production_readiness(movement, STARTER_COMBAT_TUNING)
    _expect(not bool(pending.get("production_ready", true)), "shipped defender windows and facing cone stay PLAYTEST despite valid runtime authoring")
    _expect((pending.get("missing_fields", PackedStringArray()) as PackedStringArray).has("manual_fairness_evidence_id"), "defense requires recorded three-class manual contact fairness evidence")
    var hypothetical := PlayerDefenderFactsTuning.new()
    hypothetical.authored = true
    hypothetical.dodge_invulnerability_start_seconds = 0.015
    hypothetical.dodge_invulnerability_duration_seconds = 0.09
    hypothetical.frontal_coverage_degrees = 120.0
    hypothetical.approved_final_values = true
    hypothetical.approval_reference_id = &"approval:test_only"
    hypothetical.manual_fairness_evidence_id = &"evidence:test_only"
    _expect(not bool(hypothetical.production_readiness(null, STARTER_COMBAT_TUNING).get("production_ready", true)), "production gate requires live dodge movement bounds")
    _expect(bool(hypothetical.production_readiness(movement, STARTER_COMBAT_TUNING).get("production_ready", false)), "hypothetical explicitly approved, bounded defense data passes authoring gate")


func _test_live_provider_uses_authoritative_player_state() -> void:
    var player := PLAYER_SCENE.instantiate() as PlayerController
    var combat := ClassCombatRuntime.new()
    combat.tuning = STARTER_COMBAT_TUNING
    get_root().add_child(player)
    get_root().add_child(combat)
    await process_frame

    _expect(player != null and player.movement != null, "provider fixture owns the real PlayerController movement state")
    _expect(combat.configure_class(&"melee"), "provider fixture configures the real Melee defense runtime")
    if player == null or player.movement == null:
        combat.queue_free()
        return

    var tuning := PlayerDefenderFactsTuning.new()
    tuning.authored = true
    tuning.dodge_invulnerability_start_seconds = 0.02
    tuning.dodge_invulnerability_duration_seconds = 0.05
    tuning.frontal_coverage_degrees = 120.0

    var provider := PlayerDefenderFactsProvider.new()
    var configure_errors := provider.configure(player, combat, tuning)
    _expect(configure_errors.is_empty() and provider.is_configured(), "provider accepts only a complete authored player-defense context")

    player.apply_aim_direction(Vector2.RIGHT)
    var front := provider.make_snapshot(player.global_position + Vector2(32.0, 0.0), player.global_position)
    var behind := provider.make_snapshot(player.global_position + Vector2(-32.0, 0.0), player.global_position)
    _expect(bool(front.get("facing_covered", false)), "frontal coverage uses the player's authoritative combat aim direction")
    _expect(not bool(behind.get("facing_covered", true)), "attacks behind the authored frontal cone are not covered")
    _expect(not PlayerDefenderFactsProvider.is_facing_covered(Vector2.RIGHT, Vector2(INF, 0.0), player.global_position, 120.0), "nonfinite attacker coordinates cannot grant frontal defense")

    _expect(combat.request_block(true), "Melee fixture enters its real block state")
    var blocked := provider.make_snapshot(player.global_position + Vector2(32.0, 0.0), player.global_position)
    _expect(StringName(String(blocked.get("defense_mode", &""))) == DirectHitResolver.DEFENSE_BLOCK, "provider reports the live ClassCombatRuntime defense mode")
    combat.request_block(false)

    _expect(player.movement.try_start_dodge(player.stamina, Vector2.RIGHT), "fixture starts the real authored dodge movement")
    var before_window := provider.make_snapshot(player.global_position + Vector2(32.0, 0.0), player.global_position)
    _expect(not bool(before_window.get("evade_window_active", true)), "dodge movement alone does not imply invulnerability before the authored interval")

    player.movement.tick(player, player.stamina, 0.03)
    var inside_window := provider.make_snapshot(player.global_position + Vector2(32.0, 0.0), player.global_position)
    _expect(bool(inside_window.get("evade_window_active", false)), "provider activates dodge invulnerability only inside the authored interval")

    player.movement.tick(player, player.stamina, 0.06)
    var after_window := provider.make_snapshot(player.global_position + Vector2(32.0, 0.0), player.global_position)
    _expect(not bool(after_window.get("evade_window_active", true)), "dodge invulnerability ends independently of the remaining dodge movement")

    tuning.dodge_invulnerability_duration_seconds = player.movement.tuning.dodge_duration + 1.0
    _expect(provider.make_snapshot(player.global_position + Vector2.RIGHT, player.global_position).is_empty(), "mutating authored dodge bounds after configure cannot grant a stale defender snapshot")

    _expect(
        not PlayerDefenderFactsProvider.is_facing_covered(Vector2.RIGHT, Vector2.ZERO, Vector2.ZERO, 120.0),
        "undefined attacker direction fails closed instead of fabricating facing coverage"
    )

    player.queue_free()
    combat.queue_free()
    await process_frame


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
