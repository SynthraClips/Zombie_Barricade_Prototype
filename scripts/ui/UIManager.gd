extends CanvasLayer
class_name UIManager

@onready var hud: Control = $HUD
@onready var distance_label: Label = $HUD/Margin/VBox/Distance
@onready var squad_label: Label = $HUD/Margin/VBox/Squad
@onready var coins_label: Label = $HUD/Margin/VBox/Coins
@onready var resources_label: Label = $HUD/Margin/VBox/Resources
@onready var wave_label: Label = $HUD/Margin/VBox/Wave
@onready var route_label: Label = $HUD/Margin/VBox/Route
@onready var pressure_label: Label = $HUD/Margin/VBox/Pressure
@onready var pressure_bar: ProgressBar = $HUD/Margin/VBox/PressureBar
@onready var mutation_label: Label = $HUD/Margin/VBox/Mutation
@onready var objective_label: Label = $HUD/Margin/VBox/Objective
@onready var barricade_label: Label = $HUD/Margin/VBox/Barricade
@onready var weapon_label: Label = $HUD/Margin/VBox/Weapon
@onready var special_ammo_label: Label = $HUD/Margin/VBox/SpecialAmmo
@onready var hero_label: Label = $HUD/Margin/VBox/Hero

var active_status_messages: Array[Label] = []
@onready var deploy_barricade_button: Button = $HUD/ActionPanel/Margin/Buttons/DeployBarricade
@onready var call_hero_button: Button = $HUD/ActionPanel/Margin/Buttons/CallHero
@onready var hero_ultimate_button: Button = $HUD/ActionPanel/Margin/Buttons/HeroUltimate
@onready var start_hint: Label = $HUD/StartHint
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
@onready var end_missions: Button = $EndPanel/VBox/Missions
@onready var end_menu: Button = $EndPanel/VBox/Menu
@onready var post_boss_panel: Panel = $PostBossPanel
@onready var post_boss_title: Label = $PostBossPanel/Margin/VBox/Title
@onready var post_boss_summary: Label = $PostBossPanel/Margin/VBox/Summary
@onready var post_boss_buttons: VBoxContainer = $PostBossPanel/Margin/VBox/Buttons

var run_manager: Node
var start_hint_time_remaining := 7.0

func setup(run: Node) -> void:
	run_manager = run
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_pause_ui_process_mode(self)
	run_manager.coins_changed.connect(_on_coins_changed)
	run_manager.resources_changed.connect(_on_resources_changed)
	run_manager.distance_changed.connect(_on_distance_changed)
	run_manager.wave_changed.connect(_on_wave_changed)
	run_manager.squad_changed.connect(_on_squad_changed)
	run_manager.mutation_changed.connect(_on_mutation_changed)
	run_manager.pressure_changed.connect(_on_pressure_changed)
	run_manager.run_ended.connect(_on_run_ended)
	run_manager.post_boss_choice_opened.connect(show_post_boss_choice)
	run_manager.post_boss_choice_closed.connect(_on_post_boss_choice_closed)
	_on_coins_changed(run_manager.coins)
	_on_resources_changed(run_manager.supplies, run_manager.survivors)
	_on_distance_changed(run_manager.distance_travelled)
	_on_wave_changed(run_manager.current_wave)
	_on_squad_changed(run_manager.squad_manager.get_soldier_count())
	_on_mutation_changed(run_manager.mutation_manager.get_active_mutation_state())
	_on_pressure_changed(run_manager.get_pressure_state())
	_update_route_label()
	_update_objective()
	pause_panel.visible = false
	end_panel.visible = false
	post_boss_panel.visible = false
	hit_flash.modulate.a = 0.0
	start_hint.visible = true
	start_hint_time_remaining = 7.0
	if not pause_resume.pressed.is_connected(_on_pause_resume):
		pause_resume.pressed.connect(_on_pause_resume)
		pause_menu.pressed.connect(_on_menu_pressed)
		end_replay.pressed.connect(_on_replay_pressed)
		end_upgrade.pressed.connect(_on_upgrade_pressed)
		end_missions.pressed.connect(_on_missions_pressed)
		end_menu.pressed.connect(_on_menu_pressed)
	if not deploy_barricade_button.pressed.is_connected(_on_deploy_barricade_pressed):
		deploy_barricade_button.pressed.connect(_on_deploy_barricade_pressed)
		call_hero_button.pressed.connect(_on_call_hero_pressed)
		hero_ultimate_button.pressed.connect(_on_hero_ultimate_pressed)

func _process(delta: float) -> void:
	if hit_flash.modulate.a > 0.0:
		hit_flash.modulate.a = max(hit_flash.modulate.a - delta * 2.5, 0.0)
	if run_manager != null:
		if start_hint_time_remaining > 0.0 and not get_tree().paused:
			start_hint_time_remaining = max(start_hint_time_remaining - delta, 0.0)
			start_hint.visible = start_hint_time_remaining > 0.0
		var barricade: Node = run_manager.barricade_manager.active_barricade
		var barricade_name: String = String(run_manager.barricade_manager.get_selected_barricade_definition().get("name", "Barricade"))
		var cooldown: float = run_manager.barricade_manager.deploy_cooldown
		barricade_label.text = "Deploy Barricade [B]: %s" % barricade_name
		if barricade == null or not is_instance_valid(barricade):
			barricade_label.text += " | %s" % ("READY" if cooldown <= 0.0 else "%.1fs" % cooldown)
		else:
			barricade_label.text += " | %d/%d HP" % [int(barricade.hp), int(barricade.max_hp)]
		var barricade_ready := (barricade == null or not is_instance_valid(barricade)) and cooldown <= 0.0
		deploy_barricade_button.disabled = not barricade_ready
		if barricade_ready:
			deploy_barricade_button.text = "Deploy Barricade [B]"
		elif cooldown > 0.0:
			deploy_barricade_button.text = "Barricade Cooldown %.1fs" % cooldown
		else:
			deploy_barricade_button.text = "Barricade Deployed"
		weapon_label.text = "Weapon: %s%s" % [run_manager.weapon_manager.get_current_weapon_id().replace("_", " ").capitalize(), " | Auto" if bool(SaveManager.save_data.get("settings", {}).get("auto_fire", false)) else ""]
		var hero_state: Dictionary = run_manager.get_hero_state()
		if String(hero_state.get("id", "")) == "":
			hero_label.visible = true
			hero_label.text = "Call Hero [H]: No Hero Selected"
			call_hero_button.text = "No Hero Selected"
			call_hero_button.disabled = true
			hero_ultimate_button.text = "Ultimate [U] - No Hero"
			hero_ultimate_button.disabled = true
		else:
			hero_label.visible = true
			var hero_active: bool = bool(hero_state.get("active", false))
			var hero_cooldown: float = float(hero_state.get("cooldown_remaining", 0.0))
			var hero_uses: int = int(hero_state.get("uses_remaining", 0))
			var ultimate_ready: bool = hero_active and bool(hero_state.get("ultimate_ready", false))
			var hero_suffix: String = " | ACTIVE %.1fs" % float(hero_state.get("time_remaining", 0.0)) if hero_active else " | CD %.1fs" % hero_cooldown if hero_cooldown > 0.0 else " | READY" if hero_uses > 0 else " | NO CALL-INS"
			var ultimate_suffix: String = " | ULT READY [U]" if ultimate_ready else " | ULT USED" if hero_active else " | ULT NOT READY"
			var spec_state: Dictionary = run_manager.get_specialist_state()
			hero_label.text = "Call Hero [H]: %s%s%s | Specs %d" % [String(hero_state.get("name", "Hero")), hero_suffix, ultimate_suffix, int(spec_state.get("count", 0))]
			call_hero_button.disabled = hero_active or hero_cooldown > 0.0 or hero_uses <= 0
			if not call_hero_button.disabled:
				call_hero_button.text = "Call Hero [H]"
			elif hero_active:
				call_hero_button.text = "Hero Active %.1fs" % float(hero_state.get("time_remaining", 0.0))
			elif hero_cooldown > 0.0:
				call_hero_button.text = "Hero Cooldown %.1fs" % hero_cooldown
			else:
				call_hero_button.text = "No Call-ins Remaining"
			hero_ultimate_button.disabled = not ultimate_ready
			hero_ultimate_button.text = "Ultimate [U]" if ultimate_ready else "Ultimate [U] - Not Ready"
		var ammo_state: Dictionary = run_manager.weapon_manager.get_special_ammo_state()
		var limited_state: Dictionary = run_manager.weapon_manager.get_limited_ammo_state()
		if String(ammo_state.get("type", "")) == "" and String(limited_state.get("weapon_id", "")) == "":
			special_ammo_label.visible = false
			special_ammo_label.text = ""
		elif String(limited_state.get("weapon_id", "")) != "":
			special_ammo_label.visible = true
			special_ammo_label.text = "Ammo: %s %d/%d" % [String(limited_state.get("label", "LIMITED")).to_upper(), int(limited_state.get("current", 0)), int(limited_state.get("maximum", 0))]
		else:
			special_ammo_label.visible = true
			special_ammo_label.text = "Ammo: %s | %.1fs" % [String(ammo_state.get("label", "SPECIAL")), float(ammo_state.get("time_remaining", 0.0))]
		_update_pressure_visuals()
		_update_mutation_label()
		_update_route_label()
		_update_objective()

func _on_coins_changed(value: int) -> void:
	coins_label.text = "Coins: %d" % value
	_pulse_label(coins_label, Color("f5d142"))

func _on_resources_changed(supplies: int, survivors: int) -> void:
	resources_label.text = "Supplies: %d | Survivors: %d" % [supplies, survivors]

func _on_distance_changed(value: float) -> void:
	distance_label.text = "Distance: %dm / %dm" % [int(value), int(run_manager.target_distance)]

func _on_wave_changed(value: int) -> void:
	wave_label.text = "Wave: %d" % value

func _update_route_label() -> void:
	if run_manager == null:
		route_label.visible = false
		return
	var route_state: Dictionary = run_manager.get_route_status_state()
	if not bool(route_state.get("active", false)):
		route_label.visible = true
		route_label.text = "Route: %s | %s" % [String(route_state.get("route_type_title", "Balanced Route")), String(route_state.get("run_modifier_title", "No Modifier"))]
		return
	route_label.visible = true
	var reward_multiplier: float = float(route_state.get("reward_multiplier", 1.0))
	var suffix: String = " | x%.2f coins" % reward_multiplier if reward_multiplier > 1.0 else ""
	route_label.text = "Route: %s | %s%s" % [String(route_state.get("route_type_title", "Balanced Route")), String(route_state.get("title", "Extended Route")), suffix]

func _on_squad_changed(value: int) -> void:
	squad_label.text = "Squad: %d" % value
	_pulse_label(squad_label, Color("7be495"))

func _on_mutation_changed(_state: Dictionary) -> void:
	_update_mutation_label()

func _on_pressure_changed(state: Dictionary) -> void:
	if not bool(state.get("enabled", false)):
		pressure_label.visible = false
		pressure_bar.visible = false
		return
	pressure_label.visible = true
	pressure_bar.visible = true
	pressure_bar.max_value = float(state.get("max_value", 100.0))
	pressure_bar.value = float(state.get("value", 0.0))
	var reward_multiplier: float = float(state.get("reward_multiplier", 1.0))
	var reward_suffix: String = " | x%.2f coins" % reward_multiplier if reward_multiplier > 1.0 else ""
	pressure_label.text = "Horde Pressure: %s%s" % [String(state.get("label", "Low")), reward_suffix]
	_update_pressure_visuals()

func _update_mutation_label() -> void:
	var mutation_state: Dictionary = run_manager.mutation_manager.get_active_mutation_state() if run_manager != null and run_manager.mutation_manager != null else {}
	var mutation_id: String = String(mutation_state.get("id", ""))
	var evolution_labels: Array = mutation_state.get("evolution_labels", [])
	if mutation_id == "" and evolution_labels.is_empty():
		mutation_label.visible = false
		mutation_label.text = ""
		return
	mutation_label.visible = true
	var reward_multiplier: float = float(mutation_state.get("reward_multiplier", 1.0))
	var reward_suffix: String = " | x%.2f rewards" % reward_multiplier if reward_multiplier > 1.0 else ""
	var timed_text := "Mutation: %s %.1fs" % [String(mutation_state.get("label", mutation_id)), float(mutation_state.get("time_remaining", 0.0))] if mutation_id != "" else ""
	var evolution_text := "Evolution: %s" % ", ".join(evolution_labels) if not evolution_labels.is_empty() else ""
	mutation_label.text = "%s%s%s" % [timed_text, " | " if timed_text != "" and evolution_text != "" else "", evolution_text + reward_suffix]

func _update_pressure_visuals() -> void:
	if run_manager == null or not run_manager.is_horde_pressure_enabled():
		return
	var tier: String = run_manager.get_pressure_tier()
	var pulse_strength: float = 0.0
	var bar_color := Color("9bd4ff")
	match tier:
		"medium":
			bar_color = Color("ffd166")
		"high":
			bar_color = Color("ff9f5c")
			pulse_strength = 0.18
		"surge":
			bar_color = Color("ff6b6b")
			pulse_strength = 0.32
	if pulse_strength > 0.0:
		var pulse: float = 0.82 + absf(sin(Time.get_ticks_msec() / 140.0)) * pulse_strength
		pressure_label.modulate = bar_color.lerp(Color.WHITE, clampf(1.0 - pulse, 0.0, 1.0))
		pressure_bar.modulate = Color(1.0, 1.0, 1.0, clampf(pulse, 0.0, 1.0))
	else:
		pressure_label.modulate = bar_color
		pressure_bar.modulate = Color.WHITE

func _update_objective() -> void:
	if run_manager != null and run_manager.mini_objective_label != "":
		objective_label.text = "Objective: %s" % run_manager.mini_objective_label
		return
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
	elif text.find("ROUNDS") >= 0:
		_pulse_label(special_ammo_label, color)
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
	_prune_status_messages()
	if active_status_messages.size() >= 3:
		var oldest: Label = active_status_messages.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_reposition_status_messages()
	var label := Label.new()
	label.text = text
	label.position = Vector2(330.0, 92.0 + active_status_messages.size() * 34.0)
	label.size = Vector2(420.0, 40.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = color
	popup_layer.add_child(label)
	active_status_messages.append(label)
	var tween := create_tween()
	tween.tween_interval(0.35)
	tween.tween_property(label, "modulate:a", 0.0, 0.75)
	tween.finished.connect(_finish_status_message.bind(label.get_instance_id()))

func _finish_status_message(label_instance_id: int) -> void:
	for index in range(active_status_messages.size() - 1, -1, -1):
		var active_label: Label = active_status_messages[index]
		if not is_instance_valid(active_label):
			active_status_messages.remove_at(index)
		elif active_label.get_instance_id() == label_instance_id:
			active_status_messages.remove_at(index)
			active_label.queue_free()
	_reposition_status_messages()

func _prune_status_messages() -> void:
	for index in range(active_status_messages.size() - 1, -1, -1):
		if not is_instance_valid(active_status_messages[index]):
			active_status_messages.remove_at(index)

func _reposition_status_messages() -> void:
	for index in active_status_messages.size():
		if is_instance_valid(active_status_messages[index]):
			active_status_messages[index].position.y = 92.0 + index * 34.0

func toggle_pause() -> void:
	if post_boss_panel.visible:
		return
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_panel.visible = paused

func show_post_boss_choice(options: Array) -> void:
	post_boss_panel.visible = true
	pause_panel.visible = false
	end_panel.visible = false
	post_boss_title.text = "Boss Down. Pick The Next Route."
	post_boss_summary.text = "Extract now to bank the run, or push the convoy deeper for a stronger route bonus."
	for child in post_boss_buttons.get_children():
		child.queue_free()
	var first_button: Button
	for option in options:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 68.0)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 18)
		button.text = "%s\n%s" % [String(option.get("title", "")), String(option.get("description", ""))]
		button.add_theme_color_override("font_color", Color(String(option.get("button_color", "#ffffff"))))
		button.pressed.connect(func() -> void:
			_on_post_boss_choice_pressed(String(option.get("id", "")))
		)
		post_boss_buttons.add_child(button)
		if first_button == null:
			first_button = button
	if first_button != null:
		first_button.grab_focus()

func _on_post_boss_choice_pressed(choice_id: String) -> void:
	if run_manager != null:
		run_manager.select_post_boss_route(choice_id)

func _on_post_boss_choice_closed(_state: Dictionary) -> void:
	post_boss_panel.visible = false

func show_end_screen(victory: bool, summary: Dictionary) -> void:
	get_tree().paused = false
	post_boss_panel.visible = false
	end_panel.visible = true
	end_title.text = "Run Complete" if victory else "Game Over"
	var route_type_text: String = String(summary.get("route_type_title", "Balanced Route"))
	var modifier_text: String = String(summary.get("run_modifier_title", "No Modifier"))
	var best_line := ""
	if bool(summary.get("new_best_distance", false)) or bool(summary.get("new_best_coins", false)):
		var tags: Array[String] = []
		if bool(summary.get("new_best_distance", false)):
			tags.append("New Best Distance")
		if bool(summary.get("new_best_coins", false)):
			tags.append("New Best Coins")
		best_line = "\n%s" % ", ".join(tags)
	end_summary.text = "Distance %dm | Score %d\nCoins %d | Supplies %d | Survivors %d\nKills %d | Mutated Animals %d | Bosses %d\nPickups %d | Gates %d | Night Sections %d\nMutations %d | Hero Calls %d | Ultimates %d\nRoute %s | Modifier %s\nSquad %d%s" % [
		int(summary.get("distance", 0)),
		int(summary.get("score", 0)),
		int(summary.get("coins_earned", 0)),
		int(summary.get("supplies_earned", 0)),
		int(summary.get("survivors_earned", 0)),
		int(summary.get("kills", 0)),
		int(summary.get("mutated_animals_killed", 0)),
		int(summary.get("bosses_defeated", summary.get("boss_kills", 0))),
		int(summary.get("pickups_collected", 0)),
		int(summary.get("gates_chosen", 0)),
		int(summary.get("night_sections", 0)),
		summary.get("mutation_history", []).size(),
		int(summary.get("hero_uses", 0)),
		int(summary.get("hero_ultimates", 0)),
		route_type_text,
		modifier_text,
		int(summary.get("final_soldiers", 0)),
		best_line
	]
	var specialist_count: int = 0
	var specialists_value = summary.get("specialists_rescued", [])
	if specialists_value is Array:
		specialist_count = specialists_value.size()
	if int(summary.get("mini_objectives_completed", 0)) > 0 or specialist_count > 0:
		end_summary.text += "\nMini Objectives %d | Specialists %d" % [int(summary.get("mini_objectives_completed", 0)), specialist_count]

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

func _on_deploy_barricade_pressed() -> void:
	if run_manager != null:
		run_manager.request_deploy_barricade()

func _on_call_hero_pressed() -> void:
	if run_manager != null:
		run_manager.request_call_hero()

func _on_hero_ultimate_pressed() -> void:
	if run_manager != null:
		run_manager.request_hero_ultimate()

func _on_replay_pressed() -> void:
	get_tree().paused = false
	GameManager.start_run()

func _on_upgrade_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/UpgradeScreen.tscn")

func _on_missions_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MissionScreen.tscn")

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

func _set_pause_ui_process_mode(root: Node) -> void:
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	for child in root.get_children():
		_set_pause_ui_process_mode(child)
