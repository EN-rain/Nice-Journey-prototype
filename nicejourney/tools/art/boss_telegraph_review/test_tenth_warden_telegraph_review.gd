extends SceneTree

const REVIEW: TenthWardenTelegraphReviewFixture = preload(
    "res://tools/art/boss_telegraph_review/tenth_warden_telegraph_review_only.tres"
)

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if REVIEW == null:
        push_error("Boss telegraph REVIEW fixture does not load")
        quit(1)
        return
    var review_errors := REVIEW.validate_review()
    var production_errors := REVIEW.validate_production_ready()
    if not review_errors.is_empty():
        push_error("Five-move isolated review failed: %s" % str(review_errors))
        quit(1)
        return
    if production_errors.size() < 7:
        push_error("Fail-closed production gate must report playtest and five unapproved move geometries: %s" % str(production_errors))
        quit(1)
        return
    print("TENTH WARDEN TELEGRAPH REVIEW PASS: 5/5 accepted primitive profiles; 0/5 production final approvals")
    print("TENTH WARDEN PRODUCTION FAIL-CLOSED: ", str(production_errors))
    quit(0)
