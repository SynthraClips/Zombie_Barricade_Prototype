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

func _ready() -> void:
	_load_all_data()
	_ensure_input_actions()
	UpgradeManager.initialize_from_data(upgrade_data)
	MissionManager.initialize_from_data(mission_data)

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

func start_run() -> void:
	current_run_summary = {}
	run_started.emit()
	get_tree().change_scene_to_file("res://scenes/gameplay/Battlefield.tscn")

func end_run(victory: bool, summary: Dictionary) -> void:
	last_run_victory = victory
	current_run_summary = summary.duplicate(true)
	var coins_earned: int = int(summary.get("coins_earned", 0) * float(game_config.get("run_coin_keep_ratio", 1.0)))
	SaveManager.add_banked_coins(coins_earned)
	MissionManager.register_run_summary(summary)
	SaveManager.save_data["stats"]["lifetime_distance"] += int(summary.get("distance", 0))
	SaveManager.save_data["stats"]["best_distance"] = max(int(SaveManager.save_data["stats"].get("best_distance", 0)), int(summary.get("distance", 0)))
	SaveManager.save_data["stats"]["runs_completed"] += 1
	SaveManager.save_game()
	run_finished.emit(victory, current_run_summary)

func get_starting_soldier_count() -> int:
	return int(game_config.get("starting_soldiers", 3)) + UpgradeManager.get_upgrade_value("starting_soldiers")

func get_starting_weapon_id() -> String:
	var choice: String = UpgradeManager.get_choice_value("starting_weapon")
	if choice != "":
		return choice
	return String(game_config.get("starting_weapon", "rifle"))

func get_starting_barricade_id() -> String:
	var choice: String = UpgradeManager.get_choice_value("starting_barricade_tier")
	if choice != "" and barricade_data.has(choice):
		return choice
	return String(game_config.get("starting_barricade_tier", "paper_wall"))

func get_support_role_id() -> String:
	var choice: String = UpgradeManager.get_choice_value("starting_support_role")
	if choice != "":
		return choice
	return "rifleman"
