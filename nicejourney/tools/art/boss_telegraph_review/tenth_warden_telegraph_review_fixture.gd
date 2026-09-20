@tool
class_name TenthWardenTelegraphReviewFixture
extends Resource

# REVIEW ONLY. These accepted primitives are NOT spatially matched to FINAL
# Tenth Warden contact geometry, and are never assigned to live move bindings.
@export var source_playtest: TenthWardenProductionAuthoring
@export var move_ids: Array[StringName] = []
@export var candidate_effects: Array[EffectVisualProfile] = []
@export var expected_effect_ids: Array[StringName] = []

const APPROVED_MOVE_IDS: Array[StringName] = [
    &"twin_cut", &"warden_lunge", &"arc_volley",
    &"crescent_sweep", &"punishing_step",
]

func validate_review() -> PackedStringArray:
    var errors := PackedStringArray()
    if source_playtest == null or not source_playtest.playtest_placeholder:
        errors.append("review requires explicitly PLAYTEST-only combat source")
    if move_ids.size() != APPROVED_MOVE_IDS.size() or candidate_effects.size() != APPROVED_MOVE_IDS.size() or expected_effect_ids.size() != APPROVED_MOVE_IDS.size():
        errors.append("review must contain exactly five paired moves/effects")
        return errors
    for i in APPROVED_MOVE_IDS.size():
        var move_id := APPROVED_MOVE_IDS[i]
        if move_ids[i] != move_id:
            errors.append("unexpected or reordered move: %s" % String(move_ids[i]))
        var candidate := candidate_effects[i]
        if candidate == null:
            errors.append("%s: missing candidate effect" % String(move_id))
            continue
        if candidate.effect_id != expected_effect_ids[i]:
            errors.append("%s: unexpected effect primitive" % String(move_id))
        for error: String in candidate.validate_profile():
            errors.append("%s: %s" % [String(move_id), error])
        var binding := load(
            "res://src/enemies/boss_tenth_warden/presentation/%s_visual_binding.tres" % String(move_id)
        ) as TenthWardenMoveVisualBinding
        if binding == null or binding.move_id != move_id:
            errors.append("%s: production binding missing or mismatched" % String(move_id))
        elif binding.telegraph_profile != null:
            errors.append("%s: production binding unexpectedly carries a REVIEW effect" % String(move_id))
    return errors

func validate_production_ready() -> PackedStringArray:
    var errors := validate_review()
    # An isolated preview MUST fail final binding even if the five effects load.
    if source_playtest == null or source_playtest.playtest_placeholder:
        errors.append("PLAYTEST timing/geometry is not FINAL-approved")
    if source_playtest != null:
        for move_id: StringName in APPROVED_MOVE_IDS:
            var attack := source_playtest.attack_for_move(move_id)
            if attack == null or attack.geometry == null:
                errors.append("%s: no authoritative final attack geometry" % String(move_id))
            elif String(attack.geometry.geometry_id).begins_with("geometry:playtest:"):
                errors.append("%s: source geometry is explicitly PLAYTEST" % String(move_id))
    errors.append("independent visual-to-hit-boundary/phase-duration/readability approvals not provided")
    return errors
