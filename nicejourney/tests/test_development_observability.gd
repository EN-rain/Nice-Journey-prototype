extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var gameplay: Node2D = GAMEPLAY_SCENE.instantiate() as Node2D
    root.add_child(gameplay)
    await process_frame

    var machine: ActionStateMachine = gameplay.get_node("ActionStateMachine") as ActionStateMachine
    var intents: ActionIntentController = gameplay.get_node("ActionIntentController") as ActionIntentController
    machine.set_physics_process(false)
    var action: ActionDefinition = _make_action(&"fixture:observe")
    _expect(intents.request_action(&"basic_attack", action, Vector2.RIGHT), "fixture action starts through the existing intent boundary")
    var action_instance_id: int = machine.get_current_instance_id()

    var ledger: CombatContactLedger = CombatContactLedger.new()
    _expect(ledger.try_admit_contact(action_instance_id, &"enemy:fixture:a", 0), "fixture contact identity is admitted")
    _expect(ledger.try_admit_contact(action_instance_id, &"enemy:fixture:b", 1), "second fixture contact identity is admitted")

    var guard: GameplayOperationGuard = GameplayOperationGuard.new()
    var blocker_token: int = guard.acquire_blocker(
        &"encounter:fixture",
        GameplayOperationGuard.REASON_ACTIVE_COMBAT,
        "Active combat is unresolved.",
        [GameplayOperationGuard.OP_MANUAL_SAVE]
    )
    var save_service: SaveService = SaveService.new("user://tests/development_observability")
    save_service.delete_slot(1)
    var save_coordinator: SaveRequestCoordinator = SaveRequestCoordinator.new(save_service, guard)
    var save_status: Dictionary = save_coordinator.request_save(
        1,
        SaveRequestCoordinator.REQUEST_AUTOSAVE,
        func() -> ProfileSnapshot: return _make_profile()
    )
    _expect(StringName(save_status.get("state", &"")) == SaveRequestCoordinator.STATE_PENDING, "fixture save state is pending behind the named guard")

    var memory: AiObservationMemory = AiObservationMemory.new(5)
    var observation_admission: AiObservationAdmission = AiObservationAdmission.new(memory)
    observation_admission.admit_sight(&"actor:player", Vector2(10, 20), &"moving", 10, 0.9, 30, 10)
    observation_admission.admit_sound(&"actor:ally", Vector2(30, 40), &"attacking", 11, 0.8, 30, 11)
    observation_admission.admit_shared_fact(&"actor:rival", Vector2(50, 60), &"casting", 12, 0.7, 30, 12)

    var phase_before: int = int(machine.get_phase())
    var phase_ticks_before: int = machine.get_phase_elapsed_ticks()
    var ai_size_before: int = memory.size()
    var guard_count_before: int = guard.get_blocking_reasons(GameplayOperationGuard.OP_MANUAL_SAVE).size()
    var save_before: Dictionary = save_coordinator.get_status(1)

    var snapshot: Dictionary = DevelopmentObservabilitySnapshot.compose(
        intents,
        ledger,
        guard,
        GameplayOperationGuard.OP_MANUAL_SAVE,
        save_coordinator,
        1,
        memory,
        15,
        8,
        2,
        0.05
    )
    var action_snapshot: Dictionary = snapshot.get("action", {})
    var contacts: Array = snapshot.get("contacts", [])
    var guard_snapshot: Dictionary = snapshot.get("operation_guard", {})
    var observed: Array = snapshot.get("ai_observations", [])
    _expect(bool(snapshot.get("development_only", false)), "composed observability surface is explicitly marked development-only")
    _expect(int(action_snapshot.get("action_instance_id", 0)) == action_instance_id, "composed action snapshot preserves the live action-instance ID")
    _expect(contacts.size() == 2 and int((contacts[0] as Dictionary).get("action_instance_id", 0)) == action_instance_id, "contact identity correlates to the composed action instance")
    _expect(StringName((contacts[0] as Dictionary).get("target_id", &"")) == &"enemy:fixture:a" and int((contacts[0] as Dictionary).get("hit_interval_index", -1)) == 0, "contact snapshot exposes identity only")
    _expect(not bool(guard_snapshot.get("allowed", true)) and StringName(guard_snapshot.get("reason_id", &"")) == GameplayOperationGuard.REASON_ACTIVE_COMBAT, "named operation exposes the current ordered guard reason")
    _expect(StringName(guard_snapshot.get("source_id", &"")) == &"encounter:fixture", "composed guard reason preserves its owning source identity")
    var composed_save: Dictionary = snapshot.get("save_request", {}) as Dictionary
    _expect(StringName(composed_save.get("state", &"")) == SaveRequestCoordinator.STATE_PENDING, "save request status is composed without advertising pending work as durable")
    _expect(int(composed_save.get("slot_index", 0)) == 1 and StringName(composed_save.get("request_kind", &"")) == SaveRequestCoordinator.REQUEST_AUTOSAVE, "composed save status preserves the requested slot and request identity")
    _expect(observed.size() == 2, "AI observation enumeration is bounded by the requested development limit")
    _expect(StringName((observed[0] as Dictionary).get("source_id", &"")) == &"actor:rival" and StringName((observed[1] as Dictionary).get("source_id", &"")) == &"actor:ally", "AI observation enumeration is deterministic newest-first")
    _expect(_has_required_observation_fields(observed[0] as Dictionary), "AI summary exposes observed cue/source/state/position/age/confidence/expiry")
    _expect(int((observed[0] as Dictionary).get("observed_tick", -1)) == 12 and int((observed[0] as Dictionary).get("age_ticks", -1)) == 3, "AI debug age is derived truthfully from the original observation tick")
    _expect(is_equal_approx(float((observed[0] as Dictionary).get("confidence", -1.0)), 0.55) and int((observed[0] as Dictionary).get("expiry_tick", -1)) == 42, "AI debug confidence decay and expiry preserve the authored observation metadata")
    _expect(not _contains_forbidden_key(snapshot), "development snapshot omits damage/defense/tactics/threat/raw-input/live-target/current-hidden-state fields")

    (contacts[0] as Dictionary)["target_id"] = &"enemy:mutated"
    (observed[0] as Dictionary)["observed_position"] = Vector2(999, 999)
    guard_snapshot["source_id"] = &"mutated"
    guard_snapshot["reason_id"] = &"mutated"
    (snapshot.get("save_request", {}) as Dictionary)["state"] = &"mutated"
    action_snapshot["action_instance_id"] = -1
    var snapshot_again: Dictionary = DevelopmentObservabilitySnapshot.compose(
        intents, ledger, guard, GameplayOperationGuard.OP_MANUAL_SAVE, save_coordinator, 1, memory, 15, 8, 2, 0.05
    )
    _expect(int((snapshot_again.get("action", {}) as Dictionary).get("action_instance_id", 0)) == action_instance_id, "mutating composed action data cannot mutate the action source")
    _expect(StringName(((snapshot_again.get("contacts", []) as Array)[0] as Dictionary).get("target_id", &"")) == &"enemy:fixture:a", "mutating composed contact data cannot mutate the contact ledger")
    _expect(Vector2(((snapshot_again.get("ai_observations", []) as Array)[0] as Dictionary).get("observed_position", Vector2.ZERO)) != Vector2(999, 999), "mutating composed AI data cannot mutate observation memory")
    var guard_again: Dictionary = snapshot_again.get("operation_guard", {}) as Dictionary
    _expect(StringName(guard_again.get("source_id", &"")) == &"encounter:fixture" and StringName(guard_again.get("reason_id", &"")) == GameplayOperationGuard.REASON_ACTIVE_COMBAT, "mutating composed guard data cannot mutate guard state or source identity")
    _expect(StringName((snapshot_again.get("save_request", {}) as Dictionary).get("state", &"")) == SaveRequestCoordinator.STATE_PENDING, "mutating composed save data cannot mutate coordinator status")

    _expect(int(machine.get_phase()) == phase_before and machine.get_phase_elapsed_ticks() == phase_ticks_before, "snapshot creation does not advance or alter action state")
    _expect(ledger.has_contact(action_instance_id, &"enemy:fixture:a", 0), "snapshot creation does not alter contact identity")
    _expect(memory.size() == ai_size_before, "snapshot creation does not purge or append AI observations")
    _expect(guard.get_blocking_reasons(GameplayOperationGuard.OP_MANUAL_SAVE).size() == guard_count_before, "snapshot creation does not alter operation blockers")
    _expect(save_coordinator.get_status(1) == save_before, "snapshot creation does not alter save-request state")

    guard.release_blocker(blocker_token)
    save_service.delete_slot(1)
    guard.free()
    gameplay.queue_free()
    if _failures == 0:
        print("DEVELOPMENT OBSERVABILITY TEST PASS")
    else:
        push_error("DEVELOPMENT OBSERVABILITY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _make_action(action_id: StringName) -> ActionDefinition:
    var action: ActionDefinition = ActionDefinition.new()
    action.action_id = action_id
    action.startup_ticks = 4
    action.commit_ticks = 1
    action.active_ticks = 1
    action.recovery_ticks = 1
    action.buffer_lifetime_ticks = 10
    return action

func _make_profile() -> ProfileSnapshot:
    var profile: ProfileSnapshot = ProfileSnapshot.new()
    profile.profile_id = "profile:slot_1"
    profile.protagonist_name = "Observer"
    profile.class_id = "melee"
    return profile

func _has_required_observation_fields(observation: Dictionary) -> bool:
    for key: String in ["cue_id", "source_id", "observed_state", "observed_position", "age_ticks", "confidence", "lifetime_ticks", "expiry_tick"]:
        if not observation.has(key):
            return false
    return true

func _contains_forbidden_key(value: Variant) -> bool:
    var forbidden: Array[String] = ["damage", "defense", "raw_input", "live_target", "current_hidden_state", "tactics", "threat"]
    if value is Dictionary:
        for key: Variant in (value as Dictionary).keys():
            if forbidden.has(String(key)):
                return true
            if _contains_forbidden_key((value as Dictionary)[key]):
                return true
    elif value is Array:
        for item: Variant in value as Array:
            if _contains_forbidden_key(item):
                return true
    return false

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
