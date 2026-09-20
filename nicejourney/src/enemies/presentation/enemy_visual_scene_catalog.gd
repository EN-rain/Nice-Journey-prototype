class_name EnemyVisualSceneCatalog
extends Resource

@export var archetype_ids: Array[StringName] = []
@export var scenes: Array[PackedScene] = []

func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    if archetype_ids.size() != scenes.size():
        errors.append("archetype_ids and scenes must have identical size")
        return errors
    if archetype_ids.size() != EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS.size():
        errors.append("catalog must contain exactly the twelve prototype enemy archetypes")
    var seen: Dictionary = {}
    for index: int in range(archetype_ids.size()):
        var archetype_id := archetype_ids[index]
        if not EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS.has(archetype_id):
            errors.append("unknown archetype_id: %s" % String(archetype_id))
        if seen.has(archetype_id):
            errors.append("duplicate archetype_id: %s" % String(archetype_id))
        seen[archetype_id] = true
        var scene := scenes[index]
        if scene == null:
            errors.append("scene is required for %s" % String(archetype_id))
            continue
        var instance := scene.instantiate()
        var visual := instance as EnemyVisualController
        if visual == null:
            errors.append("scene root must be EnemyVisualController for %s" % String(archetype_id))
            instance.free()
            continue
        if visual.profile == null or visual.profile.archetype_id != archetype_id:
            errors.append("scene profile must match archetype_id %s" % String(archetype_id))
        if visual.get_node_or_null("RuntimePresentationBinder") as EnemyRuntimePresentationBinder == null:
            errors.append("scene must provide RuntimePresentationBinder for %s" % String(archetype_id))
        visual.free()
    for required_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        if not seen.has(required_id):
            errors.append("missing archetype visual scene: %s" % String(required_id))
    return errors

func get_scene(archetype_id: StringName) -> PackedScene:
    var index := archetype_ids.find(archetype_id)
    if index < 0 or index >= scenes.size():
        return null
    return scenes[index]
