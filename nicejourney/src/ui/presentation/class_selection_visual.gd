class_name ClassSelectionVisual
extends Node

@export var icon_catalog: UiIconCatalog
@export_node_path("OptionButton") var class_option_path: NodePath
@export_node_path("TextureRect") var class_icon_path: NodePath
@export var class_icon_ids: Array[StringName] = []

@onready var class_option: OptionButton = get_node_or_null(class_option_path) as OptionButton
@onready var class_icon: TextureRect = get_node_or_null(class_icon_path) as TextureRect

func _ready() -> void:
    if class_option != null and not class_option.item_selected.is_connected(_on_item_selected):
        class_option.item_selected.connect(_on_item_selected)
    call_deferred(&"refresh")

func validate_setup() -> PackedStringArray:
    var errors := PackedStringArray()
    if icon_catalog == null:
        errors.append("icon_catalog is required")
    elif not icon_catalog.validate_catalog().is_empty():
        errors.append("icon_catalog must validate")
    if class_option == null:
        errors.append("class OptionButton is unavailable")
    if class_icon == null:
        errors.append("class TextureRect is unavailable")
    if class_option != null and class_icon_ids.size() != class_option.item_count:
        errors.append("class_icon_ids must match OptionButton item count")
    for icon_id: StringName in class_icon_ids:
        if icon_catalog != null and icon_catalog.get_profile(icon_id) == null:
            errors.append("unknown class icon_id: %s" % String(icon_id))
    return errors

func refresh() -> bool:
    if class_option == null or class_icon == null or icon_catalog == null:
        return false
    if class_option.selected < 0 or class_option.selected >= class_icon_ids.size():
        class_icon.texture = null
        return false
    var profile: UiIconProfile = icon_catalog.get_profile(class_icon_ids[class_option.selected])
    if profile == null or not profile.validate_profile().is_empty():
        class_icon.texture = null
        return false
    class_icon.texture = profile.texture
    class_icon.custom_minimum_size = profile.minimum_size
    class_icon.expand_mode = profile.expand_mode
    class_icon.stretch_mode = profile.stretch_mode
    class_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    return true

func _on_item_selected(_index: int) -> void:
    refresh()
