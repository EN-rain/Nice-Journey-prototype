class_name Region3SideQuestPlaytestAnchorLayer
extends Node2D

# This Inspector-owned geometric staging is optional and provisional. It does
# not override the master-backed quest policy/production-readiness gate.
@export var playtest_placeholder: bool = true
@export var escort_start_path: NodePath
@export var escort_goal_path: NodePath
@export var escort_route_paths: Array[NodePath] = []
@export var escort_hostile_spawn_paths: Array[NodePath] = []
@export var west_hostile_spawn_paths: Array[NodePath] = []
@export var west_return_landmark_path: NodePath
@export var north_defense_objective_path: NodePath
@export var north_hostile_spawn_paths: Array[NodePath] = []
@export_range(1, 1000, 1) var escort_max_hp: int = 90
@export_range(1, 1000, 1) var defense_max_hp: int = 120
@export_range(1, 250, 1) var escort_speed_px_per_second: float = 64.0
@export_range(1, 64, 1) var escort_arrival_tolerance_px: float = 12.0
@export_range(16, 512, 1) var escort_follow_distance_px: float = 192.0
@export_range(1, 120, 1) var hostile_objective_damage: int = 9
@export_range(8, 96, 1) var hostile_objective_contact_radius_px: float = 26.0
@export_range(1, 600, 1) var hostile_objective_contact_cooldown_ticks: int = 65
@export var escort_enemy_archetype_ids: Array[StringName] = [&"duelist", &"skirmisher", &"bruiser"]
@export var west_enemy_archetype_ids: Array[StringName] = [&"duelist", &"bruiser", &"skirmisher", &"defender", &"marksman"]
@export var north_enemy_archetype_ids: Array[StringName] = [&"duelist", &"skirmisher", &"bruiser", &"defender", &"marksman", &"caster"]


func validate_for_layout(layout: Region3AuthoredTownLayout) -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("Side quest anchor layer must remain marked as provisional")
    if layout == null or not is_ancestor_of(self) and layout != get_parent():
        # Layout is the expected direct parent; detached markers have no
        # authoritative Region 3 tile-space identity.
        errors.append("Side quest markers require their authored Region 3 layout parent")
        return errors
    # Counts are owned by the playtest resource and cross-checked against these
    # physical markers by Region3SideQuestAttemptService when binding a quest.
    if escort_hostile_spawn_paths.is_empty() or west_hostile_spawn_paths.is_empty() or north_hostile_spawn_paths.is_empty():
        errors.append("South, West and North must each have authored hostile markers")
    if escort_route_paths.is_empty() or escort_max_hp <= 0 or defense_max_hp <= 0:
        errors.append("Escort route and positive quest actor/objective health must be authored")
    if escort_speed_px_per_second <= 0.0 or escort_arrival_tolerance_px <= 0.0 or escort_follow_distance_px <= escort_arrival_tolerance_px:
        errors.append("Escort movement and follow distances must be positive, ordered authored tuning")
    if hostile_objective_damage <= 0 or hostile_objective_contact_radius_px <= 0.0 or hostile_objective_contact_cooldown_ticks <= 0:
        errors.append("hostile objective contact damage and cooldown must be authored and positive")
    _validate_archetypes(errors, escort_enemy_archetype_ids, escort_hostile_spawn_paths.size(), "escort")
    _validate_archetypes(errors, west_enemy_archetype_ids, west_hostile_spawn_paths.size(), "west")
    _validate_archetypes(errors, north_enemy_archetype_ids, north_hostile_spawn_paths.size(), "north")
    var seen: Dictionary = {}
    _validate_marker(errors, layout, escort_start_path, Region3SideQuestStagingService.SOUTH_OUTSKIRTS_TILE_RECT, seen, "escort start")
    _validate_marker(errors, layout, escort_goal_path, layout.town_tile_rect, seen, "escort goal")
    _validate_marker(errors, layout, west_return_landmark_path, layout.town_tile_rect, seen, "west return landmark")
    _validate_marker(errors, layout, north_defense_objective_path, Region3SideQuestStagingService.NORTH_RUINS_TILE_RECT, seen, "defense objective")
    for index: int in escort_route_paths.size():
        _validate_marker(errors, layout, escort_route_paths[index], Rect2i(Vector2i.ZERO, layout.map_size_tiles), seen, "escort route %d" % index)
    for index: int in escort_hostile_spawn_paths.size():
        _validate_marker(errors, layout, escort_hostile_spawn_paths[index], Region3SideQuestStagingService.SOUTH_OUTSKIRTS_TILE_RECT, seen, "escort hostile %d" % index)
    for index: int in west_hostile_spawn_paths.size():
        _validate_marker(errors, layout, west_hostile_spawn_paths[index], Region3SideQuestStagingService.WEST_ROAD_TILE_RECT, seen, "west hostile %d" % index)
    for index: int in north_hostile_spawn_paths.size():
        _validate_marker(errors, layout, north_hostile_spawn_paths[index], Region3SideQuestStagingService.NORTH_RUINS_TILE_RECT, seen, "north hostile %d" % index)
    return errors


func marker_world_position(path: NodePath) -> Vector2:
    var marker := get_node_or_null(path) as Marker2D
    return marker.global_position if marker != null else Vector2.INF


func _validate_marker(
    errors: PackedStringArray,
    layout: Region3AuthoredTownLayout,
    path: NodePath,
    allowed_tiles: Rect2i,
    seen: Dictionary,
    label: String
) -> void:
    var marker := get_node_or_null(path) as Marker2D
    if marker == null or not marker.position.is_finite():
        errors.append("%s must identify a finite Inspector-authored Marker2D" % label)
        return
    if seen.has(marker.get_instance_id()):
        errors.append("%s reuses another marker" % label)
        return
    seen[marker.get_instance_id()] = true
    var tile := layout.to_local(marker.global_position) / float(layout.tile_size)
    if not Rect2(Vector2(allowed_tiles.position), Vector2(allowed_tiles.size)).has_point(tile):
        errors.append("%s must remain inside its reserved side-quest staging zone" % label)

func _validate_archetypes(errors: PackedStringArray, archetypes: Array[StringName], expected: int, label: String) -> void:
    if archetypes.size() != expected:
        errors.append("%s hostile archetype count must match authored spawn count" % label)
    for archetype_id: StringName in archetypes:
        if not EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS.has(archetype_id):
            errors.append("%s hostile archetype is missing from the approved enemy roster" % label)
