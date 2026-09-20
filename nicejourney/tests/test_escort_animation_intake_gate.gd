extends SceneTree

# Synthetic, non-production geometry verifies the animation-intake validator.
# These painted test fixtures are NOT escort art and must never be exported or
# marked accepted in the 223-record visual inventory.
const ACCEPTED_STATIC: NpcVisualProfile = preload("res://src/world/npc/presentation/profiles/temporary_escort.tres")
var _failures := 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _expect(ACCEPTED_STATIC.texture.get_size() == Vector2(32, 32) and ACCEPTED_STATIC.animation_library == null and ACCEPTED_STATIC.validate_presentation().is_empty(), "accepted 32px escort identity remains static and valid")

    var valid := _fixture_profile()
    _expect(valid.validate_presentation().is_empty(), "synthetic ten-cell fixture satisfies proposed 4 idle/6 walk authoring shape (not art acceptance)")
    _expect(valid.animation_for_semantic_state(&"wait") == &"idle" and valid.animation_for_semantic_state(&"follow") == &"walk" and valid.animation_for_semantic_state(&"panic") == &"walk", "wait/follow/panic use existing authored idle/walk clips only")

    var presenter := NpcVisualPresenter.new()
    presenter.profile = valid
    root.add_child(presenter)
    _expect(presenter.sprite != null and presenter.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and presenter.sprite.hframes == 10 and presenter.sprite.vframes == 1, "candidate animation can only render as ten native nearest-filtered cells")
    _expect(presenter.animation_player != null and presenter.animation_player.has_animation(&"idle") and presenter.animation_player.has_animation(&"walk"), "real AnimationPlayer receives inspector library when validated")
    if presenter.animation_player != null:
        presenter.set_semantic_state(&"follow")
        _expect(presenter.animation_player.current_animation == "walk", "follow selects the six-frame walk animation")
        presenter.animation_player.advance(0.21)
        var prior_time := presenter.animation_player.current_animation_position
        presenter.set_semantic_state(&"follow")
        _expect(is_equal_approx(prior_time, presenter.animation_player.current_animation_position), "repeated follow physics ticks do not reset the looping walk")
        presenter.set_semantic_state(&"wait")
        _expect(presenter.animation_player.current_animation == "idle", "wait selects the four-frame idle animation")
    presenter.queue_free()
    await process_frame

    var missing_source := _fixture_profile()
    missing_source.texture = ACCEPTED_STATIC.texture
    _expect(not missing_source.validate_presentation().is_empty(), "static identity cannot masquerade as ten animation frames")

    var no_library := _fixture_profile()
    no_library.animation_library = null
    _expect(_has_problem(no_library, "requires a validated external AnimationLibrary"), "ten-frame sheet cannot masquerade as the accepted one-frame static actor")

    var missing_walk := _fixture_profile()
    missing_walk.animation_library.remove_animation(&"walk")
    _expect(_has_problem(missing_walk, "exactly idle and walk"), "missing walk/incorrect library count fails closed")

    var wrong_mapping := _fixture_profile()
    wrong_mapping.panic_animation = &"idle"
    _expect(_has_problem(wrong_mapping, "follow/panic->walk"), "escort cannot invent a separate panic clip or silently use idle")

    var wrong_frame_count := _fixture_profile()
    var short_walk := wrong_frame_count.animation_library.get_animation(&"walk")
    short_walk.track_remove_key(0, 5)
    _expect(_has_problem(wrong_frame_count, "6 discrete"), "five walk keys cannot satisfy the six-frame contract")

    var wrong_cell_order := _fixture_profile()
    wrong_cell_order.animation_library.get_animation(&"walk").track_set_key_value(0, 1, 4)
    _expect(_has_problem(wrong_cell_order, "unique ordered source cells"), "repeated animation frame index cannot pass as genuine motion")

    var wrong_track := _fixture_profile()
    wrong_track.animation_library.get_animation(&"walk").track_set_path(0, NodePath("NpcSprite:modulate"))
    _expect(_has_problem(wrong_track, "6 discrete"), "visual-property tracks cannot masquerade as a walk frame track")

    var wrong_interpolation := _fixture_profile()
    wrong_interpolation.animation_library.get_animation(&"walk").track_set_interpolation_type(0, Animation.INTERPOLATION_LINEAR)
    _expect(_has_problem(wrong_interpolation, "6 discrete"), "animated frames must remain discrete and nearest-interpolated")

    var unlooped := _fixture_profile()
    unlooped.animation_library.get_animation(&"idle").loop_mode = Animation.LOOP_NONE
    _expect(_has_problem(unlooped, "looping"), "escort idle must loop rather than stop in an uninitialized pose")

    var late_start := _fixture_profile()
    var idle := late_start.animation_library.get_animation(&"idle")
    idle.track_set_key_time(0, 0, 0.01)
    _expect(_has_problem(late_start, "strictly increasing"), "animation clips cannot wait on an uninitialized first frame")

    var duplicated_pixels := _fixture_profile()
    var duplicate_image := duplicated_pixels.texture.get_image()
    duplicate_image.blit_rect(duplicate_image, Rect2i(0, 0, 32, 32), Vector2i(32, 0))
    duplicated_pixels.texture = ImageTexture.create_from_image(duplicate_image)
    _expect(_has_problem(duplicated_pixels, "duplicates frame"), "identical source pixels cannot be padded into four idle frames")

    var single_pixel_noise := _fixture_profile()
    var noise_image := single_pixel_noise.texture.get_image()
    noise_image.blit_rect(noise_image, Rect2i(0, 0, 32, 32), Vector2i(32, 0))
    noise_image.set_pixel(33, 3, Color.WHITE)
    single_pixel_noise.texture = ImageTexture.create_from_image(noise_image)
    _expect(_has_problem(single_pixel_noise, "insufficient motion"), "single-pixel noise cannot stand in for a distinct animated pose")

    var invisible_noise := _fixture_profile()
    var invisible_image := invisible_noise.texture.get_image()
    invisible_image.blit_rect(invisible_image, Rect2i(0, 0, 32, 32), Vector2i(32, 0))
    for pixel: int in range(20):
        invisible_image.set_pixel(32 + pixel, 1, Color(1.0, 0.0, 0.0, 0.0))
    invisible_noise.texture = ImageTexture.create_from_image(invisible_image)
    _expect(_has_problem(invisible_noise, "insufficient motion"), "invisible alpha-zero RGB noise cannot pass the motion gate")

    var blank_frame := _fixture_profile()
    var blank_image := blank_frame.texture.get_image()
    blank_image.fill_rect(Rect2i(32, 0, 32, 32), Color.TRANSPARENT)
    blank_frame.texture = ImageTexture.create_from_image(blank_image)
    _expect(_has_problem(blank_frame, "empty frame") and _has_problem(blank_frame, "readable body silhouette"), "blank or empty art cells fail closed")

    var opaque_background := _fixture_profile()
    var background_image := opaque_background.texture.get_image()
    background_image.set_pixel(0, 0, Color.WHITE)
    opaque_background.texture = ImageTexture.create_from_image(background_image)
    _expect(_has_problem(opaque_background, "transparent surrounding canvas"), "opaque background/corner fragments cannot enter transparent sprite art")

    print("ESCORT ANIMATION INTAKE GATE: failures=", _failures, "; genuine source still required")
    quit(_failures)


func _fixture_profile() -> NpcVisualProfile:
    var image := Image.create(320, 32, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    for frame: int in range(10):
        image.fill_rect(Rect2i(frame * 32 + 7 + frame % 3, 6 + frame % 2, 16, 21), Color(0.5, 0.7, 0.8, 1.0))
    var profile := NpcVisualProfile.new()
    profile.role_id = &"npc:temporary_escort"
    profile.texture = ImageTexture.create_from_image(image)
    var library := AnimationLibrary.new()
    library.add_animation(&"idle", _clip(0, 4))
    library.add_animation(&"walk", _clip(4, 6))
    profile.animation_library = library
    return profile


func _clip(first: int, count: int) -> Animation:
    var animation := Animation.new()
    animation.length = float(count) * 0.125
    animation.loop_mode = Animation.LOOP_LINEAR
    var track := animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(track, NodePath("NpcSprite:frame"))
    animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
    for index: int in range(count):
        animation.track_insert_key(track, float(index) * 0.125, first + index)
    return animation


func _has_problem(profile: NpcVisualProfile, token: String) -> bool:
    for error: String in profile.validate_presentation():
        if error.contains(token):
            return true
    return false


func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: ", message)
    else:
        _failures += 1
        push_error("FAIL: " + message)
