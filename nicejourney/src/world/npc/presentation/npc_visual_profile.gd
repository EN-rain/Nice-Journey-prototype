class_name NpcVisualProfile
extends Resource

@export var role_id: StringName = &""
@export var texture: Texture2D = null
@export var animation_library: AnimationLibrary = null
@export var frame_size: Vector2i = Vector2i(32, 32)
@export var ground_anchor: Vector2 = Vector2(16.0, 29.0)
@export var mirror_left: bool = true
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var wait_animation: StringName = &"idle"
@export var follow_animation: StringName = &"walk"
@export var panic_animation: StringName = &"walk"

func animation_for_semantic_state(state: StringName) -> StringName:
    match state:
        &"wait": return wait_animation
        &"follow": return follow_animation
        &"panic": return panic_animation
        &"walk": return walk_animation
        _: return idle_animation

func validate_presentation() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(role_id)): errors.append("role_id must be a stable ID")
    if frame_size != Vector2i(32, 32): errors.append("NPC frame_size must remain 32x32")
    if ground_anchor != Vector2(16.0, 29.0): errors.append("NPC ground_anchor must remain (16,29)")
    if not mirror_left: errors.append("NPC art must author right-facing art and mirror left")
    if role_id == &"npc:temporary_escort":
        if animation_library != null:
            errors.append_array(_validate_escort_animation())
        elif texture != null and texture.get_size() != Vector2(32, 32):
            errors.append("escort animation sheet requires a validated external AnimationLibrary; static identity must be 32x32")
    return errors


func _validate_escort_animation() -> PackedStringArray:
    # This contract applies only when a genuine generated escort sheet is
    # assigned. The accepted one-frame identity stays intentionally static.
    var errors := PackedStringArray()
    if texture == null or texture.get_size() != Vector2(320, 32):
        errors.append("animated escort needs a complete 320x32 ten-cell derivative: four idle, six walk")
        return errors
    if idle_animation != &"idle" or walk_animation != &"walk" or wait_animation != &"idle" or follow_animation != &"walk" or panic_animation != &"walk":
        errors.append("escort visual mappings must remain idle/walk with wait->idle and follow/panic->walk")
    if animation_library.get_animation_list().size() != 2:
        errors.append("escort animation library must contain exactly idle and walk")
    for state: StringName in [&"idle", &"walk"]:
        if not animation_library.has_animation(state):
            errors.append("escort animation missing: %s" % String(state))
            continue
        var clip := animation_library.get_animation(state)
        var expected_count := 4 if state == &"idle" else 6
        var first_frame := 0 if state == &"idle" else 4
        if clip == null or clip.loop_mode != Animation.LOOP_LINEAR or not is_finite(clip.length) or clip.length <= 0.0 or clip.get_track_count() != 1:
            errors.append("escort %s requires one looping, finite, nonempty frame track" % String(state))
            continue
        var track := clip.find_track(NodePath("NpcSprite:frame"), Animation.TYPE_VALUE)
        if track != 0 or clip.track_get_interpolation_type(0) != Animation.INTERPOLATION_NEAREST or clip.track_get_key_count(0) != expected_count:
            errors.append("escort %s must own exactly %d discrete NpcSprite frame keys" % [String(state), expected_count])
            continue
        var previous_time := -1.0
        for frame_index: int in range(expected_count):
            var current_time := clip.track_get_key_time(0, frame_index)
            var frame: Variant = clip.track_get_key_value(0, frame_index)
            if not is_finite(current_time) or current_time <= previous_time or current_time >= clip.length or (frame_index == 0 and current_time > 0.00001):
                errors.append("escort %s frame times must be strictly increasing within clip length" % String(state))
                break
            if typeof(frame) != TYPE_INT or int(frame) != first_frame + frame_index:
                errors.append("escort %s must use its exact unique ordered source cells" % String(state))
                break
            previous_time = current_time
    var image := texture.get_image()
    if image == null or image.is_empty():
        errors.append("escort animation source pixels must be readable for frame-diversity review")
        return errors
    image.convert(Image.FORMAT_RGBA8)
    for group: Array in [[0, 4], [4, 6]]:
        var seen: Dictionary = {}
        var previous_pixels := PackedByteArray()
        for index: int in range(group[0], group[0] + group[1]):
            var frame := image.get_region(Rect2i(index * 32, 0, 32, 32))
            var alpha_bounds := frame.get_used_rect()
            if alpha_bounds.size.x <= 0 or alpha_bounds.size.y <= 0:
                errors.append("escort animation has an empty frame %d" % index)
            if (frame.get_pixel(0, 0).a > 0.0 or frame.get_pixel(31, 0).a > 0.0
                or frame.get_pixel(0, 31).a > 0.0 or frame.get_pixel(31, 31).a > 0.0):
                errors.append("escort animation frame %d lacks a transparent surrounding canvas" % index)
            var pixels := frame.get_data()
            var opaque_pixels := 0
            var changed_pixels := 0
            for offset: int in range(0, pixels.size(), 4):
                if pixels[offset + 3] >= 32:
                    opaque_pixels += 1
                # Alpha-zero RGB noise is invisible and must never count as
                # meaningful motion between generated sprite poses.
                if not previous_pixels.is_empty() and (pixels[offset + 3] >= 32 or previous_pixels[offset + 3] >= 32) and (
                    pixels[offset] != previous_pixels[offset]
                    or pixels[offset + 1] != previous_pixels[offset + 1]
                    or pixels[offset + 2] != previous_pixels[offset + 2]
                    or pixels[offset + 3] != previous_pixels[offset + 3]
                ):
                    changed_pixels += 1
            if opaque_pixels < 64:
                errors.append("escort animation frame %d lacks a readable body silhouette" % index)
            if not previous_pixels.is_empty() and changed_pixels < 12:
                errors.append("escort animation frame %d has insufficient motion over the prior frame" % index)
            var identity := pixels.hex_encode()
            if seen.has(identity):
                errors.append("escort animation duplicates frame %d and frame %d" % [int(seen[identity]), index])
            seen[identity] = index
            previous_pixels = pixels
    return errors
