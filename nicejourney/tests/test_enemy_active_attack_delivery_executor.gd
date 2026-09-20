extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_attack_authoring_validation_boundary()
    _test_active_window_and_contact_identity()
    _test_missing_signature_authoring_is_explicit()
    _test_authored_contact_requires_matching_geometry_facts()
    _test_parry_interrupts_through_phase_owner()
    _test_fatal_target_invalidation_closes_delivery()
    if _failures == 0:
        print("ENEMY ACTIVE ATTACK DELIVERY EXECUTOR TEST PASS")
    else:
        push_error("ENEMY ACTIVE ATTACK DELIVERY EXECUTOR TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_attack_authoring_validation_boundary() -> void:
    var geometry := EnemyAttackGeometryAuthoring.new()
    geometry.authored = true
    geometry.geometry_id = &"geometry:validation_fixture"
    var geometry_errors := geometry.validate_authoring()
    _expect(str(geometry_errors).contains("query_shape") and str(geometry_errors).contains("max_reach_px"), "geometry authoring rejects missing shape and exact reach instead of inferring them from presentation")
    _expect(str(geometry_errors).contains("collision_mask") and str(geometry_errors).contains("hit_interval_count"), "geometry authoring requires an explicit target mask and hit-interval count")

    var payload := EnemyAttackPayloadAuthoring.new()
    payload.authored = true
    payload.damage_domain = DirectHitResolver.DOMAIN_PHYSICAL
    payload.delivery = DirectHitResolver.DELIVERY_PROJECTILE
    payload.parryable = true
    _expect(str(payload.validate_authoring()).contains("projectiles cannot be parryable"), "payload authoring enforces the resolved DR-06 projectile-parry rule")


func _test_missing_signature_authoring_is_explicit() -> void:
    var fixture := _fixture(&"encounter:enemy_delivery_missing_authoring", &"enemy:delivery_missing_authoring")
    var encounter := fixture["encounter"] as CombatEncounterRuntime
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var driver := fixture["driver"] as EnemySignatureActionPhaseDriver
    var executor := fixture["executor"] as EnemyActiveAttackDeliveryExecutor
    runtime.definition.signature_attack_authoring = null # Explicit missing-data negative fixture; shipped duelist now has provisional authoring.
    var action_instance_id := 80501
    var selection := runtime.choose_tactic(_selector_context(), {})
    _expect(bool(driver.begin(selection, action_instance_id, {}).get("accepted", false)), "missing-authoring fixture commits signature action")
    _advance_to_active(driver, &"duelist")
    var delivery_context := runtime.get_active_delivery_context(action_instance_id)
    _expect(not bool(delivery_context.get("attack_authoring_ready", true)), "ACTIVE delivery context reports missing per-archetype attack authoring")
    _expect(not (delivery_context.get("attack_authoring_errors", PackedStringArray()) as PackedStringArray).is_empty(), "missing attack authoring exposes concrete validation errors")
    var result := executor.resolve_authored_contact(
        _contact_facts(runtime, action_instance_id, 0, &"geometry:missing"),
        false,
        DirectHitResolver.DEFENSE_NONE,
        false
    )
    _expect(not bool(result.get("accepted", false)) and StringName(result.get("reason_id", &"")) == EnemyActiveAttackDeliveryExecutor.REASON_ATTACK_AUTHORING_UNAVAILABLE, "production authored-contact path fails closed while archetype combat values are absent")
    encounter.end_encounter()


func _test_authored_contact_requires_matching_geometry_facts() -> void:
    var fixture := _fixture(&"encounter:enemy_delivery_authored", &"enemy:delivery_authored")
    var encounter := fixture["encounter"] as CombatEncounterRuntime
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var driver := fixture["driver"] as EnemySignatureActionPhaseDriver
    var executor := fixture["executor"] as EnemyActiveAttackDeliveryExecutor
    var player := fixture["player"] as CombatantRuntimeState
    runtime.definition.signature_attack_authoring = _authored_duelist_attack()
    _expect(runtime.definition.validate_signature_attack_authoring().is_empty(), "synthetic authored signature attack validates independently of production balance data")

    var action_instance_id := 80601
    var selection := runtime.choose_tactic(_selector_context(), {})
    _expect(bool(driver.begin(selection, action_instance_id, {}).get("accepted", false)), "authored-contact fixture commits signature action")
    _advance_to_active(driver, &"duelist")
    var delivery_context := runtime.get_active_delivery_context(action_instance_id)
    _expect(bool(delivery_context.get("attack_authoring_ready", false)), "ACTIVE delivery context reports complete attack authoring when exact geometry/payload resources exist")

    var wrong_geometry := executor.resolve_authored_contact(
        _contact_facts(runtime, action_instance_id, 0, &"geometry:wrong"), false, DirectHitResolver.DEFENSE_NONE, false
    )
    _expect(not bool(wrong_geometry.get("accepted", false)) and StringName(wrong_geometry.get("reason_id", &"")) == EnemyActiveAttackDeliveryExecutor.REASON_GEOMETRY_MISMATCH, "contact from a different geometry owner cannot authorize delivery")
    _expect(player.current_hp == player.max_hp and not encounter.contacts.has_contact(action_instance_id, player.actor_id, 0), "geometry mismatch cannot consume contact identity or mutate HP")

    var unconfirmed_facts := _contact_facts(runtime, action_instance_id, 0, &"geometry:duelist_lunge")
    unconfirmed_facts["contact_confirmed"] = false
    var unconfirmed := executor.resolve_authored_contact(unconfirmed_facts, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(not bool(unconfirmed.get("accepted", false)) and StringName(unconfirmed.get("reason_id", &"")) == EnemyActiveAttackDeliveryExecutor.REASON_CONTACT_NOT_CONFIRMED, "geometry owner must explicitly confirm contact before payload delivery")

    var out_of_range := executor.resolve_authored_contact(
        _contact_facts(runtime, action_instance_id, 1, &"geometry:duelist_lunge"), false, DirectHitResolver.DEFENSE_NONE, false
    )
    _expect(not bool(out_of_range.get("accepted", false)) and StringName(out_of_range.get("reason_id", &"")) == EnemyActiveAttackDeliveryExecutor.REASON_HIT_INTERVAL_OUT_OF_RANGE, "authored hit-interval count rejects invented extra hits")

    var valid := executor.resolve_authored_contact(
        _contact_facts(runtime, action_instance_id, 0, &"geometry:duelist_lunge"), false, DirectHitResolver.DEFENSE_NONE, false
    )
    _expect(bool(valid.get("accepted", false)) and int(valid.get("hp_damage", 0)) == 10, "matching caller-owned geometry facts resolve the authored payload through DR-06")
    _expect(player.current_hp == player.max_hp - 10 and encounter.contacts.has_contact(action_instance_id, player.actor_id, 0), "authored-contact path records one authoritative contact and applies only the authored damage")
    encounter.end_encounter()


func _test_active_window_and_contact_identity() -> void:
    var fixture := _fixture(&"encounter:enemy_delivery_contact", &"enemy:delivery_contact")
    var encounter := fixture["encounter"] as CombatEncounterRuntime
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var driver := fixture["driver"] as EnemySignatureActionPhaseDriver
    var executor := fixture["executor"] as EnemyActiveAttackDeliveryExecutor
    var player := fixture["player"] as CombatantRuntimeState
    var action_instance_id := 81001
    var selection := runtime.choose_tactic(_selector_context(), {})
    _expect(bool(driver.begin(selection, action_instance_id, {}).get("accepted", false)), "delivery fixture commits through the authoritative signature owner")

    var before_active := executor.resolve_authorized_contact(
        action_instance_id, 0, _attack(10.0), false, DirectHitResolver.DEFENSE_NONE, false
    )
    _expect(not bool(before_active.get("accepted", false)) and StringName(before_active.get("reason_id", &"")) == EnemyActiveAttackDeliveryExecutor.REASON_ACTIVE_WINDOW_UNAVAILABLE, "windup cannot resolve attack delivery")
    _expect(player.current_hp == player.max_hp and not encounter.contacts.has_contact(action_instance_id, player.actor_id, 0), "rejected windup delivery cannot mutate HP or contact identity")

    _advance_to_active(driver, &"duelist")
    var invalid_interval := executor.resolve_authorized_contact(
        action_instance_id, -1, _attack(10.0), false, DirectHitResolver.DEFENSE_NONE, false
    )
    _expect(not bool(invalid_interval.get("accepted", false)) and StringName(invalid_interval.get("reason_id", &"")) == EnemyActiveAttackDeliveryExecutor.REASON_INVALID_HIT_INTERVAL, "negative hit interval is rejected before combat resolution")

    var invalid_payload := executor.resolve_authorized_contact(
        action_instance_id, 0, {}, false, DirectHitResolver.DEFENSE_NONE, false
    )
    _expect(not bool(invalid_payload.get("accepted", false)) and StringName(invalid_payload.get("reason_id", &"")) == DirectHitResolver.REASON_INVALID_ATTACK, "DR-06 rejects an unauthored/invalid attack payload")
    _expect(not encounter.contacts.has_contact(action_instance_id, player.actor_id, 0), "invalid payload does not consume the active action contact interval")

    var valid := executor.resolve_authorized_contact(
        action_instance_id, 0, _attack(10.0), false, DirectHitResolver.DEFENSE_NONE, false
    )
    _expect(bool(valid.get("accepted", false)) and StringName(valid.get("outcome", &"")) == DirectHitResolver.OUTCOME_HIT, "caller-supplied valid payload resolves through DR-06 during ACTIVE")
    _expect(player.current_hp == player.max_hp - 10 and encounter.contacts.has_contact(action_instance_id, player.actor_id, 0), "accepted delivery mutates the configured target once and records contact identity")
    var context := valid.get("delivery_context", {}) as Dictionary
    _expect(StringName(context.get("actor_id", &"")) == runtime.actor_id and StringName(context.get("target_id", &"")) == player.actor_id, "resolved delivery remains bound to committed actor/target identity")

    var duplicate := executor.resolve_authorized_contact(
        action_instance_id, 0, _attack(10.0), false, DirectHitResolver.DEFENSE_NONE, false
    )
    _expect(not bool(duplicate.get("accepted", false)) and StringName(duplicate.get("reason_id", &"")) == &"duplicate_contact", "same action/target/hit interval cannot damage twice")
    _expect(player.current_hp == player.max_hp - 10, "duplicate delivery rejection leaves HP unchanged")
    encounter.end_encounter()


func _test_parry_interrupts_through_phase_owner() -> void:
    var fixture := _fixture(&"encounter:enemy_delivery_parry", &"enemy:delivery_parry")
    var encounter := fixture["encounter"] as CombatEncounterRuntime
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var driver := fixture["driver"] as EnemySignatureActionPhaseDriver
    var executor := fixture["executor"] as EnemyActiveAttackDeliveryExecutor
    var action_instance_id := 82001
    var selection := runtime.choose_tactic(_selector_context(), {})
    _expect(bool(driver.begin(selection, action_instance_id, {}).get("accepted", false)), "parry fixture commits signature action")
    _advance_to_active(driver, &"duelist")

    var parried := executor.resolve_authorized_contact(
        action_instance_id, 0, _attack(12.0), false, DirectHitResolver.DEFENSE_PARRY, true
    )
    _expect(bool(parried.get("accepted", false)) and StringName(parried.get("outcome", &"")) == DirectHitResolver.OUTCOME_PARRIED, "supported facing parry resolves against enemy ACTIVE delivery")
    _expect(bool(parried.get("attacker_interrupt_requested", false)) and bool(parried.get("attacker_interrupt_applied", false)), "parry interruption is applied through the authoritative phase driver")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE and driver.action_instance_id == 0, "parry clears runtime and phase-driver committed action identity together")
    _expect(encounter.reservations.get_active_count() == 0 and encounter.attack_pressure.get_active_count() == 0, "parry interruption releases reservation and global pressure ownership")
    _expect(not bool(runtime.get_active_delivery_context(action_instance_id).get("accepted", false)), "parried action cannot expose another ACTIVE delivery window")
    encounter.end_encounter()


func _test_fatal_target_invalidation_closes_delivery() -> void:
    var fixture := _fixture(&"encounter:enemy_delivery_fatal", &"enemy:delivery_fatal")
    var encounter := fixture["encounter"] as CombatEncounterRuntime
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var driver := fixture["driver"] as EnemySignatureActionPhaseDriver
    var executor := fixture["executor"] as EnemyActiveAttackDeliveryExecutor
    var player := fixture["player"] as CombatantRuntimeState
    var action_instance_id := 83001
    var selection := runtime.choose_tactic(_selector_context(), {})
    _expect(bool(driver.begin(selection, action_instance_id, {}).get("accepted", false)), "fatal-target fixture commits signature action")
    _advance_to_active(driver, &"duelist")

    var fatal := executor.resolve_authorized_contact(
        action_instance_id, 0, _attack(500.0), false, DirectHitResolver.DEFENSE_NONE, false
    )
    _expect(bool(fatal.get("accepted", false)) and bool(fatal.get("target_defeated", false)) and player.is_defeated(), "authorized ACTIVE delivery may defeat its configured target through DR-06")
    _expect(encounter.reservations.get_active_count() == 0 and encounter.attack_pressure.get_active_count() == 0, "target defeat immediately releases committed attack ownership")
    _expect(not bool(runtime.get_active_delivery_context(action_instance_id).get("accepted", false)), "target invalidation closes delivery authority immediately")
    _expect(driver.advance_fixed_tick(), "phase driver reconciles externally released fatal-target action")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE and driver.action_instance_id == 0, "fatal target reconciliation clears obsolete runtime and phase-driver identity")
    encounter.end_encounter()


func _fixture(encounter_id: StringName, enemy_id: StringName) -> Dictionary:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(encounter_id), "delivery fixture encounter configures")
    var player := CombatantRuntimeState.new()
    var enemy := CombatantRuntimeState.new()
    _expect(player.configure(&"player:enemy_delivery", 100, 100.0, 0.0, 0.0, 20.0, true, true, true), "delivery fixture player validates with block/parry support")
    _expect(enemy.configure(enemy_id, 100, 0.0, 0.0, 0.0, 20.0, true, false, false), "delivery fixture enemy validates")
    _expect(encounter.register_player(player) and encounter.register_enemy(enemy), "delivery fixture combatants register")
    var runtime := EnemyArchetypeRuntime.new()
    _expect(runtime.configure(encounter, enemy.actor_id, player.actor_id, &"duelist"), "delivery fixture archetype runtime configures")
    var driver := EnemySignatureActionPhaseDriver.new()
    _expect(driver.configure(runtime, EnemySignatureActionTimingCatalog.get_timing(&"duelist")), "delivery fixture phase driver configures")
    var executor := EnemyActiveAttackDeliveryExecutor.new()
    _expect(executor.configure(runtime, driver), "delivery executor binds exact runtime and phase owner")
    return {
        "encounter": encounter,
        "runtime": runtime,
        "driver": driver,
        "executor": executor,
        "player": player,
        "enemy": enemy,
    }


func _advance_to_active(driver: EnemySignatureActionPhaseDriver, archetype_id: StringName) -> void:
    var windup_ticks := int(EnemySignatureActionTimingCatalog.get_timing(archetype_id).get("windup_ticks", 0))
    for _index: int in range(windup_ticks):
        _expect(driver.advance_fixed_tick(), "delivery fixture windup tick advances")
    _expect(driver.runtime.phase_id == EnemyArchetypeRuntime.PHASE_ACTIVE, "delivery fixture reaches ACTIVE at authored timing boundary")


func _selector_context() -> Dictionary:
    return {
        "target_visible": true,
        "observation_confidence": 1.0,
        "reaction_delay_satisfied": true,
        "distance_band": EnemyArchetypeDefinition.RANGE_CLOSE,
        "reservation_available": true,
        "cooldown_ready": true,
        "objective_contested": false,
        "observed_player_recovering": true,
        "observed_player_committed": false,
        "observation_age_ticks": 0,
    }


func _attack(raw_damage: float) -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": raw_damage,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 5.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }


func _authored_duelist_attack() -> EnemySignatureAttackAuthoring:
    var geometry := EnemyAttackGeometryAuthoring.new()
    geometry.authored = true
    geometry.geometry_id = &"geometry:duelist_lunge"
    var shape := CircleShape2D.new()
    shape.radius = 12.0
    geometry.query_shape = shape
    geometry.max_reach_px = 32.0
    geometry.collision_mask = 2
    geometry.hit_interval_count = 1

    var payload := EnemyAttackPayloadAuthoring.new()
    payload.authored = true
    payload.damage_domain = DirectHitResolver.DOMAIN_PHYSICAL
    payload.delivery = DirectHitResolver.DELIVERY_CONTACT
    payload.raw_damage = 10.0
    payload.guard_pressure = 5.0
    payload.dodgeable = true
    payload.blockable = true
    payload.parryable = true
    payload.critical_multiplier = 1.5
    payload.weak_point_multiplier = 1.5

    var authoring := EnemySignatureAttackAuthoring.new()
    authoring.action_id = &"action:duelist_lunge"
    authoring.geometry = geometry
    authoring.payload = payload
    return authoring


func _contact_facts(
    runtime: EnemyArchetypeRuntime,
    action_instance_id: int,
    hit_interval_index: int,
    geometry_id: StringName
) -> Dictionary:
    return {
        "actor_id": runtime.actor_id,
        "target_id": runtime.target_id,
        "action_id": runtime.definition.signature_action_id,
        "action_instance_id": action_instance_id,
        "hit_interval_index": hit_interval_index,
        "geometry_id": geometry_id,
        "contact_confirmed": true,
        "critical_triggered": false,
        "weak_point_triggered": false,
    }


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
