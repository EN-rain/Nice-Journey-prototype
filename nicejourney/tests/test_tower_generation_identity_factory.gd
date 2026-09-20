extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Generation Identity", "ranged")
    _expect(profile != null, "generation identity fixture profile creates")
    if profile != null:
        var tuple_a := TowerGenerationIdentityFactory.build_tuple(profile, 4)
        var tuple_b := TowerGenerationIdentityFactory.build_tuple(profile, 4)
        _expect(not tuple_a.is_empty() and tuple_a == tuple_b, "same profile/floor/state produces an identical complete generation tuple")
        _expect(int(tuple_a.get("generation_seed", -1)) >= 0, "generation identity supplies a nonnegative deterministic seed")
        _expect(StableId.is_valid(String(tuple_a.get("quest_world_flags_signature", &""))), "quest/world flag signature is a stable ID")
        _expect(StableId.is_valid(String(tuple_a.get("instance_id", &""))), "persistent floor instance identity is a stable ID")

        var floor5 := TowerGenerationIdentityFactory.build_tuple(profile, 5)
        _expect(int(floor5.get("generation_seed", -1)) != int(tuple_a.get("generation_seed", -1)), "different floor identity receives a distinct deterministic seed")
        _expect(StringName(floor5.get("instance_id", &"")) != StringName(tuple_a.get("instance_id", &"")), "different floor identity receives a distinct persistent instance ID")

        var signature_before := StringName(tuple_a.get("quest_world_flags_signature", &""))
        profile.permanent_flags["branch:test_fixture"] = true
        var tuple_changed := TowerGenerationIdentityFactory.build_tuple(profile, 4)
        _expect(int(tuple_changed.get("generation_seed", -1)) == int(tuple_a.get("generation_seed", -1)), "world/quest progression changes do not reroll the profile-floor seed")
        _expect(StringName(tuple_changed.get("quest_world_flags_signature", &"")) != signature_before, "world/quest progression changes alter the separate deterministic signature")

        var cloned := ProfileSnapshot.from_dictionary(profile.to_dictionary())
        _expect(TowerGenerationIdentityFactory.build_tuple(cloned, 4) == tuple_changed, "generation tuple survives profile serialization without process-local randomness")
        _expect(TowerGenerationIdentityFactory.build_tuple(profile, 0).is_empty(), "invalid floor cannot fabricate a generation tuple")

    if _failures == 0:
        print("TOWER GENERATION IDENTITY FACTORY TEST PASS")
    else:
        push_error("TOWER GENERATION IDENTITY FACTORY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
