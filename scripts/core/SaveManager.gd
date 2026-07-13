extends Node

const LEGACY_SAVE_PATH := "user://save_data.json"
const SAVE_PATH := "user://profile_1.json" # Legacy test/tool compatibility; runtime uses the active slot path.
const PROFILE_INDEX_PATH := "user://profiles.json"
const SAVE_VERSION := 5
const PROFILE_COUNT := 3

var save_data: Dictionary = _default_save_data()
var profile_index: Dictionary = {"version": 1, "active_slot": -1, "legacy_migrated": false, "profiles": {}}
var active_profile_slot := -1

func _enter_tree() -> void:
	load_profile_index()

func load_save() -> void:
	if active_profile_slot < 0:
		push_error("Save load rejected: no active profile selected.")
		return
	save_data = _default_save_data()
	var save_path := _profile_path(active_profile_slot)
	if not FileAccess.file_exists(save_path):
		save_game()
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_backup_corrupt_save("open_failed")
		save_game()
		return
	var raw_text: String = file.get_as_text()
	var json := JSON.new()
	var parse_error := json.parse(raw_text)
	var parsed = json.data if parse_error == OK else null
	if parsed is Dictionary:
		var loaded_version := int(parsed.get("save_version", 1))
		if loaded_version < SAVE_VERSION:
			_backup_corrupt_save("pre_migration_v%d" % loaded_version, raw_text)
			print("Backed up and migrated save data from version %d to %d." % [loaded_version, SAVE_VERSION])
		save_data = _deep_merge(_default_save_data(), parsed)
		save_data["save_version"] = SAVE_VERSION
		save_game()
		return
	_backup_corrupt_save("parse_failed", raw_text)
	save_data = _default_save_data()
	save_game()

func save_game() -> bool:
	if active_profile_slot < 0:
		push_error("Save write rejected: no active profile selected.")
		return false
	var file := FileAccess.open(_profile_path(active_profile_slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not save game data.")
		return false
	save_data["save_version"] = SAVE_VERSION
	file.store_string(JSON.stringify(save_data, "\t"))
	var succeeded := file.get_error() == OK
	if not succeeded:
		push_error("Could not finish writing game data.")
	return succeeded

func load_profile_index() -> void:
	profile_index = {"version": 1, "active_slot": -1, "legacy_migrated": false, "profiles": {}}
	if FileAccess.file_exists(PROFILE_INDEX_PATH):
		var file := FileAccess.open(PROFILE_INDEX_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				profile_index = _deep_merge(profile_index, parsed)
	_migrate_legacy_save_once()
	var indexed_slot: int = int(profile_index.get("active_slot", -1))
	active_profile_slot = indexed_slot if profile_exists(indexed_slot) else -1
	if active_profile_slot < 0:
		profile_index["active_slot"] = -1

func ensure_active_profile() -> bool:
	if has_active_profile():
		return true
	var indexed_slot: int = int(profile_index.get("active_slot", -1))
	if profile_exists(indexed_slot):
		return select_profile(indexed_slot)
	for slot in PROFILE_COUNT:
		if profile_exists(slot):
			return select_profile(slot)
	return create_profile(0, "Player 1")

func get_profile_summary(slot: int) -> Dictionary:
	return profile_index.get("profiles", {}).get(str(slot), {"exists": false, "name": ""})

func profile_exists(slot: int) -> bool:
	return slot >= 0 and slot < PROFILE_COUNT and bool(get_profile_summary(slot).get("exists", false)) and FileAccess.file_exists(_profile_path(slot))

func create_profile(slot: int, profile_name: String) -> bool:
	if slot < 0 or slot >= PROFILE_COUNT or profile_exists(slot):
		return false
	active_profile_slot = slot
	save_data = _default_save_data()
	save_data["profile_name"] = profile_name.strip_edges()
	profile_index["profiles"][str(slot)] = {"exists": true, "name": save_data["profile_name"]}
	profile_index["active_slot"] = slot
	_save_profile_index()
	return save_game()

func select_profile(slot: int) -> bool:
	if not profile_exists(slot):
		return false
	if has_active_profile() and active_profile_slot != slot:
		save_game()
	active_profile_slot = slot
	profile_index["active_slot"] = slot
	_save_profile_index()
	load_save()
	return true

func clear_profile(slot: int) -> bool:
	if slot < 0 or slot >= PROFILE_COUNT:
		return false
	var path := _profile_path(slot)
	if FileAccess.file_exists(path):
		var error := DirAccess.remove_absolute(path)
		if error != OK:
			push_error("Could not clear profile %d (error %d)." % [slot + 1, error])
			return false
	profile_index["profiles"].erase(str(slot))
	if active_profile_slot == slot:
		active_profile_slot = -1
		save_data = _default_save_data()
	profile_index["active_slot"] = active_profile_slot
	_save_profile_index()
	return true

func has_active_profile() -> bool:
	return active_profile_slot >= 0 and profile_exists(active_profile_slot)

func close_active_profile() -> void:
	if has_active_profile():
		save_game()
	active_profile_slot = -1
	profile_index["active_slot"] = -1
	_save_profile_index()
	save_data = _default_save_data()

func _profile_path(slot: int) -> String:
	return "user://profile_%d.json" % (slot + 1)

func _save_profile_index() -> bool:
	var file := FileAccess.open(PROFILE_INDEX_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write profile index.")
		return false
	file.store_string(JSON.stringify(profile_index, "\t"))
	return file.get_error() == OK

func _migrate_legacy_save_once() -> void:
	if bool(profile_index.get("legacy_migrated", false)) or not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	var legacy := FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
	if legacy == null:
		push_error("Legacy save migration failed: could not open source.")
		return
	var raw := legacy.get_as_text()
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_error("Legacy save migration failed: invalid JSON; source was preserved.")
		return
	var backup := FileAccess.open("user://save_data_legacy_backup_%d.json" % Time.get_unix_time_from_system(), FileAccess.WRITE)
	if backup != null:
		backup.store_string(raw)
	var migrated: Dictionary = _deep_merge(_default_save_data(), parsed)
	migrated["save_version"] = SAVE_VERSION
	var profile_name := String(parsed.get("profile_name", "Player 1")).strip_edges()
	if profile_name.is_empty():
		profile_name = "Player 1"
	migrated["profile_name"] = profile_name
	var destination := FileAccess.open(_profile_path(0), FileAccess.WRITE)
	if destination == null:
		push_error("Legacy save migration failed: could not create Profile 1.")
		return
	destination.store_string(JSON.stringify(migrated, "\t"))
	profile_index["profiles"]["0"] = {"exists": true, "name": profile_name}
	profile_index["legacy_migrated"] = true
	_save_profile_index()
	print("Legacy save migration succeeded: imported into Profile 1.")

func add_banked_coins(value: int) -> void:
	save_data["banked_coins"] = max(0, int(save_data.get("banked_coins", 0)) + max(value, 0))
	save_game()

func spend_banked_coins(value: int) -> bool:
	if value < 0 or int(save_data.get("banked_coins", 0)) < value:
		return false
	save_data["banked_coins"] -= value
	save_game()
	return true

func _default_save_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"profile_name": "",
		"banked_coins": 0,
		"upgrades": {},
		"upgrade_choices": {},
		"permanent_upgrade_ids": [],
		"upgrade_tree_version": 1,
		"mission_states": {},
		"mission_progress": {},
		"completed_missions": [],
		"claimed_missions": [],
		"settings": {
			"screenshake": true,
			"hit_flash": true,
			"sfx_volume": 0.8,
			"auto_fire": bool(GameManager.game_config.get("auto_fire_default", true))
		},
		"selected_route_type": "balanced_route",
		"selected_hero": "captain_rhodes",
		"heroes": {
			"unlocked": ["captain_rhodes"],
			"upgrades": {},
			"timed_unlocks": {}
		},
		"specialists": {
			"unlocked": []
		},
		"boss_rewards_claimed": [],
		"daily_challenge": {
			"last_seed": "",
			"completed_seed": "",
			"claimed_reward_seed": "",
			"best_distance": 0,
			"best_score": 0,
			"last_summary": {}
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
			"runs_completed": 0,
			"highest_coins_in_run": 0,
			"total_zombies_killed": 0,
			"total_bosses_defeated": 0,
			"total_soldiers_rescued": 0,
			"total_pickups_collected": 0,
			"total_gates_chosen": 0,
			"total_runs_started": 0,
			"total_runs_failed": 0,
			"best_combo": 0,
			"best_run_score": 0,
			"best_daily_distance": 0,
			"best_daily_score": 0
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
	if active_profile_slot < 0 or not FileAccess.file_exists(_profile_path(active_profile_slot)):
		return
	var backup_path := "user://save_data_corrupt_profile_%d_%s_%d.json" % [active_profile_slot + 1, reason, Time.get_unix_time_from_system()]
	var original := FileAccess.open(_profile_path(active_profile_slot), FileAccess.READ)
	if original == null:
		return
	var backup := FileAccess.open(backup_path, FileAccess.WRITE)
	if backup == null:
		return
	var payload: String = contents if contents != "" else original.get_as_text()
	backup.store_string(payload)
