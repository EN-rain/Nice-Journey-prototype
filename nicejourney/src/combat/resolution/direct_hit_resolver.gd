class_name DirectHitResolver
extends RefCounted

const DOMAIN_PHYSICAL: StringName = &"physical"
const DOMAIN_ARCANE: StringName = &"arcane"

const DELIVERY_CONTACT: StringName = &"contact"
const DELIVERY_PROJECTILE: StringName = &"projectile"

const DEFENSE_NONE: StringName = &"none"
const DEFENSE_BLOCK: StringName = &"block"
const DEFENSE_PARRY: StringName = &"parry"

const OUTCOME_REJECTED: StringName = &"rejected"
const OUTCOME_HIT: StringName = &"hit"
const OUTCOME_DODGED: StringName = &"dodged"
const OUTCOME_BLOCKED: StringName = &"blocked"
const OUTCOME_GUARD_BROKEN: StringName = &"guard_broken"
const OUTCOME_PARRIED: StringName = &"parried"

const REASON_INVALID_ATTACK: StringName = &"invalid_attack"
const REASON_INVALID_DEFENDER: StringName = &"invalid_defender"
const REASON_PROJECTILE_PARRYABLE: StringName = &"projectile_parryable"
const REASON_NONFINITE_RESULT: StringName = &"nonfinite_result"


static func resolve(raw_attack: Variant, raw_defender: Variant) -> Dictionary:
	var attack_error: StringName = _validate_attack(raw_attack)
	if attack_error != &"":
		return _rejected(attack_error)

	var defender_error: StringName = _validate_defender(raw_defender)
	if defender_error != &"":
		return _rejected(defender_error)

	var attack: Dictionary = raw_attack as Dictionary
	var defender: Dictionary = raw_defender as Dictionary
	var current_stamina: float = float(defender["current_stamina"])

	if bool(defender["evade_window_active"]) and bool(attack["dodgeable"]):
		return _resolved(OUTCOME_DODGED, 0, current_stamina, 0.0, false, false, 1.0, 0.0)

	var defense_mode: StringName = StringName(String(defender["defense_mode"]))
	var facing_covered: bool = bool(defender["facing_covered"])

	if defense_mode == DEFENSE_PARRY:
		var parry_succeeds: bool = (
			bool(defender["parry_supported"])
			and bool(attack["parryable"])
			and StringName(String(attack["delivery"])) == DELIVERY_CONTACT
			and facing_covered
		)
		if parry_succeeds:
			return _resolved(OUTCOME_PARRIED, 0, current_stamina, 0.0, false, true, 1.0, 0.0)

	if defense_mode == DEFENSE_BLOCK:
		var block_succeeds: bool = (
			bool(defender["block_supported"])
			and bool(attack["blockable"])
			and facing_covered
		)
		if block_succeeds:
			var guard_pressure: float = float(attack["guard_pressure"])
			if current_stamina >= guard_pressure:
				return _resolved(
					OUTCOME_BLOCKED,
					0,
					current_stamina - guard_pressure,
					guard_pressure,
					false,
					false,
					1.0,
					0.0
				)

			var broken_hit: Dictionary = _resolve_damage(attack, defender)
			if not bool(broken_hit["ok"]):
				return _rejected(REASON_NONFINITE_RESULT)
			return _resolved(
				OUTCOME_GUARD_BROKEN,
				broken_hit["hp_damage"],
				0.0,
				current_stamina,
				true,
				false,
				float(broken_hit["selected_multiplier"]),
				float(broken_hit["applied_mitigation"])
			)

	var normal_hit: Dictionary = _resolve_damage(attack, defender)
	if not bool(normal_hit["ok"]):
		return _rejected(REASON_NONFINITE_RESULT)
	return _resolved(
		OUTCOME_HIT,
		normal_hit["hp_damage"],
		current_stamina,
		0.0,
		false,
		false,
		float(normal_hit["selected_multiplier"]),
		float(normal_hit["applied_mitigation"])
	)


static func _validate_attack(raw_attack: Variant) -> StringName:
	if typeof(raw_attack) != TYPE_DICTIONARY:
		return REASON_INVALID_ATTACK
	var attack: Dictionary = raw_attack as Dictionary

	if not _has_enum(attack, "domain", [DOMAIN_PHYSICAL, DOMAIN_ARCANE]):
		return REASON_INVALID_ATTACK
	if not _has_enum(attack, "delivery", [DELIVERY_CONTACT, DELIVERY_PROJECTILE]):
		return REASON_INVALID_ATTACK
	if not _has_nonnegative_finite_number(attack, "raw_damage"):
		return REASON_INVALID_ATTACK
	if not _has_bool(attack, "dodgeable") or not _has_bool(attack, "blockable") or not _has_bool(attack, "parryable"):
		return REASON_INVALID_ATTACK
	if not _has_nonnegative_finite_number(attack, "guard_pressure"):
		return REASON_INVALID_ATTACK
	if not _has_bool(attack, "critical_triggered") or not _has_multiplier(attack, "critical_multiplier"):
		return REASON_INVALID_ATTACK
	if not _has_bool(attack, "weak_point_triggered") or not _has_multiplier(attack, "weak_point_multiplier"):
		return REASON_INVALID_ATTACK

	if StringName(String(attack["delivery"])) == DELIVERY_PROJECTILE and bool(attack["parryable"]):
		return REASON_PROJECTILE_PARRYABLE
	return &""


static func _validate_defender(raw_defender: Variant) -> StringName:
	if typeof(raw_defender) != TYPE_DICTIONARY:
		return REASON_INVALID_DEFENDER
	var defender: Dictionary = raw_defender as Dictionary

	if not _has_bool(defender, "evade_window_active"):
		return REASON_INVALID_DEFENDER
	if not _has_enum(defender, "defense_mode", [DEFENSE_NONE, DEFENSE_BLOCK, DEFENSE_PARRY]):
		return REASON_INVALID_DEFENDER
	if not _has_bool(defender, "block_supported") or not _has_bool(defender, "parry_supported"):
		return REASON_INVALID_DEFENDER
	if not _has_bool(defender, "facing_covered"):
		return REASON_INVALID_DEFENDER
	if not _has_nonnegative_finite_number(defender, "current_stamina"):
		return REASON_INVALID_DEFENDER
	if not _has_finite_number(defender, "physical_defense") or not _has_finite_number(defender, "arcane_defense"):
		return REASON_INVALID_DEFENDER
	return &""


static func _resolve_damage(attack: Dictionary, defender: Dictionary) -> Dictionary:
	var selected_multiplier: float = 1.0
	if bool(attack["critical_triggered"]):
		selected_multiplier = maxf(selected_multiplier, float(attack["critical_multiplier"]))
	if bool(attack["weak_point_triggered"]):
		selected_multiplier = maxf(selected_multiplier, float(attack["weak_point_multiplier"]))

	var raw_after_bonus: float = float(attack["raw_damage"]) * selected_multiplier
	if not is_finite(raw_after_bonus):
		return {"ok": false}

	var domain: StringName = StringName(String(attack["domain"]))
	var authored_rating: float = float(defender["physical_defense"])
	if domain == DOMAIN_ARCANE:
		authored_rating = float(defender["arcane_defense"])
	var applied_mitigation: float = maxf(0.0, authored_rating)

	var mitigated: float = raw_after_bonus * 100.0 / (100.0 + applied_mitigation)
	if not is_finite(mitigated):
		return {"ok": false}

	var hp_damage: int = _round_half_up_positive(mitigated)
	if raw_after_bonus > 0.0:
		hp_damage = maxi(1, hp_damage)

	return {
		"ok": true,
		"hp_damage": hp_damage,
		"selected_multiplier": selected_multiplier,
		"applied_mitigation": applied_mitigation,
	}


static func _round_half_up_positive(value: float) -> int:
	if value <= 0.0:
		return 0
	return int(floor(value + 0.5))


static func _has_bool(data: Dictionary, key: String) -> bool:
	return data.has(key) and typeof(data[key]) == TYPE_BOOL


static func _has_enum(data: Dictionary, key: String, allowed: Array[StringName]) -> bool:
	if not data.has(key):
		return false
	var value: Variant = data[key]
	if not (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME):
		return false
	return allowed.has(StringName(String(value)))


static func _has_nonnegative_finite_number(data: Dictionary, key: String) -> bool:
	if not _has_finite_number(data, key):
		return false
	return float(data[key]) >= 0.0


static func _has_multiplier(data: Dictionary, key: String) -> bool:
	if not _has_finite_number(data, key):
		return false
	return float(data[key]) >= 1.0


static func _has_finite_number(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return false
	var value: Variant = data[key]
	var value_type: int = typeof(value)
	if not (value_type == TYPE_INT or value_type == TYPE_FLOAT):
		return false
	return is_finite(float(value))


static func _resolved(
	outcome: StringName,
	hp_damage: int,
	stamina_after: float,
	stamina_spent: float,
	guard_break: bool,
	attacker_interrupt_requested: bool,
	selected_multiplier: float,
	applied_mitigation: float
) -> Dictionary:
	return {
		"accepted": true,
		"reason_id": &"",
		"outcome": outcome,
		"hp_damage": hp_damage,
		"stamina_after": stamina_after,
		"stamina_spent": stamina_spent,
		"guard_break": guard_break,
		"attacker_interrupt_requested": attacker_interrupt_requested,
		"selected_multiplier": selected_multiplier,
		"applied_mitigation": applied_mitigation,
	}


static func _rejected(reason_id: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason_id": reason_id,
		"outcome": OUTCOME_REJECTED,
		"hp_damage": 0,
		"stamina_after": 0.0,
		"stamina_spent": 0.0,
		"guard_break": false,
		"attacker_interrupt_requested": false,
		"selected_multiplier": 1.0,
		"applied_mitigation": 0.0,
	}
