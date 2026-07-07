extends Node

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 2

var save_data: Dictionary = _default_save_data()

func _ready() -> void:
	load_save()

func load_save() -> void:
	save_data = _default_save_data()
	if not FileAccess.file_exists(SAVE_PATH):
		save_game()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_backup_corrupt_save("open_failed")
		save_game()
		return
	var raw_text: String = file.get_as_text()
	var parsed = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		save_data = _deep_merge(_default_save_data(), parsed)
		save_data["save_version"] = SAVE_VERSION
		save_game()
		return
	_backup_corrupt_save("parse_failed", raw_text)
	save_data = _default_save_data()
	save_game()

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not save game data.")
		return
	save_data["save_version"] = SAVE_VERSION
	file.store_string(JSON.stringify(save_data, "\t"))

func add_banked_coins(value: int) -> void:
	save_data["banked_coins"] += max(value, 0)
	save_game()

func spend_banked_coins(value: int) -> bool:
	if save_data["banked_coins"] < value:
		return false
	save_data["banked_coins"] -= value
	save_game()
	return true

func _default_save_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"banked_coins": 0,
		"upgrades": {},
		"upgrade_choices": {},
		"mission_progress": {},
		"completed_missions": [],
		"settings": {
			"screenshake": true,
			"hit_flash": true,
			"sfx_volume": 0.8,
			"auto_fire": bool(GameManager.game_config.get("auto_fire_default", true))
		},
		"stats": {
			"lifetime_kills": 0,
			"lifetime_distance": 0,
			"lifetime_obstacles_destroyed": 0,
			"boss_kills": 0,
			"best_distance": 0,
			"coins_collected": 0,
			"soldiers_rescued": 0,
			"barricades_deployed": 0,
			"armoury_caches_destroyed": 0,
			"runs_completed": 0
		}
	}

func _deep_merge(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	var merged: Dictionary = defaults.duplicate(true)
	for key in loaded.keys():
		var loaded_value = loaded[key]
		if defaults.has(key) and defaults[key] is Dictionary and loaded_value is Dictionary:
			merged[key] = _deep_merge(defaults[key], loaded_value)
		else:
			merged[key] = loaded_value
	return merged

func _backup_corrupt_save(reason: String, contents: String = "") -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var backup_path := "user://save_data_corrupt_%s_%d.json" % [reason, Time.get_unix_time_from_system()]
	var original := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if original == null:
		return
	var backup := FileAccess.open(backup_path, FileAccess.WRITE)
	if backup == null:
		return
	var payload: String = contents if contents != "" else original.get_as_text()
	backup.store_string(payload)
