extends Control

const SLOT_COUNT := 3

@onready var slots: VBoxContainer = $Margin/Panel/VBox/Slots
@onready var name_edit: LineEdit = $Margin/Panel/VBox/Name
@onready var start_button: Button = $Margin/Panel/VBox/Actions/Start
@onready var clear_button: Button = $Margin/Panel/VBox/Actions/Clear
@onready var confirmation: ConfirmationDialog = $ClearConfirmation

var selected_slot := -1

func _ready() -> void:
	SaveManager.load_profile_index()
	for index in SLOT_COUNT:
		var button := Button.new()
		button.custom_minimum_size.y = 72.0
		button.pressed.connect(_select_slot.bind(index))
		slots.add_child(button)
	var initial_slot: int = SaveManager.active_profile_slot if SaveManager.has_active_profile() else 0
	_select_slot(initial_slot)

func _select_slot(index: int) -> void:
	selected_slot = index
	var info: Dictionary = SaveManager.get_profile_summary(index)
	name_edit.text = String(info.get("name", ""))
	name_edit.editable = not bool(info.get("exists", false))
	_refresh()

func _refresh() -> void:
	for index in SLOT_COUNT:
		var info: Dictionary = SaveManager.get_profile_summary(index)
		var button: Button = slots.get_child(index)
		button.text = "PROFILE %d\n%s" % [index + 1, String(info.get("name", "NEW PROFILE")) if bool(info.get("exists", false)) else "NEW PROFILE"]
		button.button_pressed = index == selected_slot
	start_button.disabled = selected_slot < 0
	clear_button.disabled = selected_slot < 0 or not SaveManager.profile_exists(selected_slot)

func _on_start_pressed() -> void:
	if selected_slot < 0:
		return
	if not SaveManager.profile_exists(selected_slot):
		var profile_name := name_edit.text.strip_edges()
		if profile_name.is_empty():
			profile_name = "Player %d" % (selected_slot + 1)
		SaveManager.create_profile(selected_slot, profile_name)
	if SaveManager.select_profile(selected_slot):
		GameManager.initialize_active_profile()
		get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

func _on_clear_pressed() -> void:
	if selected_slot < 0 or not SaveManager.profile_exists(selected_slot):
		return
	confirmation.dialog_text = "Delete this profile's progression and run history?\n\nThe other profiles will not be affected. This cannot be undone."
	confirmation.popup_centered()

func _on_clear_confirmed() -> void:
	SaveManager.clear_profile(selected_slot)
	name_edit.text = ""
	name_edit.editable = true
	_refresh()
