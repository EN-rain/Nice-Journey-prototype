extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const ARROW: PackedScene = preload("res://src/combat/skills/player_arrow_projectile_v02.tscn")
const ARCANE: PackedScene = preload("res://src/combat/skills/player_arcane_projectile_v02.tscn")
const PLACEHOLDER: PackedScene = preload("res://src/combat/skills/player_projectile_placeholder.tscn")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    for class_id: String in ["ranged", "mage"]:
        await _check_class(class_id)
    if _failures == 0:
        print("PLAYER PROJECTILE SPRITE PRESENTATION TEST PASS")
    else:
        push_error("PLAYER PROJECTILE SPRITE PRESENTATION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _check_class(class_id: String) -> void:
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(ProfileCreationService.create_profile(1, "Projectile art " + class_id, class_id))
    root.add_child(game)
    await process_frame
    game._set_foundation_world_enabled(false)
    game.player.global_position = Vector2(250, 180)
    game.player.apply_aim_direction(Vector2.RIGHT)
    var delivery := game.player_playtest_attack_delivery
    var content := delivery.content
    var expected_scene := ARROW if class_id == "ranged" else ARCANE
    var expected_path := "res://assets/art/player/weapons/arrow_projectile_v02.png" if class_id == "ranged" else "res://assets/art/player/weapons/arcane_projectile_v02.png"
    _expect(content != null and content.validate_content().is_empty(), "%s playtest content and class projectile scenes validate" % class_id)
    _expect(content.ranged_projectile_scene == ARROW and content.mage_projectile_scene == ARCANE,
        "%s scene defaults resolve distinct editor-authored class sprites" % class_id)
    var original_placeholder := content.projectile_placeholder_scene
    _expect(original_placeholder == PLACEHOLDER, "%s pulse/ward placeholder scene remains separate" % class_id)
    var saved_scene := content.ranged_projectile_scene if class_id == "ranged" else content.mage_projectile_scene
    if class_id == "ranged":
        content.ranged_projectile_scene = null
    else:
        content.mage_projectile_scene = null
    _expect(not content.validate_content().is_empty(), "%s missing class sprite scene fails closed" % class_id)
    if class_id == "ranged":
        content.ranged_projectile_scene = saved_scene
    else:
        content.mage_projectile_scene = saved_scene
    _expect(content.validate_content().is_empty(), "%s restored Inspector-owned visual binding validates" % class_id)

    var machine := game.combat_runtime.action_state_machine
    var basic := game.combat_runtime.starter_kit.basic_action
    _expect(game.combat_runtime.request_basic_attack(Vector2.RIGHT), "%s basic starts via live action owner" % class_id)
    for _tick: int in basic.startup_ticks + basic.commit_ticks:
        machine.advance_fixed_tick()
    _check_projectile(delivery, expected_path, class_id + " basic")

    machine.force_interrupt(&"test:projectile_sprite_skill")
    var action_result := game.request_active_skill_slot(0)
    _expect(bool(action_result.get("accepted", false)), "%s Q starts through equipped skill owner" % class_id)
    var skill_action := action_result.get("action_definition") as ActionDefinition
    if skill_action != null:
        for _tick: int in skill_action.startup_ticks + skill_action.commit_ticks:
            machine.advance_fixed_tick()
    _expect((delivery.get("_projectiles") as Array).size() >= 2, "%s basic and skill both have live traveling visuals" % class_id)
    if (delivery.get("_projectiles") as Array).size() >= 2:
        var projectile := (delivery.get("_projectiles") as Array).back() as Dictionary
        _check_sprite(projectile.get("visual") as Node2D, expected_path, class_id + " active skill")
    if DisplayServer.get_name() != "headless":
        # The canonical action owner permits already-fired projectiles to
        # finish travel after an interruption; clear overlapping action pose
        # art while inspecting the spawned projectile pixels independently.
        _expect(machine.force_interrupt(&"test:projectile_renderer_visibility"),
            "%s committed action interrupted for unobscured projectile visual evidence" % class_id)
        # Move the real spawned projectile out of the player's overlapping
        # sprite before judging source RGB in the rendered gameplay screenshot.
        for _travel_tick: int in 24:
            await physics_frame
            var clear_of_player := false
            for record: Dictionary in delivery.get("_projectiles") as Array:
                var shot := record.get("visual") as Node2D
                if shot != null and is_instance_valid(shot) and shot.global_position.distance_to(game.player.global_position) >= 52.0:
                    clear_of_player = true
                    break
            if clear_of_player:
                break
    await _capture_if_renderer(class_id, delivery)
    await _capture_normal_hud_unoccluded(class_id, delivery)

    if class_id == "mage":
        var pulse := content.skill_for(&"delayed_pulse")
        delivery._spawn_delayed_pulse(pulse, PlayerPlaytestAttackContent.make_payload(pulse), Vector2.RIGHT, 99001)
        var pulses := delivery.get("_pulses") as Array
        _expect(not pulses.is_empty(), "Mage delayed pulse remains a distinct area visual")
        if not pulses.is_empty():
            var pulse_visual := (pulses.back() as Dictionary).get("visual") as Node2D
            _expect(pulse_visual != null and pulse_visual.get_node_or_null("ColorShape") is Polygon2D,
                "Mage delayed pulse still instantiates the original area placeholder")

    game.queue_free()
    await process_frame


func _capture_normal_hud_unoccluded(class_id: String, delivery: PlayerPlaytestAttackDelivery) -> void:
    if DisplayServer.get_name() == "headless":
        return
    var gameplay := delivery.get_parent()
    var panel := gameplay.get_node_or_null("CombatHUD/Root/Panel") as Control
    if panel == null or not panel.is_visible_in_tree():
        print("NORMAL-HUD CLEAR-TRAVEL UNVERIFIED: %s HUD panel not active" % class_id)
        return
    # Preserve real spawn, movement, range, contact, and lifespan. Both basic
    # and equipped Q must remain live beyond the panel's right edge x=348.
    var required_instances: Array[int] = []
    for record: Dictionary in delivery.get("_projectiles") as Array:
        required_instances.append(int(record.get("action_instance_id", -1)))
    if required_instances.size() != 2 or required_instances[0] == required_instances[1]:
        print("NORMAL-HUD CLEAR-TRAVEL UNVERIFIED: %s distinct basic/Q not simultaneously live" % class_id)
        return
    var captured: Array[Dictionary] = []
    for _tick: int in 80:
        captured.clear()
        for record: Dictionary in delivery.get("_projectiles") as Array:
            if not required_instances.has(int(record.get("action_instance_id", -1))):
                continue
            var shot := record.get("visual") as Node2D
            if shot != null and is_instance_valid(shot):
                var pos := shot.get_global_transform_with_canvas().origin
                if pos.x >= 365.0 and pos.x <= 615.0 and absf(pos.y - 180.0) < 8.0:
                    captured.append({"action_instance_id": int(record["action_instance_id"]),
                        "canvas_origin": [pos.x, pos.y], "traveled": float(record["traveled"]),
                        "range": float(record["range"]), "remaining": int(record["remaining"])})
        if captured.size() == 2 and captured[0]["action_instance_id"] != captured[1]["action_instance_id"]:
            break
        await physics_frame
    if captured.size() != 2 or captured[0]["action_instance_id"] == captured[1]["action_instance_id"]:
        print("NORMAL-HUD CLEAR-TRAVEL UNVERIFIED: %s basic/Q cannot both clear x365 before expiry; remaining=%s" %
            [class_id, delivery.get("_projectiles")])
        return
    var was_processing := delivery.is_physics_processing()
    delivery.set_physics_process(false)
    for _frame: int in 3:
        await process_frame
    RenderingServer.force_draw(true)
    var capture := root.get_viewport().get_texture().get_image()
    if capture != null and not capture.is_empty() and panel.is_visible_in_tree():
        var dir := "res://artifacts/combat"
        if DirAccess.make_dir_recursive_absolute(dir) == OK:
            var path := "%s/player_projectile_%s_v02_normal_hud_clear_renderer_evidence.png" % [dir, class_id]
            var metadata := "%s/player_projectile_%s_v02_normal_hud_clear_positions.json" % [dir, class_id]
            if capture.save_png(path) == OK:
                var file := FileAccess.open(metadata, FileAccess.WRITE)
                if file != null:
                    file.store_string(JSON.stringify({
                        "class_id": class_id, "capture": path,
                        "framebuffer_size": [capture.get_width(), capture.get_height()],
                        "normal_hud_panel_visible": panel.is_visible_in_tree(),
                        "normal_hud_panel_rect": [8, 8, 340, 236],
                        "projectiles": captured,
                    }, "\t") + "\n")
                    file.close()
                print("NORMAL-HUD CLEAR-TRAVEL EVIDENCE: %s metadata=%s projectiles=%s" %
                    [path, metadata, captured])
    delivery.set_physics_process(was_processing)


func _capture_if_renderer(class_id: String, delivery: PlayerPlaytestAttackDelivery) -> void:
    if DisplayServer.get_name() == "headless":
        return
    var records := delivery.get("_projectiles") as Array
    print("PROJECTILE CAPTURE OWNER: %s delivery_visible=%s canvas=%s delivery_modulate=%s viewport=%s" %
        [class_id, delivery.is_visible_in_tree(), delivery.get_global_transform_with_canvas().origin,
         delivery.modulate, root.get_viewport().get_visible_rect()])
    var gameplay := delivery.get_parent()
    var pause_panel := gameplay.get_node_or_null("PauseLayer/PausePanel") as Control
    var death_panel := gameplay.get_node_or_null("DeathRetryOverlay/Panel") as Control
    print("PROJECTILE CAPTURE OVERLAYS: %s paused=%s pause_visible=%s death_visible=%s focus=%s" %
        [class_id, paused, pause_panel != null and pause_panel.is_visible_in_tree(),
         death_panel != null and death_panel.is_visible_in_tree(),
         DisplayServer.window_is_focused()])
    for projectile: Dictionary in records:
        var visual := projectile.get("visual") as Node2D
        if visual != null and is_instance_valid(visual):
            var sprite := visual.get_node_or_null("Body") as Sprite2D
            print("PROJECTILE CAPTURE POSITION: %s world=%s screen=%s visual_visible=%s sprite_visible=%s sprite_screen=%s sprite_modulate=%s visual_modulate=%s queued=%s" % [
                class_id, visual.global_position, visual.get_global_transform_with_canvas().origin,
                visual.is_visible_in_tree(), sprite != null and sprite.is_visible_in_tree(),
                sprite.get_global_transform_with_canvas().origin if sprite != null else Vector2.INF,
                sprite.modulate if sprite != null else Color.TRANSPARENT,
                visual.modulate, visual.is_queued_for_deletion()])
            var chain: Node = sprite
            while chain != null:
                if chain is CanvasItem:
                    var item := chain as CanvasItem
                    print("PROJECTILE DRAW CHAIN: %s %s visible=%s modulate=%s self_modulate=%s z=%d top_level=%s material=%s" %
                        [class_id, item.get_path(), item.is_visible_in_tree(),
                         item.modulate, item.self_modulate, item.z_index,
                         item.top_level, item.material])
                chain = chain.get_parent()
    # Capture on the ACTIVE spawn frame, before another physics tick can hit a
    # nearby actor, wall or range limit. Preserve earlier evidence separately.
    RenderingServer.force_draw(true)
    var image := root.get_viewport().get_texture().get_image()
    if image == null or image.is_empty():
        print("RENDERER EVIDENCE UNAVAILABLE: %s framebuffer is empty" % class_id)
        return
    var evidence_dir := "res://artifacts/combat"
    if DirAccess.make_dir_recursive_absolute(evidence_dir) != OK:
        print("RENDERER EVIDENCE UNAVAILABLE: cannot create artifacts/combat")
        return
    var path := "%s/player_projectile_%s_v02_immediate_renderer_evidence.png" % [evidence_dir, class_id]
    if image.save_png(path) == OK:
        print("RENDERER EVIDENCE: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
    else:
        print("RENDERER EVIDENCE UNAVAILABLE: save failed for %s" % class_id)
    # Newly instantiated CanvasItems can report visible before the native
    # renderer has submitted their first frame. Keep live spawned visuals
    # stationary ONLY inside this visual-test capture, then allow three
    # process/render frames; no player/damage/projectile production changes.
    var was_processing := delivery.is_physics_processing()
    delivery.set_physics_process(false)
    for _frame: int in 3:
        await process_frame
    RenderingServer.force_draw(true)
    var stable_image := root.get_viewport().get_texture().get_image()
    if stable_image != null and not stable_image.is_empty():
        var stable_path := "%s/player_projectile_%s_v02_stable_live_renderer_evidence.png" % [evidence_dir, class_id]
        if stable_image.save_png(stable_path) == OK:
            print("STABLE LIVE RENDERER EVIDENCE: %s (%dx%d)" % [
                stable_path, stable_image.get_width(), stable_image.get_height()])
            var origins: Array = []
            for record: Dictionary in delivery.get("_projectiles") as Array:
                var shot := record.get("visual") as Node2D
                if shot != null and is_instance_valid(shot):
                    var canvas_origin := shot.get_global_transform_with_canvas().origin
                    origins.append([canvas_origin.x, canvas_origin.y])
            var position_path := "%s/player_projectile_%s_v02_stable_live_positions.json" % [evidence_dir, class_id]
            var positions_file := FileAccess.open(position_path, FileAccess.WRITE)
            if positions_file != null:
                positions_file.store_string(JSON.stringify({
                    "class_id": class_id,
                    "capture": stable_path,
                    "framebuffer_size": [stable_image.get_width(), stable_image.get_height()],
                    "projectile_canvas_origins": origins,
                    "source": "live _projectiles visual.get_global_transform_with_canvas before paused stable capture",
                }, "\t") + "\n")
                positions_file.close()
                print("STABLE LIVE POSITION EVIDENCE: %s" % position_path)
        else:
            print("STABLE LIVE RENDERER EVIDENCE UNAVAILABLE: save failed for %s" % class_id)
    # One bounded intentional-tint diagnostic. Do NOT modify GameplayRoot or
    # hide arbitrary UI: disable only a visible fullscreen ColorRect/CanvasModulate
    # proven to cover the viewport, then restore its exact original visibility.
    var possible_tints: Array[CanvasItem] = []
    var pending: Array[Node] = [gameplay]
    while not pending.is_empty():
        var current: Node = pending.pop_back() as Node
        if current is CanvasModulate:
            var ambient := current as CanvasModulate
            print("LIVE FULLSCREEN CANVAS MODULATE: %s color=%s visible=%s" % [
                ambient.get_path(), ambient.color, ambient.is_visible_in_tree()])
            if ambient.is_visible_in_tree() and ambient.color != Color.WHITE:
                possible_tints.append(ambient)
        if current is ColorRect:
            var rect := current as ColorRect
            var full_screen := rect.is_visible_in_tree() and rect.size.x >= 640.0 and rect.size.y >= 360.0 and rect.color.a > 0.0
            if full_screen:
                print("LIVE FULLSCREEN COLORRECT: %s color=%s rect=%s" % [
                    rect.get_path(), rect.color, rect.get_global_rect()])
                possible_tints.append(rect)
        for child: Node in current.get_children():
            pending.append(child)
    print("LIVE EXPLICIT FULLSCREEN TINT COUNT: %s %d" % [class_id, possible_tints.size()])
    if not possible_tints.is_empty():
        for tint: CanvasItem in possible_tints:
            tint.visible = false
        for _frame: int in 3:
            await process_frame
        RenderingServer.force_draw(true)
        var untinted := root.get_viewport().get_texture().get_image()
        if untinted != null and not untinted.is_empty():
            var untinted_path := "%s/player_projectile_%s_v02_test_tint_disabled_evidence.png" % [evidence_dir, class_id]
            if untinted.save_png(untinted_path) == OK:
                print("TEST-ONLY TINT-DISABLED EVIDENCE: %s" % untinted_path)
        for tint: CanvasItem in possible_tints:
            tint.visible = true
    # HUD is a separate CanvasLayer (20), above every world z-index. Its
    # Inspector-authored panel occupies the screenshot's projectile corridor.
    # Test ONLY whether panel occlusion explains the darkened source colors.
    var hud_panel := gameplay.get_node_or_null("CombatHUD/Root/Panel") as Control
    if hud_panel != null:
        print("LIVE HUD PANEL COVERAGE: %s visible=%s rect=%s layer=%s" % [
            class_id, hud_panel.is_visible_in_tree(), hud_panel.get_global_rect(),
            (gameplay.get_node("CombatHUD") as CanvasLayer).layer])
        if hud_panel.is_visible_in_tree():
            hud_panel.visible = false
            for _frame: int in 3:
                await process_frame
            RenderingServer.force_draw(true)
            var no_hud := root.get_viewport().get_texture().get_image()
            if no_hud != null and not no_hud.is_empty():
                var no_hud_path := "%s/player_projectile_%s_v02_test_hud_panel_hidden_evidence.png" % [evidence_dir, class_id]
                if no_hud.save_png(no_hud_path) == OK:
                    print("TEST-ONLY HUD-PANEL-HIDDEN EVIDENCE: %s" % no_hud_path)
            hud_panel.visible = true
    delivery.set_physics_process(was_processing)


func _check_projectile(delivery: PlayerPlaytestAttackDelivery, expected_path: String, label: String) -> void:
    var projectiles := delivery.get("_projectiles") as Array
    _expect(projectiles.size() == 1, "%s launches one tracked projectile" % label)
    if projectiles.size() == 1:
        _check_sprite((projectiles[0] as Dictionary).get("visual") as Node2D, expected_path, label)


func _check_sprite(visual: Node2D, expected_path: String, label: String) -> void:
    _expect(visual != null, "%s has a world-owned projectile visual" % label)
    if visual == null:
        return
    var sprite := visual.get_node_or_null("Body") as Sprite2D
    _expect(sprite != null and sprite.texture != null, "%s uses the distinct Sprite2D scene" % label)
    if sprite != null and sprite.texture != null:
        _expect(sprite.texture.resource_path == expected_path, "%s uses the accepted matching PNG" % label)
        _expect(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s has nearest filtering" % label)
        _expect(sprite.texture.get_size() == Vector2(32, 16), "%s retains the accepted 32x16 sprite" % label)
    _expect(visual.z_index == 26, "%s preserves the original projectile visual draw order" % label)


func _expect(ok: bool, description: String) -> void:
    if ok:
        print("PASS: %s" % description)
    else:
        _failures += 1
        push_error("FAIL: %s" % description)
