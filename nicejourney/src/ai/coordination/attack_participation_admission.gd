class_name AttackParticipationAdmission
extends RefCounted

func try_admit(
    lifecycle: EnemyRootLifecycle,
    full_ai_ledger: FullAiSimulationLedger,
    reservation_ledger: AttackReservationLedger,
    actor_id: StringName,
    target_id: StringName,
    encounter_id: StringName,
    action_instance_id: int
) -> int:
    if lifecycle == null or full_ai_ledger == null or reservation_ledger == null:
        return 0
    if not lifecycle.can_hold_group_reservation():
        return 0
    if not full_ai_ledger.is_admitted_to_encounter(actor_id, encounter_id):
        return 0
    return reservation_ledger.try_reserve(actor_id, target_id, encounter_id, action_instance_id)
