extends SceneTree

const TEST_ROOT := "user://tests/tower_manifest_save_round_trip"
var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var save_service := SaveService.new(TEST_ROOT)
    save_service.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Manifest Save", "melee")
    var request := TowerFloorGenerationCommitService.build_request(4, 44004, &"gen:v1", &"modules:v1", &"encounters:v1", &"flags:baseline")
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    _expect(not manifest.is_empty(), "fallback manifest fixture builds")
    var state := TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:save_round_trip", manifest)
    _expect(state != null, "validated manifest creates floor state")
    _expect(TowerFloorStateService.commit_floor_state(profile, state), "manifest-backed floor state commits to profile")
    var err := save_service.save_profile(1, profile)
    _expect(err == OK, "manifest-backed profile saves to JSON")
    var loaded := save_service.load_profile(1)
    _expect(loaded != null, "manifest-backed profile reloads")
    if loaded != null:
        var raw: Variant = loaded.tower_floor_states.get("4", null)
        _expect(raw is Dictionary, "reloaded profile preserves floor dictionary")
        if raw is Dictionary:
            var restored := FloorInstanceState.new()
            var errors := restored.load_dictionary(raw as Dictionary)
            _expect(errors.is_empty(), "reloaded floor state validates after JSON round trip")
            if errors.is_empty():
                _expect(restored.layout_manifest == manifest, "resolved layout manifest survives JSON persistence exactly")
    save_service.delete_slot(1)
    if _failures == 0:
        print("TOWER MANIFEST SAVE ROUND TRIP TEST PASS")
    else:
        push_error("TOWER MANIFEST SAVE ROUND TRIP TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
