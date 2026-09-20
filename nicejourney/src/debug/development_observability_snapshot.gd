class_name DevelopmentObservabilitySnapshot
extends RefCounted

const DEFAULT_CONTACT_LIMIT: int = 8
const DEFAULT_AI_LIMIT: int = 8

static func compose(
    action_intents: ActionIntentController,
    contact_ledger: CombatContactLedger,
    operation_guard: GameplayOperationGuard,
    operation: StringName,
    save_coordinator: SaveRequestCoordinator,
    save_slot_index: int,
    ai_memory: AiObservationMemory,
    now_tick: int,
    contact_limit: int = DEFAULT_CONTACT_LIMIT,
    ai_limit: int = DEFAULT_AI_LIMIT,
    confidence_decay_per_tick: float = 0.0
) -> Dictionary:
    var action_snapshot: Dictionary = {} if action_intents == null else action_intents.get_debug_snapshot()
    var action_instance_id: int = int(action_snapshot.get("action_instance_id", 0))
    var contacts: Array[Dictionary] = []
    if contact_ledger != null:
        contacts = contact_ledger.get_contact_snapshots(action_instance_id, contact_limit)

    var guard_snapshot: Dictionary = {
        "operation": operation,
        "allowed": true,
        "source_id": &"",
        "reason_id": &"",
        "reason_text": "",
    }
    if operation_guard != null:
        var reasons: Array[Dictionary] = operation_guard.get_blocking_reasons(operation)
        if not reasons.is_empty():
            guard_snapshot["allowed"] = false
            guard_snapshot["source_id"] = StringName(reasons[0].get("source_id", &""))
            guard_snapshot["reason_id"] = StringName(reasons[0].get("reason_id", &""))
            guard_snapshot["reason_text"] = String(reasons[0].get("reason_text", ""))

    var save_snapshot: Dictionary = {} if save_coordinator == null else save_coordinator.get_status(save_slot_index)
    var ai_snapshots: Array[Dictionary] = []
    if ai_memory != null:
        ai_snapshots = ai_memory.get_debug_observations(now_tick, ai_limit, confidence_decay_per_tick)

    return {
        "development_only": true,
        "action": action_snapshot.duplicate(true),
        "contacts": contacts.duplicate(true),
        "operation_guard": guard_snapshot.duplicate(true),
        "save_request": save_snapshot.duplicate(true),
        "ai_observations": ai_snapshots.duplicate(true),
    }
