extends Node2D
class_name RunManager

signal coins_changed(value: int)
signal resources_changed(supplies: int, survivors: int)
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
var supplies := 0
var survivors := 0
var distance_travelled := 0.0
var elapsed_time := 0.0
var current_wave := 1
var running := true
var target_distance := 300.0
var scroll_speed := 90.0
var max_squad_size := 8
var hero_avatar: Node2D
var pressure_config: Dictionary = {}
var current_pressure := 0.0
var pressure_distance_checkpoint := 0.0
var aim_position := Vector2(540, 520)
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
var route_type_id := "balanced_route"
var route_type_title := "Balanced Route"
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
var route_rarity_bonus := 0.0
var selected_hero_id := ""
var selected_hero_def: Dictionary = {}
var hero_active := false
var hero_time_remaining := 0.0
var hero_cooldown_remaining := 0.0
var hero_uses_remaining := 0
var hero_ultimate_ready := false
var hero_ultimate_used := false
var hero_ultimate_uses_remaining := 0
var rescued_specialists: Array[String] = []
var active_run_modifier_id := ""
var active_run_modifier_title := ""
var run_modifier_reward_multiplier := 1.0
var run_modifier_difficulty_multiplier := 1.0
var run_modifier_runner_weight_multiplier := 1.0
var current_run_summary: Dictionary = {}
var mini_objective_label := ""
var active_mini_objective: Dictionary = {}
var next_mini_objective_distance := 45.0
var mini_objective_templates: Array[Dictionary] = [
	{
		"id": "hold_line",
		"label": "Hold The Line",
		"type": "timer_only",
		"time_remaining": 8.0,
		"reward_coins": 20
	},
	{
		"id": "thin_horde",
		"label": "Thin The Horde",
		"type": "kill_count",
		"time_remaining": 9.0,
		"reward_coins": 26,
		"target": 8,
		"progress": 0
	},
	{
		"id": "supply_sweep",
		"label": "Supply Sweep",
		"type": "pickup_count",
		"time_remaining": 12.0,
		"reward_coins": 30,
		"target": 3,
		"progress": 0
	},
	{
		"id": "road_clear",
		"label": "Road Clear",
		"type": "obstacle_count",
		"time_remaining": 12.0,
		"reward_coins": 34,
		"target": 2,
		"progress": 0
	},
	{
		"id": "rescue_window",
		"label": "Rescue Window",
		"type": "rescue_count",
		"time_remaining": 14.0,
		"reward_coins": 38,
		"target": 1,
		"progress": 0
	}
]
var run_stats := {
	"kills": 0,
	"boss_kills": 0,
	"obstacles_destroyed": 0,
	"coins_earned": 0,
	"supplies_earned": 0,
	"survivors_earned": 0,
	"mutated_animals_killed": 0,
	"mutation_history": [],
	"night_sections": 0,
	"boss_ids_defeated": [],
	"hero_uses": 0,
	"hero_ultimates": 0,
	"armoury_caches_destroyed": 0,
	"survivor_rescues_completed": 0,
	"survivors_rescued": 0,
	"pickups_collected": 0,
	"gates_chosen": 0,
	"mini_objectives_completed": 0,
	"bosses_defeated": 0,
	"route_type_id": "",
	"route_type_title": "",
	"run_modifier_id": "",
	"run_modifier_title": "",
	"hero_used": "",
	"specialists_rescued": [],
	"final_distance": 0
}

func _ready() -> void:
	if not SaveManager.has_active_profile():
		running = false
		push_error("Gameplay initialization rejected: no active profile selected.")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main/ProfileSelect.tscn")
		return
	target_distance = float(GameManager.game_config.get("target_distance", 300))
	scroll_speed = float(GameManager.game_config.get("base_scroll_speed", 90.0))
	max_squad_size = int(GameManager.game_config.get("max_squad_size", 8)) + int(round(UpgradeManager.get_tree_effect_total("max_squad_size")))
	pressure_config = GameManager.game_config.get("horde_pressure", {}).duplicate(true)
	current_run_summary = {}
	run_end_locked = false
	squad_manager.setup(self)
	if squad_manager.get_soldier_count() <= 0:
		var fallback_count: int = mini(max_squad_size, max(GameManager.get_starting_soldier_count(), 3))
		for index in range(fallback_count):
			var role_id: String = GameManager.get_support_role_id() if index == 0 else "rifleman"
			squad_manager.add_soldier(role_id, true, max_squad_size)
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
	aim_position = Vector2(road.get_center_x(), road.get_squad_y() - 260.0)
	_apply_run_context()
	reset_horde_pressure(false)
	SaveManager.save_data["stats"]["total_runs_started"] = int(SaveManager.save_data.get("stats", {}).get("total_runs_started", 0)) + 1
	SaveManager.save_game()
	coins_changed.emit(coins)
	resources_changed.emit(supplies, survivors)
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
		request_deploy_barricade()
	if Input.is_action_just_pressed("pause_run"):
		ui_manager.toggle_pause()
	if Input.is_action_just_pressed("call_hero"):
		request_call_hero()
	if Input.is_action_just_pressed("hero_ultimate"):
		request_hero_ultimate()
	_update_camera(delta)
	if get_tree().paused:
		return
	elapsed_time += delta
	_update_hero_state(delta)
	distance_travelled += scroll_speed * delta / 10.0
	_update_mini_objective(delta)
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

func request_deploy_barricade() -> bool:
	var deployed: bool = barricade_manager.deploy_current_barricade()
	if not deployed:
		var cooldown: float = barricade_manager.deploy_cooldown
		var message := "BARRICADE RECHARGING %.1fs" % cooldown if cooldown > 0.0 else "BARRICADE ALREADY DEPLOYED"
		ui_manager.show_status_message(message, Color("ffb36b"))
	return deployed

func request_call_hero() -> bool:
	var called: bool = call_selected_hero()
	if not called:
		var state: Dictionary = get_hero_state()
		var message := "NO HERO SELECTED"
		if String(state.get("id", "")) != "":
			if bool(state.get("active", false)):
				message = "HERO ALREADY ACTIVE"
			elif float(state.get("cooldown_remaining", 0.0)) > 0.0:
				message = "HERO RECHARGING %.1fs" % float(state.get("cooldown_remaining", 0.0))
			elif int(state.get("uses_remaining", 0)) <= 0:
				message = "NO HERO CALL-INS REMAINING"
		ui_manager.show_status_message(message, Color("ffb36b"))
	return called

func request_hero_ultimate() -> bool:
	var triggered: bool = trigger_hero_ultimate()
	if not triggered:
		var state: Dictionary = get_hero_state()
		var message := "NO HERO SELECTED"
		if String(state.get("id", "")) != "":
			if not bool(state.get("active", false)):
				message = "CALL HERO BEFORE USING ULTIMATE"
			elif not bool(state.get("ultimate_ready", false)):
				message = "ULTIMATE NOT READY"
		ui_manager.show_status_message(message, Color("ffb36b"))
	return triggered

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
	if amount <= 0:
		return 0
	var bonus_multiplier: float = 1.0 + UpgradeManager.get_upgrade_value("coin_gain")
	var route_bonus_multiplier: float = 1.0 + UpgradeManager.get_upgrade_value("route_reward_bonus")
	var pressure_multiplier: float = get_pressure_reward_multiplier()
	var mutation_multiplier: float = mutation_manager.get_reward_multiplier() if mutation_manager != null else 1.0
	var total_multiplier: float = bonus_multiplier * route_bonus_multiplier * pressure_multiplier * mutation_multiplier * route_reward_multiplier * run_modifier_reward_multiplier
	if not is_finite(total_multiplier) or total_multiplier <= 0.0:
		total_multiplier = 1.0
	var base_amount: int = max(1, int(amount))
	var final_amount: int = base_amount
	if total_multiplier > 1.0:
		final_amount = int(ceil(float(base_amount) * total_multiplier))
	var coins_before: int = int(coins)
	coins = coins_before + final_amount
	if int(coins) <= coins_before:
		coins = coins_before + max(1, final_amount)
	final_amount = int(coins) - coins_before
	run_stats["coins_earned"] = int(run_stats["coins_earned"]) + final_amount
	coins_changed.emit(coins)
	return final_amount

func add_supplies(amount: int) -> int:
	var base_amount: int = maxi(amount, 0)
	var multiplier := 1.0 + UpgradeManager.get_tree_effect_total("supplies_retention")
	var added := int(ceil(float(base_amount) * multiplier)) if base_amount > 0 else 0
	supplies += added
	run_stats["supplies_earned"] = int(run_stats.get("supplies_earned", 0)) + added
	resources_changed.emit(supplies, survivors)
	return added

func add_survivors(amount: int) -> int:
	var base_amount: int = maxi(amount, 0)
	var multiplier := 1.0 + UpgradeManager.get_tree_effect_total("survivor_value")
	var added := int(ceil(float(base_amount) * multiplier)) if base_amount > 0 else 0
	survivors += added
	run_stats["survivors_earned"] = int(run_stats.get("survivors_earned", 0)) + added
	resources_changed.emit(supplies, survivors)
	return added

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
	_advance_active_mini_objective("kill_count", 1)
	SaveManager.save_data["stats"]["lifetime_kills"] += 1
	MissionManager.increment_progress("kills", 1)
	var enemy_definition: Dictionary = GameManager.enemy_data.get(enemy_id, {})
	if String(enemy_definition.get("category", "zombie")) == "animal":
		run_stats["mutated_animals_killed"] = int(run_stats.get("mutated_animals_killed", 0)) + 1
		SaveManager.save_data["stats"]["total_mutated_animals_killed"] = int(SaveManager.save_data.get("stats", {}).get("total_mutated_animals_killed", 0)) + 1
	if String(enemy_definition.get("category", "")) == "boss" or enemy_id == "boss":
		run_stats["boss_kills"] += 1
		run_stats["bosses_defeated"] += 1
		SaveManager.save_data["stats"]["boss_kills"] += 1
		MissionManager.increment_progress("boss_kills", 1)
		reduce_horde_pressure_for("boss_defeated")
		on_boss_defeated()
		var boss_ids: Array = run_stats.get("boss_ids_defeated", [])
		if not boss_ids.has(enemy_id):
			boss_ids.append(enemy_id)
		run_stats["boss_ids_defeated"] = boss_ids
		var permanent_boss_ids: Array = SaveManager.save_data.get("defeated_boss_ids", [])
		if not permanent_boss_ids.has(enemy_id):
			permanent_boss_ids.append(enemy_id)
		SaveManager.save_data["defeated_boss_ids"] = permanent_boss_ids

func register_obstacle_destroyed() -> void:
	run_stats["obstacles_destroyed"] += 1
	_advance_active_mini_objective("obstacle_count", 1)
	SaveManager.save_data["stats"]["lifetime_obstacles_destroyed"] += 1
	MissionManager.increment_progress("obstacles_destroyed", 1)
	SaveManager.save_data["mission_progress"]["destroy_25_barrels"] = int(SaveManager.save_data.get("mission_progress", {}).get("destroy_25_barrels", 0)) + 1

func register_armoury_cache_destroyed() -> void:
	run_stats["armoury_caches_destroyed"] += 1
	SaveManager.save_data["stats"]["armoury_caches_destroyed"] += 1
	MissionManager.increment_progress("armoury_caches_destroyed", 1)
	reduce_horde_pressure_for("armoury_cache_destroyed")

func register_survivor_rescue(soldiers_added: int) -> void:
	run_stats["survivor_rescues_completed"] += 1
	run_stats["survivors_rescued"] += max(soldiers_added, 0)
	_advance_active_mini_objective("rescue_count", 1)
	reduce_horde_pressure_for("survivor_rescue_completed")
	add_survivors(max(1, soldiers_added))

func register_pickup_collected(_reward_id: String = "") -> void:
	run_stats["pickups_collected"] += 1
	_advance_active_mini_objective("pickup_count", 1)
	SaveManager.save_data["stats"]["total_pickups_collected"] = int(SaveManager.save_data.get("stats", {}).get("total_pickups_collected", 0)) + 1
	MissionManager.increment_progress("pickups_collected", 1)

func register_gate_chosen(effect: Dictionary) -> void:
	run_stats["gates_chosen"] += 1
	SaveManager.save_data["stats"]["total_gates_chosen"] = int(SaveManager.save_data.get("stats", {}).get("total_gates_chosen", 0)) + 1
	var gate_type: String = String(effect.get("type", ""))
	if gate_type == "add_soldiers":
		MissionManager.increment_progress("choose_gates", 1)

func register_mini_objective_completed(label: String = "") -> void:
	run_stats["mini_objectives_completed"] += 1
	mini_objective_label = label
	MissionManager.increment_progress("mini_objectives_completed", 1)

func register_special_event_completed(_event_id: String = "") -> void:
	reduce_horde_pressure_for("special_event_completed")

func on_squad_count_changed() -> void:
	squad_changed.emit(squad_manager.get_soldier_count())

func get_difficulty_multiplier() -> float:
	var distance_factor: float = distance_travelled / max(target_distance, 1.0)
	var wave_factor: float = float(current_wave - 1) * 0.12
	var time_factor: float = elapsed_time / 90.0
	return (1.0 + distance_factor * 0.55 + wave_factor + time_factor * 0.25) * route_difficulty_multiplier * run_modifier_difficulty_multiplier

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
	return lerpf(1.0, cap_multiplier, get_pressure_ratio()) * route_runner_weight_multiplier * run_modifier_runner_weight_multiplier

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
		"route_type_id": route_type_id,
		"route_type_title": route_type_title,
		"history_count": route_choice_history.size(),
		"reward_multiplier": route_reward_multiplier,
		"difficulty_multiplier": route_difficulty_multiplier,
		"rescue_bonus": route_rescue_spawn_chance_bonus,
		"supply_bonus": route_supply_spawn_chance_bonus,
		"run_modifier_title": active_run_modifier_title
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

func get_route_rarity_bonus() -> float:
	return route_rarity_bonus

func get_hero_state() -> Dictionary:
	return {
		"id": selected_hero_id,
		"name": String(selected_hero_def.get("name", "No Hero")),
		"active": hero_active,
		"time_remaining": hero_time_remaining,
		"cooldown_remaining": hero_cooldown_remaining,
		"uses_remaining": hero_uses_remaining,
		"ultimate_ready": hero_ultimate_ready and hero_ultimate_uses_remaining > 0,
		"ultimate_uses_remaining": hero_ultimate_uses_remaining
	}

func get_specialist_state() -> Dictionary:
	return {
		"rescued": rescued_specialists.duplicate(),
		"count": rescued_specialists.size()
	}

func get_run_modifier_state() -> Dictionary:
	return {
		"id": active_run_modifier_id,
		"title": active_run_modifier_title,
		"reward_multiplier": run_modifier_reward_multiplier,
		"difficulty_multiplier": run_modifier_difficulty_multiplier
	}

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
		if coins <= 0 and int(run_stats.get("boss_kills", 0)) > 0:
			var fallback_reward: int = int(GameManager.enemy_data.get("boss", {}).get("reward_value", 40))
			run_stats["coins_earned"] = int(run_stats.get("coins_earned", 0)) + fallback_reward
			coins += fallback_reward
			coins_changed.emit(coins)
			SaveManager.add_banked_coins(fallback_reward)
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
	route_rarity_bonus = 0.0

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
	run_stats["final_distance"] = int(distance_travelled)
	run_stats["route_type_id"] = route_type_id
	run_stats["route_type_title"] = route_type_title
	run_stats["run_modifier_id"] = active_run_modifier_id
	run_stats["run_modifier_title"] = active_run_modifier_title
	run_stats["hero_used"] = String(GameManager.current_run_context.get("hero_id", ""))
	run_stats["specialists_rescued"] = rescued_specialists.duplicate()
	var report_score: int = int(distance_travelled) + int(run_stats["kills"]) * 2 + int(run_stats["bosses_defeated"]) * 75 + int(run_stats["survivors_rescued"]) * 8 + int(run_stats["pickups_collected"]) * 5 + int(run_stats["gates_chosen"]) * 4
	var summary := {
		"victory": victory,
		"distance": int(distance_travelled),
		"coins_earned": max(int(run_stats["coins_earned"]), int(coins)),
		"supplies_earned": int(run_stats.get("supplies_earned", supplies)),
		"survivors_earned": int(run_stats.get("survivors_earned", survivors)),
		"mutated_animals_killed": int(run_stats.get("mutated_animals_killed", 0)),
		"mutation_history": run_stats.get("mutation_history", []).duplicate(),
		"night_sections": int(run_stats.get("night_sections", 0)),
		"boss_ids_defeated": run_stats.get("boss_ids_defeated", []).duplicate(),
		"hero_uses": int(run_stats.get("hero_uses", 0)),
		"hero_ultimates": int(run_stats.get("hero_ultimates", 0)),
		"kills": run_stats["kills"],
		"boss_kills": run_stats["boss_kills"],
		"bosses_defeated": run_stats["bosses_defeated"],
		"obstacles_destroyed": run_stats["obstacles_destroyed"],
		"armoury_caches_destroyed": run_stats["armoury_caches_destroyed"],
		"survivor_rescues_completed": run_stats["survivor_rescues_completed"],
		"survivors_rescued": run_stats["survivors_rescued"],
		"soldiers_rescued": run_stats["survivors_rescued"],
		"pickups_collected": run_stats["pickups_collected"],
		"gates_chosen": run_stats["gates_chosen"],
		"mini_objectives_completed": run_stats["mini_objectives_completed"],
		"final_soldiers": squad_manager.get_soldier_count(),
		"route_choice": latest_route_choice_title,
		"route_reward_multiplier": route_reward_multiplier,
		"route_type_id": route_type_id,
		"route_type_title": route_type_title,
		"run_modifier_id": active_run_modifier_id,
		"run_modifier_title": active_run_modifier_title,
		"hero_used": run_stats["hero_used"],
		"score": report_score,
		"new_best_distance": int(distance_travelled) > int(SaveManager.save_data.get("stats", {}).get("best_distance", 0)),
		"new_best_coins": int(run_stats["coins_earned"]) > int(SaveManager.save_data.get("stats", {}).get("highest_coins_in_run", 0)),
		"is_daily": String(GameManager.current_run_context.get("mode", "standard")) == "daily"
	}
	current_run_summary = summary.duplicate(true)
	GameManager.end_run(victory, summary)
	run_ended.emit(victory)
	ui_manager.show_end_screen(victory, summary)

func _apply_run_context() -> void:
	clear_post_boss_choice_state()
	_setup_selected_hero()
	var route_def: Dictionary = GameManager.get_route_type_def(String(GameManager.current_run_context.get("route_type_id", "balanced_route")))
	_apply_route_type(String(GameManager.current_run_context.get("route_type_id", "balanced_route")), route_def)
	var modifier_id: String = String(GameManager.current_run_context.get("run_modifier_id", ""))
	if modifier_id != "":
		_apply_run_modifier(modifier_id, GameManager.get_run_modifier_def(modifier_id))

func _apply_route_type(new_route_type_id: String, route_def: Dictionary) -> void:
	route_type_id = new_route_type_id
	route_type_title = String(route_def.get("title", "Balanced Route"))
	route_reward_multiplier *= max(1.0, float(route_def.get("reward_multiplier", 1.0)))
	route_difficulty_multiplier *= max(1.0, float(route_def.get("difficulty_multiplier", 1.0)))
	route_spawn_interval_multiplier *= clampf(float(route_def.get("spawn_interval_multiplier", 1.0)), 0.5, 1.4)
	route_runner_weight_multiplier *= max(1.0, float(route_def.get("runner_weight_multiplier", 1.0)))
	route_rescue_spawn_chance_bonus += max(0.0, float(route_def.get("rescue_spawn_chance_bonus", 0.0)))
	route_rescue_spawn_distance_multiplier *= clampf(float(route_def.get("rescue_spawn_distance_multiplier", 1.0)), 0.5, 1.5)
	route_gate_spawn_distance_multiplier *= clampf(float(route_def.get("gate_spawn_distance_multiplier", 1.0)), 0.5, 1.5)
	route_supply_spawn_chance_bonus += max(0.0, float(route_def.get("supply_spawn_chance_bonus", 0.0)))
	route_supply_spawn_distance_multiplier *= clampf(float(route_def.get("supply_spawn_distance_multiplier", 1.0)), 0.5, 1.5)
	route_rarity_bonus += max(0.0, float(route_def.get("rarity_bonus", 0.0)))
	var reward_table: String = String(route_def.get("armoury_cache_reward_table", ""))
	if reward_table != "":
		route_armoury_cache_reward_table = reward_table
	run_stats["route_type_id"] = route_type_id
	run_stats["route_type_title"] = route_type_title

func _apply_run_modifier(modifier_id: String, modifier_def: Dictionary) -> void:
	if modifier_def.is_empty():
		return
	active_run_modifier_id = modifier_id
	active_run_modifier_title = String(modifier_def.get("title", modifier_id))
	run_modifier_reward_multiplier = max(1.0, float(modifier_def.get("reward_multiplier", 1.0)))
	run_modifier_difficulty_multiplier = max(1.0, float(modifier_def.get("difficulty_multiplier", 1.0)))
	run_modifier_runner_weight_multiplier = max(1.0, float(modifier_def.get("runner_weight_multiplier", 1.0)))
	scroll_speed *= max(0.7, float(modifier_def.get("scroll_speed_multiplier", 1.0)))
	if bool(modifier_def.get("weaken_barricade_on_start", false)):
		barricade_manager.damage_active_barricade(float(modifier_def.get("starting_barricade_damage", 35.0)))
	run_stats["run_modifier_id"] = active_run_modifier_id
	run_stats["run_modifier_title"] = active_run_modifier_title

func _setup_selected_hero() -> void:
	selected_hero_id = String(GameManager.current_run_context.get("hero_id", SaveManager.save_data.get("selected_hero", "")))
	selected_hero_def = GameManager.get_hero_def(selected_hero_id)
	if String(selected_hero_def.get("requires_upgrade", "")) != "" and not UpgradeManager.has_tree_effect(String(selected_hero_def.get("requires_upgrade", ""))):
		selected_hero_def = {}
	hero_active = false
	hero_time_remaining = 0.0
	hero_cooldown_remaining = 0.0
	hero_ultimate_used = false
	if selected_hero_def.is_empty():
		selected_hero_id = ""
		hero_uses_remaining = 0
		hero_ultimate_ready = false
		hero_ultimate_uses_remaining = 0
		return
	hero_uses_remaining = int(selected_hero_def.get("uses_per_run", 1))
	hero_ultimate_ready = bool(selected_hero_def.get("ultimate_enabled", true))
	hero_ultimate_uses_remaining = (1 if hero_ultimate_ready else 0) + int(round(UpgradeManager.get_tree_effect_total("hero_ultimate_uses")))
	active_mini_objective = {}
	mini_objective_label = ""
	next_mini_objective_distance = 45.0
	rescued_specialists.clear()

func _update_hero_state(delta: float) -> void:
	if selected_hero_def.is_empty():
		return
	if hero_cooldown_remaining > 0.0:
		hero_cooldown_remaining = max(hero_cooldown_remaining - delta, 0.0)
	if hero_active:
		hero_time_remaining = max(hero_time_remaining - delta, 0.0)
		if hero_time_remaining <= 0.0:
			hero_active = false
			if hero_avatar != null and is_instance_valid(hero_avatar):
				hero_avatar.queue_free()
			hero_avatar = null
			ui_manager.show_status_message("%s WITHDRAWN" % String(selected_hero_def.get("name", "HERO")).to_upper(), Color("b9d5ff"))

func call_selected_hero() -> bool:
	if selected_hero_def.is_empty() or hero_active or hero_cooldown_remaining > 0.0 or hero_uses_remaining <= 0:
		return false
	var hero_script: Script = load("res://scripts/gameplay/HeroAvatar.gd")
	if hero_script == null:
		push_error("Hero spawn failed for %s: HeroAvatar script missing." % selected_hero_id)
		return false
	hero_avatar = Node2D.new()
	hero_avatar.set_script(hero_script)
	add_child(hero_avatar)
	hero_avatar.initialize(self, selected_hero_id, selected_hero_def)
	if not is_instance_valid(hero_avatar) or not hero_avatar.is_visible_in_tree():
		push_error("Hero spawn failed for %s: instance is not visible in the gameplay tree." % selected_hero_id)
		if hero_avatar != null and is_instance_valid(hero_avatar):
			hero_avatar.queue_free()
		hero_avatar = null
		return false
	hero_active = true
	hero_uses_remaining -= 1
	hero_time_remaining = float(selected_hero_def.get("duration", 8.0)) + UpgradeManager.get_upgrade_value("hero_duration")
	hero_cooldown_remaining = max(1.0, float(selected_hero_def.get("cooldown", 18.0)) - UpgradeManager.get_upgrade_value("hero_cooldown"))
	hero_ultimate_used = false
	run_stats["hero_used"] = selected_hero_id
	run_stats["hero_uses"] = int(run_stats.get("hero_uses", 0)) + 1
	var hero_effect: String = String(selected_hero_def.get("call_in_effect", ""))
	match hero_effect:
		"fire_rate_boost":
			squad_manager.apply_reward_boost("fire_rate_boost", float(selected_hero_def.get("power", 0.35)) + UpgradeManager.get_upgrade_value("hero_power"))
		"barricade_repair":
			barricade_manager.repair_active_barricade(float(selected_hero_def.get("power", 40.0)) + UpgradeManager.get_upgrade_value("hero_power") * 20.0)
		"damage_boost":
			squad_manager.apply_reward_boost("damage_boost", float(selected_hero_def.get("power", 0.3)) + UpgradeManager.get_upgrade_value("hero_power"))
		"squad_heal":
			squad_manager.heal_soldiers(int(selected_hero_def.get("power", 2)))
		"sniper_shot":
			var targets: Array = enemy_manager.get_enemies_sorted_from(squad_manager.get_anchor_position(), 720.0)
			if not targets.is_empty():
				targets[0].take_damage(float(selected_hero_def.get("power", 48.0)), false)
		"tesla_ammo":
			weapon_manager.refill_limited_ammo(int(selected_hero_def.get("power", 5)), "tesla_cannon")
	ui_manager.show_status_message("%s DEPLOYED" % String(selected_hero_def.get("name", "HERO")).to_upper(), Color("9ee3ff"))
	return true

func trigger_hero_ultimate() -> bool:
	if selected_hero_def.is_empty() or not hero_active or hero_ultimate_uses_remaining <= 0 or not hero_ultimate_ready:
		return false
	hero_ultimate_uses_remaining -= 1
	hero_ultimate_used = hero_ultimate_uses_remaining <= 0
	run_stats["hero_ultimates"] = int(run_stats.get("hero_ultimates", 0)) + 1
	var ultimate_effect: String = String(selected_hero_def.get("ultimate_effect", ""))
	match ultimate_effect:
		"squad_overdrive":
			squad_manager.apply_reward_boost("damage_boost", float(selected_hero_def.get("ultimate_power", 0.45)) + UpgradeManager.get_upgrade_value("hero_power"))
			squad_manager.apply_reward_boost("fire_rate_boost", float(selected_hero_def.get("ultimate_power", 0.45)) + UpgradeManager.get_upgrade_value("hero_power"))
		"full_repair":
			barricade_manager.repair_active_barricade(9999.0)
			barricade_manager.reset_cooldown()
		"grenade_volley":
			var blast_damage: float = float(selected_hero_def.get("ultimate_power", 36.0)) + UpgradeManager.get_upgrade_value("hero_power") * 25.0
			var targets: Array = enemy_manager.get_enemies_sorted_from(squad_manager.get_anchor_position(), 520.0)
			for target in targets.slice(0, 3):
				if not is_instance_valid(target):
					continue
				enemy_manager.damage_enemies_in_radius(target.global_position, 48.0, blast_damage)
				ui_manager.spawn_explosion(target.global_position, 48.0)
			AudioManager.play_sfx("explosion")
		"revive_pulse":
			squad_manager.add_soldiers(int(selected_hero_def.get("ultimate_power", 4)), true, max_squad_size)
			squad_manager.heal_soldiers(int(selected_hero_def.get("ultimate_power", 4)))
		"suppressive_fire":
			squad_manager.apply_reward_boost("fire_rate_boost", float(selected_hero_def.get("ultimate_power", 0.7)))
			squad_manager.apply_reward_boost("damage_boost", float(selected_hero_def.get("ultimate_power", 0.7)) * 0.5)
		"sniper_sweep":
			for target in enemy_manager.get_enemies_sorted_from(squad_manager.get_anchor_position(), 760.0).slice(0, 5):
				if is_instance_valid(target):
					target.take_damage(float(selected_hero_def.get("ultimate_power", 62.0)), false)
		"tesla_storm":
			weapon_manager.refill_limited_ammo(int(selected_hero_def.get("ultimate_power", 12)), "tesla_cannon")
			for target in enemy_manager.get_enemies_sorted_from(squad_manager.get_anchor_position(), 480.0).slice(0, 6):
				if is_instance_valid(target):
					target.take_damage(18.0, false)
	ui_manager.show_status_message("%s ULTIMATE" % String(selected_hero_def.get("name", "HERO")).to_upper(), Color("ffd166"))
	return true

func _update_mini_objective(delta: float) -> void:
	if active_mini_objective.is_empty():
		if distance_travelled >= next_mini_objective_distance:
			_start_next_mini_objective()
		return
	active_mini_objective["time_remaining"] = max(float(active_mini_objective.get("time_remaining", 0.0)) - delta, 0.0)
	var time_remaining: float = float(active_mini_objective.get("time_remaining", 0.0))
	var objective_type: String = String(active_mini_objective.get("type", "timer_only"))
	if objective_type.ends_with("_count"):
		mini_objective_label = "%s %d/%d (%.1fs)" % [
			String(active_mini_objective.get("label", "Objective")),
			int(active_mini_objective.get("progress", 0)),
			int(active_mini_objective.get("target", 1)),
			time_remaining
		]
	else:
		mini_objective_label = "%s (%.1fs)" % [String(active_mini_objective.get("label", "Objective")), time_remaining]
	if objective_type.ends_with("_count") and int(active_mini_objective.get("progress", 0)) >= int(active_mini_objective.get("target", 1)):
		_complete_active_mini_objective()
		return
	if time_remaining > 0.0:
		return
	if objective_type.ends_with("_count"):
		ui_manager.show_status_message("MINI OBJECTIVE FAILED", Color("ff8f6b"))
		active_mini_objective = {}
		mini_objective_label = ""
		next_mini_objective_distance = distance_travelled + 70.0
		return
	_complete_active_mini_objective()

func _complete_active_mini_objective() -> void:
	var reward_value: int = int(active_mini_objective.get("reward_coins", 20))
	add_coins(reward_value)
	register_mini_objective_completed(String(active_mini_objective.get("label", "Mini Objective Complete")))
	ui_manager.show_status_message("MINI OBJECTIVE COMPLETE", Color("7be495"))
	active_mini_objective = {}
	mini_objective_label = ""
	next_mini_objective_distance = distance_travelled + 95.0

func _start_next_mini_objective() -> void:
	var template_index: int = int(run_stats["mini_objectives_completed"]) % mini_objective_templates.size()
	active_mini_objective = mini_objective_templates[template_index].duplicate(true)
	if String(active_mini_objective.get("type", "")).ends_with("_count"):
		active_mini_objective["progress"] = 0
		mini_objective_label = "%s 0/%d (%.1fs)" % [
			String(active_mini_objective.get("label", "Objective")),
			int(active_mini_objective.get("target", 1)),
			float(active_mini_objective.get("time_remaining", 0.0))
		]
	else:
		mini_objective_label = "%s (%.1fs)" % [String(active_mini_objective.get("label", "Objective")), float(active_mini_objective.get("time_remaining", 0.0))]
	ui_manager.show_status_message("MINI OBJECTIVE: %s" % String(active_mini_objective.get("label", "Objective")).to_upper(), Color("ffd166"))

func _advance_active_mini_objective(objective_type: String, amount: int) -> void:
	if active_mini_objective.is_empty() or String(active_mini_objective.get("type", "")) != objective_type:
		return
	active_mini_objective["progress"] = int(active_mini_objective.get("progress", 0)) + max(amount, 0)

func unlock_specialist(specialist_id: String) -> bool:
	if specialist_id == "":
		return false
	var specialists_save: Dictionary = SaveManager.save_data.get("specialists", {})
	var unlocked: Array = specialists_save.get("unlocked", [])
	if not unlocked.has(specialist_id):
		unlocked.append(specialist_id)
		specialists_save["unlocked"] = unlocked
		SaveManager.save_data["specialists"] = specialists_save
	var matching_hero: Dictionary = GameManager.get_hero_def(specialist_id)
	if not matching_hero.is_empty():
		var heroes_save: Dictionary = SaveManager.save_data.get("heroes", {})
		var unlocked_heroes: Array = heroes_save.get("unlocked", [])
		if not unlocked_heroes.has(specialist_id):
			unlocked_heroes.append(specialist_id)
			heroes_save["unlocked"] = unlocked_heroes
			SaveManager.save_data["heroes"] = heroes_save
	if rescued_specialists.has(specialist_id):
		return false
	rescued_specialists.append(specialist_id)
	MissionManager.increment_progress("unlock_specialist", 1)
	var specialist_def: Dictionary = GameManager.game_config.get("specialists", {}).get(specialist_id, {})
	var bonus_type: String = String(specialist_def.get("bonus_type", ""))
	match bonus_type:
		"heal":
			squad_manager.add_role_soldiers("medic", int(specialist_def.get("bonus_value", 1)), true, max_squad_size)
		"fire_rate":
			squad_manager.apply_reward_boost("fire_rate_boost", float(specialist_def.get("bonus_value", 0.2)))
		"repair":
			barricade_manager.repair_active_barricade(float(specialist_def.get("bonus_value", 30.0)))
		"damage":
			squad_manager.apply_reward_boost("damage_boost", float(specialist_def.get("bonus_value", 0.25)))
		"explosive":
			weapon_manager.apply_special_ammo("explosive", float(specialist_def.get("bonus_value", 8.0)))
	ui_manager.show_status_message("%s JOINED THE CONVOY" % String(specialist_def.get("name", specialist_id)).to_upper(), Color("ffe08a"))
	SaveManager.save_game()
	return true
