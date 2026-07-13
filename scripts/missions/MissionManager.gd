extends Node

signal mission_progressed
signal mission_completed(mission_id: String)
signal mission_claimed(mission_id: String)

var mission_defs: Array = []

func initialize_from_data(data: Dictionary) -> void:
	mission_defs = data.get("missions", []).duplicate(true)
	var daily_seed: String = Time.get_date_string_from_system()
	for daily_template in data.get("daily_templates", []):
		var mission: Dictionary = daily_template.duplicate(true)
		var template_id: String = String(mission.get("id", "daily"))
		mission["id"] = "%s_%s" % [template_id, daily_seed]
		mission["category"] = "daily"
		mission["repeatable"] = false
		mission_defs.append(mission)
	for mission in mission_defs:
		var mission_id := String(mission.get("id", ""))
		if mission_id == "":
			continue
		_ensure_mission_state(mission)
	SaveManager.save_game()

func increment_progress(target_type: String, amount: int) -> void:
	if amount <= 0:
		return
	for mission in mission_defs:
		if String(mission.get("target_type", "")) != target_type:
			continue
		var mission_id := String(mission.get("id", ""))
		_ensure_mission_state(mission)
		if _is_fully_claimed(mission):
			continue
		var state: Dictionary = _get_state(mission_id)
		if bool(state.get("claim_pending", false)):
			continue
		state["progress"] = int(state.get("progress", 0)) + amount
		SaveManager.save_data["mission_progress"][mission_id] = int(state.get("progress", 0))
		SaveManager.save_data["mission_states"][mission_id] = state
		_check_completion(mission)
	SaveManager.save_game()
	mission_progressed.emit()

func set_progress_to_max(target_type: String, value: int) -> void:
	for mission in mission_defs:
		if String(mission.get("target_type", "")) != target_type:
			continue
		var mission_id := String(mission.get("id", ""))
		_ensure_mission_state(mission)
		if _is_fully_claimed(mission):
			continue
		var state: Dictionary = _get_state(mission_id)
		if bool(state.get("claim_pending", false)):
			continue
		state["progress"] = max(int(state.get("progress", 0)), value)
		SaveManager.save_data["mission_progress"][mission_id] = int(state.get("progress", 0))
		SaveManager.save_data["mission_states"][mission_id] = state
		_check_completion(mission)
	SaveManager.save_game()
	mission_progressed.emit()

func _check_completion(mission: Dictionary) -> void:
	var mission_id := String(mission.get("id", ""))
	var state: Dictionary = _get_state(mission_id)
	var target_value := int(mission.get("target_value", 1))
	if int(state.get("progress", 0)) < target_value:
		return
	if bool(state.get("claim_pending", false)):
		return
	state["claim_pending"] = true
	SaveManager.save_data["mission_states"][mission_id] = state
	mission_completed.emit(mission_id)

func register_run_summary(summary: Dictionary) -> void:
	set_progress_to_max("distance", int(summary.get("distance", 0)))
	if int(summary.get("final_soldiers", 0)) >= 6 and bool(summary.get("victory", false)):
		set_progress_to_max("finish_with_soldiers", int(summary.get("final_soldiers", 0)))
	if int(summary.get("mini_objectives_completed", 0)) > 0:
		increment_progress("mini_objectives_completed", int(summary.get("mini_objectives_completed", 0)))
	if String(summary.get("route_type_id", "")) == "dangerous_route" and int(summary.get("bosses_defeated", summary.get("boss_kills", 0))) > 0:
		increment_progress("dangerous_route_boss", 1)
	if bool(summary.get("is_daily", false)) or String(summary.get("mode", "")) == "daily":
		increment_progress("complete_daily", 1)

func claim_mission(mission_id: String) -> bool:
	var mission: Dictionary = get_mission_definition(mission_id)
	if mission.is_empty():
		return false
	_ensure_mission_state(mission)
	var state: Dictionary = _get_state(mission_id)
	var target_value: int = int(mission.get("target_value", 1))
	if not bool(state.get("claim_pending", false)) and int(state.get("progress", 0)) < target_value:
		return false
	var reward_coins: int = int(mission.get("reward", {}).get("coins", 0))
	if reward_coins > 0:
		SaveManager.add_banked_coins(reward_coins)
	state["claim_pending"] = false
	state["claimed_count"] = int(state.get("claimed_count", 0)) + 1
	if bool(mission.get("repeatable", false)):
		state["progress"] = 0
		state["claim_pending"] = false
		SaveManager.save_data["mission_progress"][mission_id] = 0
		SaveManager.save_data["completed_missions"].erase(mission_id)
		SaveManager.save_data["claimed_missions"].erase(mission_id)
	else:
		if mission_id not in SaveManager.save_data["completed_missions"]:
			SaveManager.save_data["completed_missions"].append(mission_id)
	if mission_id not in SaveManager.save_data["claimed_missions"]:
		SaveManager.save_data["claimed_missions"].append(mission_id)
	SaveManager.save_data["mission_progress"][mission_id] = int(state.get("progress", 0))
	SaveManager.save_data["mission_states"][mission_id] = state
	SaveManager.save_game()
	mission_claimed.emit(mission_id)
	mission_progressed.emit()
	return true

func get_mission_rows() -> Array:
	var rows: Array = []
	for mission in mission_defs:
		var mission_id := String(mission.get("id", ""))
		var state: Dictionary = _get_state(mission_id)
		rows.append({
			"id": mission_id,
			"title": mission.get("title", ""),
			"description": mission.get("description", ""),
			"progress": int(state.get("progress", 0)),
			"target": int(mission.get("target_value", 0)),
			"completed": _is_fully_claimed(mission),
			"claim_pending": bool(state.get("claim_pending", false)),
			"reward_coins": int(mission.get("reward", {}).get("coins", 0)),
			"category": String(mission.get("category", "standard")),
			"repeatable": bool(mission.get("repeatable", false)),
			"claimed_count": int(state.get("claimed_count", 0))
		})
	return rows

func get_mission_definition(mission_id: String) -> Dictionary:
	for mission in mission_defs:
		if String(mission.get("id", "")) == mission_id:
			return mission
	return {}

func _ensure_mission_state(mission: Dictionary) -> void:
	var mission_id: String = String(mission.get("id", ""))
	if mission_id == "":
		return
	if not SaveManager.save_data["mission_progress"].has(mission_id):
		SaveManager.save_data["mission_progress"][mission_id] = 0
	if not SaveManager.save_data["mission_states"].has(mission_id):
		SaveManager.save_data["mission_states"][mission_id] = {
			"progress": int(SaveManager.save_data["mission_progress"].get(mission_id, 0)),
			"claim_pending": false,
			"claimed_count": 1 if mission_id in SaveManager.save_data.get("completed_missions", []) else 0
		}

func _get_state(mission_id: String) -> Dictionary:
	var state: Dictionary = SaveManager.save_data.get("mission_states", {}).get(mission_id, {}).duplicate(true)
	state["progress"] = int(state.get("progress", SaveManager.save_data.get("mission_progress", {}).get(mission_id, 0)))
	state["claim_pending"] = bool(state.get("claim_pending", false))
	state["claimed_count"] = int(state.get("claimed_count", 1 if mission_id in SaveManager.save_data.get("completed_missions", []) else 0))
	return state

func _is_fully_claimed(mission: Dictionary) -> bool:
	var mission_id: String = String(mission.get("id", ""))
	var state: Dictionary = _get_state(mission_id)
	if bool(mission.get("repeatable", false)):
		return false
	return int(state.get("claimed_count", 0)) > 0 or mission_id in SaveManager.save_data.get("completed_missions", [])
