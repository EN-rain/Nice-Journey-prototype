extends SceneTree
var failures := 0
func _init() -> void:
    call_deferred(&"_run")
func _run() -> void:
    var errors := EnemyArchetypeCatalog.validate_first_slice()
    if not errors.is_empty():
        failures += 1
        push_error("catalog validation failed: %s" % ", ".join(errors))
    if EnemyArchetypeCatalog.first_slice_definitions().size() != 4:
        failures += 1
        push_error("expected four first-slice definitions")
    if failures == 0:
        print("ENEMY FIRST SLICE TEST PASS")
    quit(failures)
