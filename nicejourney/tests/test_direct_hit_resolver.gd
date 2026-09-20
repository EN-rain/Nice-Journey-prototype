extends SceneTree

var _failures: int = 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_dodge_and_defense_order()
	_test_block_outcomes()
	_test_parry_outcomes()
	_test_damage_domains_and_rounding()
	_test_critical_and_weak_point_selection()
	_test_malformed_inputs()
	_test_determinism_and_nonmutation()

	if _failures == 0:
		print("DIRECT HIT RESOLVER TEST PASS")
	else:
		push_error("DIRECT HIT RESOLVER TEST FAILURES: %d" % _failures)
	quit(_failures)


func _test_dodge_and_defense_order() -> void:
	var attack: Dictionary = _base_attack()
	attack["dodgeable"] = true
	attack["blockable"] = true
	attack["guard_pressure"] = 10.0
	var defender: Dictionary = _base_defender()
	defender["evade_window_active"] = true
	defender["defense_mode"] = &"block"
	defender["block_supported"] = true
	defender["facing_covered"] = true
	defender["current_stamina"] = 25.0

	var dodged: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(dodged["accepted"] and dodged["outcome"] == DirectHitResolver.OUTCOME_DODGED, "authored evade window resolves a dodgeable hit before defense")
	_expect(dodged["hp_damage"] == 0 and is_equal_approx(dodged["stamina_spent"], 0.0), "dodging prevents HP damage without spending block pressure")

	attack["dodgeable"] = false
	var blocked_after_failed_dodge: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(blocked_after_failed_dodge["outcome"] == DirectHitResolver.OUTCOME_BLOCKED, "non-dodgeable hit continues into the selected valid defense")


func _test_block_outcomes() -> void:
	var attack: Dictionary = _base_attack()
	attack["blockable"] = true
	attack["guard_pressure"] = 10.0
	var defender: Dictionary = _base_defender()
	defender["defense_mode"] = &"block"
	defender["block_supported"] = true
	defender["facing_covered"] = true

	defender["current_stamina"] = 10.0
	var exact: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(exact["outcome"] == DirectHitResolver.OUTCOME_BLOCKED and exact["hp_damage"] == 0, "stamina exactly equal to guard pressure succeeds with zero HP damage")
	_expect(is_equal_approx(exact["stamina_after"], 0.0) and is_equal_approx(exact["stamina_spent"], 10.0) and not exact["guard_break"], "exact block boundary spends authored pressure without guard break")

	defender["current_stamina"] = 15.0
	var surplus: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(is_equal_approx(surplus["stamina_after"], 5.0) and is_equal_approx(surplus["stamina_spent"], 10.0), "successful block preserves the exact stamina remainder")

	defender["current_stamina"] = 9.0
	var broken: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(broken["outcome"] == DirectHitResolver.OUTCOME_GUARD_BROKEN and broken["guard_break"], "insufficient block stamina triggers guard break")
	_expect(is_equal_approx(broken["stamina_after"], 0.0) and is_equal_approx(broken["stamina_spent"], 9.0), "guard break consumes only the available stamina")
	_expect(broken["hp_damage"] == 10, "guard-broken hit resolves normal HP damage")

	defender["current_stamina"] = 15.0
	attack["blockable"] = false
	var ineligible: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(ineligible["outcome"] == DirectHitResolver.OUTCOME_HIT and ineligible["hp_damage"] == 10, "unblockable hit resolves normally through a selected block")
	_expect(is_equal_approx(ineligible["stamina_after"], 15.0) and is_equal_approx(ineligible["stamina_spent"], 0.0) and not ineligible["guard_break"], "ineligible block spends no stamina and cannot guard-break")

	attack["blockable"] = true
	defender["facing_covered"] = false
	var uncovered: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(uncovered["outcome"] == DirectHitResolver.OUTCOME_HIT and is_equal_approx(uncovered["stamina_spent"], 0.0), "block outside authored facing coverage fails without spending stamina")


func _test_parry_outcomes() -> void:
	var attack: Dictionary = _base_attack()
	attack["parryable"] = true
	var defender: Dictionary = _base_defender()
	defender["defense_mode"] = &"parry"
	defender["parry_supported"] = true
	defender["facing_covered"] = true

	var parried: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(parried["outcome"] == DirectHitResolver.OUTCOME_PARRIED and parried["hp_damage"] == 0, "supported facing parry negates an authored parryable contact hit")
	_expect(parried["attacker_interrupt_requested"], "successful parry requests the authored attacker interrupt/recovery response")

	defender["facing_covered"] = false
	var missed: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(missed["outcome"] == DirectHitResolver.OUTCOME_HIT and not missed["attacker_interrupt_requested"], "parry outside facing coverage resolves as a normal hit")

	defender["facing_covered"] = true
	defender["parry_supported"] = false
	var unsupported: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(unsupported["outcome"] == DirectHitResolver.OUTCOME_HIT, "unsupported parry capability cannot negate a hit")

	var invalid_projectile: Dictionary = _base_attack()
	invalid_projectile["delivery"] = &"projectile"
	invalid_projectile["parryable"] = true
	var rejected: Dictionary = DirectHitResolver.resolve(invalid_projectile, defender)
	_expect(not rejected["accepted"] and rejected["reason_id"] == DirectHitResolver.REASON_PROJECTILE_PARRYABLE, "projectile authored as parryable is rejected before resolution")

	invalid_projectile["parryable"] = false
	defender["parry_supported"] = true
	var projectile_hit: Dictionary = DirectHitResolver.resolve(invalid_projectile, defender)
	_expect(projectile_hit["outcome"] == DirectHitResolver.OUTCOME_HIT and not projectile_hit["attacker_interrupt_requested"], "prototype projectile cannot be parried or reflected")


func _test_damage_domains_and_rounding() -> void:
	var attack: Dictionary = _base_attack()
	var defender: Dictionary = _base_defender()
	defender["physical_defense"] = 100.0
	defender["arcane_defense"] = 0.0

	attack["domain"] = &"physical"
	var physical: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(physical["hp_damage"] == 5 and is_equal_approx(physical["applied_mitigation"], 100.0), "Physical hit uses only Physical Defense")

	attack["domain"] = &"arcane"
	var arcane: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(arcane["hp_damage"] == 10 and is_equal_approx(arcane["applied_mitigation"], 0.0), "Arcane hit uses only Arcane Defense")

	attack["domain"] = &"physical"
	defender["physical_defense"] = -50.0
	var negative_rating: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(negative_rating["hp_damage"] == 10 and is_equal_approx(negative_rating["applied_mitigation"], 0.0), "negative mitigation rating clamps to zero")

	attack["raw_damage"] = 5.0
	defender["physical_defense"] = 100.0
	var half_up: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(half_up["hp_damage"] == 3, "2.5 mitigated damage rounds upward to 3")

	attack["raw_damage"] = 4.98
	var below_half: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(below_half["hp_damage"] == 2, "mitigated damage below the half boundary rounds down")

	attack["raw_damage"] = 0.1
	defender["physical_defense"] = 10000.0
	var minimum: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(minimum["hp_damage"] == 1, "positive damaging hit clamps to at least 1 HP after mitigation")

	attack["raw_damage"] = 0.0
	attack["critical_triggered"] = true
	attack["critical_multiplier"] = 4.0
	var zero_damage: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(zero_damage["hp_damage"] == 0, "non-damaging direct hit remains zero after bonuses and mitigation")


func _test_critical_and_weak_point_selection() -> void:
	var attack: Dictionary = _base_attack()
	var defender: Dictionary = _base_defender()

	attack["critical_triggered"] = true
	attack["critical_multiplier"] = 2.0
	var crit_only: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(crit_only["hp_damage"] == 20 and is_equal_approx(crit_only["selected_multiplier"], 2.0), "critical-only direct hit uses its authored multiplier")

	attack["critical_triggered"] = false
	attack["weak_point_triggered"] = true
	attack["weak_point_multiplier"] = 2.5
	var weak_only: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(weak_only["hp_damage"] == 25 and is_equal_approx(weak_only["selected_multiplier"], 2.5), "weak-point-only direct hit uses its authored multiplier")

	attack["critical_triggered"] = true
	attack["critical_multiplier"] = 2.0
	attack["weak_point_multiplier"] = 3.0
	var both: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(both["hp_damage"] == 30 and is_equal_approx(both["selected_multiplier"], 3.0), "critical plus weak point uses the greater multiplier and never multiplies them")

	attack["weak_point_multiplier"] = 2.0
	var tie: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(tie["hp_damage"] == 20 and is_equal_approx(tie["selected_multiplier"], 2.0), "equal critical and weak-point bonuses remain one multiplier")


func _test_malformed_inputs() -> void:
	var attack: Dictionary = _base_attack()
	var defender: Dictionary = _base_defender()
	_expect(not DirectHitResolver.resolve(null, defender)["accepted"], "non-dictionary attack is rejected")
	_expect(not DirectHitResolver.resolve(attack, null)["accepted"], "non-dictionary defender is rejected")

	var missing: Dictionary = attack.duplicate(true)
	missing.erase("raw_damage")
	_expect(not DirectHitResolver.resolve(missing, defender)["accepted"], "missing required attack field is rejected")

	var bad_domain: Dictionary = attack.duplicate(true)
	bad_domain["domain"] = &"fire"
	_expect(not DirectHitResolver.resolve(bad_domain, defender)["accepted"], "unknown damage domain is rejected")
	var bad_delivery: Dictionary = attack.duplicate(true)
	bad_delivery["delivery"] = &"beam"
	_expect(not DirectHitResolver.resolve(bad_delivery, defender)["accepted"], "unknown delivery kind is rejected")
	var bad_mode: Dictionary = defender.duplicate(true)
	bad_mode["defense_mode"] = &"perfect_parry"
	_expect(not DirectHitResolver.resolve(attack, bad_mode)["accepted"], "unknown defense mode is rejected")

	var wrong_bool: Dictionary = attack.duplicate(true)
	wrong_bool["dodgeable"] = 1
	_expect(not DirectHitResolver.resolve(wrong_bool, defender)["accepted"], "non-boolean eligibility fact is rejected")

	for key: String in ["raw_damage", "guard_pressure", "critical_multiplier", "weak_point_multiplier"]:
		for value: float in [NAN, INF, -INF]:
			var invalid_numeric: Dictionary = attack.duplicate(true)
			invalid_numeric[key] = value
			_expect(not DirectHitResolver.resolve(invalid_numeric, defender)["accepted"], "nonfinite attack numeric %s is rejected" % key)

	for key: String in ["current_stamina", "physical_defense", "arcane_defense"]:
		for value: float in [NAN, INF, -INF]:
			var invalid_numeric: Dictionary = defender.duplicate(true)
			invalid_numeric[key] = value
			_expect(not DirectHitResolver.resolve(attack, invalid_numeric)["accepted"], "nonfinite defender numeric %s is rejected" % key)

	var negative_raw: Dictionary = attack.duplicate(true)
	negative_raw["raw_damage"] = -1.0
	_expect(not DirectHitResolver.resolve(negative_raw, defender)["accepted"], "negative raw damage is rejected")
	var negative_pressure: Dictionary = attack.duplicate(true)
	negative_pressure["guard_pressure"] = -1.0
	_expect(not DirectHitResolver.resolve(negative_pressure, defender)["accepted"], "negative guard pressure is rejected")
	var bad_multiplier: Dictionary = attack.duplicate(true)
	bad_multiplier["critical_multiplier"] = 0.99
	_expect(not DirectHitResolver.resolve(bad_multiplier, defender)["accepted"], "bonus multiplier below 1 is rejected")
	var negative_stamina: Dictionary = defender.duplicate(true)
	negative_stamina["current_stamina"] = -1.0
	_expect(not DirectHitResolver.resolve(attack, negative_stamina)["accepted"], "negative current stamina is rejected")

	var negative_defense: Dictionary = defender.duplicate(true)
	negative_defense["physical_defense"] = -999.0
	_expect(DirectHitResolver.resolve(attack, negative_defense)["accepted"], "finite negative mitigation rating is legal and clamps during damage resolution")


func _test_determinism_and_nonmutation() -> void:
	var attack: Dictionary = _base_attack()
	attack["critical_triggered"] = true
	attack["critical_multiplier"] = 2.0
	var defender: Dictionary = _base_defender()
	defender["physical_defense"] = 25.0
	var attack_before: Dictionary = attack.duplicate(true)
	var defender_before: Dictionary = defender.duplicate(true)

	var first: Dictionary = DirectHitResolver.resolve(attack, defender)
	var second: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(first == second, "identical direct-hit inputs resolve deterministically")
	_expect(attack == attack_before and defender == defender_before, "direct-hit resolution does not mutate caller dictionaries")

	first["hp_damage"] = 999
	first["outcome"] = &"tampered"
	var third: Dictionary = DirectHitResolver.resolve(attack, defender)
	_expect(third == second, "mutating a returned result cannot affect later resolution or caller state")


func _base_attack() -> Dictionary:
	return {
		"domain": &"physical",
		"delivery": &"contact",
		"raw_damage": 10.0,
		"dodgeable": false,
		"blockable": false,
		"parryable": false,
		"guard_pressure": 0.0,
		"critical_triggered": false,
		"critical_multiplier": 1.0,
		"weak_point_triggered": false,
		"weak_point_multiplier": 1.0,
	}


func _base_defender() -> Dictionary:
	return {
		"evade_window_active": false,
		"defense_mode": &"none",
		"block_supported": false,
		"parry_supported": false,
		"facing_covered": false,
		"current_stamina": 100.0,
		"physical_defense": 0.0,
		"arcane_defense": 0.0,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)
