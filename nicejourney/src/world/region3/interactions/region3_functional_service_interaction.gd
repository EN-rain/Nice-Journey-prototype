class_name Region3FunctionalServiceInteraction
extends Area2D

signal service_requested(structure_id: StringName, role_id: StringName)

const INTERACTION_KIND: StringName = &"interact"
const SUPPORTED_ROLE_IDS: Array[StringName] = [
    Region3TownStructureManifestValidator.ROLE_QUEST_HALL,
    Region3TownStructureManifestValidator.ROLE_BLACKSMITH,
    Region3TownStructureManifestValidator.ROLE_GENERAL_MERCHANT,
    Region3TownStructureManifestValidator.ROLE_INN_REST_HOUSE,
    Region3TownStructureManifestValidator.ROLE_TRAINING_HALL,
    Region3TownStructureManifestValidator.ROLE_CLINIC_APOTHECARY,
]

@export var expected_role_id: StringName = &""
@export_range(0.25, 2.0, 0.05) var interaction_radius_tiles: float = 0.75
@export_node_path("CollisionShape2D") var collision_shape_path: NodePath = NodePath("CollisionShape2D")

@onready var collision_shape: CollisionShape2D = get_node_or_null(collision_shape_path) as CollisionShape2D

var _input_ownership: InputOwnership = null
var _operation_guard: GameplayOperationGuard = null
var _player_in_range: PlayerController = null
var _admission := InteractionCommitAdmission.new()
var _commit_sequence: int = 0
var _authored_binding_valid: bool = false


func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    monitorable = false
    monitoring = true
    _authored_binding_valid = _apply_authored_binding()
    if not _authored_binding_valid:
        monitoring = false
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)
    if not body_exited.is_connected(_on_body_exited):
        body_exited.connect(_on_body_exited)


func bind_runtime(input_ownership: InputOwnership, operation_guard: GameplayOperationGuard) -> bool:
    if input_ownership == null or operation_guard == null or not _authored_binding_valid:
        return false
    _input_ownership = input_ownership
    _operation_guard = operation_guard
    return true


func request_service(commit_id: StringName) -> Dictionary:
    var anchor := get_parent() as Region3TownStructureAnchor
    var target_valid := (
        _authored_binding_valid
        and anchor != null
        and anchor.role_id == expected_role_id
        and SUPPORTED_ROLE_IDS.has(expected_role_id)
    )
    var menu_allows := _input_ownership != null and not _input_ownership.is_modal_open()
    var combat_allows := _operation_guard != null and _operation_guard.is_allowed(GameplayOperationGuard.OP_SERVICE)
    var context := {
        "in_range": _player_in_range != null and is_instance_valid(_player_in_range),
        "target_state_valid": target_valid,
        "required_item_satisfied": true,
        "required_quest_flag_satisfied": true,
        "menu_ownership_allows": menu_allows,
        "combat_ownership_allows": combat_allows,
        "hold_complete": true,
    }
    var result := _admission.try_admit(commit_id, context)
    result["structure_id"] = anchor.structure_id if anchor != null else &""
    result["role_id"] = expected_role_id
    if not bool(result.get("admitted", false)):
        return result
    if _player_in_range != null:
        _player_in_range.present_committed_interaction(INTERACTION_KIND)
    service_requested.emit(anchor.structure_id, expected_role_id)
    return result


func is_player_in_range() -> bool:
    return _player_in_range != null and is_instance_valid(_player_in_range)


func authored_approach_world_position() -> Vector2:
    var anchor := get_parent() as Region3TownStructureAnchor
    var layout := anchor.get_parent() as Region3AuthoredTownLayout if anchor != null else null
    if anchor == null or layout == null:
        return Vector2.INF
    return anchor.approach_world_position(float(layout.tile_size))


func validate_authored_binding() -> PackedStringArray:
    var errors := PackedStringArray()
    var anchor := get_parent() as Region3TownStructureAnchor
    if anchor == null:
        errors.append("functional service interaction must be a child of a Region3TownStructureAnchor")
        return errors
    if anchor.category != Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
        errors.append("functional service interaction requires a functional structure anchor")
    if not SUPPORTED_ROLE_IDS.has(expected_role_id):
        errors.append("functional service interaction requires one supported service role")
    if anchor.role_id != expected_role_id:
        errors.append("functional service interaction role must match its authored anchor")
    var layout := anchor.get_parent() as Region3AuthoredTownLayout
    if layout == null:
        errors.append("functional service interaction requires the authored Region 3 town layout")
        return errors
    if not is_finite(interaction_radius_tiles) or interaction_radius_tiles <= 0.0:
        errors.append("interaction_radius_tiles must be finite and positive")
    if collision_shape == null or not collision_shape.shape is CircleShape2D:
        errors.append("functional service interaction requires a CircleShape2D")
    return errors


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed(&"interact") or not is_player_in_range():
        return
    if _input_ownership == null or _operation_guard == null:
        return
    if not _input_ownership.can_route_gameplay_action(&"interact"):
        return
    _commit_sequence += 1
    var commit_id := StringName("interaction:region3_service:%s:%d" % [String(expected_role_id), _commit_sequence])
    var result := request_service(commit_id)
    if bool(result.get("admitted", false)):
        get_viewport().set_input_as_handled()


func _apply_authored_binding() -> bool:
    var anchor := get_parent() as Region3TownStructureAnchor
    var layout := anchor.get_parent() as Region3AuthoredTownLayout if anchor != null else null
    if anchor == null or layout == null or collision_shape == null or not collision_shape.shape is CircleShape2D:
        return false
    position = anchor.approach_world_position(float(layout.tile_size)) - anchor.position
    var circle := collision_shape.shape as CircleShape2D
    circle.radius = float(layout.tile_size) * interaction_radius_tiles
    return validate_authored_binding().is_empty()


func _on_body_entered(body: Node2D) -> void:
    if body is PlayerController:
        _player_in_range = body as PlayerController


func _on_body_exited(body: Node2D) -> void:
    if body == _player_in_range:
        _player_in_range = null
