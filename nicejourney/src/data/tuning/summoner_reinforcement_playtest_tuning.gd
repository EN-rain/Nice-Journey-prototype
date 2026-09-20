class_name SummonerReinforcementPlaytestTuning
extends Resource

# Reversible Inspector-owned encounter allocation. Every reserved actor is charged
# against the floor population budget before any Summoner may start a call.
@export var playtest_placeholder: bool = true
@export_range(1, 4, 1) var calls_per_summoner: int = 2
@export var reinforcement_archetype_id: StringName = &"duelist"
@export_range(1.0, 1024.0, 1.0) var spawn_min_distance_from_player_px: float = 80.0
@export var enemy_state_tuning: TowerPrototypeEnemyRuntimeTuning


func validate_tuning() -> PackedStringArray:
    var errors := PackedStringArray()
    if not playtest_placeholder:
        errors.append("Summoner reinforcement tuning must remain explicitly PLAYTEST")
    if calls_per_summoner < 1 or calls_per_summoner > 4:
        errors.append("Summoner calls per actor must be in 1..4")
    if reinforcement_archetype_id == &"summoner" or EnemyArchetypeCatalog.get_definition(reinforcement_archetype_id) == null:
        errors.append("Summoner reinforcement must use an existing non-Summoner archetype")
    if not is_finite(spawn_min_distance_from_player_px) or spawn_min_distance_from_player_px <= 0.0:
        errors.append("Summoner reinforcement requires positive player spawn clearance")
    if enemy_state_tuning == null or not enemy_state_tuning.validate_tuning().is_empty():
        errors.append("Summoner reinforcement must use valid Inspector-authored enemy stats")
    return errors
