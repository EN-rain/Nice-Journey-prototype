class_name LevelProgressionService
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_POLICY_MISSING: StringName = &"policy_missing"
const REASON_POLICY_INVALID: StringName = &"policy_invalid"
const REASON_PROFILE_INVALID: StringName = &"profile_invalid"
const REASON_PROFILE_POLICY_MISMATCH: StringName = &"profile_policy_mismatch"
const REASON_STAT_STATE_INVALID: StringName = &"stat_state_invalid"
const REASON_STAT_STATE_MISMATCH: StringName = &"stat_state_mismatch"
const REASON_XP_AWARD_INVALID: StringName = &"xp_award_invalid"
const REASON_CLAIM_ID_INVALID: StringName = &"claim_id_invalid"
const REASON_SOURCE_ID_INVALID: StringName = &"source_id_invalid"
const REASON_DUPLICATE_CLAIM: StringName = &"duplicate_claim"
const REASON_CLAIM_REJECTED: StringName = &"claim_rejected"
const REASON_STAGED_PROFILE_INVALID: StringName = &"staged_profile_invalid"
const REASON_ATOMIC_COMMIT_OWNER_MISSING: StringName = &"atomic_commit_owner_missing"
const REASON_ATOMIC_COMMIT_REJECTED: StringName = &"atomic_commit_rejected"
const REASON_ATOMIC_COMMIT_RECEIPT_INVALID: StringName = &"atomic_commit_receipt_invalid"

const ATOMIC_COMMIT_CONTRACT_VERSION: int = 2


static func atomic_owner_contract() -> Dictionary:
    return {
        "version": ATOMIC_COMMIT_CONTRACT_VERSION,
        "prepared_profile_key": &"staged_profile",
        "resulting_stat_values_key": &"resulting_stat_values",
        "claim_id_key": &"claim_id",
        "contract_version_key": &"atomic_commit_contract_version",
        "required_receipt_fields": PackedStringArray([
            "accepted",
            "durable",
            "profile_committed",
            "stat_growth_committed",
            "claim_id",
            "atomic_commit_contract_version",
        ]),
        "owner_obligations": PackedStringArray([
            "persist staged_profile, including automatic_stats and its claim ledger, as one durable transaction",
            "treat staged_profile.automatic_stats as the permanent automatic-stat source of truth",
            "apply resulting_stat_values only as a transient live-runtime mirror and roll it back if durable persistence fails",
            "return accepted only after both durable profile state and the live automatic-stat mirror are coherent",
            "echo claim_id and atomic_commit_contract_version unchanged in the receipt",
        ]),
    }


static func plan_award(
    profile: ProfileSnapshot,
    current_stat_values: Dictionary,
    xp_award: int,
    claim_id: StringName,
    source_id: StringName,
    policy: LevelProgressionPolicy
) -> Dictionary:
    var admission := _validate_admission(profile, current_stat_values, xp_award, claim_id, source_id, policy)
    if not bool(admission.get("accepted", false)):
        return admission

    var thresholds := policy.threshold_tuning
    var cumulative_before := _cumulative_equivalent(profile, policy)
    var cumulative_after := cumulative_before + xp_award
    var cap_threshold := thresholds.total_xp_to_cap()
    var target_level := profile.level
    while target_level < LevelThresholdTuning.MAX_LEVEL:
        var next_threshold := thresholds.cumulative_xp_required_for_level(target_level + 1)
        if cumulative_after < next_threshold:
            break
        target_level += 1

    var transitions: Array[Dictionary] = []
    var stat_growth_delta: Dictionary = {}
    var skill_points_granted := 0
    for from_level: int in range(profile.level, target_level):
        var transition_growth := _normalize_numeric_dictionary(policy.stat_growth_for_transition(from_level))
        var transition_points := policy.skill_points_for_transition(from_level)
        skill_points_granted += transition_points
        _accumulate_numeric_dictionary(stat_growth_delta, transition_growth)
        transitions.append({
            "from_level": from_level,
            "to_level": from_level + 1,
            "xp_threshold": thresholds.xp_required_to_next(from_level),
            "skill_points_granted": transition_points,
            "stat_growth": transition_growth.duplicate(true),
        })

    var resulting_stats := _normalize_numeric_dictionary(current_stat_values)
    _accumulate_numeric_dictionary(resulting_stats, stat_growth_delta)
    var overflow_amount := maxi(0, cumulative_after - cap_threshold) if target_level == LevelThresholdTuning.MAX_LEVEL else 0
    var resulting_xp := _stored_xp_for_total(target_level, cumulative_after, policy)

    return {
        "accepted": true,
        "reason_id": &"",
        "policy_errors": PackedStringArray(),
        "profile_policy_errors": PackedStringArray(),
        "stat_state_errors": PackedStringArray(),
        "claim_id": claim_id,
        "source_id": source_id,
        "xp_award": xp_award,
        "xp_storage_semantics": policy.xp_storage_semantics,
        "cap_overflow_behavior": policy.cap_overflow_behavior,
        "from_level": profile.level,
        "to_level": target_level,
        "levels_gained": target_level - profile.level,
        "from_xp": profile.xp,
        "to_xp": resulting_xp,
        "cumulative_xp_before": cumulative_before,
        "cumulative_xp_after_award": cumulative_after,
        "cap_overflow_amount": overflow_amount,
        "cap_reached": target_level == LevelThresholdTuning.MAX_LEVEL,
        "skill_points_before": profile.skill_points,
        "skill_points_granted": skill_points_granted,
        "skill_points_after": profile.skill_points + skill_points_granted,
        "stat_growth_delta": stat_growth_delta.duplicate(true),
        "resulting_stat_values": resulting_stats.duplicate(true),
        "transitions": transitions.duplicate(true),
    }


static func prepare_award(
    profile: ProfileSnapshot,
    current_stat_values: Dictionary,
    xp_award: int,
    claim_id: StringName,
    source_id: StringName,
    policy: LevelProgressionPolicy
) -> Dictionary:
    var plan := plan_award(profile, current_stat_values, xp_award, claim_id, source_id, policy)
    if not bool(plan.get("accepted", false)):
        return plan

    var staged := ProfileSnapshot.from_dictionary(profile.to_dictionary())
    if staged == null:
        return _rejected(REASON_PROFILE_INVALID, claim_id, source_id)
    staged.level = int(plan.get("to_level", staged.level))
    staged.xp = int(plan.get("to_xp", staged.xp))
    staged.skill_points = int(plan.get("skill_points_after", staged.skill_points))
    staged.automatic_stats = (plan.get("resulting_stat_values", {}) as Dictionary).duplicate(true)

    var ledger := ClaimLedger.new()
    if not ledger.load_dictionary(staged.claimed_transactions).is_empty():
        return _rejected(REASON_PROFILE_INVALID, claim_id, source_id)
    if not ledger.try_claim(claim_id, source_id):
        return _rejected(REASON_CLAIM_REJECTED, claim_id, source_id)
    staged.claimed_transactions = ledger.to_dictionary()
    if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _rejected(REASON_STAGED_PROFILE_INVALID, claim_id, source_id)

    var prepared := plan.duplicate(true)
    prepared["staged_profile"] = staged.to_dictionary().duplicate(true)
    prepared["requires_atomic_profile_commit"] = true
    prepared["requires_atomic_stat_growth_commit"] = true
    prepared["atomic_commit_contract_version"] = ATOMIC_COMMIT_CONTRACT_VERSION
    prepared["durable"] = false
    return prepared


static func commit_award(
    profile: ProfileSnapshot,
    current_stat_values: Dictionary,
    xp_award: int,
    claim_id: StringName,
    source_id: StringName,
    policy: LevelProgressionPolicy,
    atomic_commit_owner: Callable
) -> Dictionary:
    if not atomic_commit_owner.is_valid():
        return _rejected(REASON_ATOMIC_COMMIT_OWNER_MISSING, claim_id, source_id)
    var prepared := prepare_award(profile, current_stat_values, xp_award, claim_id, source_id, policy)
    if not bool(prepared.get("accepted", false)):
        return prepared

    var owner_input := prepared.duplicate(true)
    var raw_receipt: Variant = atomic_commit_owner.call(owner_input)
    if not raw_receipt is Dictionary:
        return _rejected(REASON_ATOMIC_COMMIT_RECEIPT_INVALID, claim_id, source_id)
    var receipt := raw_receipt as Dictionary
    if not bool(receipt.get("accepted", false)):
        var rejected := _rejected(REASON_ATOMIC_COMMIT_REJECTED, claim_id, source_id)
        rejected["commit_receipt"] = receipt.duplicate(true)
        return rejected
    if not _receipt_confirms_atomic_commit(receipt, claim_id):
        var invalid_receipt := _rejected(REASON_ATOMIC_COMMIT_RECEIPT_INVALID, claim_id, source_id)
        invalid_receipt["commit_receipt"] = receipt.duplicate(true)
        return invalid_receipt

    var staged_payload := prepared.get("staged_profile", {}) as Dictionary
    var staged := ProfileSnapshot.from_dictionary(staged_payload)
    if staged == null or not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
        return _rejected(REASON_STAGED_PROFILE_INVALID, claim_id, source_id)
    var staged_ledger := ClaimLedger.new()
    if not staged_ledger.load_dictionary(staged.claimed_transactions).is_empty() or not staged_ledger.is_claimed(claim_id):
        return _rejected(REASON_STAGED_PROFILE_INVALID, claim_id, source_id)

    profile.level = staged.level
    profile.xp = staged.xp
    profile.skill_points = staged.skill_points
    profile.automatic_stats = staged.automatic_stats.duplicate(true)
    profile.claimed_transactions = staged.claimed_transactions.duplicate(true)

    var result := prepared.duplicate(true)
    result["durable"] = true
    result["commit_receipt"] = receipt.duplicate(true)
    return result


static func _validate_admission(
    profile: ProfileSnapshot,
    current_stat_values: Dictionary,
    xp_award: int,
    claim_id: StringName,
    source_id: StringName,
    policy: LevelProgressionPolicy
) -> Dictionary:
    if profile == null:
        return _rejected(REASON_INVALID_CONTEXT, claim_id, source_id)
    if policy == null:
        return _rejected(REASON_POLICY_MISSING, claim_id, source_id)
    var policy_errors := policy.validate_policy()
    if not policy_errors.is_empty():
        var invalid_policy := _rejected(REASON_POLICY_INVALID, claim_id, source_id)
        invalid_policy["policy_errors"] = policy_errors.duplicate()
        return invalid_policy
    if not ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty():
        return _rejected(REASON_PROFILE_INVALID, claim_id, source_id)
    if xp_award < 0:
        return _rejected(REASON_XP_AWARD_INVALID, claim_id, source_id)
    if not StableId.is_valid(String(claim_id)):
        return _rejected(REASON_CLAIM_ID_INVALID, claim_id, source_id)
    if not StableId.is_valid(String(source_id)):
        return _rejected(REASON_SOURCE_ID_INVALID, claim_id, source_id)

    var ledger := ClaimLedger.new()
    if not ledger.load_dictionary(profile.claimed_transactions).is_empty():
        return _rejected(REASON_PROFILE_INVALID, claim_id, source_id)
    if ledger.is_claimed(claim_id):
        return _rejected(REASON_DUPLICATE_CLAIM, claim_id, source_id)

    var profile_policy_errors := _validate_profile_against_policy(profile, policy)
    if not profile_policy_errors.is_empty():
        var mismatch := _rejected(REASON_PROFILE_POLICY_MISMATCH, claim_id, source_id)
        mismatch["profile_policy_errors"] = profile_policy_errors.duplicate()
        return mismatch
    var persisted_stat_errors := AutomaticStatState.validate_dictionary(profile.automatic_stats)
    if not persisted_stat_errors.is_empty():
        var invalid_persisted_stats := _rejected(REASON_STAT_STATE_INVALID, claim_id, source_id)
        invalid_persisted_stats["stat_state_errors"] = persisted_stat_errors.duplicate()
        return invalid_persisted_stats
    var stat_state_errors := _validate_stat_state(current_stat_values, policy)
    if not stat_state_errors.is_empty():
        var invalid_stats := _rejected(REASON_STAT_STATE_INVALID, claim_id, source_id)
        invalid_stats["stat_state_errors"] = stat_state_errors.duplicate()
        return invalid_stats
    if not AutomaticStatState.equivalent(current_stat_values, profile.automatic_stats):
        var mismatched_stats := _rejected(REASON_STAT_STATE_MISMATCH, claim_id, source_id)
        mismatched_stats["stat_state_errors"] = PackedStringArray(["live automatic-stat mirror must match profile.automatic_stats before progression"])
        return mismatched_stats
    return {"accepted": true, "reason_id": &""}


static func _validate_profile_against_policy(profile: ProfileSnapshot, policy: LevelProgressionPolicy) -> PackedStringArray:
    var errors := PackedStringArray()
    var thresholds := policy.threshold_tuning
    var level := profile.level
    if policy.xp_storage_semantics == LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL:
        var minimum := thresholds.cumulative_xp_required_for_level(level)
        if level < LevelThresholdTuning.MAX_LEVEL:
            var next := thresholds.cumulative_xp_required_for_level(level + 1)
            if profile.xp < minimum or profile.xp >= next:
                errors.append("cumulative_total XP is inconsistent with the stored level")
        elif policy.cap_overflow_behavior == LevelProgressionPolicy.CAP_OVERFLOW_DISCARD and profile.xp != minimum:
            errors.append("discard cap policy requires cumulative_total XP to equal the Level 10 threshold")
        elif policy.cap_overflow_behavior == LevelProgressionPolicy.CAP_OVERFLOW_RETAIN and profile.xp < minimum:
            errors.append("retain cap policy requires cumulative_total XP at or above the Level 10 threshold")
    elif policy.xp_storage_semantics == LevelProgressionPolicy.XP_STORAGE_LEVEL_PROGRESS:
        if level < LevelThresholdTuning.MAX_LEVEL:
            var required := thresholds.xp_required_to_next(level)
            if profile.xp < 0 or profile.xp >= required:
                errors.append("level_progress XP must be below the next-level threshold")
        elif policy.cap_overflow_behavior == LevelProgressionPolicy.CAP_OVERFLOW_DISCARD and profile.xp != 0:
            errors.append("discard cap policy requires Level 10 level_progress XP to be zero")
    return errors


static func _validate_stat_state(current_stat_values: Dictionary, policy: LevelProgressionPolicy) -> PackedStringArray:
    var errors := PackedStringArray()
    var normalized := _normalize_numeric_dictionary(current_stat_values, errors)
    for stat_id: StringName in policy.required_stat_ids():
        if not normalized.has(String(stat_id)):
            errors.append("missing current automatic stat value: %s" % String(stat_id))
    return errors


static func _cumulative_equivalent(profile: ProfileSnapshot, policy: LevelProgressionPolicy) -> int:
    if policy.xp_storage_semantics == LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL:
        return profile.xp
    var base := policy.threshold_tuning.cumulative_xp_required_for_level(profile.level)
    return base + profile.xp


static func _stored_xp_for_total(level: int, cumulative_total: int, policy: LevelProgressionPolicy) -> int:
    var cap_threshold := policy.threshold_tuning.total_xp_to_cap()
    if policy.xp_storage_semantics == LevelProgressionPolicy.XP_STORAGE_CUMULATIVE_TOTAL:
        if level == LevelThresholdTuning.MAX_LEVEL and policy.cap_overflow_behavior == LevelProgressionPolicy.CAP_OVERFLOW_DISCARD:
            return cap_threshold
        return cumulative_total
    if level == LevelThresholdTuning.MAX_LEVEL:
        if policy.cap_overflow_behavior == LevelProgressionPolicy.CAP_OVERFLOW_DISCARD:
            return 0
        return maxi(0, cumulative_total - cap_threshold)
    return cumulative_total - policy.threshold_tuning.cumulative_xp_required_for_level(level)


static func _normalize_numeric_dictionary(source: Dictionary, errors: PackedStringArray = PackedStringArray()) -> Dictionary:
    var result: Dictionary = {}
    for raw_key: Variant in source.keys():
        var key := String(raw_key)
        if not StableId.is_valid(key):
            errors.append("invalid automatic stat ID: %s" % key)
            continue
        if result.has(key):
            errors.append("duplicate automatic stat ID after normalization: %s" % key)
            continue
        var raw_value: Variant = source[raw_key]
        if not _is_finite_number(raw_value):
            errors.append("automatic stat value must be finite: %s" % key)
            continue
        result[key] = float(raw_value)
    return result


static func _accumulate_numeric_dictionary(target: Dictionary, delta: Dictionary) -> void:
    for raw_key: Variant in delta.keys():
        var key := String(raw_key)
        target[key] = float(target.get(key, 0.0)) + float(delta[raw_key])


static func _receipt_confirms_atomic_commit(receipt: Dictionary, claim_id: StringName) -> bool:
    return (
        bool(receipt.get("accepted", false))
        and bool(receipt.get("durable", false))
        and bool(receipt.get("profile_committed", false))
        and bool(receipt.get("stat_growth_committed", false))
        and int(receipt.get("atomic_commit_contract_version", -1)) == ATOMIC_COMMIT_CONTRACT_VERSION
        and StringName(String(receipt.get("claim_id", &""))) == claim_id
    )


static func _rejected(reason_id: StringName, claim_id: StringName, source_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "policy_errors": PackedStringArray(),
        "profile_policy_errors": PackedStringArray(),
        "stat_state_errors": PackedStringArray(),
        "claim_id": claim_id,
        "source_id": source_id,
        "durable": false,
    }


static func _is_finite_number(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return true
    if typeof(value) != TYPE_FLOAT:
        return false
    return is_finite(float(value))
