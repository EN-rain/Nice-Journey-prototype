extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Service Discovery", "ranged")
    var first := Region3ServiceDiscoveryService.mark_discovered(profile, &"r3:functional:04", &"general_merchant")
    _expect(bool(first.get("accepted", false)) and bool(first.get("mutated", false)), "first valid service interaction records live discovery")
    _expect(not bool(first.get("durable", true)), "service discovery is explicitly live/unbanked until a legitimate safe snapshot")
    _expect(Region3ServiceDiscoveryService.is_discovered(profile, &"r3:functional:04"), "recorded service discovery is queryable from profile state")
    var second := Region3ServiceDiscoveryService.mark_discovered(profile, &"r3:functional:04", &"general_merchant")
    _expect(bool(second.get("accepted", false)) and not bool(second.get("mutated", true)), "repeat discovery is idempotent")
    var before := profile.permanent_flags.duplicate(true)
    var mismatch := Region3ServiceDiscoveryService.mark_discovered(profile, &"r3:functional:04", &"blacksmith")
    _expect(not bool(mismatch.get("accepted", true)) and mismatch.get("reason_id") == &"structure_role_mismatch", "mismatched service identity rejects")
    _expect(profile.permanent_flags == before, "rejected discovery cannot mutate profile flags")
    var decorative := Region3ServiceDiscoveryService.mark_discovered(profile, &"r3:decorative:01", &"general_merchant")
    _expect(not bool(decorative.get("accepted", true)), "decorative structure cannot masquerade as a discovered functional service")
    _expect(ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty(), "service-discovery flags preserve profile validity")
    if _failures == 0:
        print("REGION 3 SERVICE DISCOVERY SERVICE TEST PASS")
    else:
        push_error("REGION 3 SERVICE DISCOVERY SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
