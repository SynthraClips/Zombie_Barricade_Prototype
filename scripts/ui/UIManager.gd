extends CanvasLayer
class_name UIManager

@onready var hud: Control = $HUD
@onready var distance_label: Label = $HUD/Margin/VBox/Distance
@onready var squad_label: Label = $HUD/Margin/VBox/Squad
@onready var coins_label: Label = $HUD/Margin/VBox/Coins
@onready var wave_label: Label = $HUD/Margin/VBox/Wave
@onready var objective_label: Label = $HUD/Margin/VBox/Objective
@onready var barricade_label: Label = $HUD/Margin/VBox/Barricade
@onready var weapon_label: Label = $HUD/Margin/VBox/Weapon
@onready var popup_layer: Control = $PopupLayer
@onready var hit_flash: ColorRect = $HitFlash
@onready var pause_panel: Panel = $PausePanel
@onready var end_panel: Panel = $EndPanel
@onready var end_title: Label = $EndPanel/VBox/Title
@onready var end_summary: Label = $EndPanel/VBox/Summary
@onready var pause_resume: Button = $PausePanel/VBox/Resume
@onready var pause_menu: Button = $PausePanel/VBox/Menu
@onready var end_replay: Button = $EndPanel/VBox/Replay
@onready var end_upgrade: Button = $EndPanel/VBox/Upgrade
@onready var end_menu: Button = $EndPanel/VBox/Menu

var run_manager: Node

func setup(run: Node) -> void:
	run_manager = run
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_pause_ui_process_mode(self)
	run_manager.coins_changed.connect(_on_coins_changed)
	run_manager.distance_changed.connect(_on_distance_changed)
	run_manager.wave_changed.connect(_on_wave_changed)
	run_manager.squad_changed.connect(_on_squad_changed)
	run_manager.run_ended.connect(_on_run_ended)
	_on_coins_changed(run_manager.coins)
	_on_distance_changed(run_manager.distance_travelled)
	_on_wave_changed(run_manager.current_wave)
	_on_squad_changed(run_manager.squad_manager.get_soldier_count())
	_update_objective()
	pause_panel.visible = false
	end_panel.visible = false
	hit_flash.modulate.a = 0.0
	if not pause_resume.pressed.is_connected(_on_pause_resume):
		pause_resume.pressed.connect(_on_pause_resume)
		pause_menu.pressed.connect(_on_menu_pressed)
		end_replay.pressed.connect(_on_replay_pressed)
		end_upgrade.pressed.connect(_on_upgrade_pressed)
		end_menu.pressed.connect(_on_menu_pressed)

func _process(delta: float) -> void:
	if hit_flash.modulate.a > 0.0:
		hit_flash.modulate.a = max(hit_flash.modulate.a - delta * 2.5, 0.0)
	if run_manager != null:
		var barricade: Node = run_manager.barricade_manager.active_barricade
		var barricade_name: String = String(run_manager.barricade_manager.get_selected_barricade_definition().get("name", "Barricade"))
		var cooldown: float = run_manager.barricade_manager.deploy_cooldown
		barricade_label.text = "Barricade: %s" % barricade_name
		if barricade == null or not is_instance_valid(barricade):
			barricade_label.text += " | %s" % ("READY" if cooldown <= 0.0 else "%.1fs" % cooldown)
		else:
			barricade_label.text += " | %d/%d HP" % [int(barricade.hp), int(barricade.max_hp)]
		weapon_label.text = "Weapon: %s%s" % [run_manager.weapon_manager.get_current_weapon_id().replace("_", " ").capitalize(), " | Auto" if bool(SaveManager.save_data.get("settings", {}).get("auto_fire", false)) else ""]
		_update_objective()

func _on_coins_changed(value: int) -> void:
	coins_label.text = "Coins: %d" % value
	_pulse_label(coins_label, Color("f5d142"))

func _on_distance_changed(value: float) -> void:
	distance_label.text = "Distance: %dm / %dm" % [int(value), int(run_manager.target_distance)]

func _on_wave_changed(value: int) -> void:
	wave_label.text = "Wave: %d" % value

func _on_squad_changed(value: int) -> void:
	squad_label.text = "Squad: %d" % value
	_pulse_label(squad_label, Color("7be495"))

func _update_objective() -> void:
	var missions := MissionManager.get_mission_rows()
	for mission in missions:
		if not mission["completed"]:
			objective_label.text = "Objective: %s (%d/%d)" % [mission["title"], mission["progress"], mission["target"]]
			return
	objective_label.text = "Objective: All missions complete"

func flash_hit() -> void:
	if not bool(SaveManager.save_data.get("settings", {}).get("hit_flash", true)):
		return
	hit_flash.modulate.a = 0.25

func spawn_damage_number(world_position: Vector2, amount: float, color: Color = Color("ff6b6b")) -> void:
	var label := Label.new()
	label.text = str(int(round(amount)))
	label.position = world_position
	label.modulate = color
	popup_layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", world_position + Vector2(0, -40), 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.finished.connect(label.queue_free)

func spawn_reward_popup(world_position: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = world_position + Vector2(-20, -12)
	label.modulate = color
	label.scale = Vector2.ONE * 0.88
	popup_layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -50), 0.8)
	tween.parallel().tween_property(label, "scale", Vector2.ONE * 1.04, 0.15)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)
	if text.find("COIN") >= 0:
		_pulse_label(coins_label, color)
	elif text.find("SOLDIER") >= 0 or text.find("MEDICAL") >= 0:
		_pulse_label(squad_label, color)
	elif text.find("WEAPON") >= 0:
		_pulse_label(weapon_label, color)
	elif text.find("BARRICADE") >= 0:
		_pulse_label(barricade_label, color)

func spawn_bullet_trail(from_position: Vector2, to_position: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	line.add_point(from_position)
	line.add_point(to_position)
	popup_layer.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.12)
	tween.finished.connect(line.queue_free)

func spawn_explosion(world_position: Vector2, radius: float) -> void:
	var burst := ColorRect.new()
	burst.color = Color("ff9655", 0.8)
	burst.position = world_position - Vector2(radius, radius)
	burst.size = Vector2.ONE * radius * 2.0
	popup_layer.add_child(burst)
	var tween := create_tween()
	tween.tween_property(burst, "scale", Vector2(1.4, 1.4), 0.15)
	tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.15)
	tween.finished.connect(burst.queue_free)
	run_manager.add_screen_shake(0.12, 5.0)

func show_status_message(text: String, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(240.0, 96.0)
	label.size = Vector2(240.0, 32.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = color
	popup_layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 14.0, 0.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.1)
	tween.finished.connect(label.queue_free)

func toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_panel.visible = paused

func show_end_screen(victory: bool, summary: Dictionary) -> void:
	get_tree().paused = false
	end_panel.visible = true
	end_title.text = "Run Complete" if victory else "Game Over"
	end_summary.text = "Distance %dm\nKills %d\nCoins %d\nSquad %d" % [summary["distance"], summary["kills"], summary["coins_earned"], summary["final_soldiers"]]

func _on_run_ended(victory: bool) -> void:
	pass

func _pulse_label(label: Label, color: Color) -> void:
	label.modulate = color
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 1.05, 0.08)
	tween.parallel().tween_property(label, "modulate", Color.WHITE, 0.26)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14)

func _on_pause_resume() -> void:
	toggle_pause()

func _on_replay_pressed() -> void:
	get_tree().paused = false
	GameManager.start_run()

func _on_upgrade_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/UpgradeScreen.tscn")

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

func _set_pause_ui_process_mode(root: Node) -> void:
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	for child in root.get_children():
		_set_pause_ui_process_mode(child)
