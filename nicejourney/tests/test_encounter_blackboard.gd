extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_observed_shared_facts()
    _test_role_ownership_requires_active_lifecycle()
    if _failures == 0:
        print("ENCOUNTER BLACKBOARD TEST PASS")
    else:
        push_error("ENCOUNTER BLACKBOARD TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_observed_shared_facts() -> void:
    var board := EncounterBlackboard.new()
    _expect(board.configure(&"encounter:blackboard_observation", 4), "blackboard accepts stable encounter identity and bounded fact capacity")
    _expect(board.publish_observed_fact(
        &"player:blackboard_fixture",
        Vector2(12.0, 18.0),
        &"state:casting_observed",
        10,
        0.8,
        12,
        12
    ), "blackboard admits an observed shared fact through the perception admission boundary")
    var fact := board.latest_fact(&"player:blackboard_fixture", 14, 0.05)
    _expect(not fact.is_empty(), "unexpired shared fact remains observable")
    _expect(int(fact.get("age_ticks", -1)) == 4, "shared fact preserves observation age")
    _expect(is_equal_approx(float(fact.get("confidence", -1.0)), 0.6), "shared fact confidence decays rather than becoming omniscient certainty")
    _expect(StringName(fact.get("cue_id", &"")) == AiObservationAdmission.CUE_SHARED, "blackboard marks shared facts as shared observations")
    _expect(board.latest_fact(&"player:blackboard_fixture", 22).is_empty(), "expired shared observation cannot reveal stale live player state")
    _expect(board.purge_expired(22) == 1, "expired shared observation is purged deterministically")

func _test_role_ownership_requires_active_lifecycle() -> void:
    var board := EncounterBlackboard.new()
    _expect(board.configure(&"encounter:blackboard_roles"), "role blackboard configures")
    var active := EnemyRootLifecycle.new()
    var other := EnemyRootLifecycle.new()
    _expect(active.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:activate"), "role fixture activates first actor lifecycle")
    _expect(other.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:activate"), "role fixture activates second actor lifecycle")
    _expect(board.try_claim_role(&"role:flank_left", &"enemy:blackboard_a", active), "Active actor can claim one encounter coordination role")
    _expect(board.try_claim_role(&"role:flank_left", &"enemy:blackboard_a", active), "same actor role claim is idempotent")
    _expect(not board.try_claim_role(&"role:flank_left", &"enemy:blackboard_b", other), "second actor cannot silently steal an occupied role")
    _expect(not board.try_claim_role(&"role:ranged_lane", &"enemy:blackboard_a", active), "one actor cannot silently occupy multiple coordination roles")
    _expect(active.request_transition(EnemyRootLifecycle.State.DEFEATED, &"combat:defeated"), "role fixture defeats first actor")
    _expect(not board.try_claim_role(&"role:support", &"enemy:blackboard_a", active), "Defeated actor cannot claim a new group role")
    _expect(board.release_actor_roles(&"enemy:blackboard_a") == 1, "defeat cleanup can release every role owned by one actor")
    _expect(board.try_claim_role(&"role:flank_left", &"enemy:blackboard_b", other), "released coordination role can be reused by another Active actor")
    _expect(board.release_role(&"role:flank_left", &"enemy:blackboard_b"), "exact role owner can release its claim")
    _expect(board.get_role_owner(&"role:flank_left") == &"", "released role no longer exposes an owner")

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
