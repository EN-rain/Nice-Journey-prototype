class_name TowerEncounterPresentationFactory
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_CATALOG_INVALID: StringName = &"catalog_invalid"
const REASON_RUNTIME_INVALID: StringName = &"runtime_invalid"
const REASON_SCENE_MISSING: StringName = &"scene_missing"
const REASON_BINDING_FAILED: StringName = &"binding_failed"

static func build(
    activation: Dictionary,
    visual_catalog: EnemyVisualSceneCatalog,
    tile_size: int = TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE
) -> Dictionary:
    if visual_catalog == null or tile_size <= 0:
        return _rejected(REASON_INVALID_CONTEXT)
    var catalog_errors := visual_catalog.validate_catalog()
    if not catalog_errors.is_empty():
        var rejected := _rejected(REASON_CATALOG_INVALID)
        rejected["errors"] = catalog_errors.duplicate()
        return rejected
    if not bool(activation.get("accepted", false)) or bool(activation.get("resolved", false)):
        return _rejected(REASON_RUNTIME_INVALID)
    var encounter := activation.get("encounter_runtime") as CombatEncounterRuntime
    var raw_placements: Variant = activation.get("placements", null)
    var raw_runtimes: Variant = activation.get("archetype_runtimes", null)
    if encounter == null or not raw_placements is Array or not raw_runtimes is Dictionary:
        return _rejected(REASON_RUNTIME_INVALID)

    var root := Node2D.new()
    root.name = _node_name("Encounter_%s_Presentation" % String(encounter.encounter_id))
    root.set_meta(&"encounter_id", encounter.encounter_id)
    var visuals_by_actor: Dictionary = {}
    var status_by_actor: Dictionary = {}
    var bound_binders: Array[EnemyRuntimePresentationBinder] = []

    for raw_placement: Variant in raw_placements as Array:
        if not raw_placement is Dictionary:
            _cleanup(root, bound_binders)
            return _rejected(REASON_RUNTIME_INVALID)
        var placement := raw_placement as Dictionary
        var actor_id := StringName(String(placement.get("actor_id", &"")))
        var archetype_id := StringName(String(placement.get("archetype_id", &"")))
        var world_tile_variant: Variant = placement.get("world_tile", null)
        var archetype_runtime := (raw_runtimes as Dictionary).get(actor_id) as EnemyArchetypeRuntime
        if not StableId.is_valid(String(actor_id)) or not world_tile_variant is Vector2i or archetype_runtime == null:
            _cleanup(root, bound_binders)
            return _rejected(REASON_RUNTIME_INVALID)
        var scene := visual_catalog.get_scene(archetype_id)
        if scene == null:
            _cleanup(root, bound_binders)
            return _rejected(REASON_SCENE_MISSING)
        var visual := scene.instantiate() as EnemyVisualController
        if visual == null or visual.profile == null or visual.profile.archetype_id != archetype_id:
            if visual != null:
                visual.free()
            _cleanup(root, bound_binders)
            return _rejected(REASON_SCENE_MISSING)
        visual.name = _node_name(String(actor_id))
        visual.position = (Vector2(world_tile_variant as Vector2i) + Vector2(0.5, 0.5)) * float(tile_size)
        visual.set_meta(&"actor_id", actor_id)
        visual.set_meta(&"archetype_id", archetype_id)
        visual.set_meta(&"elite", bool(placement.get("elite", false)))
        root.add_child(visual)
        var binder := visual.get_node_or_null("RuntimePresentationBinder") as EnemyRuntimePresentationBinder
        if binder == null or not binder.bind_runtime(encounter, actor_id) or not binder.bind_archetype_runtime(archetype_runtime):
            _cleanup(root, bound_binders)
            return _rejected(REASON_BINDING_FAILED)
        bound_binders.append(binder)
        var status := EnemyCombatStatusPresenter.new()
        status.name = "CombatStatus"
        status.z_index = 50
        visual.add_child(status)
        if not status.bind_runtime(encounter, actor_id):
            _cleanup(root, bound_binders)
            return _rejected(REASON_BINDING_FAILED)
        visuals_by_actor[actor_id] = visual
        status_by_actor[actor_id] = status

    return {
        "accepted": true,
        "reason_id": &"",
        "encounter_id": encounter.encounter_id,
        "root": root,
        "visuals_by_actor": visuals_by_actor,
        "status_by_actor": status_by_actor,
        "errors": PackedStringArray(),
    }

static func _cleanup(root: Node2D, binders: Array[EnemyRuntimePresentationBinder]) -> void:
    for binder: EnemyRuntimePresentationBinder in binders:
        if binder != null:
            binder.unbind_runtime()
    if root != null:
        root.free()

static func _node_name(value: String) -> String:
    return value.replace(":", "_").replace("/", "_").replace("-", "_").replace(".", "_")

static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "encounter_id": &"",
        "root": null,
        "visuals_by_actor": {},
        "status_by_actor": {},
        "errors": PackedStringArray(),
    }
