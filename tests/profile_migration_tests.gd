extends SceneTree

var failures: Array[String] = []
var passes := 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("[PASS] ", label)
	else:
		failures.append(label)
		push_error("[FAIL] " + label)

func _run() -> void:
	var saves: Node = root.get_node("SaveManager")
	for path in ["user://profiles.json", "user://profile_1.json", "user://profile_2.json", "user://profile_3.json", "user://save_data.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var legacy := FileAccess.open("user://save_data.json", FileAccess.WRITE)
	legacy.store_string(JSON.stringify({
		"save_version": 4,
		"banked_coins": 321,
		"upgrades": {"soldier_damage": 2},
		"completed_missions": ["legacy_mission"],
		"stats": {"runs_completed": 7, "best_distance": 444}
	}, "\t"))
	legacy.close()
	saves.load_profile_index()
	_expect(saves.profile_exists(0), "legacy save imports into Profile 1")
	_expect(String(saves.get_profile_summary(0).get("name", "")) == "Profile 1", "migration assigns the standard slot name")
	_expect(saves.select_profile(0), "migrated Profile 1 can be selected")
	_expect(int(saves.save_data.get("banked_coins", 0)) == 321 and int(saves.save_data.get("stats", {}).get("runs_completed", 0)) == 7, "migration preserves coins and run history")
	_expect(int(saves.save_data.get("upgrades", {}).get("soldier_damage", 0)) == 2 and saves.save_data.get("completed_missions", []).has("legacy_mission"), "migration preserves upgrades and mission progression")
	var backup_found := false
	for file_name in DirAccess.get_files_at("user://"):
		if String(file_name).begins_with("save_data_legacy_backup_"):
			backup_found = true
	_expect(backup_found, "migration backs up the legacy save")
	var legacy_changed := FileAccess.open("user://save_data.json", FileAccess.WRITE)
	legacy_changed.store_string(JSON.stringify({"banked_coins": 9999}))
	legacy_changed.close()
	saves.load_profile_index()
	_expect(saves.select_profile(0) and int(saves.save_data.get("banked_coins", 0)) == 321, "legacy data is not imported repeatedly")
	print("PROFILE MIGRATION TESTS: %d passed, %d failed" % [passes, failures.size()])
	quit(0 if failures.is_empty() else 1)
