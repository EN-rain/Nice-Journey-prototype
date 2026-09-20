extends SceneTree

var _failures: int = 0

const PLAYER_SHEETS: Dictionary = {
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

const ENEMY_ARCHETYPES: Array[String] = [
    "duelist",
    "bruiser",
    "defender",
    "marksman",
    "skirmisher",
    "assassin",
    "mobile_ranged",
    "caster",
    "support",
    "summoner",
    "flying_harrier",
    "controller_disruptor",
]

const FUNCTIONAL_BUILDINGS: Array[String] = [
    "central_tower",
    "quest_hall",
    "blacksmith",
    "merchant",
    "inn",
    "storage",
    "training",
    "clinic",
]

const SKILL_ICONS: Array[String] = [
    "arc_cleave",
    "driving_thrust",
    "riposte",
    "efficient_footwork",
    "breaker",
    "parry_recovery",
    "piercing_shot",
    "fan_shot",
    "backstep_shot",
    "longshot",
    "fleet_recovery",
    "expose",
    "arcane_lance",
    "delayed_pulse",
    "aegis_ward",
    "mana_weave",
    "flow_recovery",
    "stable_casting",
]

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_player_animation_inventory()
    _test_weapon_vfx_and_telegraph_inventory()
    _test_enemy_inventory()
    _test_region3_inventory()
    _test_tower_inventory()
    _test_ui_inventory()

    if _failures == 0:
        print("VISUAL ASSET INVENTORY TEST PASS")
    else:
        push_error("VISUAL ASSET INVENTORY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_player_animation_inventory() -> void:
    _expect(PLAYER_SHEETS.size() == 17, "player production inventory covers all 17 required body animation categories")
    for animation_variant: Variant in PLAYER_SHEETS.keys():
        var animation: String = String(animation_variant)
        var frames: int = int(PLAYER_SHEETS[animation_variant])
        var path: String = "res://assets/art/player/animations/player_body_%s_sheet_v03.png" % animation
        _expect_texture_size(path, Vector2i(frames * 32, 32), "player %s sheet" % animation)

func _test_weapon_vfx_and_telegraph_inventory() -> void:
    var weapon_files: Array[String] = [
        "starter_sword_v02.png",
        "starter_shield_v02.png",
        "starter_bow_v02.png",
        "starter_staff_v02.png",
        "arrow_projectile_v02.png",
        "arcane_projectile_v02.png",
    ]
    for filename: String in weapon_files:
        _expect_file("res://assets/art/player/weapons/%s" % filename, "starter weapon/projectile exists: %s" % filename)

    var player_vfx: Array[String] = [
        "light_slash_trail_v02.png",
        "heavy_slash_trail_v02.png",
        "block_spark_v02.png",
        "parry_spark_v02.png",
        "ranged_release_flash_v02.png",
        "arcane_cast_burst_v02.png",
    ]
    for filename: String in player_vfx:
        _expect_file("res://assets/art/player/vfx/%s" % filename, "player combat VFX exists: %s" % filename)

    var telegraphs: Array[String] = [
        "telegraph_narrow_line_v02.png",
        "telegraph_wide_line_v02.png",
        "telegraph_cone_v02.png",
        "telegraph_short_arc_v02.png",
        "telegraph_wide_sweep_v02.png",
        "telegraph_circle_v02.png",
        "telegraph_delayed_circle_v02.png",
        "telegraph_projectile_lane_v02.png",
        "telegraph_lunge_path_v02.png",
        "telegraph_boss_warning_v02.png",
        "telegraph_block_cue_v02.png",
        "telegraph_parry_cue_v02.png",
        "telegraph_guard_break_v02.png",
    ]
    for filename: String in telegraphs:
        _expect_file("res://assets/art/vfx/telegraphs/%s" % filename, "telegraph primitive exists: %s" % filename)

func _test_enemy_inventory() -> void:
    _expect(ENEMY_ARCHETYPES.size() == 12, "visual inventory represents all 12 reusable enemy archetypes")
    for archetype: String in ENEMY_ARCHETYPES:
        var version: String = "v02"
        var sheet_path: String = "res://assets/art/enemies/%s/enemy_%s_core_sheet_%s.png" % [archetype, archetype, version]
        _expect_texture_size(sheet_path, Vector2i(288, 48), "%s core enemy sheet" % archetype)
        for pose: String in ["idle", "move", "windup", "release", "hit", "death"]:
            _expect_texture_size(
                "res://assets/art/enemies/%s/enemy_%s_%s_%s.png" % [archetype, archetype, pose, version],
                Vector2i(48, 48),
                "%s %s frame" % [archetype, pose]
            )
        if archetype == "defender":
            _expect_texture_size(
                "res://assets/art/enemies/defender/enemy_defender_block_v02.png",
                Vector2i(48, 48),
                "defender block frame"
            )

    _expect_texture_size(
        "res://assets/art/enemies/boss_tenth_warden/tenth_warden_core_sheet_v01.png",
        Vector2i(864, 96),
        "The Tenth Warden core sheet"
    )
    for boss_pose: String in [
        "idle", "phase_two", "twin_cut", "warden_lunge", "arc_volley",
        "crescent_sweep", "punishing_step", "hit", "death"
    ]:
        _expect_texture_size(
            "res://assets/art/enemies/boss_tenth_warden/tenth_warden_%s_v01.png" % boss_pose,
            Vector2i(96, 96),
            "The Tenth Warden %s frame" % boss_pose
        )

func _test_region3_inventory() -> void:
    _expect(FUNCTIONAL_BUILDINGS.size() == 8, "Region 3 visual inventory represents the eight functional structures")
    for building: String in FUNCTIONAL_BUILDINGS:
        var expected_size := Vector2i(224, 224) if building == "central_tower" else Vector2i(192, 192)
        _expect_texture_size(
            "res://assets/art/environments/region3/functional_buildings/region3_%s_exterior_v02.png" % building,
            expected_size,
            "Region 3 %s generated V02 exterior" % building
        )
    for index: int in range(1, 13):
        _expect_texture_size(
            "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_%02d_v02.png" % index,
            Vector2i(160, 160),
            "Region 3 decorative structure %02d current V02" % index
        )
    _expect_texture_size("res://assets/art/environments/region3/props/region3_prop_sheet_v02.png", Vector2i(256, 256), "Region 3 current V02 prop sheet")
    _expect_texture_size("res://assets/art/environments/region3/roads/region3_ground_road_tileset_v02.png", Vector2i(128, 64), "Region 3 current V02 road/ground tileset")
    _expect_texture_size("res://assets/art/environments/region3/ruins/region3_ruins_module_sheet_v02.png", Vector2i(256, 128), "Region 3 current V02 ruins module sheet")
    _expect_texture_size("res://assets/art/environments/region3/outskirts/region3_outskirts_support_sheet_v02.png", Vector2i(192, 128), "Region 3 current V02 outskirts sheet")
    _expect_texture_size("res://assets/art/environments/region3/risk_zone/region3_risk_zone_support_sheet_v02.png", Vector2i(192, 128), "Region 3 current V02 risk-zone sheet")

func _test_tower_inventory() -> void:
    _expect_texture_size("res://assets/art/environments/tower/tiles/tower_common_tileset_v01.png", Vector2i(128, 128), "tower common tileset")
    for room_type: String in ["combat", "safe", "reward", "vendor", "secret", "elite", "objective", "boss"]:
        _expect_texture_size(
            "res://assets/art/environments/tower/rooms/tower_room_%s_v01.png" % room_type,
            Vector2i(96, 96),
            "tower %s room visual" % room_type
        )

func _test_ui_inventory() -> void:
    _expect(SKILL_ICONS.size() == 18, "UI inventory contains one icon contract for each prototype skill")
    for skill_id: String in SKILL_ICONS:
        _expect_texture_size("res://assets/art/ui/skills/skill_%s_v02.png" % skill_id, Vector2i(32, 32), "current skill icon %s" % skill_id)
    for class_id: String in ["melee", "ranged", "mage"]:
        _expect_texture_size("res://assets/art/ui/classes/class_%s_icon_v01.png" % class_id, Vector2i(32, 32), "class icon %s" % class_id)
    for family: String in ["escort", "tower_defense", "annihilation"]:
        _expect_texture_size("res://assets/art/ui/quests/quest_family_%s_v01.png" % family, Vector2i(32, 32), "quest-family icon %s" % family)
    for status_id: String in ["burn", "slow"]:
        _expect_texture_size("res://assets/art/ui/status/status_%s_v01.png" % status_id, Vector2i(32, 32), "status icon %s" % status_id)
    _expect_texture_size("res://assets/art/ui/markers/tower_sigil_icon_v01.png", Vector2i(32, 32), "Tower Sigil icon")
    _expect_texture_size("res://assets/art/ui/markers/map_marker_sheet_v01.png", Vector2i(128, 32), "map marker sheet")

func _expect_texture_size(path: String, expected_size: Vector2i, label: String) -> void:
    var texture: Texture2D = load(path) as Texture2D
    _expect(texture != null, "%s loads" % label)
    if texture == null:
        return
    _expect(Vector2i(texture.get_width(), texture.get_height()) == expected_size, "%s uses expected dimensions %s" % [label, expected_size])

func _expect_file(path: String, message: String) -> void:
    _expect(FileAccess.file_exists(path) or ResourceLoader.exists(path), message)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
