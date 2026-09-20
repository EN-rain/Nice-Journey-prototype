extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
    root.add_child(player)
    await process_frame

    var animator: PlayerBodyAnimator = player.get_node("PlayerBodyAnimator") as PlayerBodyAnimator
    var body: Sprite2D = player.get_node("BodyVisual/Body") as Sprite2D

    _expect(animator != null, "player scene owns the production body animator")
    _expect(body != null, "player scene retains a dedicated body Sprite2D")
    if animator != null and body != null:
        _expect(animator.get_state() == PlayerBodyAnimator.STATE_IDLE, "player body animator starts in idle")
        _expect(body.hframes == 4 and body.texture.get_width() == 128 and body.texture.get_height() == 32, "live image-gen-derived idle sheet slices into four exact 32x32 frames")
        _expect(body.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "player animation presentation preserves nearest-neighbor filtering")

        _expect(animator.resolve_state(false, false, false, 0.0, 80.0, 120.0) == PlayerBodyAnimator.STATE_IDLE, "zero velocity resolves idle")
        _expect(animator.resolve_state(false, false, false, 80.0, 80.0, 120.0) == PlayerBodyAnimator.STATE_WALK, "walk speed resolves walk")
        _expect(animator.resolve_state(false, false, false, 120.0, 80.0, 120.0) == PlayerBodyAnimator.STATE_RUN, "run speed resolves run")
        _expect(animator.resolve_state(false, true, false, 0.0, 80.0, 120.0) == PlayerBodyAnimator.STATE_DASH, "dash presentation outranks ordinary locomotion")
        _expect(animator.resolve_state(false, false, true, 0.0, 80.0, 120.0) == PlayerBodyAnimator.STATE_DODGE, "dodge presentation outranks ordinary locomotion")
        _expect(animator.resolve_state(true, true, true, 120.0, 80.0, 120.0) == PlayerBodyAnimator.STATE_CLIMB, "climb presentation has highest locomotion presentation priority")

    var sheets: Dictionary = {
        "idle": 4,
        "walk": 6,
        "run": 6,
        "dash": 4,
        "dodge": 4,
        "attack": 6,
        "heavy_attack": 6,
        "block": 7,
        "parry": 6,
        "cast": 7,
        "hit": 6,
        "death": 6,
        "interact": 5,
        "pickup": 5,
        "use_item": 7,
        "climb": 6,
        "sleep": 4,
    }
    for name_variant: Variant in sheets.keys():
        var name: String = String(name_variant)
        var frame_count: int = int(sheets[name_variant])
        var path: String = "res://assets/art/player/animations/player_body_%s_sheet_v03.png" % name
        var texture: Texture2D = load(path) as Texture2D
        _expect(texture != null, "%s production animation sheet loads" % name)
        if texture != null:
            _expect(texture.get_width() == frame_count * 32 and texture.get_height() == 32, "%s sheet preserves exact 32x32 frame cells" % name)

    _test_starter_weapon_and_basic_action_presentation(player, animator)

    player.apply_aim_direction(Vector2.LEFT)
    _expect(player.get_node("BodyVisual").scale.x < 0.0, "animation body remains compatible with side-only left mirroring")
    player.apply_aim_direction(Vector2.UP)
    _expect(player.get_node("BodyVisual").scale.x < 0.0, "near-vertical aim retains mirrored body presentation")

    player.queue_free()
    if _failures == 0:
        print("PLAYER BODY ANIMATION ASSET TEST PASS")
    else:
        push_error("PLAYER BODY ANIMATION ASSET TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_starter_weapon_and_basic_action_presentation(player: PlayerController, animator: PlayerBodyAnimator) -> void:
    var machine: ActionStateMachine = ActionStateMachine.new()
    root.add_child(machine)
    var tuning: StarterCombatTuning = StarterCombatTuning.new()

    _expect(player.configure_starter_visuals(&"melee", machine), "Melee starter visuals configure from the locked class identity")
    _expect(player.starter_weapon_visual.get_main_hand_texture() != null, "Melee presentation replaces the line placeholder with a sword texture")
    _expect(player.starter_weapon_visual.has_visible_shield(), "Melee presentation includes the starter shield on the body-facing layer")
    var melee: StarterKitDefinition = StarterKitCatalog.create(&"melee", tuning)
    _expect(machine.request_action(melee.basic_action, Vector2.RIGHT), "Melee basic attack fixture starts")
    _expect(animator.get_action_override() == &"attack", "Melee basic action drives the production attack body sheet without owning action legality")
    while machine.is_busy():
        machine.advance_fixed_tick()
    _expect(animator.get_action_override() == &"", "finishing Melee action releases the presentation override")
    _expect(player.combat_effects.get_last_effect_id() == &"vfx_light_slash_trail", "Melee commit plays the inspector-bound generated slash VFX")

    _expect(player.configure_starter_visuals(&"ranged", machine), "Ranged starter visuals configure")
    _expect(not player.starter_weapon_visual.has_visible_shield(), "Ranged presentation keeps off-hand empty")
    var ranged: StarterKitDefinition = StarterKitCatalog.create(&"ranged", tuning)
    _expect(machine.request_action(ranged.basic_action, Vector2.RIGHT), "Ranged basic attack fixture starts")
    _expect(animator.get_action_override() == &"attack", "Ranged basic action uses the shared weapon-free attack body presentation")
    while machine.is_busy():
        machine.advance_fixed_tick()
    _expect(player.combat_effects.get_last_effect_id() == &"vfx_ranged_release_flash", "Ranged commit plays the inspector-bound generated release VFX")

    _expect(player.configure_starter_visuals(&"mage", machine), "Mage starter visuals configure")
    _expect(not player.starter_weapon_visual.has_visible_shield(), "Mage presentation keeps off-hand empty")
    var mage: StarterKitDefinition = StarterKitCatalog.create(&"mage", tuning)
    _expect(machine.request_action(mage.basic_action, Vector2.RIGHT), "Mage basic attack fixture starts")
    _expect(animator.get_action_override() == &"cast", "Mage basic action drives the production cast body sheet")
    while machine.is_busy():
        machine.advance_fixed_tick()
    _expect(animator.get_action_override() == &"", "finishing Mage action releases the presentation override")
    _expect(player.combat_effects.get_last_effect_id() == &"vfx_arcane_cast_burst", "Mage commit plays the inspector-bound generated Arcane VFX")

    machine.queue_free()

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
