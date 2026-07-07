extends Control

@onready var coins_label: Label = $Margin/Panel/VBox/Coins
@onready var list: VBoxContainer = $Margin/Panel/VBox/Scroll/List

func _ready() -> void:
	_build_rows()

func _build_rows() -> void:
	coins_label.text = "Saved Coins: %d" % int(SaveManager.save_data.get("banked_coins", 0))
	for child in list.get_children():
		child.queue_free()
	for upgrade_id in UpgradeManager.upgrade_defs.keys():
		var def: Dictionary = UpgradeManager.upgrade_defs[upgrade_id]
		var row := PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 118)
		var row_box := VBoxContainer.new()
		row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_theme_constant_override("separation", 6)
		row.add_child(row_box)
		var top_row := HBoxContainer.new()
		top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = "%s  Lv.%d" % [String(def.get("title", upgrade_id)), UpgradeManager.get_level(upgrade_id)]
		name_label.add_theme_font_size_override("font_size", 20)
		var state_label := Label.new()
		state_label.text = "Affordable" if UpgradeManager.can_purchase(upgrade_id) else "Locked"
		state_label.modulate = Color("7be495") if UpgradeManager.can_purchase(upgrade_id) else Color("ff9a7d")
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top_row.add_child(name_label)
		top_row.add_child(state_label)
		var detail_label := Label.new()
		detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var next_value := _describe_upgrade(upgrade_id, def)
		detail_label.text = next_value
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.text = "Buy %d" % UpgradeManager.get_cost(upgrade_id)
		button.disabled = not UpgradeManager.can_purchase(upgrade_id)
		button.pressed.connect(func():
			if UpgradeManager.purchase(upgrade_id):
				_build_rows()
		)
		row_box.add_child(top_row)
		row_box.add_child(detail_label)
		row_box.add_child(button)
		list.add_child(row)

func _describe_upgrade(upgrade_id: String, def: Dictionary) -> String:
	var level: int = UpgradeManager.get_level(upgrade_id)
	var max_level: int = int(def.get("max_level", 1))
	if String(def.get("type", "")) == "choice":
		var current := UpgradeManager.get_choice_value(upgrade_id)
		if current == "":
			current = String(def.get("choices", ["rifleman"])[0])
		var next_index: int = min(level + 1, max(max_level, 1))
		var choices: Array = def.get("choices", [])
		var next_choice: String = String(choices[min(next_index, max(choices.size() - 1, 0))]) if not choices.is_empty() else current
		return "Current: %s\nNext: %s\nCost: %d" % [current.replace("_", " ").capitalize(), next_choice.replace("_", " ").capitalize(), UpgradeManager.get_cost(upgrade_id)]
	var current_bonus: float = UpgradeManager.get_upgrade_value(upgrade_id)
	var next_bonus: float = float(def.get("base", 0.0)) + float(def.get("per_level", 0.0)) * min(level + 1, max_level)
	return "Current Bonus: %.2f\nNext Bonus: %.2f\nCost: %d" % [current_bonus, next_bonus, UpgradeManager.get_cost(upgrade_id)]

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
