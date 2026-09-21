extends SceneTree

# Real accepted escort profile and presenter; no synthetic source art or quest events.
var _failures := 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var runtime := Region3SideQuestRuntime.new()
    root.add_child(runtime)
    var actor := Region3EscortActor.new()
    runtime.add_child(actor)
    runtime._escort_actor = actor
    var presenter := actor.get_node_or_null("NpcVisualPresenter") as NpcVisualPresenter
    _expect(presenter != null and presenter.sprite != null, "Region 3 escort uses its real Inspector-owned NPC sprite")
    if presenter == null or presenter.sprite == null:
        runtime.queue_free()
        await process_frame
        quit(_failures)
        return

    var origin := actor.global_position
    runtime._sync_escort_visual(origin, true)
    _expect(presenter.semantic_state == &"wait", "spawn and stopped actor select wait")

    actor.global_position += Vector2(4, 0)
    runtime._sync_escort_visual(origin)
    _expect(presenter.semantic_state == &"follow" and presenter.facing_right and not presenter.sprite.flip_h,
        "actual rightward movement selects follow and unmirrored right-facing art")

    var before_left := actor.global_position
    actor.global_position += Vector2(-4, 0)
    runtime._sync_escort_visual(before_left)
    _expect(presenter.semantic_state == &"follow" and not presenter.facing_right and presenter.sprite.flip_h,
        "actual leftward movement selects follow and mirrors the same accepted body")

    var before_vertical := actor.global_position
    actor.global_position += Vector2(0, -4)
    runtime._sync_escort_visual(before_vertical)
    _expect(presenter.semantic_state == &"follow" and not presenter.facing_right and presenter.sprite.flip_h,
        "vertical travel keeps last horizontal facing")

    runtime._sync_escort_visual(actor.global_position)
    _expect(presenter.semantic_state == &"wait" and presenter.sprite.flip_h,
        "no displacement stops follow without changing last facing")

    var before_goal := actor.global_position
    actor.global_position += Vector2(4, 0)
    runtime._sync_escort_visual(before_goal, true)
    _expect(presenter.semantic_state == &"wait" and presenter.facing_right and not presenter.sprite.flip_h,
        "completed final step stops movement while retaining actual final travel direction")

    runtime.queue_free()
    await process_frame
    print("REGION3 ESCORT PRESENTATION FAILURES: ", _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: ", message)
    else:
        _failures += 1
        push_error("FAIL: " + message)
