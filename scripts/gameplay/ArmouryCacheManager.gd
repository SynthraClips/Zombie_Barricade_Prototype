extends Node2D
class_name ArmouryCacheManager

@export var cache_scene: PackedScene

var run_manager: Node
var active_caches: Array[Node2D] = []
var next_spawn_distance := 0.0

func setup(run: Node) -> void:
	run_manager = run
	if cache_scene == null:
		cache_scene = load("res://scenes/gameplay/ArmouryCache.tscn")
	for child in get_children():
		child.queue_free()
	active_caches.clear()
	next_spawn_distance = float(_get_config().get("spawn_start_distance", 90.0))

func update_caches(delta: float) -> void:
	active_caches = active_caches.filter(func(cache): return is_instance_valid(cache))
	for cache in active_caches:
		cache.update_cache(delta)
	if active_caches.size() >= int(_get_config().get("max_active", 1)):
		return
	if run_manager.distance_travelled < next_spawn_distance:
		return
	_attempt_spawn()
	next_spawn_distance += float(_get_config().get("spawn_distance_interval", 120.0)) * run_manager.get_route_supply_spawn_distance_multiplier()

func spawn_cache(world_position: Vector2 = Vector2.INF, config_overrides: Dictionary = {}) -> Node2D:
	if active_caches.size() >= int(_get_config().get("max_active", 1)):
		return null
	var config := _get_config().duplicate(true)
	for key in config_overrides.keys():
		config[key] = config_overrides[key]
	var spawn_y: float = float(config.get("spawn_y", run_manager.road.get_spawn_y() - 36.0))
	var spawn_position := world_position
	if spawn_position == Vector2.INF:
		var padding: float = float(config.get("spawn_lane_padding", 68.0))
		var raw_x: float = randf_range(210.0, 510.0)
		spawn_position = Vector2(run_manager.road.clamp_lane_x(raw_x, spawn_y, padding), spawn_y)
	var cache: Node2D = cache_scene.instantiate()
	var reward_id: String = _roll_reward_id(String(config.get("reward_table", "default")))
	add_child(cache)
	cache.call("initialize", run_manager, self, spawn_position, config, reward_id)
	active_caches.append(cache)
	run_manager.ui_manager.show_status_message("ARMOURY CACHE!", Color("ffd166"))
	run_manager.ui_manager.spawn_reward_popup(spawn_position + Vector2(-20.0, -34.0), "SUPPLY CACHE", Color("ffd166"))
	return cache

func unregister_cache(cache: Node) -> void:
	active_caches.erase(cache)

func clear_all_caches(reason: String = "reset") -> void:
	var caches_to_clear := active_caches.duplicate()
	active_caches.clear()
	for cache in caches_to_clear:
		if not is_instance_valid(cache):
			continue
		if cache.has_method("force_cleanup"):
			cache.call("force_cleanup", reason)
		else:
			cache.queue_free()

func find_cache_at_position(world_position: Vector2, hit_radius: float) -> Node2D:
	for cache in active_caches:
		if is_instance_valid(cache) and cache.global_position.distance_to(world_position) <= hit_radius:
			return cache
	return null

func get_target_cache(from_position: Vector2, max_range: float, aim_position: Vector2 = Vector2.ZERO, auto_fire: bool = false) -> Node2D:
	var best_cache: Node2D
	var best_score := INF
	for cache in active_caches:
		if not is_instance_valid(cache):
			continue
		if from_position.distance_to(cache.global_position) > max_range:
			continue
		if not auto_fire and aim_position != Vector2.ZERO and cache.global_position.distance_to(aim_position) > 115.0:
			continue
		var score: float = from_position.distance_to(cache.global_position) if auto_fire else cache.global_position.distance_to(aim_position)
		if score < best_score:
			best_score = score
			best_cache = cache
	return best_cache

func award_cache_reward(cache: Node) -> Dictionary:
	var reward_id: String = String(cache.get("reward_id"))
	if reward_id == "":
		return {}
	return run_manager.reward_manager.apply_reward_by_id(reward_id)

func _attempt_spawn() -> void:
	var config := _get_config()
	if not bool(config.get("enabled", true)):
		return
	var spawn_chance: float = float(config.get("spawn_chance", 0.35)) + run_manager.get_pressure_high_value_event_bonus() + run_manager.get_route_supply_spawn_chance_bonus()
	if randf() > min(spawn_chance, 0.95):
		return
	spawn_cache()

func _roll_reward_id(table_name: String) -> String:
	var reward_tables: Dictionary = GameManager.reward_data.get("armoury_cache_reward_tables", {})
	var route_table: String = run_manager.get_route_armoury_cache_reward_table()
	if route_table != "" and reward_tables.has(route_table):
		table_name = route_table
	var entries: Array = reward_tables.get(table_name, [])
	if entries.is_empty():
		return "coins_large"
	var total_weight := 0.0
	for entry in entries:
		total_weight += max(0.01, float(entry.get("weight", 1.0)))
	var roll := randf() * total_weight
	for entry in entries:
		roll -= max(0.01, float(entry.get("weight", 1.0)))
		if roll <= 0.0:
			return String(entry.get("reward_id", "coins_large"))
	return String(entries.back().get("reward_id", "coins_large"))

func _get_config() -> Dictionary:
	return GameManager.game_config.get("armoury_cache", {})
