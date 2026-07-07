extends Node2D
class_name RunManager

signal coins_changed(value: int)
signal distance_changed(value: float)
signal wave_changed(value: int)
signal squad_changed(value: int)
signal mutation_changed(state: Dictionary)
signal pressure_changed(state: Dictionary)
signal run_ended(victory: bool)
signal post_boss_choice_opened(options: Array)
signal post_boss_choice_closed(state: Dictionary)

@onready var road: Node2D = $Road
@onready var camera: Camera2D = $Camera2D
@onready var squad_manager: Node = $SquadManager
@onready var weapon_manager: Node = $WeaponManager
@onready var enemy_manager: Node = $EnemyManager
@onready var wave_spawner: Node = $WaveSpawner
@onready var barricade_manager: Node = $BarricadeManager
@onready var reward_manager: Node = $RewardManager
@onready var gate_manager: Node = $GateManager
@onready var armoury_cache_manager: Node = $ArmouryCacheManager
@onready var survivor_rescue_manager: Node = $SurvivorRescueManager
@onready var mutation_manager: Node = $MutationManager
@onready var ui_manager: CanvasLayer = $UI

var coins := 0
var distance_travelled := 0.0
var elapsed_time := 0.0
var current_wave := 1
var running := true
var target_distance := 300.0
var scroll_speed := 90.0
var max_squad_size := 8
var pressure_config: Dictionary = {}
var current_pressure := 0.0
var pressure_distance_checkpoint := 0.0
var aim_position := Vector2(360, 520)
var fire_input_held := false
var shake_time := 0.0
var shake_strength := 0.0
var run_end_locked := false
var pending_post_boss_choice := false
var post_boss_choice_selection_locked := false
var boss_choices_presented := 0
var route_choice_history: Array[String] = []
var latest_route_choice_id := ""
var latest_route_choice_title := ""
var route_reward_multiplier := 1.0
var route_difficulty_multiplier := 1.0
var route_spawn_interval_multiplier := 1.0
var route_runner_weight_multiplier := 1.0
var route_rescue_spawn_chance_bonus := 0.0
var route_rescue_spawn_distance_multiplier := 1.0
var route_gate_spawn_distance_multiplier := 1.0
var route_supply_spawn_chance_bonus := 0.0
var route_supply_spawn_distance_multiplier := 1.0
var route_armoury_cache_reward_table := ""
var run_stats := {
	"kills": 0,
	"boss_kills": 0,
	"obstacles_destroyed": 0,
	"coins_earned": 0,
	"armoury_caches_destroyed": 0,
	"survivor_rescues_completed": 0,
	"survivors_rescued": 0
}

func _ready() -> void:
	target_distance = float(GameManager.game_config.get("target_distance", 300))
	scroll_speed = float(GameManager.game_config.get("base_scroll_speed", 90.0))
	max_squad_size = int(GameManager.game_config.get("max_squad_size", 8))
	pressure_config = GameManager.game_config.get("horde_pressure", {}).duplicate(true)
	squad_manager.setup(self)
	weapon_manager.setup(self)
	enemy_manager.setup(self)
	wave_spawner.setup(self)
	barricade_manager.setup(self)
	reward_manager.setup(self)
	gate_manager.setup(self)
	armoury_cache_manager.setup(self)
	survivor_rescue_manager.setup(self)
	mutation_manager.setup(self)
	ui_manager.setup(self)
	aim_position = Vector2(360, road.get_squad_y() - 260.0)
	reset_horde_pressure(false)
	coins_changed.emit(coins)
	distance_changed.emit(distance_travelled)
	wave_changed.emit(current_wave)
	squad_changed.emit(squad_manager.get_soldier_count())
	notify_mutation_state_changed()
	pressure_changed.emit(get_pressure_state())

func _process(delta: float) -> void:
	if not running:
		_update_camera(delta)
		return
	_sync_pointer_target()
	if Input.is_action_just_pressed("deploy_barricade"):
		if not barricade_manager.deploy_current_barricade():
			ui_manager.show_status_message("BARRICADE RECHARGING", Color("ffb36b"))
	if Input.is_action_just_pressed("pause_run"):
		ui_manager.toggle_pause()
	_update_camera(delta)
	if get_tree().paused:
		return
	elapsed_time += delta
	distance_travelled += scroll_speed * delta / 10.0
	update_horde_pressure(delta)
	road.queue_redraw()
	squad_manager.update_squad(delta)
	reward_manager.update_rewards(delta)
	gate_manager.update_gates(delta)
	armoury_cache_manager.update_caches(delta)
	survivor_rescue_manager.update_rescues(delta)
	barricade_manager.update_barricade(delta)
	enemy_manager.update_enemies(delta)
	mutation_manager.update_mutations(delta)
	wave_spawner.update_spawner(delta)
	distance_changed.emit(distance_travelled)
	if distance_travelled >= target_distance:
		finish_run(true)

func _update_camera(delta: float) -> void:
	if shake_time > 0.0:
		shake_time -= delta
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	else:
		camera.offset = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if not running or get_tree().paused:
		return
	if event is InputEventMouseMotion:
		update_aim_position(event.position)
		squad_manager.handle_pointer_input(event.position)
	elif event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			update_aim_position(button_event.position)
			set_fire_input_held(button_event.pressed)
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			update_aim_position(touch_event.position)
			squad_manager.handle_pointer_input(touch_event.position, true)
			set_fire_input_held(true)
		else:
			squad_manager.release_touch_input()
			set_fire_input_held(false)
	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		update_aim_position(drag_event.position)
		squad_manager.handle_pointer_input(drag_event.position, true)
		set_fire_input_held(true)

func _sync_pointer_target() -> void:
	if squad_manager.touch_input_active:
		return
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	update_aim_position(mouse_position)
	squad_manager.handle_pointer_input(mouse_position)
	set_fire_input_held(Input.is_action_pressed("fire_weapon"))

func update_aim_position(screen_position: Vector2) -> void:
	aim_position = screen_position

func get_aim_position() -> Vector2:
	return aim_position

func should_fire() -> bool:
	if not running or get_tree().paused or pending_post_boss_choice:
		return false
	if is_auto_fire_enabled():
		return true
	return fire_input_held

func is_auto_fire_enabled() -> bool:
	return bool(SaveManager.save_data.get("settings", {}).get("auto_fire", GameManager.game_config.get("auto_fire_default", true)))

func set_fire_input_held(value: bool) -> void:
	fire_input_held = value

func extend_target_distance(amount: int) -> void:
	target_distance += max(amount, 0)
	distance_changed.emit(distance_travelled)

func add_screen_shake(duration: float, strength: float) -> void:
	if not SaveManager.save_data.get("settings", {}).get("screenshake", true):
		return
	shake_time = max(shake_time, duration)
	shake_strength = max(shake_strength, strength)

func add_coins(amount: int) -> int:
	var bonus_multiplier: float = 1.0 + UpgradeManager.get_upgrade_value("coin_gain")
	var pressure_multiplier: float = get_pressure_reward_multiplier()
	var mutation_multiplier: float = mutation_manager.get_reward_multiplier() if mutation_manager != null else 1.0
	var final_amount: int = int(round(amount * bonus_multiplier * pressure_multiplier * mutation_multiplier * route_reward_multiplier))
	coins += final_amount
	run_stats["coins_earned"] += final_amount
	coins_changed.emit(coins)
	return final_amount

func spend_run_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

func set_wave(value: int) -> void:
	current_wave = value
	wave_changed.emit(current_wave)

func register_kill(enemy_id: String) -> void:
	run_stats["kills"] += 1
	SaveManager.save_data["stats"]["lifetime_kills"] += 1
	MissionManager.increment_progress("kills", 1)
	if enemy_id == "boss":
		run_stats["boss_kills"] += 1
		SaveManager.save_data["stats"]["boss_kills"] += 1
		MissionManager.increment_progress("boss_kills", 1)
		reduce_horde_pressure_for("boss_defeated")
		on_boss_defeated()

func register_obstacle_destroyed() -> void:
	run_stats["obstacles_destroyed"] += 1
	SaveManager.save_data["stats"]["lifetime_obstacles_destroyed"] += 1
	MissionManager.increment_progress("obstacles_destroyed", 1)

func register_armoury_cache_destroyed() -> void:
	run_stats["armoury_caches_destroyed"] += 1
	SaveManager.save_data["stats"]["armoury_caches_destroyed"] += 1
	MissionManager.increment_progress("armoury_caches_destroyed", 1)
	reduce_horde_pressure_for("armoury_cache_destroyed")

func register_survivor_rescue(soldiers_added: int) -> void:
	run_stats["survivor_rescues_completed"] += 1
	run_stats["survivors_rescued"] += max(soldiers_added, 0)
	reduce_horde_pressure_for("survivor_rescue_completed")

func register_special_event_completed(_event_id: String = "") -> void:
	reduce_horde_pressure_for("special_event_completed")

func on_squad_count_changed() -> void:
	squad_changed.emit(squad_manager.get_soldier_count())

func get_difficulty_multiplier() -> float:
	var distance_factor: float = distance_travelled / max(target_distance, 1.0)
	var wave_factor: float = float(current_wave - 1) * 0.12
	var time_factor: float = elapsed_time / 90.0
	return (1.0 + distance_factor * 0.55 + wave_factor + time_factor * 0.25) * route_difficulty_multiplier

func update_horde_pressure(delta: float) -> void:
	if not is_horde_pressure_enabled():
		return
	var gain_per_second: float = float(pressure_config.get("gain_per_second", 0.0))
	var gain_per_distance: float = float(pressure_config.get("gain_per_distance", 0.0))
	var distance_delta: float = max(distance_travelled - pressure_distance_checkpoint, 0.0)
	pressure_distance_checkpoint = distance_travelled
	var pressure_gain: float = delta * gain_per_second + distance_delta * gain_per_distance
	if pressure_gain > 0.0:
		set_horde_pressure(current_pressure + pressure_gain, "passive_gain")

func reset_horde_pressure(emit_signal: bool = true) -> void:
	var start_value: float = float(pressure_config.get("start_value", 0.0))
	current_pressure = clampf(start_value, 0.0, get_horde_pressure_max())
	pressure_distance_checkpoint = distance_travelled
	if emit_signal:
		pressure_changed.emit(get_pressure_state())

func set_horde_pressure(value: float, reason: String = "") -> void:
	if not is_horde_pressure_enabled():
		current_pressure = 0.0
		pressure_changed.emit(get_pressure_state())
		return
	var previous_tier: String = get_pressure_tier()
	current_pressure = clampf(value, 0.0, get_horde_pressure_max())
	pressure_changed.emit(get_pressure_state())
	var new_tier: String = get_pressure_tier()
	if _get_pressure_tier_rank(new_tier) > _get_pressure_tier_rank(previous_tier):
		_show_pressure_warning_for_tier(new_tier, reason)

func reduce_horde_pressure_for(reason_key: String) -> void:
	if not is_horde_pressure_enabled():
		return
	var reduction_values: Dictionary = pressure_config.get("reduction_values", {})
	var reduction: float = float(reduction_values.get(reason_key, 0.0))
	if reduction <= 0.0:
		return
	set_horde_pressure(current_pressure - reduction, reason_key)

func is_horde_pressure_enabled() -> bool:
	return bool(pressure_config.get("enabled", false))

func get_horde_pressure_max() -> float:
	return max(1.0, float(pressure_config.get("max_pressure", 100.0)))

func get_pressure_ratio() -> float:
	if not is_horde_pressure_enabled():
		return 0.0
	return clampf(current_pressure / get_horde_pressure_max(), 0.0, 1.0)

func get_pressure_tier() -> String:
	var thresholds: Dictionary = pressure_config.get("thresholds", {})
	if current_pressure >= float(thresholds.get("surge", 85.0)):
		return "surge"
	if current_pressure >= float(thresholds.get("high", 60.0)):
		return "high"
	if current_pressure >= float(thresholds.get("medium", 30.0)):
		return "medium"
	return "low"

func get_pressure_label() -> String:
	match get_pressure_tier():
		"medium":
			return "Medium"
		"high":
			return "High"
		"surge":
			return "Surging"
		_:
			return "Low"

func get_pressure_state() -> Dictionary:
	return {
		"enabled": is_horde_pressure_enabled(),
		"value": current_pressure,
		"max_value": get_horde_pressure_max(),
		"ratio": get_pressure_ratio(),
		"tier": get_pressure_tier(),
		"label": get_pressure_label(),
		"reward_multiplier": get_pressure_reward_multiplier()
	}

func get_pressure_spawn_interval_multiplier() -> float:
	var cap_multiplier: float = float(pressure_config.get("spawn_interval_multiplier_at_max", 1.0))
	return lerpf(1.0, cap_multiplier, get_pressure_ratio()) * route_spawn_interval_multiplier

func get_pressure_runner_weight_multiplier() -> float:
	var cap_multiplier: float = float(pressure_config.get("runner_weight_multiplier_at_max", 1.0))
	return lerpf(1.0, cap_multiplier, get_pressure_ratio()) * route_runner_weight_multiplier

func get_pressure_mutation_interval_scale() -> float:
	var cap_scale: float = float(pressure_config.get("mutation_interval_scale_at_max", 1.0))
	return lerpf(1.0, cap_scale, get_pressure_ratio())

func get_pressure_reward_multiplier() -> float:
	var cap_multiplier: float = float(pressure_config.get("reward_multiplier_at_max", 1.0))
	return lerpf(1.0, cap_multiplier, get_pressure_ratio())

func get_pressure_high_value_event_bonus() -> float:
	var cap_bonus: float = float(pressure_config.get("high_value_event_chance_bonus_at_max", 0.0))
	return lerpf(0.0, cap_bonus, get_pressure_ratio())

func get_route_status_state() -> Dictionary:
	return {
		"active": latest_route_choice_id != "",
		"choice_id": latest_route_choice_id,
		"title": latest_route_choice_title,
		"history_count": route_choice_history.size(),
		"reward_multiplier": route_reward_multiplier,
		"difficulty_multiplier": route_difficulty_multiplier,
		"rescue_bonus": route_rescue_spawn_chance_bonus,
		"supply_bonus": route_supply_spawn_chance_bonus
	}

func get_route_rescue_spawn_chance_bonus() -> float:
	return route_rescue_spawn_chance_bonus

func get_route_rescue_spawn_distance_multiplier() -> float:
	return route_rescue_spawn_distance_multiplier

func get_route_gate_spawn_distance_multiplier() -> float:
	return route_gate_spawn_distance_multiplier

func get_route_supply_spawn_chance_bonus() -> float:
	return route_supply_spawn_chance_bonus

func get_route_supply_spawn_distance_multiplier() -> float:
	return route_supply_spawn_distance_multiplier

func get_route_armoury_cache_reward_table() -> String:
	return route_armoury_cache_reward_table

func on_boss_defeated() -> void:
	if not running or pending_post_boss_choice:
		return
	if run_stats["boss_kills"] <= boss_choices_presented:
		return
	boss_choices_presented = run_stats["boss_kills"]
	post_boss_choice_selection_locked = false
	pending_post_boss_choice = true
	set_fire_input_held(false)
	get_tree().paused = true
	post_boss_choice_opened.emit(_build_post_boss_choice_options())

func select_post_boss_route(choice_id: String) -> bool:
	if not pending_post_boss_choice or post_boss_choice_selection_locked:
		return false
	post_boss_choice_selection_locked = true
	var route_defs: Dictionary = GameManager.game_config.get("post_boss_routes", {})
	var route_def: Dictionary = route_defs.get(choice_id, {})
	if route_def.is_empty():
		post_boss_choice_selection_locked = false
		return false
	_close_post_boss_choice(false)
	if choice_id == "extract_now":
		ui_manager.show_status_message("EXTRACTING WITH THE HAUL", Color("9ee3ff"))
		finish_run(true)
		return true
	_apply_route_choice(choice_id, route_def)
	return true

func _build_post_boss_choice_options() -> Array:
	var options: Array = []
	var route_defs: Dictionary = GameManager.game_config.get("post_boss_routes", {})
	var route_order: Array = GameManager.game_config.get("post_boss_route_order", [])
	for route_id_variant in route_order:
		var route_id: String = String(route_id_variant)
		var route_def: Dictionary = route_defs.get(route_id, {})
		if route_def.is_empty():
			continue
		options.append({
			"id": route_id,
			"title": String(route_def.get("title", route_id)),
			"description": String(route_def.get("description", "")),
			"button_color": String(route_def.get("button_color", "#ffffff"))
		})
	return options

func _apply_route_choice(choice_id: String, route_def: Dictionary) -> void:
	latest_route_choice_id = choice_id
	latest_route_choice_title = String(route_def.get("title", choice_id))
	route_choice_history.append(choice_id)
	route_reward_multiplier *= max(1.0, float(route_def.get("reward_multiplier", 1.0)))
	route_difficulty_multiplier *= max(1.0, float(route_def.get("difficulty_multiplier", 1.0)))
	route_spawn_interval_multiplier *= clampf(float(route_def.get("spawn_interval_multiplier", 1.0)), 0.5, 1.0)
	route_runner_weight_multiplier *= max(1.0, float(route_def.get("runner_weight_multiplier", 1.0)))
	route_rescue_spawn_chance_bonus += max(0.0, float(route_def.get("rescue_spawn_chance_bonus", 0.0)))
	route_rescue_spawn_distance_multiplier *= clampf(float(route_def.get("rescue_spawn_distance_multiplier", 1.0)), 0.5, 1.0)
	route_gate_spawn_distance_multiplier *= clampf(float(route_def.get("gate_spawn_distance_multiplier", 1.0)), 0.5, 1.0)
	route_supply_spawn_chance_bonus += max(0.0, float(route_def.get("supply_spawn_chance_bonus", 0.0)))
	route_supply_spawn_distance_multiplier *= clampf(float(route_def.get("supply_spawn_distance_multiplier", 1.0)), 0.5, 1.0)
	var reward_table: String = String(route_def.get("armoury_cache_reward_table", ""))
	if reward_table != "":
		route_armoury_cache_reward_table = reward_table
	var extend_reward_id: String = String(route_def.get("extend_reward_id", ""))
	var extend_result: Dictionary = {}
	if extend_reward_id != "":
		extend_result = reward_manager.apply_reward_by_id(extend_reward_id)
		var popup_text: String = String(extend_result.get("popup", ""))
		if popup_text != "":
			ui_manager.spawn_reward_popup(squad_manager.get_anchor_position() + Vector2(0.0, -100.0), popup_text, Color(extend_result.get("color", Color("7de3ff"))))
	var route_summary: String = "%s | x%.2f rewards" % [latest_route_choice_title.to_upper(), route_reward_multiplier]
	if choice_id == "push_forward":
		route_summary += " | HARDER HORDE"
	elif choice_id == "rescue_route":
		route_summary += " | MORE RESCUES"
	elif choice_id == "supply_route":
		route_summary += " | MORE SUPPLIES"
	ui_manager.show_status_message(route_summary, Color(String(route_def.get("button_color", "#ffffff"))))
	pressure_changed.emit(get_pressure_state())
	notify_mutation_state_changed()
	post_boss_choice_closed.emit(get_route_status_state())

func _close_post_boss_choice(emit_signal: bool = true) -> void:
	pending_post_boss_choice = false
	get_tree().paused = false
	if emit_signal:
		post_boss_choice_closed.emit(get_route_status_state())

func clear_post_boss_choice_state() -> void:
	pending_post_boss_choice = false
	post_boss_choice_selection_locked = false
	boss_choices_presented = 0
	route_choice_history.clear()
	latest_route_choice_id = ""
	latest_route_choice_title = ""
	route_reward_multiplier = 1.0
	route_difficulty_multiplier = 1.0
	route_spawn_interval_multiplier = 1.0
	route_runner_weight_multiplier = 1.0
	route_rescue_spawn_chance_bonus = 0.0
	route_rescue_spawn_distance_multiplier = 1.0
	route_gate_spawn_distance_multiplier = 1.0
	route_supply_spawn_chance_bonus = 0.0
	route_supply_spawn_distance_multiplier = 1.0
	route_armoury_cache_reward_table = ""

func _get_pressure_tier_rank(tier: String) -> int:
	match tier:
		"medium":
			return 1
		"high":
			return 2
		"surge":
			return 3
		_:
			return 0

func _show_pressure_warning_for_tier(tier: String, _reason: String = "") -> void:
	var warning_text: String = String(pressure_config.get("warnings", {}).get(tier, ""))
	if warning_text == "":
		return
	ui_manager.show_status_message(warning_text, Color("ff8b6b"))

func notify_mutation_state_changed() -> void:
	var state: Dictionary = mutation_manager.get_active_mutation_state() if mutation_manager != null else {}
	mutation_changed.emit(state)

func finish_run(victory: bool) -> void:
	if not running or run_end_locked:
		return
	run_end_locked = true
	running = false
	_close_post_boss_choice(false)
	reset_horde_pressure()
	mutation_manager.clear_state("run_end")
	weapon_manager.clear_special_ammo()
	enemy_manager.clear_all_obstacles("run_end")
	armoury_cache_manager.clear_all_caches("run_end")
	survivor_rescue_manager.clear_all_rescues("run_end")
	var summary := {
		"victory": victory,
		"distance": int(distance_travelled),
		"coins_earned": run_stats["coins_earned"],
		"kills": run_stats["kills"],
		"boss_kills": run_stats["boss_kills"],
		"obstacles_destroyed": run_stats["obstacles_destroyed"],
		"armoury_caches_destroyed": run_stats["armoury_caches_destroyed"],
		"survivor_rescues_completed": run_stats["survivor_rescues_completed"],
		"survivors_rescued": run_stats["survivors_rescued"],
		"final_soldiers": squad_manager.get_soldier_count(),
		"route_choice": latest_route_choice_title,
		"route_reward_multiplier": route_reward_multiplier
	}
	GameManager.end_run(victory, summary)
	run_ended.emit(victory)
	ui_manager.show_end_screen(victory, summary)
