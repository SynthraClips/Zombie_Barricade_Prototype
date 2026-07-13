extends Node

signal run_started
signal run_finished(victory: bool, summary: Dictionary)
signal data_loaded

const DATA_ROOT := "res://data/"
const DataRepository = preload("res://scripts/core/DataRepository.gd")

var game_config: Dictionary = {}
var enemy_data: Dictionary = {}
var weapon_data: Dictionary = {}
var barricade_data: Dictionary = {}
var wave_data: Dictionary = {}
var mutation_data: Dictionary = {}
var reward_data: Dictionary = {}
var gate_data: Dictionary = {}
var mission_data: Dictionary = {}
var upgrade_data: Dictionary = {}

var current_run_summary: Dictionary = {}
var last_run_victory: bool = false
var current_run_context: Dictionary = {}

func _ready() -> void:
	_load_all_data()
	_ensure_input_actions()
	UpgradeManager.initialize_from_data(upgrade_data)

func initialize_active_profile() -> void:
	if not SaveManager.has_active_profile():
		push_error("Profile initialization rejected: no active profile selected.")
		return
	UpgradeManager.initialize_from_data(upgrade_data)
	MissionManager.initialize_from_data(mission_data)
	AudioManager.set_sfx_volume(float(SaveManager.save_data.get("settings", {}).get("sfx_volume", 0.8)))

func _load_all_data() -> void:
	game_config = DataRepository.load_json(DATA_ROOT + "game_config.json", {})
	enemy_data = DataRepository.load_json(DATA_ROOT + "enemies.json", {})
	weapon_data = DataRepository.load_json(DATA_ROOT + "weapons.json", {})
	barricade_data = DataRepository.load_json(DATA_ROOT + "barricades.json", {})
	wave_data = DataRepository.load_json(DATA_ROOT + "waves.json", {})
	mutation_data = DataRepository.load_json(DATA_ROOT + "mutations.json", {})
	reward_data = DataRepository.load_json(DATA_ROOT + "rewards.json", {})
	gate_data = DataRepository.load_json(DATA_ROOT + "gates.json", {})
	mission_data = DataRepository.load_json(DATA_ROOT + "missions.json", {})
	upgrade_data = DataRepository.load_json(DATA_ROOT + "upgrades.json", {})
	data_loaded.emit()

func _ensure_input_actions() -> void:
	_add_action_if_missing("deploy_barricade", KEY_B)
	_add_action_if_missing("pause_run", KEY_ESCAPE)
	_add_action_if_missing("call_hero", KEY_H)
	_add_action_if_missing("hero_ultimate", KEY_U)
	if not InputMap.has_action("fire_weapon"):
		InputMap.add_action("fire_weapon")
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire_weapon", mouse_event)

func _add_action_if_missing(action: String, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action, event)

func start_run(run_context: Dictionary = {}) -> void:
	if not SaveManager.has_active_profile():
		push_error("Run start rejected: select a profile first.")
		get_tree().change_scene_to_file("res://scenes/main/ProfileSelect.tscn")
		return
	current_run_summary = {}
	current_run_context = _build_run_context(run_context)
	run_started.emit()
	get_tree().change_scene_to_file("res://scenes/gameplay/Battlefield.tscn")

func end_run(victory: bool, summary: Dictionary) -> void:
	last_run_victory = victory
	current_run_summary = summary.duplicate(true)
	current_run_summary["mode"] = String(current_run_context.get("mode", "standard"))
	current_run_summary["daily_seed"] = String(current_run_context.get("daily_seed", ""))
	var active_scene: Node = get_tree().current_scene
	if int(current_run_summary.get("coins_earned", 0)) <= 0 and active_scene != null:
		var scene_coins = active_scene.get("coins")
		if scene_coins != null:
			current_run_summary["coins_earned"] = int(scene_coins)
	var report_bonus_multiplier: float = 1.0 + UpgradeManager.get_upgrade_value("report_reward_bonus")
	var coins_earned: int = int(current_run_summary.get("coins_earned", 0) * float(game_config.get("run_coin_keep_ratio", 1.0)) * report_bonus_multiplier)
	SaveManager.add_banked_coins(coins_earned)
	MissionManager.register_run_summary(current_run_summary)
	var stats: Dictionary = SaveManager.save_data.get("stats", {})
	var distance: int = int(summary.get("distance", 0))
	var kills: int = int(summary.get("kills", 0))
	var bosses: int = int(summary.get("bosses_defeated", summary.get("boss_kills", 0)))
	var rescued: int = int(summary.get("soldiers_rescued", summary.get("survivors_rescued", 0)))
	var pickups: int = int(summary.get("pickups_collected", 0))
	var gates: int = int(summary.get("gates_chosen", 0))
	var score: int = int(summary.get("score", distance + kills * 2 + bosses * 75 + rescued * 8 + pickups * 5))
	stats["lifetime_distance"] = int(stats.get("lifetime_distance", 0)) + distance
	stats["best_distance"] = max(int(stats.get("best_distance", 0)), distance)
	stats["highest_coins_in_run"] = max(int(stats.get("highest_coins_in_run", 0)), int(summary.get("coins_earned", 0)))
	stats["total_zombies_killed"] = int(stats.get("total_zombies_killed", 0)) + kills
	stats["total_bosses_defeated"] = int(stats.get("total_bosses_defeated", 0)) + bosses
	stats["total_soldiers_rescued"] = int(stats.get("total_soldiers_rescued", 0)) + rescued
	stats["total_pickups_collected"] = int(stats.get("total_pickups_collected", 0)) + pickups
	stats["total_gates_chosen"] = int(stats.get("total_gates_chosen", 0)) + gates
	stats["best_run_score"] = max(int(stats.get("best_run_score", 0)), score)
	if victory:
		stats["runs_completed"] = int(stats.get("runs_completed", 0)) + 1
	else:
		stats["total_runs_failed"] = int(stats.get("total_runs_failed", 0)) + 1
	if String(current_run_context.get("mode", "standard")) == "daily":
		var daily_state: Dictionary = SaveManager.save_data.get("daily_challenge", {})
		daily_state["completed_seed"] = String(current_run_context.get("daily_seed", ""))
		daily_state["last_seed"] = String(current_run_context.get("daily_seed", ""))
		daily_state["best_distance"] = max(int(daily_state.get("best_distance", 0)), distance)
		daily_state["best_score"] = max(int(daily_state.get("best_score", 0)), score)
		daily_state["last_summary"] = current_run_summary.duplicate(true)
		SaveManager.save_data["daily_challenge"] = daily_state
		stats["best_daily_distance"] = max(int(stats.get("best_daily_distance", 0)), distance)
		stats["best_daily_score"] = max(int(stats.get("best_daily_score", 0)), score)
	SaveManager.save_data["stats"] = stats
	SaveManager.save_game()
	run_finished.emit(victory, current_run_summary)

func get_starting_soldier_count() -> int:
	var base_count: int = int(game_config.get("starting_soldiers", 3))
	if base_count <= 0:
		base_count = 3
	var bonus_count: int = int(UpgradeManager.get_upgrade_value("starting_soldiers"))
	var total: int = base_count + bonus_count
	if total < 3:
		return 3
	return total

func get_starting_weapon_id() -> String:
	var choice: String = UpgradeManager.get_choice_value("starting_weapon")
	if choice != "" and weapon_data.has(choice):
		return choice
	var configured: String = String(game_config.get("starting_weapon", "rifle"))
	if configured == "" or not weapon_data.has(configured):
		return "rifle"
	return configured

func get_starting_barricade_id() -> String:
	var choice: String = UpgradeManager.get_choice_value("starting_barricade_tier")
	if choice != "" and barricade_data.has(choice):
		return choice
	var configured: String = String(game_config.get("starting_barricade_tier", "wooden_wall"))
	if configured == "" or not barricade_data.has(configured):
		return "wooden_wall"
	return configured

func get_support_role_id() -> String:
	var choice: String = UpgradeManager.get_choice_value("starting_support_role")
	if choice != "":
		return choice
	return "rifleman"

func get_route_type_def(route_type_id: String) -> Dictionary:
	return game_config.get("route_types", {}).get(route_type_id, {})

func get_run_modifier_def(modifier_id: String) -> Dictionary:
	return game_config.get("run_modifiers", {}).get(modifier_id, {})

func get_hero_def(hero_id: String) -> Dictionary:
	return game_config.get("heroes", {}).get(hero_id, {})

func get_hero_order() -> Array:
	return game_config.get("hero_order", [])

func build_daily_run_context(date_override: String = "") -> Dictionary:
	var date_key: String = date_override if date_override != "" else Time.get_date_string_from_system()
	var route_ids: Array = game_config.get("daily_challenge", {}).get("route_pool", game_config.get("route_type_order", []))
	var modifier_ids: Array = game_config.get("daily_challenge", {}).get("modifier_pool", game_config.get("run_modifier_order", []))
	var objective_ids: Array = game_config.get("daily_challenge", {}).get("objective_pool", [])
	var seed_value: int = _string_seed(date_key)
	var context := {
		"mode": "daily",
		"daily_seed": date_key,
		"run_seed": seed_value,
		"route_type_id": _pick_seeded_value(route_ids, seed_value, "balanced_route"),
		"run_modifier_id": _pick_seeded_value(modifier_ids, seed_value + 11, ""),
		"daily_objective_id": _pick_seeded_value(objective_ids, seed_value + 29, "")
	}
	return _build_run_context(context)

func _build_run_context(overrides: Dictionary = {}) -> Dictionary:
	var context := {
		"mode": "standard",
		"daily_seed": "",
		"run_seed": int(Time.get_ticks_usec()) ^ randi(),
		"route_type_id": String(SaveManager.save_data.get("selected_route_type", "balanced_route")),
		"run_modifier_id": _pick_random_run_modifier_id(),
		"daily_objective_id": "",
		"hero_id": String(SaveManager.save_data.get("selected_hero", ""))
	}
	for key in overrides.keys():
		context[key] = overrides[key]
	if String(context.get("route_type_id", "")) == "":
		context["route_type_id"] = "balanced_route"
	if String(context.get("run_modifier_id", "")) == "" and not game_config.get("run_modifier_order", []).is_empty():
		context["run_modifier_id"] = _pick_random_run_modifier_id()
	return context

func _pick_random_run_modifier_id() -> String:
	var modifier_ids: Array = game_config.get("run_modifier_order", [])
	if modifier_ids.is_empty():
		return ""
	return String(modifier_ids[randi() % modifier_ids.size()])

func _pick_seeded_value(values: Array, seed_value: int, fallback: String) -> String:
	if values.is_empty():
		return fallback
	return String(values[posmod(seed_value, values.size())])

func _string_seed(text: String) -> int:
	var value := 0
	for char_index in text.length():
		value = (value * 31 + text.unicode_at(char_index)) % 2147483647
	return value
