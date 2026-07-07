extends Control

@onready var list: VBoxContainer = $Margin/Panel/VBox/Scroll/List

func _ready() -> void:
	for child in list.get_children():
		child.queue_free()
	for row_data in MissionManager.get_mission_rows():
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 104)
		var card_box := VBoxContainer.new()
		card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_box.add_theme_constant_override("separation", 6)
		card.add_child(card_box)
		var title := Label.new()
		title.add_theme_font_size_override("font_size", 20)
		title.text = "%s %s" % [row_data["title"], "(DONE)" if row_data["completed"] else ""]
		title.modulate = Color("7be495") if row_data["completed"] else Color.WHITE
		var description := Label.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.text = row_data["description"]
		var progress := Label.new()
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.text = "Progress: %d / %d | Reward: %d coins" % [row_data["progress"], row_data["target"], row_data["reward_coins"]]
		card_box.add_child(title)
		card_box.add_child(description)
		card_box.add_child(progress)
		list.add_child(card)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
