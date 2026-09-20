class_name AiObservationMemory
extends RefCounted

var _capacity: int = 1
var _observations: Array[Dictionary] = []

func _init(capacity: int = 8) -> void:
    _capacity = maxi(capacity, 1)

func record_observation(
    cue_id: StringName,
    source_id: StringName,
    observed_position: Vector2,
    observed_state: StringName,
    observed_tick: int,
    confidence: float,
    lifetime_ticks: int
) -> bool:
    if cue_id == &"" or source_id == &"" or observed_tick < 0:
        return false
    if not observed_position.is_finite():
        return false
    if not is_finite(confidence) or confidence < 0.0 or confidence > 1.0 or lifetime_ticks <= 0:
        return false

    _observations.append({
        "cue_id": cue_id,
        "source_id": source_id,
        "observed_position": observed_position,
        "observed_state": observed_state,
        "observed_tick": observed_tick,
        "confidence": confidence,
        "lifetime_ticks": lifetime_ticks,
        "expiry_tick": observed_tick + lifetime_ticks,
    })
    while _observations.size() > _capacity:
        _observations.remove_at(_oldest_observation_index())
    return true

func latest_for_source(source_id: StringName, now_tick: int, confidence_decay_per_tick: float = 0.0) -> Dictionary:
    if source_id == &"" or now_tick < 0 or not is_finite(confidence_decay_per_tick) or confidence_decay_per_tick < 0.0:
        return {}
    var latest: Dictionary = {}
    for index: int in range(_observations.size() - 1, -1, -1):
        var observation: Dictionary = _observations[index]
        if StringName(observation.get("source_id", &"")) != source_id:
            continue
        if now_tick >= int(observation.get("expiry_tick", 0)):
            continue
        if latest.is_empty() or int(observation.get("observed_tick", -1)) > int(latest.get("observed_tick", -1)):
            latest = observation
    if latest.is_empty():
        return {}
    return _snapshot(latest, now_tick, confidence_decay_per_tick)

func can_react_to(observation: Dictionary, now_tick: int, authored_reaction_delay_ticks: int) -> bool:
    if observation.is_empty() or now_tick < 0 or authored_reaction_delay_ticks < 0:
        return false
    var observed_tick: int = int(observation.get("observed_tick", -1))
    if observed_tick < 0:
        return false
    if now_tick >= int(observation.get("expiry_tick", observed_tick)):
        return false
    return now_tick >= observed_tick + authored_reaction_delay_ticks

func purge_expired(now_tick: int) -> int:
    if now_tick < 0:
        return 0
    var removed: int = 0
    for index: int in range(_observations.size() - 1, -1, -1):
        if now_tick < int(_observations[index].get("expiry_tick", 0)):
            continue
        _observations.remove_at(index)
        removed += 1
    return removed

func size() -> int:
    return _observations.size()

func get_debug_observations(now_tick: int, max_records: int = 8, confidence_decay_per_tick: float = 0.0) -> Array[Dictionary]:
    var snapshots: Array[Dictionary] = []
    if now_tick < 0 or max_records <= 0 or not is_finite(confidence_decay_per_tick) or confidence_decay_per_tick < 0.0:
        return snapshots
    var ordered: Array[Dictionary] = _observations.duplicate(true)
    ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var a_tick: int = int(a.get("observed_tick", -1))
        var b_tick: int = int(b.get("observed_tick", -1))
        if a_tick != b_tick:
            return a_tick > b_tick
        var a_source: String = String(a.get("source_id", &""))
        var b_source: String = String(b.get("source_id", &""))
        if a_source != b_source:
            return a_source < b_source
        return String(a.get("cue_id", &"")) < String(b.get("cue_id", &""))
    )
    for observation: Dictionary in ordered:
        if now_tick >= int(observation.get("expiry_tick", 0)):
            continue
        snapshots.append(_snapshot(observation, now_tick, confidence_decay_per_tick))
        if snapshots.size() >= max_records:
            break
    return snapshots

func clear() -> void:
    _observations.clear()

func _oldest_observation_index() -> int:
    var oldest_index: int = 0
    var oldest_tick: int = int(_observations[0].get("observed_tick", 0))
    for index: int in range(1, _observations.size()):
        var observed_tick: int = int(_observations[index].get("observed_tick", 0))
        if observed_tick < oldest_tick:
            oldest_tick = observed_tick
            oldest_index = index
    return oldest_index

func _snapshot(observation: Dictionary, now_tick: int, confidence_decay_per_tick: float) -> Dictionary:
    var observed_tick: int = int(observation.get("observed_tick", 0))
    var age_ticks: int = maxi(now_tick - observed_tick, 0)
    var confidence: float = maxf(
        float(observation.get("confidence", 0.0)) - confidence_decay_per_tick * float(age_ticks),
        0.0
    )
    return {
        "cue_id": StringName(observation.get("cue_id", &"")),
        "source_id": StringName(observation.get("source_id", &"")),
        "observed_position": Vector2(observation.get("observed_position", Vector2.ZERO)),
        "observed_state": StringName(observation.get("observed_state", &"")),
        "observed_tick": observed_tick,
        "age_ticks": age_ticks,
        "confidence": confidence,
        "lifetime_ticks": int(observation.get("lifetime_ticks", 0)),
        "expiry_tick": int(observation.get("expiry_tick", observed_tick)),
    }
