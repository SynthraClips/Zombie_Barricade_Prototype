extends Node
class_name MutationManager

var run_manager: Node
var mutation_settings: Dictionary = {}
var mutation_definitions: Dictionary = {}
var mutation_schedule: Array = []
var active_mutation_id := ""
var active_mutation: Dictionary = {}
var active_time_remaining := 0.0
var next_trigger_distance := INF
var next_trigger_time := INF
var last_mutation_id := ""

func setup(run: Node) -> void:
	run_manager = run
	mutation_settings = GameManager.mutation_data.get("settings", {}).duplicate(true)
	mutation_definitions = GameManager.mutation_data.get("mutations", {}).duplicate(true)
	mutation_schedule = GameManager.mutation_data.get("schedule", []).duplicate(true)
	clear_state("setup", false)
	var first_schedule: Dictionary = _get_schedule_for_current_progress()
	next_trigger_distance = _get_schedule_value(first_schedule, "start_distance", float(mutation_settings.get("start_distance", INF)))
	next_trigger_time = _get_schedule_value(first_schedule, "time_interval", float(mutation_settings.get("time_interval", INF)))

func update_mutations(delta: float) -> void:
	if not is_mutation_active():
		_try_start_scheduled_mutation()
		return
	active_time_remaining = max(active_time_remaining - delta, 0.0)
	if active_time_remaining <= 0.0:
		end_active_mutation()

func can_start_mutation_for_schedule(schedule_override: Dictionary = {}) -> bool:
	if not bool(mutation_settings.get("enabled", true)):
		return false
	if is_mutation_active() and not bool(mutation_settings.get("allow_stacking", false)):
		return false
	var schedule_row: Dictionary = schedule_override if not schedule_override.is_empty() else _get_schedule_for_current_progress()
	if schedule_row.is_empty():
		return false
	if run_manager.current_wave < int(schedule_row.get("minimum_wave", mutation_settings.get("minimum_wave", 1))):
		return false
	return not _get_allowed_mutation_ids(schedule_row).is_empty()

func get_active_mutation_state() -> Dictionary:
	return {
		"id": active_mutation_id,
		"label": String(active_mutation.get("label", "")),
		"description": String(active_mutation.get("description", "")),
		"time_remaining": active_time_remaining,
		"warning_text": String(active_mutation.get("warning_text", "")),
		"reward_multiplier": get_reward_multiplier()
	}

func is_mutation_active() -> bool:
	return active_mutation_id != ""

func get_spawn_weight_multiplier(enemy_id: String) -> float:
	if not is_mutation_active():
		return 1.0
	return max(0.01, float(active_mutation.get("spawn_weight_modifiers", {}).get(enemy_id, 1.0)))

func get_enemy_stat_modifiers(enemy_id: String) -> Dictionary:
	if not is_mutation_active():
		return {}
	var affected_ids: Array = active_mutation.get("affected_enemy_ids", [])
	if not affected_ids.is_empty() and not affected_ids.has(enemy_id):
		return {}
	return active_mutation.get("enemy_stat_modifiers", {}).duplicate(true)

func get_reward_multiplier() -> float:
	if not is_mutation_active():
		return 1.0
	return max(1.0, float(active_mutation.get("reward_multiplier", 1.0)))

func select_mutation_from_allowed(allowed_mutations: Array) -> Dictionary:
	var valid_ids: Array[String] = []
	for mutation_id in allowed_mutations:
		var normalized_id: String = String(mutation_id)
		if mutation_definitions.has(normalized_id):
			valid_ids.append(normalized_id)
	if valid_ids.is_empty():
		return {}
	if bool(mutation_settings.get("avoid_immediate_repeats", true)) and valid_ids.size() > 1 and valid_ids.has(last_mutation_id):
		valid_ids.erase(last_mutation_id)
	var selected_id: String = valid_ids[randi() % valid_ids.size()]
	return mutation_definitions.get(selected_id, {}).duplicate(true)

func start_mutation_by_id(mutation_id: String, duration_override: float = -1.0) -> bool:
	if not mutation_definitions.has(mutation_id):
		return false
	if is_mutation_active():
		if not bool(mutation_settings.get("allow_stacking", false)):
			end_active_mutation(false)
		else:
			return false
	active_mutation = mutation_definitions.get(mutation_id, {}).duplicate(true)
	active_mutation_id = String(active_mutation.get("id", mutation_id))
	active_time_remaining = duration_override if duration_override > 0.0 else float(active_mutation.get("duration", 12.0))
	last_mutation_id = active_mutation_id
	_apply_active_mutation_to_existing_enemies()
	run_manager.ui_manager.show_status_message(String(active_mutation.get("warning_text", "Mutation: %s" % active_mutation.get("label", mutation_id))), Color("ff8b6b"))
	run_manager.notify_mutation_state_changed()
	return true

func end_active_mutation(show_message: bool = true) -> void:
	if not is_mutation_active():
		return
	var end_text: String = String(active_mutation.get("end_text", ""))
	active_mutation_id = ""
	active_mutation = {}
	active_time_remaining = 0.0
	_apply_active_mutation_to_existing_enemies()
	if show_message and end_text != "":
		run_manager.ui_manager.show_status_message(end_text, Color("8ee4ff"))
	run_manager.notify_mutation_state_changed()

func clear_state(reason: String = "reset", show_message: bool = false) -> void:
	if not is_mutation_active():
		active_mutation_id = ""
		active_mutation = {}
		active_time_remaining = 0.0
		run_manager.notify_mutation_state_changed()
		return
	end_active_mutation(show_message and reason != "setup")

func get_allowed_mutation_ids_for_current_schedule() -> Array:
	return _get_allowed_mutation_ids(_get_schedule_for_current_progress())

func _try_start_scheduled_mutation() -> void:
	var schedule_row: Dictionary = _get_schedule_for_current_progress()
	if not can_start_mutation_for_schedule(schedule_row):
		return
	if run_manager.distance_travelled < next_trigger_distance:
		return
	if run_manager.elapsed_time < next_trigger_time:
		return
	var selected_mutation: Dictionary = select_mutation_from_allowed(_get_allowed_mutation_ids(schedule_row))
	if selected_mutation.is_empty():
		return
	var duration_override: float = float(selected_mutation.get("duration", 12.0))
	start_mutation_by_id(String(selected_mutation.get("id", "")), duration_override)
	var interval_distance: float = _get_schedule_value(schedule_row, "interval_distance", float(mutation_settings.get("distance_interval", 120.0)))
	var time_interval: float = _get_schedule_value(schedule_row, "time_interval", float(mutation_settings.get("time_interval", 24.0)))
	var pressure_scale: float = run_manager.get_pressure_mutation_interval_scale() if run_manager != null else 1.0
	next_trigger_distance = run_manager.distance_travelled + interval_distance * pressure_scale
	next_trigger_time = run_manager.elapsed_time + time_interval * pressure_scale

func _get_schedule_for_current_progress() -> Dictionary:
	var selected: Dictionary = {}
	for row in mutation_schedule:
		if run_manager.distance_travelled >= float(row.get("start_distance", 0.0)):
			selected = row
	return selected

func _get_allowed_mutation_ids(schedule_row: Dictionary) -> Array:
	var allowed: Array = schedule_row.get("allowed_mutations", [])
	if allowed.is_empty():
		allowed = mutation_definitions.keys()
	return allowed

func _get_schedule_value(schedule_row: Dictionary, key: String, default_value: float) -> float:
	if schedule_row.has(key):
		return float(schedule_row.get(key, default_value))
	return default_value

func _apply_active_mutation_to_existing_enemies() -> void:
	if run_manager == null or run_manager.enemy_manager == null:
		return
	run_manager.enemy_manager.refresh_enemy_mutation_modifiers()
