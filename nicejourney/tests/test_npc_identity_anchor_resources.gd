extends SceneTree
const PROFILES = ["tower_quest_coordinator","merchant","blacksmith_upgrader","story_lore","variable_quest","temporary_escort"]
var failures := 0
func _init() -> void:
    call_deferred("_run")
func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)
func _run() -> void:
    var roles := {}
    for id: String in PROFILES:
        var p := load("res://src/world/npc/presentation/profiles/" + id + ".tres") as NpcVisualProfile
        _check(p != null, "profile loads: " + id)
        if p == null: continue
        _check(p.validate_presentation().is_empty(),"profile contract: " + id)
        _check(not roles.has(p.role_id),"unique NPC role: " + id)
        roles[p.role_id] = true
        _check(p.texture != null and p.texture.get_size() == Vector2(32,32),"one complete static32px identity frame: " + id)
        _check(p.texture.resource_path.begins_with("res://assets/art/npc/"),"production texture path: " + id)
        for face_right: bool in [true,false]:
            var n := NpcVisualPresenter.new()
            n.profile = p
            n.facing_right = face_right
            root.add_child(n)
            _check(n.sprite != null,"actual presenter creates sprite: " + id)
            if n.sprite != null:
                _check(n.sprite.texture == p.texture,"actual consumer resolves profile texture: " + id)
                _check(n.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,"native pixel filter: " + id)
                _check(n.sprite.flip_h == not face_right,"mirrored-left presentation: " + id)
                var ground := n.sprite.position + p.ground_anchor - Vector2(p.frame_size)*0.5
                _check(ground.is_equal_approx(Vector2.ZERO),"profile ground anchor maps to entity origin: " + id)
            n.free()
    print("NPC IDENTITY ANCHOR RESOURCE FAILURES: ",failures)
    quit(0 if failures == 0 else 1)
