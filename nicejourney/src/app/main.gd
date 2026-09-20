extends Node

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")

@export var save_root: String = SaveService.DEFAULT_SAVE_ROOT

var _save_service: SaveService = null
var _selected_slot: int = 0
var _active_gameplay: GameplayRoot = null

@onready var front_end: Control = $FrontEnd
@onready var slot_buttons: Array[Button] = [$FrontEnd/Panel/Scroller/Layout/Slot1, $FrontEnd/Panel/Scroller/Layout/Slot2, $FrontEnd/Panel/Scroller/Layout/Slot3]
@onready var creation_panel: VBoxContainer = $FrontEnd/Panel/Scroller/Layout/CreationPanel
@onready var name_edit: LineEdit = $FrontEnd/Panel/Scroller/Layout/CreationPanel/NameEdit
@onready var class_option: OptionButton = $FrontEnd/Panel/Scroller/Layout/CreationPanel/ClassOption
@onready var create_button: Button = $FrontEnd/Panel/Scroller/Layout/CreationPanel/CreateButton
@onready var feedback: Label = $FrontEnd/Panel/Scroller/Layout/Feedback
@onready var gameplay_host: Node = $GameplayHost

func _ready() -> void:
	_save_service = SaveService.new(save_root)
	class_option.clear()
	class_option.add_item(tr("Melee"))
	class_option.add_item(tr("Ranged"))
	class_option.add_item(tr("Mage"))
	for index: int in range(slot_buttons.size()):
		slot_buttons[index].pressed.connect(_on_slot_pressed.bind(index + 1))
	create_button.pressed.connect(_on_create_pressed)
	creation_panel.visible = false
	_refresh_slots()
	if not slot_buttons.is_empty():
		slot_buttons[0].grab_focus()

func _refresh_slots() -> void:
	for index: int in range(slot_buttons.size()):
		var slot_index: int = index + 1
		var profile: ProfileSnapshot = _save_service.load_profile(slot_index)
		if profile == null:
			slot_buttons[index].text = tr("Slot %d — Empty") % slot_index
		else:
			slot_buttons[index].text = tr("Slot %d — %s | %s | Lv.%d") % [slot_index, profile.protagonist_name, _class_display_name(profile.class_id), profile.level]

func _on_slot_pressed(slot_index: int) -> void:
	feedback.text = ""
	_selected_slot = slot_index
	var profile: ProfileSnapshot = _save_service.load_profile(slot_index)
	if profile != null:
		_start_gameplay(profile, slot_index)
		return
	creation_panel.visible = true
	name_edit.text = ""
	name_edit.grab_focus()

func _on_create_pressed() -> void:
	if _selected_slot < 1:
		return
	var class_id: String = ["melee", "ranged", "mage"][class_option.selected]
	var profile: ProfileSnapshot = ProfileCreationService.create_profile(_selected_slot, name_edit.text, class_id)
	if profile == null:
		feedback.text = tr("Enter a protagonist name (1–40 characters).")
		return
	var save_error: int = _save_service.save_profile(_selected_slot, profile)
	if save_error != OK:
		feedback.text = tr("Could not create the save slot. Error %d.") % save_error
		return
	_refresh_slots()
	_start_gameplay(profile, _selected_slot)

func _start_gameplay(profile: ProfileSnapshot, slot_index: int) -> void:
	front_end.visible = false
	if _active_gameplay != null:
		_active_gameplay.queue_free()
	_active_gameplay = GAMEPLAY_SCENE.instantiate() as GameplayRoot
	if _active_gameplay == null:
		feedback.text = tr("Gameplay scene failed to load.")
		front_end.visible = true
		return
	_active_gameplay.set_profile(profile)
	if not _active_gameplay.set_save_context(_save_service, slot_index):
		feedback.text = tr("Gameplay save context is invalid.")
		_active_gameplay.queue_free()
		_active_gameplay = null
		front_end.visible = true
		return
	gameplay_host.add_child(_active_gameplay)
	if not _active_gameplay.ensure_starting_world():
		feedback.text = tr("Could not initialize the saved gameplay world.")
		_active_gameplay.queue_free()
		_active_gameplay = null
		front_end.visible = true
		return

func _class_display_name(class_id: String) -> String:
	match class_id:
		"melee":
			return tr("Melee")
		"ranged":
			return tr("Ranged")
		"mage":
			return tr("Mage")
		_:
			return class_id
