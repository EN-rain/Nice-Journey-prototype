class_name UiIconCatalogShowcase
extends Control

@export var icon_catalog: UiIconCatalog
@export var presenter_scene: PackedScene
@export_node_path("GridContainer") var grid_path: NodePath = NodePath("Center/Grid")
@export var tile_minimum_size: Vector2 = Vector2(72, 70)
@export var show_labels: bool = true

@onready var grid: GridContainer = get_node_or_null(grid_path) as GridContainer

func _ready() -> void:
    rebuild()

func rebuild() -> bool:
    if grid == null or icon_catalog == null or presenter_scene == null:
        return false
    if not icon_catalog.validate_catalog().is_empty():
        return false
    for child: Node in grid.get_children():
        child.queue_free()
    for profile: UiIconProfile in icon_catalog.profiles:
        var tile := VBoxContainer.new()
        tile.custom_minimum_size = tile_minimum_size
        tile.alignment = BoxContainer.ALIGNMENT_CENTER
        var presenter := presenter_scene.instantiate() as UiIconPresenter
        if presenter == null or not presenter.configure_profile(profile):
            tile.queue_free()
            return false
        presenter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        presenter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        tile.add_child(presenter)
        if show_labels:
            var label := Label.new()
            label.text = String(profile.icon_id)
            label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
            label.custom_minimum_size.x = tile_minimum_size.x
            tile.add_child(label)
        grid.add_child(tile)
    return true
