class_name GameplayRoot
extends Node2D

const TOWER_VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const ENEMY_VISUAL_SCENE_CATALOG: EnemyVisualSceneCatalog = preload("res://src/enemies/presentation/enemy_visual_scene_catalog.tres")
const PLAYER_COMBAT_RUNTIME_TUNING: PlayerCombatRuntimeTuning = preload("res://src/data/tuning/player_combat_runtime_default.tres")
const TOWER_PROTOTYPE_ENEMY_RUNTIME_TUNING: TowerPrototypeEnemyRuntimeTuning = preload("res://src/data/tuning/tower_prototype_enemy_runtime_default.tres")
const TOWER_ROOM_DISCOVERY_TRIGGER_SCRIPT: Script = preload("res://src/world/tower/tower_room_discovery_trigger.gd")
const TOWER_FLOOR_DISCOVERY_SERVICE_SCRIPT: Script = preload("res://src/world/tower/tower_floor_discovery_service.gd")
const QUEST_LOG_MENU_SCRIPT: Script = preload("res://src/ui/quest_log_menu.gd")
const SKILLS_MENU_SCRIPT: Script = preload("res://src/ui/skills_menu.gd")
const INVENTORY_MENU_SCRIPT: Script = preload("res://src/ui/inventory_menu.gd")
const STORAGE_HOUSE_MENU_SCRIPT: Script = preload("res://src/ui/storage_house_menu.gd")
const MERCHANT_MENU_SCRIPT: Script = preload("res://src/ui/merchant_menu.gd")
const BLACKSMITH_MENU_SCRIPT: Script = preload("res://src/ui/blacksmith_menu.gd")
const PENDING_REWARD_CLAIM_TRANSACTION_SERVICE_SCRIPT: Script = preload("res://src/items/pending_reward_claim_transaction_service.gd")
const INVENTORY_DROP_TRANSACTION_SERVICE_SCRIPT: Script = preload("res://src/items/inventory_drop_transaction_service.gd")
const REGION3_INVENTORY_DROP_TRANSACTION_SERVICE_SCRIPT: Script = preload("res://src/world/region3/items/region3_inventory_drop_transaction_service.gd")
const PROFILE_STORAGE_TRANSACTION_SERVICE_SCRIPT: Script = preload("res://src/items/profile_storage_transaction_service.gd")
const PLAYER_DROP_STATE_VALIDATOR_SCRIPT: Script = preload("res://src/items/player_drop_state_validator.gd")
const TOWER_PLAYER_DROP_PICKUP_SCENE: PackedScene = preload("res://src/world/tower/items/tower_player_drop_pickup.tscn")
const REGION3_PLAYER_DROP_PICKUP_SCENE: PackedScene = preload("res://src/world/region3/items/region3_player_drop_pickup.tscn")
const TENTH_WARDEN_SANCTUM_SCENE: PackedScene = preload("res://src/world/tower/boss/tenth_warden_sanctum.tscn")
const REGION3_TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const REGION3_SIDE_RUNTIME_SCENE: PackedScene = preload("res://src/world/region3/quests/region3_side_quest_runtime.tscn")
const REGION3_SIDE_QUEST_IDS: Array[StringName] = [
    Region3SideQuestAttemptService.QUEST_ESCORT,
    Region3SideQuestAttemptService.QUEST_ANNIHILATION,
    Region3SideQuestAttemptService.QUEST_DEFENSE,
]
const REGION3_MAP_ID: StringName = &"region:3"
const REGION3_TOWN_CHECKPOINT_ID: StringName = &"checkpoint:region3_town"
const REGION3_START_SAFE_ID: StringName = &"safe:region3_start"
const REGION3_FLOOR1_PREPARATION_ATTEMPT_ID: StringName = &"attempt:primary_floor_1:region3_preparation"
const REGION3_TRAINING_HALL_STRUCTURE_ID: StringName = &"r3:functional:07"
const REGION3_GENERAL_MERCHANT_VENDOR_ID: StringName = &"vendor:general_merchant"
const DEATH_RETRY_MODAL_ID: StringName = &"death_retry"
const REASON_PRIMARY_ACTIVATION_POLICY_UNAVAILABLE: StringName = &"primary_quest_activation_policy_unavailable"
const REASON_FLOOR10_BOSS_RUNTIME_NOT_READY: StringName = &"floor10_boss_runtime_not_ready"
const REASON_FLOOR10_BOSS_OBJECTIVE_NOT_ACTIVE: StringName = &"floor10_boss_objective_not_active"
const REASON_FLOOR10_BOSS_CONTACT_OWNER_NOT_READY: StringName = &"floor10_boss_contact_owner_not_ready"
const REASON_FLOOR10_BOSS_ENCOUNTER_CONFLICT: StringName = &"floor10_boss_encounter_conflict"
const REASON_FLOOR10_BOSS_RUNTIME_PREPARE_FAILED: StringName = &"floor10_boss_runtime_prepare_failed"
const REASON_FLOOR10_BOSS_PLAYER_BIND_FAILED: StringName = &"floor10_boss_player_bind_failed"
const REASON_FLOOR10_BOSS_CONTACT_BIND_FAILED: StringName = &"floor10_boss_contact_bind_failed"
const REASON_FLOOR10_BOSS_PROGRESSION_BIND_FAILED: StringName = &"floor10_boss_progression_bind_failed"
const RECOVERY_TARGET_HEALTH: StringName = &"runtime:player_health"
const RECOVERY_TARGET_STAMINA: StringName = &"runtime:player_stamina"
const RECOVERY_TARGET_MANA: StringName = &"runtime:class_mana"
const SUPPORTED_RECOVERY_TARGETS: Array[StringName] = [RECOVERY_TARGET_HEALTH, RECOVERY_TARGET_STAMINA, RECOVERY_TARGET_MANA]

signal tower_travel_finished(result: Dictionary)
signal player_defeat_detected(result: Dictionary)
signal region3_storage_service_requested(structure_id: StringName, role_id: StringName)
signal region3_service_requested(structure_id: StringName, role_id: StringName)

var _profile: ProfileSnapshot = null
var _save_service: SaveService = null
var _slot_index: int = 0
var _save_coordinator: SaveRequestCoordinator = null
var _pending_autosave_context: Dictionary = {}
var tower_restore_status: Dictionary = {}
var last_tower_travel_result: Dictionary = {}
var shared_active_combat: ActiveCombatRegistry = ActiveCombatRegistry.new()
var shared_full_ai: FullAiSimulationLedger = FullAiSimulationLedger.new()
var _active_combat_guard_token: int = 0
var _unsupported_manual_save_guard_token: int = 0
var _unsupported_manual_save_guard_reason_text: String = ""
var _player_combat_bindings: Dictionary = {}
var _death_guard_token: int = 0
var last_player_defeat_event: Dictionary = {}
var last_tower_encounter_trigger_result: Dictionary = {}
var last_tower_room_discovery_result: Dictionary = {}
var last_tower_player_drop_result: Dictionary = {}
var last_region3_player_drop_result: Dictionary = {}
var last_region3_start_result: Dictionary = {}
var last_region3_subzone_discovery_result: Dictionary = {}
var last_region3_storage_service_request: Dictionary = {}
var last_region3_service_request: Dictionary = {}
var last_region3_storage_transfer_result: Dictionary = {}
var last_region3_recovery_result: Dictionary = {}
var last_region3_quest_hall_preparation_result: Dictionary = {}
var last_region3_training_skill_result: Dictionary = {}
var last_region3_primary_turn_in_result: Dictionary = {}
var last_region3_primary_accept_result: Dictionary = {}
var last_tower_primary_exit_result: Dictionary = {}
var last_tower_escort_activation_result: Dictionary = {}
var last_region3_hub_autosave_result: Dictionary = {}
var last_manual_save_result: Dictionary = {}
var last_floor10_preboss_checkpoint_result: Dictionary = {}
var last_floor10_boss_progression_result: Dictionary = {}
var _floor10_boss_sanctum: TenthWardenSanctum = null
var _floor10_boss_progression_bridge: Floor10BossProgressionBridge = null
var _floor10_boss_defender_facts_provider: Callable = Callable()
var _floor10_default_defender_facts_provider: PlayerDefenderFactsProvider = null
var _floor10_boss_music_override_active: bool = false
var _tower_player_drop_pickups: Dictionary = {}
var _region3_player_drop_pickups: Dictionary = {}
var _region3_return_position: Vector2 = Vector2.INF
var _region3_suspended_for_tower: bool = false
var _region3_last_discovery_zone_id: StringName = &""
var _training_hall_skill_session_active: bool = false
var _training_hall_skill_transaction_sequence: int = 0
var _profile_mutation_transaction_sequence: int = 0
var _music_state_controller: AudioMusicStateController = AudioMusicStateController.new()
var _music_routing_ready: bool = false
var _music_override_state: StringName = &""
var last_music_routing_errors: PackedStringArray = PackedStringArray()

@export var world_canvas_size: Vector2i = Vector2i(640, 360)
@export_range(1, 256, 1) var grid_cell_size: int = 32
@export var background_color: Color = Color(0.08, 0.09, 0.12, 1.0)
@export var grid_color: Color = Color(0.14, 0.15, 0.19, 1.0)
@export_range(0.5, 8.0, 0.5) var grid_line_width: float = 1.0
@export var tenth_warden_production_authoring: TenthWardenProductionAuthoring = null
@export var player_defender_facts_tuning: PlayerDefenderFactsTuning = null
@export var music_routing_definition: AudioMusicRoutingDefinition = null
@export var vendor_stock_catalog: VendorStockCatalog = null
@export var blacksmith_recipe_catalog: UpgradeRecipeCatalog = null
@export var item_category_catalog: ItemCategoryCatalog = null
@export var region3_inn_recovery_definition: Dictionary = {}
@export var region3_clinic_recovery_definition: Dictionary = {}
@export var region3_recovery_resource_mapping: Dictionary = {}
@export var level_progression_policy: LevelProgressionPolicy = null
@export var region3_playtest_content: Region3PlaytestContent = null
@export var progression_playtest_content: ProgressionPlaytestContent = null
@export var side_quests_playtest_content: Region3SideQuestsPlaytestContent = null
@export var active_skills_playtest_content: ActiveSkillsPlaytestContent = null
@export var status_effects_playtest_tuning: StatusEffectsPlaytestTuning = null
@export var enemy_playtest_attacks: EnemyPlaytestAttackCatalog = null
@export var status_playtest_tuning: StatusPlaytestTuning = null
@export var side_quests_playtest: Region3SideQuestsPlaytest = null
@export var active_skills_playtest: ActiveSkillsPlaytest = null
@export var passive_skills_playtest: PassiveSkillsPlaytestContent = null
@export var consumable_playtest_tuning: ConsumablePlaytestTuning = null

# Transient mirror of profile-owned automatic stats. Initialized from a valid
# saved profile, or the Inspector-authored class baseline for legacy new slots.
var _progression_runtime_stats: Dictionary = {}
var last_quest_xp_result: Dictionary = {}
var last_region3_side_quest_result: Dictionary = {}
var _pending_region3_side_leave_quest_id: StringName = &""
var last_active_skill_request: Dictionary = {}
var _passive_skill_runtime: PassiveSkillRuntime = PassiveSkillRuntime.new()
var last_consumable_request: Dictionary = {}

@onready var player: PlayerController = $Player
@onready var combat_hud: Node = $CombatHUD
@onready var input_ownership: InputOwnership = $InputOwnership
@onready var combat_runtime: ClassCombatRuntime = $ClassCombatRuntime
@onready var player_playtest_attack_delivery: PlayerPlaytestAttackDelivery = $PlayerPlaytestAttackDelivery
@onready var enemy_playtest_live_delivery: EnemyPlaytestLiveDelivery = $EnemyPlaytestLiveDelivery
@onready var enemy_non_damage_playtest_delivery: EnemyNonDamagePlaytestDelivery = $EnemyNonDamagePlaytestDelivery
@export_range(1, 120, 1) var playtest_riposte_window_ticks: int = 30
var _successful_parry_ticks: int = 0
@onready var operation_guard: GameplayOperationGuard = $GameplayOperationGuard
@onready var pause_coordinator: PauseCoordinator = $PauseCoordinator
@onready var tower_access_menu: TowerAccessMenu = $TowerAccessMenu
@onready var map_menu: MapMenu = $MapMenu
@onready var quest_log_menu: Node = $QuestLogMenu
@onready var skills_menu: Node = $SkillsMenu
@onready var inventory_menu: Node = $InventoryMenu
@onready var storage_house_menu: StorageHouseMenu = $StorageHouseMenu
@onready var merchant_menu: MerchantMenu = $MerchantMenu
@onready var blacksmith_menu: BlacksmithMenu = $BlacksmithMenu
@onready var region3_town_session_host: Region3TownSessionHost = $Region3TownSessionHost
@onready var tower_floor_session_host: TowerFloorSessionHost = $TowerFloorSessionHost
@onready var tower_encounter_session_host: TowerEncounterSessionHost = $TowerEncounterSessionHost
@onready var death_retry_overlay: DeathRetryOverlay = $DeathRetryOverlay
@onready var manual_save_button: Button = $PauseLayer/PausePanel/Menu/Layout/SaveButton
@onready var manual_save_status_label: Label = $PauseLayer/PausePanel/Menu/Layout/SaveStatus

var _foundation_collision_defaults: Array[Dictionary] = []

func set_profile(profile: ProfileSnapshot) -> void:
    _profile = profile
    if is_node_ready():
        _initialize_progression_runtime_stats()
        if _profile != null:
            combat_runtime.bind_equipment_state(_profile.equipment_state)
        _rebind_passive_skill_runtime()
        if player_playtest_attack_delivery != null:
            player_playtest_attack_delivery.configure_skill_ranks(_profile, active_skills_playtest)
    if is_node_ready() and combat_hud != null:
        combat_hud.call("set_profile", _profile)
    if is_node_ready() and quest_log_menu != null:
        quest_log_menu.call("set_profile", _profile)
    if is_node_ready() and skills_menu != null:
        skills_menu.call("set_profile", _profile)
    if is_node_ready() and inventory_menu != null:
        inventory_menu.call("set_profile", _profile)
    if is_node_ready() and storage_house_menu != null:
        storage_house_menu.set_profile(_profile)
    if is_node_ready() and merchant_menu != null:
        merchant_menu.set_profile(_profile)
    if is_node_ready() and blacksmith_menu != null:
        blacksmith_menu.set_profile(_profile)

func set_save_context(save_service: SaveService, slot_index: int) -> bool:
    if save_service == null or slot_index < 1 or slot_index > SaveService.SLOT_COUNT:
        return false
    _save_service = save_service
    _slot_index = slot_index
    if is_node_ready():
        _initialize_save_coordinator()
    return true

func ensure_starting_world() -> bool:
    last_region3_start_result = {}
    if _profile == null or not is_node_ready():
        last_region3_start_result = {"accepted": false, "reason_id": &"startup_context_unavailable"}
        return false
    if is_tower_floor_active():
        last_region3_start_result = {"accepted": true, "reason_id": &"", "world_kind": &"tower"}
        return true
    if is_region3_active():
        last_region3_start_result = {"accepted": true, "reason_id": &"", "world_kind": &"region3"}
        return true

    var safe_state := _profile.safe_state
    var restore_region_safe := false
    var arrival_position := Vector2.INF
    if not safe_state.is_empty():
        var safe_errors := SafeCheckpointState.validate_dictionary(safe_state)
        if not safe_errors.is_empty():
            last_region3_start_result = {"accepted": false, "reason_id": &"invalid_safe_state"}
            return false
        var floor_id := int(safe_state.get("floor_id", 0))
        if floor_id > 0:
            if _restore_persisted_tower_session():
                last_region3_start_result = {"accepted": true, "reason_id": &"", "world_kind": &"tower"}
                return true
            last_region3_start_result = {
                "accepted": false,
                "reason_id": StringName(tower_restore_status.get("reason_id", &"tower_restore_failed")),
            }
            return false
        if StringName(String(safe_state.get("map_id", &""))) != REGION3_MAP_ID:
            last_region3_start_result = {"accepted": false, "reason_id": &"unsupported_region_safe_map"}
            return false
        restore_region_safe = true
        var safe_player_state := safe_state.get("player_state", {}) as Dictionary
        if safe_player_state.has("position_x") and safe_player_state.has("position_y"):
            var position_x: Variant = safe_player_state.get("position_x", null)
            var position_y: Variant = safe_player_state.get("position_y", null)
            if not _finite_numeric(position_x) or not _finite_numeric(position_y):
                last_region3_start_result = {"accepted": false, "reason_id": &"invalid_region_safe_position"}
                return false
            arrival_position = Vector2(float(position_x), float(position_y))

    var runtime_root := REGION3_TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    if runtime_root == null:
        last_region3_start_result = {"accepted": false, "reason_id": &"region3_runtime_instantiate_failed"}
        return false
    if not restore_region_safe:
        arrival_position = region3_town_session_host.resolve_start_position(runtime_root)
    elif not is_finite(arrival_position.x) or not is_finite(arrival_position.y):
        arrival_position = region3_town_session_host.resolve_start_position(runtime_root)

    if not activate_region3_runtime(runtime_root, arrival_position):
        if runtime_root.get_parent() == null:
            runtime_root.free()
        last_region3_start_result = {"accepted": false, "reason_id": &"region3_activation_failed"}
        return false

    if restore_region_safe:
        if not _restore_player_safe_state(safe_state.get("player_state", {})):
            _clear_region3_runtime_to_foundation()
            last_region3_start_result = {"accepted": false, "reason_id": &"region3_player_state_restore_failed"}
            return false
        last_region3_start_result = {
            "accepted": true,
            "reason_id": &"",
            "world_kind": &"region3",
            "restored_safe_state": true,
            "durable_start": true,
            "arrival_position": arrival_position,
        }
        return true

    if _save_service == null or _slot_index < 1:
        _clear_region3_runtime_to_foundation()
        last_region3_start_result = {"accepted": false, "reason_id": &"region3_initial_save_context_unavailable"}
        return false
    var initial_safe := SafeCheckpointState.make(
        REGION3_START_SAFE_ID,
        REGION3_MAP_ID,
        0,
        REGION3_TOWN_CHECKPOINT_ID,
        _capture_player_safe_state(),
        _capture_quest_attempt_state(),
        _next_safe_snapshot_sequence()
    )
    if initial_safe.is_empty():
        _clear_region3_runtime_to_foundation()
        last_region3_start_result = {"accepted": false, "reason_id": &"region3_initial_safe_state_invalid"}
        return false
    var save_result := SafeCheckpointCommitService.commit_checkpoint(_save_service, _slot_index, _profile, initial_safe)
    if save_result != OK:
        _clear_region3_runtime_to_foundation()
        last_region3_start_result = {
            "accepted": false,
            "reason_id": &"region3_initial_safe_commit_failed",
            "save_error": save_result,
        }
        return false
    last_region3_start_result = {
        "accepted": true,
        "reason_id": &"",
        "world_kind": &"region3",
        "restored_safe_state": false,
        "durable_start": true,
        "arrival_position": arrival_position,
    }
    return true


func activate_region3_runtime(runtime_root: Region3AuthoredTownLayout, arrival_position: Vector2) -> bool:
    if runtime_root == null or is_tower_floor_active():
        return false
    _set_foundation_world_enabled(false)
    if not region3_town_session_host.activate(runtime_root, player, player.camera, arrival_position):
        _set_foundation_world_enabled(true)
        player.camera.set_world_bounds(Rect2(Vector2.ZERO, Vector2(world_canvas_size)))
        queue_redraw()
        return false
    if not _bind_region3_runtime_services():
        region3_town_session_host.clear_loaded_region()
        _set_foundation_world_enabled(true)
        player.camera.set_world_bounds(Rect2(Vector2.ZERO, Vector2(world_canvas_size)))
        queue_redraw()
        return false
    _region3_last_discovery_zone_id = &""
    if not _update_region3_subzone_discovery(true):
        region3_town_session_host.clear_loaded_region()
        _set_foundation_world_enabled(true)
        player.camera.set_world_bounds(Rect2(Vector2.ZERO, Vector2(world_canvas_size)))
        queue_redraw()
        return false
    if not _sync_region3_player_drop_pickups():
        region3_town_session_host.clear_loaded_region()
        _region3_player_drop_pickups.clear()
        _set_foundation_world_enabled(true)
        player.camera.set_world_bounds(Rect2(Vector2.ZERO, Vector2(world_canvas_size)))
        queue_redraw()
        return false
    var side_configured: Dictionary = _bind_region3_side_runtime()
    last_region3_side_quest_result = side_configured.duplicate(true)
    if not bool(side_configured.get("accepted", false)):
        _clear_region3_runtime_to_foundation()
        return false
    queue_redraw()
    return true


func is_region3_active() -> bool:
    return region3_town_session_host != null and region3_town_session_host.has_active_region()


func _update_region3_subzone_discovery(force: bool = false) -> bool:
    if _profile == null or not is_region3_active():
        return false
    var layout := region3_town_session_host.active_runtime_root
    if layout == null:
        return false
    var local_position := region3_town_session_host.to_local(player.global_position)
    var resolved := Region3SubzoneDiscoveryService.zone_id_at_local_position(layout, local_position)
    if not bool(resolved.get("accepted", false)):
        last_region3_subzone_discovery_result = resolved.duplicate(true)
        return false
    var zone_id := StringName(String(resolved.get("zone_id", &"")))
    if not force and zone_id == _region3_last_discovery_zone_id:
        return true
    if zone_id == &"":
        var initialized := Region3SubzoneDiscoveryService.ensure_initialized(_profile, layout)
        last_region3_subzone_discovery_result = initialized.duplicate(true)
        if bool(initialized.get("accepted", false)):
            _region3_last_discovery_zone_id = &""
        return bool(initialized.get("accepted", false))
    var result := Region3SubzoneDiscoveryService.mark_zone_explored(_profile, layout, zone_id)
    result["tile"] = resolved.get("tile", Vector2i(-1, -1))
    last_region3_subzone_discovery_result = result.duplicate(true)
    if bool(result.get("accepted", false)):
        _region3_last_discovery_zone_id = zone_id
        return true
    return false


func _bind_region3_runtime_services() -> bool:
    var storage_interaction := region3_town_session_host.get_storage_interaction()
    if storage_interaction == null:
        return false
    if not storage_interaction.bind_runtime(input_ownership, operation_guard):
        return false
    if not storage_interaction.service_requested.is_connected(_on_region3_storage_service_requested):
        storage_interaction.service_requested.connect(_on_region3_storage_service_requested)
    var functional_interactions := region3_town_session_host.get_functional_service_interactions()
    if functional_interactions.size() != Region3FunctionalServiceInteraction.SUPPORTED_ROLE_IDS.size():
        return false
    for interaction: Region3FunctionalServiceInteraction in functional_interactions:
        if not interaction.bind_runtime(input_ownership, operation_guard):
            return false
        if not interaction.service_requested.is_connected(_on_region3_service_requested):
            interaction.service_requested.connect(_on_region3_service_requested)
    return true


func _on_region3_storage_service_requested(structure_id: StringName, role_id: StringName) -> void:
    last_region3_storage_service_request = {
        "structure_id": structure_id,
        "role_id": role_id,
        "world_kind": &"region3",
    }
    var discovery_result := _record_region3_service_request(structure_id, role_id)
    last_region3_storage_service_request["discovery_result"] = discovery_result.duplicate(true)
    var service_opened := storage_house_menu != null and storage_house_menu.open_service(structure_id, role_id)
    last_region3_storage_service_request["service_opened"] = service_opened
    region3_storage_service_requested.emit(structure_id, role_id)


func _on_region3_service_requested(structure_id: StringName, role_id: StringName) -> void:
    _record_region3_service_request(structure_id, role_id)
    if role_id == Region3TownStructureManifestValidator.ROLE_BLACKSMITH:
        var blacksmith_status := _open_region3_blacksmith_service()
        last_region3_service_request["service_opened"] = bool(blacksmith_status.get("accepted", false))
        last_region3_service_request["reason_id"] = StringName(String(blacksmith_status.get("reason_id", &"")))
        last_region3_service_request["integration_status"] = blacksmith_status.duplicate(true)
        return
    if role_id == Region3TownStructureManifestValidator.ROLE_GENERAL_MERCHANT:
        var merchant_status := _open_region3_general_merchant_service()
        last_region3_service_request["service_opened"] = bool(merchant_status.get("accepted", false))
        last_region3_service_request["reason_id"] = StringName(String(merchant_status.get("reason_id", &"")))
        last_region3_service_request["integration_status"] = merchant_status.duplicate(true)
        return
    if role_id == Region3TownStructureManifestValidator.ROLE_INN_REST_HOUSE:
        var recovery_status: Dictionary = get_region3_recovery_integration_status(role_id)
        var recovery_result: Dictionary = request_region3_recovery_service(role_id) if bool(recovery_status.get("available", false)) else recovery_status.duplicate(true)
        last_region3_recovery_result = recovery_result.duplicate(true)
        last_region3_service_request["service_opened"] = false
        last_region3_service_request["reason_id"] = StringName(String(recovery_result.get("reason_id", &"")))
        last_region3_service_request["integration_status"] = recovery_status.duplicate(true)
        last_region3_service_request["result"] = recovery_result.duplicate(true)
        return
    if role_id == Region3TownStructureManifestValidator.ROLE_CLINIC_APOTHECARY:
        var clinic_definition := _region3_recovery_definition_for_role(role_id)
        var clinic_mode := Region3RecoveryServiceDefinition.service_mode(clinic_definition)
        if clinic_mode in [Region3RecoveryServiceDefinition.MODE_STOCK_ONLY, Region3RecoveryServiceDefinition.MODE_STOCK_AND_RECOVERY]:
            var stock_vendor_id := StringName(String(clinic_definition.get("stock_reference_id", &"")))
            var clinic_stock_status := _open_region3_vendor_service(stock_vendor_id)
            last_region3_service_request["service_opened"] = bool(clinic_stock_status.get("accepted", false))
            last_region3_service_request["reason_id"] = StringName(String(clinic_stock_status.get("reason_id", &"")))
            last_region3_service_request["integration_status"] = clinic_stock_status.duplicate(true)
            if clinic_mode == Region3RecoveryServiceDefinition.MODE_STOCK_AND_RECOVERY:
                last_region3_service_request["recovery_status"] = get_region3_recovery_integration_status(role_id).duplicate(true)
                last_region3_service_request["recovery_action"] = &"request_region3_recovery_service"
            return
        if clinic_mode == Region3RecoveryServiceDefinition.MODE_RECOVERY_ONLY:
            var recovery_status: Dictionary = get_region3_recovery_integration_status(role_id)
            var recovery_result: Dictionary = request_region3_recovery_service(role_id) if bool(recovery_status.get("available", false)) else recovery_status.duplicate(true)
            last_region3_recovery_result = recovery_result.duplicate(true)
            last_region3_service_request["service_opened"] = false
            last_region3_service_request["reason_id"] = StringName(String(recovery_result.get("reason_id", &"")))
            last_region3_service_request["integration_status"] = recovery_status.duplicate(true)
            last_region3_service_request["result"] = recovery_result.duplicate(true)
            return
        last_region3_service_request["service_opened"] = false
        last_region3_service_request["reason_id"] = &"clinic_combined_service_surface_unavailable" if clinic_mode == Region3RecoveryServiceDefinition.MODE_STOCK_AND_RECOVERY else &"clinic_service_content_unresolved"
        last_region3_service_request["integration_status"] = Region3RecoveryServiceDefinition.production_readiness(clinic_definition)
        return
    if role_id == Region3TownStructureManifestValidator.ROLE_TRAINING_HALL:
        var service_opened := _open_training_hall_skill_session(structure_id)
        last_region3_service_request["service_opened"] = service_opened
        return
    if role_id != Region3TownStructureManifestValidator.ROLE_QUEST_HALL:
        return
    # The first Quest Hall interaction previews a live side-quest departure.
    # Only a separate second interaction confirms its authored terminal rule.
    if _has_active_region3_side_quest():
        var side_runtime := _region3_side_runtime()
        if side_runtime != null and side_runtime.active_quest_id() != &"":
            var side_id := side_runtime.active_quest_id()
            var leave_result := request_region3_side_quest_leave(_pending_region3_side_leave_quest_id == side_id)
            _pending_region3_side_leave_quest_id = side_id if not bool(leave_result.get("durable", false)) and bool(leave_result.get("accepted", false)) else &""
            last_region3_service_request["result"] = leave_result.duplicate(true)
            return
    var side_turn_in := _commit_next_region3_side_turn_in()
    if bool(side_turn_in.get("attempted", false)):
        last_region3_side_quest_result = side_turn_in.duplicate(true)
        last_region3_service_request["result"] = side_turn_in.duplicate(true)
        return
    var turn_in_result := _commit_region3_primary_turn_in_if_ready()
    if bool(turn_in_result.get("attempted", false)):
        last_region3_primary_turn_in_result = turn_in_result.duplicate(true)
        last_region3_service_request["result"] = turn_in_result.duplicate(true)
        return
    var retry_xp := _claim_next_completed_quest_xp()
    if bool(retry_xp.get("attempted", false)):
        last_region3_service_request["result"] = retry_xp.duplicate(true)
        return
    var accept_result := _accept_next_primary_quest_if_ready()
    if bool(accept_result.get("attempted", false)):
        last_region3_primary_accept_result = accept_result.duplicate(true)
        last_region3_service_request["result"] = accept_result.duplicate(true)
        return
    if not Region3PreparationCommitService.has_tower_sigil(_profile) or not Region3PreparationCommitService.is_floor_1_unlocked(_profile):
        last_region3_quest_hall_preparation_result = _commit_region3_quest_hall_preparation()
        last_region3_service_request["result"] = last_region3_quest_hall_preparation_result.duplicate(true)
        return
    var side_accept := _accept_next_region3_side_quest_if_ready()
    if bool(side_accept.get("attempted", false)):
        last_region3_side_quest_result = side_accept.duplicate(true)
        last_region3_service_request["result"] = side_accept.duplicate(true)
        return
    last_region3_quest_hall_preparation_result = _commit_region3_quest_hall_preparation()
    last_region3_service_request["result"] = last_region3_quest_hall_preparation_result.duplicate(true)


func _record_region3_service_request(structure_id: StringName, role_id: StringName) -> Dictionary:
    var discovery_result := Region3ServiceDiscoveryService.mark_discovered(_profile, structure_id, role_id)
    last_region3_service_request = {
        "structure_id": structure_id,
        "role_id": role_id,
        "world_kind": &"region3",
        "discovery_result": discovery_result.duplicate(true),
    }
    region3_service_requested.emit(structure_id, role_id)
    return discovery_result


func _open_region3_general_merchant_service() -> Dictionary:
    return _open_region3_vendor_service(REGION3_GENERAL_MERCHANT_VENDOR_ID)


func _open_region3_vendor_service(vendor_id: StringName) -> Dictionary:
    var readiness := _ensure_region3_vendor_state(vendor_id)
    if not bool(readiness.get("accepted", false)):
        return readiness
    if merchant_menu == null or not merchant_menu.open_service(vendor_id):
        return {
            "accepted": false,
            "reason_id": &"merchant_menu_unavailable",
            "vendor_id": vendor_id,
            "initialized": bool(readiness.get("initialized", false)),
        }
    return {
        "accepted": true,
        "reason_id": &"",
        "vendor_id": vendor_id,
        "initialized": bool(readiness.get("initialized", false)),
    }


func _ensure_region3_general_merchant_state() -> Dictionary:
    return _ensure_region3_vendor_state(REGION3_GENERAL_MERCHANT_VENDOR_ID)


func _ensure_region3_vendor_state(vendor_id: StringName) -> Dictionary:
    if _profile == null or not StableId.is_valid(String(vendor_id)):
        return {"accepted": false, "reason_id": &"merchant_profile_unavailable", "initialized": false}

    var economy := EconomyState.new()
    if not _profile.economy_state.is_empty():
        var economy_errors := economy.load_dictionary(_profile.economy_state)
        if not economy_errors.is_empty():
            return {
                "accepted": false,
                "reason_id": &"merchant_economy_state_invalid",
                "vendor_id": vendor_id,
                "initialized": false,
                "errors": economy_errors.duplicate(),
            }
    if economy.get_vendor(vendor_id) != null:
        return {"accepted": true, "reason_id": &"", "vendor_id": vendor_id, "initialized": false}

    if vendor_stock_catalog == null:
        return {
            "accepted": false,
            "reason_id": VendorStockCatalog.REASON_CONTENT_UNAVAILABLE,
            "vendor_id": vendor_id,
            "initialized": false,
            "missing_fields": PackedStringArray([
                "stock_manifest",
                "buy_prices",
                "sell_prices",
                "quantities",
                "restock_rule_id",
                "restock_policy",
                "availability_conditions",
                "item_category_catalog",
            ]),
        }
    var catalog_status := vendor_stock_catalog.vendor_readiness(vendor_id, item_category_catalog, true)
    if not bool(catalog_status.get("available", false)):
        var unavailable := catalog_status.duplicate(true)
        unavailable["accepted"] = false
        unavailable["initialized"] = false
        return unavailable

    var definition := vendor_stock_catalog.get_definition(vendor_id)
    if definition == null or not economy.initialize_vendor_once(definition):
        return {"accepted": false, "reason_id": &"merchant_initialization_failed", "vendor_id": vendor_id, "initialized": false}
    var candidate := _profile.to_dictionary()
    candidate["economy_state"] = economy.to_dictionary()
    var profile_errors := ProfileSnapshot.validate_dictionary(candidate)
    if not profile_errors.is_empty():
        return {
            "accepted": false,
            "reason_id": &"merchant_initialization_profile_invalid",
            "vendor_id": vendor_id,
            "initialized": false,
            "errors": profile_errors.duplicate(),
        }
    _profile.economy_state = economy.to_dictionary()
    return {
        "accepted": true,
        "reason_id": &"",
        "vendor_id": vendor_id,
        "initialized": true,
        "durable": false,
        "durability_boundary": &"next_safe_snapshot",
    }


func get_region3_services_economy_audio_content_status() -> Dictionary:
    var merchant_status: Dictionary
    if vendor_stock_catalog == null:
        merchant_status = {
            "available": false,
            "reason_id": VendorStockCatalog.REASON_CONTENT_UNAVAILABLE,
            "vendor_id": REGION3_GENERAL_MERCHANT_VENDOR_ID,
            "missing_fields": PackedStringArray([
                "stock_manifest",
                "buy_prices",
                "sell_prices",
                "quantities",
                "restock_rule_id",
                "restock_policy",
                "availability_conditions",
                "item_category_catalog",
            ]),
        }
    else:
        merchant_status = vendor_stock_catalog.general_merchant_readiness(item_category_catalog, true)

    var blacksmith_status := get_region3_blacksmith_integration_status()
    var inn_status := Region3RecoveryServiceDefinition.production_readiness(region3_inn_recovery_definition)
    var clinic_status := Region3RecoveryServiceDefinition.production_readiness(region3_clinic_recovery_definition)

    if bool(inn_status.get("available", false)):
        var inn_recovery := region3_inn_recovery_definition.get("recovery_amounts", {}) as Dictionary
        var inn_mapping := _validate_region3_recovery_resource_mapping(inn_recovery)
        inn_status["resource_mapping_ready"] = bool(inn_mapping.get("accepted", false))
        inn_status["resource_mapping_errors"] = (inn_mapping.get("errors", PackedStringArray()) as PackedStringArray).duplicate()
        if not bool(inn_mapping.get("accepted", false)):
            inn_status["available"] = false
            inn_status["reason_id"] = &"recovery_resource_mapping_invalid"

    if bool(clinic_status.get("available", false)):
        var clinic_recovery := region3_clinic_recovery_definition.get("recovery_amounts", {}) as Dictionary
        var clinic_mapping := _validate_region3_recovery_resource_mapping(clinic_recovery)
        var clinic_vendor_id := StringName(String(region3_clinic_recovery_definition.get("stock_reference_id", &"")))
        var clinic_vendor_status := (
            vendor_stock_catalog.vendor_readiness(clinic_vendor_id, item_category_catalog, true)
            if vendor_stock_catalog != null
            else {
                "available": false,
                "reason_id": VendorStockCatalog.REASON_CONTENT_UNAVAILABLE,
                "vendor_id": clinic_vendor_id,
                "missing_fields": PackedStringArray(["stock_manifest", "item_category_catalog"]),
            }
        )
        clinic_status["resource_mapping_ready"] = bool(clinic_mapping.get("accepted", false))
        clinic_status["resource_mapping_errors"] = (clinic_mapping.get("errors", PackedStringArray()) as PackedStringArray).duplicate()
        clinic_status["stock_ready"] = bool(clinic_vendor_status.get("available", false))
        clinic_status["stock_status"] = clinic_vendor_status.duplicate(true)
        clinic_status["combined_service_surface_ready"] = false
        if not bool(clinic_mapping.get("accepted", false)):
            clinic_status["available"] = false
            clinic_status["reason_id"] = &"recovery_resource_mapping_invalid"
        elif not bool(clinic_vendor_status.get("available", false)):
            clinic_status["available"] = false
            clinic_status["reason_id"] = VendorStockCatalog.REASON_CONTENT_UNAVAILABLE
        else:
            clinic_status["available"] = true
            clinic_status["combined_service_surface_ready"] = true
            clinic_status["reason_id"] = &""

    var audio_status: Dictionary
    if music_routing_definition == null:
        audio_status = {
            "available": false,
            "reason_id": &"content_unavailable",
            "missing_fields": PackedStringArray([
                "exploration_event",
                "exploration_stream",
                "combat_event",
                "combat_stream",
                "boss_event",
                "boss_stream",
                "recovery_event",
                "recovery_stream",
                "fade_seconds",
                "debounce_seconds",
            ]),
            "validation_errors": PackedStringArray(["production music routing is not assigned"]),
        }
    else:
        audio_status = music_routing_definition.production_readiness()

    var complete := (
        bool(merchant_status.get("available", false))
        and bool(blacksmith_status.get("available", false))
        and bool(inn_status.get("available", false))
        and bool(clinic_status.get("available", false))
        and bool(audio_status.get("available", false))
    )
    return {
        "complete": complete,
        "merchant": merchant_status.duplicate(true),
        "blacksmith": blacksmith_status.duplicate(true),
        "inn": inn_status.duplicate(true),
        "clinic": clinic_status.duplicate(true),
        "audio": audio_status.duplicate(true),
    }


func get_region3_blacksmith_integration_status() -> Dictionary:
    if blacksmith_recipe_catalog == null:
        return {
            "available": false,
            "reason_id": UpgradeRecipeCatalog.REASON_CONTENT_UNAVAILABLE,
            "authored_recipe_count": 0,
            "missing_fields": PackedStringArray([
                "recipe_id",
                "compatible_definition_ids",
                "compatible_rarities",
                "source_rank",
                "result_rank",
                "maximum_rank",
                "gold_cost",
                "material_costs",
                "stat_changes",
                "prerequisites",
                "item_category_catalog",
            ]),
            "validation_errors": PackedStringArray(["production Blacksmith recipe catalog is not assigned"]),
        }
    return blacksmith_recipe_catalog.readiness(item_category_catalog, true)


func _open_region3_blacksmith_service() -> Dictionary:
    if _profile == null or blacksmith_menu == null or not is_region3_active():
        return {"accepted": false, "reason_id": &"blacksmith_context_unavailable"}
    var readiness := get_region3_blacksmith_integration_status()
    if not bool(readiness.get("available", false)):
        var unavailable := readiness.duplicate(true)
        unavailable["accepted"] = false
        return unavailable
    var recipes := blacksmith_recipe_catalog.validated_recipes()
    if recipes.is_empty():
        return {"accepted": false, "reason_id": UpgradeRecipeCatalog.REASON_CONTENT_UNAVAILABLE}
    if not blacksmith_menu.configure(
        _profile,
        input_ownership,
        recipes,
        Callable(self, &"request_region3_blacksmith_upgrade")
    ):
        return {"accepted": false, "reason_id": &"blacksmith_menu_configuration_failed"}
    if not blacksmith_menu.open_service():
        return {"accepted": false, "reason_id": &"blacksmith_menu_unavailable"}
    return {
        "accepted": true,
        "reason_id": &"",
        "authored_recipe_count": recipes.size(),
    }


func _upgrade_recipe_matches(left: UpgradeRecipeDefinition, right: UpgradeRecipeDefinition) -> bool:
    if left == null or right == null:
        return false
    return (
        left.recipe_id == right.recipe_id
        and left.compatible_definition_ids == right.compatible_definition_ids
        and left.compatible_rarities == right.compatible_rarities
        and left.source_rank == right.source_rank
        and left.result_rank == right.result_rank
        and left.maximum_rank == right.maximum_rank
        and left.gold_cost == right.gold_cost
        and left.material_costs == right.material_costs
        and left.stat_changes == right.stat_changes
        and left.validate_authored_definition().is_empty()
        and right.validate_authored_definition().is_empty()
    )


func get_region3_recovery_integration_status(role_id: StringName) -> Dictionary:
    var definition := _region3_recovery_definition_for_role(role_id)
    if definition.is_empty():
        return {
            "available": false,
            "accepted": false,
            "reason_id": &"recovery_definition_unavailable",
            "role_id": role_id,
            "definition_errors": PackedStringArray(["production recovery definition is not assigned"]),
            "mapping_errors": PackedStringArray(),
        }

    var definition_errors := Region3RecoveryServiceDefinition.validate_dictionary(definition)
    if not definition_errors.is_empty():
        return {
            "available": false,
            "accepted": false,
            "reason_id": Region3RecoveryTransactionService.REASON_DEFINITION_INVALID,
            "role_id": role_id,
            "definition_errors": definition_errors.duplicate(),
            "mapping_errors": PackedStringArray(),
        }
    if not bool(definition.get("available", false)):
        return {
            "available": false,
            "accepted": false,
            "reason_id": Region3RecoveryTransactionService.REASON_SERVICE_UNAVAILABLE,
            "role_id": role_id,
            "definition_errors": PackedStringArray(),
            "mapping_errors": PackedStringArray(),
        }

    var recovery_variant: Variant = definition.get("recovery_amounts", null)
    if not recovery_variant is Dictionary or (recovery_variant as Dictionary).is_empty():
        return {
            "available": false,
            "accepted": false,
            "reason_id": Region3RecoveryTransactionService.REASON_RECOVERY_PAYLOAD_UNAVAILABLE,
            "role_id": role_id,
            "definition_errors": PackedStringArray(),
            "mapping_errors": PackedStringArray(["direct recovery requires explicit recovery_amounts; stock-only Clinic content is not a recovery transaction"]),
        }

    var mapping_status := _validate_region3_recovery_resource_mapping(recovery_variant as Dictionary)
    if not bool(mapping_status.get("accepted", false)):
        return {
            "available": false,
            "accepted": false,
            "reason_id": StringName(String(mapping_status.get("reason_id", &"recovery_resource_mapping_invalid"))),
            "role_id": role_id,
            "definition_errors": PackedStringArray(),
            "mapping_errors": (mapping_status.get("errors", PackedStringArray()) as PackedStringArray).duplicate(),
        }

    if _save_service == null or _slot_index < 1:
        return {
            "available": false,
            "accepted": false,
            "reason_id": &"recovery_save_context_unavailable",
            "role_id": role_id,
            "definition_errors": PackedStringArray(),
            "mapping_errors": PackedStringArray(),
        }

    return {
        "available": true,
        "accepted": true,
        "reason_id": &"",
        "role_id": role_id,
        "service_id": StringName(String(definition.get("service_id", &""))),
        "definition_errors": PackedStringArray(),
        "mapping_errors": PackedStringArray(),
        "resource_mapping": (mapping_status.get("mapping", {}) as Dictionary).duplicate(true),
    }


func request_region3_recovery_service(role_id: StringName) -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if _profile == null or not is_region3_active() or operation_guard == null:
        return {"accepted": false, "reason_id": &"recovery_context_unavailable", "durable": false}
    if not operation_guard.is_allowed(GameplayOperationGuard.OP_SERVICE):
        var blocking := operation_guard.get_blocking_reasons(GameplayOperationGuard.OP_SERVICE)
        var reason_id := &"recovery_operation_blocked"
        if not blocking.is_empty():
            reason_id = StringName(String((blocking[0] as Dictionary).get("reason_id", reason_id)))
        return {"accepted": false, "reason_id": reason_id, "durable": false}

    var status := get_region3_recovery_integration_status(role_id)
    if not bool(status.get("available", false)):
        var unavailable := status.duplicate(true)
        unavailable["durable"] = false
        return unavailable

    var definition := _region3_recovery_definition_for_role(role_id)
    var service_id := StringName(String(definition.get("service_id", &"")))
    var transaction_id := _next_profile_mutation_transaction_id(&"region3_recovery", service_id)
    if transaction_id == &"":
        return {"accepted": false, "reason_id": &"recovery_transaction_id_unavailable", "durable": false}

    var result := Region3RecoveryTransactionService.commit(
        _profile,
        definition,
        transaction_id,
        shared_active_combat.is_active(),
        Callable(self, &"_commit_region3_recovery_atomic")
    )
    if bool(result.get("accepted", false)):
        if inventory_menu != null:
            inventory_menu.call("set_profile", _profile)
        if merchant_menu != null:
            merchant_menu.set_profile(_profile)
        result["integration_status"] = status.duplicate(true)
    last_region3_recovery_result = result.duplicate(true)
    return result


func _region3_recovery_definition_for_role(role_id: StringName) -> Dictionary:
    if role_id == Region3RecoveryServiceDefinition.ROLE_INN_REST_HOUSE:
        return region3_inn_recovery_definition.duplicate(true)
    if role_id == Region3RecoveryServiceDefinition.ROLE_CLINIC_APOTHECARY:
        return region3_clinic_recovery_definition.duplicate(true)
    return {}


func _validate_region3_recovery_resource_mapping(recovery_amounts: Dictionary) -> Dictionary:
    var errors := PackedStringArray()
    var normalized: Dictionary = {}
    var claimed_targets: Dictionary = {}

    if region3_recovery_resource_mapping.is_empty():
        errors.append("production recovery resource mapping is not assigned")
    for raw_source_id: Variant in region3_recovery_resource_mapping.keys():
        var source_id := StringName(String(raw_source_id))
        var target_id := StringName(String(region3_recovery_resource_mapping[raw_source_id]))
        if not StableId.is_valid(String(source_id)):
            errors.append("recovery resource mapping contains an invalid authored resource ID")
            continue
        if target_id not in SUPPORTED_RECOVERY_TARGETS:
            errors.append("unsupported runtime recovery target for %s: %s" % [String(source_id), String(target_id)])
            continue
        if normalized.has(source_id):
            errors.append("duplicate recovery resource mapping for %s" % String(source_id))
            continue
        if claimed_targets.has(target_id):
            errors.append("multiple authored recovery resources cannot map to the same runtime target: %s" % String(target_id))
            continue
        normalized[source_id] = target_id
        claimed_targets[target_id] = source_id

    for raw_resource_id: Variant in recovery_amounts.keys():
        var resource_id := StringName(String(raw_resource_id))
        if not normalized.has(resource_id):
            errors.append("missing runtime recovery mapping for %s" % String(resource_id))
            continue
        var target_id: StringName = normalized[resource_id]
        var amount_variant: Variant = recovery_amounts[raw_resource_id]
        var amount := float(amount_variant)
        if target_id == RECOVERY_TARGET_HEALTH and not is_equal_approx(amount, round(amount)):
            errors.append("health recovery amount must be integral for %s" % String(resource_id))
        if target_id == RECOVERY_TARGET_MANA and (combat_runtime == null or not combat_runtime.has_mana()):
            errors.append("mapped mana recovery target is unavailable for the active class")

    return {
        "accepted": errors.is_empty(),
        "reason_id": &"" if errors.is_empty() else &"recovery_resource_mapping_invalid",
        "errors": errors,
        "mapping": normalized.duplicate(true),
    }


func _commit_region3_recovery_atomic(prepared: Dictionary) -> Dictionary:
    var transaction_id := StringName(String(prepared.get(Region3RecoveryTransactionService.COMMIT_RECEIPT_TRANSACTION_ID_KEY, prepared.get("transaction_id", &""))))
    var rejected := func(reason_id: StringName) -> Dictionary:
        return {
            Region3RecoveryTransactionService.COMMIT_RECEIPT_ACCEPTED_KEY: false,
            "reason_id": reason_id,
            Region3RecoveryTransactionService.COMMIT_RECEIPT_TRANSACTION_ID_KEY: transaction_id,
        }

    if _profile == null or _save_service == null or _slot_index < 1 or not is_region3_active():
        return rejected.call(&"recovery_atomic_context_unavailable")

    var recovery_amounts := prepared.get(Region3RecoveryTransactionService.COMMIT_INPUT_RECOVERY_AMOUNTS_KEY, {}) as Dictionary
    var mapping_status := _validate_region3_recovery_resource_mapping(recovery_amounts)
    if not bool(mapping_status.get("accepted", false)):
        return rejected.call(StringName(String(mapping_status.get("reason_id", &"recovery_resource_mapping_invalid"))))
    var resource_mapping := mapping_status.get("mapping", {}) as Dictionary

    var before_player_state := _capture_player_safe_state()
    var recovered := _build_recovered_player_state(before_player_state, recovery_amounts, resource_mapping)
    if not bool(recovered.get("accepted", false)):
        return rejected.call(StringName(String(recovered.get("reason_id", &"recovery_runtime_state_invalid"))))
    var after_player_state := recovered.get("player_state", {}) as Dictionary
    if not _restore_player_safe_state(after_player_state):
        _restore_player_safe_state(before_player_state)
        return rejected.call(&"recovery_runtime_apply_failed")

    var staged_payload := prepared.get(Region3RecoveryTransactionService.COMMIT_INPUT_STAGED_PROFILE_KEY, {}) as Dictionary
    var staged_profile := ProfileSnapshot.from_dictionary(staged_payload)
    if staged_profile == null:
        _restore_player_safe_state(before_player_state)
        return rejected.call(&"recovery_staged_profile_invalid")

    var snapshot_sequence := _next_safe_snapshot_sequence()
    var safe_state := SafeCheckpointState.make(
        StringName("safe:region3_recovery:%d" % snapshot_sequence),
        REGION3_MAP_ID,
        0,
        REGION3_TOWN_CHECKPOINT_ID,
        after_player_state,
        _capture_quest_attempt_state(),
        snapshot_sequence
    )
    if safe_state.is_empty():
        _restore_player_safe_state(before_player_state)
        return rejected.call(&"recovery_safe_state_invalid")

    var save_error := SafeCheckpointCommitService.commit_checkpoint(_save_service, _slot_index, staged_profile, safe_state)
    if save_error != OK:
        _restore_player_safe_state(before_player_state)
        var save_rejected: Dictionary = rejected.call(&"recovery_save_failed") as Dictionary
        save_rejected["save_error"] = save_error
        return save_rejected

    _profile.safe_state = safe_state.duplicate(true)
    return {
        Region3RecoveryTransactionService.COMMIT_RECEIPT_ACCEPTED_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_DURABLE_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_PROFILE_COMMITTED_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_RECOVERY_COMMITTED_KEY: true,
        Region3RecoveryTransactionService.COMMIT_RECEIPT_TRANSACTION_ID_KEY: transaction_id,
        "safe_state": safe_state.duplicate(true),
    }


func _build_recovered_player_state(
    source_state: Dictionary,
    recovery_amounts: Dictionary,
    resource_mapping: Dictionary
) -> Dictionary:
    var state := source_state.duplicate(true)
    for raw_resource_id: Variant in recovery_amounts.keys():
        var resource_id := StringName(String(raw_resource_id))
        if not resource_mapping.has(resource_id):
            return {"accepted": false, "reason_id": &"recovery_resource_mapping_invalid", "player_state": {}}
        var target_id := StringName(String(resource_mapping[resource_id]))
        var amount := float(recovery_amounts[raw_resource_id])
        match target_id:
            RECOVERY_TARGET_HEALTH:
                if not is_equal_approx(amount, round(amount)):
                    return {"accepted": false, "reason_id": &"recovery_health_amount_invalid", "player_state": {}}
                var health_state := state.get("health_state", {}) as Dictionary
                var current_hp := int(health_state.get("current", state.get("hp", 0)))
                var max_hp := player.health.get_max_hp()
                var recovered_hp := mini(max_hp, current_hp + int(round(amount)))
                health_state["current"] = recovered_hp
                health_state["maximum_at_capture"] = max_hp
                state["health_state"] = health_state
                state["hp"] = recovered_hp
                state["hp_max"] = max_hp
            RECOVERY_TARGET_STAMINA:
                var stamina_state := state.get("stamina_state", {}) as Dictionary
                var current_stamina := float(stamina_state.get("current", state.get("stamina", 0.0)))
                var max_stamina := player.stamina.get_max_stamina()
                var recovered_stamina := minf(max_stamina, current_stamina + amount)
                stamina_state["current"] = recovered_stamina
                stamina_state["maximum_at_capture"] = max_stamina
                stamina_state["regeneration_block_time"] = 0.0
                state["stamina_state"] = stamina_state
                state["stamina"] = recovered_stamina
                state["stamina_max"] = max_stamina
            RECOVERY_TARGET_MANA:
                if combat_runtime == null or not combat_runtime.has_mana():
                    return {"accepted": false, "reason_id": &"recovery_mana_target_unavailable", "player_state": {}}
                var combat_state := state.get("combat_state", {}) as Dictionary
                var current_mana := float(combat_state.get("mana", combat_runtime.get_mana()))
                var max_mana := combat_runtime.get_max_mana()
                var recovered_mana := minf(max_mana, current_mana + amount)
                combat_state["mana"] = recovered_mana
                combat_state["mana_maximum_at_capture"] = max_mana
                state["combat_state"] = combat_state
                state["mana"] = recovered_mana
                state["mana_max"] = max_mana
            _:
                return {"accepted": false, "reason_id": &"recovery_runtime_target_unsupported", "player_state": {}}
    return {"accepted": true, "reason_id": &"", "player_state": state}


func _open_training_hall_skill_session(structure_id: StringName) -> bool:
    _training_hall_skill_session_active = false
    if (
        structure_id != REGION3_TRAINING_HALL_STRUCTURE_ID
        or _profile == null
        or _save_service == null
        or _slot_index < 1
        or skills_menu == null
        or not is_region3_active()
    ):
        return false
    _sync_operation_guard_with_active_combat()
    if shared_active_combat.is_active() or not operation_guard.is_allowed(GameplayOperationGuard.OP_SERVICE):
        return false
    _training_hall_skill_session_active = true
    var configured := bool(skills_menu.call(
        "configure_progression_actions",
        Callable(self, &"_request_training_hall_skill_rank_purchase"),
        Callable(self, &"_request_training_hall_skill_loadout_swap"),
        Callable(self, &"_training_hall_skill_interaction_state"),
        Callable(self, &"_next_training_hall_skill_transaction_id")
    ))
    if not configured or not bool(skills_menu.call("open_menu")):
        _training_hall_skill_session_active = false
        skills_menu.call("clear_progression_actions")
        return false
    return true


func _training_hall_skill_interaction_state() -> Dictionary:
    _sync_operation_guard_with_active_combat()
    var active_combat := shared_active_combat.is_active()
    var safe_interaction := (
        _training_hall_skill_session_active
        and _profile != null
        and _save_service != null
        and _slot_index >= 1
        and is_region3_active()
    )
    return {
        "safe_interaction": safe_interaction,
        "active_combat": active_combat,
    }


func _request_training_hall_skill_rank_purchase(skill_id: StringName, transaction_id: StringName) -> Dictionary:
    var interaction_state := _training_hall_skill_interaction_state()
    if bool(interaction_state.get("active_combat", true)):
        return _training_hall_skill_rejected(SkillProgressionService.REASON_ACTIVE_COMBAT, transaction_id, skill_id)
    if not bool(interaction_state.get("safe_interaction", false)):
        return _training_hall_skill_rejected(&"training_hall_safe_interaction_required", transaction_id, skill_id)
    var result := SkillProgressionService.commit_rank_purchase(
        _save_service,
        _slot_index,
        _profile,
        skill_id,
        transaction_id
    )
    last_region3_training_skill_result = result.duplicate(true)
    if bool(result.get("accepted", false)):
        _rebind_passive_skill_runtime()
        if combat_hud != null:
            combat_hud.call("set_profile", _profile)
    return result


func _request_training_hall_skill_loadout_swap(
    kind: StringName,
    loadout_slot_index: int,
    skill_id: StringName,
    transaction_id: StringName,
    _reported_safe_interaction: bool,
    _reported_active_combat: bool
) -> Dictionary:
    var interaction_state := _training_hall_skill_interaction_state()
    var safe_interaction := bool(interaction_state.get("safe_interaction", false))
    var active_combat := bool(interaction_state.get("active_combat", true))
    var result: Dictionary
    if kind == SkillDefinition.KIND_ACTIVE:
        result = SkillProgressionService.commit_active_swap(
            _save_service,
            _slot_index,
            _profile,
            loadout_slot_index,
            skill_id,
            transaction_id,
            safe_interaction,
            active_combat
        )
    elif kind == SkillDefinition.KIND_PASSIVE:
        result = SkillProgressionService.commit_passive_swap(
            _save_service,
            _slot_index,
            _profile,
            loadout_slot_index,
            skill_id,
            transaction_id,
            safe_interaction,
            active_combat
        )
    else:
        result = _training_hall_skill_rejected(&"invalid_skill_kind", transaction_id, skill_id)
    last_region3_training_skill_result = result.duplicate(true)
    if bool(result.get("accepted", false)):
        _rebind_passive_skill_runtime()
        if combat_hud != null:
            combat_hud.call("set_profile", _profile)
    return result


func _next_training_hall_skill_transaction_id(operation_id: StringName, skill_id: StringName, slot_index: int) -> StringName:
    if (
        _profile == null
        or not _training_hall_skill_session_active
        or operation_id not in [&"rank_purchase", &"loadout_swap"]
        or not StableId.is_valid(String(skill_id))
        or slot_index < -1
        or slot_index > 1
    ):
        return &""
    var sequence := maxi(_training_hall_skill_transaction_sequence + 1, _profile.claimed_transactions.size() + 1)
    for offset: int in range(1024):
        var candidate := StringName("transaction:region3_training_skill:%s:%s:%d:%d" % [
            String(operation_id),
            String(skill_id),
            slot_index,
            sequence + offset,
        ])
        if not _profile.claimed_transactions.has(String(candidate)):
            _training_hall_skill_transaction_sequence = sequence + offset
            return candidate
    return &""


func _training_hall_skill_rejected(reason_id: StringName, transaction_id: StringName, skill_id: StringName) -> Dictionary:
    var result := {
        "accepted": false,
        "reason_id": reason_id,
        "transaction_id": transaction_id,
        "skill_id": skill_id,
        "durable": false,
    }
    last_region3_training_skill_result = result.duplicate(true)
    return result


func _commit_region3_quest_hall_preparation() -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if _profile == null or _save_service == null or _slot_index < 1 or not is_region3_active():
        return {"accepted": false, "reason_id": &"quest_hall_context_unavailable"}
    var blocking_reasons := operation_guard.get_blocking_reasons(GameplayOperationGuard.OP_SERVICE)
    if not blocking_reasons.is_empty():
        return {
            "accepted": false,
            "reason_id": StringName((blocking_reasons[0] as Dictionary).get("reason_id", &"operation_blocked")),
        }
    if Region3PreparationCommitService.has_tower_sigil(_profile) and Region3PreparationCommitService.is_floor_1_unlocked(_profile):
        return {"accepted": false, "reason_id": &"already_committed"}

    var quest_entry_variant: Variant = _profile.quest_progress.get(String(Region3PreparationCommitService.QUEST_ID), null)
    var quest_entry := (quest_entry_variant as Dictionary) if quest_entry_variant is Dictionary else {}
    var quest_state := StringName(String(quest_entry.get("state", &"")))
    var quest_stage := StringName(String(quest_entry.get("stage_id", &"")))
    var availability_result: Dictionary = {}
    var acceptance_result: Dictionary = {}
    if quest_state == &"" or quest_state == QuestProgressState.STATE_UNAVAILABLE:
        availability_result = QuestActivationService.mark_available(
            _profile,
            Region3PreparationCommitService.QUEST_ID,
            true
        )
        if not bool(availability_result.get("accepted", false)):
            var availability_rejected := availability_result.duplicate(true)
            availability_rejected["phase"] = &"availability"
            return availability_rejected
        quest_state = QuestProgressState.STATE_AVAILABLE
    if quest_state == QuestProgressState.STATE_AVAILABLE:
        acceptance_result = QuestActivationService.accept(
            _profile,
            Region3PreparationCommitService.QUEST_ID,
            REGION3_FLOOR1_PREPARATION_ATTEMPT_ID,
            true
        )
        if not bool(acceptance_result.get("accepted", false)):
            var acceptance_rejected := acceptance_result.duplicate(true)
            acceptance_rejected["phase"] = &"acceptance"
            acceptance_rejected["availability_result"] = availability_result.duplicate(true)
            return acceptance_rejected
        quest_state = QuestProgressState.STATE_ACTIVE
        quest_stage = StringName(String(acceptance_result.get("stage_id", &"")))
    if quest_state != QuestProgressState.STATE_ACTIVE or quest_stage != &"region3_preparation":
        return {
            "accepted": false,
            "reason_id": &"quest_preparation_stage_unavailable",
            "phase": &"preparation",
        }
    var result := Region3PreparationCommitService.commit(
        _save_service,
        _slot_index,
        _profile,
        _profile.safe_state,
        shared_active_combat.is_active(),
        REGION3_FLOOR1_PREPARATION_ATTEMPT_ID
    )
    result["availability_result"] = availability_result.duplicate(true)
    result["acceptance_result"] = acceptance_result.duplicate(true)
    if bool(result.get("accepted", false)):
        if quest_log_menu != null:
            quest_log_menu.call("set_profile", _profile)
        if inventory_menu != null:
            inventory_menu.call("set_profile", _profile)
        if storage_house_menu != null:
            storage_house_menu.set_profile(_profile)
    return result


func _mark_primary_available_if_unlocked(floor_id: int) -> Dictionary:
    if _profile == null or floor_id < 2 or floor_id > PrototypeTowerFloorCatalog.FLOOR_COUNT:
        return {"accepted": false, "reason_id": &"primary_floor_out_of_range", "floor_id": floor_id}
    var quest_id := _primary_quest_id_for_floor(floor_id)
    var definition := QuestCatalog.get_definition(quest_id)
    var production_status := QuestCatalog.primary_production_status(floor_id)
    if definition == null or not bool(production_status.get("production_ready", false)):
        return {
            "accepted": false,
            "reason_id": REASON_PRIMARY_ACTIVATION_POLICY_UNAVAILABLE,
            "floor_id": floor_id,
            "quest_id": quest_id,
            "production_status": production_status.duplicate(true),
        }
    var required_fact := PrimaryQuestProductionV01.unlocked_fact_id(floor_id)
    if not bool(_profile.permanent_flags.get(String(required_fact), false)):
        return {
            "accepted": false,
            "reason_id": QuestActivationService.REASON_PREREQUISITES_NOT_SATISFIED,
            "floor_id": floor_id,
            "quest_id": quest_id,
            "missing_prerequisite_ids": [required_fact],
        }
    var raw_entry: Variant = _profile.quest_progress.get(String(quest_id), null)
    if raw_entry is Dictionary:
        var current_state := StringName(String((raw_entry as Dictionary).get("state", &"")))
        if current_state in [
            QuestProgressState.STATE_AVAILABLE,
            QuestProgressState.STATE_ACTIVE,
            QuestProgressState.STATE_OBJECTIVES_COMPLETE,
            QuestProgressState.STATE_COMPLETED,
        ]:
            return {
                "accepted": true,
                "reason_id": &"already_exposed",
                "floor_id": floor_id,
                "quest_id": quest_id,
                "quest_state": current_state,
                "changed": false,
            }
    var available := QuestActivationService.mark_available(_profile, quest_id, true)
    available["floor_id"] = floor_id
    available["production_status"] = production_status.duplicate(true)
    available["changed"] = bool(available.get("accepted", false))
    return available


func _accept_next_primary_quest_if_ready() -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if (
        _profile == null
        or _save_service == null
        or _slot_index < 1
        or not is_region3_active()
        or shared_active_combat.is_active()
    ):
        return {"attempted": false, "accepted": false, "reason_id": &"primary_accept_context_unavailable"}

    var available_floor_ids: Array[int] = []
    for floor_id: int in range(2, PrototypeTowerFloorCatalog.FLOOR_COUNT + 1):
        var quest_id := _primary_quest_id_for_floor(floor_id)
        var raw_entry: Variant = _profile.quest_progress.get(String(quest_id), null)
        if not raw_entry is Dictionary:
            continue
        if StringName(String((raw_entry as Dictionary).get("state", &""))) == QuestProgressState.STATE_AVAILABLE:
            available_floor_ids.append(floor_id)
    if available_floor_ids.is_empty():
        return {"attempted": false, "accepted": false, "reason_id": &"no_available_primary_quest"}
    if available_floor_ids.size() != 1:
        return {
            "attempted": true,
            "accepted": false,
            "reason_id": &"ambiguous_available_primary_quest",
            "floor_ids": available_floor_ids.duplicate(),
        }

    var floor_id := available_floor_ids[0]
    var quest_id := _primary_quest_id_for_floor(floor_id)
    var definition := QuestCatalog.get_definition(quest_id)
    var production_status := QuestCatalog.primary_production_status(floor_id)
    if definition == null or not bool(production_status.get("production_ready", false)):
        return {
            "attempted": true,
            "accepted": false,
            "reason_id": REASON_PRIMARY_ACTIVATION_POLICY_UNAVAILABLE,
            "floor_id": floor_id,
            "quest_id": quest_id,
            "production_status": production_status.duplicate(true),
        }

    var raw_entry := _profile.quest_progress.get(String(quest_id), {}) as Dictionary
    var history := raw_entry.get("attempt_history", []) as Array
    var attempt_id := StringName("attempt:primary_floor_%d:quest_hall_%03d" % [floor_id, history.size() + 1])
    var facts := PrimaryQuestProductionV01.satisfied_prerequisite_facts(_profile, definition)
    var quest_progress_before := _profile.quest_progress.duplicate(true)
    var accepted := QuestActivationService.activate_authored(
        _profile,
        quest_id,
        attempt_id,
        QuestCatalog.REGION3_QUEST_HALL_ANCHOR_ID,
        facts
    )
    accepted["attempted"] = true
    accepted["floor_id"] = floor_id
    accepted["production_status"] = production_status.duplicate(true)
    if not bool(accepted.get("accepted", false)):
        return accepted

    var safe_state := SafeCheckpointState.make(
        StringName("safe:region3_quest_hall_accept_floor_%d" % floor_id),
        REGION3_MAP_ID,
        0,
        REGION3_TOWN_CHECKPOINT_ID,
        _capture_player_safe_state(),
        _capture_quest_attempt_state(),
        _next_safe_snapshot_sequence()
    )
    if safe_state.is_empty():
        _profile.quest_progress = quest_progress_before
        return {
            "attempted": true,
            "accepted": false,
            "reason_id": &"primary_accept_safe_state_invalid",
            "floor_id": floor_id,
            "quest_id": quest_id,
        }
    var save_error := SafeCheckpointCommitService.commit_checkpoint(
        _save_service,
        _slot_index,
        _profile,
        safe_state
    )
    if save_error != OK:
        _profile.quest_progress = quest_progress_before
        return {
            "attempted": true,
            "accepted": false,
            "reason_id": &"primary_accept_save_failed",
            "save_error": save_error,
            "floor_id": floor_id,
            "quest_id": quest_id,
        }

    accepted["durable"] = true
    accepted["save_error"] = OK
    accepted["safe_state"] = safe_state.duplicate(true)
    if quest_log_menu != null:
        quest_log_menu.call("set_profile", _profile)
    return accepted


func _commit_region3_primary_turn_in_if_ready() -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if _profile == null or _save_service == null or _slot_index < 1 or not is_region3_active():
        return {"attempted": false, "accepted": false, "reason_id": &"quest_hall_context_unavailable"}
    var blocking_reasons := operation_guard.get_blocking_reasons(GameplayOperationGuard.OP_SERVICE)
    if not blocking_reasons.is_empty():
        return {
            "attempted": false,
            "accepted": false,
            "reason_id": StringName((blocking_reasons[0] as Dictionary).get("reason_id", &"operation_blocked")),
        }
    if _profile.safe_state.is_empty() or not SafeCheckpointState.validate_dictionary(_profile.safe_state).is_empty():
        return {"attempted": false, "accepted": false, "reason_id": &"no_pending_primary_turn_in"}
    var pending_floor_ids: Array[int] = []
    for candidate_floor_id: int in range(1, PrototypeTowerFloorCatalog.FLOOR_COUNT + 1):
        var candidate_quest_id := _primary_quest_id_for_floor(candidate_floor_id)
        var candidate_entry_variant: Variant = _profile.quest_progress.get(String(candidate_quest_id), null)
        if not candidate_entry_variant is Dictionary:
            continue
        var candidate_entry := candidate_entry_variant as Dictionary
        if (
            StringName(String(candidate_entry.get("state", &""))) != QuestProgressState.STATE_OBJECTIVES_COMPLETE
            or StringName(String(candidate_entry.get("stage_id", &""))) != &"floor_objective"
        ):
            continue
        var candidate_floor_variant: Variant = _profile.tower_floor_states.get(str(candidate_floor_id), null)
        if not candidate_floor_variant is Dictionary:
            continue
        if not PrimaryFloorExitCommitProof.is_turn_in_safe_context(
            candidate_floor_variant as Dictionary,
            candidate_floor_id,
            candidate_quest_id,
            _profile.safe_state
        ):
            continue
        pending_floor_ids.append(candidate_floor_id)
    if pending_floor_ids.is_empty():
        return {"attempted": false, "accepted": false, "reason_id": &"no_pending_primary_turn_in"}
    if pending_floor_ids.size() != 1:
        return {"attempted": false, "accepted": false, "reason_id": &"ambiguous_pending_primary_turn_in"}
    var floor_id := pending_floor_ids[0]
    var quest_id := _primary_quest_id_for_floor(floor_id)
    if quest_id == &"":
        return {"attempted": false, "accepted": false, "reason_id": &"no_pending_primary_turn_in"}
    var raw_entry: Variant = _profile.quest_progress.get(String(quest_id), null)
    if not raw_entry is Dictionary:
        return {"attempted": false, "accepted": false, "reason_id": &"no_pending_primary_turn_in"}
    var entry := raw_entry as Dictionary
    if (
        StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_OBJECTIVES_COMPLETE
        or StringName(String(entry.get("stage_id", &""))) != &"floor_objective"
    ):
        return {"attempted": false, "accepted": false, "reason_id": &"no_pending_primary_turn_in"}

    var result: Dictionary
    if floor_id == 1:
        result = Floor1PrimaryObjectiveService.commit_turn_in(
            _save_service,
            _slot_index,
            _profile,
            _profile.safe_state
        )
    elif floor_id <= PrimaryFloorTurnInService.LAST_GENERIC_FLOOR:
        result = PrimaryFloorTurnInService.commit_turn_in(
            _save_service,
            _slot_index,
            _profile,
            floor_id,
            _profile.safe_state
        )
    else:
        result = Floor10PrimaryBossObjectiveService.commit_turn_in(
            _save_service,
            _slot_index,
            _profile,
            _profile.safe_state
        )
    result["attempted"] = true
    result["quest_id"] = quest_id
    result["turn_in_floor_id"] = floor_id
    if not bool(result.get("accepted", false)):
        return result

    var next_floor_id := 0
    var next_quest_id: StringName = &""
    var next_entry_existed := false
    var next_entry_before: Dictionary = {}
    if floor_id < PrototypeTowerFloorCatalog.FLOOR_COUNT:
        next_floor_id = floor_id + 1
        next_quest_id = _primary_quest_id_for_floor(next_floor_id)
        var existing_next: Variant = _profile.quest_progress.get(String(next_quest_id), null)
        next_entry_existed = existing_next is Dictionary
        if next_entry_existed:
            next_entry_before = (existing_next as Dictionary).duplicate(true)
        var availability := _mark_primary_available_if_unlocked(next_floor_id)
        result["next_primary_availability"] = availability.duplicate(true)

    var region_safe := _commit_region3_safe_snapshot_after_primary_turn_in(floor_id)
    result["region3_safe_snapshot"] = region_safe.duplicate(true)
    result["region3_safe_snapshot_committed"] = bool(region_safe.get("accepted", false))

    if floor_id < PrototypeTowerFloorCatalog.FLOOR_COUNT:
        var availability_result := result.get("next_primary_availability", {}) as Dictionary
        if (
            not bool(region_safe.get("accepted", false))
            and bool(availability_result.get("changed", false))
        ):
            if next_entry_existed:
                _profile.quest_progress[String(next_quest_id)] = next_entry_before.duplicate(true)
            else:
                _profile.quest_progress.erase(String(next_quest_id))
        var raw_next: Variant = _profile.quest_progress.get(String(next_quest_id), null)
        var next_state := StringName(String((raw_next as Dictionary).get("state", &""))) if raw_next is Dictionary else &""
        result["next_primary_quest_id"] = next_quest_id
        result["next_primary_state"] = next_state
        result["next_primary_production_status"] = QuestCatalog.primary_production_status(next_floor_id)
        result["next_primary_activation_policy_available"] = next_state in [
            QuestProgressState.STATE_AVAILABLE,
            QuestProgressState.STATE_ACTIVE,
            QuestProgressState.STATE_OBJECTIVES_COMPLETE,
            QuestProgressState.STATE_COMPLETED,
        ]
        if not bool(result["next_primary_activation_policy_available"]):
            result["next_primary_activation_reason_id"] = (
                &"next_primary_availability_save_failed"
                if bool(availability_result.get("accepted", false))
                else StringName(String(availability_result.get("reason_id", REASON_PRIMARY_ACTIVATION_POLICY_UNAVAILABLE)))
            )
        else:
            result["next_primary_activation_reason_id"] = &""
    else:
        result["next_primary_quest_id"] = &""
        result["next_primary_state"] = &""
        result["next_primary_activation_policy_available"] = false
        result["next_primary_activation_reason_id"] = &"prototype_milestone_complete"

    # The primary turn-in is already durably committed. A later XP save failure
    # must not revoke it; the separate claim remains retryable at Quest Hall.
    result["xp_award"] = request_completed_quest_xp(quest_id)
    if floor_id == 10:
        result["boss_xp_award"] = request_cleared_tenth_warden_xp()
    if quest_log_menu != null:
        quest_log_menu.call("set_profile", _profile)
    return result


func request_completed_quest_xp(quest_id: StringName) -> Dictionary:
    _sync_operation_guard_with_active_combat()
    var allowed_quest_ids := QuestCatalog.FLOOR_PRIMARY_IDS + QuestCatalog.SIDE_IDS
    if (
        _profile == null or _save_service == null or _slot_index < 1
        or not is_region3_active() or not allowed_quest_ids.has(quest_id)
        or progression_playtest_content == null or not progression_playtest_content.validate_content().is_empty()
    ):
        last_quest_xp_result = {"accepted": false, "reason_id": &"xp_context_unavailable", "quest_id": quest_id}
        return last_quest_xp_result.duplicate(true)
    if not operation_guard.get_blocking_reasons(GameplayOperationGuard.OP_SERVICE).is_empty():
        last_quest_xp_result = {"accepted": false, "reason_id": &"xp_operation_blocked", "quest_id": quest_id}
        return last_quest_xp_result.duplicate(true)
    last_quest_xp_result = PlaytestQuestXpCommitService.commit_completed_quest(
        _save_service, _slot_index, _profile, progression_playtest_content, quest_id,
        Callable(self, &"_capture_progression_runtime_stats"),
        Callable(self, &"_apply_progression_runtime_stats")
    )
    if bool(last_quest_xp_result.get("accepted", false)):
        if skills_menu != null:
            skills_menu.call("set_profile", _profile)
        if quest_log_menu != null:
            quest_log_menu.call("set_profile", _profile)
        if combat_hud != null:
            combat_hud.call("set_profile", _profile)
    return last_quest_xp_result.duplicate(true)


func request_cleared_tenth_warden_xp() -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if (
        _profile == null or _save_service == null or _slot_index < 1
        or not is_region3_active() or progression_playtest_content == null
        or not progression_playtest_content.validate_content().is_empty()
    ):
        return {"accepted": false, "reason_id": &"xp_context_unavailable", "boss_reward": true}
    if not operation_guard.get_blocking_reasons(GameplayOperationGuard.OP_SERVICE).is_empty():
        return {"accepted": false, "reason_id": &"xp_operation_blocked", "boss_reward": true}
    var result := PlaytestQuestXpCommitService.commit_cleared_tenth_warden(
        _save_service, _slot_index, _profile, progression_playtest_content,
        Callable(self, &"_capture_progression_runtime_stats"),
        Callable(self, &"_apply_progression_runtime_stats")
    )
    if bool(result.get("accepted", false)):
        if skills_menu != null:
            skills_menu.call("set_profile", _profile)
        if quest_log_menu != null:
            quest_log_menu.call("set_profile", _profile)
        if combat_hud != null:
            combat_hud.call("set_profile", _profile)
    return result


func _claim_next_completed_quest_xp() -> Dictionary:
    if _profile == null or progression_playtest_content == null:
        return {"attempted": false}
    for quest_id: StringName in QuestCatalog.FLOOR_PRIMARY_IDS + QuestCatalog.SIDE_IDS:
        var raw_entry: Variant = _profile.quest_progress.get(String(quest_id), null)
        if not raw_entry is Dictionary or StringName(String((raw_entry as Dictionary).get("state", &""))) != QuestProgressState.STATE_COMPLETED:
            continue
        var reward := progression_playtest_content.reward_for_source(StringName("quest:%s" % String(quest_id)))
        if reward == null:
            continue
        var ledger := ClaimLedger.new()
        if not ledger.load_dictionary(_profile.claimed_transactions).is_empty():
            return {"attempted": true, "accepted": false, "reason_id": &"xp_claim_ledger_invalid"}
        if ledger.is_claimed(reward.claim_id):
            continue
        var result := request_completed_quest_xp(quest_id)
        result["attempted"] = true
        return result
    var floor10_quest: Variant = _profile.quest_progress.get(String(Floor10PrimaryBossObjectiveService.QUEST_ID), null)
    var floor10_boss_reward := progression_playtest_content.reward_for_source(&"boss:tenth_warden_floor_10")
    if floor10_boss_reward != null and floor10_quest is Dictionary and StringName(String((floor10_quest as Dictionary).get("state", &""))) == QuestProgressState.STATE_COMPLETED:
        var boss_ledger := ClaimLedger.new()
        if not boss_ledger.load_dictionary(_profile.claimed_transactions).is_empty():
            return {"attempted": true, "accepted": false, "reason_id": &"xp_claim_ledger_invalid"}
        if not boss_ledger.is_claimed(floor10_boss_reward.claim_id):
            var boss_result := request_cleared_tenth_warden_xp()
            boss_result["attempted"] = true
            return boss_result
    return {"attempted": false}


func _initialize_progression_runtime_stats() -> void:
    _progression_runtime_stats = {}
    if _profile == null or progression_playtest_content == null or not progression_playtest_content.validate_content().is_empty():
        return
    var initial: Variant = _profile.automatic_stats
    if (initial as Dictionary).is_empty():
        initial = progression_playtest_content.automatic_stat_base_by_class.get(_profile.class_id, null)
    if not initial is Dictionary or not AutomaticStatState.validate_dictionary(initial).is_empty():
        return
    if not _apply_progression_runtime_stats(initial as Dictionary):
        push_error("Could not apply saved progression automatic stats")


func _rebind_passive_skill_runtime() -> bool:
    var bound := (
        _profile != null
        and passive_skills_playtest != null
        and _passive_skill_runtime.bind_profile(_profile, passive_skills_playtest)
    )
    if not bound:
        _passive_skill_runtime.clear()
    combat_runtime.bind_passive_skill_runtime(_passive_skill_runtime if bound else null)
    player.set_passive_skill_runtime(_passive_skill_runtime if bound else null)
    if player_playtest_attack_delivery != null:
        player_playtest_attack_delivery.set_passive_skill_runtime(_passive_skill_runtime if bound else null)
    return bound


func _capture_progression_runtime_stats() -> Dictionary:
    return _progression_runtime_stats.duplicate(true)


func _apply_progression_runtime_stats(stats: Dictionary) -> bool:
    if player == null or player.health == null or player.stamina == null:
        return false
    if not AutomaticStatState.validate_dictionary(stats).is_empty() or not stats.has("hp") or not stats.has("stamina"):
        return false
    var target_hp := float(stats["hp"])
    var target_stamina := float(stats["stamina"])
    if not is_finite(target_hp) or target_hp < 1.0 or target_hp > 2147483647.0 or not is_equal_approx(target_hp, round(target_hp)):
        return false
    if not is_finite(target_stamina) or target_stamina < 1.0 or target_stamina > 1000000.0:
        return false
    if player.health.tuning == null or player.stamina.tuning == null:
        return false
    var health_tuning := player.health.tuning.duplicate(true) as HealthTuning
    var stamina_tuning := player.stamina.tuning.duplicate(true) as StaminaTuning
    if health_tuning == null or stamina_tuning == null:
        return false
    var current_hp := player.health.current_hp
    var current_stamina := player.stamina.current_stamina
    health_tuning.max_hp = int(target_hp)
    stamina_tuning.max_stamina = target_stamina
    player.health.tuning = health_tuning
    player.stamina.tuning = stamina_tuning
    player.health.set_current_hp(current_hp)
    player.stamina.apply_combat_value(current_stamina, false)
    _progression_runtime_stats = AutomaticStatState.normalize_dictionary(stats)
    return true


func _commit_region3_safe_snapshot_after_primary_turn_in(floor_id: int) -> Dictionary:
    if _save_service == null or _slot_index < 1 or not is_region3_active():
        return {"accepted": false, "reason_id": &"region3_safe_context_unavailable", "save_error": ERR_INVALID_PARAMETER}
    var safe_state := SafeCheckpointState.make(
        StringName("safe:region3_quest_hall_after_floor_%d" % floor_id),
        REGION3_MAP_ID,
        0,
        REGION3_TOWN_CHECKPOINT_ID,
        _capture_player_safe_state(),
        _capture_quest_attempt_state(),
        _next_safe_snapshot_sequence()
    )
    if safe_state.is_empty():
        return {"accepted": false, "reason_id": &"region3_safe_state_invalid", "save_error": ERR_INVALID_DATA}
    var save_error := SafeCheckpointCommitService.commit_checkpoint(_save_service, _slot_index, _profile, safe_state)
    return {
        "accepted": save_error == OK,
        "reason_id": &"" if save_error == OK else &"region3_safe_commit_failed",
        "save_error": save_error,
        "safe_state": safe_state.duplicate(true) if save_error == OK else {},
    }


func _primary_quest_id_for_floor(floor_id: int) -> StringName:
    if floor_id < 1 or floor_id > QuestCatalog.FLOOR_PRIMARY_IDS.size():
        return &""
    return QuestCatalog.FLOOR_PRIMARY_IDS[floor_id - 1]


func _clear_region3_runtime_to_foundation() -> void:
    var side_runtime := _region3_side_runtime()
    if side_runtime != null:
        side_runtime.unbind_world()
    region3_town_session_host.clear_loaded_region()
    _region3_player_drop_pickups.clear()
    _region3_last_discovery_zone_id = &""
    _region3_return_position = Vector2.INF
    _region3_suspended_for_tower = false
    _set_foundation_world_enabled(true)
    player.camera.set_world_bounds(Rect2(Vector2.ZERO, Vector2(world_canvas_size)))
    player.camera.reset_after_teleport()
    queue_redraw()


func _finite_numeric(value: Variant) -> bool:
    return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


func _ready() -> void:
    _apply_region3_playtest_content()
    if progression_playtest_content != null and progression_playtest_content.validate_content().is_empty() and level_progression_policy == null:
        level_progression_policy = progression_playtest_content.policy
    player.set_input_ownership(input_ownership)
    player.set_status_movement_provider(status_playtest_tuning, Callable(self, &"_player_status_states_for_movement"))
    _capture_foundation_collision_defaults()
    player.camera.set_world_bounds(Rect2(Vector2.ZERO, Vector2(world_canvas_size)))
    if not input_ownership.modal_opened.is_connected(_on_modal_opened):
        input_ownership.modal_opened.connect(_on_modal_opened)
    if not pause_coordinator.modal_back_requested.is_connected(_on_modal_back_requested):
        pause_coordinator.modal_back_requested.connect(_on_modal_back_requested)
    if manual_save_button != null and not manual_save_button.pressed.is_connected(_on_manual_save_pressed):
        manual_save_button.pressed.connect(_on_manual_save_pressed)
    if not pause_coordinator.pause_changed.is_connected(_on_pause_changed):
        pause_coordinator.pause_changed.connect(_on_pause_changed)
    _initialize_save_coordinator()
    _configure_music_routing()
    tower_encounter_session_host.shared_active_combat = shared_active_combat
    tower_encounter_session_host.shared_full_ai = shared_full_ai
    tower_encounter_session_host.set_decision_target(player)
    if enemy_playtest_attacks != null and enemy_playtest_attacks.validate_catalog().is_empty():
        tower_encounter_session_host.playtest_attack_catalog = enemy_playtest_attacks
    if status_playtest_tuning != null and status_playtest_tuning.validate_tuning().is_empty():
        tower_encounter_session_host.status_playtest_tuning = status_playtest_tuning
    if not death_retry_overlay.retry_requested.is_connected(_on_death_retry_requested):
        death_retry_overlay.retry_requested.connect(_on_death_retry_requested)
    if _profile != null:
        var class_id: StringName = StringName(_profile.class_id)
        if not combat_runtime.configure_class(class_id):
            push_error("Could not configure starter combat kit for class %s" % _profile.class_id)
        elif not player.configure_starter_visuals(class_id, combat_runtime.action_state_machine, combat_runtime):
            push_error("Could not configure starter weapon/body presentation for class %s" % _profile.class_id)
        _initialize_progression_runtime_stats()
        if not combat_runtime.bind_player_stamina(player.stamina):
            push_error("Could not bind live stamina to the player action resource pool")
        if not combat_runtime.bind_equipment_state(_profile.equipment_state):
            push_error("Could not bind profile-owned starter equipment to combat")
        if not _rebind_passive_skill_runtime():
            push_error("Could not bind Inspector-authored passive skill effects")
        if not tower_access_menu.configure(_profile, input_ownership, operation_guard):
            push_error("Could not configure Tower Access Menu")
        elif not tower_access_menu.floor_selected.is_connected(_on_tower_floor_selected):
            tower_access_menu.floor_selected.connect(_on_tower_floor_selected)
        if not map_menu.configure(_profile, input_ownership, tower_floor_session_host, operation_guard):
            push_error("Could not configure Map Menu")
        if quest_log_menu == null or not bool(quest_log_menu.call(
            "configure",
            _profile,
            input_ownership,
            Callable(self, &"request_pending_reward_claim"),
            Callable(self, &"get_pending_reward_claim_status")
        )):
            push_error("Could not configure Quest Log Menu")
        if skills_menu == null or not bool(skills_menu.call("configure", _profile, input_ownership)):
            push_error("Could not configure Skills Menu")
        if inventory_menu == null or not bool(inventory_menu.call(
            "configure",
            _profile,
            input_ownership,
            Callable(self, &"request_inventory_destroy"),
            Callable(self, &"request_inventory_drop"),
            Callable(self, &"get_inventory_drop_status"),
            Callable(self, &"request_inventory_equip"),
            Callable(self, &"request_inventory_unequip"),
            Callable(self, &"request_inventory_quick_slot"),
            item_category_catalog
        )):
            push_error("Could not configure Inventory Menu")
        if storage_house_menu == null or not storage_house_menu.configure(
            _profile,
            input_ownership,
            Callable(self, &"request_region3_storage_deposit"),
            Callable(self, &"request_region3_storage_withdraw")
        ):
            push_error("Could not configure Storage House Menu")
        if merchant_menu == null or not merchant_menu.configure(
            _profile,
            input_ownership,
            Callable(self, &"request_region3_merchant_buy"),
            Callable(self, &"request_region3_merchant_sell"),
            Callable(self, &"request_region3_recovery_service")
        ):
            push_error("Could not configure Merchant Menu")
        if blacksmith_menu != null:
            blacksmith_menu.set_profile(_profile)
        _restore_persisted_tower_session()
    if player_playtest_attack_delivery == null or not player_playtest_attack_delivery.configure(
        player, combat_runtime, tower_encounter_session_host,
        Callable(self, &"_get_playtest_boss_for_player_delivery")
    ):
        push_error("Could not bind provisional player attack contact delivery")
    else:
        player_playtest_attack_delivery.region3_side_target_provider = Callable(self, &"_region3_side_live_targets")
        player_playtest_attack_delivery.configure_skill_ranks(_profile, active_skills_playtest)
        player_playtest_attack_delivery.set_passive_skill_runtime(_passive_skill_runtime if _passive_skill_runtime.content != null else null)
    if enemy_playtest_live_delivery == null or not enemy_playtest_live_delivery.configure(
        player, combat_runtime, tower_encounter_session_host, player_defender_facts_tuning
    ):
        push_error("Could not bind provisional enemy attack contact delivery")
    else:
        enemy_playtest_live_delivery.defender_provider.set_skill_evade_window_provider(
            Callable(player_playtest_attack_delivery, &"has_active_backstep_evade_window")
        )
        if not enemy_playtest_live_delivery.successful_player_parry.is_connected(_on_playtest_successful_parry):
            enemy_playtest_live_delivery.successful_player_parry.connect(_on_playtest_successful_parry)
    if enemy_non_damage_playtest_delivery == null or not enemy_non_damage_playtest_delivery.configure(tower_encounter_session_host, player):
        push_error("Could not bind provisional Support/Controller non-damage signature delivery")
    if combat_hud == null or not bool(combat_hud.call("configure", player, combat_runtime, tower_floor_session_host, _profile, active_skills_playtest, Callable(self, &"_playtest_skill_prerequisites"))):
        push_error("Could not configure Combat HUD")
    queue_redraw()

func _apply_region3_playtest_content() -> void:
    if region3_playtest_content == null:
        return
    var errors := region3_playtest_content.validate_content()
    if not errors.is_empty():
        push_error("Region 3 playtest content invalid: %s" % str(errors))
        return
    # Caller-injected fixtures and later approved production resources take precedence.
    if vendor_stock_catalog == null:
        vendor_stock_catalog = region3_playtest_content.merchant_stock
    if blacksmith_recipe_catalog == null:
        blacksmith_recipe_catalog = region3_playtest_content.blacksmith_recipes
    if item_category_catalog == null:
        item_category_catalog = region3_playtest_content.item_categories
    if region3_inn_recovery_definition.is_empty():
        region3_inn_recovery_definition = region3_playtest_content.inn_recovery.duplicate(true)
    if region3_clinic_recovery_definition.is_empty():
        region3_clinic_recovery_definition = region3_playtest_content.clinic_recovery.duplicate(true)
    if region3_recovery_resource_mapping.is_empty():
        region3_recovery_resource_mapping = region3_playtest_content.recovery_mapping.duplicate(true)


func _exit_tree() -> void:
    _cleanup_floor10_boss_encounter(false)
    _music_state_controller.stop()
    _music_routing_ready = false


func _playtest_skill_prerequisites() -> Dictionary:
    return {&"successful_parry": _successful_parry_ticks > 0}


func request_active_skill_slot(slot_index: int) -> Dictionary:
    if _profile == null or combat_runtime == null or player == null or active_skills_playtest == null:
        last_active_skill_request = {"accepted": false, "reason_id": &"skill_runtime_unavailable", "slot_index": slot_index}
        return last_active_skill_request.duplicate(true)
    if not active_skills_playtest.validate_content().is_empty() or slot_index < 0 or slot_index >= SkillLoadoutState.ACTIVE_SLOT_COUNT:
        last_active_skill_request = {"accepted": false, "reason_id": &"skill_playtest_content_invalid", "slot_index": slot_index}
        return last_active_skill_request.duplicate(true)
    var input_action := &"skill_1" if slot_index == 0 else &"skill_2"
    if death_retry_overlay != null and death_retry_overlay.is_open():
        last_active_skill_request = {"accepted": false, "reason_id": &"skill_player_unavailable", "slot_index": slot_index}
        return last_active_skill_request.duplicate(true)
    if input_ownership == null or not input_ownership.can_route_gameplay_action(input_action):
        last_active_skill_request = {"accepted": false, "reason_id": &"skill_input_owned", "slot_index": slot_index}
        return last_active_skill_request.duplicate(true)
    last_active_skill_request = SkillExecutionService.request_active(
        _profile, slot_index, active_skills_playtest.action_definitions_by_mechanic(),
        Callable(combat_runtime, &"request_active_skill_action"), input_action,
        player.get_aim_direction(),
        {&"successful_parry": _successful_parry_ticks > 0},
        active_skills_playtest
    )
    if bool(last_active_skill_request.get("accepted", false)):
        if last_active_skill_request.get("skill_id", &"") == &"riposte":
            _successful_parry_ticks = 0
        last_active_skill_request["playtest_placeholder"] = true
        var attack_entry := player_playtest_attack_delivery.effect_for_action(StringName(String(last_active_skill_request.get("action_id", &"")))) if player_playtest_attack_delivery != null else {}
        last_active_skill_request["effect_delivery_available"] = not attack_entry.is_empty() and StringName(String(attack_entry.get("mode", &""))) != PlayerPlaytestAttackContent.MODE_WARD
    return last_active_skill_request.duplicate(true)


func _unhandled_input(event: InputEvent) -> void:
    if death_retry_overlay != null and death_retry_overlay.is_open():
        return
    if event.is_action_pressed(&"skill_1") or event.is_action_pressed(&"skill_2"):
        var slot_index := 0 if event.is_action_pressed(&"skill_1") else 1
        if bool(request_active_skill_slot(slot_index).get("accepted", false)):
            get_viewport().set_input_as_handled()
        return
    for slot_index: int in range(InventoryState.QUICK_SLOT_COUNT):
        if event.is_action_pressed(StringName("consumable_%d" % (slot_index + 1))):
            if bool(request_consumable_slot(slot_index).get("accepted", false)):
                get_viewport().set_input_as_handled()
            return
    if event.is_action_pressed(&"basic_attack"):
        if combat_runtime.request_basic_attack(player.get_aim_direction()):
            get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed(&"block"):
        if input_ownership.can_route_gameplay_action(&"block") and combat_runtime.request_block(true):
            get_viewport().set_input_as_handled()
        return
    if event.is_action_released(&"block"):
        combat_runtime.request_block(false)
        return
    if event.is_action_pressed(&"parry"):
        if input_ownership.can_route_gameplay_action(&"parry") and combat_runtime.request_parry():
            get_viewport().set_input_as_handled()

func _on_playtest_successful_parry(_encounter_id: StringName, _actor_id: StringName) -> void:
    if (
        combat_runtime != null and combat_runtime.supports_parry()
        and combat_runtime.get_defense_mode() == DirectHitResolver.DEFENSE_PARRY
        and combat_runtime.get_parry_window_ticks_remaining() > 0
        and player != null and player.health.current_hp > 0
    ):
        _successful_parry_ticks = playtest_riposte_window_ticks
        combat_runtime.cancel_defense()
        var recovered := _passive_skill_runtime.parry_recovery_stamina_gain()
        if recovered > 0.0:
            player.stamina.apply_combat_value(minf(player.stamina.get_max_stamina(), player.stamina.current_stamina + recovered), false)


func _on_modal_opened(_modal_id: StringName) -> void:
    _successful_parry_ticks = 0
    combat_runtime.cancel_defense()

func _on_modal_back_requested(modal_id: StringName) -> void:
    if modal_id == MapMenu.MODAL_ID and map_menu != null and map_menu.is_open():
        map_menu.close_menu(&"pause")
    elif modal_id == TowerAccessMenu.MODAL_ID and tower_access_menu != null and tower_access_menu.is_open():
        tower_access_menu.close_menu(&"pause")
    elif modal_id == QUEST_LOG_MENU_SCRIPT.MODAL_ID and quest_log_menu != null and bool(quest_log_menu.call("is_open")):
        quest_log_menu.call("close_menu", &"pause")
    elif modal_id == SKILLS_MENU_SCRIPT.MODAL_ID and skills_menu != null and bool(skills_menu.call("is_open")):
        skills_menu.call("close_menu", &"pause")
        _training_hall_skill_session_active = false
    elif modal_id == INVENTORY_MENU_SCRIPT.MODAL_ID and inventory_menu != null and bool(inventory_menu.call("is_open")):
        inventory_menu.call("close_menu", &"pause")
    elif modal_id == STORAGE_HOUSE_MENU_SCRIPT.MODAL_ID and storage_house_menu != null and storage_house_menu.is_open():
        storage_house_menu.close_menu(&"pause")
    elif modal_id == MERCHANT_MENU_SCRIPT.MODAL_ID and merchant_menu != null and merchant_menu.is_open():
        merchant_menu.close_menu(&"pause")
    elif modal_id == BLACKSMITH_MENU_SCRIPT.MODAL_ID and blacksmith_menu != null and blacksmith_menu.is_open():
        blacksmith_menu.close_menu(&"pause")

func _initialize_save_coordinator() -> void:
    if _save_service == null or _slot_index < 1 or operation_guard == null:
        return
    if _save_coordinator == null:
        _save_coordinator = SaveRequestCoordinator.new(_save_service, operation_guard)

func request_manual_save() -> Dictionary:
    _sync_operation_guard_with_active_combat()
    _sync_operation_guard_with_unsupported_manual_save_state()
    if _profile == null or _save_coordinator == null or _slot_index < 1:
        last_manual_save_result = {
            "slot_index": _slot_index,
            "request_id": 0,
            "request_kind": SaveRequestCoordinator.REQUEST_MANUAL,
            "state": SaveRequestCoordinator.STATE_FAILED,
            "reason_id": &"save_context_unavailable",
            "reason_text": tr("Manual save context is unavailable."),
            "error_code": ERR_INVALID_PARAMETER,
        }
        return last_manual_save_result.duplicate(true)
    last_manual_save_result = ManualSaveRequestService.request(
        _save_coordinator,
        _slot_index,
        _profile,
        Callable(self, &"_capture_current_save_safe_state")
    )
    return last_manual_save_result.duplicate(true)


func _on_manual_save_pressed() -> void:
    _render_manual_save_status(request_manual_save())


func _on_pause_changed(is_paused: bool, _reason_id: StringName) -> void:
    if is_paused and manual_save_status_label != null:
        manual_save_status_label.text = tr("Save captures the current supported out-of-combat state.")


func _render_manual_save_status(result: Dictionary) -> void:
    if manual_save_status_label == null:
        return
    if StringName(String(result.get("state", &""))) == SaveRequestCoordinator.STATE_SUCCEEDED:
        manual_save_status_label.text = tr("Game saved.")
        return
    var reason_text := String(result.get("reason_text", "")).strip_edges()
    if reason_text.is_empty():
        reason_text = String(result.get("reason_id", &"save_failed"))
    manual_save_status_label.text = tr("Save unavailable: %s") % reason_text


func _capture_current_save_safe_state() -> Dictionary:
    return _capture_current_supported_safe_state(&"manual")


func _capture_current_autosave_safe_state() -> Dictionary:
    return _capture_current_supported_safe_state(&"autosave")


func _capture_current_supported_safe_state(snapshot_kind: StringName) -> Dictionary:
    if _profile == null or snapshot_kind not in [&"manual", &"autosave"]:
        return {}
    var escort_capture := _escort_safe_capture_status()
    if not bool(escort_capture.get("accepted", false)):
        return {}
    var sequence := _next_safe_snapshot_sequence()
    if is_region3_active():
        if not region3_town_session_host.get_world_bounds().has_point(player.global_position):
            return {}
        return SafeCheckpointState.make(
            StringName("safe:%s_region3_%d" % [String(snapshot_kind), sequence]),
            REGION3_MAP_ID,
            0,
            REGION3_TOWN_CHECKPOINT_ID,
            _capture_player_safe_state(),
            _capture_quest_attempt_state(),
            sequence
        )
    if not is_tower_floor_active():
        return {}
    var floor_id := tower_floor_session_host.active_floor_id
    var floor_state := _load_current_floor_state(floor_id)
    if floor_state == null or not _tower_position_is_authored_traversable(floor_state, player.global_position):
        return {}
    var checkpoint_anchor_id := _resolve_tower_manual_respawn_anchor(floor_state)
    if checkpoint_anchor_id == &"":
        return {}
    return SafeCheckpointState.make(
        StringName("safe:%s_tower_floor_%d_%d" % [String(snapshot_kind), floor_id, sequence]),
        StringName("tower:floor_%d" % floor_id),
        floor_id,
        checkpoint_anchor_id,
        _capture_player_safe_state(),
        _capture_quest_attempt_state(),
        sequence
    )


func _load_current_floor_state(floor_id: int) -> FloorInstanceState:
    if _profile == null or floor_id < 1 or floor_id > PrototypeTowerFloorCatalog.FLOOR_COUNT:
        return null
    var raw_floor: Variant = _profile.tower_floor_states.get(str(floor_id), null)
    if not raw_floor is Dictionary:
        return null
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(raw_floor as Dictionary).is_empty() or floor_state.floor_id != floor_id:
        return null
    return floor_state


func _resolve_tower_manual_respawn_anchor(floor_state: FloorInstanceState) -> StringName:
    if floor_state == null:
        return &""
    if not _profile.safe_state.is_empty() and int(_profile.safe_state.get("floor_id", 0)) == floor_state.floor_id:
        var existing := StringName(String(_profile.safe_state.get("checkpoint_anchor_id", &"")))
        if _tower_respawn_anchor_is_valid(floor_state, existing):
            return existing
    var active_anchor := StringName(String(tower_floor_session_host.active_arrival.get("arrival_anchor_id", &"")))
    if _tower_respawn_anchor_is_valid(floor_state, active_anchor):
        return active_anchor
    return &""


func _tower_respawn_anchor_is_valid(floor_state: FloorInstanceState, anchor_id: StringName) -> bool:
    if floor_state == null or not StableId.is_valid(String(anchor_id)):
        return false
    var entrance := TowerArrivalResolver.resolve_entrance(floor_state)
    if bool(entrance.get("accepted", false)) and StringName(String(entrance.get("arrival_anchor_id", &""))) == anchor_id:
        return true
    return bool(TowerArrivalResolver.resolve_checkpoint(floor_state, anchor_id).get("accepted", false))


func _tower_position_is_authored_traversable(floor_state: FloorInstanceState, global_position: Vector2) -> bool:
    if floor_state == null or not is_finite(global_position.x) or not is_finite(global_position.y):
        return false
    var local_position := tower_floor_session_host.to_local(global_position)
    var tile_size := float(TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE)
    var manifest := floor_state.layout_manifest
    for raw_room: Variant in manifest.get("rooms", []) as Array:
        if not raw_room is Dictionary:
            continue
        var room := raw_room as Dictionary
        var rect_variant: Variant = room.get("rect", null)
        if not rect_variant is Rect2i:
            continue
        var definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(room.get("module_id", &""))))
        if definition == null:
            continue
        var room_rect := rect_variant as Rect2i
        var room_local := local_position - Vector2(room_rect.position) * tile_size
        var on_walkable := false
        for walkable_rect: Rect2i in definition.walkable_rects:
            var walkable_pixels := Rect2(Vector2(walkable_rect.position) * tile_size, Vector2(walkable_rect.size) * tile_size)
            if walkable_pixels.has_point(room_local):
                on_walkable = true
                break
        if not on_walkable:
            continue
        var inside_collision := false
        for collision_rect: Rect2i in definition.collision_rects:
            var collision_pixels := Rect2(Vector2(collision_rect.position) * tile_size, Vector2(collision_rect.size) * tile_size)
            if collision_pixels.has_point(room_local):
                inside_collision = true
                break
        if not inside_collision:
            return true
    for raw_edge: Variant in manifest.get("edges", []) as Array:
        if not raw_edge is Dictionary:
            continue
        var edge := raw_edge as Dictionary
        var width_tiles := int(edge.get("route_width_tiles", 0))
        if width_tiles <= 0:
            continue
        var width_px := float(width_tiles) * tile_size
        for raw_tile: Variant in edge.get("route_tiles", []) as Array:
            if not raw_tile is Vector2i:
                continue
            var center := (Vector2(raw_tile as Vector2i) + Vector2(0.5, 0.5)) * tile_size
            if Rect2(center - Vector2.ONE * width_px * 0.5, Vector2.ONE * width_px).has_point(local_position):
                return true
    return false


func _sync_operation_guard_with_unsupported_manual_save_state() -> void:
    if operation_guard == null:
        return
    var reason_text := _unsupported_manual_save_reason_text()
    if not reason_text.is_empty():
        if _unsupported_manual_save_guard_token != 0 and _unsupported_manual_save_guard_reason_text != reason_text:
            operation_guard.release_blocker(_unsupported_manual_save_guard_token)
            _unsupported_manual_save_guard_token = 0
            _unsupported_manual_save_guard_reason_text = ""
        if _unsupported_manual_save_guard_token == 0:
            _unsupported_manual_save_guard_token = operation_guard.acquire_blocker(
                &"save:unsupported_transient",
                GameplayOperationGuard.REASON_UNSUPPORTED_TRANSIENT_STATE,
                reason_text,
                [GameplayOperationGuard.OP_MANUAL_SAVE]
            )
            _unsupported_manual_save_guard_reason_text = reason_text
        return
    if _unsupported_manual_save_guard_token != 0:
        operation_guard.release_blocker(_unsupported_manual_save_guard_token)
        _unsupported_manual_save_guard_token = 0
    _unsupported_manual_save_guard_reason_text = ""


func _unsupported_manual_save_reason_text() -> String:
    var escort_capture := _escort_safe_capture_status()
    if not bool(escort_capture.get("accepted", false)):
        return tr("Manual save is unavailable while the active Escort actor cannot be restored exactly.")
    if player != null and (player.is_dashing() or player.is_dodging() or player.is_climbing()):
        return tr("Manual save is unavailable during transient player movement.")
    if combat_runtime != null and combat_runtime.action_state_machine != null and combat_runtime.action_state_machine.is_busy():
        return tr("Manual save is unavailable while an action is still resolving.")
    return ""


func _has_active_escort_attempt() -> bool:
    return not _active_escort_quest_ids().is_empty()


func _active_escort_quest_ids() -> Array[StringName]:
    var result: Array[StringName] = []
    if _profile == null:
        return result
    for definition: QuestDefinition in QuestCatalog.all_definitions():
        if definition.family != QuestDefinition.FAMILY_ESCORT:
            continue
        var raw_entry: Variant = _profile.quest_progress.get(String(definition.quest_id), null)
        if raw_entry is Dictionary and StringName(String((raw_entry as Dictionary).get("state", &""))) == QuestProgressState.STATE_ACTIVE:
            result.append(definition.quest_id)
    result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
    return result


func _escort_safe_capture_status() -> Dictionary:
    var active_ids := _active_escort_quest_ids()
    if active_ids.is_empty():
        return {"accepted": true, "reason_id": &"", "states": {}}
    if not is_tower_floor_active():
        if is_region3_active():
            for quest_id: StringName in active_ids:
                if quest_id == Region3SideQuestAttemptService.QUEST_ESCORT:
                    var side_runtime := _region3_side_runtime()
                    if side_runtime == null or side_runtime.active_quest_id() != quest_id or side_runtime._escort_actor == null:
                        return {"accepted": false, "reason_id": &"escort_runtime_missing", "quest_id": quest_id, "states": {}}
                    var side_capture := side_runtime.capture_escort_safe_state()
                    if not bool(side_capture.get("accepted", false)):
                        return {"accepted": false, "reason_id": StringName(side_capture.get("reason_id", &"escort_runtime_missing")), "quest_id": quest_id, "states": {}}
                    continue
                var definition := QuestCatalog.get_definition(quest_id)
                if definition == null or definition.kind != QuestDefinition.KIND_PRIMARY or definition.floor_id <= 0:
                    return {"accepted": false, "reason_id": &"escort_runtime_scope_unavailable", "quest_id": quest_id, "states": {}}
            return {"accepted": true, "reason_id": &"", "states": {}}
        return {"accepted": false, "reason_id": &"escort_runtime_scope_unavailable", "states": {}}
    if tower_floor_session_host == null or not tower_floor_session_host.has_restorable_escort_tuning():
        return {"accepted": false, "reason_id": &"escort_restore_tuning_unavailable", "states": {}}
    var floor_id := tower_floor_session_host.active_floor_id
    for quest_id: StringName in active_ids:
        var definition := QuestCatalog.get_definition(quest_id)
        if definition == null or definition.floor_id != floor_id:
            return {"accepted": false, "reason_id": &"escort_runtime_scope_unavailable", "quest_id": quest_id, "states": {}}
    var capture := tower_floor_session_host.capture_escort_safe_states()
    if not bool(capture.get("accepted", false)):
        return capture
    var states := capture.get("states", {}) as Dictionary
    for quest_id: StringName in active_ids:
        if not states.has(String(quest_id)):
            return {"accepted": false, "reason_id": &"escort_runtime_missing", "quest_id": quest_id, "states": {}}
    if states.size() != active_ids.size():
        return {"accepted": false, "reason_id": &"escort_runtime_set_mismatch", "states": {}}
    return {"accepted": true, "reason_id": &"", "states": states.duplicate(true)}


func _request_current_safe_autosave() -> Dictionary:
    _sync_operation_guard_with_active_combat()
    _sync_operation_guard_with_unsupported_manual_save_state()
    if _profile == null or _save_coordinator == null or _slot_index < 1:
        return {
            "slot_index": _slot_index,
            "request_id": 0,
            "request_kind": SaveRequestCoordinator.REQUEST_AUTOSAVE,
            "state": SaveRequestCoordinator.STATE_FAILED,
            "reason_id": &"save_context_unavailable",
            "reason_text": tr("Autosave context is unavailable."),
            "error_code": ERR_INVALID_PARAMETER,
        }
    var capture_context: Dictionary = {}
    var provider := func() -> Variant:
        var safe_state := _capture_current_autosave_safe_state()
        if safe_state.is_empty():
            return null
        var staged := ProfileSnapshot.from_dictionary(_profile.to_dictionary())
        if staged == null:
            return null
        staged.safe_state = safe_state.duplicate(true)
        if not ProfileSnapshot.validate_dictionary(staged.to_dictionary()).is_empty():
            return null
        capture_context["safe_state"] = safe_state.duplicate(true)
        return staged
    var status := _save_coordinator.request_save(
        _slot_index,
        SaveRequestCoordinator.REQUEST_AUTOSAVE,
        provider
    )
    var state := StringName(String(status.get("state", &"")))
    if state == SaveRequestCoordinator.STATE_SUCCEEDED:
        _apply_completed_autosave_capture(capture_context)
        _pending_autosave_context.clear()
    elif state == SaveRequestCoordinator.STATE_PENDING:
        _pending_autosave_context = {
            "request_id": int(status.get("request_id", 0)),
            "capture_context": capture_context,
        }
    return status


func _process_pending_saves() -> void:
    if _save_coordinator == null:
        return
    _save_coordinator.process_pending()
    if _pending_autosave_context.is_empty():
        return
    var status := _save_coordinator.get_status(_slot_index)
    if int(status.get("request_id", 0)) != int(_pending_autosave_context.get("request_id", -1)):
        _pending_autosave_context.clear()
        return
    var state := StringName(String(status.get("state", &"")))
    if state == SaveRequestCoordinator.STATE_SUCCEEDED:
        _apply_completed_autosave_capture(_pending_autosave_context.get("capture_context", {}) as Dictionary)
        _pending_autosave_context.clear()
    elif state == SaveRequestCoordinator.STATE_FAILED:
        _pending_autosave_context.clear()


func _apply_completed_autosave_capture(capture_context: Dictionary) -> void:
    if _profile == null or not capture_context.has("safe_state"):
        return
    var safe_variant: Variant = capture_context.get("safe_state", null)
    if safe_variant is Dictionary and SafeCheckpointState.validate_dictionary(safe_variant as Dictionary).is_empty():
        _profile.safe_state = (safe_variant as Dictionary).duplicate(true)

func _sync_operation_guard_with_active_combat() -> void:
    if operation_guard == null:
        return
    if shared_active_combat.is_active():
        if _active_combat_guard_token == 0:
            _active_combat_guard_token = operation_guard.acquire_blocker(
                &"combat:shared_active",
                GameplayOperationGuard.REASON_ACTIVE_COMBAT,
                tr("Tower travel, manual save, and safe services are unavailable during active combat."),
                [GameplayOperationGuard.OP_SIGIL_TRAVEL, GameplayOperationGuard.OP_MANUAL_SAVE, GameplayOperationGuard.OP_SERVICE]
            )
        return
    if _active_combat_guard_token != 0:
        operation_guard.release_blocker(_active_combat_guard_token)
        _active_combat_guard_token = 0

func get_shared_active_combat_registry() -> ActiveCombatRegistry:
    return shared_active_combat

func get_shared_full_ai_ledger() -> FullAiSimulationLedger:
    return shared_full_ai

func get_pending_reward_claim_status() -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if _profile == null or operation_guard == null:
        return {
            "allowed": false,
            "reason_id": &"claim_context_unavailable",
            "blocking_reasons": [],
        }
    var blocking_reasons := operation_guard.get_blocking_reasons(GameplayOperationGuard.OP_SERVICE)
    return {
        "allowed": blocking_reasons.is_empty(),
        "reason_id": &"" if blocking_reasons.is_empty() else StringName((blocking_reasons[0] as Dictionary).get("reason_id", &"operation_blocked")),
        "blocking_reasons": blocking_reasons.duplicate(true),
    }


func request_region3_storage_deposit(item_instance_id: StringName, quantity: int) -> Dictionary:
    return _request_region3_storage_transfer(true, item_instance_id, quantity)


func request_region3_storage_withdraw(item_instance_id: StringName, quantity: int) -> Dictionary:
    return _request_region3_storage_transfer(false, item_instance_id, quantity)


func _request_region3_storage_transfer(depositing: bool, item_instance_id: StringName, quantity: int) -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if (
        _profile == null
        or not is_region3_active()
        or storage_house_menu == null
        or not storage_house_menu.is_open()
        or input_ownership.current_modal() != STORAGE_HOUSE_MENU_SCRIPT.MODAL_ID
        or not StableId.is_valid(String(item_instance_id))
        or quantity <= 0
    ):
        var invalid := {"accepted": false, "reason_id": &"storage_service_context_unavailable", "durable": false}
        last_region3_storage_transfer_result = invalid.duplicate(true)
        return invalid
    var blocking_reasons := operation_guard.get_blocking_reasons(GameplayOperationGuard.OP_SERVICE)
    if not blocking_reasons.is_empty():
        var blocked := {
            "accepted": false,
            "reason_id": StringName((blocking_reasons[0] as Dictionary).get("reason_id", &"operation_blocked")),
            "durable": false,
        }
        last_region3_storage_transfer_result = blocked.duplicate(true)
        return blocked
    var direction := &"deposit" if depositing else &"withdraw"
    var transaction_id := _next_region3_storage_transaction_id(direction, item_instance_id)
    if transaction_id == &"":
        var unavailable := {"accepted": false, "reason_id": &"storage_transaction_id_unavailable", "durable": false}
        last_region3_storage_transfer_result = unavailable.duplicate(true)
        return unavailable
    var result: Dictionary
    if depositing:
        result = PROFILE_STORAGE_TRANSACTION_SERVICE_SCRIPT.deposit(
            _profile,
            transaction_id,
            item_instance_id,
            quantity
        )
    else:
        result = PROFILE_STORAGE_TRANSACTION_SERVICE_SCRIPT.withdraw(
            _profile,
            transaction_id,
            item_instance_id,
            quantity
        )
    last_region3_storage_transfer_result = result.duplicate(true)
    if bool(result.get("accepted", false)):
        storage_house_menu.set_profile(_profile)
        if inventory_menu != null:
            inventory_menu.call("set_profile", _profile)
    return result


func _next_region3_storage_transaction_id(direction: StringName, item_instance_id: StringName) -> StringName:
    if _profile == null or direction not in [&"deposit", &"withdraw"]:
        return &""
    var sequence := _profile.claimed_transactions.size() + 1
    for offset: int in range(1024):
        var candidate := StringName("transaction:region3_storage_%s:%s:%d" % [String(direction), String(item_instance_id), sequence + offset])
        if not _profile.claimed_transactions.has(String(candidate)):
            return candidate
    return &""


func request_region3_merchant_buy(definition_id: StringName, quantity: int) -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if (
        _profile == null
        or merchant_menu == null
        or not merchant_menu.is_open()
        or not is_region3_active()
        or not operation_guard.is_allowed(GameplayOperationGuard.OP_SERVICE)
        or not StableId.is_valid(String(definition_id))
        or quantity <= 0
    ):
        return {"accepted": false, "reason_id": &"merchant_context_unavailable", "durable": false}
    var vendor_id := merchant_menu.active_vendor_id()
    if not StableId.is_valid(String(vendor_id)):
        return {"accepted": false, "reason_id": &"merchant_vendor_unavailable", "durable": false}
    var transaction_id := _next_profile_mutation_transaction_id(&"region3_vendor_buy", definition_id)
    if transaction_id == &"":
        return {"accepted": false, "reason_id": &"merchant_transaction_id_unavailable", "durable": false}
    var item_instance_id := StringName("item:region3_vendor_purchase:%s" % String(transaction_id))
    var result := ProfileEconomyTransactionService.buy(
        _profile,
        vendor_id,
        transaction_id,
        definition_id,
        item_instance_id,
        quantity
    )
    if bool(result.get("accepted", false)) and inventory_menu != null:
        inventory_menu.call("set_profile", _profile)
    return result


func request_region3_merchant_sell(item_instance_id: StringName, quantity: int) -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if (
        _profile == null
        or merchant_menu == null
        or not merchant_menu.is_open()
        or not is_region3_active()
        or not operation_guard.is_allowed(GameplayOperationGuard.OP_SERVICE)
        or not StableId.is_valid(String(item_instance_id))
        or quantity <= 0
    ):
        return {"accepted": false, "reason_id": &"merchant_context_unavailable", "durable": false}
    var vendor_id := merchant_menu.active_vendor_id()
    if not StableId.is_valid(String(vendor_id)):
        return {"accepted": false, "reason_id": &"merchant_vendor_unavailable", "durable": false}
    var transaction_id := _next_profile_mutation_transaction_id(&"region3_vendor_sell", item_instance_id)
    if transaction_id == &"":
        return {"accepted": false, "reason_id": &"merchant_transaction_id_unavailable", "durable": false}
    var result := ProfileEconomyTransactionService.sell(
        _profile,
        vendor_id,
        transaction_id,
        item_instance_id,
        quantity
    )
    if bool(result.get("accepted", false)) and inventory_menu != null:
        inventory_menu.call("set_profile", _profile)
    return result

func request_region3_blacksmith_upgrade(
    location_id: StringName,
    item_instance_id: StringName,
    recipe: UpgradeRecipeDefinition
) -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if (
        _profile == null
        or blacksmith_menu == null
        or not blacksmith_menu.is_open()
        or not is_region3_active()
        or not operation_guard.is_allowed(GameplayOperationGuard.OP_SERVICE)
        or not StableId.is_valid(String(item_instance_id))
        or recipe == null
        or blacksmith_recipe_catalog == null
    ):
        return {"accepted": false, "reason_id": &"blacksmith_context_unavailable", "durable": false}
    var authoritative := blacksmith_recipe_catalog.get_recipe(recipe.recipe_id)
    if authoritative == null or not _upgrade_recipe_matches(recipe, authoritative):
        return {"accepted": false, "reason_id": &"blacksmith_recipe_authority_mismatch", "durable": false}
    var transaction_id := _next_profile_mutation_transaction_id(&"region3_blacksmith_upgrade", item_instance_id)
    if transaction_id == &"":
        return {"accepted": false, "reason_id": &"blacksmith_transaction_id_unavailable", "durable": false}
    var result := ProfileUpgradeTransactionService.upgrade(
        _profile,
        location_id,
        transaction_id,
        item_instance_id,
        authoritative
    )
    if bool(result.get("accepted", false)):
        # Equipped Blacksmith targets retain instance ID; refresh the live
        # per-rank attack effect immediately after a successful mutation.
        combat_runtime.bind_equipment_state(_profile.equipment_state)
        if inventory_menu != null:
            inventory_menu.call("set_profile", _profile)
        if storage_house_menu != null:
            storage_house_menu.set_profile(_profile)
        blacksmith_menu.set_profile(_profile)
    return result


func request_pending_reward_claim(reward_claim_id: StringName) -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if _profile == null or operation_guard == null or not StableId.is_valid(String(reward_claim_id)):
        return {
            "accepted": false,
            "reason_id": &"claim_context_unavailable",
            "durable": false,
        }
    var transaction_id := StringName("transaction:pending_reward_claim:%s" % String(reward_claim_id))
    var result: Dictionary = PENDING_REWARD_CLAIM_TRANSACTION_SERVICE_SCRIPT.claim(
        _profile,
        operation_guard,
        reward_claim_id,
        transaction_id
    )
    if bool(result.get("accepted", false)):
        var autosave_status := _request_current_safe_autosave()
        result["autosave_status"] = autosave_status.duplicate(true)
        var autosave_state := StringName(String(autosave_status.get("state", &"")))
        result["durable"] = autosave_state == SaveRequestCoordinator.STATE_SUCCEEDED
        if autosave_state == SaveRequestCoordinator.STATE_SUCCEEDED:
            result["durability_boundary"] = &"autosave_committed"
        elif autosave_state == SaveRequestCoordinator.STATE_PENDING:
            result["durability_boundary"] = &"autosave_pending"
        if quest_log_menu != null:
            quest_log_menu.call("set_profile", _profile)
        if inventory_menu != null:
            inventory_menu.call("set_profile", _profile)
    return result


func request_inventory_equip(item_instance_id: StringName, slot_id: StringName) -> Dictionary:
    if _profile == null or not StableId.is_valid(String(item_instance_id)) or not StableId.is_valid(String(slot_id)):
        return {"accepted": false, "reason_id": &"equip_context_unavailable", "durable": false}
    var catalog := StarterEquipmentCatalog.build()
    if catalog == null or not catalog.validate_catalog().is_empty():
        return {"accepted": false, "reason_id": &"equipment_catalog_unavailable", "durable": false}
    var transaction_id := _next_profile_mutation_transaction_id(&"inventory_equip", item_instance_id)
    if transaction_id == &"":
        return {"accepted": false, "reason_id": &"equip_transaction_id_unavailable", "durable": false}
    var result := ProfileInventoryMutationService.equip(_profile, catalog, transaction_id, item_instance_id, slot_id)
    if bool(result.get("accepted", false)):
        combat_runtime.bind_equipment_state(_profile.equipment_state)
    return result


func request_inventory_unequip(slot_id: StringName) -> Dictionary:
    if _profile == null or not StableId.is_valid(String(slot_id)):
        return {"accepted": false, "reason_id": &"unequip_context_unavailable", "durable": false}
    var transaction_id := _next_profile_mutation_transaction_id(&"inventory_unequip", slot_id)
    if transaction_id == &"":
        return {"accepted": false, "reason_id": &"unequip_transaction_id_unavailable", "durable": false}
    var result := ProfileInventoryMutationService.unequip(_profile, transaction_id, slot_id)
    if bool(result.get("accepted", false)):
        combat_runtime.bind_equipment_state(_profile.equipment_state)
    return result


func request_consumable_slot(slot_index: int) -> Dictionary:
    var input_id := StringName("consumable_%d" % (slot_index + 1))
    if (
        _profile == null or player == null or player.health == null
        or slot_index < 0 or slot_index >= InventoryState.QUICK_SLOT_COUNT
        or consumable_playtest_tuning == null or item_category_catalog == null
    ):
        last_consumable_request = {"accepted": false, "reason_id": &"consumable_context_unavailable"}
        return last_consumable_request.duplicate(true)
    if (
        player.health.is_defeated()
        or (death_retry_overlay != null and death_retry_overlay.is_open())
        or input_ownership == null or not input_ownership.can_route_gameplay_action(input_id)
    ):
        last_consumable_request = {"accepted": false, "reason_id": &"consumable_input_blocked"}
        return last_consumable_request.duplicate(true)
    var transaction_id := _next_profile_mutation_transaction_id(
        &"consumable_use", StringName("quick_slot:%d" % slot_index)
    )
    if transaction_id == &"":
        last_consumable_request = {"accepted": false, "reason_id": &"consumable_transaction_unavailable"}
        return last_consumable_request.duplicate(true)
    var staged := ConsumablePlaytestUseService.prepare(
        _profile, slot_index, transaction_id, item_category_catalog, consumable_playtest_tuning,
        player.health.current_hp, player.health.get_max_hp()
    )
    if not bool(staged.get("accepted", false)):
        last_consumable_request = staged.duplicate(true)
        return last_consumable_request.duplicate(true)
    if not player.health.set_current_hp(int(staged["health_after"])):
        last_consumable_request = {"accepted": false, "reason_id": &"consumable_health_apply_failed"}
        return last_consumable_request.duplicate(true)
    # No intermediate signal or safe-save request may claim staged items before
    # both the live health owner and validated inventory transaction succeed.
    _profile.item_state = (staged["item_state"] as Dictionary).duplicate(true)
    _profile.claimed_transactions = (staged["claimed_transactions"] as Dictionary).duplicate(true)
    last_consumable_request = staged.duplicate(true)
    last_consumable_request.erase("item_state")
    last_consumable_request.erase("claimed_transactions")
    if inventory_menu != null:
        inventory_menu.call("set_profile", _profile)
    if combat_hud != null:
        combat_hud.call("set_profile", _profile)
    return last_consumable_request.duplicate(true)


func request_inventory_quick_slot(slot_index: int, item_instance_id: StringName) -> Dictionary:
    if (
        _profile == null
        or slot_index < 0
        or slot_index >= InventoryState.QUICK_SLOT_COUNT
        or (item_instance_id != &"" and not StableId.is_valid(String(item_instance_id)))
    ):
        return {"accepted": false, "reason_id": &"quick_slot_context_unavailable", "durable": false}
    var subject := item_instance_id if item_instance_id != &"" else StringName("quick_slot:%d:clear" % slot_index)
    var transaction_id := _next_profile_mutation_transaction_id(&"inventory_quick_slot", subject)
    if transaction_id == &"":
        return {"accepted": false, "reason_id": &"quick_slot_transaction_id_unavailable", "durable": false}
    return ProfileInventoryMutationService.bind_quick_slot(
        _profile,
        transaction_id,
        slot_index,
        item_instance_id,
        item_category_catalog
    )


func _next_profile_mutation_transaction_id(operation_id: StringName, subject_id: StringName) -> StringName:
    if _profile == null or not StableId.is_valid(String(operation_id)) or not StableId.is_valid(String(subject_id)):
        return &""
    var sequence := maxi(_profile_mutation_transaction_sequence + 1, _profile.claimed_transactions.size() + 1)
    for offset: int in range(1024):
        var candidate := StringName("transaction:%s:%s:%d" % [String(operation_id), String(subject_id), sequence + offset])
        if not _profile.claimed_transactions.has(String(candidate)):
            _profile_mutation_transaction_sequence = sequence + offset
            return candidate
    return &""

func request_inventory_destroy(item_instance_id: StringName, quantity: int, confirmed: bool) -> Dictionary:
    if _profile == null or not StableId.is_valid(String(item_instance_id)) or quantity <= 0:
        return {"accepted": false, "reason_id": &"destroy_context_unavailable", "durable": false}
    var transaction_id := _next_inventory_destroy_transaction_id(item_instance_id)
    if transaction_id == &"":
        return {"accepted": false, "reason_id": &"destroy_transaction_id_unavailable", "durable": false}
    var result: Dictionary = InventoryDestroyTransactionService.destroy_normal_item(
        _profile,
        transaction_id,
        item_instance_id,
        quantity,
        confirmed
    )
    result["durable"] = false
    if bool(result.get("accepted", false)):
        result["durability_boundary"] = &"next_safe_snapshot"
        if inventory_menu != null:
            inventory_menu.call("set_profile", _profile)
    return result

func _next_inventory_destroy_transaction_id(item_instance_id: StringName) -> StringName:
    if _profile == null:
        return &""
    var sequence := _profile.claimed_transactions.size() + 1
    for offset: int in range(1024):
        var candidate := StringName("transaction:inventory_destroy:%s:%d" % [String(item_instance_id), sequence + offset])
        if not _profile.claimed_transactions.has(String(candidate)):
            return candidate
    return &""

func get_inventory_drop_status() -> Dictionary:
    if _profile == null:
        return {"allowed": false, "reason_id": &"profile_unavailable", "world_kind": &"", "floor_id": 0}
    if is_tower_floor_active():
        return {
            "allowed": true,
            "reason_id": &"",
            "world_kind": &"tower",
            "floor_id": tower_floor_session_host.active_floor_id,
        }
    if is_region3_active():
        return {
            "allowed": true,
            "reason_id": &"",
            "world_kind": &"region3",
            "floor_id": 0,
        }
    return {"allowed": false, "reason_id": &"drop_world_required", "world_kind": &"", "floor_id": 0}

func request_inventory_drop(item_instance_id: StringName) -> Dictionary:
    if _profile == null or not StableId.is_valid(String(item_instance_id)):
        return {"accepted": false, "reason_id": &"drop_context_unavailable", "durable": false}
    if is_tower_floor_active():
        return _request_tower_inventory_drop(item_instance_id)
    if is_region3_active():
        return _request_region3_inventory_drop(item_instance_id)
    return {"accepted": false, "reason_id": &"drop_context_unavailable", "durable": false}

func _request_tower_inventory_drop(item_instance_id: StringName) -> Dictionary:
    var floor_id := tower_floor_session_host.active_floor_id
    var transaction_id := _next_inventory_drop_transaction_id(item_instance_id)
    if transaction_id == &"":
        return {"accepted": false, "reason_id": &"drop_transaction_id_unavailable", "durable": false}
    var floor_local_position := tower_floor_session_host.to_local(player.global_position)
    var result: Dictionary = INVENTORY_DROP_TRANSACTION_SERVICE_SCRIPT.drop_full_stack(
        _profile,
        floor_id,
        transaction_id,
        item_instance_id,
        floor_local_position
    )
    result["durable"] = false
    result["world_kind"] = &"tower"
    if not bool(result.get("accepted", false)):
        last_tower_player_drop_result = result.duplicate(true)
        return result
    result["durability_boundary"] = &"next_safe_snapshot"
    var source_id := StringName(String(result.get("source_id", &"")))
    result["runtime_pickup_ready"] = _sync_tower_player_drop_pickups(source_id)
    last_tower_player_drop_result = result.duplicate(true)
    if inventory_menu != null:
        inventory_menu.call("set_profile", _profile)
    return result

func _request_region3_inventory_drop(item_instance_id: StringName) -> Dictionary:
    var layout := region3_town_session_host.active_runtime_root
    if layout == null:
        return {"accepted": false, "reason_id": &"drop_context_unavailable", "durable": false, "world_kind": &"region3"}
    var transaction_id := _next_inventory_drop_transaction_id(item_instance_id)
    if transaction_id == &"":
        return {"accepted": false, "reason_id": &"drop_transaction_id_unavailable", "durable": false, "world_kind": &"region3"}
    var region_local_position := region3_town_session_host.to_local(player.global_position)
    var result: Dictionary = REGION3_INVENTORY_DROP_TRANSACTION_SERVICE_SCRIPT.drop_full_stack(
        _profile,
        layout,
        transaction_id,
        item_instance_id,
        region_local_position
    )
    result["durable"] = false
    result["world_kind"] = &"region3"
    if not bool(result.get("accepted", false)):
        last_region3_player_drop_result = result.duplicate(true)
        return result
    result["durability_boundary"] = &"next_safe_snapshot"
    var source_id := StringName(String(result.get("source_id", &"")))
    result["runtime_pickup_ready"] = _sync_region3_player_drop_pickups(source_id)
    last_region3_player_drop_result = result.duplicate(true)
    if inventory_menu != null:
        inventory_menu.call("set_profile", _profile)
    return result

func _next_inventory_drop_transaction_id(item_instance_id: StringName) -> StringName:
    if _profile == null:
        return &""
    var sequence := _profile.claimed_transactions.size() + 1
    for offset: int in range(1024):
        var candidate := StringName("transaction:inventory_drop:%s:%d" % [String(item_instance_id), sequence + offset])
        if not _profile.claimed_transactions.has(String(candidate)):
            return candidate
    return &""

func _next_inventory_pickup_transaction_id(source_id: StringName) -> StringName:
    if _profile == null:
        return &""
    var sequence := _profile.claimed_transactions.size() + 1
    for offset: int in range(1024):
        var candidate := StringName("transaction:inventory_pickup:%s:%d" % [String(source_id), sequence + offset])
        if not _profile.claimed_transactions.has(String(candidate)):
            return candidate
    return &""

func request_tower_travel(floor_id: int, danger_confirmed: bool, leave_plans: Array = []) -> Dictionary:
    _sync_operation_guard_with_active_combat()
    _sync_operation_guard_with_unsupported_manual_save_state()
    if _profile == null or _save_coordinator == null or operation_guard == null:
        return _tower_travel_rejected(&"save_context_unavailable")
    var selection := TowerAccessMenuService.validate_selection(_profile, operation_guard, floor_id)
    if not bool(selection.get("accepted", false)):
        return _tower_travel_rejected(StringName(selection.get("reason_id", &"selection_rejected")), selection)
    if _has_active_region3_side_quest():
        var leave_quest_id: StringName = &""
        for side_quest_id: StringName in REGION3_SIDE_QUEST_IDS:
            var raw_side: Variant = _profile.quest_progress.get(String(side_quest_id), null)
            if raw_side is Dictionary and StringName(String((raw_side as Dictionary).get("state", &""))) == QuestProgressState.STATE_ACTIVE:
                leave_quest_id = side_quest_id
                break
        var leave_rejection := _tower_travel_rejected(TowerTravelPlanService.REASON_LEAVE_PLAN_MISSING, selection)
        leave_rejection["plan"] = {"leave_quest_id": leave_quest_id}
        return leave_rejection
    var entry := selection.get("entry", {}) as Dictionary
    if bool(entry.get("requires_danger_confirmation", false)) and not danger_confirmed:
        return _tower_travel_rejected(&"danger_confirmation_required", selection)

    var identity := TowerGenerationIdentityFactory.build_tuple(_profile, floor_id)
    if identity.is_empty():
        return _tower_travel_rejected(&"generation_identity_invalid", selection)
    var plan := TowerTravelPlanService.stage(
        _profile,
        operation_guard,
        floor_id,
        int(identity["generation_seed"]),
        StringName(identity["generator_version"]),
        StringName(identity["module_content_version"]),
        StringName(identity["encounter_config_id"]),
        StringName(identity["quest_world_flags_signature"]),
        StringName(identity["instance_id"]),
        leave_plans,
        []
    )
    if not bool(plan.get("accepted", false)):
        var rejected := _tower_travel_rejected(StringName(plan.get("reason_id", &"travel_plan_rejected")), selection)
        rejected["plan"] = plan.duplicate(true)
        return rejected

    var generation_guard_token := operation_guard.acquire_blocker(
        &"tower:generation_construction",
        GameplayOperationGuard.REASON_GENERATOR_CONSTRUCTION,
        tr("Manual save is unavailable while the destination floor is being constructed."),
        [GameplayOperationGuard.OP_MANUAL_SAVE]
    )
    var runtime_preparation := TowerTravelCommitService.prepare_runtime(plan, TOWER_VISUAL_CATALOG)
    if generation_guard_token != 0:
        operation_guard.release_blocker(generation_guard_token)
    if not bool(runtime_preparation.get("accepted", false)):
        var rejected := _tower_travel_rejected(StringName(runtime_preparation.get("reason_id", &"runtime_preparation_failed")), selection)
        rejected["plan"] = plan.duplicate(true)
        rejected["runtime_preparation"] = runtime_preparation.duplicate(true)
        return rejected

    var destination_player_state := _capture_player_safe_state()
    var prepared_arrival := runtime_preparation.get("arrival", {}) as Dictionary
    var world_tile_variant: Variant = prepared_arrival.get("world_tile", null)
    if world_tile_variant is Vector2i:
        var destination_position := (Vector2(world_tile_variant as Vector2i) + Vector2(0.5, 0.5)) * float(TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE)
        destination_player_state["position_x"] = destination_position.x
        destination_player_state["position_y"] = destination_position.y
    var commit := TowerTravelCommitService.commit(
        _save_coordinator,
        _slot_index,
        _profile,
        operation_guard,
        plan,
        runtime_preparation,
        destination_player_state,
        _capture_quest_attempt_state(),
        _next_safe_snapshot_sequence()
    )
    if not bool(commit.get("accepted", false)):
        var runtime_root := runtime_preparation.get("runtime_root") as Node2D
        if runtime_root != null and runtime_root.get_parent() == null:
            runtime_root.free()
        var rejected := _tower_travel_rejected(StringName(commit.get("reason_id", &"travel_commit_failed")), selection)
        rejected["plan"] = plan.duplicate(true)
        rejected["commit"] = commit.duplicate(true)
        return rejected

    if not activate_committed_tower_travel(commit):
        var runtime_root := commit.get("runtime_root") as Node2D
        if runtime_root != null and runtime_root.get_parent() == null:
            runtime_root.free()
        return {
            "accepted": false,
            "reason_id": &"session_activation_failed",
            "durable_commit": true,
            "floor_id": floor_id,
            "selection": selection.duplicate(true),
            "commit": commit.duplicate(true),
        }
    var result := {
        "accepted": true,
        "reason_id": &"",
        "durable_commit": true,
        "floor_id": floor_id,
        "selection": selection.duplicate(true),
        "commit": commit.duplicate(true),
    }
    last_tower_travel_result = result.duplicate(true)
    tower_travel_finished.emit(result.duplicate(true))
    return result

func _on_tower_floor_selected(floor_id: int, danger_confirmed: bool) -> void:
    var result := request_tower_travel(floor_id, danger_confirmed)
    last_tower_travel_result = result.duplicate(true)
    if bool(result.get("accepted", false)):
        tower_access_menu.close_menu()
        return
    var reason_id := StringName(result.get("reason_id", &"travel_rejected"))
    var message := tr("Travel could not be completed: %s") % String(reason_id).replace("_", " ")
    if reason_id == TowerTravelPlanService.REASON_LEAVE_PLAN_MISSING:
        var plan := result.get("plan", {}) as Dictionary
        message = tr("An active quest requires an authored leave decision before tower travel: %s") % String(plan.get("leave_quest_id", &""))
    tower_access_menu.set_status_message(message)
    tower_travel_finished.emit(result.duplicate(true))

func retry_failed_attempt() -> Dictionary:
    if _save_service == null or _slot_index < 1:
        return {"accepted": false, "reason_id": &"save_context_unavailable"}
    var retry := DeathRetryCoordinator.retry_failed_attempt(_save_service, _slot_index)
    if not bool(retry.get("accepted", false)):
        return retry
    var restored_profile := retry.get("profile") as ProfileSnapshot
    if restored_profile == null:
        return {"accepted": false, "reason_id": &"restored_profile_missing"}

    if tower_access_menu != null and tower_access_menu.visible:
        tower_access_menu.close_menu()
    if is_region3_active() and not is_tower_floor_active():
        # Regional death retry preserves the loaded town and its world bounds.
        # A tower clear would enable the foundation collision at the origin.
        _clear_player_combat_bindings()
        tower_encounter_session_host.end_all_encounters()
    else:
        clear_tower_floor_session(Vector2.ZERO)
    var side_runtime := _region3_side_runtime()
    if side_runtime != null and not side_runtime.unbind_world(true):
        return {"accepted": false, "reason_id": &"side_quest_checkpoint_reset_failed"}
    _profile = restored_profile
    shared_active_combat = ActiveCombatRegistry.new()
    shared_full_ai = FullAiSimulationLedger.new()
    tower_encounter_session_host.shared_active_combat = shared_active_combat
    tower_encounter_session_host.shared_full_ai = shared_full_ai
    tower_encounter_session_host.set_decision_target(player)
    _active_combat_guard_token = 0

    var class_id := StringName(_profile.class_id)
    if not combat_runtime.configure_class(class_id) or not combat_runtime.bind_player_stamina(player.stamina) or not combat_runtime.bind_equipment_state(_profile.equipment_state):
        return {"accepted": false, "reason_id": &"combat_runtime_restore_failed"}
    if not player.configure_starter_visuals(class_id, combat_runtime.action_state_machine, combat_runtime):
        return {"accepted": false, "reason_id": &"player_presentation_restore_failed"}
    if not _rebind_passive_skill_runtime():
        return {"accepted": false, "reason_id": &"passive_skill_restore_failed"}
    if player_playtest_attack_delivery != null and not player_playtest_attack_delivery.configure_skill_ranks(_profile, active_skills_playtest):
        return {"accepted": false, "reason_id": &"active_skill_rank_restore_failed"}
    if not tower_access_menu.configure(_profile, input_ownership, operation_guard):
        return {"accepted": false, "reason_id": &"tower_menu_restore_failed"}

    var floor_id := int(_profile.safe_state.get("floor_id", 0))
    if floor_id > 0:
        if not _restore_persisted_tower_session():
            var rejected := retry.duplicate(true)
            rejected["accepted"] = false
            rejected["reason_id"] = StringName(tower_restore_status.get("reason_id", &"tower_session_restore_failed"))
            return rejected
    else:
        var player_state := _profile.safe_state.get("player_state", {}) as Dictionary
        if not _restore_player_safe_state(player_state):
            var rejected := retry.duplicate(true)
            rejected["accepted"] = false
            rejected["reason_id"] = &"player_state_restore_failed"
            return rejected
        if player_state.has("position_x") and player_state.has("position_y"):
            player.global_position = Vector2(float(player_state["position_x"]), float(player_state["position_y"]))
            player.velocity = Vector2.ZERO
            player.camera.reset_after_teleport()

    if side_runtime != null and is_region3_active():
        var configured: Dictionary = _bind_region3_side_runtime()
        if not bool(configured.get("accepted", false)):
            return {"accepted": false, "reason_id": StringName(configured.get("reason_id", &"side_runtime_restore_failed"))}
    _sync_operation_guard_with_active_combat()
    queue_redraw()
    retry["profile"] = _profile
    retry["restored_live_gameplay"] = true
    return retry

func _capture_player_safe_state() -> Dictionary:
    var health_state := player.health.capture_safe_state()
    var stamina_state := player.stamina.capture_safe_state()
    var combat_state := combat_runtime.capture_safe_state()
    var state := {
        "position_x": player.global_position.x,
        "position_y": player.global_position.y,
        "hp": player.health.current_hp,
        "hp_max": player.health.get_max_hp(),
        "health_state": health_state,
        "stamina": player.stamina.current_stamina,
        "stamina_max": player.stamina.get_max_stamina(),
        "stamina_state": stamina_state,
        "class_id": String(combat_runtime.get_class_id()),
        "defense_mode": String(combat_runtime.get_defense_mode()),
        "combat_state": combat_state,
    }
    if combat_runtime.has_mana():
        state["mana"] = combat_runtime.get_mana()
        state["mana_max"] = combat_runtime.get_max_mana()
    return state

func _restore_player_safe_state(raw_state: Variant) -> bool:
    if not raw_state is Dictionary:
        return false
    var state := raw_state as Dictionary
    var health_variant: Variant = state.get("health_state", null)
    if health_variant is Dictionary:
        if not player.health.restore_safe_state(health_variant as Dictionary):
            return false
    elif state.has("hp"):
        var hp_value: Variant = state.get("hp", null)
        if typeof(hp_value) != TYPE_INT and typeof(hp_value) != TYPE_FLOAT:
            return false
        if not player.health.restore_safe_state({"current": hp_value}):
            return false

    var stamina_variant: Variant = state.get("stamina_state", null)
    if stamina_variant is Dictionary:
        if not player.stamina.restore_safe_state(stamina_variant as Dictionary):
            return false
    elif state.has("stamina"):
        var stamina_value: Variant = state.get("stamina", null)
        if not (typeof(stamina_value) == TYPE_INT or typeof(stamina_value) == TYPE_FLOAT):
            return false
        if not player.stamina.restore_safe_state({"current": float(stamina_value), "regeneration_block_time": 0.0}):
            return false

    var combat_variant: Variant = state.get("combat_state", null)
    if combat_variant is Dictionary:
        if not combat_runtime.restore_safe_state(combat_variant as Dictionary):
            return false
    elif state.has("class_id") or state.has("mana") or state.has("defense_mode"):
        var legacy_combat := combat_runtime.capture_safe_state()
        if state.has("class_id"):
            legacy_combat["class_id"] = String(state.get("class_id", ""))
        if state.has("defense_mode"):
            legacy_combat["defense_mode"] = String(state.get("defense_mode", "none"))
        if state.has("mana"):
            legacy_combat["mana"] = float(state.get("mana", combat_runtime.get_mana()))
        if not combat_runtime.restore_safe_state(legacy_combat):
            return false
    return true

func _capture_quest_attempt_state() -> Dictionary:
    if _profile == null:
        return {}
    var result := {"quest_progress": _profile.quest_progress.duplicate(true)}
    var escort_capture := _escort_safe_capture_status()
    if bool(escort_capture.get("accepted", false)):
        var states := escort_capture.get("states", {}) as Dictionary
        if not states.is_empty():
            result["escort_runtime_states"] = states.duplicate(true)
    # The regional escort snapshot is committed to the profile's quest entry;
    # it is not a second mutable copy of the actor position in safe_state.
    result["quest_progress"] = _profile.quest_progress.duplicate(true)
    return result

func _next_safe_snapshot_sequence() -> int:
    if _profile == null or _profile.safe_state.is_empty():
        return 1
    return int(_profile.safe_state.get("snapshot_sequence", 0)) + 1

func _tower_travel_rejected(reason_id: StringName, selection: Dictionary = {}) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "durable_commit": false,
        "floor_id": int(selection.get("floor_id", 0)),
        "selection": selection.duplicate(true),
    }

func _restore_persisted_tower_session() -> bool:
    tower_restore_status = {}
    if _profile == null or _profile.safe_state.is_empty():
        return false
    if not SafeCheckpointState.validate_dictionary(_profile.safe_state).is_empty():
        tower_restore_status = {"accepted": false, "reason_id": &"invalid_safe_state"}
        return false
    var floor_id := int(_profile.safe_state.get("floor_id", 0))
    if floor_id <= 0:
        return false
    var raw_floor: Variant = _profile.tower_floor_states.get(str(floor_id), null)
    if not raw_floor is Dictionary:
        tower_restore_status = {"accepted": false, "reason_id": &"floor_instance_missing", "floor_id": floor_id}
        return false
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(raw_floor as Dictionary).is_empty() or floor_state.floor_id != floor_id:
        tower_restore_status = {"accepted": false, "reason_id": &"floor_instance_invalid", "floor_id": floor_id}
        return false
    var arrival := TowerArrivalResolver.resolve_saved_safe_state(floor_state, _profile.safe_state)
    if not bool(arrival.get("accepted", false)):
        tower_restore_status = {"accepted": false, "reason_id": StringName(arrival.get("reason_id", &"")), "floor_id": floor_id}
        return false
    var build := TowerFloorRuntimeComposer.build(floor_state.layout_manifest, TOWER_VISUAL_CATALOG)
    if not bool(build.get("accepted", false)):
        tower_restore_status = {"accepted": false, "reason_id": &"runtime_build_failed", "floor_id": floor_id}
        return false
    var root := build.get("root") as Node2D
    var activated := activate_committed_tower_travel({"accepted": true, "runtime_root": root, "arrival": arrival})
    if not activated:
        if root != null and root.get_parent() == null:
            root.free()
        tower_restore_status = {"accepted": false, "reason_id": &"session_activation_failed", "floor_id": floor_id}
        return false
    var safe_player_state := _profile.safe_state.get("player_state", {}) as Dictionary
    if not _restore_player_safe_state(safe_player_state):
        clear_tower_floor_session(Vector2.ZERO)
        tower_restore_status = {"accepted": false, "reason_id": &"player_state_restore_failed", "floor_id": floor_id}
        return false
    if safe_player_state.has("position_x") and safe_player_state.has("position_y"):
        var position_x: Variant = safe_player_state.get("position_x", null)
        var position_y: Variant = safe_player_state.get("position_y", null)
        if not _finite_numeric(position_x) or not _finite_numeric(position_y):
            clear_tower_floor_session(Vector2.ZERO)
            tower_restore_status = {"accepted": false, "reason_id": &"player_position_restore_failed", "floor_id": floor_id}
            return false
        var saved_position := Vector2(float(position_x), float(position_y))
        if not _tower_position_is_authored_traversable(floor_state, saved_position):
            clear_tower_floor_session(Vector2.ZERO)
            tower_restore_status = {"accepted": false, "reason_id": &"player_position_restore_failed", "floor_id": floor_id}
            return false
        player.global_position = saved_position
        player.velocity = Vector2.ZERO
        player.camera.reset_after_teleport()
    var escort_restore := _restore_saved_escort_runtime_states(floor_state)
    if not bool(escort_restore.get("accepted", false)):
        clear_tower_floor_session(Vector2.ZERO)
        tower_restore_status = {
            "accepted": false,
            "reason_id": &"escort_runtime_restore_failed",
            "escort_reason_id": StringName(String(escort_restore.get("reason_id", &""))),
            "floor_id": floor_id,
        }
        return false
    tower_restore_status = {
        "accepted": true,
        "reason_id": &"",
        "floor_id": floor_id,
        "arrival": arrival.duplicate(true),
        "fallback_to_entrance": bool(arrival.get("fallback_to_entrance", false)),
        "fallback_reason_id": StringName(arrival.get("fallback_reason_id", &"")),
        "escort_restore": escort_restore.duplicate(true),
    }
    return true


func _restore_saved_escort_runtime_states(floor_state: FloorInstanceState) -> Dictionary:
    if _profile == null or floor_state == null or tower_floor_session_host == null:
        return {"accepted": false, "reason_id": &"escort_restore_context_unavailable"}
    var attempt_variant: Variant = _profile.safe_state.get("quest_attempt_state", null)
    if not attempt_variant is Dictionary:
        return {"accepted": false, "reason_id": &"escort_safe_attempt_state_invalid"}
    var attempt_state := attempt_variant as Dictionary
    if not attempt_state.has("escort_runtime_states"):
        return {"accepted": true, "reason_id": &"", "restored": false, "restored_quest_ids": []}
    var restore := tower_floor_session_host.restore_escort_safe_states(
        _profile,
        floor_state,
        attempt_state.get("escort_runtime_states", null)
    )
    restore["restored"] = bool(restore.get("accepted", false))
    return restore


func _saved_safe_state_has_escort_runtime_for_floor(floor_id: int) -> bool:
    if _profile == null or floor_id <= 0 or int(_profile.safe_state.get("floor_id", 0)) != floor_id:
        return false
    var attempt_variant: Variant = _profile.safe_state.get("quest_attempt_state", null)
    if not attempt_variant is Dictionary:
        return false
    var states_variant: Variant = (attempt_variant as Dictionary).get("escort_runtime_states", null)
    return states_variant is Dictionary and not (states_variant as Dictionary).is_empty()


func _activate_current_primary_escort_runtime_if_needed() -> Dictionary:
    if _profile == null or tower_floor_session_host == null or not is_tower_floor_active():
        return {"accepted": false, "reason_id": &"escort_activation_context_unavailable"}
    var floor_id := tower_floor_session_host.active_floor_id
    var quest_id := _primary_quest_id_for_floor(floor_id)
    var definition := QuestCatalog.get_definition(quest_id)
    if definition == null or definition.family != QuestDefinition.FAMILY_ESCORT:
        return {
            "accepted": true,
            "reason_id": &"floor_primary_is_not_escort",
            "floor_id": floor_id,
            "quest_id": quest_id,
            "activated": false,
        }
    var raw_entry: Variant = _profile.quest_progress.get(String(quest_id), null)
    if not raw_entry is Dictionary or StringName(String((raw_entry as Dictionary).get("state", &""))) != QuestProgressState.STATE_ACTIVE:
        return {
            "accepted": true,
            "reason_id": &"escort_primary_not_active",
            "floor_id": floor_id,
            "quest_id": quest_id,
            "activated": false,
        }
    if tower_floor_session_host.get_escort_runtime(quest_id) != null:
        return {
            "accepted": true,
            "reason_id": &"escort_already_active",
            "floor_id": floor_id,
            "quest_id": quest_id,
            "activated": false,
        }
    if _saved_safe_state_has_escort_runtime_for_floor(floor_id):
        return {
            "accepted": true,
            "reason_id": &"escort_restore_pending",
            "floor_id": floor_id,
            "quest_id": quest_id,
            "activated": false,
        }
    var floor_state := _load_current_floor_state(floor_id)
    if floor_state == null:
        return {
            "accepted": false,
            "reason_id": &"escort_floor_state_invalid",
            "floor_id": floor_id,
            "quest_id": quest_id,
        }
    var result := tower_floor_session_host.activate_escort(_profile, floor_state, quest_id)
    result["floor_id"] = floor_id
    result["quest_id"] = quest_id
    result["activated"] = bool(result.get("accepted", false))
    return result


func activate_committed_tower_travel(commit_result: Dictionary) -> bool:
    if not bool(commit_result.get("accepted", false)):
        return false
    tower_encounter_session_host.end_all_encounters()
    var runtime_root := commit_result.get("runtime_root") as Node2D
    var arrival_variant: Variant = commit_result.get("arrival", null)
    if runtime_root == null or not arrival_variant is Dictionary:
        return false

    var suspended_region := false
    var region_return_position := Vector2.INF
    if is_region3_active():
        region_return_position = region3_town_session_host.to_local(player.global_position)
        suspended_region = region3_town_session_host.suspend()
        if not suspended_region:
            return false
    _set_foundation_world_enabled(false)
    if not tower_floor_session_host.activate(runtime_root, arrival_variant as Dictionary, player, player.camera):
        if suspended_region:
            region3_town_session_host.resume(player, player.camera, region_return_position)
        else:
            _set_foundation_world_enabled(true)
            player.camera.set_world_bounds(Rect2(Vector2.ZERO, Vector2(world_canvas_size)))
        queue_redraw()
        return false
    _region3_suspended_for_tower = suspended_region
    _region3_return_position = region_return_position if suspended_region else Vector2.INF
    _record_tower_room_discovery(StringName(String((arrival_variant as Dictionary).get("room_instance_id", &""))))
    _bind_tower_room_triggers(runtime_root)
    _sync_tower_player_drop_pickups()
    last_tower_escort_activation_result = _activate_current_primary_escort_runtime_if_needed()
    if not bool(last_tower_escort_activation_result.get("accepted", false)):
        tower_floor_session_host.clear_active_floor()
        if suspended_region:
            region3_town_session_host.resume(player, player.camera, region_return_position)
        else:
            _set_foundation_world_enabled(true)
            player.camera.set_world_bounds(Rect2(Vector2.ZERO, Vector2(world_canvas_size)))
        _region3_suspended_for_tower = false
        _region3_return_position = Vector2.INF
        queue_redraw()
        return false
    queue_redraw()
    return true

func clear_tower_floor_session(return_position: Vector2) -> void:
    _cleanup_floor10_boss_encounter(true)
    _tower_player_drop_pickups.clear()
    _clear_player_combat_bindings()
    tower_encounter_session_host.end_all_encounters()
    _sync_operation_guard_with_active_combat()
    tower_floor_session_host.clear_active_floor()

    if _region3_suspended_for_tower and region3_town_session_host.has_loaded_region():
        var resume_position := _region3_return_position
        if not region3_town_session_host.resume(player, player.camera, resume_position):
            _clear_region3_runtime_to_foundation()
            player.global_position = return_position
        else:
            _set_foundation_world_enabled(false)
        _region3_suspended_for_tower = false
        _region3_return_position = Vector2.INF
        queue_redraw()
        return

    _set_foundation_world_enabled(true)
    player.global_position = return_position
    player.velocity = Vector2.ZERO
    player.camera.set_world_bounds(Rect2(Vector2.ZERO, Vector2(world_canvas_size)))
    player.camera.reset_after_teleport()
    queue_redraw()

func is_tower_floor_active() -> bool:
    return tower_floor_session_host != null and tower_floor_session_host.has_active_floor()

func activate_tower_encounter(
    plan: Dictionary,
    encounter_id: StringName,
    player_state: CombatantRuntimeState,
    enemy_states: Dictionary,
    quest_bindings_by_actor: Dictionary = {}
) -> Dictionary:
    if _profile == null or not is_tower_floor_active():
        return {"accepted": false, "reason_id": &"tower_floor_not_active"}
    var floor_id := tower_floor_session_host.active_floor_id
    var raw_floor: Variant = _profile.tower_floor_states.get(str(floor_id), null)
    if not raw_floor is Dictionary:
        return {"accepted": false, "reason_id": &"floor_instance_missing"}
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(raw_floor as Dictionary).is_empty() or floor_state.floor_id != floor_id:
        return {"accepted": false, "reason_id": &"floor_instance_invalid"}
    if not _player_combat_bindings.is_empty():
        if not _sync_overlapping_player_status_states():
            return {"accepted": false, "reason_id": &"player_status_state_sync_failed"}
        var live_status_restore := player_state.restore_status_states(_first_live_player_status_states())
        if not bool(live_status_restore.get("accepted", false)):
            return {"accepted": false, "reason_id": &"player_status_state_restore_failed"}

    var result := tower_encounter_session_host.activate_encounter(
        _profile,
        floor_state,
        plan,
        encounter_id,
        player_state,
        enemy_states,
        ENEMY_VISUAL_SCENE_CATALOG,
        quest_bindings_by_actor
    )
    if bool(result.get("accepted", false)) and not bool(result.get("resolved", false)):
        var encounter := tower_encounter_session_host.get_encounter_runtime(encounter_id)
        var binding := PlayerCombatantRuntimeBinding.new()
        if encounter == null or not binding.bind(player, encounter, player_state):
            tower_encounter_session_host.end_encounter(encounter_id)
            _sync_operation_guard_with_active_combat()
            return {"accepted": false, "reason_id": &"player_runtime_binding_failed"}
        binding.live_player_defeated.connect(_on_live_player_defeated.bind(encounter_id))
        _player_combat_bindings[encounter_id] = binding
        if not _sync_overlapping_player_status_states():
            _release_player_combat_binding(encounter_id)
            tower_encounter_session_host.end_encounter(encounter_id)
            _sync_operation_guard_with_active_combat()
            return {"accepted": false, "reason_id": &"player_status_state_sync_failed"}
        if _player_combat_bindings.size() == 1:
            player.bind_combat_runtime(encounter, player_state.actor_id)
    _sync_operation_guard_with_active_combat()
    return result

func _bind_tower_room_triggers(root: Node) -> void:
    if root == null:
        return
    var pending: Array[Node] = [root]
    while not pending.is_empty():
        var current: Node = pending.pop_back() as Node
        if current.get_script() == TOWER_ROOM_DISCOVERY_TRIGGER_SCRIPT:
            var discovery_callable := Callable(self, "_on_tower_room_discovered")
            if not current.is_connected(&"player_entered", discovery_callable):
                current.connect(&"player_entered", discovery_callable)
        if current is TowerEncounterRoomTrigger:
            var encounter_trigger := current as TowerEncounterRoomTrigger
            if not encounter_trigger.player_entered.is_connected(_on_tower_encounter_room_entered):
                encounter_trigger.player_entered.connect(_on_tower_encounter_room_entered)
        for child: Node in current.get_children():
            pending.append(child)

func _sync_region3_player_drop_pickups(require_exit_source_id: StringName = &"") -> bool:
    if _profile == null or not is_region3_active():
        return false
    var layout := region3_town_session_host.active_runtime_root
    if layout == null or not is_instance_valid(layout):
        return false
    if not Region3SubzoneDiscoveryService.validate_state_dictionary(_profile.region_state).is_empty():
        return false
    if StringName(String(_profile.region_state.get("map_revision_id", &""))) != layout.map_revision_id:
        return false
    if not Region3SubzoneDiscoveryService.validate_loose_positions_for_layout(_profile.region_state, layout).is_empty():
        return false

    var container := layout.get_node_or_null("PlayerDrops") as Node2D
    if container == null:
        container = Node2D.new()
        container.name = "PlayerDrops"
        layout.add_child(container)

    var loose_items := _profile.region_state.get("loose_items", {}) as Dictionary
    var valid_sources: Dictionary = {}
    for raw_source_id: Variant in loose_items.keys():
        var source_id := StringName(String(raw_source_id))
        var raw_entry: Variant = loose_items.get(String(source_id), null)
        if not bool(PLAYER_DROP_STATE_VALIDATOR_SCRIPT.should_validate_entry(raw_source_id, raw_entry)):
            continue
        if not (PLAYER_DROP_STATE_VALIDATOR_SCRIPT.validate_entry(raw_entry, source_id) as PackedStringArray).is_empty():
            continue
        valid_sources[String(source_id)] = true
        var existing: Variant = _region3_player_drop_pickups.get(String(source_id), null)
        if existing is Area2D and is_instance_valid(existing as Area2D):
            continue
        var entry := raw_entry as Dictionary
        var item := entry.get("item", {}) as Dictionary
        var position_data := entry.get("world_position", {}) as Dictionary
        var pickup := REGION3_PLAYER_DROP_PICKUP_SCENE.instantiate() as Area2D
        if pickup == null:
            continue
        var configured := bool(pickup.call(
            "configure",
            source_id,
            StringName(String(item.get("item_instance_id", &""))),
            StringName(String(item.get("definition_id", &""))),
            int(item.get("quantity", 0)),
            Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0))),
            source_id == require_exit_source_id
        ))
        if not configured:
            pickup.free()
            continue
        container.add_child(pickup)
        pickup.connect(&"pickup_requested", Callable(self, "_on_region3_player_drop_pickup_requested"))
        _region3_player_drop_pickups[String(source_id)] = pickup

    for raw_source_id: Variant in _region3_player_drop_pickups.keys():
        var source_text := String(raw_source_id)
        var pickup_variant: Variant = _region3_player_drop_pickups.get(source_text, null)
        if valid_sources.has(source_text) and pickup_variant is Area2D and is_instance_valid(pickup_variant as Area2D):
            continue
        if pickup_variant is Area2D and is_instance_valid(pickup_variant as Area2D):
            (pickup_variant as Area2D).queue_free()
        _region3_player_drop_pickups.erase(source_text)

    if require_exit_source_id == &"":
        return true
    var fresh_pickup: Variant = _region3_player_drop_pickups.get(String(require_exit_source_id), null)
    return fresh_pickup is Area2D and is_instance_valid(fresh_pickup as Area2D)

func _on_region3_player_drop_pickup_requested(source_id: StringName, pickup: Area2D) -> void:
    if _profile == null or not is_region3_active() or pickup == null:
        if pickup != null and is_instance_valid(pickup):
            pickup.call("resolve_pickup_attempt", false)
        return
    var layout := region3_town_session_host.active_runtime_root
    if layout == null:
        pickup.call("resolve_pickup_attempt", false)
        return
    var transaction_id := _next_inventory_pickup_transaction_id(source_id)
    if transaction_id == &"":
        pickup.call("resolve_pickup_attempt", false)
        return
    var result: Dictionary = REGION3_INVENTORY_DROP_TRANSACTION_SERVICE_SCRIPT.collect_player_drop(
        _profile,
        layout,
        source_id,
        transaction_id
    )
    result["durable"] = false
    result["world_kind"] = &"region3"
    if bool(result.get("accepted", false)):
        result["durability_boundary"] = &"next_safe_snapshot"
        _region3_player_drop_pickups.erase(String(source_id))
        if inventory_menu != null:
            inventory_menu.call("set_profile", _profile)
    last_region3_player_drop_result = result.duplicate(true)
    pickup.call("resolve_pickup_attempt", bool(result.get("accepted", false)))

func _sync_tower_player_drop_pickups(require_exit_source_id: StringName = &"") -> bool:
    if _profile == null or not is_tower_floor_active():
        return false
    var floor_id := tower_floor_session_host.active_floor_id
    var raw_floor: Variant = _profile.tower_floor_states.get(str(floor_id), null)
    if not raw_floor is Dictionary:
        return false
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(raw_floor as Dictionary).is_empty() or floor_state.floor_id != floor_id:
        return false
    var runtime_root := tower_floor_session_host.active_runtime_root
    if runtime_root == null or not is_instance_valid(runtime_root):
        return false

    var container := runtime_root.get_node_or_null("PlayerDrops") as Node2D
    if container == null:
        container = Node2D.new()
        container.name = "PlayerDrops"
        runtime_root.add_child(container)

    var valid_sources: Dictionary = {}
    for raw_source_id: Variant in floor_state.loose_items.keys():
        var source_id := StringName(String(raw_source_id))
        var raw_entry: Variant = floor_state.loose_items.get(String(source_id), null)
        if not bool(PLAYER_DROP_STATE_VALIDATOR_SCRIPT.should_validate_entry(raw_source_id, raw_entry)):
            continue
        if not (PLAYER_DROP_STATE_VALIDATOR_SCRIPT.validate_entry(raw_entry, source_id) as PackedStringArray).is_empty():
            continue
        valid_sources[String(source_id)] = true
        var existing: Variant = _tower_player_drop_pickups.get(String(source_id), null)
        if existing is Area2D and is_instance_valid(existing as Area2D):
            continue
        var entry := raw_entry as Dictionary
        var item := entry.get("item", {}) as Dictionary
        var position_data := entry.get("world_position", {}) as Dictionary
        var pickup := TOWER_PLAYER_DROP_PICKUP_SCENE.instantiate() as Area2D
        if pickup == null:
            continue
        var configured := bool(pickup.call(
            "configure",
            source_id,
            StringName(String(item.get("item_instance_id", &""))),
            StringName(String(item.get("definition_id", &""))),
            int(item.get("quantity", 0)),
            Vector2(float(position_data.get("x", 0.0)), float(position_data.get("y", 0.0))),
            source_id == require_exit_source_id
        ))
        if not configured:
            pickup.free()
            continue
        container.add_child(pickup)
        pickup.connect(&"pickup_requested", Callable(self, "_on_tower_player_drop_pickup_requested"))
        _tower_player_drop_pickups[String(source_id)] = pickup

    for raw_source_id: Variant in _tower_player_drop_pickups.keys():
        var source_text := String(raw_source_id)
        var pickup_variant: Variant = _tower_player_drop_pickups.get(source_text, null)
        if valid_sources.has(source_text) and pickup_variant is Area2D and is_instance_valid(pickup_variant as Area2D):
            continue
        if pickup_variant is Area2D and is_instance_valid(pickup_variant as Area2D):
            (pickup_variant as Area2D).queue_free()
        _tower_player_drop_pickups.erase(source_text)

    if require_exit_source_id == &"":
        return true
    var fresh_pickup: Variant = _tower_player_drop_pickups.get(String(require_exit_source_id), null)
    return fresh_pickup is Area2D and is_instance_valid(fresh_pickup as Area2D)

func _on_tower_player_drop_pickup_requested(source_id: StringName, pickup: Area2D) -> void:
    if _profile == null or not is_tower_floor_active() or pickup == null:
        if pickup != null and is_instance_valid(pickup):
            pickup.call("resolve_pickup_attempt", false)
        return
    var transaction_id := _next_inventory_pickup_transaction_id(source_id)
    if transaction_id == &"":
        pickup.call("resolve_pickup_attempt", false)
        return
    var result: Dictionary = INVENTORY_DROP_TRANSACTION_SERVICE_SCRIPT.collect_player_drop(
        _profile,
        tower_floor_session_host.active_floor_id,
        source_id,
        transaction_id
    )
    result["durable"] = false
    if bool(result.get("accepted", false)):
        result["durability_boundary"] = &"next_safe_snapshot"
        _tower_player_drop_pickups.erase(String(source_id))
        if inventory_menu != null:
            inventory_menu.call("set_profile", _profile)
    last_tower_player_drop_result = result.duplicate(true)
    pickup.call("resolve_pickup_attempt", bool(result.get("accepted", false)))

func _on_tower_room_discovered(room_instance_id: StringName) -> void:
    _record_tower_room_discovery(room_instance_id)
    last_floor10_preboss_checkpoint_result = _commit_floor10_preboss_checkpoint_if_reached(room_instance_id)
    if _is_current_floor_exit_room(room_instance_id):
        last_tower_primary_exit_result = _commit_completed_primary_exit(room_instance_id)

func _record_tower_room_discovery(room_instance_id: StringName) -> Dictionary:
    if _profile == null or not is_tower_floor_active():
        last_tower_room_discovery_result = {
            "accepted": false,
            "reason_id": &"tower_floor_not_active",
            "changed": false,
            "room_instance_id": room_instance_id,
        }
        return last_tower_room_discovery_result.duplicate(true)
    last_tower_room_discovery_result = TOWER_FLOOR_DISCOVERY_SERVICE_SCRIPT.mark_room_discovered(
        _profile,
        tower_floor_session_host.active_floor_id,
        room_instance_id
    )
    return last_tower_room_discovery_result.duplicate(true)


func _commit_floor10_preboss_checkpoint_if_reached(room_instance_id: StringName) -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if (
        _profile == null
        or _save_service == null
        or _slot_index < 1
        or not is_tower_floor_active()
        or tower_floor_session_host.active_floor_id != 10
        or not StableId.is_valid(String(room_instance_id))
    ):
        return {"attempted": false, "accepted": false, "reason_id": &"not_floor10_preboss_context"}
    if shared_active_combat.is_active():
        return {"attempted": true, "accepted": false, "reason_id": GameplayOperationGuard.REASON_ACTIVE_COMBAT}

    var floor_state := _load_current_floor_state(10)
    if floor_state == null:
        return {"attempted": true, "accepted": false, "reason_id": &"floor_instance_invalid"}
    var checkpoint_id: StringName = &"checkpoint:floor10_preboss"
    var anchor := floor_state.get_checkpoint_anchor(checkpoint_id)
    if anchor.is_empty() or StringName(String(anchor.get("room_instance_id", &""))) != room_instance_id:
        return {"attempted": false, "accepted": false, "reason_id": &"room_is_not_preboss_checkpoint"}
    var resolved := TowerArrivalResolver.resolve_checkpoint(floor_state, checkpoint_id)
    if not bool(resolved.get("accepted", false)) or StringName(String(resolved.get("room_instance_id", &""))) != room_instance_id:
        return {"attempted": true, "accepted": false, "reason_id": &"preboss_checkpoint_invalid"}
    if (
        int(_profile.safe_state.get("floor_id", 0)) == 10
        and StringName(String(_profile.safe_state.get("checkpoint_anchor_id", &""))) == checkpoint_id
    ):
        return {"attempted": true, "accepted": true, "reason_id": &"already_committed", "changed": false}
    if not _tower_position_is_authored_traversable(floor_state, player.global_position):
        return {"attempted": true, "accepted": false, "reason_id": &"preboss_player_position_invalid"}

    var safe_state := SafeCheckpointState.make(
        &"safe:tower_floor_10_preboss",
        &"tower:floor_10",
        10,
        checkpoint_id,
        _capture_player_safe_state(),
        _capture_quest_attempt_state(),
        _next_safe_snapshot_sequence()
    )
    if safe_state.is_empty():
        return {"attempted": true, "accepted": false, "reason_id": &"preboss_safe_state_invalid"}
    var save_error := SafeCheckpointCommitService.commit_checkpoint(_save_service, _slot_index, _profile, safe_state)
    return {
        "attempted": true,
        "accepted": save_error == OK,
        "reason_id": &"" if save_error == OK else &"preboss_save_failed",
        "changed": save_error == OK,
        "save_error": save_error,
        "checkpoint_anchor_id": checkpoint_id,
        "room_instance_id": room_instance_id,
    }


func _is_current_floor_exit_room(room_instance_id: StringName) -> bool:
    if _profile == null or not is_tower_floor_active() or not StableId.is_valid(String(room_instance_id)):
        return false
    var raw_floor: Variant = _profile.tower_floor_states.get(str(tower_floor_session_host.active_floor_id), null)
    if not raw_floor is Dictionary:
        return false
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(raw_floor as Dictionary).is_empty():
        return false
    return StringName(String(floor_state.layout_manifest.get("exit_room_id", &""))) == room_instance_id


func _commit_completed_primary_exit(exit_room_id: StringName) -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if (
        _profile == null
        or _save_service == null
        or _slot_index < 1
        or not is_tower_floor_active()
        or shared_active_combat.is_active()
        or not StableId.is_valid(String(exit_room_id))
    ):
        return {"accepted": false, "reason_id": &"tower_exit_context_unavailable", "durable": false}
    var floor_id := tower_floor_session_host.active_floor_id
    var quest_id := _primary_quest_id_for_floor(floor_id)
    if quest_id == &"":
        return {"accepted": false, "reason_id": &"primary_quest_missing", "floor_id": floor_id, "durable": false}
    var raw_entry: Variant = _profile.quest_progress.get(String(quest_id), null)
    if not raw_entry is Dictionary:
        return {"accepted": false, "reason_id": &"primary_quest_not_active", "floor_id": floor_id, "quest_id": quest_id, "durable": false}
    var entry := raw_entry as Dictionary
    if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_OBJECTIVES_COMPLETE:
        return {"accepted": false, "reason_id": &"objectives_not_complete", "floor_id": floor_id, "quest_id": quest_id, "durable": false}
    if StringName(String(entry.get("stage_id", &""))) != &"floor_objective":
        return {"accepted": false, "reason_id": &"wrong_stage", "floor_id": floor_id, "quest_id": quest_id, "durable": false}

    var floor_key := str(floor_id)
    var raw_floor: Variant = _profile.tower_floor_states.get(floor_key, null)
    if not raw_floor is Dictionary:
        return {"accepted": false, "reason_id": &"floor_instance_missing", "floor_id": floor_id, "quest_id": quest_id, "durable": false}
    var original_floor := (raw_floor as Dictionary).duplicate(true)
    var staged_floor := FloorInstanceState.new()
    if not staged_floor.load_dictionary(original_floor).is_empty() or staged_floor.floor_id != floor_id:
        return {"accepted": false, "reason_id": &"floor_instance_invalid", "floor_id": floor_id, "quest_id": quest_id, "durable": false}
    if StringName(String(staged_floor.layout_manifest.get("exit_room_id", &""))) != exit_room_id:
        return {"accepted": false, "reason_id": &"exit_room_mismatch", "floor_id": floor_id, "quest_id": quest_id, "durable": false}

    if staged_floor.get_checkpoint_anchor(exit_room_id).is_empty():
        var exit_room := _tower_manifest_room(staged_floor.layout_manifest, exit_room_id)
        if exit_room.is_empty():
            return {"accepted": false, "reason_id": &"exit_room_missing", "floor_id": floor_id, "quest_id": quest_id, "durable": false}
        var module := TowerPrototypeModuleCatalog.get_definition(StringName(String(exit_room.get("module_id", &""))))
        if module == null or module.arrival_candidates.is_empty():
            return {"accepted": false, "reason_id": &"exit_safe_anchor_unavailable", "floor_id": floor_id, "quest_id": quest_id, "durable": false}
        var local_tile := module.arrival_candidates[0]
        if not staged_floor.add_checkpoint_anchor(exit_room_id, exit_room_id, local_tile):
            return {"accepted": false, "reason_id": &"exit_checkpoint_registration_failed", "floor_id": floor_id, "quest_id": quest_id, "durable": false}
    var resolved_exit := TowerArrivalResolver.resolve_checkpoint(staged_floor, exit_room_id)
    if not bool(resolved_exit.get("accepted", false)):
        return {
            "accepted": false,
            "reason_id": &"exit_safe_anchor_invalid",
            "arrival_reason_id": StringName(resolved_exit.get("reason_id", &"")),
            "floor_id": floor_id,
            "quest_id": quest_id,
            "durable": false,
        }

    var snapshot_sequence := _next_safe_snapshot_sequence()
    if not PrimaryFloorExitCommitProof.mark_committed_exit(staged_floor, quest_id, exit_room_id, snapshot_sequence):
        return {"accepted": false, "reason_id": &"exit_commit_proof_invalid", "floor_id": floor_id, "quest_id": quest_id, "durable": false}
    _profile.tower_floor_states[floor_key] = staged_floor.to_dictionary()
    var safe_state := SafeCheckpointState.make(
        StringName("safe:tower_floor_%d_exit" % floor_id),
        StringName("tower:floor_%d" % floor_id),
        floor_id,
        exit_room_id,
        _capture_player_safe_state(),
        _capture_quest_attempt_state(),
        snapshot_sequence
    )
    if safe_state.is_empty():
        _profile.tower_floor_states[floor_key] = original_floor
        return {"accepted": false, "reason_id": &"exit_safe_state_invalid", "floor_id": floor_id, "quest_id": quest_id, "durable": false}
    var save_error := SafeCheckpointCommitService.commit_checkpoint(_save_service, _slot_index, _profile, safe_state)
    if save_error != OK:
        _profile.tower_floor_states[floor_key] = original_floor
        return {
            "accepted": false,
            "reason_id": &"exit_safe_commit_failed",
            "save_error": save_error,
            "floor_id": floor_id,
            "quest_id": quest_id,
            "durable": false,
        }

    call_deferred(&"_complete_primary_exit_return")
    return {
        "accepted": true,
        "reason_id": &"",
        "save_error": OK,
        "floor_id": floor_id,
        "quest_id": quest_id,
        "checkpoint_anchor_id": exit_room_id,
        "safe_state": safe_state.duplicate(true),
        "durable": true,
        "return_to_region3_pending": _region3_suspended_for_tower,
    }


func _complete_primary_exit_return() -> void:
    if is_tower_floor_active():
        clear_tower_floor_session(Vector2.ZERO)
    if is_region3_active():
        last_region3_hub_autosave_result = _request_current_safe_autosave()


func _tower_manifest_room(manifest: Dictionary, room_instance_id: StringName) -> Dictionary:
    for raw_room: Variant in manifest.get("rooms", []) as Array:
        if raw_room is Dictionary and StringName(String((raw_room as Dictionary).get("room_instance_id", &""))) == room_instance_id:
            return (raw_room as Dictionary).duplicate(true)
    return {}

func _on_tower_encounter_room_entered(room_instance_id: StringName) -> void:
    if _is_current_floor10_boss_room(room_instance_id):
        last_tower_encounter_trigger_result = _activate_floor10_boss_encounter(room_instance_id)
        return
    var context := _prepare_current_floor_prototype_encounters()
    if not bool(context.get("accepted", false)):
        last_tower_encounter_trigger_result = context.duplicate(true)
        return
    var plan := context.get("plan", {}) as Dictionary
    for raw_encounter_id: Variant in context.get("encounter_ids", []) as Array:
        var encounter_id := StringName(String(raw_encounter_id))
        for placement: Dictionary in TowerEncounterPlanValidator.placements_for_encounter(plan, encounter_id):
            if StringName(String(placement.get("room_instance_id", &""))) != room_instance_id:
                continue
            if tower_encounter_session_host.is_encounter_active(encounter_id):
                last_tower_encounter_trigger_result = {
                    "accepted": true,
                    "reason_id": &"encounter_already_active",
                    "encounter_id": encounter_id,
                    "room_instance_id": room_instance_id,
                    "content_status": StringName(plan.get("content_status", &"")),
                }
                return
            last_tower_encounter_trigger_result = activate_current_floor_prototype_encounter(encounter_id)
            last_tower_encounter_trigger_result["room_instance_id"] = room_instance_id
            return
    last_tower_encounter_trigger_result = {
        "accepted": true,
        "reason_id": &"room_has_no_prototype_encounter",
        "encounter_id": &"",
        "room_instance_id": room_instance_id,
    }


func set_floor10_boss_defender_facts_provider(provider: Callable) -> bool:
    if _floor10_boss_sanctum != null:
        return false
    if provider.is_null() or not provider.is_valid():
        return false
    _floor10_default_defender_facts_provider = null
    _floor10_boss_defender_facts_provider = provider
    return true


func clear_floor10_boss_defender_facts_provider() -> bool:
    if _floor10_boss_sanctum != null:
        return false
    _floor10_boss_defender_facts_provider = Callable()
    _floor10_default_defender_facts_provider = null
    return true


func get_floor10_boss_production_status() -> Dictionary:
    var authoring := _floor10_boss_authoring_readiness()
    var defender_facts := _floor10_boss_defender_facts_readiness(false)
    var authoring_ready := bool(authoring.get("accepted", false))
    var defender_facts_ready := bool(defender_facts.get("accepted", false))
    var placeholder_tuning := (
        (tenth_warden_production_authoring != null and tenth_warden_production_authoring.playtest_placeholder)
        or (player_defender_facts_tuning != null and player_defender_facts_tuning.playtest_placeholder)
    )
    return {
        "production_ready": authoring_ready and defender_facts_ready,
        "playtest_placeholder": placeholder_tuning,
        "authoring_ready": authoring_ready,
        "authoring_errors": (authoring.get("errors", PackedStringArray()) as PackedStringArray).duplicate(),
        "defender_facts_ready": defender_facts_ready,
        "defender_facts_errors": (defender_facts.get("errors", PackedStringArray()) as PackedStringArray).duplicate(),
        "boss_authoring_resource_assigned": tenth_warden_production_authoring != null,
        "player_defender_facts_tuning_assigned": player_defender_facts_tuning != null,
    }


func get_floor10_boss_runtime_snapshot() -> Dictionary:
    return {
        "active": _floor10_boss_sanctum != null and is_instance_valid(_floor10_boss_sanctum),
        "encounter_id": _floor10_boss_sanctum.encounter_id if _floor10_boss_sanctum != null and is_instance_valid(_floor10_boss_sanctum) else &"",
        "outcome": _floor10_boss_sanctum.committed_terminal_outcome if _floor10_boss_sanctum != null and is_instance_valid(_floor10_boss_sanctum) else TenthWardenEncounterState.OUTCOME_ONGOING,
        "contact_delivery": _floor10_boss_sanctum.live_contact_delivery.get_debug_snapshot() if _floor10_boss_sanctum != null and is_instance_valid(_floor10_boss_sanctum) and _floor10_boss_sanctum.live_contact_delivery != null else {},
        "progression_bound": _floor10_boss_progression_bridge != null and _floor10_boss_progression_bridge.is_bound(),
        "boss_music_override_active": _floor10_boss_music_override_active,
    }


func _activate_floor10_boss_encounter(room_instance_id: StringName) -> Dictionary:
    if _floor10_boss_sanctum != null and is_instance_valid(_floor10_boss_sanctum):
        return {
            "accepted": true,
            "reason_id": &"encounter_already_active" if _floor10_boss_sanctum.committed_terminal_outcome == TenthWardenEncounterState.OUTCOME_ONGOING else &"encounter_already_resolved",
            "encounter_id": _floor10_boss_sanctum.encounter_id,
            "room_instance_id": room_instance_id,
            "floor_id": 10,
            "runtime_driver_ready": _floor10_boss_sanctum.live_contact_delivery != null,
            "progression_bound": _floor10_boss_progression_bridge != null and _floor10_boss_progression_bridge.is_bound(),
            "boss_music_available": _floor10_boss_music_override_active,
        }

    var readiness := _floor10_boss_authoring_readiness()
    if not bool(readiness.get("accepted", false)):
        return {
            "accepted": false,
            "reason_id": REASON_FLOOR10_BOSS_RUNTIME_NOT_READY,
            "encounter_id": &"",
            "room_instance_id": room_instance_id,
            "floor_id": 10,
            "authoring_ready": false,
            "authoring_errors": (readiness.get("errors", PackedStringArray()) as PackedStringArray).duplicate(),
            "runtime_driver_ready": false,
            "boss_music_available": false,
        }

    var objective_readiness := _floor10_boss_objective_readiness()
    if not bool(objective_readiness.get("accepted", false)):
        return {
            "accepted": false,
            "reason_id": REASON_FLOOR10_BOSS_OBJECTIVE_NOT_ACTIVE,
            "objective_reason_id": StringName(String(objective_readiness.get("reason_id", &""))),
            "encounter_id": &"",
            "room_instance_id": room_instance_id,
            "floor_id": 10,
            "authoring_ready": true,
            "authoring_errors": PackedStringArray(),
            "runtime_driver_ready": false,
            "boss_music_available": false,
        }
    var defender_facts_readiness := _floor10_boss_defender_facts_readiness()
    if not bool(defender_facts_readiness.get("accepted", false)):
        return {
            "accepted": false,
            "reason_id": REASON_FLOOR10_BOSS_CONTACT_OWNER_NOT_READY,
            "encounter_id": &"",
            "room_instance_id": room_instance_id,
            "floor_id": 10,
            "authoring_ready": true,
            "authoring_errors": PackedStringArray(),
            "defender_facts_errors": (defender_facts_readiness.get("errors", PackedStringArray()) as PackedStringArray).duplicate(),
            "runtime_driver_ready": false,
            "boss_music_available": false,
        }
    if tower_encounter_session_host.get_active_encounter_count() > 0 or not _player_combat_bindings.is_empty():
        return {
            "accepted": false,
            "reason_id": REASON_FLOOR10_BOSS_ENCOUNTER_CONFLICT,
            "encounter_id": &"",
            "room_instance_id": room_instance_id,
            "floor_id": 10,
            "authoring_ready": true,
            "authoring_errors": PackedStringArray(),
            "runtime_driver_ready": true,
            "boss_music_available": false,
        }

    var raw_floor: Variant = _profile.tower_floor_states.get("10", null)
    if not raw_floor is Dictionary:
        return {"accepted": false, "reason_id": REASON_FLOOR10_BOSS_RUNTIME_PREPARE_FAILED, "runtime_reason_id": &"floor10_instance_missing"}
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(raw_floor as Dictionary).is_empty():
        return {"accepted": false, "reason_id": REASON_FLOOR10_BOSS_RUNTIME_PREPARE_FAILED, "runtime_reason_id": &"floor10_instance_invalid"}
    var room := _tower_manifest_room(floor_state.layout_manifest, room_instance_id)
    var rect_variant: Variant = room.get("rect", null)
    if typeof(rect_variant) != TYPE_RECT2I or tower_floor_session_host.active_runtime_root == null:
        return {"accepted": false, "reason_id": REASON_FLOOR10_BOSS_RUNTIME_PREPARE_FAILED, "runtime_reason_id": &"boss_room_runtime_geometry_unavailable"}

    var player_state := PlayerCombatantRuntimeBinding.create_state(
        player,
        combat_runtime,
        PLAYER_COMBAT_RUNTIME_TUNING,
        &"player:local"
    )
    if player_state == null:
        return {"accepted": false, "reason_id": REASON_FLOOR10_BOSS_RUNTIME_PREPARE_FAILED, "runtime_reason_id": &"player_runtime_state_failed"}

    var sanctum := TENTH_WARDEN_SANCTUM_SCENE.instantiate() as TenthWardenSanctum
    if sanctum == null:
        return {"accepted": false, "reason_id": REASON_FLOOR10_BOSS_RUNTIME_PREPARE_FAILED, "runtime_reason_id": &"sanctum_scene_failed"}
    sanctum.name = "TenthWardenProductionSanctum"
    var room_rect := rect_variant as Rect2i
    var room_center := (Vector2(room_rect.position) + Vector2(room_rect.size) * 0.5) * float(TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE)
    tower_floor_session_host.active_runtime_root.add_child(sanctum)
    sanctum.global_position = tower_floor_session_host.active_runtime_root.to_global(room_center)

    if not sanctum.prepare_production_encounter(
        player_state,
        tenth_warden_production_authoring,
        shared_active_combat,
        shared_full_ai,
        tower_encounter_session_host.shared_attack_pressure
    ):
        sanctum.queue_free()
        _sync_operation_guard_with_active_combat()
        return {"accepted": false, "reason_id": REASON_FLOOR10_BOSS_RUNTIME_PREPARE_FAILED, "runtime_reason_id": &"sanctum_prepare_rejected"}

    var binding := PlayerCombatantRuntimeBinding.new()
    if not binding.bind(player, sanctum.encounter_runtime, player_state):
        sanctum.end_encounter()
        sanctum.queue_free()
        _sync_operation_guard_with_active_combat()
        return {"accepted": false, "reason_id": REASON_FLOOR10_BOSS_PLAYER_BIND_FAILED}
    if not sanctum.bind_live_contact_delivery(
        player,
        combat_runtime,
        _floor10_boss_defender_facts_provider
    ):
        binding.unbind()
        sanctum.end_encounter()
        sanctum.queue_free()
        _sync_operation_guard_with_active_combat()
        return {"accepted": false, "reason_id": REASON_FLOOR10_BOSS_CONTACT_BIND_FAILED}

    var bridge := Floor10BossProgressionBridge.new()
    var bridge_result := bridge.bind(_profile, sanctum)
    if not bool(bridge_result.get("accepted", false)):
        binding.unbind()
        sanctum.end_encounter()
        sanctum.queue_free()
        _sync_operation_guard_with_active_combat()
        return {
            "accepted": false,
            "reason_id": REASON_FLOOR10_BOSS_PROGRESSION_BIND_FAILED,
            "runtime_reason_id": StringName(String(bridge_result.get("reason_id", &""))),
        }

    _floor10_boss_sanctum = sanctum
    _floor10_boss_progression_bridge = bridge
    bridge.progression_committed.connect(_on_floor10_boss_progression_committed)
    binding.live_player_defeated.connect(_on_live_player_defeated.bind(sanctum.encounter_id))
    _player_combat_bindings[sanctum.encounter_id] = binding
    if not player.bind_combat_runtime(sanctum.encounter_runtime, player_state.actor_id):
        _cleanup_floor10_boss_encounter(true)
        return {"accepted": false, "reason_id": REASON_FLOOR10_BOSS_PLAYER_BIND_FAILED}

    if sanctum.player_spawn != null:
        player.global_position = sanctum.player_spawn.global_position
        player.velocity = Vector2.ZERO
        player.camera.reset_after_teleport()

    _floor10_boss_music_override_active = _music_routing_ready and set_music_override_state(AudioMusicStateController.STATE_BOSS)
    _sync_operation_guard_with_active_combat()
    return {
        "accepted": true,
        "reason_id": &"",
        "encounter_id": sanctum.encounter_id,
        "room_instance_id": room_instance_id,
        "floor_id": 10,
        "authoring_ready": true,
        "authoring_errors": PackedStringArray(),
        "runtime_driver_ready": true,
        "progression_bound": bridge.is_bound(),
        "boss_music_available": _floor10_boss_music_override_active,
    }


func _floor10_boss_objective_readiness() -> Dictionary:
    if _profile == null:
        return {"accepted": false, "reason_id": &"profile_missing"}
    var raw_entry: Variant = _profile.quest_progress.get(String(Floor10PrimaryBossObjectiveService.QUEST_ID), null)
    if not raw_entry is Dictionary:
        return {"accepted": false, "reason_id": &"quest_missing"}
    var entry := raw_entry as Dictionary
    if StringName(String(entry.get("state", &""))) != QuestProgressState.STATE_ACTIVE:
        return {"accepted": false, "reason_id": &"quest_not_active"}
    if StringName(String(entry.get("stage_id", &""))) != &"floor_objective":
        return {"accepted": false, "reason_id": &"wrong_stage"}
    var raw_floor: Variant = _profile.tower_floor_states.get("10", null)
    if not raw_floor is Dictionary or not FloorInstanceState.validate_dictionary(raw_floor as Dictionary).is_empty():
        return {"accepted": false, "reason_id": &"floor10_instance_invalid"}
    if bool((raw_floor as Dictionary).get("boss_defeated", false)):
        return {"accepted": false, "reason_id": &"boss_already_defeated"}
    return {"accepted": true, "reason_id": &""}


func _on_floor10_boss_progression_committed(result: Dictionary) -> void:
    last_floor10_boss_progression_result = result.duplicate(true)
    if _floor10_boss_sanctum == null or not is_instance_valid(_floor10_boss_sanctum):
        return
    var encounter_id := _floor10_boss_sanctum.encounter_id
    var binding := _player_combat_bindings.get(encounter_id) as PlayerCombatantRuntimeBinding
    if binding != null and binding.is_bound() and StringName(String(result.get("outcome_id", &""))) == TenthWardenEncounterState.OUTCOME_VICTORY:
        binding.persist_status_safe_states(combat_runtime)
    _release_player_combat_binding(encounter_id)
    if _player_combat_bindings.is_empty():
        player.unbind_combat_runtime()
    if _floor10_boss_music_override_active:
        clear_music_override_state()
        _floor10_boss_music_override_active = false
    _sync_operation_guard_with_active_combat()


func _get_playtest_boss_for_player_delivery() -> TenthWardenSanctum:
    return _floor10_boss_sanctum if _floor10_boss_sanctum != null and is_instance_valid(_floor10_boss_sanctum) else null


func _cleanup_floor10_boss_encounter(remove_node: bool) -> void:
    if _floor10_boss_progression_bridge != null:
        _floor10_boss_progression_bridge.unbind()
        _floor10_boss_progression_bridge = null
    if _floor10_boss_sanctum != null and is_instance_valid(_floor10_boss_sanctum):
        var encounter_id := _floor10_boss_sanctum.encounter_id
        var binding := _player_combat_bindings.get(encounter_id) as PlayerCombatantRuntimeBinding
        if binding != null and binding.is_bound():
            binding.persist_status_safe_states(combat_runtime)
        _release_player_combat_binding(encounter_id)
        _floor10_boss_sanctum.end_encounter()
        if remove_node:
            _floor10_boss_sanctum.queue_free()
    _floor10_boss_sanctum = null
    if _player_combat_bindings.is_empty() and player != null:
        player.unbind_combat_runtime()
    if _floor10_boss_music_override_active:
        clear_music_override_state()
        _floor10_boss_music_override_active = false
    _sync_operation_guard_with_active_combat()


func _floor10_boss_authoring_readiness() -> Dictionary:
    if tenth_warden_production_authoring == null:
        return {
            "accepted": false,
            "errors": PackedStringArray(["Tenth Warden production combat authoring resource is not assigned"]),
        }
    var errors := tenth_warden_production_authoring.validate_authoring()
    return {
        "accepted": errors.is_empty(),
        "errors": errors.duplicate(),
    }


func _floor10_boss_defender_facts_readiness(assign_provider: bool = true) -> Dictionary:
    if not _floor10_boss_defender_facts_provider.is_null() and _floor10_boss_defender_facts_provider.is_valid():
        return {"accepted": true, "errors": PackedStringArray()}
    if player_defender_facts_tuning == null:
        return {
            "accepted": false,
            "errors": PackedStringArray(["player defender-facts tuning resource is not assigned"]),
        }
    var provider := PlayerDefenderFactsProvider.new()
    var errors := provider.configure(player, combat_runtime, player_defender_facts_tuning)
    if not errors.is_empty():
        return {"accepted": false, "errors": errors.duplicate()}
    provider.set_skill_evade_window_provider(
        Callable(player_playtest_attack_delivery, &"has_active_backstep_evade_window")
    )
    if assign_provider:
        _floor10_default_defender_facts_provider = provider
        _floor10_boss_defender_facts_provider = Callable(provider, &"make_snapshot")
    return {"accepted": true, "errors": PackedStringArray()}


func _is_current_floor10_boss_room(room_instance_id: StringName) -> bool:
    if _profile == null or not is_tower_floor_active() or tower_floor_session_host.active_floor_id != 10:
        return false
    var raw_floor: Variant = _profile.tower_floor_states.get("10", null)
    if not raw_floor is Dictionary:
        return false
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(raw_floor as Dictionary).is_empty():
        return false
    var room := _tower_manifest_room(floor_state.layout_manifest, room_instance_id)
    if room.is_empty():
        return false
    return (room.get("tags", []) as Array).has(TowerFloorLayoutManifestValidator.TAG_BOSS)

func get_current_floor_prototype_encounter_ids() -> Array[StringName]:
    var context := _prepare_current_floor_prototype_encounters()
    if not bool(context.get("accepted", false)):
        return []
    var result: Array[StringName] = []
    for raw_id: Variant in context.get("encounter_ids", []) as Array:
        result.append(StringName(String(raw_id)))
    return result

func activate_current_floor_prototype_encounter(encounter_id: StringName) -> Dictionary:
    if tower_encounter_session_host.is_encounter_active(encounter_id):
        return {"accepted": false, "reason_id": &"encounter_already_active", "encounter_id": encounter_id}
    var context := _prepare_current_floor_prototype_encounters()
    if not bool(context.get("accepted", false)):
        return context
    var encounter_ids := get_current_floor_prototype_encounter_ids()
    if not encounter_ids.has(encounter_id):
        return {"accepted": false, "reason_id": &"encounter_not_authored", "encounter_id": encounter_id}

    var quest_progress_before := _profile.quest_progress.duplicate(true)
    var plan_status := StringName(String((context.get("plan", {}) as Dictionary).get("content_status", &"")))
    var objective_bind := (
        TowerProductionEncounterPreparationService.bind_active_objectives(_profile, context.get("objective_configs", {}))
        if plan_status == TowerProductionEncounterContentCatalog.CONTENT_STATUS
        else TowerPrototypeEncounterPreparationService.bind_active_objectives(_profile, context.get("objective_configs", {}))
    )
    if not bool(objective_bind.get("accepted", false)):
        return objective_bind

    var player_state := PlayerCombatantRuntimeBinding.create_state(
        player,
        combat_runtime,
        PLAYER_COMBAT_RUNTIME_TUNING,
        &"player:local"
    )
    if player_state == null:
        _profile.quest_progress = quest_progress_before
        return {"accepted": false, "reason_id": &"player_runtime_state_failed", "encounter_id": encounter_id}
    var result := activate_tower_encounter(
        context.get("plan", {}) as Dictionary,
        encounter_id,
        player_state,
        context.get("enemy_states", {}) as Dictionary,
        context.get("quest_bindings_by_actor", {}) as Dictionary
    )
    if not bool(result.get("accepted", false)):
        _profile.quest_progress = quest_progress_before
        return result
    result["objective_binding"] = objective_bind.duplicate(true)
    result["content_status"] = StringName((context.get("plan", {}) as Dictionary).get("content_status", &""))
    return result

func _prepare_current_floor_prototype_encounters() -> Dictionary:
    if _profile == null or not is_tower_floor_active():
        return {"accepted": false, "reason_id": &"tower_floor_not_active"}
    var floor_id := tower_floor_session_host.active_floor_id
    var raw_floor: Variant = _profile.tower_floor_states.get(str(floor_id), null)
    if not raw_floor is Dictionary:
        return {"accepted": false, "reason_id": &"floor_instance_missing"}
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(raw_floor as Dictionary).is_empty() or floor_state.floor_id != floor_id:
        return {"accepted": false, "reason_id": &"floor_instance_invalid"}
    if floor_id >= 2:
        return TowerProductionEncounterPreparationService.prepare(
            _profile,
            floor_state,
            TOWER_PROTOTYPE_ENEMY_RUNTIME_TUNING
        )
    return TowerPrototypeEncounterPreparationService.prepare(
        _profile,
        floor_state,
        TOWER_PROTOTYPE_ENEMY_RUNTIME_TUNING
    )

func end_tower_encounter(encounter_id: StringName) -> bool:
    var binding := _player_combat_bindings.get(encounter_id) as PlayerCombatantRuntimeBinding
    if binding != null:
        if not _sync_overlapping_player_status_states():
            return false
        if _player_combat_bindings.size() == 1:
            if not binding.persist_status_safe_states(combat_runtime):
                return false
        elif (
            player.runtime_presentation_binder != null
            and player.runtime_presentation_binder.bound_runtime == binding.encounter
            and not _bind_player_presentation_to_surviving_encounter(encounter_id)
        ):
            return false
    _release_player_combat_binding(encounter_id)
    var ended := tower_encounter_session_host.end_encounter(encounter_id)
    if _player_combat_bindings.is_empty():
        player.unbind_combat_runtime()
    _sync_operation_guard_with_active_combat()
    return ended

func _on_live_player_defeated(actor_id: StringName, encounter_id: StringName) -> void:
    if death_retry_overlay != null and death_retry_overlay.is_open():
        return
    last_player_defeat_event = {
        "actor_id": actor_id,
        "encounter_id": encounter_id,
        "floor_id": tower_floor_session_host.active_floor_id if is_tower_floor_active() else 0,
    }
    _enter_death_retry_flow()
    player_defeat_detected.emit(last_player_defeat_event.duplicate(true))

func _enter_death_retry_flow() -> void:
    combat_runtime.cancel_defense()
    player.velocity = Vector2.ZERO
    tower_encounter_session_host.set_physics_process(false)
    var side_runtime := _region3_side_runtime()
    if side_runtime != null:
        side_runtime.set_physics_process(false)
    input_ownership.open_modal(DEATH_RETRY_MODAL_ID)
    if _death_guard_token == 0:
        _death_guard_token = operation_guard.acquire_blocker(
            &"death:retry_flow",
            GameplayOperationGuard.REASON_UNSUPPORTED_TRANSIENT_STATE,
            tr("Retry from the latest committed checkpoint before continuing."),
            [GameplayOperationGuard.OP_SIGIL_TRAVEL, GameplayOperationGuard.OP_MANUAL_SAVE, GameplayOperationGuard.OP_SERVICE]
        )
    death_retry_overlay.open_overlay(tr("Latest committed checkpoint will be restored."))

func _on_death_retry_requested() -> void:
    if death_retry_overlay == null or not death_retry_overlay.is_open():
        return
    death_retry_overlay.set_retry_pending(true)
    var result := retry_failed_attempt()
    if bool(result.get("accepted", false)):
        _exit_death_retry_flow()
        return
    death_retry_overlay.set_retry_pending(false)
    death_retry_overlay.set_status(tr("Retry unavailable: %s") % String(result.get("reason_id", &"unknown")))

func _exit_death_retry_flow() -> void:
    if death_retry_overlay != null:
        death_retry_overlay.close_overlay()
    input_ownership.close_modal(DEATH_RETRY_MODAL_ID)
    if _death_guard_token != 0:
        operation_guard.release_blocker(_death_guard_token)
        _death_guard_token = 0
    tower_encounter_session_host.set_physics_process(true)
    var side_runtime := _region3_side_runtime()
    if side_runtime != null:
        side_runtime.set_physics_process(true)
    last_player_defeat_event.clear()

func is_death_retry_open() -> bool:
    return death_retry_overlay != null and death_retry_overlay.is_open()

func _sync_overlapping_player_status_states() -> bool:
    if _player_combat_bindings.is_empty():
        return true
    var encounter_ids: Array = _player_combat_bindings.keys()
    encounter_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    var merged_states: Array = []
    for raw_encounter_id: Variant in encounter_ids:
        var binding := _player_combat_bindings.get(raw_encounter_id) as PlayerCombatantRuntimeBinding
        if binding == null or not binding.is_bound() or binding.state == null:
            return false
        for raw_state: Variant in binding.state.get_status_states():
            if not raw_state is Dictionary:
                return false
            var state := raw_state as Dictionary
            var merged := PrototypeStatusResolver.apply_status(merged_states, {
                "status_id": state.get("status_id", &""),
                "behavior": state.get("behavior", &""),
                "magnitude": state.get("magnitude", 0.0),
                "duration_ticks": state.get("remaining_ticks", 0),
            })
            if not bool(merged.get("accepted", false)):
                return false
            merged_states = (merged.get("states", []) as Array).duplicate(true)
    for raw_encounter_id: Variant in encounter_ids:
        var binding := _player_combat_bindings.get(raw_encounter_id) as PlayerCombatantRuntimeBinding
        var restored := binding.state.restore_status_states(merged_states)
        if not bool(restored.get("accepted", false)):
            return false
    return true


func _player_status_states_for_movement() -> Array:
    # Live encounter state owns current ticks; the class-safe snapshot owns
    # restored status when no encounter is bound. Never change action clocks.
    if not _player_combat_bindings.is_empty():
        return _first_live_player_status_states()
    if combat_runtime != null:
        return combat_runtime.get_status_safe_states()
    return []


func _first_live_player_status_states() -> Array:
    if _player_combat_bindings.is_empty():
        return []
    var encounter_ids: Array = _player_combat_bindings.keys()
    encounter_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    var binding := _player_combat_bindings.get(encounter_ids[0]) as PlayerCombatantRuntimeBinding
    if binding == null or not binding.is_bound() or binding.state == null:
        return []
    return binding.state.get_status_states()


func _bind_player_presentation_to_surviving_encounter(excluded_encounter_id: StringName) -> bool:
    var encounter_ids: Array = _player_combat_bindings.keys()
    encounter_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    for raw_encounter_id: Variant in encounter_ids:
        var candidate_id := StringName(String(raw_encounter_id))
        if candidate_id == excluded_encounter_id:
            continue
        var binding := _player_combat_bindings.get(raw_encounter_id) as PlayerCombatantRuntimeBinding
        if binding != null and binding.is_bound():
            return player.bind_combat_runtime(binding.encounter, binding.actor_id)
    return false


func _release_player_combat_binding(encounter_id: StringName) -> void:
    var binding := _player_combat_bindings.get(encounter_id) as PlayerCombatantRuntimeBinding
    if binding != null:
        binding.unbind()
    _player_combat_bindings.erase(encounter_id)

func _clear_player_combat_bindings() -> void:
    var encounter_ids: Array = _player_combat_bindings.keys()
    for raw_id: Variant in encounter_ids:
        _release_player_combat_binding(StringName(raw_id))
    player.unbind_combat_runtime()

func _configure_music_routing() -> void:
    _music_routing_ready = false
    _music_override_state = &""
    last_music_routing_errors = PackedStringArray()
    _music_state_controller.stop()
    if music_routing_definition == null:
        last_music_routing_errors.append("music routing definition is not assigned")
        return
    var audio_service: Node = get_node_or_null("/root/AudioService")
    if audio_service == null:
        last_music_routing_errors.append("AudioService autoload is unavailable")
        return
    var errors := music_routing_definition.validate_definition()
    if not errors.is_empty():
        last_music_routing_errors = errors.duplicate()
        return
    for definition: AudioEventDefinition in music_routing_definition.event_definitions():
        if bool(audio_service.call("has_event", definition.event_id)):
            var existing := audio_service.call("get_event_definition", definition.event_id) as AudioEventDefinition
            if existing != definition:
                last_music_routing_errors.append("registered music event conflicts with authored routing event: %s" % String(definition.event_id))
                return
        elif not bool(audio_service.call("register_event", definition)):
            last_music_routing_errors.append("could not register authored music event: %s" % String(definition.event_id))
            return
    var controller_errors := _music_state_controller.configure(
        audio_service,
        music_routing_definition.events_by_state(),
        music_routing_definition.fade_seconds,
        music_routing_definition.debounce_seconds
    )
    if not controller_errors.is_empty():
        last_music_routing_errors = controller_errors.duplicate()
        return
    _music_routing_ready = _music_state_controller.request_state(AudioMusicStateController.STATE_EXPLORATION)
    if not _music_routing_ready:
        last_music_routing_errors.append("could not start authored exploration music state")


func set_music_override_state(state_id: StringName) -> bool:
    if not _music_routing_ready or state_id not in [AudioMusicStateController.STATE_BOSS, AudioMusicStateController.STATE_RECOVERY]:
        return false
    _music_override_state = state_id
    return _music_state_controller.request_state(state_id)


func clear_music_override_state() -> bool:
    if not _music_routing_ready:
        return false
    _music_override_state = &""
    var state_id := AudioMusicStateController.STATE_COMBAT if shared_active_combat.is_active() else AudioMusicStateController.STATE_EXPLORATION
    return _music_state_controller.request_state(state_id)


func get_music_routing_snapshot() -> Dictionary:
    return {
        "ready": _music_routing_ready,
        "current_state": _music_state_controller.current_state(),
        "pending_state": _music_state_controller.pending_state(),
        "override_state": _music_override_state,
        "errors": last_music_routing_errors.duplicate(),
    }


func _physics_process(_delta: float) -> void:
    if _successful_parry_ticks > 0:
        _successful_parry_ticks -= 1


func _process(_delta: float) -> void:
    if is_region3_active():
        _update_region3_subzone_discovery()
    if _training_hall_skill_session_active and (skills_menu == null or not bool(skills_menu.call("is_open"))):
        _training_hall_skill_session_active = false
    if _player_combat_bindings.size() > 1:
        _sync_overlapping_player_status_states()
    _sync_operation_guard_with_active_combat()
    _sync_operation_guard_with_unsupported_manual_save_state()
    _process_pending_saves()
    if _music_routing_ready:
        var desired_music_state := _music_override_state
        if desired_music_state == &"":
            desired_music_state = AudioMusicStateController.STATE_COMBAT if shared_active_combat.is_active() else AudioMusicStateController.STATE_EXPLORATION
        _music_state_controller.request_state(desired_music_state)
        _music_state_controller.advance(_delta)
    if (player.is_dodging() or player.is_dashing()) and combat_runtime.get_defense_mode() != DirectHitResolver.DEFENSE_NONE:
        combat_runtime.cancel_defense()

func _region3_side_runtime() -> Region3SideQuestRuntime:
    if region3_town_session_host == null or not region3_town_session_host.has_loaded_region():
        return null
    return region3_town_session_host.active_runtime_root.get_node_or_null("Region3SideQuests") as Region3SideQuestRuntime


func _region3_side_player_state() -> CombatantRuntimeState:
    return PlayerCombatantRuntimeBinding.create_state(
        player, combat_runtime, PLAYER_COMBAT_RUNTIME_TUNING, &"player:local"
    )


func _bind_region3_side_runtime() -> Dictionary:
    if _profile == null or _save_service == null or _slot_index < 1:
        return {"accepted": true, "runtime_available": false, "reason_id": &"side_quest_save_context_unavailable"}
    if not is_region3_active() or side_quests_playtest == null or progression_playtest_content == null:
        return {"accepted": true, "runtime_available": false, "reason_id": &"side_quest_playtest_content_unavailable"}
    var side_runtime := _region3_side_runtime()
    if side_runtime == null:
        side_runtime = REGION3_SIDE_RUNTIME_SCENE.instantiate() as Region3SideQuestRuntime
        if side_runtime == null:
            return {"accepted": false, "reason_id": &"side_quest_runtime_scene_invalid"}
        side_runtime.name = "Region3SideQuests"
        region3_town_session_host.active_runtime_root.add_child(side_runtime)
    side_runtime.playtest_attack_catalog = enemy_playtest_attacks
    side_runtime.status_playtest_tuning = status_playtest_tuning
    if not side_runtime.encounter_started.is_connected(_on_region3_side_encounter_started):
        side_runtime.encounter_started.connect(_on_region3_side_encounter_started)
    if not side_runtime.encounter_ended.is_connected(_on_region3_side_encounter_ended):
        side_runtime.encounter_ended.connect(_on_region3_side_encounter_ended)
    if not side_runtime.quest_progressed.is_connected(_on_region3_side_quest_changed):
        side_runtime.quest_progressed.connect(_on_region3_side_quest_changed)
    if enemy_playtest_live_delivery != null:
        enemy_playtest_live_delivery.set_region3_host(side_runtime)
    var bound: Dictionary = side_runtime.bind_world(
        region3_town_session_host.active_runtime_root, player, _profile, _save_service,
        _slot_index, side_quests_playtest, progression_playtest_content,
        Callable(self, &"_region3_side_player_state"), shared_active_combat,
        shared_full_ai, tower_encounter_session_host.shared_attack_pressure
    )
    if not bool(bound.get("accepted", false)):
        return bound
    var restored: Dictionary = side_runtime.restore_active_quest()
    if not bool(restored.get("accepted", false)):
        return restored
    bound["runtime_available"] = true
    bound["restored"] = bool(restored.get("restored", false))
    return bound


func _on_region3_side_encounter_started(encounter_id: StringName, encounter: CombatEncounterRuntime) -> void:
    var player_state := encounter.get_combatant(&"player:local") if encounter != null else null
    var binding := PlayerCombatantRuntimeBinding.new()
    if player_state == null or not binding.bind(player, encounter, player_state):
        last_region3_side_quest_result = {"accepted": false, "reason_id": &"side_player_binding_failed", "encounter_id": encounter_id}
        return
    binding.live_player_defeated.connect(_on_live_player_defeated.bind(encounter_id))
    _player_combat_bindings[encounter_id] = binding
    player.bind_combat_runtime(encounter, player_state.actor_id)
    _sync_operation_guard_with_active_combat()


func _on_region3_side_encounter_ended(encounter_id: StringName) -> void:
    var binding := _player_combat_bindings.get(encounter_id) as PlayerCombatantRuntimeBinding
    if binding != null and binding.is_bound():
        binding.persist_status_safe_states(combat_runtime)
    _release_player_combat_binding(encounter_id)
    if _player_combat_bindings.is_empty():
        player.unbind_combat_runtime()
    _sync_operation_guard_with_active_combat()


func _region3_side_live_targets() -> Array[Dictionary]:
    var side_runtime := _region3_side_runtime()
    var targets: Array[Dictionary] = []
    if side_runtime == null or not is_region3_active():
        return targets
    for encounter_id: StringName in side_runtime.get_active_encounter_ids():
        var encounter := side_runtime.get_encounter_runtime(encounter_id)
        if encounter == null or encounter.get_combatant(&"player:local") == null:
            continue
        for raw_actor_id: Variant in side_runtime.get_visuals_by_actor(encounter_id).keys():
            var actor_id := StringName(String(raw_actor_id))
            var visual := side_runtime.get_visuals_by_actor(encounter_id).get(raw_actor_id) as Node2D
            var combatant := encounter.get_combatant(actor_id)
            if visual != null and is_instance_valid(visual) and combatant != null and not combatant.is_defeated():
                targets.append({"encounter_id": encounter_id, "actor_id": actor_id,
                    "position": visual.global_position, "encounter": encounter, "boss": false})
    return targets


func _on_region3_side_quest_changed(quest_id: StringName, result: Dictionary) -> void:
    last_region3_side_quest_result = result.duplicate(true)
    last_region3_side_quest_result["quest_id"] = quest_id
    if quest_log_menu != null:
        quest_log_menu.call("set_profile", _profile)
    if bool(result.get("objectives_complete", false)) or bool(result.get("failed", false)):
        _request_current_safe_autosave()


func _has_active_region3_side_quest() -> bool:
    if _profile == null:
        return false
    for quest_id: StringName in REGION3_SIDE_QUEST_IDS:
        var raw: Variant = _profile.quest_progress.get(String(quest_id), null)
        if raw is Dictionary and StringName(String((raw as Dictionary).get("state", &""))) == QuestProgressState.STATE_ACTIVE:
            return true
    return false


func _accept_next_region3_side_quest_if_ready() -> Dictionary:
    if _profile == null:
        return {"attempted": false, "accepted": false}
    if _has_active_region3_side_quest():
        return {"attempted": false, "accepted": false}
    for quest_id: StringName in REGION3_SIDE_QUEST_IDS:
        var raw: Variant = _profile.quest_progress.get(String(quest_id), {})
        var state := StringName(String((raw as Dictionary).get("state", &""))) if raw is Dictionary else &""
        if state in [QuestProgressState.STATE_COMPLETED, QuestProgressState.STATE_OBJECTIVES_COMPLETE]:
            continue
        var result := request_region3_side_quest(quest_id)
        result["attempted"] = true
        return result
    return {"attempted": false, "accepted": false}


func request_region3_side_quest(quest_id: StringName) -> Dictionary:
    _sync_operation_guard_with_active_combat()
    var side_runtime := _region3_side_runtime()
    if (
        not REGION3_SIDE_QUEST_IDS.has(quest_id) or _profile == null
        or _save_service == null or _slot_index < 1 or not is_region3_active()
        or side_runtime == null or side_quests_playtest == null
        or not side_quests_playtest.validate_content(progression_playtest_content).is_empty()
    ):
        return {"accepted": false, "reason_id": &"side_quest_context_unavailable", "quest_id": quest_id}
    if shared_active_combat.is_active() or not operation_guard.get_blocking_reasons(GameplayOperationGuard.OP_SERVICE).is_empty():
        return {"accepted": false, "reason_id": &"side_quest_operation_blocked", "quest_id": quest_id}
    if _has_active_region3_side_quest():
        return {"accepted": false, "reason_id": &"another_side_quest_active", "quest_id": quest_id}
    var accepted: Dictionary = side_runtime.request_accept(quest_id)
    last_region3_side_quest_result = accepted.duplicate(true)
    if bool(accepted.get("accepted", false)):
        _pending_region3_side_leave_quest_id = &""
    if bool(accepted.get("accepted", false)) and quest_log_menu != null:
        quest_log_menu.call("set_profile", _profile)
    return accepted


func request_region3_side_quest_leave(confirmed: bool = false) -> Dictionary:
    var side_runtime := _region3_side_runtime()
    if side_runtime == null or _profile == null or not is_region3_active() or side_runtime.active_quest_id() == &"":
        return {"accepted": false, "reason_id": &"side_quest_leave_unavailable"}
    var quest_id := side_runtime.active_quest_id()
    var result: Dictionary = side_runtime.request_leave(confirmed)
    result["quest_id"] = quest_id
    last_region3_side_quest_result = result.duplicate(true)
    if confirmed and bool(result.get("accepted", false)):
        _pending_region3_side_leave_quest_id = &""
        _sync_operation_guard_with_active_combat()
        if quest_log_menu != null:
            quest_log_menu.call("set_profile", _profile)
    return result


func _commit_next_region3_side_turn_in() -> Dictionary:
    if _profile == null:
        return {"attempted": false}
    for quest_id: StringName in REGION3_SIDE_QUEST_IDS:
        var raw: Variant = _profile.quest_progress.get(String(quest_id), null)
        if raw is Dictionary and StringName(String((raw as Dictionary).get("state", &""))) == QuestProgressState.STATE_OBJECTIVES_COMPLETE:
            var result := request_region3_side_quest_turn_in(quest_id)
            result["attempted"] = true
            return result
    return {"attempted": false}


func request_region3_side_quest_turn_in(quest_id: StringName) -> Dictionary:
    _sync_operation_guard_with_active_combat()
    if (
        _profile == null or _save_service == null or _slot_index < 1 or not is_region3_active()
        or not REGION3_SIDE_QUEST_IDS.has(quest_id)
    ):
        return {"accepted": false, "reason_id": &"side_turn_in_context_unavailable", "quest_id": quest_id}
    if shared_active_combat.is_active() or not operation_guard.get_blocking_reasons(GameplayOperationGuard.OP_SERVICE).is_empty():
        return {"accepted": false, "reason_id": &"side_turn_in_operation_blocked", "quest_id": quest_id}
    var raw: Variant = _profile.quest_progress.get(String(quest_id), null)
    if not raw is Dictionary or StringName(String((raw as Dictionary).get("state", &""))) != QuestProgressState.STATE_OBJECTIVES_COMPLETE:
        return {"accepted": false, "reason_id": &"side_objectives_not_complete", "quest_id": quest_id}
    var side_runtime := _region3_side_runtime()
    if side_runtime == null:
        return {"accepted": false, "reason_id": &"side_runtime_unavailable", "quest_id": quest_id}
    var result: Dictionary = side_runtime.request_turn_in(true)
    if bool(result.get("accepted", false)):
        result["xp_award"] = request_completed_quest_xp(quest_id)
    last_region3_side_quest_result = result.duplicate(true)
    if quest_log_menu != null:
        quest_log_menu.call("set_profile", _profile)
    return result


func _draw() -> void:
    if is_tower_floor_active() or is_region3_active():
        return
    var canvas_size := Vector2(world_canvas_size)
    draw_rect(Rect2(Vector2.ZERO, canvas_size), background_color, true)
    for x: int in range(0, world_canvas_size.x + 1, grid_cell_size):
        draw_line(Vector2(x, 0), Vector2(x, world_canvas_size.y), grid_color, grid_line_width)
    for y: int in range(0, world_canvas_size.y + 1, grid_cell_size):
        draw_line(Vector2(0, y), Vector2(world_canvas_size.x, y), grid_color, grid_line_width)

func _capture_foundation_collision_defaults() -> void:
    _foundation_collision_defaults.clear()
    for object: CollisionObject2D in _foundation_collision_objects():
        var entry: Dictionary = {
            "object": object,
            "collision_layer": object.collision_layer,
            "collision_mask": object.collision_mask,
            "process_mode": object.process_mode,
        }
        if object is Area2D:
            entry["monitoring"] = (object as Area2D).monitoring
            entry["monitorable"] = (object as Area2D).monitorable
        _foundation_collision_defaults.append(entry)

func _set_foundation_world_enabled(enabled: bool) -> void:
    for entry: Dictionary in _foundation_collision_defaults:
        var object := entry.get("object") as CollisionObject2D
        if object == null or not is_instance_valid(object):
            continue
        object.visible = enabled
        if enabled:
            object.collision_layer = int(entry.get("collision_layer", 0))
            object.collision_mask = int(entry.get("collision_mask", 0))
            object.process_mode = int(entry.get("process_mode", Node.PROCESS_MODE_INHERIT)) as Node.ProcessMode
            if object is Area2D:
                (object as Area2D).monitoring = bool(entry.get("monitoring", true))
                (object as Area2D).monitorable = bool(entry.get("monitorable", true))
        else:
            object.collision_layer = 0
            object.collision_mask = 0
            object.process_mode = Node.PROCESS_MODE_DISABLED
            if object is Area2D:
                (object as Area2D).monitoring = false
                (object as Area2D).monitorable = false

func _foundation_collision_objects() -> Array[CollisionObject2D]:
    return [
        $TopWall as CollisionObject2D,
        $BottomWall as CollisionObject2D,
        $LeftWall as CollisionObject2D,
        $RightWall as CollisionObject2D,
        $CenterBlock as CollisionObject2D,
        $ClimbLink as CollisionObject2D,
    ]
