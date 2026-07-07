extends Node

signal mission_progressed
signal mission_completed(mission_id: String)

var mission_defs: Array = []

func initialize_from_data(data: Dictionary) -> void:
	mission_defs = data.get("missions", [])
	for mission in mission_defs:
		var mission_id := String(mission.get("id", ""))
		if mission_id == "":
			continue
		if not SaveManager.save_data["mission_progress"].has(mission_id):
			SaveManager.save_data["mission_progress"][mission_id] = 0
	SaveManager.save_game()

func increment_progress(target_type: String, amount: int) -> void:
	for mission in mission_defs:
		if String(mission.get("target_type", "")) != target_type:
			continue
		var mission_id := String(mission.get("id", ""))
		if mission_id in SaveManager.save_data["completed_missions"]:
			continue
		SaveManager.save_data["mission_progress"][mission_id] = int(SaveManager.save_data["mission_progress"].get(mission_id, 0)) + amount
		_check_completion(mission)
	SaveManager.save_game()
	mission_progressed.emit()

func set_progress_to_max(target_type: String, value: int) -> void:
	for mission in mission_defs:
		if String(mission.get("target_type", "")) != target_type:
			continue
		var mission_id := String(mission.get("id", ""))
		if mission_id in SaveManager.save_data["completed_missions"]:
			continue
		SaveManager.save_data["mission_progress"][mission_id] = max(int(SaveManager.save_data["mission_progress"].get(mission_id, 0)), value)
		_check_completion(mission)
	SaveManager.save_game()
	mission_progressed.emit()

func _check_completion(mission: Dictionary) -> void:
	var mission_id := String(mission.get("id", ""))
	var target_value := int(mission.get("target_value", 1))
	if int(SaveManager.save_data["mission_progress"].get(mission_id, 0)) < target_value:
		return
	if mission_id in SaveManager.save_data["completed_missions"]:
		return
	SaveManager.save_data["completed_missions"].append(mission_id)
	SaveManager.add_banked_coins(int(mission.get("reward", {}).get("coins", 0)))
	mission_completed.emit(mission_id)

func register_run_summary(summary: Dictionary) -> void:
	set_progress_to_max("distance", int(summary.get("distance", 0)))
	if int(summary.get("final_soldiers", 0)) >= 6 and bool(summary.get("victory", false)):
		set_progress_to_max("finish_with_soldiers", int(summary.get("final_soldiers", 0)))

func get_mission_rows() -> Array:
	var rows: Array = []
	for mission in mission_defs:
		var mission_id := String(mission.get("id", ""))
		rows.append({
			"id": mission_id,
			"title": mission.get("title", ""),
			"description": mission.get("description", ""),
			"progress": int(SaveManager.save_data["mission_progress"].get(mission_id, 0)),
			"target": int(mission.get("target_value", 0)),
			"completed": mission_id in SaveManager.save_data["completed_missions"],
			"reward_coins": int(mission.get("reward", {}).get("coins", 0))
		})
	return rows
