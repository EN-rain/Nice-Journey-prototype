extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    await _test_mage_resource_and_tower_context()
    await _test_melee_defense_and_no_unused_resource_bar()

    if _failures == 0:
        print("COMBAT HUD UI TEST PASS")
    else:
        push_error("COMBAT HUD UI TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_mage_resource_and_tower_context() -> void:
    var profile := ProfileCreationService.create_profile(1, "HUD Mage", "mage")
    profile.level = 2
    var gameplay: Node2D = GAMEPLAY_SCENE.instantiate() as Node2D
    gameplay.call("set_profile", profile)
    root.add_child(gameplay)
    await process_frame

    var hud: Node = gameplay.get_node("CombatHUD")
    var hud_root: Control = gameplay.get_node("CombatHUD/Root") as Control
    var panel: Control = gameplay.get_node("CombatHUD/Root/Panel") as Control
    var hp_value: Label = gameplay.get_node("CombatHUD/Root/Panel/Layout/HPRow/Value") as Label
    var stamina_value: Label = gameplay.get_node("CombatHUD/Root/Panel/Layout/StaminaRow/Value") as Label
    var mana_row: Control = gameplay.get_node("CombatHUD/Root/Panel/Layout/ManaRow") as Control
    var mana_value: Label = gameplay.get_node("CombatHUD/Root/Panel/Layout/ManaRow/Value") as Label
    var context: Label = gameplay.get_node("CombatHUD/Root/Panel/Layout/Context") as Label
    var cooldowns: Label = gameplay.get_node("CombatHUD/Root/Panel/Layout/Cooldowns") as Label
    var burn_status: Control = gameplay.get_node("CombatHUD/Root/Panel/Layout/BurnStatus") as Control
    var burn_status_icon: TextureRect = gameplay.get_node("CombatHUD/Root/Panel/Layout/BurnStatus/Icon") as TextureRect
    var burn_status_label: Label = gameplay.get_node("CombatHUD/Root/Panel/Layout/BurnStatus/Label") as Label
    var slow_status: Control = gameplay.get_node("CombatHUD/Root/Panel/Layout/SlowStatus") as Control
    var slow_status_icon: TextureRect = gameplay.get_node("CombatHUD/Root/Panel/Layout/SlowStatus/Icon") as TextureRect
    var slow_status_label: Label = gameplay.get_node("CombatHUD/Root/Panel/Layout/SlowStatus/Label") as Label
    var quest_label: Label = gameplay.get_node("CombatHUD/Root/Panel/Layout/Quest") as Label
    var skills_header: Label = gameplay.get_node("CombatHUD/Root/Panel/Layout/SkillsHeader") as Label
    var active_skill_1_icon: TextureRect = gameplay.get_node("CombatHUD/Root/Panel/Layout/ActiveSkill1/Icon") as TextureRect
    var active_skill_1_label: Label = gameplay.get_node("CombatHUD/Root/Panel/Layout/ActiveSkill1/Label") as Label
    var active_skill_2_icon: TextureRect = gameplay.get_node("CombatHUD/Root/Panel/Layout/ActiveSkill2/Icon") as TextureRect
    var active_skill_2_label: Label = gameplay.get_node("CombatHUD/Root/Panel/Layout/ActiveSkill2/Label") as Label
    var player: PlayerController = gameplay.get_node("Player") as PlayerController
    var combat: ClassCombatRuntime = gameplay.get_node("ClassCombatRuntime") as ClassCombatRuntime
    var floor_host: TowerFloorSessionHost = gameplay.get_node("TowerFloorSessionHost") as TowerFloorSessionHost

    _expect(bool(hud.call("refresh_from_runtime")), "combat HUD reads configured live gameplay owners")
    _expect(mana_row.visible, "Mage HUD exposes the authored mana resource")
    _expect(gameplay.get_node_or_null("CombatHUD/Root/Panel/Layout/AmmoRow") == null, "approved no-ammunition starter contract creates no unused ammo HUD row")
    _expect(hp_value.text == "%d/%d" % [player.health.current_hp, player.health.get_max_hp()], "HUD HP text matches the live health owner")
    _expect(stamina_value.text == "%d/%d" % [roundi(player.stamina.current_stamina), roundi(player.stamina.get_max_stamina())], "HUD stamina text matches the live stamina owner")
    _expect(mana_value.text == "%d/%d" % [roundi(combat.get_mana()), roundi(combat.get_max_mana())], "HUD mana text matches the live Mage resource owner")
    _expect(skills_header.visible and skills_header.text.contains("Loadout only"), "HUD exposes active skills explicitly as a non-actionable loadout view")
    _expect(active_skill_1_label.text.contains("Arcane Lance") and active_skill_2_label.text.contains("Delayed Pulse"), "Mage HUD uses authored active-skill display names from persistent loadout state")
    _expect(active_skill_1_label.text.contains("PLAYTEST Ready") and active_skill_2_label.text.contains("PLAYTEST Ready") and not active_skill_1_label.text.contains("Production ready"), "Mage HUD labels executable provisional Q/R skills without claiming final production action authority")
    _expect(active_skill_1_icon.texture != null and active_skill_2_icon.texture != null, "Mage HUD resolves both equipped active skills through the existing UI icon catalog")
    _expect(not burn_status.visible and not slow_status.visible, "HUD hides inactive prototype status rows")

    var status_encounter := CombatEncounterRuntime.new()
    _expect(status_encounter.configure(&"encounter:hud_status"), "HUD status fixture configures encounter runtime")
    var status_state := PlayerCombatantRuntimeBinding.create_state(player, combat, preload("res://src/data/tuning/player_combat_runtime_default.tres"), &"player:hud_status")
    _expect(status_state != null and status_encounter.register_player(status_state), "HUD status fixture registers the live player status owner")
    _expect(player.bind_combat_runtime(status_encounter, status_state.actor_id), "HUD status fixture exposes the bound authoritative runtime to presentation")
    status_encounter.apply_status_to_target(status_state.actor_id, {"status_id": &"burn:hud", "behavior": &"burn", "magnitude": 2.0, "duration_ticks": 90})
    status_encounter.apply_status_to_target(status_state.actor_id, {"status_id": &"slow:hud", "behavior": &"slow", "magnitude": 0.2, "duration_ticks": 120})
    hud.call("refresh_from_runtime")
    _expect(burn_status.visible and slow_status.visible, "HUD exposes active Burn and Slow rows from encounter-owned status state")
    _expect(burn_status_icon.texture != null and slow_status_icon.texture != null, "HUD reuses the existing Burn/Slow icon catalog profiles")
    _expect(burn_status_label.text.contains("burn:hud") and burn_status_label.text.contains("90t"), "Burn HUD state exposes authoritative identity and remaining fixed ticks")
    _expect(slow_status_label.text.contains("slow:hud") and slow_status_label.text.contains("120t"), "Slow HUD state exposes authoritative identity and remaining fixed ticks")
    status_encounter.advance_status_ticks(90)
    hud.call("refresh_from_runtime")
    _expect(not burn_status.visible and slow_status.visible and slow_status_label.text.contains("30t"), "HUD removes expired Burn while keeping the independently active Slow")
    player.unbind_combat_runtime()

    _expect(player.health.set_current_hp(player.health.get_max_hp() - 23), "HUD fixture changes live HP through HealthComponent")
    _expect(player.stamina.apply_combat_value(31.0, true), "HUD fixture changes live stamina through StaminaComponent")
    _expect(combat.resource_pool.set_value(ClassCombatRuntime.RESOURCE_MANA, 41.0), "HUD fixture changes live mana through the authoritative resource pool")
    hud.call("refresh_from_runtime")
    _expect(hp_value.text.begins_with(str(player.health.get_max_hp() - 23)), "HUD refresh reflects live HP changes")
    _expect(stamina_value.text.begins_with("31/"), "HUD refresh reflects live stamina changes")
    _expect(mana_value.text.begins_with("41/"), "HUD refresh reflects live mana changes")

    _expect(combat.action_state_machine.restore_cooldown_state({&"action:test_hud": 30}), "HUD fixture seeds an authoritative action cooldown")
    hud.call("refresh_from_runtime")
    _expect(cooldowns.text.contains("action:test_hud"), "HUD exposes active cooldown identity from ActionStateMachine state")
    var cooldown_snapshot: Dictionary = hud.call("current_snapshot")
    (cooldown_snapshot.get("cooldowns", {}) as Dictionary).clear()
    _expect(not (hud.call("current_snapshot") as Dictionary).get("cooldowns", {}).is_empty(), "callers cannot mutate the HUD's authoritative snapshot copy")

    floor_host.active_floor_id = 4
    hud.call("refresh_from_runtime")
    var floor_entry := PrototypeTowerFloorCatalog.get_entry(4)
    var recommended := int(floor_entry.get("recommended_level", 0))
    var expected_danger := DangerEvaluator.display_name(DangerEvaluator.evaluate_rank(profile.level, recommended))
    _expect(context.text.contains("Tower Floor 4"), "HUD exposes current Tower floor identity from the live floor host")
    _expect(context.text.contains("Recommended Lv.%d" % recommended), "HUD exposes the authored recommended level for the current Tower floor")
    _expect(context.text.contains(expected_danger), "HUD danger text uses the shared DangerEvaluator instead of a presentation-only rank")

    var quest_objective := AnnihilationObjectiveState.new()
    _expect(quest_objective.configure([&"enemy:hud_a", &"enemy:hud_b"]), "HUD quest fixture configures the current floor's designated objective")
    _expect(bool(quest_objective.record_actor_defeated(&"enemy:hud_a").get("accepted", false)), "HUD quest fixture records authoritative objective progress")
    profile.quest_progress["primary_floor_4"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": &"floor_objective",
        "attempt_id": &"attempt:hud_floor4",
        "objective_state": quest_objective.to_dictionary(),
    }
    hud.call("refresh_from_runtime")
    _expect(quest_label.visible and quest_label.text.contains("primary_floor_4"), "live HUD exposes only the current Tower floor's active primary objective")
    _expect(quest_label.text.contains("Defeated 1/2"), "live HUD objective text reflects persisted annihilation progress")

    var settings: Node = root.get_node_or_null("AccessibilitySettings")
    if settings != null:
        settings.call("set_ui_scale", 1.25)
        settings.call("set_text_scale", 1.25)
        await process_frame
        _expect(hud_root.theme != null and is_equal_approx(hud_root.theme.default_base_scale, 1.25) and hud_root.theme.default_font_size == 20, "combat HUD consumes the global UI/text accessibility scale")
        var panel_rect := panel.get_global_rect()
        _expect(panel_rect.position.x >= 0.0 and panel_rect.position.y >= 0.0 and panel_rect.end.x <= 640.0 and panel_rect.end.y <= 360.0, "largest supported UI/text scale keeps the combat HUD inside the minimum 640x360 canvas")
        settings.call("set_ui_scale", 1.0)
        settings.call("set_text_scale", 1.0)

    gameplay.queue_free()
    await process_frame


func _test_melee_defense_and_no_unused_resource_bar() -> void:
    var profile := ProfileCreationService.create_profile(2, "HUD Melee", "melee")
    var gameplay: Node2D = GAMEPLAY_SCENE.instantiate() as Node2D
    gameplay.call("set_profile", profile)
    root.add_child(gameplay)
    await process_frame

    var hud: Node = gameplay.get_node("CombatHUD")
    var mana_row: Control = gameplay.get_node("CombatHUD/Root/Panel/Layout/ManaRow") as Control
    var state_label: Label = gameplay.get_node("CombatHUD/Root/Panel/Layout/State") as Label
    var combat: ClassCombatRuntime = gameplay.get_node("ClassCombatRuntime") as ClassCombatRuntime

    _expect(not mana_row.visible, "non-Mage HUD hides the unused mana row")
    _expect(combat.request_block(true), "Melee fixture enters the genuine supported Block state")
    hud.call("refresh_from_runtime")
    _expect(state_label.text.contains("BLOCK"), "HUD defense state reflects the authoritative ClassCombatRuntime mode")
    combat.request_block(false)
    hud.call("refresh_from_runtime")
    _expect(state_label.text.contains("NONE"), "HUD defense state clears when the authoritative runtime leaves Block")

    gameplay.queue_free()
    await process_frame


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
