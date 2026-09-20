class_name EnemyActiveAttackDeliveryExecutor
extends RefCounted

const REASON_NOT_CONFIGURED: StringName = &"not_configured"
const REASON_INVALID_HIT_INTERVAL: StringName = &"invalid_hit_interval"
const REASON_ACTIVE_WINDOW_UNAVAILABLE: StringName = &"active_window_unavailable"
const REASON_PHASE_DRIVER_DESYNC: StringName = &"phase_driver_desync"
const REASON_ATTACK_AUTHORING_UNAVAILABLE: StringName = &"attack_authoring_unavailable"
const REASON_INVALID_CONTACT_FACTS: StringName = &"invalid_contact_facts"
const REASON_CONTACT_NOT_CONFIRMED: StringName = &"contact_not_confirmed"
const REASON_CONTACT_IDENTITY_MISMATCH: StringName = &"contact_identity_mismatch"
const REASON_GEOMETRY_MISMATCH: StringName = &"geometry_mismatch"
const REASON_HIT_INTERVAL_OUT_OF_RANGE: StringName = &"hit_interval_out_of_range"

var runtime: EnemyArchetypeRuntime = null
var phase_driver: EnemySignatureActionPhaseDriver = null


func configure(
    source_runtime: EnemyArchetypeRuntime,
    source_phase_driver: EnemySignatureActionPhaseDriver
) -> bool:
    if source_runtime == null or source_phase_driver == null:
        return false
    if not source_runtime.is_configured() or source_phase_driver.runtime != source_runtime:
        return false
    runtime = source_runtime
    phase_driver = source_phase_driver
    return true


# This executor does not own attack geometry or payload authoring. Callers may invoke it
# only after an authoritative geometry/contact owner has confirmed a contact candidate and
# supplied the corresponding DR-06 attack payload plus defender transient facts.
func resolve_authorized_contact(
    action_instance_id: int,
    hit_interval_index: int,
    attack_payload: Variant,
    evade_window_active: bool,
    defense_mode: StringName,
    facing_covered: bool
) -> Dictionary:
    if runtime == null or phase_driver == null:
        return _rejected(REASON_NOT_CONFIGURED)
    if hit_interval_index < 0:
        return _rejected(REASON_INVALID_HIT_INTERVAL)
    if phase_driver.runtime != runtime or phase_driver.action_instance_id != action_instance_id:
        return _rejected(REASON_PHASE_DRIVER_DESYNC)

    var delivery_context := runtime.get_active_delivery_context(action_instance_id)
    if not bool(delivery_context.get("accepted", false)):
        var rejected := _rejected(REASON_ACTIVE_WINDOW_UNAVAILABLE)
        rejected["runtime_reason_id"] = StringName(String(delivery_context.get("reason_id", &"")))
        return rejected

    var result := runtime.encounter.resolve_direct_contact(
        runtime.actor_id,
        runtime.target_id,
        action_instance_id,
        hit_interval_index,
        attack_payload as Dictionary if attack_payload is Dictionary else {},
        evade_window_active,
        defense_mode,
        facing_covered
    )
    result["delivery_context"] = delivery_context.duplicate(true)
    result["attacker_interrupt_applied"] = false
    if bool(result.get("accepted", false)) and bool(result.get("attacker_interrupt_requested", false)):
        result["attacker_interrupt_applied"] = phase_driver.cancel(AttackReservationLedger.RELEASE_INTERRUPTION)
    return result


# High-level delivery boundary for production geometry owners. The caller owns the actual
# physics query and supplies its confirmed contact facts; payload values come only from the
# archetype's authored signature-attack resource.
func resolve_authored_contact(
    contact_facts: Variant,
    evade_window_active: bool,
    defense_mode: StringName,
    facing_covered: bool
) -> Dictionary:
    if runtime == null or phase_driver == null or runtime.definition == null:
        return _rejected(REASON_NOT_CONFIGURED)
    var authoring_errors := runtime.definition.validate_signature_attack_authoring()
    if not authoring_errors.is_empty():
        var unavailable := _rejected(REASON_ATTACK_AUTHORING_UNAVAILABLE)
        unavailable["authoring_errors"] = authoring_errors
        return unavailable
    if not contact_facts is Dictionary:
        return _rejected(REASON_INVALID_CONTACT_FACTS)

    var facts := contact_facts as Dictionary
    for key: String in [
        "actor_id",
        "target_id",
        "action_id",
        "action_instance_id",
        "hit_interval_index",
        "geometry_id",
        "contact_confirmed",
        "critical_triggered",
        "weak_point_triggered",
    ]:
        if not facts.has(key):
            return _rejected(REASON_INVALID_CONTACT_FACTS)
    if not facts["contact_confirmed"] is bool or not facts["critical_triggered"] is bool or not facts["weak_point_triggered"] is bool:
        return _rejected(REASON_INVALID_CONTACT_FACTS)
    if not bool(facts["contact_confirmed"]):
        return _rejected(REASON_CONTACT_NOT_CONFIRMED)
    if typeof(facts["action_instance_id"]) != TYPE_INT or typeof(facts["hit_interval_index"]) != TYPE_INT:
        return _rejected(REASON_INVALID_CONTACT_FACTS)

    var action_instance_id := int(facts["action_instance_id"])
    var hit_interval_index := int(facts["hit_interval_index"])
    if StringName(String(facts["actor_id"])) != runtime.actor_id \
        or StringName(String(facts["target_id"])) != runtime.target_id \
        or StringName(String(facts["action_id"])) != runtime.definition.signature_action_id:
        return _rejected(REASON_CONTACT_IDENTITY_MISMATCH)

    var authoring := runtime.definition.signature_attack_authoring
    if authoring == null or authoring.geometry == null or authoring.payload == null:
        return _rejected(REASON_ATTACK_AUTHORING_UNAVAILABLE)
    if StringName(String(facts["geometry_id"])) != authoring.geometry.geometry_id:
        return _rejected(REASON_GEOMETRY_MISMATCH)
    if hit_interval_index < 0 or hit_interval_index >= authoring.geometry.hit_interval_count:
        return _rejected(REASON_HIT_INTERVAL_OUT_OF_RANGE)

    var attack_payload := authoring.payload.make_payload(
        bool(facts["critical_triggered"]),
        bool(facts["weak_point_triggered"])
    )
    if attack_payload.is_empty():
        return _rejected(REASON_ATTACK_AUTHORING_UNAVAILABLE)
    return resolve_authorized_contact(
        action_instance_id,
        hit_interval_index,
        attack_payload,
        evade_window_active,
        defense_mode,
        facing_covered
    )


func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "runtime_reason_id": &"",
        "outcome": DirectHitResolver.OUTCOME_REJECTED,
        "hp_damage": 0,
        "action_instance_id": phase_driver.action_instance_id if phase_driver != null else 0,
        "attacker_interrupt_applied": false,
        "delivery_context": {},
        "authoring_errors": PackedStringArray(),
    }
