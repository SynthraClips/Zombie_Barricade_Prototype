extends Node2D
class_name SurvivorRescueManager

@export var rescue_scene: PackedScene

var run_manager: Node
var active_rescues: Array[Node2D] = []
var next_spawn_distance := 0.0

func setup(run: Node) -> void:
	run_manager = run
	if rescue_scene == null:
		rescue_scene = load("res://scenes/gameplay/SurvivorRescue.tscn")
	for child in get_children():
		child.queue_free()
	active_rescues.clear()
	next_spawn_distance = float(_get_config().get("spawn_start_distance", 54.0))

func update_rescues(delta: float) -> void:
	active_rescues = active_rescues.filter(func(rescue): return is_instance_valid(rescue))
	for rescue in active_rescues:
		rescue.update_rescue(delta)
	if active_rescues.size() >= int(_get_config().get("max_active", 1)):
		return
	if run_manager.distance_travelled < next_spawn_distance:
		return
	_attempt_spawn()
	next_spawn_distance += float(_get_config().get("spawn_distance_interval", 92.0)) * run_manager.get_route_rescue_spawn_distance_multiplier()

func spawn_rescue(world_position: Vector2 = Vector2.INF, config_overrides: Dictionary = {}) -> Node2D:
	if active_rescues.size() >= int(_get_config().get("max_active", 1)):
		return null
	var config := _get_config().duplicate(true)
	for key in config_overrides.keys():
		config[key] = config_overrides[key]
	var spawn_y: float = float(config.get("spawn_y", run_manager.road.get_spawn_y() - 24.0))
	var spawn_position := world_position
	if spawn_position == Vector2.INF:
		var padding: float = float(config.get("spawn_lane_padding", 78.0))
		var raw_x: float = randf_range(210.0, 510.0)
		spawn_position = Vector2(run_manager.road.clamp_lane_x(raw_x, spawn_y, padding), spawn_y)
	var rescue: Node2D = rescue_scene.instantiate()
	add_child(rescue)
	rescue.call("initialize", run_manager, self, spawn_position, config)
	active_rescues.append(rescue)
	run_manager.ui_manager.show_status_message("SURVIVORS TRAPPED!", Color("ffd166"))
	run_manager.ui_manager.spawn_reward_popup(spawn_position + Vector2(-34.0, -52.0), "RESCUE", Color("ffd166"))
	return rescue

func unregister_rescue(rescue: Node) -> void:
	active_rescues.erase(rescue)

func clear_all_rescues(reason: String = "reset") -> void:
	var rescues_to_clear := active_rescues.duplicate()
	active_rescues.clear()
	for rescue in rescues_to_clear:
		if not is_instance_valid(rescue):
			continue
		if rescue.has_method("force_cleanup"):
			rescue.call("force_cleanup", reason)
		else:
			rescue.queue_free()

func find_rescue_at_position(world_position: Vector2, hit_radius: float) -> Node2D:
	for rescue in active_rescues:
		if is_instance_valid(rescue) and rescue.global_position.distance_to(world_position) <= hit_radius:
			return rescue
	return null

func get_target_rescue(from_position: Vector2, max_range: float, aim_position: Vector2 = Vector2.ZERO, auto_fire: bool = false) -> Node2D:
	var best_rescue: Node2D
	var best_score := INF
	for rescue in active_rescues:
		if not is_instance_valid(rescue):
			continue
		if from_position.distance_to(rescue.global_position) > max_range:
			continue
		if not auto_fire and aim_position != Vector2.ZERO and rescue.global_position.distance_to(aim_position) > 120.0:
			continue
		var score: float = from_position.distance_to(rescue.global_position) if auto_fire else rescue.global_position.distance_to(aim_position)
		if score < best_score:
			best_score = score
			best_rescue = rescue
	return best_rescue

func award_rescue(rescue: Node) -> Dictionary:
	var config := _get_config()
	var rescue_soldiers = rescue.get("soldiers_reward")
	var rescue_coins = rescue.get("coin_reward")
	var soldiers_reward: int = int(rescue_soldiers if rescue_soldiers != null else config.get("soldiers_reward", 3))
	var coin_reward: int = int(rescue_coins if rescue_coins != null else config.get("coin_reward", 0))
	var applied_soldiers: int = 0
	if soldiers_reward > 0:
		var allow_overcap: bool = bool(GameManager.game_config.get("allow_pickup_soldier_overcap", false))
		var soldier_result: Dictionary = run_manager.reward_manager.apply_reward_effect("add_soldiers", {
			"value": soldiers_reward,
			"label": "Survivor Rescue",
			"color": "#7be495",
			"allow_overcap": allow_overcap,
			"overcap_limit": int(GameManager.game_config.get("pickup_soldier_overcap_limit", 0))
		})
		applied_soldiers = int(soldier_result.get("applied", 0))
	if coin_reward > 0:
		run_manager.reward_manager.apply_reward_effect("coins", {
			"value": coin_reward,
			"label": "Rescue Bonus",
			"color": "#ffd166"
		})
	run_manager.register_survivor_rescue(applied_soldiers)
	return {
		"soldiers": applied_soldiers,
		"coins": coin_reward,
		"popup": "+%d SOLDIERS RESCUED" % applied_soldiers,
		"color": Color("7be495")
	}

func _attempt_spawn() -> void:
	var config := _get_config()
	if not bool(config.get("enabled", true)):
		return
	var spawn_chance: float = float(config.get("spawn_chance", 0.3)) + run_manager.get_pressure_high_value_event_bonus() * 0.6 + run_manager.get_route_rescue_spawn_chance_bonus()
	if randf() > min(spawn_chance, 0.9):
		return
	spawn_rescue()

func _get_config() -> Dictionary:
	return GameManager.game_config.get("survivor_rescue", {})
