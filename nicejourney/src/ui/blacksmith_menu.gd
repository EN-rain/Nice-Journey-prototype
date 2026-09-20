class_name BlacksmithMenu
extends CanvasLayer

const MODAL_ID: StringName = &"ui:blacksmith"
const VIEW_SERVICE: Script = preload("res://src/ui/blacksmith_view_service.gd")

@onready var overlay: Control = $Overlay
@onready var summary_label: Label = $Overlay/Panel/Layout/Summary
@onready var option_list: ItemList = $Overlay/Panel/Layout/Options
@onready var detail_label: Label = $Overlay/Panel/Layout/Detail
@onready var upgrade_button: Button = $Overlay/Panel/Layout/Upgrade
@onready var status_label: Label = $Overlay/Panel/Layout/Status
@onready var back_button: Button = $Overlay/Panel/Layout/Back

var _profile: ProfileSnapshot = null
var _input_ownership: InputOwnership = null
var _upgrade_request: Callable = Callable()
var _recipes: Array[UpgradeRecipeDefinition] = []
var _recipes_by_id: Dictionary = {}
var _snapshot: Dictionary = {}
var _selected_option: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    overlay.visible = false
    option_list.item_selected.connect(_on_option_selected)
    upgrade_button.pressed.connect(_on_upgrade_pressed)
    back_button.pressed.connect(_on_back_pressed)
    upgrade_button.disabled = true


func configure(
    profile: ProfileSnapshot,
    input_ownership: InputOwnership,
    recipes: Array,
    upgrade_request: Callable
) -> bool:
    if profile == null or input_ownership == null or not upgrade_request.is_valid():
        return false
    var typed_recipes: Array[UpgradeRecipeDefinition] = []
    var by_id: Dictionary = {}
    for raw_recipe: Variant in recipes:
        if not raw_recipe is UpgradeRecipeDefinition:
            return false
        var recipe := raw_recipe as UpgradeRecipeDefinition
        if recipe == null or not recipe.validate_definition().is_empty() or by_id.has(recipe.recipe_id):
            return false
        typed_recipes.append(recipe)
        by_id[recipe.recipe_id] = recipe
    _profile = profile
    _input_ownership = input_ownership
    _upgrade_request = upgrade_request
    _recipes = typed_recipes
    _recipes_by_id = by_id
    return true


func set_profile(profile: ProfileSnapshot) -> bool:
    if profile == null:
        return false
    _profile = profile
    if overlay.visible:
        _refresh_snapshot()
    return true


func open_service() -> bool:
    if _profile == null or _input_ownership == null:
        return false
    if _input_ownership.is_modal_open() and _input_ownership.current_modal() != MODAL_ID:
        return false
    if not _refresh_snapshot():
        return false
    overlay.visible = true
    _input_ownership.open_modal(MODAL_ID)
    if option_list.item_count > 0:
        option_list.grab_focus()
    else:
        back_button.grab_focus()
    return true


func close_menu(triggering_action: StringName = &"") -> void:
    if not overlay.visible:
        return
    overlay.visible = false
    _selected_option = {}
    upgrade_button.disabled = true
    if _input_ownership != null:
        _input_ownership.close_modal(MODAL_ID, triggering_action)


func is_open() -> bool:
    return overlay.visible


func current_snapshot() -> Dictionary:
    return _snapshot.duplicate(true)


func _refresh_snapshot() -> bool:
    var view: Dictionary = VIEW_SERVICE.build_view(_profile, _recipes)
    if not bool(view.get("accepted", false)):
        status_label.text = tr("Blacksmith view unavailable: %s") % String(view.get("reason_id", &"unknown"))
        return false
    _snapshot = view.duplicate(true)
    _render_snapshot()
    return true


func _render_snapshot() -> void:
    summary_label.text = tr("Gold: %d | Authored recipes: %d") % [
        int(_snapshot.get("gold", 0)), int(_snapshot.get("authored_recipe_count", 0))
    ]
    option_list.clear()
    for raw_option: Variant in _snapshot.get("upgrade_options", []) as Array:
        if not raw_option is Dictionary:
            continue
        var option := raw_option as Dictionary
        option_list.add_item("%s [%s] +%d → +%d | %d Gold%s" % [
            String(option.get("definition_id", &"")),
            String(option.get("location_id", &"")),
            int(option.get("before_rank", 0)),
            int(option.get("after_rank", 0)),
            int(option.get("gold_cost", 0)),
            "" if bool(option.get("affordable", false)) else tr(" — missing resources"),
        ])
        option_list.set_item_metadata(option_list.item_count - 1, option.duplicate(true))
    _selected_option = {}
    upgrade_button.disabled = true
    detail_label.text = tr("Select an authored compatible upgrade option.")
    if _recipes.is_empty():
        status_label.text = tr("No authored upgrade recipes were supplied; Blacksmith mutation remains unavailable.")
    elif option_list.item_count == 0:
        status_label.text = tr("No owned inventory/storage item currently matches the supplied authored recipes.")
    else:
        status_label.text = tr("Upgrade previews use only caller-supplied authored recipes. Accepted changes remain unbanked until the next committed safe snapshot.")


func _on_option_selected(index: int) -> void:
    if index < 0 or index >= option_list.item_count:
        return
    _selected_option = (option_list.get_item_metadata(index) as Dictionary).duplicate(true)
    var recipe_id := StringName(String(_selected_option.get("recipe_id", &"")))
    var affordable := bool(_selected_option.get("affordable", false))
    upgrade_button.disabled = not _recipes_by_id.has(recipe_id) or not affordable
    detail_label.text = tr("Recipe %s | %s | %s → rank %d | Gold %d | Materials %s | Stats %s%s") % [
        String(recipe_id),
        String(_selected_option.get("location_id", &"")),
        String(_selected_option.get("item_instance_id", &"")),
        int(_selected_option.get("after_rank", 0)),
        int(_selected_option.get("gold_cost", 0)),
        _dictionary_text(_selected_option.get("material_costs", {}) as Dictionary),
        _dictionary_text(_selected_option.get("stat_changes", {}) as Dictionary),
        "" if affordable else tr(" | Missing Gold %d; materials %s") % [
            int(_selected_option.get("gold_shortfall", 0)),
            _dictionary_text(_selected_option.get("missing_materials", {}) as Dictionary),
        ],
    ]
    if not affordable:
        status_label.text = tr("Upgrade unavailable: required Gold or materials are missing from inventory.")


func _on_upgrade_pressed() -> void:
    if upgrade_button.disabled or _selected_option.is_empty() or not _upgrade_request.is_valid():
        return
    var recipe_id := StringName(String(_selected_option.get("recipe_id", &"")))
    var recipe: UpgradeRecipeDefinition = _recipes_by_id.get(recipe_id, null) as UpgradeRecipeDefinition
    if recipe == null:
        return
    var raw_result: Variant = _upgrade_request.call(
        StringName(String(_selected_option.get("location_id", &""))),
        StringName(String(_selected_option.get("item_instance_id", &""))),
        recipe
    )
    if not raw_result is Dictionary:
        status_label.text = tr("Upgrade failed: invalid response.")
        return
    var result := raw_result as Dictionary
    if not bool(result.get("accepted", false)):
        status_label.text = tr("Upgrade rejected: %s") % String(result.get("reason_id", &"unknown"))
        return
    _refresh_snapshot()
    status_label.text = tr("Upgrade completed. Change is live but unbanked until the next committed safe snapshot.")


func _dictionary_text(values: Dictionary) -> String:
    if values.is_empty():
        return tr("none")
    var keys: Array[String] = []
    for raw_key: Variant in values.keys():
        keys.append(String(raw_key))
    keys.sort()
    var parts := PackedStringArray()
    for key: String in keys:
        parts.append("%s:%s" % [key, str(values[key])])
    return ", ".join(parts)


func _on_back_pressed() -> void:
    close_menu()
