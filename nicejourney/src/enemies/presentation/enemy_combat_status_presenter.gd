class_name EnemyCombatStatusPresenter
extends Node2D

# Reversible first-pass combat readability presentation. Gameplay HP ownership stays
# in CombatantRuntimeState; this node only reflects authoritative encounter results.
const BAR_WIDTH: float = 24.0
const BAR_HEIGHT: float = 3.0
const BAR_OFFSET_Y: float = -22.0
const DAMAGE_LIFETIME_TICKS: int = 36
const DAMAGE_RISE_PER_TICK: float = 0.25

var bound_runtime: CombatEncounterRuntime = null
var bound_actor_id: StringName = &""
var _damage_labels: Array[Label] = []


func bind_runtime(runtime: CombatEncounterRuntime, actor_id: StringName) -> bool:
    if runtime == null or not StableId.is_valid(String(actor_id)):
        return false
    if runtime.get_combatant(actor_id) == null:
        return false
    unbind_runtime()
    bound_runtime = runtime
    bound_actor_id = actor_id
    bound_runtime.direct_contact_resolved.connect(_on_direct_contact_resolved)
    bound_runtime.enemy_defeated.connect(_on_enemy_defeated)
    queue_redraw()
    return true


func unbind_runtime() -> void:
    if bound_runtime != null:
        if bound_runtime.direct_contact_resolved.is_connected(_on_direct_contact_resolved):
            bound_runtime.direct_contact_resolved.disconnect(_on_direct_contact_resolved)
        if bound_runtime.enemy_defeated.is_connected(_on_enemy_defeated):
            bound_runtime.enemy_defeated.disconnect(_on_enemy_defeated)
    bound_runtime = null
    bound_actor_id = &""
    _clear_damage_labels()
    queue_redraw()


func get_health_ratio() -> float:
    if bound_runtime == null or bound_actor_id == &"":
        return 0.0
    var state := bound_runtime.get_combatant(bound_actor_id)
    if state == null or state.max_hp <= 0:
        return 0.0
    return clampf(float(state.current_hp) / float(state.max_hp), 0.0, 1.0)


func get_damage_number_count() -> int:
    return _damage_labels.size()


func advance_fixed_tick() -> void:
    var expired: Array[Label] = []
    for label: Label in _damage_labels:
        if label == null or not is_instance_valid(label):
            expired.append(label)
            continue
        var ticks_remaining := int(label.get_meta(&"ticks_remaining", 0)) - 1
        label.set_meta(&"ticks_remaining", ticks_remaining)
        label.position.y -= DAMAGE_RISE_PER_TICK
        if ticks_remaining <= 0:
            expired.append(label)
    for label: Label in expired:
        _damage_labels.erase(label)
        if label != null and is_instance_valid(label):
            label.queue_free()


func _physics_process(_delta: float) -> void:
    advance_fixed_tick()


func _draw() -> void:
    if bound_runtime == null or bound_actor_id == &"":
        return
    var state := bound_runtime.get_combatant(bound_actor_id)
    if state == null:
        return
    var ratio := get_health_ratio()
    var outer := Rect2(Vector2(-BAR_WIDTH * 0.5 - 1.0, BAR_OFFSET_Y - 1.0), Vector2(BAR_WIDTH + 2.0, BAR_HEIGHT + 2.0))
    var background := Rect2(Vector2(-BAR_WIDTH * 0.5, BAR_OFFSET_Y), Vector2(BAR_WIDTH, BAR_HEIGHT))
    var fill := Rect2(background.position, Vector2(BAR_WIDTH * ratio, BAR_HEIGHT))
    draw_rect(outer, Color(0.05, 0.05, 0.06, 0.95), true)
    draw_rect(background, Color(0.16, 0.16, 0.18, 0.95), true)
    if ratio > 0.0:
        draw_rect(fill, Color(0.78, 0.18, 0.18, 1.0), true)


func _on_direct_contact_resolved(
    _attacker_id: StringName,
    target_id: StringName,
    _action_instance_id: int,
    _hit_interval_index: int,
    result: Dictionary
) -> void:
    if target_id != bound_actor_id or not bool(result.get("accepted", false)):
        return
    var hp_damage := int(result.get("hp_damage", 0))
    if hp_damage > 0:
        _spawn_damage_label(hp_damage)
    queue_redraw()


func _on_enemy_defeated(actor_id: StringName) -> void:
    if actor_id == bound_actor_id:
        queue_redraw()


func _spawn_damage_label(amount: int) -> void:
    var label := Label.new()
    label.name = "Damage_%d" % (_damage_labels.size() + 1)
    label.text = str(amount)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.position = Vector2(-16.0, BAR_OFFSET_Y - 13.0)
    label.size = Vector2(32.0, 12.0)
    label.add_theme_font_size_override(&"font_size", 8)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.set_meta(&"ticks_remaining", DAMAGE_LIFETIME_TICKS)
    add_child(label)
    _damage_labels.append(label)


func _clear_damage_labels() -> void:
    for label: Label in _damage_labels:
        if label != null and is_instance_valid(label):
            label.queue_free()
    _damage_labels.clear()


func _exit_tree() -> void:
    unbind_runtime()
